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
is stale, runs `swift test`, then builds the app and runs the UI tests on the
iPhone simulators the runner has (iPhone 17 Pro and iPhone 16e where
available). Screenshots from the run are uploaded as a build artifact.
