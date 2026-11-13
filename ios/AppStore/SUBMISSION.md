# Submitting GyattChores 1.0 to the App Store

Everything App Store Connect asks for before the **Add for Review** button turns on, in the
order it asks. Where there is text to enter, it is here ready to paste. Where only you can
answer, it says so and says what to weigh.

Checked against Apple's pages on 12 November 2026; links are at the bottom.

## Read this first

**Today, every copy of the app shares one database: your family's.** A public listing would
let any stranger who installs it read and change your children's chore data. That needs a
decision before you submit: stay on TestFlight, ask Apple for an unlisted app, or separate
each family's data first. [REVIEW-RISKS.md](REVIEW-RISKS.md) lays out the choices (item 1)
and everything else a reviewer is likely to object to.

My recommendation is to stay on TestFlight for now. If you do, you need none of this page.

**Don't paste from the `app-store-metadata/` folder.** It describes an older, different app.

## Before you open App Store Connect

1. **Upload a build that says 1.0.** The project said 0.1.0 until now, so the builds already
   in TestFlight will say 0.1.0 too. Apple files a build under the version number inside it,
   so those can't be picked for the 1.0 listing. This branch changes the project to 1.0. Once
   it is merged, archive and upload from your Mac exactly as before (`ios/README.md`,
   "Uploading from a Mac instead"), and wait for Apple's email saying the build has finished
   processing.
2. **Download the screenshots** from GitHub ([Screenshots](#1-screenshots) below says
   where). The download unzips to three folders.
3. **Fix the privacy page** on gyattchores.com so it matches what the app does
   ([REVIEW-RISKS.md](REVIEW-RISKS.md), item 2). Apple reads it.

## A. The version page ("1.0 Prepare for Submission" in the sidebar)

### 1. Screenshots

Three folders, six pictures each, numbered in the order to show them. Drag all six from a
folder into the matching slot.

| Folder | Pixels | Slot in App Store Connect |
|---|---|---|
| `iphone-large-1320x2868` | 1320 × 2868 | The largest iPhone size (taken on an iPhone 17 Pro Max, a 6.9-inch screen) |
| `iphone-medium-1206x2622` | 1206 × 2622 | The next iPhone size down (taken on an iPhone 17 Pro, a 6.3-inch screen) |
| `ipad-13-inch-2064x2752` | 2064 × 2752 | iPad 13-inch (taken on an iPad Pro 13-inch) |

- Where they are: <https://github.com/mattgiss/gyattchores/actions/workflows/ios.yml>. Open the
  newest run with a green tick, scroll to the bottom of its page to **Artifacts**, and
  download **app-store-screenshots**. You need to be signed in to GitHub. GitHub deletes
  artifacts after about 90 days; a new run makes new ones.
- The run's **App Store screenshots** job fails unless every file is exactly the size in the
  table and has no transparency channel (Apple refuses both). Its log lists each file with
  its size.
- Why two iPhone sizes: Apple's page currently says the required iPhone size is the medium
  one in one place and the large one in another. With both uploaded, either reading is met.
  If App Store Connect shows only one iPhone slot, use the large folder.
- Smaller iPhone and iPad sizes are filled in by Apple from these.
- The pictures use made-up players (sockninja, dishwizard, broomrider), not your family.
- The iPad pictures have a small curved mark in the bottom-right corner. That is iPadOS's own
  window-resize handle, not a flaw.
- App Preview (video): leave empty.

They are retaken on every push that changes anything under `ios/`, so after an app change
the newest green run has a fresh set.

### 2. Promotional Text (170 characters at most; this is 155)

```
Pick about 25 minutes of chores, check them off, and send them to a parent to approve. Streaks, levels and a weekly leaderboard keep the whole house going.
```

### 3. Description (4,000 at most)

```
GyattChores keeps housework small: about 25 minutes a day for each person, so nothing piles up.

HOW A DAY WORKS
• Pick what you want from a built-in list of 27 everyday chores, or tap "suggest" and the app fills your card to 25 minutes.
• Check each chore off as you go, then submit the card.
• A parent approves or rejects each chore in the parent area, which is locked with Face ID, Touch ID or a code.

WHAT KEEPS IT GOING
• Chores that have been skipped for a while take longer and move up the list, so they stop being ignored.
• Approved chores earn XP. Levels are shown as version numbers: v1.0, v1.1 and up.
• A daily streak multiplies the XP you earn.
• A weekly leaderboard and a 30-day log show how everyone is doing.
• Finished early? A bonus round lets you log extra chores.
• Dares: secretly guess which chores someone else will do today. Guesses are revealed the next day, and a right guess earns points for both of you.

FOR A SHARED HOUSEHOLD
• Everyone's iPhones and iPads stay in step.
• Works without a connection and catches up later.
• On iPad, the household list and the day's card sit side by side.

No accounts, no ads, no in-app purchases, no tracking.
```

This describes the app as it is, apart from one line: "Everyone's iPhones and iPads stay in
step" is only a fair description once each family has its own data (REVIEW-RISKS.md, item 1).

### 4. Keywords (100 bytes at most; this is 94)

```
chores,chore chart,family,housework,cleaning,tasks,streak,routine,household,parents,tidy,habit
```

### 5. Support URL

```
https://gyattchores.com/about.html
```

Apple requires this page to show a way to reach you; it has your email. It also names your
children's player names and calls the app "a private family app". Change that first if you
go public (REVIEW-RISKS.md, items 5 and 6).

### 6. Marketing URL

Optional. Leave it empty.

### 7. Version

```
1.0
```

Already set. Leave it; the project now matches.

### 8. Copyright

```
2026 Matthew Gissentanna
```

Apple adds the © itself. Use the name the developer account is under, if it is different.

### 9. Build

Click **+** next to Build and pick the 1.0 build. If the list is empty, the 1.0 build has
not been uploaded or has not finished processing.

The placeholder app icon should be replaced once a build is attached: Apple takes the icon
from the build, and CI confirms the icon is inside the app. I could not watch this happen. If
it is still a placeholder an hour after you attach the build, the build's icon needs looking at.

No encryption question should appear; the app already answers it ("no").

### 10. App Review Information

- **Sign-in required:** untick. The app has no accounts.
- **Contact** (first name, last name, phone, email): **only you can fill this in.** The phone
  number needs a plus sign and country code, such as +1 555 010 0199.
- **Notes:** paste the text below, then replace the line in capitals with your parent code.
  Only you know it; do not put it anywhere in this repository. Delete the last line unless
  you are asking for an unlisted app.

```
GyattChores is a household chore tracker. There is no account or sign-in.

A DAY IN THE APP
1. On the home screen, tap a name under "who's playing".
2. Tap "suggest a 25-min card", then "LOCK IN CARD".
3. Tap each chore to check it off, then "SUBMIT FOR APPROVAL".
4. Go back to the home screen.

PARENT AREA (approving chores)
1. Tap the "GYATTCHORES" title five times quickly.
2. Enter the parent code: REPLACE THIS WITH THE PARENT CODE
   (Face ID or Touch ID also opens it on a device that has one set up.)
3. Tap "approve" or "reject" on a waiting chore. Players can be added or renamed at the bottom.

DARES (optional)
On the home screen, tap a name under "whose phone is this?", then "DARES". Pick another player and tap up to three chores you think they will do today. Dares are revealed on the home screen the next day.

DATA
So that a household's devices stay in step, the app sends chore logs (player username, chore, points, approval status, time), the player list, display names and dares to our database, hosted by Supabase. There are no ads, analytics, tracking or purchases. Face ID is used only to open the parent area.

This app is intended for unlisted distribution.
```

- **Attachment:** none.

Be aware: with the app as it is today, the reviewer will be looking at, and able to change,
your family's real chores.

### 11. Version Release

Choose **Manually release this version**, so nothing goes live until you say so.

## B. App Information (sidebar, under General)

| Field | Enter |
|---|---|
| Name | `GyattChores` (already there) |
| Subtitle (30 at most; this is 27) | `Family chores, 25 min a day` |
| Primary category | Productivity |
| Secondary category | Lifestyle |
| Content Rights | "No, it does not contain, show, or access third-party content" |
| License Agreement | Leave Apple's standard one |

**Age Rating** — click **Set Up Age Ratings** and answer:

| Question | Answer |
|---|---|
| Parental Controls | No |
| Age Assurance | No |
| Unrestricted Web Access | No |
| User-Generated Content | No |
| Messaging and Chat | No |
| Advertising | No |
| Profanity or Crude Humor; Horror/Fear Themes; Alcohol, Tobacco, or Drug Use | None |
| Medical or Treatment Information; Health or Wellness Topics | None |
| Mature or Suggestive Themes; Sexual Content or Nudity; Graphic Sexual Content | None |
| Cartoon or Fantasy Violence; Realistic Violence; Prolonged Graphic or Sadistic Realistic Violence; Guns or Other Weapons | None |
| Gambling; Simulated Gambling; Loot Boxes | No / None |
| Contests | None (see below) |
| Age Categories and Override | **Not Applicable** — do not choose Made for Kids |

The result should be **4+**.

Three answers deserve a second look, because they are your call:

- *Parental Controls* means tools that limit what a child can see or do in the app. The
  parent area approves chores; it does not restrict content. Hence "No". Answering "Yes"
  would still give 4+.
- *Contests* is defined as events where "users compete with one another for rankings". The
  weekly leaderboard inside one household is arguably that. "None" and "Infrequent" both
  give 4+; "Frequent" would make it 13+, which would be wrong for this app.
- *User-Generated Content* means content spread widely between users. Player names and
  display names seen only by one's own household are not that. This "No" stops being true
  if strangers share one database (REVIEW-RISKS.md, item 1).

*Made for Kids* cannot be undone after approval and brings stricter rules the app does not
meet today (REVIEW-RISKS.md, item 3).

If App Store Connect asks about your **Digital Services Act trader status**: that is about
selling in the European Union, and **only you can answer it**. It does not arise if the app
is offered only in the United States.

## C. Pricing and Availability

| Field | Enter |
|---|---|
| Price | Free ($0.00) |
| Availability | **Your decision.** I suggest United States only to begin with. Europe and the UK add privacy rules for children's data and the trader question above. |
| Distribution method | Public. (An unlisted app also starts as Public; you ask Apple to switch it after you submit.) |
| Pre-order | No |
| Tax category | Leave as it is |

## D. App Privacy

**Privacy Policy URL**

```
https://gyattchores.com/privacy.html
```

Fix the page first (see "Before you open App Store Connect").

**"Do you or your third-party partners collect data from this app?"** — **Yes.**

"Collect" means data leaves the device and is kept. I read the code that sends it
(`ios/GyattCore/Sources/GyattCore/Supabase.swift` and `Sync.swift`) and the database tables
(`simple-logs-schema.sql`, `family-state-schema.sql`). This is everything that leaves the
phone:

- each chore log: player number, player name, chore, points, and whether it is pending,
  approved or rejected (the server adds the time)
- the list of players (number and name) and the numbers of removed players
- a player's display name, if they set one (free text, up to 24 characters)
- each player's dares for the day (who they dared and which chore)

Not sent: the minutes on a card, the sound setting, "whose phone this is", anything from
Face ID. There is no analytics, advertising or other outside code in the app.

**Data types to tick**, and the same three answers for each:

| Tick | Because |
|---|---|
| Contact Info → **Name** | Usernames and display names are free text, and a family may type real first names |
| Identifiers → **User ID** | Apple's definition includes "screen name, handle"; that is what a username is |
| User Content → **Other User Content** | The chore logs, approvals and dares |

For each of the three:

| Question | Answer |
|---|---|
| What is it used for? | **App Functionality** only |
| Is it linked to the user's identity? | **Yes** — every log is stored with the player's name |
| Is it used for tracking? | **No** |

Then click **Publish**.

Two things that are yours to weigh:

- Ticking **Name** is the cautious choice. If you are sure only nicknames will ever be
  typed, User ID alone covers it.
- The database host can see the internet address a request came from, as any server can.
  The app does not store or use it, so by Apple's examples it is not declared.

## E. Submit

1. Top right of the version page: **Add for Review**. If it is still grey, or it answers
   with a list of missing items, something above is unfinished: most often the build,
   the screenshots, the age rating or App Privacy.
2. **Submit for Review** on the next screen.
3. For an unlisted app only: after submitting, send Apple the request form linked from
   their unlisted-distribution page.

## What I could not check

- App Store Connect itself. Field names come from Apple's help pages, and the screens may be
  worded slightly differently (the screenshot slots especially).
- The live website and the live database; I read the files in this repository.
- Whether Apple would agree to an unlisted app for a family.

## Apple pages used

- Screenshot sizes: <https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/>
- Version page fields and limits: <https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/>
- App Information fields: <https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/>
- Builds and version numbers: <https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/> and <https://developer.apple.com/help/app-store-connect/manage-builds/choose-a-build-to-submit/>
- Age rating questions and results: <https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/> and <https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/>
- Categories: <https://developer.apple.com/app-store/categories/>
- Price and availability: <https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store/> and <https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/set-distribution-methods/>
- Privacy answers: <https://developer.apple.com/app-store/app-privacy-details/> and <https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/>
- Submitting: <https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/>
- Unlisted apps: <https://developer.apple.com/support/unlisted-app-distribution/>
- App Review Guidelines (16 October 2026): <https://developer.apple.com/app-store/review/guidelines/>
