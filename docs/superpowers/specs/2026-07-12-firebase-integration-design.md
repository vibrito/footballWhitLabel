# Firebase Integration Design

**Goal:** Add Firebase Analytics (automatic collection only, no custom events) and Firebase
Crashlytics for metrics/crash reporting, plus Firebase Cloud Messaging scaffolding for a future
push-notification phase — wired up but never requesting notification permission or showing any
push UI yet.

**Architecture:** This is the app's first external dependency (`CLAUDE.md`'s Tech Stack
currently states "External dependencies: None"). The Firebase iOS SDK is added via Swift
Package Manager, integrated into `project.pbxproj` with a one-off Ruby script using the
`xcodeproj` gem (already present as a transitive dependency of `fastlane`, confirmed installed
at 1.28.1) rather than hand-editing the project file — SPM package integration touches far more
of the object graph (a package reference, three product dependencies, framework-phase entries)
than the single-file wiring this project has done so far, and the gem guarantees referential
integrity where manual text editing doesn't. `ChampionshipApp` (SwiftUI-only today, no
`AppDelegate`) gains a small bridged `AppDelegate` via `@UIApplicationDelegateAdaptor` — Apple's
standard pattern for combining SwiftUI's app lifecycle with Firebase's UIKit-shaped setup and
push-notification callbacks.

## Package Integration

`firebase-ios-sdk` added as a remote Swift package, pinned `upToNextMajorVersion` from `12.0.0`
(current latest release: `12.16.0`, confirmed via the GitHub releases API). Three products
linked to the `BR2026` app target only (not the test targets, which don't need Firebase):
- `FirebaseAnalytics`
- `FirebaseCrashlytics`
- `FirebaseMessaging`

(`FirebaseCore` is a transitive dependency of all three, not selected separately.)

Performed via a Ruby script using the `xcodeproj` gem's object model — `XCRemoteSwiftPackageReference`
for the package, `XCSwiftPackageProductDependency` per product, each added to the target's
`package_product_dependencies` and to a `PBXBuildFile` (with `product_ref`, no `file_ref`) in
the target's `frameworks_build_phase.files`. This mirrors how an earlier task in this project's
history already used the `xcodeproj` gem for a different pbxproj change ("Xcode project file
updated via programmatic xcodeproj gem (safe, repeatable)").

## `GoogleService-Info.plist`

Committed directly to the repo at `BR2026/GoogleService-Info.plist` (per your decision — Google's
own guidance is this file isn't a traditional secret, unlike `Secrets.xcconfig`'s football API
key). Confirmed valid and already scoped to this app: `BUNDLE_ID` matches `com.vibrito.br2026`.
Wired as a **Resources** build phase entry (not Sources — it's a data file, not code), with the
matching `PBXFileReference`/group-children/build-phase entries.

## App Lifecycle

New `BR2026/App/AppDelegate.swift`:

```swift
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        // Silent registration: this hands the app an APNs token (below) and lets Firebase
        // mint an FCM token, without ever prompting the user for permission. No permission
        // means no visible alert/banner can show — that's a separate, later step once an
        // actual push-notification feature exists to justify asking.
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // No consumer yet — this is scaffolding. A future push-notification phase reads this.
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {}
```

`ChampionshipApp` gains:
```swift
@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
```

## Capabilities

New `BR2026/BR2026.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
</dict>
</plist>
```
(Xcode's signing pipeline automatically substitutes `production` for TestFlight/App Store
archives based on the distribution certificate — a single checked-in `development` value is
correct and standard, not something that needs per-configuration branching.)

Wired via a new `CODE_SIGN_ENTITLEMENTS = BR2026/BR2026.entitlements` build setting (both Debug
and Release app-target configs, alongside the existing `ASSETCATALOG_COMPILER_APPICON_NAME`
etc.).

`Generated/BR2026-Info.plist` gains:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```
This enables silent/data-only push delivery in the background — distinct from user-visible
alerts, which still require permission this design deliberately never requests.

## Crashlytics Symbol Upload

A new Run Script build phase on the app target (Firebase's documented path for SPM-based
integrations):
```bash
"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```
Without this, crashes still reach the Firebase console but without symbolicated stack traces.

## Privacy Policy Website (All 5 Locales)

The current claim in Section 2 ("This app does not use analytics, advertising, or tracking
software of any kind") becomes false the moment this ships and must change. Canonical English
replacement (all 5 locales get full, equivalent translated text in the implementation plan,
matching the pattern already established for this website — not English-with-a-note):

```
2. Analytics and Tracking
This app uses Firebase Analytics and Firebase Crashlytics (both provided by Google) to
understand how the app is used and to diagnose crashes. Firebase Analytics collects
general usage data such as which screens are viewed and how often the app is opened;
Firebase Crashlytics collects crash reports, which may include device model, OS version,
and app state at the time of the crash. Neither service is used for advertising, and
neither collects your name, email, or other personally identifying information.
```

Section 3 ("Third-Party Services") gains a sentence naming Firebase alongside the existing
sports-data-API disclosure:

```
3. Third-Party Services
Match, team, and competition data (including team crest images) is loaded from a
third-party sports data API. This app also uses Firebase (Google) for analytics and
crash reporting, as described above. Loading data from these services may expose your
device's IP address to them, as is standard for any network request. We do not control
and are not responsible for these services' own data practices.
```

The in-app Terms of Service is unaffected — it never made a no-analytics claim (that claim
lives only in the website's Privacy Policy, per the existing split where Privacy Policy is
"out of scope for the in-app screen" per CLAUDE.md).

**Out of scope for this design:** App Store Connect's App Privacy questionnaire (the "nutrition
label") is a manual App Store Connect console step, not a code change — flagged here so it isn't
forgotten before actual submission, the same way earlier legal-copy specs flagged counsel review.

## CLAUDE.md

- **Tech Stack** table: "External dependencies: None" → "Firebase (Analytics, Crashlytics,
  Messaging) via SPM — first external dependency; see Firebase section" (or similar), with a new
  short section documenting the SPM package, the three products, and the
  `xcodeproj`-gem-scripted integration approach for future maintainers who need to add another
  Firebase product later.
- **Scope** section: add a line clarifying that Messaging is wired up (APNs registration, FCM
  token generation) but no permission is requested and no push-consuming feature exists —
  the existing "no notifications" scope boundary still holds at the user-facing feature level,
  this is plumbing only.

## Testing

No new automated tests: `AppDelegate` is thin glue code with no business logic to unit test
(consistent with CLAUDE.md's "unit test ViewModels and Services — not Views," and `AppDelegate`
is even further from testable logic than a View). Verification is a real build + a manual
Simulator run confirming Firebase initializes without crashing and (if visible in Xcode's
console/Firebase debug view) an FCM token is generated.

## Out of Scope

- Any custom `Analytics.logEvent(...)` calls — automatic collection only, per your choice.
- Requesting notification permission (`UNUserNotificationCenter.requestAuthorization`).
- Any push-notification-consuming UI or business logic.
- App Store Connect's App Privacy questionnaire (manual, flagged above).
- CI/fastlane changes for Crashlytics dSYM upload automation beyond the local Run Script phase
  (e.g., a dedicated `upload_symbols` fastlane action) — the Run Script phase alone is
  sufficient for this phase.
