//
// © 2024-present https://github.com/cengiz-pz
//

import Foundation
import OSLog
import UIKit
import UniformTypeIdentifiers

/// Represents content received when another iOS app opens this Godot app via "Open With".
///
/// Files are copied from security-scoped URLs (which are only valid during the delivery
/// callback) into the app's private Caches directory so that GDScript can access them
/// via ordinary filesystem paths. The OS clears the cache automatically when storage is low.
///
/// Instances are created by ``ShareTargetManager`` (available from iOS 14.3+,
/// matching the plugin's deployment target) and consumed via
/// ``SharePlugin/get_received_data()``.  The GDScript-facing dictionary representation
/// uses the same keys as the Android plugin:
/// `mime_type`, `text`, `subject`, `file_paths` (Array of String), `is_multiple`.
@objcMembers public class ReceivedSharedData: NSObject {

	private static let logger = Logger(subsystem: "org.godotengine.plugin", category: "ReceivedSharedData")

	public let mimeType: String
	public let text: String
	public let subject: String
	public let filePaths: [String]
	public let isMultiple: Bool

	init(mimeType: String = "",
			text: String = "",
			subject: String = "",
			filePaths: [String] = [],
			isMultiple: Bool = false) {
		self.mimeType = mimeType
		self.text = text
		self.subject = subject
		self.filePaths = filePaths
		self.isMultiple = isMultiple
	}

	// MARK: - Factory

	/// Parses a URL delivered by the system into a ``ReceivedSharedData`` instance.
	///
	/// - For `file://` URLs the file is copied to the cache directory and the path is returned.
	/// - For web URLs (http/https) the URL string is placed in `text` with `mime_type = "text/plain"`.
	/// - Returns `nil` when the URL cannot be resolved or copied.
	static func from(url: URL) -> ReceivedSharedData? {
		if url.isFileURL {
			return fromFile(url: url)
		}
		// Plain web URL shared as text
		return ReceivedSharedData(mimeType: "text/plain", text: url.absoluteString)
	}

	private static func fromFile(url: URL) -> ReceivedSharedData? {
		// Security-scoped resources must be accessed within a startAccessing/stopAccessing pair.
		let accessed = url.startAccessingSecurityScopedResource()
		defer { if accessed { url.stopAccessingSecurityScopedResource() } }

		let mime = mimeType(for: url)
		guard let cached = copyToCache(url: url) else {
			logger.error("Failed to copy file to cache: \(url.path)")
			return nil
		}
		return ReceivedSharedData(mimeType: mime, filePaths: [cached])
	}

	// MARK: - Serialisation

	/// Returns an ``NSDictionary`` with the same keys as the Android plugin's
	/// `ReceivedSharedData.toDictionary()` so that the GDScript layer is platform-agnostic.
	func toDictionary() -> NSDictionary {
		NSDictionary(dictionary: [
			"mime_type": mimeType,
			"text": text,
			"subject": subject,
			"file_paths": filePaths,
			"is_multiple": isMultiple
		])
	}

	// MARK: - Private helpers

	private static func mimeType(for url: URL) -> String {
		let ext = url.pathExtension
		if let utType = UTType(filenameExtension: ext),
				let mime = utType.preferredMIMEType {
			return mime
		}
		return fallbackMIMEType(for: ext.lowercased())
	}

	private static func fallbackMIMEType(for ext: String) -> String {
		switch ext {
		case "jpg", "jpeg": return "image/jpeg"
		case "png":         return "image/png"
		case "gif":         return "image/gif"
		case "webp":        return "image/webp"
		case "heic":        return "image/heic"
		case "mp4", "m4v":  return "video/mp4"
		case "mov":         return "video/quicktime"
		case "mp3":         return "audio/mpeg"
		case "m4a":         return "audio/mp4"
		case "wav":         return "audio/wav"
		case "pdf":         return "application/pdf"
		case "txt":         return "text/plain"
		case "html", "htm": return "text/html"
		case "zip":         return "application/zip"
		default:            return "application/octet-stream"
		}
	}

	/// Copies `url` to `<Caches>/share_received/<filename>`.
	///
	/// Must be called inside a `startAccessingSecurityScopedResource` / `stop…` pair.
	private static func copyToCache(url: URL) -> String? {
		let fm = FileManager.default
		guard let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else {
			return nil
		}
		let dir = caches.appendingPathComponent("share_received", isDirectory: true)
		let dest = dir.appendingPathComponent(url.lastPathComponent)

		do {
			try fm.createDirectory(at: dir, withIntermediateDirectories: true)
			if fm.fileExists(atPath: dest.path) {
				try fm.removeItem(at: dest)
			}
			try fm.copyItem(at: url, to: dest)
			logger.debug("Copied shared file to cache: \(dest.path)")
			return dest.path
		} catch {
			logger.error("copyToCache error: \(error.localizedDescription)")
			return nil
		}
	}
}
