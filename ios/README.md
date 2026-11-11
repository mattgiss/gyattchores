# GyattChores for iOS

A native SwiftUI rebuild of the web app, for iPhone (iOS 17+). Same game, same
rules: build a 25-minute card, check it off, submit it, a parent approves, XP
and streaks follow.

This replaces the older tap-to-log sources in [`../GyattChoresApp/`](../GyattChoresApp/),
which predate the daily-card game and aren't used by this project.

## What's here

```
ios/
├── project.yml        XcodeGen spec — the .xcodeproj is generated from this
├── GyattCore/         Swift package: the game rules, no UI
│   ├── Sources/       models, engine, game moves, save file
│   └── Tests/         34 tests, incl. answers generated from the web engine
└── GyattChores/       the SwiftUI app
    ├── GameStore.swift    observable wrapper around GyattCore, saves on every move
    ├── Theme.swift        monospace + #F23861, light and dark
    └── Views/             home + daily log, picker, card, parent controls
```

The web app's `index.html` stays the source of truth for game rules.
`tools/native/generate-engine-fixtures.mjs` runs the web engine over a set of
scenarios and writes its answers to `GyattCore/Tests/…/Fixtures`; the Swift
tests replay them. If a rule changes on the web, CI says so.

## Build and run on your iPhone

One-time setup on the Mac:

```bash
brew install xcodegen
```

Then:

```bash
cd ios
xcodegen generate
open GyattChores.xcodeproj
```

In Xcode:

1. Select the **GyattChores** target → **Signing & Capabilities** → pick your
   **Team**. (To make this stick across `xcodegen generate`, put your Team ID
   in `DEVELOPMENT_TEAM` in `project.yml`.)
2. Choose your iPhone in the run-destination menu (a wirelessly paired phone
   shows up there once it's on the same network) and press **Run** (⌘R).
3. First run on a device: on the phone, trust the developer certificate under
   **Settings → General → VPN & Device Management** if iOS asks.

Run the rule tests any time, no Xcode needed:

```bash
cd ios/GyattCore && swift test
```

## Ship to TestFlight

1. **Create the app record** (once): [App Store Connect](https://appstoreconnect.apple.com)
   → **Apps → +  → New App** → iOS, bundle ID `com.gissentanna.gyattchores`,
   any SKU. If the bundle ID isn't listed, running the app on a device from
   Xcode with automatic signing registers it.
2. In Xcode set the destination to **Any iOS Device (arm64)**, then
   **Product → Archive**.
3. In the Organizer window that opens: **Distribute App → TestFlight & App
   Store → Distribute**.
4. Wait for the build to finish processing in App Store Connect → **TestFlight**
   (usually a few minutes), add yourself under **Internal Testing**, and install
   it from the TestFlight app on the phone.

For every later upload, bump `CURRENT_PROJECT_VERSION` in `project.yml` and
re-run `xcodegen generate` — App Store Connect rejects a repeated build number.

## What works today, and what doesn't yet

Works: player select, the 25-minute daily log, building a card (with fill-to-25
suggestions and escalation), check-off and submit, bonus round, parent
approve/reject behind the family code (tap the **GYATTCHORES** title five
times), XP / version levels / streak momentum. Everything is saved on the
device.

Not yet:

- **Cross-device sync.** Data stays on the phone it was entered on, so the
  parent approves on the kid's phone for now. The log format matches the web
  app's `simple_logs` table, so sync can be added without a data migration.
- **iPad layout** and landscape. iPhone, portrait only.
- **Notifications** (the web app's Discord pings have no equivalent here).

## Changing things

- **Players and chores** live in `GyattCore/Sources/GyattCore/ChoreCatalog.swift`.
  They must match `PLAYERS` / `CHORE_POOL` in `index.html` — a test fails if
  they don't. To change them, change the web app first, regenerate the
  fixtures (`node tools/native/generate-engine-fixtures.mjs`), then update the
  catalog.
- **A game rule** — same order: `index.html`, regenerate fixtures, then make
  `Engine.swift` pass.
- **The parent code** is checked against a hash in `AdminGate.swift`; it's the
  same code as the web app.
