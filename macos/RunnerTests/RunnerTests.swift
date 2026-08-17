import Cocoa
import XCTest
@testable import gnfp_wallet

final class RunnerTests: XCTestCase {
  func testCrashLogPathIsEphemeral() {
    let crash =
      "/private/var/folders/xx/yyyy/T/AppTranslocation/UUID/d/gnfp_wallet.app/Contents/MacOS/gnfp_wallet"
    XCTAssertTrue(AppRelocator.isEphemeralLaunchPath(crash))
    XCTAssertTrue(AppRelocator.shouldRelocate(crash))
    XCTAssertFalse(AppRelocator.isInstalledInApplications(crash))
  }

  func testApplicationsInstallIsStable() {
    let path = "/Applications/GNFP Wallet.app/Contents/MacOS/gnfp_wallet"
    XCTAssertFalse(AppRelocator.isEphemeralLaunchPath(path))
    XCTAssertFalse(AppRelocator.shouldRelocate(path))
    XCTAssertTrue(AppRelocator.isInstalledInApplications(path))
  }

  func testDmgVolumeIsEphemeral() {
    let path = "/Volumes/GNFP Wallet/GNFP Wallet.app/Contents/MacOS/gnfp_wallet"
    XCTAssertTrue(AppRelocator.isEphemeralLaunchPath(path))
    XCTAssertTrue(AppRelocator.shouldRelocate(path))
  }

  func testFlutterTesterIsNotAnApp() {
    XCTAssertFalse(AppRelocator.isEphemeralLaunchPath("/var/folders/xx/flutter_tester"))
    XCTAssertFalse(AppRelocator.shouldRelocate("/var/folders/xx/flutter_tester"))
  }

  func testReleaseBuildProductsAreNotRelocated() {
    let path =
      "/Users/rus/gnfp-wallet/build/macos/Build/Products/Release/gnfp_wallet.app/Contents/MacOS/gnfp_wallet"
    XCTAssertFalse(AppRelocator.shouldRelocate(path))
  }
}
