import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    // The nib creates this window before FlutterAppDelegate finishes launching.
    // Relocate before Flutter maps the engine off a temp / DMG vnode.
    if AppRelocator.relocateAndRelaunchIfNeeded() {
      exit(0)
    }

    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
