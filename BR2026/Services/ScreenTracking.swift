import SwiftUI
import FirebaseAnalytics

extension View {
    /// Firebase's automatic screen_view tracking relies on swizzling UIViewController
    /// lifecycle methods, which SwiftUI's non-UIKit-backed view hierarchy never triggers —
    /// so each top-level screen logs its own screen_view event explicitly on appear.
    func trackScreen(_ name: String) -> some View {
        onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: name,
                AnalyticsParameterScreenClass: name
            ])
        }
    }
}
