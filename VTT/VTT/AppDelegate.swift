import Cocoa
import ApplicationServices
import os.log

private let log = Logger(subsystem: "com.jsglazer.VTT", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: VTTController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("applicationDidFinishLaunching")
        print("VTT: applicationDidFinishLaunching")

        let trusted = AXIsProcessTrusted()
        print("VTT: accessibility trusted = \(trusted)")
        if !trusted {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(opts as CFDictionary)
        }

        controller = VTTController()
        Task { await controller?.loadModel() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
