//
// © 2024-present https://github.com/cengiz-pz
//

#import <Foundation/Foundation.h>

#import "share_plugin_bootstrap.h"
#import "share_plugin.h"

#import "core/config/engine.h"


SharePlugin *share_plugin;

void share_plugin_init() {
	NSLog(@"SharePlugin: Initializing plugin at timestamp: %f", [[NSDate date] timeIntervalSince1970]);
	share_plugin = memnew(SharePlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("SharePlugin", share_plugin));
	NSLog(@"SharePlugin: Singleton registered");
}

void share_plugin_deinit() {
	NSLog(@"SharePlugin: Deinitializing plugin");
	if (share_plugin) {
		memdelete(share_plugin);
		share_plugin = nullptr;
	}
}
