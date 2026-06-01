import Cocoa

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: VTTController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = VTTController()
        Task { await controller?.loadModel() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
