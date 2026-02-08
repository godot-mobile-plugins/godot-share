//
// © 2024-present https://github.com/cengiz-pz
//

import Foundation
import OSLog
import UIKit

private let MIME_TYPE_TEXT  = "text/plain"
private let MIME_TYPE_IMAGE = "image/*"

// Enum to represent the result of the share operation
@objc public enum ShareResult: Int {
	case completed
	case failed
	case canceled
}

@available(iOS 16.0, *)
@objcMembers public class Share : NSObject {

	private static let logger = Logger(subsystem: "org.godotengine.plugin", category: "Share")

	let title: String?
	let subject: String?
	let content: String?
	let filePath: String?
	let mimeType: String?

	// Define the type for the completion handler that the Objective-C code will provide
	public typealias ShareCompletionHandler = (ShareResult, String?) -> Void

	/// Initializes the Share object with optional values
	/// - Parameters:
	///   - title: The title of the shared item (optional)
	///   - subject: The subject line for shared item (optional)
	///   - content: The text content (optional)
	///   - filePath: Path to an attachment (optional)
	///   - mimeType: MIME type of the attachment (optional)
	init(title: String? = nil,
		subject: String? = nil,
		content: String? = nil,
		filePath: String? = nil,
		mimeType: String? = nil) {

		self.title = title
		self.subject = subject
		self.content = content
		self.filePath = filePath
		self.mimeType = mimeType
	}

	func share(completionHandler: @escaping ShareCompletionHandler) {
		Self.logger.debug("SharePlugin.share called")
		
		guard let viewController = ActiveViewController.getActiveViewController() else {
			Self.logger.error("No active view controller found")
			// Call handler for immediate failure
			completionHandler(.failed, "No active view controller found")
			return
		}
		
		var itemsToShare: [Any] = []

		if let content = content, !content.isEmpty {
			itemsToShare.append(content as NSString)
		}

		// File attachment
		if let filePath = filePath, let mimeType = mimeType {
			let path = filePath.replacingOccurrences(of: "file://", with: "")
			let url = URL(fileURLWithPath: path)
			
			if mimeType == MIME_TYPE_IMAGE || mimeType.hasPrefix("image/"),
			let image = UIImage(contentsOfFile: path) {
				itemsToShare.append(image)
			} else {
				itemsToShare.append(url) // Share as file URL
			}
		}
		
		guard !itemsToShare.isEmpty else {
			Self.logger.info("No items to share")
			// Call handler for immediate failure
			completionHandler(.failed, "No items to share")
			return
		}
		
		let activityVC = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
		
		// Exclude unwanted activities
		activityVC.excludedActivityTypes = [
			.print,
			.assignToContact,
			.addToReadingList,
			.markupAsPDF
		]
		
		// iPad popover setup
		if UIDevice.current.userInterfaceIdiom == .pad {
			activityVC.popoverPresentationController?.sourceView = viewController.view
			activityVC.popoverPresentationController?.sourceRect = CGRect(
				x: viewController.view.bounds.midX,
				y: viewController.view.bounds.midY,
				width: 0, height: 0
			)
			activityVC.popoverPresentationController?.permittedArrowDirections = []
		}
		
		// Completion handler
		activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
			if completed {
				Self.logger.debug("Share completed via \(activityType?.rawValue ?? "unknown")")
				completionHandler(.completed, activityType?.rawValue)
			} else if let error = error {
				Self.logger.error("Share failed: \(error.localizedDescription)")
				completionHandler(.failed, error.localizedDescription)
			} else {
				Self.logger.debug("Share canceled")
				completionHandler(.canceled, nil)
			}
		}
		
		// Present on main thread
		DispatchQueue.main.async {
			viewController.present(activityVC, animated: true, completion: nil)
		}
	}
}
