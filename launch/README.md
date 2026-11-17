# Launch kit

Everything the two stores and the website need, in one place. iPhone, iPad and Android launch on
the same day.

Status as of 17 November 2026: **ready** means it exists and matches the app as it is today;
**yours** means only the owner can do it.

## Where things are

| | App Store (iPhone, iPad) | Google Play (Android) |
|---|---|---|
| Field-by-field guide with text to paste | [`ios/AppStore/SUBMISSION.md`](../ios/AppStore/SUBMISSION.md) | [`android/PlayStore/README.md`](../android/PlayStore/README.md) |
| What a reviewer might object to | [`ios/AppStore/REVIEW-RISKS.md`](../ios/AppStore/REVIEW-RISKS.md) | in the Play guide, under "Decide these before the first upload" |
| Screenshots | made by CI on every push: the `app-store-screenshots` download on the newest green [iOS run](https://github.com/mattgiss/gyattchores/actions/workflows/ios.yml) | [`android/PlayStore/screenshots/`](../android/PlayStore/screenshots/) |
| Icon and graphics | in the app (`ios/GyattChores/Assets.xcassets`) | [`android/PlayStore/graphics/`](../android/PlayStore/graphics/) |
| The build | the public scheme, uploaded from the Mac (`ios/README.md`) | `android/play-bundle.sh` |

Shared: the website (`main` branch) carries the support page (`app.html`), the privacy policy
(`app-privacy.html`) and the beta sign-up. Both stores link to the same two pages.

## Checklist

### Both stores

| Item | Status |
|---|---|
| Privacy policy page, live | ready: `https://gyattchores.com/app-privacy.html` (it still says "iPhone and iPad" in places and needs widening to Android before launch) |
| Support page, live | ready: `https://gyattchores.com/app.html` (same note) |
| Marketing site with beta sign-up | drafted on the branch `claude/marketing-site`, not published |
| One version number on both | **yours**: iPhone says 1.0, Android says 0.7.1 |
| Launch date and countries | **yours** |

### App Store

| Item | Status |
|---|---|
| Name, subtitle, promotional text, description, keywords | ready |
| Screenshots (two iPhone sizes, 13-inch iPad) | ready, from CI |
| App Review notes | ready |
| App Privacy answers ("Data Not Collected") | ready |
| Age rating answers | ready |
| TestFlight test information and "What to test" | ready |
| A 1.0 build of the public scheme uploaded | **yours** (from the Mac) |
| App Review contact name, phone, email | **yours** |
| External test group and public link | **yours**; Apple reviews the first build |

### Google Play

| Item | Status |
|---|---|
| App name, short and full description | ready |
| Phone, 7-inch and 10-inch screenshots | ready |
| Icon 512 and feature graphic | ready |
| Data safety, content rating, ads and app-access answers | ready |
| Package name, final | **yours**: permanent after the first upload |
| Target audience answer | **yours**, with a recommendation in the guide |
| Play Console developer account and contact email | **yours** |
| Signed bundle uploaded | **yours** (`play-bundle.sh` on the Mac) |
| Closed test with 12 testers for 14 days | **yours**: this sets the earliest Android launch date |

## The order that gets both out on the same day

1. Settle the package name and the version number.
2. Upload the Android bundle to internal testing, then start the closed test. The 14-day clock
   only starts once 12 testers have opted in.
3. Upload the iPhone build, fill in TestFlight's test information, and open external testing.
4. Publish the marketing site so beta requests have somewhere to come from.
5. While the Android closed test runs, fill in both store listings from the two guides.
6. Submit the iPhone app for review with **manual release**. Apply for production on Play when
   the closed test is done.
7. When both are approved, release both.
