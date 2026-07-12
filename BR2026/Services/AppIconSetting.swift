import UIKit

@MainActor
protocol AppIconSetting {
    var currentIconName: String? { get }
    func setIconName(_ name: String?) async throws
}

@MainActor
final class UIKitAppIconSetting: AppIconSetting {
    var currentIconName: String? { UIApplication.shared.alternateIconName }

    func setIconName(_ name: String?) async throws {
        try await UIApplication.shared.setAlternateIconName(name)
    }
}
