import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override init() {
    super.init()
    if AppRelocator.relocateAndRelaunchIfNeeded() {
      exit(0)
    }
  }

  override func applicationWillFinishLaunching(_ notification: Notification) {
    if AppRelocator.relocateAndRelaunchIfNeeded() {
      exit(0)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
