# Apple Developer Account — Pre-flight Checklist

Everything to do immediately after paying for the $99/year Apple Developer Program.
Work through this list top to bottom — order matters.

---

## Day 1 — Account setup (30 min)

- [ ] Sign in at developer.apple.com with your Apple ID
- [ ] Enroll as an **Individual** (not Organisation) — faster, no D-U-N-S number needed
- [ ] Pay $99 — account activates within minutes to hours
- [ ] Verify your Apple ID has two-factor authentication enabled

---

## Day 1 — Certificates & identifiers (1 hour)

- [ ] **Register Bundle ID:** Identifiers → App IDs → + → App → `com.gissentanna.gyattchores`
  - Enable capabilities: App Groups (for Watch), Siri
- [ ] **Register Watch Bundle ID:** `com.gissentanna.gyattchores.watchkitapp`
- [ ] **Create Distribution Certificate:** Certificates → + → Apple Distribution → follow the CSR flow
- [ ] **Create Development Certificate:** Certificates → + → Apple Development
- [ ] **Register your test devices:** Devices → + → add iPhone and Watch UDIDs (Settings → General → About → copy)
- [ ] **Create App Store provisioning profile:** Profiles → + → App Store Distribution → select `com.gissentanna.gyattchores`
- [ ] **Create Watch provisioning profile:** same for `com.gissentanna.gyattchores.watchkitapp`

---

## Day 1 — App Store Connect setup (30 min)

- [ ] Sign in at appstoreconnect.apple.com
- [ ] Apps → + → New App
  - Platform: iOS
  - Name: **GyattChores**
  - Primary Language: English (U.S.)
  - Bundle ID: `com.gissentanna.gyattchores` (select from registered IDs)
  - SKU: `gyattchores-001` (internal only)
- [ ] Paste listing content from `app-store-metadata/listing.md`:
  - [ ] Subtitle
  - [ ] Promotional text
  - [ ] Description
  - [ ] Keywords
  - [ ] Support URL: `https://gyattchores.com`
  - [ ] Privacy Policy URL: `https://gyattchores.com/privacy`
- [ ] Upload screenshots (see `app-store-metadata/screenshots-spec.md`)
- [ ] Set App Review Notes (paste from `listing.md`)

---

## Day 2 — Xcode project setup (2–3 hours)

- [ ] Open Xcode → Create new project → App → SwiftUI → `com.gissentanna.gyattchores`
- [ ] Add existing source files from `GyattChoresApp/GyattChores/`:
  - `Models/Models.swift`
  - `Services/ChoreStore.swift`
  - `Views/HomeView.swift`
  - `Views/AdminView.swift`
  - `Views/ContentView.swift`
  - `Intents/LogChoreIntent.swift`
  - `GyattChoresApp.swift`
  - `Assets.xcassets/` (already has AppIcon Contents.json)
  - `PrivacyInfo.xcprivacy` ✅ (already in repo)
  - `Info.plist` ✅ (already in repo — merge keys into Xcode's generated plist)
- [ ] Add watchOS target: File → New → Target → Watch App
  - Add `GyattChoresApp/GyattChoresWatch/` sources
- [ ] Set deployment target: iOS 17.0
- [ ] Add Siri capability (Signing & Capabilities → + → Siri)
- [ ] Add App Groups capability (for shared UserDefaults with Watch)
- [ ] Set the AppIcon images (add the 1024×1024 PNG for iOS and watchOS)
- [ ] Commit the `.xcodeproj` to the repo

---

## Day 2 — First TestFlight build (1 hour)

- [ ] Product → Archive in Xcode
- [ ] Distribute App → App Store Connect → Upload
- [ ] In App Store Connect: TestFlight → select build → add internal testers (yourself)
- [ ] Install on your iPhone from TestFlight
- [ ] Run the smoke test from `docs/governance/change-enablement.md` §7.1
- [ ] Test on Apple Watch

---

## Day 3 — Submit for App Review

- [ ] App Store Connect → Pricing and Availability → Free · All territories
- [ ] Age Rating questionnaire (answers in `listing.md`)
- [ ] Content Rights: "Does not contain third-party content" → confirm
- [ ] Submit for Review
- [ ] Average review time: 1–3 days for first submission

---

## Keys to have ready (from the repo)

| Item | Value / Location |
|---|---|
| Bundle ID | `com.gissentanna.gyattchores` |
| App name | GyattChores |
| Privacy policy URL | `https://gyattchores.com/privacy` |
| Support URL | `https://gyattchores.com` |
| Admin PIN (review notes only) | `7874` — **change before v1.0 release** |
| Description | `app-store-metadata/listing.md` |
| Keywords | `app-store-metadata/listing.md` |
| Screenshots spec | `app-store-metadata/screenshots-spec.md` |
| Age rating | 4+ (no objectionable content) |

---

## Common first-submission rejections — pre-empt them

| Risk | Pre-emption |
|---|---|
| **Guideline 5.1.1 — Data collected** | Privacy policy URL is set; privacy nutrition labels match `PrivacyInfo.xcprivacy` (no data collected) |
| **Missing PrivacyInfo.xcprivacy** | File is in the repo and committed ✅ |
| **Guideline 2.1 — App completeness** | App Review notes explain the PIN and test flow |
| **Guideline 4.2 — Minimum functionality** | The approval workflow + Siri integration + Watch app establish differentiated functionality |
| **Broken link in metadata** | Ensure `gyattchores.com/privacy` returns 200 before submitting |
