# Families on more than one phone: encrypted relay, joined by QR code

Status: steps 1 to 4 are built and shipped in the family builds. Step 5's one-app change is built
on the `one-app` branch and held until every phone has moved. Decided 2026-11-16: an encrypted relay with a QR-code join. Not
local-only sync, and not a server that can read family data.

## What a family sees

1. **A parent sets up on their phone.** This is the same three steps as today: admin name and
   code, players, chores. The family lives on this phone, and nothing goes anywhere yet. A family
   that only ever uses one device never touches the relay.
2. **The parent adds a phone.** Admin → "Add a phone" (after the admin code). The phone shows a QR
   code for 10 minutes and says: "Scan this with the other phone's camera, inside DOYOURWORK."
3. **The other phone joins.** On first run, setup offers "Join a family" next to "Set up this
   device". The phone scans the code, downloads the family, and asks "Whose phone is this?"
   (or "Shared phone"). It never asks for an account, email or password.
4. **From then on everything syncs.** Chores logged, approvals, dares, players and the chore list
   reach every phone, wherever the phones are. Admin actions still need the admin code on every
   phone.
5. **The parent removes a phone.** Admin → Phones → Remove. That phone stops getting updates.

Joining works between iPhone, iPad and Android in any mix.

## How it works

### The family key never leaves the family's phones

- **Setup.** When a family first adds a phone, the first phone makes:
  - a random **household id** (16 bytes), and
  - a random **family key** (32 bytes).
- **The QR code** carries `dyw1:` + base64url(household id ‖ family key ‖ join token), about 90
  characters. It passes from screen to camera and is never sent to the server.
- **Encryption.**
  - Two subkeys come from the family key with HKDF-SHA256 (salt = household id, info "dyw1 enc"
    and "dyw1 row"), so encryption and row-id hashing never share a key.
  - Every record is encrypted on the phone with AES-256-GCM under the enc subkey, with a fresh
    random 12-byte nonce, and stored as base64(0x01 ‖ nonce ‖ ciphertext ‖ tag).
  - The associated data is household id ‖ record kind ‖ 0x00 ‖ row id, so the server can't swap
    rows between families, kinds or rows without decryption failing.
  - The exact format, byte for byte, is spelled out in `native/tools/relay-crypto.mjs`.
  - The library on each platform: CryptoKit `AES.GCM` on iOS, and `Cipher("AES/GCM/NoPadding")`
    on Android (built in, no new dependency).
- **Where phones keep the key.** On iOS, the Keychain, marked this-device-only so it doesn't
  spread through iCloud Keychain. On Android, an AES key in the Android Keystore that wraps it.
- **State keys are hashed too.** Today's state keys (`players`, `dare|3|2026-11-16`) would reveal
  things, so the server stores HMAC-SHA256(family key, key) instead.

### What the server holds

| Table | Columns | What the server can see |
|---|---|---|
| `households` | id, created_at | That a household exists |
| `household_devices` | household_id, device_user_id, joined_at | How many devices, and when they joined |
| `join_tokens` | household_id, token_hash, expires_at, used_at | Nothing usable: a hash, and 10 minutes long |
| `records` | household_id, kind (`log` \| `state`), row_id, ciphertext, client_updated_at, server_updated_at | Sizes, counts and timing. Not names, chores, points or codes |

- **Device identity.** Each device signs in with **Supabase anonymous auth**: no email, just a
  random user id kept on the device.
- **Access rules.** Row-level security allows a device to read and write `records` only for
  households it's listed in. Someone who photographs the QR code later gets nothing: the token has
  expired, and without a device row they can't download the ciphertext.
- **Joining** goes through one function, `join_household(household_id, token)`. It checks the
  token's hash, that it hasn't expired, and that it hasn't been used, then adds the calling
  device. Making a token is `create_join_token(household_id)`, allowed only for existing members.
  The admin-code check happens in the app, before it calls this.
- **The server also sees** device IP addresses and request times, like any server. Say so in the
  privacy policy.

### Sync keeps today's rules

The server can't read records, so all merging stays on the phones. It already happens there today:

- **Logs** (`kind = log`, one row per chore logged). The server's copy wins unless this phone has
  a change that hasn't gone out yet. This is `LogSync` today.
- **State** (`kind = state`, one row per hashed key). The newest `client_updated_at` wins. This is
  `StateSync` today.
- **Fetching.** A phone pulls `records where server_updated_at > last pull`. It syncs when the app
  opens, comes to the front, or after a change, as now. Live updates through Supabase Realtime can
  come later.

`LogSync`, `StateSync` and `FamilyState` stay. Only the transport underneath them changes, from
plain rows in `simple_logs` / `family_state` to encrypted rows in `records`. This applies to both
DoYourWorkCore and the Kotlin `sync` package.

### Shared test vectors

Add `native/fixtures/relay-crypto.json`: fixed key, nonce, plaintext, associated data and expected
ciphertext, plus HMAC cases. Both test suites read it, the same way `engine-scenarios.json` keeps
the engines in step. An iPhone and an Android phone must produce and open the same bytes.

## Losing phones

- **One phone lost:** nothing is lost. The other phones have everything, and the parent removes
  the lost phone.
- **Every phone lost:** the server only holds ciphertext, so without the key the family can't be
  recovered by anyone, us included. The safety net is the backup file, which works as today. There
  is no recovery code (decided 2026-11-16).
- **Removing a phone doesn't change the key.** A removed phone that kept a copy of the data still
  has what it already downloaded, but it can't fetch anything new, because the server drops its
  device row. Changing the key (re-encrypting everything and handing out a new key) is a later
  addition.

## One app instead of two editions

- The App Store / Play app becomes the only edition. It works offline until someone taps "Add a
  phone".
- The "DOYOURWORK Family" scheme, the `FAMILY_SYNC` flag and the plaintext tables retire after
  your family moves over (see "Moving your family over").
- **Built on the `one-app` branch** (not released):
  - **One code path.** Every install keeps the family's shared lists, and syncs only through the
    relay, only once it's linked. The old tables' client and address are gone from both apps;
    CI checks every build has the relay's address and not the old one.
  - **A phone that isn't linked** looks like today's public app: no sync status, "Everything here
    stays on this device", Erase everything, and a restored backup replaces what's there. Dares and
    "whose phone is this" only appear once a phone is linked, since they need each phone to be
    someone's.
  - **A linked phone** shows the sync status, adds a restored backup to the family, and has no
    Erase. If it's removed or the family is deleted, it keeps everything and is simply unlinked
    (there's no "sync off" state any more).
  - **"Join a family"** is on the first-run screen, for a new phone. "Loading the family" only shows
    on a phone that has just joined.
  - **Data carried over.** A phone that ran the family build keeps its shared lists. A phone that
    ran the App Store build only keeps the dares from any old shared file (a stale leftover from
    an earlier version), and its shared lists are rebuilt from its own players and chores, so a
    later "Add a phone" sends everything.
  - **iOS:** one scheme, "DOYOURWORK", with the camera prompt in every build.
  - **Android:** the `family` and `public` flavors become `github` (com.gyattchores.app, the
    debug key, what Obtainium installs) and `play` (com.doyourwork.app, the upload key).
    They differ only in id and signing; INTERNET, CAMERA and the QR scanner are in every build.
  - **The web app** (native/tools/web-engine.html, still served at doyourwork.today) no longer
    syncs; it stays as the source of truth for the game rules. The Discord bots that read the
    old tables (Card Notify, already switched off, and Points Recovery) are removed: with the
    relay, the server can't read chores, so a bot can't either.
- The public edition's selling point today is "no network code at all". After this, the line
  becomes "everything stays on your phones; if you add a second phone, it travels encrypted, and
  we can't read it."

## Moving your family over

Do it in one sitting, with every phone in the room. Until a phone has moved, it keeps syncing
through the old tables, and changes don't cross between moved and unmoved phones.

**Before**
1. Update every phone. iPhones and iPads update from TestFlight, Android phones from Obtainium.
   The version line on the home screen shows the build.
2. On each phone, check the home screen says "Synced". Joining drops anything a phone hasn't
   sent yet.
3. On the parent's phone, save a backup: Admin → Device → "Save a backup…".

**Moving**
1. On the parent's phone: Admin → Device → Phones → **Add a phone**. The first time, it encrypts
   the family and sends it (a few seconds), then shows a QR code.
2. On the next phone: Admin → Device → Phones → **Join with a code** → Scan the code, and point
   it at the QR code. A phone that was just installed has the same button on its "Loading the
   family" screen. The family loads; check the players and points look right. Whose phone it is
   stays as it was.
3. A code works once. On the parent's phone tap Done, then Add a phone again for the next phone.
4. When every phone is done, the parent's phone lists them all under Phones, and each phone's
   home screen says "Synced".

**If something goes wrong**
- If a phone shows "That code has expired or was already used", make a new code on the parent's
  phone.
- If the family on the relay looks wrong: Admin → Device → Phones → Delete this family from the
  server on the parent's phone. Then restore the backup there if needed, and start again from
  Add a phone.

**After**
1. Check every phone is on the relay: the parent's phone lists them all under Phones, and the old
   tables have stopped changing (`supabase/retire-old-tables.sql` has the two queries).
2. Merge the `one-app` branch and release it: TestFlight (scheme "DOYOURWORK") and
   `android/release.sh` (the `github` flavor). A phone that hadn't moved would be left on its own,
   with its data, until it joins with a code.
3. Make `simple_logs` and `family_state` read-only (step 1 of `supabase/retire-old-tables.sql`).
   Delete them later (step 2).

**The web app at doyourwork.today/index.html is retired** (decided 2026-11-16). The copy left at
native/tools/web-engine.html stops syncing in the one-app change. That change goes to `main`,
which deploys the website.

## Store and privacy work

- **App Store privacy label.** Under Apple's definitions, data sent off the device may count as
  collected even when it's encrypted. Check the current App Privacy guidance before choosing
  answers. At least the anonymous device id and diagnostics need declaring, and probably "Other
  User Content" (encrypted).
- **Export compliance.** The iOS build declares `ITSAppUsesNonExemptEncryption = NO`. Encrypting
  family data with AES-GCM may change that answer (and the annual self-classification report).
  Check before submitting the one-app build.
- **Google Play data-safety form.** It asks whether data is encrypted in transit and whether users
  can ask for deletion. Answer both: yes, and Admin → "Delete this family from the server".
- **Privacy policy (`app-privacy.html`).** Rewrite the "collects nothing" paragraphs for both
  platforms.
- **Children.** No names have to be real, and nothing is readable by us. Keep the advice to use
  nicknames. If the listing targets under-13s, COPPA and Apple's Kids category rules apply. This
  decision is already open in the launch kit.
- **Deletion.** Admin → "Delete this family from the server" removes the household and all its
  records (one function call), then leaves the family on this phone only.

## Build order

1. **Server.** Done 2026-11-17. Supabase project `doyourwork` (ref `omemognwvcnonnzjmcxm`,
   `https://omemognwvcnonnzjmcxm.supabase.co`, organization Liquid Sun Creative, West US) runs
   `supabase/doyourwork/001_relay.sql`, with anonymous sign-ins on and "automatically expose new
   tables" off. The apps use its publishable key. The old project keeps serving today's family
   sync until the move. Checked end to end with three anonymous devices: create a family, write,
   join with a one-time code, outsiders and signed-out callers see nothing, delete the family.
2. **Crypto and transport** in DoYourWorkCore and Kotlin, with the shared test vectors. Built
   2026-11-17:
   - **Crypto:** `RelayCrypto.swift` / `RelayCrypto.kt` hold the family keys, sealing and opening
     records, state row ids and the join code. Both match `native/fixtures/relay-crypto.json` byte
     for byte.
   - **Transport:** `RelayClient.swift` / `Relay.kt` are the relay versions of today's `LogAPI`
     and `StateAPI`, so `LogSync` and `StateSync` run unchanged on top. They also handle
     anonymous sign-in and refresh, creating a household, join codes, listing and removing phones,
     and deleting the household.
   - **Interface change:** `updateStatus` now takes the whole log, because a record is sealed as
     one piece, and `RemoteLog` carries `minutes`.
   - **Tests:** both suites test against an in-memory relay with the SQL's rules. A live test runs
     against the real project when `RELAY_LIVE=1` is set; it deletes its household but leaves its
     anonymous users behind.
   - **Still to do:** the app still uses the old tables. Keeping the session and keys on the
     device (Keychain / Keystore) and switching the apps over come with the join flow, along with
     an in-memory relay for the UI tests (like today's `-syncURL`).
3. **Join flow.** Started 2026-11-17, in the **family build only** (the iOS "DOYOURWORK Family"
   scheme and Android's family flavor, the builds the family's phones run). The App Store / Play
   build gets no network code, camera permission or server address until step 5, and CI checks
   the iOS App Store build has no server address in it.
   - **Admin → Device → Phones.** "Add a phone" puts the family on the relay the first time: a new
     household and family key, every log and piece of state uploaded again encrypted
     (`LogSync.forNewServer` / `StateSync.forNewServer`), and sync switches from the old tables to
     the relay. Then, and every time after, it shows a QR code with a 10-minute countdown.
   - **"Join with a code"** (only while a phone is still on the old tables, in Admin and on the
     "Loading the family" screen a new phone starts on) asks first, then scans.
     On success the phone drops what it had from the old tables and loads the family from the
     relay. Whose phone it is stays. Bad, used or expired codes and no connection each get a
     plain message.
   - **Phones list.** Once on the relay, the list shows "This phone" and the others, each with a
     date and a Remove button.
   - **Storage.** The keys and the anonymous sign-in live in the iOS Keychain (this device only) and,
     on Android, in preferences encrypted with an Android Keystore key.
   - **Drawing and scanning.** CoreImage draws the QR code on iOS and VisionKit's
     `DataScannerViewController` reads it. On Android, ZXing does both.
   - **Address.** The relay's address, and on Android the old tables' address too, is kept in
     family-only code, not in DoYourWorkCore or Kotlin `main`. Neither store build contains
     "supabase.co". Before this, the Play build carried the old tables' address unused.
   - **Tests.** UI tests use an in-memory relay (`MemoryRelay`, the same one the unit tests use).
     `-scanResult seeded` makes a second phone with a family in it and hands over its code, so the
     whole join is tested without a camera.
   - **Still to do:**
     - "Join a family" on the first-run setup screen. It belongs to the one-app build in step 5.
     - Trying it with two real phones and a real camera, against the real server.
     - Android debug builds only ever use the in-memory relay, so its Keystore storage is first
       exercised by a release family build. iOS uses the in-memory relay under UI tests only.
4. **Server deletion.** Built 2026-11-17, in the family build on both apps.
   - **Deleting.** Admin → Device → Phones → "Delete this family from the server…" asks first,
     then calls `delete_household`. The household and every record go, for every phone. This
     phone forgets its keys and sign-in, keeps the whole family, and turns sync off: it doesn't
     fall back to the old tables. Phones then says "Sync is off. The family is only on this
     phone.", still offering Add a phone (a new household and key) and Join with a code.
   - **Phones that are left out.** Reads from a household a phone isn't in come back empty rather
     than failing, so every relay sync pass first asks the server's `is_member`. A phone that was
     removed, or whose family was deleted, then does the same as above and says once: "This phone
     is no longer in the family's sync. Everything on it stays here." A phone left out before its
     first load goes to setup instead of waiting.
   - **Tests.**
     - Unit tests cover `isMember` after a removal and after a delete, and the live test checks
       it against the real server.
     - iOS UI tests delete a family, and drop a phone using `-seededDeletes`: the seeded other
       phone deletes the family 4 seconds after the join.
     - On Android, the delete was checked on the emulator. The view-model logic has no unit
       tests, because Robolectric is only on the classpath for store-screenshot builds.
   - **Still to do:** the Play data-safety answer that points at this button, and the same
     button in the one-app build.
5. **Move your family over**, then retire `FAMILY_SYNC`.
   - **Shipped** 2026-11-17: the relay in the family builds (TestFlight build 202611171913, Android
     0.8.0).
   - **Checked:** an iPhone and an Android phone share a family on the real relay. DoYourWorkCore's
     `testInteropWithAndroid` and the Android `RelayTest.interopWithIos` run side by side and hand
     join codes to each other through a folder: each side makes a family, the other joins it, and
     both read, approve and add logs and lists (`INTEROP_DIR=<dir>`; see the tests).
   - **Built, held:** the one-app change on the `one-app` branch (see "One app instead of two
     editions"). It ships only after every phone has moved ("Moving your family over", After).
6. **Store forms and privacy policy**, then submit.

## Decisions

Made 2026-11-16:
- **The web app is retired.**
- **No recovery code.**
- **The relay gets a new Supabase project of its own.**
- **QR scanning on Android uses ZXing**, so there's no Google Play services dependency. This is
  the default; it can be revisited.
