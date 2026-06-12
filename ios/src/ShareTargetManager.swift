//
// © 2024-present https://github.com/cengiz-pz
//

import ObjectiveC
import OSLog
import UIKit

/// Intercepts content shared to this Godot app via the iOS "Open With" picker and
/// surfaces the payload to the C++ plugin layer.
///
/// ## How URL delivery works on iOS 13+ (scene-based apps)
///
/// When a user picks "Open With → [Your App]", iOS delivers the URL via the scene
/// delegate's `scene(_:openURLContexts:)` method.  `UIScene` does **not** store a
/// persistent `openURLContexts` property — the URLs are only available inside that
/// callback.  This class intercepts the callback using Objective-C runtime method
/// injection so that no modification of Godot's scene delegate source is needed.
///
/// ## Critical timing requirement
///
/// The iOS foreground-resume sequence when an already-running app receives a file:
///
///   1. `UIScene.willEnterForegroundNotification`   ← install interceptor HERE
///   2. `scene(_:openURLContexts:)` called            ← URL is delivered HERE
///   3. `UIScene.didActivateNotification`
///   4. `UIApplication.didBecomeActiveNotification`  ← TOO LATE to install
///   5. Godot `NOTIFICATION_APPLICATION_RESUMED`
///
/// The previous implementation only observed `didBecomeActiveNotification` (step 4),
/// which always missed the URL at step 2.  The fix is `willEnterForegroundNotification`
/// (step 1) combined with an immediate installation attempt in `init()` for scenes
/// that are already active when the plugin starts.
///
/// ## Interceptor installation (no swizzling of known classes)
///
/// `installInterceptor(on:)` adds or replaces `scene:openURLContexts:` on the
/// **concrete delegate class** at runtime.  If the method already existed, the original
/// IMP is saved under `sharePlugin_scene_openURLContexts:` and called first, so
/// Godot's own URL handling is fully preserved.  Method existence (`savedSelector`)
/// is used to guard against double-installation instead of a static boolean, which
/// allows the function to be called safely from multiple notification paths.
@objcMembers public class ShareTargetManager: NSObject {

	// MARK: - Singleton

	public static let shared = ShareTargetManager()

	// MARK: - Logging

	static let logger = Logger(
		subsystem: "org.godotengine.plugin",
		category: "ShareTargetManager"
	)

	// MARK: - State

	private var pendingData: ReceivedSharedData?
	private var processedURLStrings = Set<String>()
	private static let enabledKey = "SharePluginTargetEnabled"

	/// Selector under which the original `scene:openURLContexts:` IMP is saved when
	/// we replace (not merely add) the method.  Its presence on a class is used as a
	/// guard against double-installation on the same class.
	private static let savedSelector = NSSelectorFromString("sharePlugin_scene_openURLContexts:")

	// MARK: - Init

	override private init() {
		super.init()
		setupObservers()

		// Attempt immediate installation for scenes that are already active when the
		// plugin initialises.  Deferred to the next run-loop tick so that the scene
		// delegate reference is fully resolved by the time we query it.
		DispatchQueue.main.async { [weak self] in
			self?.installInterceptorOnActiveScenes()
		}
	}

	// MARK: - Observers

	private func setupObservers() {
		let nc = NotificationCenter.default

		// ── Timing-critical: must fire BEFORE scene(_:openURLContexts:) ───────────

		// Background → foreground resume: fires at step 1 in the sequence above,
		// before the URL is delivered at step 2.  This is the key fix.
		nc.addObserver(
			self,
			selector: #selector(handleSceneWillEnterForeground(_:)),
			name: UIScene.willEnterForegroundNotification,
			object: nil
		)

		// Cold start: fires when the scene is first created (before any URL delivery).
		nc.addObserver(
			self,
			selector: #selector(handleSceneWillConnect(_:)),
			name: UIScene.willConnectNotification,
			object: nil
		)

		// ── Fallbacks ─────────────────────────────────────────────────────────────

		// Pre-scene / iOS ≤ 12 path: URL in application launch options.
		nc.addObserver(
			self,
			selector: #selector(handleAppDidFinishLaunching(_:)),
			name: UIApplication.didFinishLaunchingNotification,
			object: nil
		)
	}

	// MARK: - Notification handlers

	@objc private func handleSceneWillEnterForeground(_ notification: Notification) {
		// Step 1 of the resume sequence — install before the URL arrives at step 2.
		guard let scene = notification.object as? UIScene else { return }

		if let delegate = scene.delegate {
			Self.logger.debug("willEnterForeground: installing interceptor via scene delegate")
			installInterceptor(on: type(of: delegate))
		} else if let appDelegate = UIApplication.shared.delegate {
			Self.logger.debug("willEnterForeground: scene.delegate nil - trying AppDelegate")
			installInterceptor(on: type(of: appDelegate))
		}
	}

	@objc private func handleSceneWillConnect(_ notification: Notification) {
		guard let scene = notification.object as? UIScene else { return }

		if let delegate = scene.delegate {
			Self.logger.debug("willConnect: installing interceptor via scene delegate")
			installInterceptor(on: type(of: delegate))
		} else if let appDelegate = UIApplication.shared.delegate {
			Self.logger.debug("willConnect: scene.delegate nil - trying AppDelegate")
			installInterceptor(on: type(of: appDelegate))
		}
	}

	@objc private func handleAppDidFinishLaunching(_ notification: Notification) {
		// Pre-scene fallback.
		if let url = notification.userInfo?[UIApplication.LaunchOptionsKey.url] as? URL {
			Self.logger.info("App launched with URL (launch options): \(url.absoluteString)")
			processURL(url)
		}
	}

	// MARK: - Interceptor installation

	/// Tries to install the `scene:openURLContexts:` interceptor on the delegate of
	/// every currently-connected scene.  Called once from `init()` (deferred to the
	/// next run loop tick) so that scenes already active at plugin-start time are covered.
	private func installInterceptorOnActiveScenes() {
		var installed = false

		for scene in UIApplication.shared.connectedScenes {
			if let delegate = scene.delegate {
				installInterceptor(on: type(of: delegate))
				installed = true
				break	// one installation covers all scenes of the same delegate class
			}
		}

		if !installed, let appDelegate = UIApplication.shared.delegate {
			Self.logger.debug("installInterceptorOnActiveScenes: falling back to AppDelegate")
			installInterceptor(on: type(of: appDelegate))
		}
	}

	/// Installs (or confirms already installed) `scene:openURLContexts:` on `cls`.
	///
	/// Uses the presence of `savedSelector` on `cls` as a guard: if the selector already
	/// exists the method was previously swizzled, so we return early without touching
	/// the class again.  This is safer than a static boolean flag because it works
	/// correctly when `installInterceptor` is called on multiple different classes.
	private func installInterceptor(on cls: AnyClass) {
		let targetSel = NSSelectorFromString("scene:openURLContexts:")
		let savedSel  = ShareTargetManager.savedSelector

		// Guard: already installed on this class.
		if class_getInstanceMethod(cls, savedSel) != nil {
			Self.logger.debug("Interceptor already present on \(NSStringFromClass(cls)) - skip")
			return
		}

		// Build the replacement block.
		// ObjC method signature: - (void)scene:(UIScene *)scene
		//                           openURLContexts:(NSSet<UIOpenURLContext *> *)ctxs;
		let block: @convention(block) (AnyObject, UIScene, NSSet) -> Void =
			{ [weak self] (delegateObj, scene, urlContextsNS) in
				// Forward to original IMP if it was saved.
				if let origMethod = class_getInstanceMethod(type(of: delegateObj), savedSel) {
					typealias OrigFn = @convention(c) (AnyObject, Selector, UIScene, NSSet) -> Void
					let fn = unsafeBitCast(method_getImplementation(origMethod), to: OrigFn.self)
					fn(delegateObj, savedSel, scene, urlContextsNS)
				}
				// Process each delivered URL context.
				Self.logger.info(
					"scene:openURLContexts: intercepted - \(urlContextsNS.count) context(s)"
				)
				for case let ctx as UIOpenURLContext in urlContextsNS {
					self?.processURL(ctx.url)
				}
			}

		let newIMP  = imp_implementationWithBlock(block)
		let typeEnc = "v@:@@"	// void (id, SEL, id, id)

		if let existingMethod = class_getInstanceMethod(cls, targetSel) {
			// Save original IMP under savedSel so the block can call through to it,
			// then replace the live IMP.
			let saved = class_addMethod(
				cls, savedSel,
				method_getImplementation(existingMethod),
				method_getTypeEncoding(existingMethod)
			)
			if saved {
				method_setImplementation(existingMethod, newIMP)
				Self.logger.info(
					"Swizzled scene:openURLContexts: on \(NSStringFromClass(cls))"
				)
			} else {
				// savedSel add failed → race condition; another thread beat us.
				Self.logger.warning(
					"class_addMethod for savedSel failed on \(NSStringFromClass(cls)) - concurrent install?"
				)
			}
		} else {
			// Method not yet defined on this class — add it fresh.
			class_addMethod(cls, targetSel, newIMP, typeEnc)
			Self.logger.info(
				"Added scene:openURLContexts: to \(NSStringFromClass(cls))"
			)
		}
	}

	// MARK: - URL processing

	private func processURL(_ url: URL) {
		let key = url.absoluteString
		guard !processedURLStrings.contains(key) else {
			Self.logger.debug("Already processed URL - skipping: \(key)")
			return
		}
		processedURLStrings.insert(key)

		guard let data = ReceivedSharedData.from(url: url) else {
			Self.logger.warning("Could not build ReceivedSharedData from: \(key)")
			return
		}
		Self.logger.info(
			"Share received - mimeType: \(data.mimeType), files: \(data.filePaths), text: \(data.text)"
		)
		pendingData = data
	}

	// MARK: - Public API (called from C++ via Obj-C bridge)

	/// Enables or disables share-target processing.
	///
	/// Document type registrations in Info.plist cannot be toggled at runtime — the
	/// app always appears in "Open With" pickers.  This flag controls whether received
	/// content is processed and surfaced to GDScript.  Persisted in `UserDefaults`.
	public func setEnabled(_ enabled: Bool) {
		UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
		Self.logger.info("Share target \(enabled ? "enabled" : "disabled")")
	}

	/// Returns `true` when share-target processing is currently enabled.
	public func isEnabled() -> Bool {
		UserDefaults.standard.bool(forKey: Self.enabledKey)
	}

	/// Consumes and returns the pending received-share payload, or `nil` when nothing
	/// is pending or share-target mode is disabled.
	///
	/// Called from `SharePlugin::get_received_data()` in the C++ layer, which is in
	/// turn polled by `Share._notification(NOTIFICATION_APPLICATION_RESUMED)` on iOS.
	public func consumePendingData() -> ReceivedSharedData? {
		guard isEnabled() else {
			Self.logger.debug("consumePendingData: share target disabled - returning nil")
			return nil
		}
		let data = pendingData
		pendingData = nil
		// Clear the processed-URLs set so the same file can be shared again later.
		if data != nil {
			processedURLStrings.removeAll()
		}
		return data
	}
}
