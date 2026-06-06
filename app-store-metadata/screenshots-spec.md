# App Store Screenshots Specification

Required before App Store submission. Produce these in Simulator or on real hardware.

## Required sizes (Apple mandate)

| Device class | Resolution | Required? |
|---|---|---|
| iPhone 6.7" (iPhone 15 Pro Max) | 1290 × 2796 px | **Required** |
| iPhone 6.5" (iPhone 14 Plus / 13 Pro Max) | 1284 × 2778 px | Recommended (reuse 6.7") |
| iPhone 5.5" (iPhone 8 Plus) | 1242 × 2208 px | Required if targeting iOS 12+ |
| iPad Pro 12.9" (6th gen) | 2048 × 2732 px | Required if supporting iPad |
| iPad Pro 12.9" (2nd gen) | 2048 × 2732 px | Same as above |

> Tip: Use the 6.7" screenshots for 6.5" — Apple accepts them.

## Screenshot sequence (6 shots recommended)

### Shot 1 — The hook
**File:** `01-home-with-players.png`
**Caption overlay:** "Make chores a game 🎮"
**What to show:** Home screen with both player cards visible, weekly points on each, crown on the leader. Chore grid partially visible below.
**State:** BeKindHearted selected (cyan border), 750 pts this week, crown. Stats pills showing Today + This Week + This Month + Total.

### Shot 2 — Logging a chore
**File:** `02-log-chore.png`
**Caption overlay:** "Tap. Done. Points earned."
**What to show:** The success overlay — large emoji (🍽️ Dishes), "Logged!" text, "+500 pts" in cyan. Blur behind.
**State:** Immediately after tapping a chore.

### Shot 3 — Stats with trends
**File:** `03-stats-trend.png`
**Caption overlay:** "See who's ahead of last month ↑"
**What to show:** Close-up of the 4 stat pills (Today, This Week, This Month, Total Earned) with green ↑ trend arrows.
**State:** Player has real activity; trend arrows visible.

### Shot 4 — Parent approval
**File:** `04-admin-approve.png`
**Caption overlay:** "Parents stay in control 🔐"
**What to show:** Admin panel unlocked, showing 2-3 pending chores with approve/reject buttons.
**State:** Several pending items queued.

### Shot 5 — History tab
**File:** `05-history.png`
**Caption overlay:** "Full history, always on device"
**What to show:** History tab with summary stats (Total Earned, Chores Done, Pending, Rejected) and the log list below.
**State:** Rich history with a mix of approved, rejected entries.

### Shot 6 — Apple Watch
**File:** `06-watch.png`
**Caption overlay:** "Log from your wrist ⌚"
**What to show:** Watch app chore list, or the success state on Watch.
**State:** Chore tapped, "+250 pts" showing.

---

## Production process

1. **Simulator:** Xcode → Open Simulator → Choose iPhone 15 Pro Max → File → Take Screenshot
2. **Framing:** Use [Apple's screenshot frames](https://developer.apple.com/design/resources/) or Rottenwood/Previewed for device frames + caption overlays
3. **Caption font:** SF Pro Display or Inter, bold, white or light on dark overlay
4. **Brand colours:** Cyan `#00E5FF` / Purple `#A855F7` for accents; dark `#0A0A0F` background

## Do NOT include in screenshots
- The PIN entry screen (shows admin code)
- Any error states or the "Offline" banner
- Any in-progress animations

## Localized screenshots
For v1.0: English only.
Future: Spanish (es-MX) — same shots, translated caption overlays.
