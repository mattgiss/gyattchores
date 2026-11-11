# GyattChores for iOS

The native SwiftUI app. `GyattCore/` is the UI-free package (game rules, data
model, sync); `GyattChores/` is the app; `GyattChoresUITests/` drives the app
in a simulator.

## Build

```bash
brew install xcodegen      # once
cd ios
xcodegen                   # after adding or removing files, or editing project.yml
open GyattChores.xcodeproj
```

Pick your team under **Signing & Capabilities**, choose a device, and run.

## Tests

**Rules and sync** — no Xcode needed, runs on macOS or Linux:

```bash
cd ios/GyattCore && swift test
```

These check the Swift engine against answers produced by the web app's own
engine, lifted out of `index.html`:

- `android/app/src/test/resources/golden.json` — one large random history
  (`TZ=UTC node native/tools/golden.js index.html android/app/src/test/resources/golden.json`)
- `native/fixtures/engine-scenarios.json` — small named cases: sync duplicates,
  midnight boundaries, minutes fallbacks, escalation tiers, the admin-code hash
  (`node native/tools/scenarios.mjs`)

When a game rule changes in `index.html`, regenerate both and commit them; a
failing test then names the rule a native port still has wrong.

**The app itself** — UI tests play a day in a simulator: suggest a card, lock
it in, check everything off, submit, log a bonus chore, relaunch, and try a
wrong parent code.

```bash
cd ios && xcodegen
xcodebuild test -project GyattChores.xcodeproj -scheme GyattChores \
  -destination 'platform=iOS Simulator,name=iPhone 16e'
```

or **Product → Test** (⌘U) in Xcode.

The UI tests launch the app with `-uiTesting`, a debug-only switch that gives
it a separate data folder and turns sync off, so a test run can't read or
write the family's real chores. `-resetData` empties that folder and
`-demoData` fills it with a made-up month. None of this exists in release
builds.

## CI

`.github/workflows/ios.yml` runs on every push that touches `ios/`, `native/`
or `index.html`: it regenerates the test data and fails if the committed copy
is stale, runs `swift test`, builds the app and runs the UI tests on the
iPhone simulators the runner has (iPhone 17 Pro and iPhone 16e where
available), and archives the app in Release with the newest Xcode to catch
anything that would stop a TestFlight upload. Screenshots from the UI tests
are uploaded as a build artifact.

## TestFlight

`.github/workflows/ios-testflight.yml` archives the app on a GitHub Mac runner
and uploads it to TestFlight, so a release doesn't need a local Mac.

One-time setup:

1. **Register the bundle ID.** [Certificates, IDs & Profiles → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
   → **+** → App IDs → App → bundle ID `com.gyattchores.app` (explicit).
2. **Create the app record.** [App Store Connect](https://appstoreconnect.apple.com/apps)
   → **Apps → + → New App** → iOS, pick that bundle ID, any name and SKU.
   An upload fails until this exists.
3. **Create an API key.** App Store Connect → **Users and Access →
   Integrations → App Store Connect API → Team Keys → +**, with **Admin**
   access (Xcode's automatic signing needs it to create the distribution
   certificate). Note the **Key ID** and the **Issuer ID** shown on that page,
   and download the `.p8` file — it can only be downloaded once.
4. **Add four repository secrets** on GitHub under **Settings → Secrets and
   variables → Actions**:

   | Secret | Value |
   |---|---|
   | `APP_STORE_CONNECT_KEY_ID` | the Key ID |
   | `APP_STORE_CONNECT_ISSUER_ID` | the Issuer ID |
   | `APP_STORE_CONNECT_KEY_P8` | the whole contents of the `.p8` file |
   | `APPLE_TEAM_ID` | your Team ID, from [Membership details](https://developer.apple.com/account#MembershipDetailsCard) |

To release, push a tag — the part after `ios-v` becomes the app version:

```bash
git tag ios-v0.1.0 && git push origin ios-v0.1.0
```

The build number is a timestamp, so it never repeats. When the run finishes,
the build shows up under **TestFlight** in App Store Connect after Apple
processes it (usually a few minutes); add yourself under **Internal Testing**
and install it from the TestFlight app.

Before inviting external testers or submitting to the App Store, fill in
**App Privacy** in App Store Connect: with sync on, the app sends chore logs
and player names to the family's Supabase project.
