# Handover from the cloud thread, 18 November 2026

The cloud thread that did the rename, the icon, the scoreboard tiles and the website is closing.
This is what it leaves behind. Delete this file once everything below is done or moved elsewhere.

## Already finished (nothing to redo)

| What | Where |
|---|---|
| The app is called DOYOURWORK, with the "dyw" icon | `native-android`, commits `03cddb0`, `79a44f9`, `3f983d9` |
| Scoreboard tiles and sixteen player characters, both apps | `native-android`, commits `ad556b8`, `574c604` |
| Store listings, screenshots, banner, checklists | `launch/README.md` and the two guides it links to |
| gyattchores.com is the page about the app, with support and privacy pages | `main`, pull request #73, published 17 November |

All of it passed the iPhone checks before landing (run 43998789343: five jobs green) and both
Android editions' tests (99 each).

## Left to do, in order

1. **Get the new build onto phones.** No release has the new name, icon or tiles yet: the newest
   Android release is v0.7.1 and the newest TestFlight build is from 16 November, both from before
   they landed. This needs the Mac.
   - Android: `android/release.sh` with a new version, then Obtainium on the Fold 7 and the Pixel.
   - iPhone: a new TestFlight build.
2. **Check one thing on the Fold 7 and the Pixel first.** The cloud thread sent Matt a test copy of
   the device-only edition (`com.gyattchores.app.public`), signed with that machine's key, not the
   Mac's. If he installed it, a Mac-built copy of the device-only edition will be refused until the
   test copy is uninstalled. The family edition is a different app and is not affected.
3. **Try the character picker between two real family phones.** A pick is shared as a
   `character|<id>` row beside `display|<id>`. That is covered by unit tests on both platforms but
   has never been run between two phones. The same goes for the encrypted relay now being
   designed: a player's `character` has to travel with their name.
4. **Look at the live website once by eye.** The cloud machine could not load gyattchores.com, so
   the publish was confirmed only by GitHub's deploy succeeding.
5. **Fix a small Android bug.** On a 360dp-wide phone, the list shown after "Sort into chores" in
   Admin cuts long chore names short ("tidy the playr…").
6. **Decide what to do with three old pages still on the site:** `privacy.html`,
   `privacy/index.html` and `recover.html`. They belong to the earlier family test versions and
   still say GyattChores. The new privacy page links to `privacy.html` on purpose.

## Waiting on Matt

- Whether "DOYOURWORK" is free as an App Store name (fallback: "DOYOURWORK: Chore Scoreboard").
- A domain to match the name. The site and both store listings point at gyattchores.com today.
- The Android package name for the Play Store. `com.gyattchores.app.public` becomes permanent
  with the first upload.
- One version number for both apps. iPhone says 1.0, Android says 0.7.1.
- Starting the Play closed test (12 testers for 14 days, for a new personal account), the Play
  target-audience answer, and the review contact details for both stores.
- Optional: the four App Store Connect secrets on GitHub, so TestFlight builds can go up without
  the Mac (`ios/README.md`, "TestFlight"). The one attempt so far stopped for lack of them.
- Optional: two Discord automations are still enabled but only run when started by hand
  (Customer Announcement, Points Recovery Audit). The scheduled ones are already off.

## Tools that used to exist only in that thread

- `tools/brand/`: redraws the icon, the Play banner and the website's pictures. See its README.
- `tools/characters/`: the character drawings and the script that writes them out for both apps.
  To add a character, draw it in `art.mjs`, run `build.mjs`, and raise the count in
  `CharactersTest.kt` and `CharacterTests.swift`.
- `android/PlayStore/take-screenshots.sh`: retakes the Play screenshots without a phone.

## Branches that can go

Fully merged: `claude/rename-doyourwork`, `claude/player-tiles`, `claude/launch-kit`,
`claude/marketing-site`, and this one (`claude/handoff`) once it is merged. Older `claude/…`
branches from before 15 November were merged at the time, but check each before deleting.
