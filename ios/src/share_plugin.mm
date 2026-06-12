//
// © 2024-present https://github.com/cengiz-pz
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "share_plugin.h"

#include "core/config/project_settings.h"
#include "core/variant/typed_array.h"

#import "share_plugin-Swift.h"

// ── Outgoing share keys ───────────────────────────────────────────────────────

String const DATA_KEY_TITLE = "title";
String const DATA_KEY_SUBJECT = "subject";
String const DATA_KEY_CONTENT = "content";
String const DATA_KEY_FILE_PATH = "file_path";
String const DATA_KEY_MIME_TYPE = "mime_type";

// ── Signal names ──────────────────────────────────────────────────────────────

String const SIGNAL_NAME_SHARE_COMPLETED = "share_completed";
String const SIGNAL_NAME_SHARE_FAILED = "share_failed";
String const SIGNAL_NAME_SHARE_CANCELED = "share_canceled";
String const SIGNAL_NAME_SHARE_RECEIVED = "share_received";

// ── Helpers ───────────────────────────────────────────────────────────────────

static NSString *getNsStringOrNil(const Dictionary &data, const String &key) {
	if (!data.has(key)) {
		return nil;
	}

	String godotStr = data[key];
	if (godotStr.is_empty()) {
		return nil;
	}

	return [NSString stringWithUTF8String:godotStr.utf8().get_data()];
}

/// Converts an NSArray of NSString paths into a Godot PackedStringArray.
static PackedStringArray nsArrayToPackedStringArray(NSArray<NSString *> *array) {
	PackedStringArray result;
	if (!array) {
		return result;
	}
	for (NSString *item in array) {
		result.push_back(String(item.UTF8String));
	}
	return result;
}

// ── Bind methods ──────────────────────────────────────────────────────────────

void SharePlugin::_bind_methods() {
	// Outgoing share (existing)
	ClassDB::bind_method(D_METHOD("share"), &SharePlugin::share);
	ADD_SIGNAL(MethodInfo(SIGNAL_NAME_SHARE_COMPLETED, PropertyInfo(Variant::STRING, "activity_type")));
	ADD_SIGNAL(MethodInfo(SIGNAL_NAME_SHARE_FAILED, PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo(SIGNAL_NAME_SHARE_CANCELED));

	// Incoming share / share-target mode (new)
	ClassDB::bind_method(D_METHOD("set_share_target", "enabled"), &SharePlugin::set_share_target);
	ClassDB::bind_method(D_METHOD("is_share_target"), &SharePlugin::is_share_target);
	ClassDB::bind_method(D_METHOD("get_received_data"), &SharePlugin::get_received_data);
	ADD_SIGNAL(MethodInfo(SIGNAL_NAME_SHARE_RECEIVED, PropertyInfo(Variant::DICTIONARY, "data")));
}

// ── Outgoing share implementation (unchanged) ─────────────────────────────────

Error SharePlugin::share(const Dictionary &sharedData) {
	NSLog(@"SharePlugin::share");

	// Share is @available(iOS 16.0, *); guard required at the lower deployment target.
	if (@available(ios 16.0, *)) {
		Share *shareInstance = [[Share alloc] initWithTitle:getNsStringOrNil(sharedData, DATA_KEY_TITLE)
													subject:getNsStringOrNil(sharedData, DATA_KEY_SUBJECT)
													content:getNsStringOrNil(sharedData, DATA_KEY_CONTENT)
												   filePath:getNsStringOrNil(sharedData, DATA_KEY_FILE_PATH)
												   mimeType:getNsStringOrNil(sharedData, DATA_KEY_MIME_TYPE)];

		[shareInstance shareWithCompletionHandler:^(enum ShareResult result, NSString *_Nullable info) {
			String godotInfo;
			if (info) {
				godotInfo = String(info.UTF8String);
			}

			switch (result) {
				case ShareResultCompleted:
					NSLog(@"Share completed via: %@", info);
					this->emit_signal(SIGNAL_NAME_SHARE_COMPLETED, godotInfo);
					break;
				case ShareResultFailed:
					NSLog(@"Share failed: %@", info);
					this->emit_signal(SIGNAL_NAME_SHARE_FAILED, godotInfo);
					break;
				case ShareResultCanceled:
					NSLog(@"Share canceled");
					this->emit_signal(SIGNAL_NAME_SHARE_CANCELED);
					break;
			}
		}];

		return OK;
	} else {
		NSLog(@"SharePlugin::share – requires iOS 16.0 or later");
		this->emit_signal(SIGNAL_NAME_SHARE_FAILED, String("share() requires iOS 16.0 or later"));
		return ERR_UNAVAILABLE;
	}
}

// ── Incoming share / share-target mode (new) ──────────────────────────────────
//
// ShareTargetManager and ReceivedSharedData do NOT carry @available(iOS 16.0, *)
// because they only use UIScene (iOS 13+) and UTType (iOS 14+), both of which are
// unconditionally available at the plugin's deployment target (iOS 14.3).
// No @available guards are therefore needed for their usage below.

void SharePlugin::set_share_target(bool enabled) {
	NSLog(@"SharePlugin::set_share_target(%s)", enabled ? "true" : "false");
	[ShareTargetManager.shared setEnabled:enabled];
}

bool SharePlugin::is_share_target() {
	return [ShareTargetManager.shared isEnabled];
}

Dictionary SharePlugin::get_received_data() {
	Dictionary result;

	ReceivedSharedData *data = [ShareTargetManager.shared consumePendingData];
	if (!data) {
		return result;
	}

	NSLog(@"SharePlugin::get_received_data – returning payload (mimeType: %@)", data.mimeType);

	result["mime_type"] = String(data.mimeType.UTF8String);
	result["text"] = String(data.text.UTF8String);
	result["subject"] = String(data.subject.UTF8String);
	result["file_paths"] = nsArrayToPackedStringArray(data.filePaths);
	result["is_multiple"] = (bool)data.isMultiple;

	return result;
}

// ── Lifecycle ─────────────────────────────────────────────────────────────────

SharePlugin::SharePlugin() {
	NSLog(@"SharePlugin constructor");
	// ShareTargetManager.shared is a Swift singleton; accessing it here starts its
	// NSNotificationCenter observers so URL contexts are captured even during cold start.
	(void)[ShareTargetManager shared];
}

SharePlugin::~SharePlugin() {
	NSLog(@"SharePlugin destructor");
}
