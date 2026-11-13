# GyattChores for iOS

The native SwiftUI app: a chore scoreboard for one family on one iPhone or
iPad. `GyattCore/` is the UI-free package (game rules, data model, the chore
sorter); `GyattChores/` is the app; `GyattChoresUITests/` drives the app in a
simulator.

## How it keeps a family's data

On the device, and nowhere else.

- **No accounts and no server.** The app has no network code. Players, chores,
  points and admin codes are JSON files in the app's own storage
  (`Application Support`). Deleting the app deletes them; so does **admin →
  device → erase everything**.
- **Set up on first run.** Nothing is built in: the first launch asks who's in
  charge (a name and an admin code), who's playing, and what needs doing.
- **Admins.** An admin approves chores and changes players and chores. Any
  player can be made one, each with their own code. Only a salted hash of a
  code is stored, and a forgotten code can't be recovered: the way back in is
  to delete the app. Face ID / Touch ID for the admin area is off unless an
  admin turns it on.
- **Their own chores.** A family can start from the 27 starter chores
  (`native/chores.json`) or write or dictate their own. `ChoreIntake` sorts
  free text ("do the dishes and take out the trash, feed the dog 5 minutes")
  into a list to review. It is plain word-sorting on the device; dictation is
  the keyboard's own microphone key, so the app asks for no microphone or
  speech permission.
- **One device for now.** Everyone uses the same iPhone or iPad. Sharing a
  scoreboard between a family's devices through their own iCloud is the
  planned next step.

A device that ran an earlier, synced build keeps its players and history: on
first launch of this version it asks for an admin name and code and carries
on from there, on its own.

## Build

```bash
brew install xcodegen      # once
cd ios
xcodegen                   # after adding or removing files, or editing project.yml
open GyattChores.xcodeproj
```

Pick your team under **Signing & Capabilities**, choose a device, and run.

## Tests

**Rules** — no Xcode needed, runs on macOS or Linux:

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

The rest cover what only the native app has: sorting typed or spoken text
into chores, admin codes, and loading saves from earlier versions.

**The app itself** — UI tests set a family up from a fresh install with
chores typed as a sentence, play a day (suggest a card, lock it in, check
everything off, submit, log a bonus chore, relaunch), approve chores as an
admin, add a player and make them an admin, add a chore, and erase everything.

```bash
cd ios && xcodegen
xcodebuild test -project GyattChores.xcodeproj -scheme GyattChores \
  -destination 'platform=iOS Simulator,name=iPhone 16e'
```

or **Product → Test** (⌘U) in Xcode.

The UI tests launch the app with `-uiTesting`, a debug-only switch that gives
it a separate data folder, so a test run can't touch a real scoreboard.
`-resetData` empties that folder (a fresh install), `-demoFamily` sets up a
made-up family (pat is the admin, code 2468; riley and sam play), and
`-demoData` adds a made-up month on top (with `-demoRejectedDay`, the second
player's chores for today are all rejected). `-screenshots` is for the App
Store pictures: the made-up family gets three players with names fit for a
store page. None of this exists in release builds.

## CI

`.github/workflows/ios.yml` runs on every push that touches `ios/`, `native/`
or `index.html`: it regenerates the test data and fails if the committed copy
is stale, runs `swift test`, builds the app and runs the UI tests on the
iPhone simulators the runner has (iPhone 17 Pro and iPhone 16e where
available), and archives the app in Release with the newest Xcode to catch
anything that would stop a TestFlight upload. Screenshots from the UI tests
are uploaded as a build artifact.

A separate job takes the App Store listing's screenshots
(`testAppStoreScreenshots`) on an iPhone 17 Pro Max, an iPhone 17 Pro and a
13-inch iPad Pro, checks each file is exactly a size App Store Connect
accepts, and uploads them as the `app-store-screenshots` artifact.

## App Store

[`AppStore/SUBMISSION.md`](AppStore/SUBMISSION.md) lists every field App Store
Connect asks for, with text ready to paste, and
[`AppStore/REVIEW-RISKS.md`](AppStore/REVIEW-RISKS.md) lists what is left that
App Review might object to.

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
git tag ios-v1.0 && git push origin ios-v1.0
```

The build number is a timestamp, so it never repeats. When the run finishes,
the build shows up under **TestFlight** in App Store Connect after Apple
processes it (usually a few minutes); add yourself under **Internal Testing**
and install it from the TestFlight app.

### Uploading from a Mac instead

No API key needed: this signs and uploads with the Apple ID signed in to
Xcode. Steps 1 and 2 above still apply. Before you start:

- **Xcode → Settings → Apple Accounts** must list your paid developer team,
  not only a "Personal Team". Individual memberships use the same Team ID for
  both, so check the team shows as **Developer Team**.
- [developer.apple.com/account](https://developer.apple.com/account) must not
  show a banner asking you to accept an updated license agreement. Until you
  accept it, signing and uploads fail.

Archive, with a timestamp build number:

```bash
cd ios
xcodebuild archive -project GyattChores.xcodeproj -scheme GyattChores \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/GyattChores.xcarchive -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=<team id> CURRENT_PROJECT_VERSION=$(date -u +%Y%m%d%H%M)
```

Then upload. `ios/ExportOptions.plist` is gitignored, so create it if you
don't have it:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>        <string>app-store-connect</string>
	<key>destination</key>   <string>upload</string>
	<key>teamID</key>        <string><team id></string>
	<key>signingStyle</key>  <string>automatic</string>
</dict>
</plist>
```

```bash
xcodebuild -exportArchive -archivePath build/GyattChores.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates
```

`** EXPORT SUCCEEDED **` means the upload is done. The build then appears
under **TestFlight** as *Processing* and switches to *Ready to Submit* when
Apple finishes processing it. The **Internal** testing group has automatic
distribution turned on, so its testers get every new build without you doing
anything.

For **App Privacy** in App Store Connect the answer is "Data Not Collected":
the app has no network code and nothing a family enters leaves the device.
