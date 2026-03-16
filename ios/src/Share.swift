//
// © 2024-present https://github.com/cengiz-pz
//

import Foundation
import OSLog
import UIKit

private let mimeTypeText = "text/plain"
private let mimeTypeImage = "image/*"

// Enum to represent the result of the share operation
@objc public enum ShareResult: Int {
	case completed
	case failed
	case canceled
}

@available(iOS 16.0, *)
@objcMembers public class Share: NSObject {

	private static let logger = Logger(subsystem: "org.godotengine.plugin", category: "Share")

	let title: String?
	let subject: String?
	let content: String?
	let filePath: String?
	let mimeType: String?

	public typealias ShareCompletionHandler = (ShareResult, String?) -> Void

	/// Initializes the Share object with optional values.
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

	/// Builds the array of items that will be passed to UIActivityViewController.
	private func buildItemsToShare() -> [Any] {
		var items: [Any] = []

		if let content = content, !content.isEmpty {
			items.append(content as NSString)
		}

		if let filePath = filePath, let mimeType = mimeType {
			let path = filePath.replacingOccurrences(of: "file://", with: "")
			if mimeType == mimeTypeImage || mimeType.hasPrefix("image/"),
			   let image = UIImage(contentsOfFile: path) {
				items.append(image)
			} else {
				items.append(URL(fileURLWithPath: path))
			}
		}

		return items
	}

	/// Configures the popover presentation for iPad.
	private func configurePopoverIfNeeded(for activityVC: UIActivityViewController,
										  in viewController: UIViewController) {
		guard UIDevice.current.userInterfaceIdiom == .pad else { return }

		let midPoint = CGPoint(x: viewController.view.bounds.midX,
							   y: viewController.view.bounds.midY)
		activityVC.popoverPresentationController?.sourceView = viewController.view
		activityVC.popoverPresentationController?.sourceRect = CGRect(origin: midPoint,
																	   size: .zero)
		activityVC.popoverPresentationController?.permittedArrowDirections = []
	}

	func share(completionHandler: @escaping ShareCompletionHandler) {
		Self.logger.debug("SharePlugin.share called")

		guard let viewController = ActiveViewController.getActiveViewController() else {
			Self.logger.error("No active view controller found")
			completionHandler(.failed, "No active view controller found")
			return
		}

		let itemsToShare = buildItemsToShare()

		guard !itemsToShare.isEmpty else {
			Self.logger.info("No items to share")
			completionHandler(.failed, "No items to share")
			return
		}

		let activityVC = UIActivityViewController(activityItems: itemsToShare,
												applicationActivities: nil)
		activityVC.excludedActivityTypes = [.print, .assignToContact, .addToReadingList, .markupAsPDF]

		configurePopoverIfNeeded(for: activityVC, in: viewController)

		// Completion handler
		activityVC.completionWithItemsHandler = { activityType, completed, _, error in
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
