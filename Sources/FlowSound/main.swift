import AppKit

if CommandLine.arguments.count == 3, CommandLine.arguments[1] == MusicAutomationScript.helperArgument {
    // The signed app's short-lived automation child has no menu bar or capture session.
    var error: NSDictionary?
    guard let command = NeteaseScriptCommand(rawValue: CommandLine.arguments[2]),
          let script = NSAppleScript(source: command.source) else { exit(1) }
    let result = script.executeAndReturnError(&error)
    if let error {
        let message = (error[NSAppleScript.errorMessage] as? String) ?? error.description
        FileHandle.standardError.write(Data(message.utf8))
        exit(1)
    }
    print(result.stringValue ?? "")
    exit(0)
}

FlowSoundDiagnostics.log("main started")

let app = NSApplication.shared
let delegate = FlowSoundApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
FlowSoundDiagnostics.log("starting NSApplication.run")
app.run()
