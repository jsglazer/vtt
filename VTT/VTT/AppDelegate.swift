import Cocoa
import os.log

private let log = Logger(subsystem: "com.jsglazer.VTT", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: VTTController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("applicationDidFinishLaunching")
        print("VTT: applicationDidFinishLaunching")
        controller = VTTController()
        Task { await controller?.loadModel() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
