import AppKit

FlowSoundDiagnostics.log("main started")

let app = NSApplication.shared
let delegate = FlowSoundApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
FlowSoundDiagnostics.log("starting NSApplication.run")
app.run()
