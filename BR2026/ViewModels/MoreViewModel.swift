import Foundation
import Observation

@Observable
final class MoreViewModel {
    let sections: [MoreSection] = [
        MoreSection(
            id: "legal",
            titleKey: "Legal",
            rows: [
                MoreRow(
                    id: "termsOfService",
                    titleKey: "Terms of Service",
                    systemImage: "doc.text",
                    destination: .termsOfService,
                    isEnabled: true
                )
            ]
        ),
        MoreSection(
            id: "preferences",
            titleKey: "Preferences",
            rows: [
                MoreRow(
                    id: "settings",
                    titleKey: "Settings",
                    systemImage: "gearshape",
                    destination: nil,
                    isEnabled: false
                ),
                MoreRow(
                    id: "inAppPurchases",
                    titleKey: "In-App Purchases",
                    systemImage: "cart",
                    destination: nil,
                    isEnabled: false
                )
            ]
        )
    ]
}
