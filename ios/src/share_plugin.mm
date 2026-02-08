//
// © 2024-present https://github.com/cengiz-pz
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "share_plugin.h"

#include "core/config/project_settings.h"

#import "share_plugin-Swift.h"

String const DATA_KEY_TITLE = "title";
String const DATA_KEY_SUBJECT = "subject";
String const DATA_KEY_CONTENT = "content";
String const DATA_KEY_FILE_PATH = "file_path";
String const DATA_KEY_MIME_TYPE = "mime_type";

String const MIME_TYPE_TEXT = "text/plain";
String const MIME_TYPE_IMAGE = "image/*";

String const SIGNAL_NAME_SHARE_COMPLETED = "share_completed";
String const SIGNAL_NAME_SHARE_FAILED = "share_failed";
String const SIGNAL_NAME_SHARE_CANCELED = "share_canceled";


static NSString* getNsStringOrNil(const Dictionary &data, const String &key) {
	if (!data.has(key)) {
		return nil;
	}

	String godotStr = data[key];
	if (godotStr.is_empty()) {
		return nil;
	}

	return [NSString stringWithUTF8String:godotStr.utf8().get_data()];
}

void SharePlugin::_bind_methods() {
	ClassDB::bind_method(D_METHOD("share"), &SharePlugin::share);

	ADD_SIGNAL(MethodInfo(SIGNAL_NAME_SHARE_COMPLETED, PropertyInfo(Variant::STRING, "activity_type")));
	ADD_SIGNAL(MethodInfo(SIGNAL_NAME_SHARE_FAILED, PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo(SIGNAL_NAME_SHARE_CANCELED));
}

Error SharePlugin::share(const Dictionary &sharedData) {
	NSLog(@"SharePlugin::share");

	Share *shareInstance = [[Share alloc] initWithTitle:getNsStringOrNil(sharedData, DATA_KEY_TITLE)
								subject:getNsStringOrNil(sharedData, DATA_KEY_SUBJECT)
								content:getNsStringOrNil(sharedData, DATA_KEY_CONTENT)
								filePath:getNsStringOrNil(sharedData, DATA_KEY_FILE_PATH)
								mimeType:getNsStringOrNil(sharedData, DATA_KEY_MIME_TYPE)];

	[shareInstance shareWithCompletionHandler:^(enum ShareResult result, NSString * _Nullable info) {

		String godotInfo = String();
		if (info) {
			godotInfo = String([info UTF8String]);
		}

		switch (result) {
			case ShareResultCompleted:
				NSLog(@"Share completed with activity: %@", info);
				this->emit_signal(SIGNAL_NAME_SHARE_COMPLETED, godotInfo);
				break;
			case ShareResultFailed:
				NSLog(@"Share failed with error: %@", info);
				this->emit_signal(SIGNAL_NAME_SHARE_FAILED, godotInfo);
				break;
			case ShareResultCanceled:
				NSLog(@"Share canceled");
				this->emit_signal(SIGNAL_NAME_SHARE_CANCELED);
				break;
		}
	}];

	return OK;
}

SharePlugin::SharePlugin() {
	NSLog(@"SharePlugin constructor");
}

SharePlugin::~SharePlugin() {
	NSLog(@"SharePlugin destructor");
}
