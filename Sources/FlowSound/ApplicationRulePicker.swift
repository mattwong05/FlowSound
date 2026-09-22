import AppKit
import UniformTypeIdentifiers

@MainActor
enum ApplicationRulePicker {
    static func chooseApplications(for window: NSWindow, completion: @escaping ([String]) -> Void) {
        let panel = NSOpenPanel()
        panel.title = FlowSoundStrings.text(.chooseApplications)
        panel.prompt = FlowSoundStrings.text(.addApplications)
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.beginSheetModal(for: window) { response in
            guard response == .OK else { return }
            let identifiers = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
            let valid = FlowSoundSettings.normalizedBundleIdentifiers(identifiers)
            guard identifiers.count == panel.urls.count,
                  identifiers.allSatisfy({ FlowSoundSettings.normalizedBundleIdentifiers([$0]).count == 1 }) else {
                let alert = NSAlert()
                alert.messageText = FlowSoundStrings.text(.chooseApplications)
                alert.informativeText = FlowSoundStrings.text(.applicationMissingIdentifier)
                alert.beginSheetModal(for: window)
                return
            }
            completion(valid)
        }
    }

}
