import Foundation
import ServiceManagement

enum LoginItemController {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusText: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            "Launch at login is enabled."
        case .notRegistered:
            "Launch at login is disabled."
        case .requiresApproval:
            "Launch at login requires approval in System Settings."
        case .notFound:
            "Launch at login is unavailable for this build."
        @unknown default:
            "Launch at login status is unknown."
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status != .notRegistered {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
