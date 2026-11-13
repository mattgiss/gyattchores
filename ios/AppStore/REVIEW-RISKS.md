# What could go wrong at App Review

Most serious first. Each item says what the problem is, where I saw it, and what to do.
Written 12 November 2026 against the code on this branch (line numbers are from here) and Apple's
[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
(last updated 16 October 2026).

## 1. Everyone who installs the app shares your family's data — do not list it publicly yet

**This is a blocker for a public App Store listing.** It is not a blocker for TestFlight.

What the app does today:

- Every copy of the app talks to the same database, with the same key, built into the app
  (`ios/GyattCore/Sources/GyattCore/Supabase.swift`, lines 9–10). Nothing in any request says
  which family it belongs to.
- On every sync the app downloads *all* chore logs and *all* shared lists
  (`simple_logs?select=*`, line 50; `family_state?select=*`, line 63), and it syncs when it
  opens and every 10 seconds after (`ios/GyattChores/GyattChoresApp.swift`, lines 17–22).
  There is no off switch.
- The database rules let anyone holding that key read, add and change every row
  (`simple-logs-schema.sql` and `family-state-schema.sql`: `to anon … using (true)` for
  select, insert and update). The schema file says why: "This is a private family app".
- The app takes its player list from the database (`AppStore.swift`, `adoptSharedPlayers`
  and `adoptPlayersFromLogs`), and a fresh install starts with your children's player names
  before it has synced at all (`AppStore.swift`, line 70).
- The parent area is no barrier between families. It opens with Face ID or Touch ID for
  whoever owns the phone (`AdminView.swift`, lines 17 and 53), or with one code that is the
  same in every copy of the app (`Engine.adminCodeHash`). That code is also written out in
  plain text elsewhere in this public repository (see item 4).
- Anyone can give the player whose phone it is a display name: free text, no parent code
  needed (`HomeView.swift`, "✎ display name"). It syncs to every phone like everything else.
  Among strangers that is user-written text shown to other users, and Apple requires
  filtering, reporting and blocking for that (guideline 1.2). The app has none.
- Every new row in the database is posted to your family's Discord channel and pings you
  (`scripts/card-notify.sh`, run every 10 minutes by `.github/workflows/card-notify.yml`).

So a stranger who installed a public build would see your children's player names and
their whole chore history, could log chores as them, could approve or reject their
chores with their own Face ID, could rename or remove your players, and would trigger
Discord pings to you. In the other direction, their children's names and chores would be
stored in your database, which makes you the one collecting data from other people's
children (see item 3). The App Review tester would be the first such stranger.

What I could not check: the rules on the live database. I read the SQL files in the
repository, which say at the top to run them in the Supabase project; I did not query your
database.

Your options:

| Option | What it means | Good for | Catch |
|---|---|---|---|
| **A. Stay on TestFlight** (recommended now) | Keep installing through TestFlight, as you do today. Invite only family. | Your family, right now. Needs none of the store listing. | [Builds stop working after 90 days](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/), so upload a fresh one every couple of months. Family members outside your developer account are "external testers", and Apple reviews the first build you give them. |
| **B. Unlisted app** | A real App Store app that only people with the link can find. [Apple's page](https://developer.apple.com/support/unlisted-app-distribution/). | No 90-day expiry. | It still goes through full App Review (everything in SUBMISSION.md, and the tester still lands in your family's data). You must ask Apple for it and they may say no: their examples are employee and partner apps. Apple says "Unlisted apps are available to anyone who has access to the link. Consider implementing a mechanism within your app to prevent unauthorized use." This app has none. |
| **C. Separate each family, then go public** | Change the app so each family has its own space: a family code or sign-in, database rules that only return that family's rows, a parent code each family sets, no built-in player names. | A genuine public release. | Real development work on the app and the database. Not started; I was asked not to do it here. |
| **D. Public, but with sync turned off** | A build that keeps everything on one device. | Fastest route to a public listing. | Loses the reason your family uses it: phones staying in step. Also a code change. |

My recommendation: **A now**. Do C before any public listing. Choose B only if re-uploading
every 90 days becomes a nuisance, and add some gate first. The rest of this list matters
only once you go for B, C or D.

## 2. Privacy: the app sends data without saying so, and the privacy page is wrong

Apple's rules: a privacy policy link in App Store Connect *and inside the app*, a policy that
says what is collected and how to get it deleted (guideline 5.1.1(i)); consent before
collecting data (5.1.1(ii)); no sending personal data without permission (5.1.2(i)).

- **Nothing in the app tells the user data is leaving the phone.** The only sign is the small
  "⇅ synced" text on the home screen. There is no notice, no consent step and no off switch.
- **There is no privacy policy link inside the app.** I searched `ios/GyattChores/` for any
  link; there is none.
- **`privacy.html` does not describe the iPhone app.** Specifically:
  - It says data "never leaves your device unless you choose to enable optional cloud sync".
    In the iPhone app sync is always on.
  - It says "no other users can access your data". With the database rules above, every
    user can.
  - It says "No data sold or shared with any third party". The data is stored by Supabase,
    and the notifier posts it to Discord.
  - It lists chore logs only. The app also uploads the player list, display names and dares.
  - Its deletion instructions ("contact the household that set up Supabase") only make sense
    for your own family.
  - It uses one of your children's player names as its example.
- **There are two privacy pages that disagree.** `privacy.html` says sync is "on by default";
  `privacy/index.html` says "off by default". Pick one address and make the other redirect.
- **The App Privacy answers cannot be "Data Not Collected".** SUBMISSION.md has the answers
  that match the code.

What to do: rewrite the privacy page to match SUBMISSION.md's privacy section, add a line and
a link in the app (a code change for whoever works on the app next), and decide how someone
can ask for their data to be deleted. I could not open gyattchores.com from here, so I read
the files in the repository instead of the live pages.

## 3. The app is used by children

- **Don't tick "Made for Kids".** It puts the app in the Kids Category, where apps "may not
  send personally identifiable information or device information to third parties"
  (guideline 1.3); player names going to Supabase would be a problem. The choice
  [can't be undone once approved](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/).
- **Then the listing must not say it is for children.** "Apps not in the Kids Category cannot
  include any terms in app name, subtitle, icon, screenshots or description that imply the
  main audience for the app is children" (guideline 5.1.4). The texts in SUBMISSION.md are
  written for a household and a parent. `about.html` ("Pomodoro for kids") and the old
  drafts in `app-store-metadata/` are not.
- **Age rating:** the questionnaire answers come out at 4+. That is about content, and it is
  separate from the Kids Category.
- **Children's privacy law.** With a public listing you would be storing other families'
  children's nicknames and daily activity. In the US that is COPPA territory (parental
  consent, deletion on request); Europe and the UK have their own rules. Guideline 5.1.4
  expects you to comply. I am not a lawyer; this is one more reason for option A, or for
  limiting a first release to the United States.

## 4. The reviewer needs the parent code, and the code is effectively public

- Apple asks you to "provide App Review with full access to your app" (the guidelines'
  "Before You Submit" list; guideline 2.1 says the same about logins). The parent area is
  behind a code, so the code has to go in the App Review notes. Only you can type it there.
- The repository holds only a scrambled form of the code for the iPhone app. But a 4-digit
  PIN is written in plain text in older files in this same public repository
  (`app-store-metadata/listing.md`, `app-store-metadata/developer-account-checklist.md`,
  `development-narrative.md`, `GyattChoresApp/GyattChores/Views/AdminView.swift`), and I
  checked: scrambling that PIN gives exactly the value in `Engine.swift`. If that is still
  your parent code, anyone can read it. Even if it were not written down, a short code
  scrambled this way can be recovered in seconds.
- The code cannot be changed from inside the app, and it is the same for every install.
- For your own family this is the "keeps kids from approving their own chores" lock it was
  meant to be. For a public app it is not a lock at all (see item 1).

## 5. Your children's player names are in public material

Guideline 2.3.9: screenshots "should display fictional account information instead of data
from a real person."

- The new store screenshots use made-up names (sockninja, dishwizard, broomrider), and the
  test that takes them fails if either real name or any test-mode text is on screen.
- Still carrying the real names: the app itself on a fresh install (`AppStore.swift`, line
  70), `about.html`, `privacy.html`, and the old drafts in `app-store-metadata/`.
- **Do not paste anything from `app-store-metadata/`.** It describes an older app (Siri,
  Apple Watch, a different bundle ID, "nothing is sent to external servers"), none of which
  is true of this one. Describing features the app does not have is its own rejection reason
  (guidelines 2.3 and 2.3.1).

## 6. Apple may say the app is for one family

The guidelines open with: "If you build an app that you just want to show to family and
friends, the App Store isn't the best way to do that." A reviewer could reach that view
quickly: 27 fixed chores, some specific to your house ("empty guest bathroom trash"), no way
to add chores, your players already there, and a support page (`about.html`) that says "a
chore tracking app built for one family" and "This is a private family app". I would expect
such a rejection to cite guideline 4.2 (minimum functionality).

## 7. Smaller things

- **Version number.** The project said 0.1.0 while the listing says 1.0. Fixed on this
  branch (now 1.0); see SUBMISSION.md. A 0.x number on the store also reads as a beta, which
  guideline 2.2 sends to TestFlight.
- **The name.** "Gyatt" is slang. Store text has to suit all ages (guideline 2.3.8). I think
  a rejection over the name is unlikely, but have a one-line answer ready.
- **Support page.** Apple requires the support address to show real contact details.
  `about.html` has your email, so it qualifies, but see items 3, 5 and 6 for what else is on
  that page.
- **iPad.** The app now runs on iPad, so Apple will test it there and iPad screenshots are
  required. Both are covered: CI runs the UI tests on an iPad simulator and takes iPad
  screenshots.
- **Already in good shape** (checked in the CI log of the Release build): the encryption
  question is pre-answered "no", the Face ID explanation is present, the app icon and the
  privacy manifest are in the app, and it builds with the current Xcode.
