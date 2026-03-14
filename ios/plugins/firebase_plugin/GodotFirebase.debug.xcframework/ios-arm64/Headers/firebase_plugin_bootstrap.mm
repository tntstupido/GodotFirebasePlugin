#import "firebase_plugin.h"
#import "firebase_plugin_bootstrap.h"

#import <FirebaseCore/FIRApp.h>
#import <FirebaseCore/FIROptions.h>
#import <FirebaseCrashlytics/FIRCrashlytics.h>

#include "core/config/engine.h"

static FirebasePlugin *firebase_plugin = nullptr;

static void ensure_firebase_configured_early() {
	static dispatch_once_t once_token;
	dispatch_once(&once_token, ^{
		dispatch_block_t configure_block = ^{
			FIROptions *options = [FIROptions defaultOptions];
			if (options == nil) {
				return;
			}

			@try {
				[FIRApp configureWithOptions:options];
				[FIRCrashlytics crashlytics];
			} @catch (NSException *exception) {
				// The runtime bridge reports configuration failures later once Godot is ready.
			}
		};

		if ([NSThread isMainThread]) {
			configure_block();
		} else {
			dispatch_sync(dispatch_get_main_queue(), configure_block);
		}
	});
}

__attribute__((constructor)) static void firebase_plugin_static_constructor() {
	ensure_firebase_configured_early();
}

@interface FirebasePluginAutoConfigurator : NSObject
@end

@implementation FirebasePluginAutoConfigurator

+ (void)load {
	ensure_firebase_configured_early();
}

@end

void init_firebase_plugin() {
	ensure_firebase_configured_early();
	firebase_plugin = memnew(FirebasePlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("GodotFirebase", firebase_plugin));
}

void deinit_firebase_plugin() {
	if (firebase_plugin != nullptr) {
		memdelete(firebase_plugin);
		firebase_plugin = nullptr;
	}
}
