# What could go wrong at App Review

Most serious first. Each item says what the problem is and what to do about it. Written
13 November 2026 and brought up to date on 17 November 2026, against Apple's
[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
(last updated 16 October 2026), after the app was rebuilt to keep everything on the device.

## What the rebuild settled

The earlier version of this list opened with a blocker: every install shared one family's
database, with that family's players built in and one admin code for everyone. All of that is
gone from the iOS app:

- **No database.** The sync code was removed; the app has no network code. Each install holds
  only what was typed into it.
- **Nothing built in.** A fresh install opens on a setup screen. No player names ship with it.
- **Each family's own admin codes**, chosen at setup, stored on the device as a salted hash.
  The old shared code opens nothing.
- **Their own chores.** A family can write or dictate its own list and edit it later, so it is
  no longer an app shaped around one household (the old guideline 4.2 worry).
- **Display names** are free text, but only ever shown on the device they were typed on, so
  the rules for user content shared between strangers (guideline 1.2) don't come into it.
- **App Privacy** is now honestly "Data Not Collected".

What follows is what's left.

## 1. The website has to match the app before you submit

Apple opens the Support URL and the Privacy Policy URL, and the app itself links to the
privacy page (guideline 5.1.1(i) requires both a policy in App Store Connect and a link in
the app).

- **The two pages are published:** `app-privacy.html` and `app.html` were added to the
  website on 13 November 2026. Open both on gyattchores.com once before submitting; a link
  that leads to a missing page is a likely rejection.
- **Don't point Apple at the existing pages.** `privacy.html` and `privacy/index.html`
  describe the older website version (optional cloud sync) and disagree with each other;
  `about.html` calls it "a private family app" and names your children's players. They are
  accurate for the website and wrong for this app.
- **The website and the Android app still use the shared family database.** That is separate
  from this submission, but a reviewer who wanders from the support page to the web app will
  see a different product. The new `app.html` says plainly that it is about the iPhone and
  iPad app.

## 2. The app is used by children

- **Don't tick "Made for Kids".** The choice
  [can't be undone once approved](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/),
  and it brings the Kids Category rules (guideline 1.3) for no benefit.
- **Then the listing must not say it is for children.** "Apps not in the Kids Category cannot
  include any terms in app name, subtitle, icon, screenshots or description that imply the
  main audience for the app is children" (guideline 5.1.4). The texts in SUBMISSION.md are
  written for a household. Keep "kids" out of the keywords too.
- **Age rating:** the questionnaire answers come out at 4+.
- **Children's privacy law** was the heavy part of this item and is now light: the app
  collects nothing from anyone, so there is no children's data in your hands to protect,
  consent to or delete. I am not a lawyer, but this is the position Apple's own "Data Not
  Collected" label describes.

## 3. A forgotten admin code cannot be recovered

There is no server to reset it from, by design. The app says so when the code is chosen and
again on the unlock screen, and offers two ways out: Face ID / Touch ID for the admin area
(off by default, an admin can turn it on) and, failing that, deleting the app and starting a
new scoreboard, which loses the points. Expect the occasional support email and one-star
review about this. It is not a review-rejection risk. Making a second person an admin is the
practical safeguard, and the app allows it.

## 4. One device only, for now

The listing says so ("One device, one scoreboard"). Apple won't object, but families with a
phone each will ask for sharing. Do not describe sharing in the listing until the public app
does it: describing features an app doesn't have is a rejection reason (guideline 2.3.1). A
backup file can move a scoreboard to a new device, and the listing says only that.

Dares are in the family build only, for the same reason: a secret guess needs each person on
their own device.

## 5. Two builds from one project

The public app and your family's synced build share a bundle id. That is what lets the family
build update your household's phones in place, and it is also the way to get this wrong:

- **Only the public scheme goes to App Review and to outside testers.** A family build submitted
  by mistake talks to a database, which contradicts "Data Not Collected" and every privacy
  answer in SUBMISSION.md.
- Both builds upload to the same app record. In TestFlight, check which one a build is before
  adding it to a group: the version line at the bottom of the scoreboard ends in "· family" on a
  family build.
- CI archives both and checks that the public one carries no server address.

## 6. Smaller things

- **The old parent code** that used to be written out in this repository has been replaced
  and the files that held it removed. It never had anything to do with this version of the
  iOS app, where each family sets its own.
- **Real player names in public material:** check `about.html` and `privacy.html` on the
  website. None are in the app or on the new store pages.
- **The name.** "Gyatt" is slang. Store text has to suit all ages (guideline 2.3.8). I think
  a rejection over the name is unlikely, but have a one-line answer ready.
- **Don't name other platforms.** The app launches alongside an Android version, but the App
  Store listing, screenshots and review notes must not mention it (guideline 2.3.10).
- **Sorting spoken chores is simple word-sorting,** not AI, and it will sometimes split or
  join chores wrongly. The app shows the result as a list to fix before anything is added,
  and the listing says "sorts it into a list you can tidy up". Keep the claim that modest.
- **iPad.** The app runs on iPad, so Apple will test it there and iPad screenshots are
  required. Both are covered: CI runs the UI tests on an iPad simulator and takes iPad
  screenshots.
- **Already in good shape** (checked in the CI log of the Release build): the encryption
  question is pre-answered "no", the Face ID explanation is present, the app icon and the
  privacy manifest are in the app, and it builds with the current Xcode.
