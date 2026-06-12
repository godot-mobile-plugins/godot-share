//
// © 2026-present https://github.com/cengiz-pz
//
// ShareFixtures.swift
// share_plugin_tests
//
// Shared test data, factory helpers, and UIKit scaffolding used across the
// entire share plugin test suite.
//
// IMPORTANT — SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY
// ------------------------------------------------------------
// This target has SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES, which
// enforces Swift 6-style per-file imports.  A @testable import in ShareTests.swift
// does NOT make `Share` or `ActiveViewController` visible here.  This file must
// carry its own @testable import share_plugin.
//

import Foundation
@testable import share_plugin
import UIKit

// MARK: - String / MIME constants -------------------------------------------------

/// Canonical strings re-used by every test file.
///
/// Centralising them here means a single change propagates everywhere and avoids
/// the silent divergence that comes from duplicating string literals.
enum ShareTestData {

	// MARK: Content
	static let title    = "Godot Share Plugin Test"
	static let subject  = "Unit-test subject line"
	static let content  = "Hello from the iOS Share Plugin 🎮"

	// MARK: MIME types
	static let plainMime  = "text/plain"
	static let imageMime  = "image/png"
	static let imageWild  = "image/*"
	static let pdfMime    = "application/pdf"
	static let binaryMime = "application/octet-stream"

	// MARK: Error messages (mirrors literals in Share.swift)
	//
	// Keep these in sync with Share.swift.  If the messages ever change, the
	// compiler will not catch the divergence, but the tests will fail loudly.
	static let noItemsError    = "No items to share"
	static let noActiveVCError = "No active view controller found"
}

// MARK: - Share fixture factory ---------------------------------------------------

/// Pre-built ``Share`` configurations that cover common test scenarios.
///
/// Using named factory methods instead of inline `Share(...)` calls keeps
/// individual tests focused on behaviour rather than on construction details.
@available(iOS 16.0, *)
enum ShareFixtures {

	/// All-nil ``Share``.  ``Share/share(completionHandler:)`` will fail with
	/// ``ShareTestData/noItemsError`` (or ``ShareTestData/noActiveVCError`` in a
	/// headless environment where no key window exists).
	static func empty() -> Share { Share() }

	/// ``Share`` carrying only a text body.
	static func text(_ string: String = ShareTestData.content) -> Share {
		Share(content: string)
	}

	/// ``Share`` with title, subject, and body text all populated.
	static func fullText() -> Share {
		Share(
			title: ShareTestData.title,
			subject: ShareTestData.subject,
			content: ShareTestData.content
		)
	}

	/// ``Share`` pointing at a local file using a bare filesystem path.
	///
	/// - Parameters:
	///   - path: Absolute filesystem path — **without** a `file://` prefix.
	///   - mime: MIME type string; defaults to ``ShareTestData/plainMime``.
	static func file(path: String, mime: String = ShareTestData.plainMime) -> Share {
		Share(filePath: path, mimeType: mime)
	}

	/// ``Share`` pointing at a local file using a `file://` URI, mirroring the
	/// format that Godot passes to the plugin at runtime.
	///
	/// - Parameters:
	///   - localPath: Absolute filesystem path — the `file://` prefix is added here.
	///   - mime: MIME type string; defaults to ``ShareTestData/plainMime``.
	static func fileUri(localPath: String, mime: String = ShareTestData.plainMime) -> Share {
		Share(filePath: "file://\(localPath)", mimeType: mime)
	}
}

// MARK: - Temporary file helpers --------------------------------------------------

/// Creates short-lived files in the system's temporary directory.
///
/// Every returned `URL` must be deleted by the caller in `tearDown` to prevent
/// tmp directory pollution across test runs.
enum TempFileFixtures {

	/// Writes a UTF-8 text file and returns its `URL`.
	///
	/// - Parameter body: File body text.
	/// - Returns: `URL` of the newly created file.
	/// - Throws: `Error` if writing fails.
	static func makeText(body: String = "share plugin test fixture\n") throws -> URL {
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent("sp_\(UUID().uuidString).txt")
		try body.write(to: url, atomically: true, encoding: .utf8)
		return url
	}

	/// Creates a 2 × 2 blue PNG and returns its `URL`.
	///
	/// Using the smallest possible valid image keeps test execution fast and
	/// avoids unnecessary disk pressure in CI.
	///
	/// - Returns: `URL` of the newly created PNG file.
	/// - Throws: `Error` if rendering or writing fails.
	static func makeImage() throws -> URL {
		let size = CGSize(width: 2, height: 2)
		let url  = FileManager.default.temporaryDirectory
			.appendingPathComponent("sp_\(UUID().uuidString).png")
		let renderer = UIGraphicsImageRenderer(size: size)
		let data = renderer.pngData { ctx in
			UIColor.systemBlue.setFill()
			ctx.fill(CGRect(origin: .zero, size: size))
		}
		try data.write(to: url)
		return url
	}
}

// MARK: - UIWindow / UIWindowScene helpers ----------------------------------------

/// Factory and scene-inspection utilities for constructing a minimal UIKit
/// environment inside each test case.
enum WindowFixtures {

	// MARK: Scene accessors

	/// Returns the first foreground-active `UIWindowScene`, or `nil` when none
	/// exists (e.g. in a standalone xctest process on modern iOS).
	static func foregroundScene() -> UIWindowScene? {
		UIApplication.shared.connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.first { $0.activationState == .foregroundActive }
	}

	/// Returns *any* connected `UIWindowScene` regardless of its activation state.
	///
	/// A standalone `xctest` process on iOS 16+ has a connected scene that is
	/// not in the `foregroundActive` state.  Windows created via
	/// `UIWindow(windowScene:)` with this scene are properly registered in
	/// `UIApplication.shared.windows`, making them visible to
	/// `ActiveViewController.getActiveViewController()`.  Without a scene
	/// association, a `UIWindow(frame:)` is invisible to that API on modern iOS.
	static func anyConnectedScene() -> UIWindowScene? {
		UIApplication.shared.connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.first
	}

	// MARK: Window factory

	/// Creates a `UIWindow`, sets `root` as its `rootViewController`, and makes
	/// the window key and visible.
	///
	/// Scene selection order:
	///   1. `foregroundScene()` — preferred when a host app is running.
	///   2. `anyConnectedScene()` — fallback for standalone xctest processes where
	///      the scene exists but is not in the `foregroundActive` state.
	///   3. `UIWindow(frame:)` — last resort for truly headless environments.
	///
	/// A short run-loop pass is executed after `makeKeyAndVisible()` to allow
	/// UIKit to propagate the key-window change before callers inspect it.
	///
	/// - Parameter root: Root view controller.  Defaults to a plain `UIViewController`.
	/// - Returns: The configured `UIWindow`.  Call `window.isHidden = true` in
	///   `tearDown` to restore state between tests.
	@discardableResult
	static func makeKeyWindow(root: UIViewController = UIViewController()) -> UIWindow {
		let window: UIWindow
		if let scene = foregroundScene() ?? anyConnectedScene() {
			window = UIWindow(windowScene: scene)
		} else {
			window = UIWindow(frame: UIScreen.main.bounds)
		}
		window.rootViewController = root
		window.makeKeyAndVisible()
		// Allow UIKit to process the key-window change synchronously.
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
		return window
	}
}
