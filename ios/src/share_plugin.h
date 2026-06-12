//
// © 2024-present https://github.com/cengiz-pz
//

#ifndef share_plugin_h
#define share_plugin_h

#include "core/object/class_db.h"
#include "core/object/object.h"

// -- Outgoing share keys (existing) ------------------------------------------

extern String const DATA_KEY_TITLE;
extern String const DATA_KEY_SUBJECT;
extern String const DATA_KEY_CONTENT;
extern String const DATA_KEY_FILE_PATH;
extern String const DATA_KEY_MIME_TYPE;

// -- Signal names -------------------------------------------------------------

extern String const SIGNAL_NAME_SHARE_COMPLETED;
extern String const SIGNAL_NAME_SHARE_FAILED;
extern String const SIGNAL_NAME_SHARE_CANCELED;

/// Emitted when another app opens this app via "Open With" (share-target mode).
///
/// Payload keys (matching the Android plugin):
/// `mime_type`, `text`, `subject`, `file_paths` (PackedStringArray), `is_multiple`.
extern String const SIGNAL_NAME_SHARE_RECEIVED;

// -----------------------------------------------------------------------------

class SharePlugin : public Object {
	GDCLASS(SharePlugin, Object);

	static void _bind_methods();

public:
	// -- Outgoing share (existing) --------------------------------------------

	Error share(const Dictionary &sharedData);

	// -- Incoming share / share-target mode (new) -----------------------------

	/// Enables or disables share-target mode.
	///
	/// On iOS, document types are always registered in Info.plist (via the export plugin's
	/// `_get_ios_plist_content()`), so the app always appears in "Open With" pickers.
	/// This method controls whether received files are processed and surfaced to GDScript.
	/// The preference is persisted in `NSUserDefaults` and restored on next launch.
	///
	/// Corresponds to `Share.set_share_target(enabled)` in GDScript.
	void set_share_target(bool enabled);

	/// Returns `true` when share-target processing is currently enabled.
	bool is_share_target();

	/// Consumes and returns the most recently received share payload as a Dictionary,
	/// or an empty Dictionary when nothing is pending or share-target mode is disabled.
	///
	/// Dictionary keys: `mime_type`, `text`, `subject`, `file_paths`, `is_multiple`.
	///
	/// Called automatically by `Share._ready()` (deferred) and on
	/// `NOTIFICATION_APPLICATION_RESUMED`; you do not normally need to call this directly.
	Dictionary get_received_data();

	SharePlugin();
	~SharePlugin();
};

#endif /* share_plugin_h */
