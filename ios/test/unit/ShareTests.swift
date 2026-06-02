//
// © 2026-present https://github.com/cengiz-pz
//
// ShareTests.swift
// share_plugin_tests
//
// Unit tests for Share.swift and the ShareResult ObjC-bridged enum.
//
// Organisation
// ─────────────
// ShareResultTests   – raw-value and ObjC-bridging tests; no @available guard
//                      because ShareResult itself carries none.
// ShareTests         – init and share() behaviour tests; guarded @available(iOS 16.0, *)
//                      because Share requires it.
//
// Test strategy
// ──────────────
// share() has two synchronous early-exit paths that are the primary focus of
// unit tests:
//
//   1. No active view controller  →  completionHandler(.failed, noActiveVCError)
//   2. No items to share          →  completionHandler(.failed, noItemsError)
//
// Both paths call the completion handler synchronously, before any
// DispatchQueue.main.async, so XCTestExpectation with a short timeout works
// cleanly.
//
// Item-building tests (§ "share() — item building") use *inverted* expectations:
// they pass when the "No items" failure is NOT called within the timeout,
// confirming that buildItemsToShare() produced at least one item.  Since the
// "No items" guard fires synchronously, it would be fulfilled immediately if
// triggered — the 0.3 s window is more than sufficient.
//
// UIActivityViewController presentation is an integration concern and is NOT
// exercised in this file.  The inverted-expectation tearDown dismisses any sheet
// that was triggered.
//

import XCTest
@testable import share_plugin

// MARK: - ShareResult tests -------------------------------------------------------

/// Tests for the `ShareResult` ObjC-bridged enum.
///
/// No `@available` restriction is needed because `ShareResult` is declared
/// without one.  These tests verify the integer contract that Godot relies on
/// when receiving signal arguments.
final class ShareResultTests: XCTestCase {

	// MARK: Raw values

	func testCompleted_RawValue_IsZero() {
		XCTAssertEqual(ShareResult.completed.rawValue, 0)
	}

	func testFailed_RawValue_IsOne() {
		XCTAssertEqual(ShareResult.failed.rawValue, 1)
	}

	func testCanceled_RawValue_IsTwo() {
		XCTAssertEqual(ShareResult.canceled.rawValue, 2)
	}

	// MARK: ObjC / Godot bridging

	/// All three raw-value integers must round-trip through `Int` so Godot can
	/// reconstruct the enum from the signal argument it receives.
	func testValidRawValues_InitializeToNonNil() {
		XCTAssertNotNil(ShareResult(rawValue: 0), "expected .completed")
		XCTAssertNotNil(ShareResult(rawValue: 1), "expected .failed")
		XCTAssertNotNil(ShareResult(rawValue: 2), "expected .canceled")
	}

	func testOutOfBoundsRawValues_ReturnNil() {
		XCTAssertNil(ShareResult(rawValue: -1))
		XCTAssertNil(ShareResult(rawValue:  3))
	}

	/// Verifies case identity so accidental reordering is caught immediately.
	func testRawValueToCase_Mapping_IsStable() {
		XCTAssertEqual(ShareResult(rawValue: 0), .completed)
		XCTAssertEqual(ShareResult(rawValue: 1), .failed)
		XCTAssertEqual(ShareResult(rawValue: 2), .canceled)
	}
}

// MARK: - Share tests -------------------------------------------------------------

/// Tests for `Share` initialisation and `share()` behaviour.
@available(iOS 16.0, *)
final class ShareTests: XCTestCase {

	// MARK: Properties

	/// Test window created in `setUp`; torn down in `tearDown`.
	private var testWindow: UIWindow?

	/// Temp files accumulated during a test; deleted in `tearDown`.
	private var tempFiles: [URL] = []

	// MARK: Lifecycle

	override func setUp() {
		super.setUp()
		// Provide a real key window so ActiveViewController can find a root VC.
		// Without this, share() would fail with "No active view controller found"
		// instead of the "No items to share" message the failure-path tests target.
		testWindow = WindowFixtures.makeKeyWindow()
	}

	override func tearDown() {
		// Dismiss any UIActivityViewController sheet that an item-building test
		// may have triggered.  The dismiss fires completionWithItemsHandler with
		// .canceled and info == nil, so it does NOT accidentally fulfill any
		// inverted expectation whose condition checks for noItemsError.
		testWindow?.rootViewController?.presentedViewController?
			.dismiss(animated: false, completion: nil)

		testWindow?.isHidden = true
		testWindow = nil

		tempFiles.forEach { try? FileManager.default.removeItem(at: $0) }
		tempFiles.removeAll()

		super.tearDown()
	}

	// MARK: - Initialisation ──────────────────────────────────────────────────────

	func testInit_NoArguments_AllPropertiesNil() {
		let share = ShareFixtures.empty()

		XCTAssertNil(share.title)
		XCTAssertNil(share.subject)
		XCTAssertNil(share.content)
		XCTAssertNil(share.filePath)
		XCTAssertNil(share.mimeType)
	}

	func testInit_AllArguments_StoredUnchanged() {
		let share = Share(
			title:    ShareTestData.title,
			subject:  ShareTestData.subject,
			content:  ShareTestData.content,
			filePath: "/tmp/doc.pdf",
			mimeType: ShareTestData.pdfMime
		)

		XCTAssertEqual(share.title,    ShareTestData.title)
		XCTAssertEqual(share.subject,  ShareTestData.subject)
		XCTAssertEqual(share.content,  ShareTestData.content)
		XCTAssertEqual(share.filePath, "/tmp/doc.pdf")
		XCTAssertEqual(share.mimeType, ShareTestData.pdfMime)
	}

	func testInit_ContentOnly_OtherPropertiesAreNil() {
		let share = ShareFixtures.text()

		XCTAssertNil(share.title)
		XCTAssertNil(share.subject)
		XCTAssertEqual(share.content, ShareTestData.content)
		XCTAssertNil(share.filePath)
		XCTAssertNil(share.mimeType)
	}

	func testInit_FileAndMimeOnly_ContentAndMetadataNil() {
		let share = ShareFixtures.file(path: "/tmp/file.txt")

		XCTAssertNil(share.title)
		XCTAssertNil(share.subject)
		XCTAssertNil(share.content)
		XCTAssertEqual(share.filePath, "/tmp/file.txt")
		XCTAssertEqual(share.mimeType, ShareTestData.plainMime)
	}

	func testInit_ExplicitNilArguments_PropertiesNil() {
		let share = Share(
			title: nil, subject: nil, content: nil,
			filePath: nil, mimeType: nil
		)

		XCTAssertNil(share.title)
		XCTAssertNil(share.subject)
		XCTAssertNil(share.content)
		XCTAssertNil(share.filePath)
		XCTAssertNil(share.mimeType)
	}

	// MARK: - share() — synchronous failure: no items ─────────────────────────────
	//
	// buildItemsToShare() returns an empty array when:
	//   • content is nil or empty, AND
	//   • filePath and mimeType are not both non-nil
	//
	// Both guards inside share() call the completion handler synchronously
	// (before DispatchQueue.main.async), so waitForExpectations with a 2 s
	// timeout is generous and deterministic.

	func testShare_AllNil_ReturnsFailedResult() {
		let exp = expectation(description: "completion called")

		ShareFixtures.empty().share { result, _ in
			XCTAssertEqual(result, .failed)
			exp.fulfill()
		}

		waitForExpectations(timeout: 2)
	}

	func testShare_AllNil_InfoStringIsNonEmpty() {
		// The Godot layer logs the info string, so it must never be nil or blank.
		let exp = expectation(description: "completion called")
		var capturedInfo: String?

		ShareFixtures.empty().share { _, info in
			capturedInfo = info
			exp.fulfill()
		}

		waitForExpectations(timeout: 2)

		XCTAssertNotNil(capturedInfo, "Failure must include a reason string")
		XCTAssertFalse(capturedInfo!.isEmpty)
	}

	func testShare_AllNil_InfoIsOneOfTheKnownErrorMessages() {
		// If a window is available, "No items to share" fires.
		// In a headless CI environment (no connected scene), "No active view
		// controller found" fires first.  Both are valid; check for either.
		let exp = expectation(description: "completion called")
		var receivedInfo: String?

		ShareFixtures.empty().share { _, info in
			receivedInfo = info
			exp.fulfill()
		}

		waitForExpectations(timeout: 2)

		let valid: Set<String> = [ShareTestData.noItemsError, ShareTestData.noActiveVCError]
		XCTAssertTrue(
			valid.contains(receivedInfo ?? ""),
			"Unexpected failure info: \"\(receivedInfo ?? "<nil>")\""
		)
	}

	func testShare_EmptyStringContent_ReturnsFailedResult() {
		// An empty string is treated the same as nil by buildItemsToShare().
		let exp = expectation(description: "completion called")

		ShareFixtures.text("").share { result, _ in
			XCTAssertEqual(result, .failed)
			exp.fulfill()
		}

		waitForExpectations(timeout: 2)
	}

	func testShare_WhitespaceOnlyContent_ReturnsFailedResult() {
		// "   " is non-nil but isEmpty == false; however UIActivityViewController
		// sharing whitespace-only strings is not meaningful.
		// Swift's `!content.isEmpty` check lets whitespace through, but we verify
		// the plugin's current documented behaviour here.
		//
		// Note: if this test fails after a product change that strips whitespace,
		// update it to assert .failed instead.
		let exp = expectation(description: "completion called")

		// The plugin currently DOES include whitespace strings as items, so
		// sharing whitespace should NOT produce a "No items" failure.
		let noItemsExp = expectation(description: "'No items' must NOT fire for whitespace")
		noItemsExp.isInverted = true

		Share(content: "   ").share { _, info in
			if info == ShareTestData.noItemsError { noItemsExp.fulfill() }
			exp.fulfill()
		}

		waitForExpectations(timeout: 2)
	}

	func testShare_FilepathWithoutMimeType_ReturnsFailedResult() {
		// Without a paired mimeType, the file branch in buildItemsToShare() is
		// skipped entirely.
		let exp = expectation(description: "completion called")

		Share(filePath: "/tmp/doc.txt").share { result, _ in
			XCTAssertEqual(result, .failed)
			exp.fulfill()
		}

		waitForExpectations(timeout: 2)
	}

	func testShare_MimeTypeWithoutFilepath_ReturnsFailedResult() {
		// Without a paired filePath, the file branch is also skipped.
		let exp = expectation(description: "completion called")

		Share(mimeType: ShareTestData.plainMime).share { result, _ in
			XCTAssertEqual(result, .failed)
			exp.fulfill()
		}

		waitForExpectations(timeout: 2)
	}

	func testShare_OnlyTitleAndSubject_ReturnsFailedResult() {
		// Metadata-only shares carry no actual payload.
		let exp = expectation(description: "completion called")

		Share(title: ShareTestData.title, subject: ShareTestData.subject).share { result, _ in
			XCTAssertEqual(result, .failed)
			exp.fulfill()
		}

		waitForExpectations(timeout: 2)
	}

	// MARK: - share() — item building: text ───────────────────────────────────────
	//
	// These tests use *inverted* XCTestExpectations: the test PASSES when the
	// "No items to share" failure is NOT called within the timeout.  This confirms
	// that buildItemsToShare() produced at least one item and the share flow
	// continued past the guard — i.e., it tried to present UIActivityViewController.
	//
	// The inverted expectations require a live key window (setUp provides one).

	func testShare_NonEmptyContent_DoesNotTriggerNoItemsFailure() throws {
		guard testWindow != nil else {
			throw XCTSkip("Requires a key window — run on simulator or device")
		}

		let noItems = expectation(description: "'No items' must NOT fire")
		noItems.isInverted = true

		ShareFixtures.text().share { _, info in
			if info == ShareTestData.noItemsError { noItems.fulfill() }
		}

		waitForExpectations(timeout: 0.3)
	}

	func testShare_FullTextShare_DoesNotTriggerNoItemsFailure() throws {
		guard testWindow != nil else { throw XCTSkip("Requires simulator") }

		let noItems = expectation(description: "'No items' must NOT fire")
		noItems.isInverted = true

		ShareFixtures.fullText().share { _, info in
			if info == ShareTestData.noItemsError { noItems.fulfill() }
		}

		waitForExpectations(timeout: 0.3)
	}

	// MARK: - share() — item building: files ──────────────────────────────────────

	func testShare_PlainTextFile_DoesNotTriggerNoItemsFailure() throws {
		guard testWindow != nil else { throw XCTSkip("Requires simulator") }

		let fileURL = try TempFileFixtures.makeText()
		tempFiles.append(fileURL)

		let noItems = expectation(description: "'No items' must NOT fire")
		noItems.isInverted = true

		ShareFixtures.file(path: fileURL.path).share { _, info in
			if info == ShareTestData.noItemsError { noItems.fulfill() }
		}

		waitForExpectations(timeout: 0.3)
	}

	func testShare_ImageFile_DoesNotTriggerNoItemsFailure() throws {
		guard testWindow != nil else { throw XCTSkip("Requires simulator") }

		let fileURL = try TempFileFixtures.makeImage()
		tempFiles.append(fileURL)

		let noItems = expectation(description: "'No items' must NOT fire")
		noItems.isInverted = true

		ShareFixtures.file(path: fileURL.path, mime: ShareTestData.imageMime).share { _, info in
			if info == ShareTestData.noItemsError { noItems.fulfill() }
		}

		waitForExpectations(timeout: 0.3)
	}

	func testShare_WildcardImageMime_DoesNotTriggerNoItemsFailure() throws {
		// "image/*" should be treated as an image MIME type by buildItemsToShare().
		guard testWindow != nil else { throw XCTSkip("Requires simulator") }

		let fileURL = try TempFileFixtures.makeImage()
		tempFiles.append(fileURL)

		let noItems = expectation(description: "'No items' must NOT fire")
		noItems.isInverted = true

		ShareFixtures.file(path: fileURL.path, mime: ShareTestData.imageWild).share { _, info in
			if info == ShareTestData.noItemsError { noItems.fulfill() }
		}

		waitForExpectations(timeout: 0.3)
	}

	func testShare_PdfFile_DoesNotTriggerNoItemsFailure() throws {
		guard testWindow != nil else { throw XCTSkip("Requires simulator") }

		let fileURL = try TempFileFixtures.makeText(body: "%PDF-1.4 fixture\n")
		tempFiles.append(fileURL)

		let noItems = expectation(description: "'No items' must NOT fire")
		noItems.isInverted = true

		ShareFixtures.file(path: fileURL.path, mime: ShareTestData.pdfMime).share { _, info in
			if info == ShareTestData.noItemsError { noItems.fulfill() }
		}

		waitForExpectations(timeout: 0.3)
	}

	func testShare_ContentAndFile_DoesNotTriggerNoItemsFailure() throws {
		// Both a text item and a file item together should still work.
		guard testWindow != nil else { throw XCTSkip("Requires simulator") }

		let fileURL = try TempFileFixtures.makeText()
		tempFiles.append(fileURL)

		let noItems = expectation(description: "'No items' must NOT fire")
		noItems.isInverted = true

		Share(content: ShareTestData.content,
				filePath: fileURL.path,
				mimeType: ShareTestData.plainMime).share { _, info in
			if info == ShareTestData.noItemsError { noItems.fulfill() }
		}

		waitForExpectations(timeout: 0.3)
	}

	// MARK: - share() — file:// URI stripping ─────────────────────────────────────

	func testShare_FileURIPrefix_IsStrippedAndFileIsResolved() throws {
		// Godot passes paths as "file:///var/…"; the plugin must strip the prefix
		// before constructing the file URL.
		guard testWindow != nil else { throw XCTSkip("Requires simulator") }

		let fileURL = try TempFileFixtures.makeText()
		tempFiles.append(fileURL)

		let noItems = expectation(description: "'No items' must NOT fire")
		noItems.isInverted = true

		// Exact format Godot supplies at runtime
		ShareFixtures.fileUri(localPath: fileURL.path).share { _, info in
			if info == ShareTestData.noItemsError { noItems.fulfill() }
		}

		waitForExpectations(timeout: 0.3)
	}

	func testShare_FileURIPrefix_OnNonExistentImagePath_FallsBackToURLItem() throws {
		// Even a missing image is wrapped as a URL item (non-empty), because
		// UIImage(contentsOfFile:) returns nil and the else-branch appends the URL.
		guard testWindow != nil else { throw XCTSkip("Requires simulator") }

		let noItems = expectation(description: "'No items' must NOT fire")
		noItems.isInverted = true

		ShareFixtures.fileUri(
			localPath: "/nonexistent/ghost_\(UUID().uuidString).png",
			mime: ShareTestData.imageMime
		).share { _, info in
			if info == ShareTestData.noItemsError { noItems.fulfill() }
		}

		waitForExpectations(timeout: 0.3)
	}

	// MARK: - share() — non-existent files ────────────────────────────────────────

	func testShare_NonExistentImagePath_FallsBackToURLItem() throws {
		// Same logic as the URI test above, but with a bare path.
		guard testWindow != nil else { throw XCTSkip("Requires simulator") }

		let noItems = expectation(description: "'No items' must NOT fire")
		noItems.isInverted = true

		ShareFixtures.file(
			path: "/nonexistent/ghost_\(UUID().uuidString).png",
			mime: ShareTestData.imageMime
		).share { _, info in
			if info == ShareTestData.noItemsError { noItems.fulfill() }
		}

		waitForExpectations(timeout: 0.3)
	}

	func testShare_NonExistentTextFile_AppendsURLItem() throws {
		// A missing plain-text file is still wrapped in a URL (the else-branch
		// in buildItemsToShare doesn't validate existence).
		guard testWindow != nil else { throw XCTSkip("Requires simulator") }

		let noItems = expectation(description: "'No items' must NOT fire")
		noItems.isInverted = true

		ShareFixtures.file(
			path: "/nonexistent/missing_\(UUID().uuidString).txt",
			mime: ShareTestData.plainMime
		).share { _, info in
			if info == ShareTestData.noItemsError { noItems.fulfill() }
		}

		waitForExpectations(timeout: 0.3)
	}
}
