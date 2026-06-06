# GyattChores — App of the Year 2027 Roadmap

| | |
|---|---|
| **Vision** | The chore app that actually makes kids want to do chores. |
| **Target** | Apple App of the Year — Family category — 2027 |
| **Submission window** | App Store nominations close ~October 2027 |
| **Owner** | Matthew Gissentanna |
| **Last updated** | 2026-06-06 |

Apple's App of the Year criteria (inferred from past winners): **exceptional design**, **meaningful use of platform features** (Siri, Widgets, Live Activities, Dynamic Island), **broad accessibility**, **delightful UX**, and a **story that resonates**. GyattChores already has the story — a dad building something real for his kids. The roadmap builds the product around it.

---

## Phase 0 — Go Live (Now → Q3 2026)

**Goal:** Ship a production-stable v1.0 to the App Store. Nothing else matters until this is done.

### Blockers (must fix before App Store submission)

| Item | Why it blocks | Action |
|---|---|---|
| Branch protection off | Any push can break production | Enable CA-01 |
| No CI quality gate | Regressions reach live silently | Build CI workflow (CA-04) |
| Xcode project not committed | Can't build from the repo | Add `.xcodeproj` or use SPM |
| No `Info.plist` in repo | App Store build impossible | Add with correct bundle ID, version, required keys |
| No `PrivacyInfo.xcprivacy` | Required by Apple since iOS 17.4 — submission rejected without it | Add privacy manifest |
| No App Store screenshots | Required for submission | Produce 6.7" and 5.5" sets |
| No privacy policy URL | Required for apps involving children's data | Publish at gyattchores.com/privacy |
| Admin PIN in client source | Not a security boundary — document clearly for App Review | Already in SECURITY.md ✅ |
| `ADMIN_CODE` hardcoded | Must not be in source for production | Move to a setting, or at minimum document in App Review notes |

### v1.0 release checklist

```
App Store Connect
- [ ] App ID / bundle ID registered (e.g. com.gissentanna.gyattchores)
- [ ] App record created in App Store Connect
- [ ] TestFlight internal build uploaded
- [ ] Privacy policy published and linked
- [ ] Age rating completed (4+)
- [ ] Keywords, description, and subtitle written
- [ ] Screenshots: iPhone 6.7" (required), iPad 12.9" (recommended)
- [ ] App icon 1024×1024 set in App Store Connect
- [ ] App Review notes explaining the PIN and family-use model

App quality
- [ ] No crashes on cold launch (verified via TestFlight)
- [ ] Offline mode works end-to-end (log chore → approve → persist → reload)
- [ ] Dynamic Type supported (text scales with system font size)
- [ ] VoiceOver: all interactive elements have accessibility labels
- [ ] Dark mode ✅ (already done)
- [ ] Haptics ✅ (already done)

iOS integration
- [ ] Home screen widget (This Week points per player)
- [ ] Siri Shortcuts ✅ (App Intent for LogChoreIntent already exists)
- [ ] App Icon badge for pending approvals
```

---

## Phase 1 — Delight (Q3 2026 → Q1 2027)

**Goal:** Make the app so good that the kids ask to use it. Add the features that reviewers notice.

### 1.1 Real-time features (Live Activities + Dynamic Island)

- **Pending approval Live Activity** — when a chore is logged, a Live Activity shows on the parent's Lock Screen: "🦁 bekindhearted logged Dishes · Waiting for approval." Parent approves from Lock Screen.
- **Dynamic Island** — show the current week leader's score as a compact live update.

### 1.2 Widgets

- **Small:** weekly leader + crown.
- **Medium:** per-player This Week bars (like a mini leaderboard).
- **Large:** full leaderboard + pending count + quick-log buttons.
- **Lock Screen widget:** pending approval count badge.

### 1.3 Push notifications

- Parent gets a notification when a chore is logged (requires APNs setup).
- Kids get a congratulations notification when approved (+X pts!).
- Daily reminder (opt-in, configurable) — "You haven't logged any chores today."

### 1.4 Streaks & levelling

The `leveling-progression-examples.md` in the repo already designed this. Implement it:

- **Daily streak** — consecutive days with at least one approved chore.
- **Level system** — Bronze → Silver → Gold → Platinum → Legendary.
- **Badges** — "Clean Machine" (7-day streak), "Point King" (first to 10,000 all-time), "Consistent" (approved chore every day for a month).

### 1.5 Family sharing / iCloud sync

Replace or supplement Supabase with **CloudKit (iCloud)** for native Apple-ecosystem sync:
- No account creation required (uses existing Apple ID).
- Works in China (Supabase doesn't always).
- Positions the app as a true Apple-native experience — critical for App of the Year consideration.
- Keep Supabase as an optional non-Apple fallback.

### 1.6 Chore scheduling

- Recurring chores (daily, weekly) with reminders.
- "Chore of the Day" spotlight on the home screen.
- Calendar view — tap any past day to see what was done.

---

## Phase 2 — Polish (Q1 2027 → Q3 2027)

**Goal:** Remove every rough edge. App of the Year apps feel hand-crafted.

### 2.1 Design system

- Move from inline JSX styles to a proper design token system (web) / ViewModifier system (iOS).
- Commission or refine the app icon for a premium feel.
- Micro-animations: chore completion particle burst, approval confetti, streak flames.
- Sound design: subtle, satisfying tap sounds (respect system silence switch).

### 2.2 Apple Watch app (already exists — polish it)

- Complication showing today's points.
- Quick-log from Watch face.
- Taptic feedback pattern for approval.
- Watch-native approval workflow (parent approves from watch).

### 2.3 Accessibility (App Review and WCAG 2.1 AA)

- Full VoiceOver navigation audit.
- Reduce Motion support (disable particle effects).
- High contrast mode.
- Minimum 44×44pt tap targets (audit all buttons).

### 2.4 Localization

- English (US) ✅
- Spanish (es) — large US family market
- French (fr-CA)
- Emoji-heavy UI already lowers translation burden.

### 2.5 Performance

- Cold launch < 400ms on iPhone 12 or newer.
- Web app: replace Babel standalone + CDN React with a proper build (Vite).
- No janky scrolling — profile with Instruments.

---

## Phase 3 — Nomination (Q3 2027)

**Goal:** Be in the conversation for App of the Year.

### What Apple looks for (based on past winners)

1. **Meaningful real-world impact** — GyattChores teaches responsibility and makes family life easier. That's the story.
2. **Exceptional platform integration** — Live Activities, Dynamic Island, Widgets, Siri, Watch, iCloud. Hit all of them.
3. **Design quality** — nominated apps feel like they could only exist on Apple hardware.
4. **Momentum** — strong ratings (target 4.8+), regular updates, active App Store presence.
5. **The human story** — a dad building something real for his kids. This is the PR angle. Write a press kit.

### Nomination prep

- [ ] Reach out to Apple Developer Relations (review program) — submit your app for editorial consideration via appstoreconnect.apple.com → App Analytics → Request Feature.
- [ ] Write a press kit: the story of building the app, who uses it, what changed in the family.
- [ ] Target App Store editorial featuring (Today tab) in September/October 2027.
- [ ] Ratings campaign: ask the family (and testers) to leave a review at a natural "win" moment (first approval).
- [ ] Submit to Apple Design Awards separately — it's a parallel track.

---

## KPIs for the roadmap

| Milestone | KPI | Target |
|---|---|---|
| App Store launch | Crash-free sessions | ≥ 99.5% |
| Phase 1 complete | Daily active sessions | Consistent daily family use |
| Phase 2 complete | App Store rating | ≥ 4.8 (50+ ratings) |
| Phase 3 | Editorial feature | At least one App Store Today feature |
| Award | Apple App of the Year | 🏆 2027 |

---

## Immediate next actions (this week)

1. **Run `/prod-check`** to get the current production score.
2. **Add the Xcode project** to the repo — nothing else in Phase 0 can happen without a buildable project.
3. **Enable branch protection on `main`** (Settings → Branches in GitHub). 5 minutes.
4. **Register the bundle ID** in Apple Developer portal.
5. **Run `scripts/supabase-audit.sql`** in the Supabase dashboard and share results — data health is the foundation of everything.
