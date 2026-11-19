# DOYOURWORK on Google Play

Everything the Play Console asks for before an app can go to production, in roughly the order
it asks, with text ready to paste. Where only you can answer, it says so.

This is for the **play** flavor (`com.doyourwork.app`). It's the same app as the
**github** flavor (`com.gyattchores.app`) that goes out through `release.sh` and Obtainium
(pointed at https://github.com/mattgiss/doyourwork); the two differ only in id, signing and
distribution. The github id keeps the app's first name because changing it would stop installed
phones from updating; the play id had never been uploaded, so it uses the new name. Everything stays on the phone until someone
taps Admin → Phones → "Add a phone", and then it travels to the family's other phones through
the encrypted relay (docs/design/encrypted-relay-join.md).

Written 17 November 2026 from what I know of the Play Console. I could not open the Play Console
from here, so treat field names and limits as a guide and trust the Console where it disagrees.

## Decide these before the first upload

1. **The package name is permanent.** The play flavor is `com.doyourwork.app` (chosen 18 November
   2026). Once a bundle with that name is uploaded it can never be changed, and it shows in the
   app's Play Store address.
2. **The version.** The Play build says 1.0, like the iPhone app (set in the play flavor in
   `app/build.gradle.kts`; `release.sh` only changes the github build's version).
3. **A closed test comes first.** New personal developer accounts have to run a closed test with
   at least 12 testers who stay opted in for 14 days before Google allows a production release.
   I believe that is still the rule; the Console's dashboard says exactly what your account
   needs. Start the closed test as early as you can, because it sets the earliest date Android
   can launch. The beta requests from doyourwork.today are where those testers come from.

## The build

```bash
cd android && ./play-bundle.sh
```

prints the path of the signed `.aab` to upload. It needs the upload key described in
`play-bundle.sh`. Accept **Play App Signing** when the Console offers it.

## Store listing (Grow → Store presence → Main store listing)

**App name** (30 at most; this is 28)

```
DOYOURWORK: Chore Scoreboard
```

**Short description** (80 at most; this is 80)

```
25 minutes of chores a day. Points, streaks, a weekly winner. Only you can read it.
```

**Full description** (4,000 at most)

```
DOYOURWORK is a scoreboard for housework. Everyone picks about 25 minutes of chores a day and checks them off, an admin (usually a parent) approves, and points, streaks and a weekly winner follow.

PRIVATE BY DESIGN
• No accounts and no sign-up. Open it and start.
• On one phone or tablet, nothing ever leaves it.
• Add a second device and everything is encrypted on the device before it's sent, with a key only your family's devices have. We can't read it.
• No ads, no tracking, no in-app purchases.
• Erase a device, or delete your family from the server, whenever you like.

YOUR CHORES, IN YOUR WORDS
• Start from 27 everyday chores, or just describe your home. Type or dictate "do the dishes, take out the trash, feed the dog for 5 minutes" and the app sorts it into a list you can tidy up.
• Add, rename, re-time and remove chores whenever you like.

HOW A DAY WORKS
• Pick what you want, or let the app suggest a 25-minute card.
• Check each chore off as you go, then send the card.
• An admin says yes or no to each chore, behind their own code.
• One chore, one person, per day: no arguments over who did the dishes.

WHAT KEEPS IT GOING
• Chores that get skipped take longer next time and move up the list, so they stop being ignored.
• Approved chores earn points. Levels are shown as version numbers: v1.0, v1.1 and up.
• A daily streak multiplies what you earn.
• A weekly leaderboard and a 30-day log show how everyone is doing.
• Send your card and a puzzle opens, with up to an hour of play a day.
• Finished early? A bonus round lets you log extra chores.
• Fifteen colour themes, and everyone can give themselves a display name.

YOURS TO KEEP
• Save a backup of the whole scoreboard to a file you control, and restore it on a new phone.

ONE DEVICE, OR EVERYONE'S
Share one phone or tablet, like the scoreboard at a bowling alley, or give everyone their own. In Admin, tap "Add a phone" and scan the code it shows with the other device: points, approvals and the chore list stay in step. With everyone on their own phone, you can dare each other to do a chore. On a tablet or an unfolded foldable, the scoreboard and the day's card sit side by side.
```

Don't mention iPhone, Apple or the App Store in any of this: Google's metadata policy doesn't
allow naming other platforms.

**Graphics**

| Asset | Size | Where it is |
|---|---|---|
| App icon | 512 × 512 PNG | `graphics/icon-512.png` |
| Feature graphic | 1024 × 500, no transparency | `graphics/feature-graphic.png` |
| Phone screenshots | 1080 × 1920, six | `screenshots/phone/` |
| 7-inch tablet screenshots | 1920 × 1200, six | `screenshots/tablet-7-inch/` |
| 10-inch tablet screenshots | 2560 × 1600, six | `screenshots/tablet-10-inch/` |

The screenshots are numbered in the order to show them and use a made-up family. They are the
real app, drawn by `StoreScreenshotsTest`; retake them after any change to how the app looks:

```bash
cd android && ./PlayStore/take-screenshots.sh
```

**Category and contact** (Store settings)

| Field | Enter |
|---|---|
| App or game | App |
| Category | Productivity |
| Tags | Your choice from Google's list; "Productivity" and "Parenting" fit |
| Email | **Only you can fill this in.** It is shown publicly on the listing. |
| Website | `https://doyourwork.today` |
| Phone | Optional. Leave empty. |

## App content (Policy → App content)

| Declaration | Answer |
|---|---|
| Privacy policy | `https://doyourwork.today/app-privacy.html` |
| Ads | No, the app does not contain ads |
| App access | All functionality is available without special access. (The admin code is one the tester sets themself during setup.) |
| Content rating | Questionnaire category: Utility, Productivity, Communication or Other. Answer No to every content question. The result should be Everyone / PEGI 3. |
| Target audience and content | **Your decision; see below.** |
| News app | No |
| Data safety | See below |
| Government app | No |
| Financial features | None |
| Health | None |
| Advertising ID | No, the app does not use an advertising ID |

**Target audience.** This is the one answer that changes what rules apply. If any age group
under 13 is ticked, Google's Families Policy applies to the whole app. DOYOURWORK would meet it
(no ads, and nothing readable by anyone outside the family is sent), but it adds declarations and review. The app is set up
and run by an adult and the listing is written for a household, so my recommendation is to tick
**13–15, 16–17 and 18 and over**, and when asked whether the listing could unintentionally
appeal to children, answer honestly that younger children may use it at home under an adult's
supervision. This mirrors the App Store choice of not ticking "Made for Kids". I am not a
lawyer, and this is a judgment call that is yours.

**Data safety.** Google counts data as collected when the app sends it off the device, but says
end-to-end encrypted data, "unreadable by you or anyone other than the sender and recipient", is
out of scope. A family's records are exactly that: sealed on the phone with a key the server
never has. What is collected is each linked phone's anonymous sign-in ID.

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | Yes |
| Is all of the user data collected by your app encrypted in transit? | Yes (HTTPS) |
| Do you provide a way for users to request that their data is deleted? | Yes: Admin → Device → Phones → "Delete this family from the server" |
| Data types collected | **Device or other IDs** only (the anonymous ID of a phone that has joined a family) |
| — Collected or shared? | Collected, not shared |
| — Processed ephemerally? | No (kept while the family is on the server) |
| — Required or optional? | Optional: only phones that add or join another phone sign in |
| — Why is it collected? | App functionality |

Not declared, and why: the family's names, chores, logs and codes (end-to-end encrypted, out of
scope); the camera (it reads the QR code on the phone, nothing is sent); IP addresses (seen by the
host to serve each request, not kept or used by us). An unlinked phone sends nothing at all.

## Testing tracks

| Track | Use it for |
|---|---|
| Internal testing | You and the family, straight away, no review. Up to 100 testers by email. |
| Closed testing | The 12-tester, 14-day requirement above, and the public beta. Add testers by the email on their Google account, or use a Google Group. |
| Production | The launch. Unlocks once the closed test requirement is met. |

Release notes for the first closed test (500 at most):

```
The first test release of DOYOURWORK: a chore scoreboard for your household. Set up your family, pick 25 minutes of chores, and have an admin approve them. Use one phone, or add more with a QR code; what's shared is encrypted so only your family can read it. Tell us what confused you and what broke.
```

## Launch

- Price: Free.
- Countries: your decision. United States only is the simplest start.
- Release it as a staged or full rollout on the same day the App Store version is released
  (the App Store side is set to manual release so the two can be lined up).

## What I could not check

- The Play Console itself: its screens, exact wording, and what your particular account is
  required to do before production.
- That Google accepts `com.doyourwork.app` as a package name. It builds, but the first upload is
  the real test.
- The app on a physical phone. The screenshots are the real screens drawn on a computer.
