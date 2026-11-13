# What could go wrong at App Review

Most serious first. Each item says what the problem is and what to do about it. Written
13 November 2026 against Apple's
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

- **The two pages don't exist on the site yet.** `app-privacy.html` and `app.html` are
  drafted on the branch `claude/app-pages`, waiting for your go-ahead to be published. Until
  they are, the link in the app leads to a missing page, which is a likely rejection.
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
phone each will ask for sharing. That is the planned next version, through the family's own
iCloud, which keeps "Data Not Collected" true. Do not describe it in the listing until it
exists: describing features the app doesn't have is a rejection reason (guideline 2.3.1).

Dares are gone from this version for the same reason: a secret guess needs each person on
their own device. They can come back with sharing.

## 5. Your own family's devices

A phone that already has the TestFlight build keeps its players and history when it updates,
asks whoever opens it first for an admin name and code, and from then on is a scoreboard of
its own. It no longer shares with the other phones, the website or Android. So decide which
device is the family scoreboard before installing this version on your children's phones,
or leave their phones on the current build until sharing arrives.

## 6. Smaller things

- **Old parent code in the repository.** A 4-digit code is still written in plain text in
  older files (`app-store-metadata/listing.md`, `app-store-metadata/developer-account-checklist.md`,
  `development-narrative.md`, `GyattChoresApp/GyattChores/Views/AdminView.swift`). It no
  longer has anything to do with the iOS app, but it is still the website's admin code.
- **Real player names in public material:** `about.html`, `privacy.html` and the stale
  `app-store-metadata/` folder. None of it is in the app or the new store pages.
- **Do not paste anything from `app-store-metadata/`.** It describes an older app (Siri,
  Apple Watch, a different bundle ID), none of which is true of this one.
- **The name.** "Gyatt" is slang. Store text has to suit all ages (guideline 2.3.8). I think
  a rejection over the name is unlikely, but have a one-line answer ready.
- **Sorting spoken chores is simple word-sorting,** not AI, and it will sometimes split or
  join chores wrongly. The app shows the result as a list to fix before anything is added,
  and the listing says "sorts it into a list you can tidy up". Keep the claim that modest.
- **iPad.** The app runs on iPad, so Apple will test it there and iPad screenshots are
  required. Both are covered: CI runs the UI tests on an iPad simulator and takes iPad
  screenshots.
- **Already in good shape** (checked in the CI log of the Release build): the encryption
  question is pre-answered "no", the Face ID explanation is present, the app icon and the
  privacy manifest are in the app, and it builds with the current Xcode.
