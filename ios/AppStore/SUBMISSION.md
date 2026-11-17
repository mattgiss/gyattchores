# Submitting GyattChores 1.0 to the App Store

Everything App Store Connect asks for before the **Add for Review** button turns on, in the
order it asks. Where there is text to enter, it is here ready to paste. Where only you can
answer, it says so and says what to weigh.

Checked against Apple's pages on 12 November 2026 (links at the bottom); the texts were brought up to date with the app on 17 November 2026. The whole launch kit, Google Play included, is indexed in [`launch/README.md`](../../launch/README.md).

## Read this first

**Submit the public build, not the family one.** The project builds two apps from one codebase
(`ios/README.md`, "Two builds"). The scheme **GyattChores** is the App Store app: everything stays
on the device and it contains no network code. **GyattChores Family** syncs with your own
family's database and is only for your household's TestFlight. Everything on this page describes
the public build; a family build sent to App Review would contradict every privacy answer here.

The iPhone and iPad app launches the same day as the Android one. Choose **manual release**
(section 11) so the two can be lined up.

## Before you open App Store Connect

1. **Upload a build that says 1.0.** The project said 0.1.0 until now, so the builds already
   in TestFlight will say 0.1.0 too. Apple files a build under the version number inside it,
   so those can't be picked for the 1.0 listing. This branch changes the project to 1.0. Once
   it is merged, archive and upload from your Mac exactly as before (`ios/README.md`,
   "Uploading from a Mac instead"), and wait for Apple's email saying the build has finished
   processing.
2. **Download the screenshots** from GitHub ([Screenshots](#1-screenshots) below says
   where). The download unzips to three folders.
3. **Open the app's privacy and support pages** on gyattchores.com (`app-privacy.html` and
   `app.html`) and check they load. The app links to the privacy page, and Apple opens both.

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
- The pictures use a made-up family (sockninja, dishwizard and broomrider play; pat is the admin).
- The iPad pictures have a small curved mark in the bottom-right corner. That is iPadOS's own
  window-resize handle, not a flaw.
- App Preview (video): leave empty.

They are retaken on every push that changes anything under `ios/`, so after an app change
the newest green run has a fresh set.

### 2. Promotional Text (170 characters at most; this is 145)

```
A chore scoreboard for your household: 25 minutes a day each, approved by an admin. No accounts, no sign-up, and nothing ever leaves your device.
```

### 3. Description (4,000 at most)

```
GyattChores is a scoreboard for housework. Everyone picks about 25 minutes of chores a day and checks them off, an admin (usually a parent) approves, and points, streaks and a weekly winner follow.

PRIVATE BY DESIGN
• No accounts and no sign-up. Open it and start.
• Everything stays on your iPhone or iPad. The app has no servers and never goes online.
• No ads, no tracking, no in-app purchases.
• Delete the app, or tap "Erase everything", and it's all gone.

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
• Save a backup of the whole scoreboard to a file you control, and restore it on a new device.

ONE DEVICE, ONE SCOREBOARD
GyattChores runs on a single iPhone or iPad that the household shares, like the scoreboard at a bowling alley. On iPad, the scoreboard and the day's card sit side by side.
```

Every line describes something the app does today. Two things are deliberately left out: sharing
between devices, which the public app doesn't do, and any mention of Android, since Apple doesn't
allow other platforms to be named in a listing (guideline 2.3.10).

### 4. Keywords (100 bytes at most; this is 91)

```
chores,chore chart,family,housework,cleaning,tasks,streak,routine,household,parents,offline
```

### 5. Support URL

```
https://gyattchores.com/app.html
```

Apple requires this page to show a way to reach you; it has your email. Don't use
`about.html`: it describes the older website version as "a private family app" and names
your children's players.

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
- **Notes:** paste the text below as it is. There is no code of yours to give the reviewer:
  they choose their own when they set the app up.

```
GyattChores is a household chore scoreboard for one shared iPhone or iPad. There is no account or sign-in, and the app has no network code: everything stays on the device.

SETTING UP (first launch)
1. Tap "Set up this device".
2. Type any name and an admin code of 4 or more characters, twice (for example 2468). Tap "Next".
3. Add one or two player names. Tap "Next".
4. Tap "Use the starter list". (Or tap "Write or say your own", type "dishes, take out the trash, feed the dog 5 minutes", then "Sort into chores" and add them.)

A DAY IN THE APP
1. On the scoreboard, tap a player's name.
2. Tap "Suggest a 25-minute card", then "Lock in my card".
3. Tap each chore to check it off, then "Send it off for approval". Go back.

ADMIN AREA
1. Tap "Admin" at the top and enter the code you chose in step 2.
2. "Approve": say yes or no to the waiting chores. "Players": add people or make someone an admin. "Chores": add, edit or remove chores. "Device": save or restore a backup, the privacy policy, and erase everything.

There are no ads, analytics, tracking or purchases. Face ID / Touch ID is optional, off by default, and used only to open the admin area. Dictation is the system keyboard's own; the app does not use the microphone. A backup is a file the user saves through the system's save panel to a place they choose.
```

- **Attachment:** none.

### 11. Version Release

Choose **Manually release this version**, so nothing goes live until you say so.

## B. App Information (sidebar, under General)

| Field | Enter |
|---|---|
| Name | `GyattChores` (already there) |
| Subtitle (30 at most; this is 28) | `The private chore scoreboard` |
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
  admin area approves chores; it does not restrict content. Hence "No". Answering "Yes"
  would still give 4+.
- *Contests* is defined as events where "users compete with one another for rankings". The
  weekly leaderboard inside one household is arguably that. "None" and "Infrequent" both
  give 4+; "Frequent" would make it 13+, which would be wrong for this app.
- *User-Generated Content* means content spread widely between users. Names and chores
  typed into the app never leave the device they were typed on, so there is none.

*Made for Kids* cannot be undone after approval, and the listing is written for a household,
not for children (REVIEW-RISKS.md, item 2).

If App Store Connect asks about your **Digital Services Act trader status**: that is about
selling in the European Union, and **only you can answer it**. It does not arise if the app
is offered only in the United States.

## C. Pricing and Availability

| Field | Enter |
|---|---|
| Price | Free ($0.00) |
| Availability | **Your decision.** With no data collected, the children's-privacy reasons for holding back Europe and the UK are gone; what remains there is the trader question above. United States only is still the simplest start. |
| Distribution method | Public |
| Pre-order | No |
| Tax category | Leave as it is |

## D. App Privacy

**Privacy Policy URL**

```
https://gyattchores.com/app-privacy.html
```

Apple requires a policy even for an app that collects nothing, and requires the app to link
to it. The app does (on the welcome screen and under admin → device).

**"Do you or your third-party partners collect data from this app?"** — **No.**

Apple's definition: "collect" means sending data off the device in a way that lets you or
anyone else access it. The app can't: it contains no network code at all (CI builds it, and
`ios/README.md` says where everything is kept). Players, chores, points and admin codes are
files in the app's own storage on the device. There is no analytics, advertising or other
outside code.

Choosing No finishes the section: the listing will show **Data Not Collected**. Click
**Publish**.

Two things worth knowing, neither of which changes the answer:

- If the device owner has iCloud Backup or an encrypted computer backup turned on, the app's
  files are in that backup like any other app's. That is the owner's own backup; you can't
  see it, so it is not collection.
- Dictating chores uses the keyboard's microphone key, which is Apple's dictation, not this
  app. The app never touches the microphone.
- Saving a backup writes a file through the system's save panel to wherever the person chooses
  (Files, iCloud Drive, AirDrop). The app sends it nowhere itself.

## E. Submit

1. Top right of the version page: **Add for Review**. If it is still grey, or it answers
   with a list of missing items, something above is unfinished: most often the build,
   the screenshots, the age rating or App Privacy.
2. **Submit for Review** on the next screen.

## F. TestFlight (the beta)

TestFlight asks for its own short set of answers, under **TestFlight → Test Information** in the
sidebar. They are needed before anyone outside your App Store Connect team can test.

| Field | Enter |
|---|---|
| Beta App Description | the text below |
| Feedback Email | **Only you can fill this in.** Testers' feedback goes here. |
| Marketing URL | `https://gyattchores.com` |
| Privacy Policy URL | `https://gyattchores.com/app-privacy.html` |
| Beta App Review: contact name, phone, email | **Only you can fill this in.** |
| Beta App Review: sign-in required | Untick |
| Beta App Review: notes | the same notes as section 10 |

Beta App Description:

```
GyattChores is a chore scoreboard for one household on one iPhone or iPad. Everyone picks about 25 minutes of chores a day, an admin approves what got done, and points, streaks and a weekly winner follow. There are no accounts and nothing leaves your device.
```

**What to Test**, entered on each build (4,000 at most):

```
Thanks for trying GyattChores early.

Please set it up for your own household: an admin, a few players, and your chores (try describing them in a sentence). Then run it for a few days.

We'd most like to hear:
• Was anything in setup confusing?
• Did sorting your chores from a sentence get them right?
• Did 25 minutes a day feel like the right amount?
• Anything that looked wrong on your device, and which device it was.

To send feedback, take a screenshot in the app and choose "Share Beta Feedback", or reply to the invite email.
```

Who can test:

- **Internal testers** are people on your App Store Connect team (up to 100). They get builds
  straight away with no review.
- **External testers** are everyone else: the people who ask through gyattchores.com. Create a
  group under **External Testing**, add the build, and Apple reviews the first build before
  anyone can install it. After that, add each person by the email on their Apple account, or
  switch on the group's **public link** and send that instead; a public link can be capped at a
  number of testers.
- Send only **public** builds to external testers. The family build is for your own household.

## What I could not check

- App Store Connect itself. Field names come from Apple's help pages, and the screens may be
  worded slightly differently (the screenshot slots especially).
- The live website; I read the files in this repository.

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
- App Review Guidelines (16 October 2026): <https://developer.apple.com/app-store/review/guidelines/>
