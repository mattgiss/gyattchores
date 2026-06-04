# GyattChores

A simple, gamified family chore tracker. Kids tap to log the chores they've done, a parent approves them with a PIN, and points roll up into a friendly weekly competition.

**Live site:** [gyattchores.com](https://gyattchores.com)

## How it works

1. **Pick a player** — tap a player card (e.g. 🦁 BeKindHearted or 🦖 MegoDinoLava).
2. **Log a chore** — tap any chore tile. It's recorded as **pending** and earns no points yet.
3. **Parent approves** — open the ✓ menu, enter the admin PIN, and approve (or reject) pending chores. Approving awards the chore's points.
4. **Compete** — approved points count toward **Today** and **This Week** totals. The player leading the week gets a 👑.

Points reset naturally each week (the "This Week" total only counts approved chores logged since Monday).

## Data & storage

GyattChores is **offline-first**. All chore logs are stored in the browser's `localStorage` on the device (key: `gyattchores_logs`) — there is **no backend and no network call to save a chore**, so logging always works, even offline. Tabs/windows on the same device stay in sync via the browser `storage` event.

> Trade-off: because data is local to each device, there is no cross-device sync. Each device keeps its own history. (A previous version synced via Supabase; that backend was retired — see [History](#history).)

## Features

- **Tap-to-log chores** — 17 chores, each worth a set number of points.
- **Parent approval workflow** — chores stay pending until approved with the admin PIN, so points can't be self-awarded.
- **Approve all** — clear the whole pending queue in one tap.
- **Today / This Week totals** — per-player point tallies.
- **Weekly leader** — the top scorer this week is marked with a crown.
- **Installable PWA** — add to an iOS/Android home screen; runs fully offline.

## Chores & points

| Chore | Points | Chore | Points |
|-------|-------:|-------|-------:|
| 💩 Pick up Poop | 500 | 🌱 Water Plants | 250 |
| 🧹 Vacuum | 500 | 🐕 Feed Alfred | 250 |
| 📬 Get Mail | 250 | 🐱 Feed Chevy | 250 |
| 🗑️ Trash | 375 | 🧹 Sweep | 375 |
| 🍽️ Dishes | 500 | 🧽 Wipe Counters | 375 |
| 🫧 Load Dishwasher | 625 | 👕 Fold Laundry | 500 |
| ✨ Unload Dishwasher | 500 | 🍴 Set Table | 250 |
| 🛏️ Clean Room | 750 | 🧹 Clear Table | 250 |
| 🚿 Clean Bathroom | 750 | | |

> Players, chores, point values, and the admin PIN are defined at the top of the `<script>` block in `index.html` (the `PLAYERS`, `CHORES`, and `ADMIN_CODE` constants). Edit them there to customize.

## Tech stack

| Layer | Technology |
|-------|------------|
| UI | React 18 (via CDN) + Babel Standalone (in-browser JSX) |
| Storage | Browser `localStorage` — no backend, no database |
| Styling | Hand-written CSS (Material-inspired dark theme) |
| Hosting | GitHub Pages (custom domain via `CNAME`) |
| Mobile | PWA (add-to-home-screen) + a native SwiftUI app (see below) |

There is **no build step and no server**. The entire web app is a single self-contained `index.html`.

## Running locally

Any static file server works:

```bash
# from the repo root
python -m http.server 8000
# then open http://localhost:8000/index.html
```

Opening `index.html` directly via `file://` also works in most browsers.

> A ready-to-use preview config lives in `.claude/launch.json` (serves the app on port 8766).

## Deploying

The site is hosted on **GitHub Pages** from `main`, with the custom domain set in `CNAME`. Pushing to `main` triggers a Pages rebuild:

```bash
git add .
git commit -m "Update GyattChores"
git push origin main
```

## Native iOS app

A native SwiftUI app (iPhone + Apple Watch) lives in [`GyattChoresApp/`](GyattChoresApp/). It mirrors the web app's design and uses the same local-storage model (`UserDefaults`, key `gyattchores_logs`), including a Shortcuts/App Intent for logging a chore by voice.

> Note: the Xcode project file is not committed — the directory contains the Swift sources (`Models/`, `Views/`, `Services/`, `Intents/`). To build, create a new Xcode app target and add these sources.

## Project structure

```
gyattchores/
├── index.html              # The entire web app (self-contained SPA)
├── CNAME                   # Custom domain for GitHub Pages
├── apple-touch-icon.png    # iOS home-screen icon
├── gyattchores-logo*.svg   # Logo variants
├── SECURITY.md             # Security model & disclosure
├── GyattChoresApp/         # Native SwiftUI app (iPhone + Watch)
├── development-narrative.md / development-story.html   # The build journey
├── ebook.md / ebook.html   # Long-form write-up of the project
└── leveling-progression-examples.md   # Design notes for a future leveling system
```

## Security

GyattChores has no backend and stores nothing on a server — all data lives in the browser's `localStorage` on each device. The admin PIN is a lightweight, client-side "are you a grown-up?" gate, **not** a real security boundary. See [SECURITY.md](SECURITY.md).

## History

This started as a Supabase-backed app, was rewritten into a simple offline-first localStorage app, briefly reconnected to Supabase for cross-device sync, and then returned to offline-first localStorage after that backend was retired. That journey is preserved in [`development-narrative.md`](development-narrative.md) and the [`ebook`](ebook.md).

## License

MIT License — feel free to fork and adapt for your family.

---

**Created with love for BeKindHearted and MegoDinoLava** · *Built by Matthew Gissentanna*
