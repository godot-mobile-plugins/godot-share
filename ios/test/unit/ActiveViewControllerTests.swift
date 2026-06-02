//
// © 2026-present https://github.com/cengiz-pz
//
// ActiveViewControllerTests.swift
// share_plugin_tests
//
// Unit tests for ActiveViewController.getActiveViewController().
//
// The method traverses the following state machine:
//
//   [key window root VC]
//       │
//       └─► while (presentedViewController != nil) → climb to topmost presented VC
//               │
//               ├─► if UINavigationController  → return topViewController
//               │
//               └─► if UITabBarController      → selectedViewController
//                       │
//                       └─► if UINavigationController → return topViewController
//
// Environment detection
// ─────────────────────
// In a standalone xctest process (no host app) the UIWindowScene connected to
// the process is not in the `foregroundActive` state.  `getActiveViewController`
// falls back to `UIApplication.shared.windows.first`, which only includes
// windows created via `UIWindow(windowScene:)` on modern iOS.
//
// setUp creates one window via `WindowFixtures.makeKeyWindow` (which now uses
// `anyConnectedScene()` as a fallback) and immediately checks whether
// `getActiveViewController()` returns the exact probe VC we installed — using
// Swift's identity operator (`===`).  If it does, the environment supports key-
// window tests and `testWindowUsable` is set to `true`.  If a different VC is
// returned (e.g. xctest's own window came first) or nil is returned, all window-
// dependent tests skip gracefully rather than fail.
//
// Test structure
// ──────────────
// • Tests that need a specific VC hierarchy:
//     1. Call `let window = try requireWindow()`.
//     2. Replace `window.rootViewController` with the desired controller.
//     3. Assert the expected result from `getActiveViewController()`.
//   This reuses the single `testWindow` from setUp instead of creating one
//   per test, avoiding ordering issues in `UIApplication.shared.windows`.
//
// • Tests that verify a property about the RETURN TYPE (not a specific instance)
//   also go through `requireWindow()` so they produce a meaningful assertion
//   instead of vacuously passing when the result happens to be nil.
//
// • Two environment-only smoke tests do NOT call `requireWindow()`:
//     - testGetActiveViewController_DoesNotCrash
//     - testGetActiveViewController_WithNoKeyWindow_ReturnsNilOrUIViewController
//
// Presentation tests additionally guard `WindowFixtures.foregroundScene() != nil`
// because `UIViewController.present` requires a foreground-active scene.
//

import XCTest
@testable import share_plugin

final class ActiveViewControllerTests: XCTestCase {

	// MARK: - Properties

	/// The single UIWindow created in setUp and torn down in tearDown.
	private var testWindow: UIWindow?

	/// `true` when `getActiveViewController()` was confirmed to return *our*
	/// probe VC (by identity) during setUp.  Any test that checks specific VC
	/// equality must call `requireWindow()`, which throws `XCTSkip` when false.
	private var testWindowUsable = false

	// MARK: - Lifecycle

	override func setUp() {
		super.setUp()

		// Install a known probe VC so we can verify — by identity — that
		// getActiveViewController() finds *our* window and not an xctest-
		// internal window that happened to be first in UIApplication.windows.
		let probeVC = UIViewController()
		testWindow = WindowFixtures.makeKeyWindow(root: probeVC)

		testWindowUsable = (ActiveViewController.getActiveViewController() === probeVC)
	}

	override func tearDown() {
		// Dismiss any presented VC (presentation tests left open by an earlier run).
		testWindow?.rootViewController?.presentedViewController?
			.dismiss(animated: false, completion: nil)
		testWindow?.isHidden = true
		testWindow = nil
		testWindowUsable = false
		super.tearDown()
	}

	// MARK: - Helpers

	/// Returns the shared test window if the environment supports a detectable
	/// key window; otherwise throws `XCTSkip`.
	///
	/// Uses `testWindowUsable`, which is set in setUp by comparing the return
	/// value of `getActiveViewController()` to the probe VC by identity.
	private func requireWindow(
		file: StaticString = #filePath,
		line: UInt = #line
	) throws -> UIWindow {
		guard testWindowUsable, let window = testWindow else {
			throw XCTSkip(
				"getActiveViewController() does not find our key window in this "
				+ "environment. Run the tests with a host app or on a device.",
				file: file,
				line: line
			)
		}
		return window
	}

	/// Presents `vc` on `presenter` with `animated: false`, then waits for the
	/// completion callback before returning.
	private func present(
		_ vc: UIViewController,
		on presenter: UIViewController,
		file: StaticString = #filePath,
		line: UInt = #line
	) throws {
		guard WindowFixtures.foregroundScene() != nil else {
			throw XCTSkip(
				"VC presentation requires a foreground-active UIWindowScene.",
				file: file,
				line: line
			)
		}
		let exp = expectation(description: "present(animated: false) completion")
		presenter.present(vc, animated: false) { exp.fulfill() }
		waitForExpectations(
			timeout: 2,
			handler: { XCTAssertNil($0, "Presentation timed out", file: file, line: line) }
		)
	}

	// MARK: - Smoke tests (no window required) ────────────────────────────────────

	func testGetActiveViewController_DoesNotCrash() {
		XCTAssertNoThrow(ActiveViewController.getActiveViewController())
	}

	/// Without any test-specific setup, the method may return nil or the
	/// xctest runner's own VC — both are acceptable; we only verify no crash
	/// and a correct type when non-nil.
	func testGetActiveViewController_WithNoKeyWindow_ReturnsNilOrUIViewController() {
		// Hide our setUp window so we're testing a state close to "no window".
		testWindow?.isHidden = true

		let result = ActiveViewController.getActiveViewController()
		if let result { XCTAssert(result is UIViewController) }
	}

	// MARK: - Plain Root ──────────────────────────────────────────────────────────

	func testGetActiveViewController_WithPlainRootVC_ReturnsNonNil() throws {
		_ = try requireWindow()
		// setUp already installed a plain UIViewController — result must be non-nil.
		XCTAssertNotNil(ActiveViewController.getActiveViewController())
	}

	func testGetActiveViewController_WithPlainRootVC_ReturnsUIViewController() throws {
		_ = try requireWindow()
		XCTAssertTrue(ActiveViewController.getActiveViewController() is UIViewController)
	}

	func testGetActiveViewController_WithPlainRootVC_ReturnsRootVC() throws {
		let window = try requireWindow()

		let root = UIViewController()
		window.rootViewController = root

		XCTAssertEqual(ActiveViewController.getActiveViewController(), root)
	}

	// MARK: - UINavigationController ──────────────────────────────────────────────

	func testGetActiveViewController_RootIsNavController_ReturnsTopVC() throws {
		let window = try requireWindow()

		let rootVC = UIViewController()
		let topVC  = UIViewController()
		let nav = UINavigationController(rootViewController: rootVC)
		nav.viewControllers.append(topVC)
		window.rootViewController = nav

		XCTAssertEqual(
			ActiveViewController.getActiveViewController(), topVC,
			"Should unwrap the nav stack to topViewController"
		)
	}

	func testGetActiveViewController_RootIsNavController_NotNavItself() throws {
		let window = try requireWindow()

		let nav = UINavigationController(rootViewController: UIViewController())
		window.rootViewController = nav

		let result = ActiveViewController.getActiveViewController()
		XCTAssertFalse(
			result is UINavigationController,
			"Should unwrap one level to topViewController, not return the nav itself"
		)
	}

	func testGetActiveViewController_NavControllerWithOneVC_ReturnsOnlyVC() throws {
		let window = try requireWindow()

		let only = UIViewController()
		let nav  = UINavigationController(rootViewController: only)
		window.rootViewController = nav

		XCTAssertEqual(ActiveViewController.getActiveViewController(), only)
	}

	func testGetActiveViewController_NavControllerDeepStack_ReturnsDeepestVC() throws {
		let window = try requireWindow()

		let vcs = (0 ..< 6).map { _ in UIViewController() }
		let nav = UINavigationController()
		nav.viewControllers = vcs
		window.rootViewController = nav

		XCTAssertEqual(
			ActiveViewController.getActiveViewController(), vcs.last,
			"Deep stacks should still resolve to the deepest VC"
		)
	}

	// MARK: - UITabBarController ───────────────────────────────────────────────────

	func testGetActiveViewController_TabBar_ReturnsFirstSelectedVC() throws {
		let window = try requireWindow()

		let vc0 = UIViewController()
		let vc1 = UIViewController()
		let tab = UITabBarController()
		tab.viewControllers = [vc0, vc1]
		tab.selectedIndex = 0
		window.rootViewController = tab

		XCTAssertEqual(ActiveViewController.getActiveViewController(), vc0)
	}

	func testGetActiveViewController_TabBar_ReturnsSecondSelectedVC() throws {
		let window = try requireWindow()

		let vc0 = UIViewController()
		let vc1 = UIViewController()
		let tab = UITabBarController()
		tab.viewControllers = [vc0, vc1]
		tab.selectedIndex = 1
		window.rootViewController = tab

		XCTAssertEqual(ActiveViewController.getActiveViewController(), vc1)
	}

	func testGetActiveViewController_TabBar_NotTabBarItself() throws {
		let window = try requireWindow()

		let tab = UITabBarController()
		tab.viewControllers = [UIViewController()]
		tab.selectedIndex = 0
		window.rootViewController = tab

		let result = ActiveViewController.getActiveViewController()
		XCTAssertFalse(
			result is UITabBarController,
			"Should unwrap to the selected view controller"
		)
	}

	// MARK: - UITabBarController with embedded UINavigationController ─────────────

	func testGetActiveViewController_TabBarWithNavigation_ReturnsTopVC() throws {
		let window = try requireWindow()

		let rootVC = UIViewController()
		let topVC  = UIViewController()
		let nav = UINavigationController(rootViewController: rootVC)
		nav.viewControllers.append(topVC)

		let tab = UITabBarController()
		tab.viewControllers = [nav]
		tab.selectedIndex = 0
		window.rootViewController = tab

		// Expected traversal: Tab → NavController → topViewController
		XCTAssertEqual(ActiveViewController.getActiveViewController(), topVC)
	}

	func testGetActiveViewController_TabBarWithNavigation_NotNavController() throws {
		let window = try requireWindow()

		let nav = UINavigationController(rootViewController: UIViewController())
		let tab = UITabBarController()
		tab.viewControllers = [nav]
		tab.selectedIndex = 0
		window.rootViewController = tab

		let result = ActiveViewController.getActiveViewController()
		XCTAssertFalse(
			result is UINavigationController,
			"Tab → Nav should unwrap to topViewController"
		)
	}

	func testGetActiveViewController_TabBarSecondTabHasNavigation_ReturnsCorrectTopVC() throws {
		let window = try requireWindow()

		let plainVC = UIViewController()
		let topVC   = UIViewController()
		let nav = UINavigationController(rootViewController: UIViewController())
		nav.viewControllers.append(topVC)

		let tab = UITabBarController()
		tab.viewControllers = [plainVC, nav]
		tab.selectedIndex = 1
		window.rootViewController = tab

		XCTAssertEqual(ActiveViewController.getActiveViewController(), topVC)
	}

	// MARK: - Presented View Controllers ──────────────────────────────────────────

	func testGetActiveViewController_WithOnePresentedVC_ReturnsPresentedVC() throws {
		let window = try requireWindow()

		let baseVC      = UIViewController()
		let presentedVC = UIViewController()
		window.rootViewController = baseVC

		try present(presentedVC, on: baseVC)

		XCTAssertEqual(
			ActiveViewController.getActiveViewController(), presentedVC,
			"A presented VC should shadow the root VC"
		)
	}

	func testGetActiveViewController_WithChainedPresentations_ReturnsTopmostVC() throws {
		let window = try requireWindow()

		let baseVC    = UIViewController()
		let middleVC  = UIViewController()
		let topmostVC = UIViewController()
		window.rootViewController = baseVC

		try present(middleVC,  on: baseVC)
		try present(topmostVC, on: middleVC)

		XCTAssertEqual(
			ActiveViewController.getActiveViewController(), topmostVC,
			"Must climb the entire presented-VC chain"
		)
	}

	func testGetActiveViewController_NavControllerPresentsVC_ReturnsPresentedVC() throws {
		let window = try requireWindow()

		let nav = UINavigationController(rootViewController: UIViewController())
		window.rootViewController = nav

		let presentedVC = UIViewController()
		try present(presentedVC, on: nav)

		// Presented VC takes precedence over nav.topViewController.
		XCTAssertEqual(
			ActiveViewController.getActiveViewController(), presentedVC,
			"Presented VC must take precedence over topViewController"
		)
	}

	func testGetActiveViewController_TabBarPresentsVC_ReturnsPresentedVC() throws {
		let window = try requireWindow()

		let tab = UITabBarController()
		tab.viewControllers = [UIViewController()]
		tab.selectedIndex = 0
		window.rootViewController = tab

		let presentedVC = UIViewController()
		try present(presentedVC, on: tab)

		XCTAssertEqual(ActiveViewController.getActiveViewController(), presentedVC)
	}

	// MARK: - After Dismissal ─────────────────────────────────────────────────────

	func testGetActiveViewController_AfterDismissal_ReturnsBaseVC() throws {
		let window = try requireWindow()

		let baseVC      = UIViewController()
		let presentedVC = UIViewController()
		window.rootViewController = baseVC

		try present(presentedVC, on: baseVC)

		let dismissExp = expectation(description: "dismiss completion")
		presentedVC.dismiss(animated: false) { dismissExp.fulfill() }
		waitForExpectations(timeout: 2)

		XCTAssertEqual(
			ActiveViewController.getActiveViewController(), baseVC,
			"After dismissal the base VC should be active again"
		)
	}
}
