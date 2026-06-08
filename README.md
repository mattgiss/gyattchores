# GyattChores

A gamified family chore tracker. Each day a kid builds a **~25-minute card** of chores — picking what they want, with the app suggesting more to fill the time — then submits it for a parent to approve. Approved chores earn **XP**, a **daily streak** multiplies it, and the kid levels up like they're shipping a better version of themselves.

**Live site:** [gyattchores.com](https://gyattchores.com)

## How it works

1. **Pick a player** — tap a name (bekindhearted or megadinolava).
2. **Build today's card** — pick the chores you want up to a **25-minute budget**, then tap **fill to 25m** to top it up with smart suggestions (most-neglected chores first). Lock it in.
3. **Do the work & submit** — check off each chore as you finish; the submit button activates once they're all checked.
4. **Parent approves** — tap the **GYATTCHORES** title 5× on the player-select screen, enter the family admin code, then approve or reject each pending chore.
5. **Earn XP & level up** — approved chores add XP. Keep a daily streak and a **momentum multiplier** boosts the XP you earn (up to **2× at a 10-day streak**). Your level shows as a **version number** (v1.0 → v1.1 → …). Neglected chores **escalate** — they cost more minutes and get suggested first.

## Data & storage

GyattChores is **local-first with optional cloud sync**:

- **Always saves locally first.** Every chore log is written to the browser's `localStorage` (key: `gyattchores_logs`) instantly. Submitting never blocks on the network and **can never fail because a server is down**.
- **Syncs across devices when it can.** If the shared Supabase backend is reachable, logs sync in the background so each kid's phone and the parent's admin screen see the same data. New local entries are pushed; shared rows are pulled and merged. (Approvals self-heal if a row was lost server-side — they're re-created rather than silently dropped.)
- **Degrades gracefully.** If the backend is unreachable (e.g. a paused free-tier project), the app keeps working offline, shows an "offline" hint in the header, and syncs automatically once the backend is back.

Same-device tabs also stay in sync via the browser `storage` event.

### Enabling cross-device sync (Supabase)

Sync is optional — the app works fully without it. To turn it on:

1. In your Supabase project, open **SQL Editor** and run [`simple-logs-schema.sql`](simple-logs-schema.sql). This creates the `simple_logs` table and the row-level-security policies the app needs — **including the `update` policy**, which the approval flow depends on.
2. Set your project URL and **anon public** key near the top of the `<script>` block in `index.html` (`SUPABASE_URL` / `SUPABASE_ANON_KEY`).

If the table is missing or the project is paused, the app simply stays in local-only mode until it's available.

## Features

- **Pick-your-own daily card** — choose chores up to a 25-minute budget; the app auto-suggests more (same-area and most-neglected first) to reach 25 minutes, so every day is a full, short session.
- **Escalation** — the longer a chore goes undone, the more minutes it costs and the higher it's suggested (`!` neglected, `!!` long overdue).
- **Parent approval workflow** — chores stay pending until approved with the admin code, so XP can't be self-awarded.
- **XP, momentum & version-number levels** — approved chores earn XP; a daily streak multiplies it up to 2×; your level is shown as a version of yourself (v1.0 → v1.1 → …), and XP only ever grows.
- **Streaks** — consecutive days with an approved chore keep your momentum alive.
- **Cross-device sync** — an optional Supabase backend keeps each kid's phone and the parent's admin view in sync.
- **Build-freshness indicator** — the header shows the running build version next to the sync state: **blue** when you're on the latest deploy, **red** when a newer one is live (time to refresh).
- **Installable PWA** — add to an iOS/Android home screen; logs save locally and keep working offline.

## Chores

GyattChores ships with **27 chores** across the house. Each has a **base time in minutes** (≈3–25 min) that **escalates** the longer it goes undone, so neglected chores cost more and surface first when building the next card. The daily card targets **25 minutes** of work.

| Area | Examples |
|------|----------|
| Kitchen | load/unload dishwasher, wipe counters, sweep, empty trash |
| Bathroom | scrub toilet, wipe mirrors, sweep, empty trash |
| Laundry | start/switch/fold laundry, collect dirty laundry |
| Floors | vacuum living room, pick up clutter, wipe dining table |
| Outdoor | pick up dog poop, take out trash/recycling, water plants |
| Bedroom | make bed, pick up floor, put away clean clothes |

> Players, the chore pool, and the (hashed) admin code are defined at the top of the `<script>` block in `index.html` — the `PLAYERS`, `CHORE_POOL`, and `ADMIN_CODE_HASH` constants. The `BUILD` constant just below them is the build version shown in the app; **bump it on every deploy** so the freshness indicator stays accurate.

## Tech stack

| Layer | Technology |
|-------|------------|
| UI | React 18 (via CDN) + Babel Standalone (in-browser JSX) |
| Storage | Browser `localStorage` (source of truth) |
| Sync (optional) | Supabase (`simple_logs` table) for cross-device sharing |
| Styling | Hand-written CSS — terminal aesthetic (light, monospace, pink accent) |
| Hosting | GitHub Pages (custom domain via `CNAME`) |
| Mobile | Installable PWA (add-to-home-screen) |

There is **no build step**. The entire web app is a single self-contained `index.html`; Supabase is used only as an optional background sync layer.

## Running locally

Any static file server works:

```bash
# from the repo root
python -m http.server 8000
# then open http://localhost:8000/index.html
```

Opening `index.html` directly via `file://` also works in most browsers (the build-freshness check just stays grey, since there's nothing to compare against).

> A ready-to-use preview config lives in `.claude/launch.json` (serves the app on port 8766).

## Deploying

The site is hosted on **GitHub Pages** from `main`, with the custom domain set in `CNAME`. Pushing to `main` triggers a Pages rebuild:

```bash
# bump the BUILD constant in index.html first, then:
git add .
git commit -m "Update GyattChores"
git push origin main
```

Bumping `BUILD` on each deploy is what lets the in-app indicator tell a freshly-loaded copy from a stale cached one.

## Native iOS app

The [`GyattChoresApp/`](GyattChoresApp/) directory holds Swift sources for an earlier, **tap-to-log** version of the design (iPhone + Apple Watch), including a Shortcuts/App Intent for logging a chore by voice. It predates the current daily-card / XP model in the web app and isn't kept in sync with it.

> Note: the Xcode project file is not committed — the directory contains only the Swift sources (`Models/`, `Views/`, `Services/`, `Intents/`). To build, create a new Xcode app target and add these sources.

## Project structure

```
gyattchores/
├── index.html              # The entire web app (self-contained SPA)
├── simple-logs-schema.sql  # Supabase table + RLS for optional cross-device sync
├── CNAME                   # Custom domain for GitHub Pages
├── apple-touch-icon.png    # iOS home-screen icon
├── gyattchores-logo*.svg   # Logo variants
├── about.html / ebook.html / development-story.html   # Public about, guide, and story pages
├── SECURITY.md             # Security model & disclosure
├── GyattChoresApp/         # Earlier native SwiftUI app (iPhone + Watch)
└── docs/governance/        # Lightweight service-management docs
```

## Security

All chore data lives in the browser's `localStorage` on each device; the optional Supabase sync stores only non-sensitive chore logs, written with the project's public anon key under permissive row-level-security policies (it's a private family app). The admin code is a lightweight, client-side "are you a grown-up?" gate — stored as a hash rather than plaintext, but **not** a real security boundary. See [SECURITY.md](SECURITY.md).

## Governance & operations

This repository is run under a lightweight, ITIL 4-aligned **Service Management System** in [`docs/governance/`](docs/governance/README.md) — covering change control, incident & problem management, monitoring, security, and a continual-improvement backlog. New contributors should start with [`CONTRIBUTING.md`](CONTRIBUTING.md).

- **How changes reach production:** [Change Enablement](docs/governance/change-enablement.md)
- **When something breaks:** [Incident & Problem Management](docs/governance/incident-and-problem-management.md)
- **The Discord alerting:** [Monitoring & Event Management](docs/governance/monitoring-and-event-management.md)
- **Current posture & gaps:** [Governance Audit](docs/governance/governance-audit.md) · [Improvement backlog](docs/governance/continual-improvement.md)

## History

This started as a Supabase-backed tap-to-log app, was rewritten into a simple offline-first localStorage app, became **local-first with optional Supabase sync**, and most recently turned into a daily-card game: kids build a 25-minute card, earn XP with streak-based momentum, and level up by version number. That journey is preserved in [`development-narrative.md`](development-narrative.md) and the [`ebook`](ebook.md).

## License

MIT License — feel free to fork and adapt for your family.

---

**Created with love for bekindhearted and megadinolava** · *Built by Matthew Gissentanna*
