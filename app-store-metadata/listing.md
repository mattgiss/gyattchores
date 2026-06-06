# App Store Listing — GyattChores

Paste these directly into App Store Connect. Fields are character-counted to Apple's limits.

---

## Name (30 chars max)
```
GyattChores
```
(11 chars ✅)

## Subtitle (30 chars max)
```
Family Chore Tracker & Points
```
(29 chars ✅)

## Promotional Text (170 chars max)
*Shown at the top of the listing; can be updated without a new build.*
```
Make chores fun. Kids tap to log what they've done, parents approve with a PIN, and points roll into a weekly family competition. Who'll wear the crown this week?
```
(162 chars ✅)

## Description (4000 chars max)

```
GyattChores turns household chores into a game your kids actually want to play.

HOW IT WORKS
1. Pick your player — each family member has their own card with a weekly point total and a shot at the crown 👑
2. Tap a chore — it's instantly logged as pending. The list covers everything from Clean Room (750 pts) to Get Mail (250 pts).
3. Parent approves — open the Admin screen, enter your PIN, and approve or reject pending chores. Approving awards the points.
4. Compete — approved points stack into Today and This Week totals. The week's leader earns the crown. Points reset naturally each Monday.

DESIGNED FOR REAL FAMILIES
• No accounts or sign-ups — just tap and go
• Works offline, always. Every chore is saved instantly to the device; the app can never fail to log because a server is down.
• Optional cross-device sync keeps everyone's phone in step when you need it
• Admin PIN keeps kids from approving their own chores (it's a family lock, not Fort Knox)
• Approve All button clears the weekend backlog in one tap

STATS THAT MOTIVATE
Track Today, This Week, This Month, and Total Earned for each player — with trending arrows showing whether they're ahead of or behind last month's pace. Data stays on your device; nothing is shared with advertisers or analytics platforms.

NATIVE APPLE EXPERIENCE
• Ask Siri to "Log dishes for BeKindHearted" using Shortcuts
• Apple Watch companion app for quick chore logging from the wrist
• Dark mode, haptic feedback, and a clean design built around the way families actually use their phones

CUSTOMISABLE
Players, chores, point values, and the admin PIN are all editable. Rename everything to match your household — your dog, your chores, your rules.

PRIVACY FIRST
GyattChores collects no personal data, has no advertising, and includes no analytics. Your family's chore history stays on your devices. See our full privacy policy at gyattchores.com/privacy.

---
Built by a dad for his kids. BeKindHearted and MegoDinoLava helped test every version.
```
(1,618 chars ✅ — well under 4000 limit)

---

## Keywords (100 chars max, comma-separated)
*Choose for discoverability — no spaces after commas to save chars.*
```
chores,kids,family,chore chart,responsibility,points,rewards,allowance,household,tasks,parenting
```
(96 chars ✅)

## Support URL
```
https://gyattchores.com
```

## Privacy Policy URL (required)
```
https://gyattchores.com/privacy
```

## Marketing URL (optional)
```
https://gyattchores.com
```

---

## App Review Notes
*Paste into the "Notes for App Review" field in App Store Connect.*

```
GyattChores is a private family chore tracker with no accounts or sign-ups.

ADMIN PIN: The app has a 4-digit PIN (7874 in the demo build — change this before shipping) that gates the approval screen. This is a convenience lock to prevent children from approving their own chores, not a security boundary. The PIN is intentionally visible in the app source and is documented in our SECURITY policy. App Review can enter the PIN 7874 to access the admin screen and approve/reject pending chores.

TEST FLOW:
1. Launch the app
2. Tap a player card (🦁 BeKindHearted or 🦖 MegoDinoLava)
3. Tap any chore tile — it will be logged as "pending" with no points yet
4. Tap the ✓ button (top right)
5. Enter PIN: 7874
6. Approve the pending chore — points will be awarded
7. Return to the home screen — Today and This Week stats update

SIRI SHORTCUT: Say "Log dishes for BeKindHearted" to trigger the App Intent. No special permissions required.

WATCH APP: The companion watchOS app mirrors the iOS workflow. No special entitlements are required.

DATA: All data is stored locally on device (UserDefaults). Nothing is sent to external servers unless the optional Supabase sync is configured by the user (it is not enabled in the review build).
```

---

## Age Rating Questionnaire Answers

| Question | Answer | Reason |
|---|---|---|
| Made for Kids (COPPA) | No | App is for families; parent is the primary user |
| Age Rating | 4+ | No objectionable content |
| Cartoon or fantasy violence | None | |
| Realistic violence | None | |
| Sexual content | None | |
| Mature themes | None | |
| Medical / treatment information | None | |
| Profanity | None | |
| Gambling | None | |
| Horror / fear themes | None | |
| Contests | None | |
| User-generated content | None | Chores are selected from a preset list; player names are set by parent |
| Advertising | No | |
| Tracking / advertising data | No | |

**Resulting rating: 4+ ✅**

---

## In-App Purchases
None planned for v1.0. (Premium features in a future version — e.g., themes, extended history, family sharing — may be added post-launch.)

---

## What's New (first release)
```
Welcome to GyattChores! 

• Log chores with a tap — instantly saved, never lost
• Parent approval workflow with PIN
• Today, This Week, This Month, and Total Earned stats with trend arrows
• Siri Shortcuts — log chores by voice
• Apple Watch companion app
• Works offline, always
```
