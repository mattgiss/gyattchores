# Families on more than one phone: encrypted relay, joined by QR code

Status: design, nothing built. Decided 2026-11-16: an encrypted relay with a QR-code join. Not
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
  - Every record is encrypted on the phone with AES-256-GCM under the family key, with a fresh
    random 12-byte nonce.
  - The associated data is household id ‖ record kind ‖ row id, so the server can't swap rows
    between families or kinds without decryption failing.
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
GyattCore and the Kotlin `sync` package.

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
- The "GyattChores Family" scheme, the `FAMILY_SYNC` flag and the plaintext tables retire after
  your family moves over (see "Moving your family over").
- The public edition's selling point today is "no network code at all". After this, the line
  becomes "everything stays on your phones; if you add a second phone, it travels encrypted, and
  we can't read it."

## Moving your family over

1. Ship the relay in a TestFlight / Obtainium build.
2. On your phone (it already has the whole family through today's sync), tap Admin → "Add a
   phone". The family uploads encrypted under a new household.
3. Each other phone updates and scans the code. It keeps its own settings (whose phone it is,
   theme) and swaps its data source.
4. Once every phone is moved, the old sync is switched off. `simple_logs` and `family_state` are
   kept read-only for a while, then deleted.

**The web app at gyattchores.com/index.html is retired** (decided 2026-11-16). It reads and
writes `simple_logs`, so it keeps working until step 4, then goes away in the same change that
switches the old sync off. That change goes to `main`, which deploys the website.

## Store and privacy work

- **App Store privacy label.** Under Apple's definitions, data sent off the device may count as
  collected even when it's encrypted. Check the current App Privacy guidance before choosing
  answers. At least the anonymous device id and diagnostics need declaring, and probably "Other
  User Content" (encrypted).
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
2. **Crypto and transport** in GyattCore and Kotlin, with the shared test vectors and an encrypted
   in-memory test server for the UI tests (like today's `-syncURL`).
3. **Join flow.** QR display (CoreImage / ZXing core for drawing), scanning (VisionKit
   `DataScannerViewController` / CameraX + ML Kit, or ZXing), camera permission text,
   Admin → Phones.
4. **Server deletion** (Admin → "Delete this family from the server").
5. **Move your family over**, then retire `FAMILY_SYNC`.
6. **Store forms and privacy policy**, then submit.

## Decisions

Made 2026-11-16:
- **The web app is retired.**
- **No recovery code.**
- **The relay gets a new Supabase project of its own.**
- **QR scanning on Android uses ZXing**, so there's no Google Play services dependency. This is
  the default; it can be revisited.
