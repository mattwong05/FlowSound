import Foundation
import ServiceManagement

enum LoginItemController {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var isEnabledOrPendingApproval: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            true
        case .notRegistered, .notFound:
            false
        @unknown default:
            false
        }
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
            "Launch at login is not registered for this build."
        @unknown default:
            "Launch at login status is unknown."
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        switch (enabled, service.status) {
        case (true, .notRegistered), (true, .notFound):
            try service.register()
        case (true, .enabled), (true, .requiresApproval):
            break
        case (false, .enabled), (false, .requiresApproval):
            try service.unregister()
        case (false, .notRegistered), (false, .notFound):
            break
        @unknown default:
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
