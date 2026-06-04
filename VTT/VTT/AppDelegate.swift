import Cocoa
import ApplicationServices
import os.log

private let log = Logger(subsystem: "com.jsglazer.VTT", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: VTTController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("applicationDidFinishLaunching")
        print("VTT: applicationDidFinishLaunching")

        controller = VTTController()
        Task { await controller?.loadModel() }

        if !AXIsProcessTrusted() {
            print("VTT: accessibility trusted = false — showing prompt")
            DispatchQueue.main.async { self.showAccessibilityAlert() }
        } else {
            print("VTT: accessibility trusted = true")
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
            VTT needs Accessibility permission to type into other apps (Sublime Text, Drafts, etc.).

            Click "Open Settings", enable VTT under Privacy & Security → Accessibility, then restart VTT.

            Note: after every Clean Build you must re-grant this permission.
            """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(opts as CFDictionary)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
