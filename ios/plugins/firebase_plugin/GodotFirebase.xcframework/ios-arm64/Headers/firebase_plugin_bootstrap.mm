#import "firebase_plugin.h"
#import "firebase_plugin_bootstrap.h"

#import <FirebaseCore/FIRApp.h>
#import <FirebaseCore/FIROptions.h>
#import <FirebaseCrashlytics/FIRCrashlytics.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#include "core/config/engine.h"

static FirebasePlugin *firebase_plugin = nullptr;
static BOOL firebase_launch_observer_installed = NO;
static BOOL firebase_launch_notification_seen = NO;
static Class firebase_swizzled_delegate_class = Nil;
static IMP firebase_original_set_delegate_imp = nil;
static IMP firebase_original_will_finish_imp = nil;
static IMP firebase_original_did_finish_imp = nil;

static void configure_firebase_if_possible() {
	static dispatch_once_t once_token;
	dispatch_once(&once_token, ^{
		dispatch_async(dispatch_get_main_queue(), ^{
			FIROptions *options = [FIROptions defaultOptions];
			if (options == nil) {
				return;
			}

			@try {
				[FIRApp configureWithOptions:options];
				FIRCrashlytics *crashlytics = [FIRCrashlytics crashlytics];
				[crashlytics setCrashlyticsCollectionEnabled:YES];
				NSLog(@"[GodotFirebase] Crashlytics ready | collection_enabled=%@ | did_crash_previous=%@",
					[crashlytics isCrashlyticsCollectionEnabled] ? @"true" : @"false",
					[crashlytics didCrashDuringPreviousExecution] ? @"true" : @"false");
				[crashlytics sendUnsentReports];
			} @catch (NSException *exception) {
				NSLog(@"[GodotFirebase] Early Firebase configure exception: %@", exception.reason ?: @"unknown");
			}
		});
	});
}

static BOOL firebase_delegate_will_finish(id self, SEL _cmd, UIApplication *application, NSDictionary *launch_options) {
	firebase_launch_notification_seen = YES;
	configure_firebase_if_possible();
	if (firebase_original_will_finish_imp != nil) {
		typedef BOOL (*WillFinishFn)(id, SEL, UIApplication *, NSDictionary *);
		return ((WillFinishFn)firebase_original_will_finish_imp)(self, _cmd, application, launch_options);
	}
	return YES;
}

static BOOL firebase_delegate_did_finish(id self, SEL _cmd, UIApplication *application, NSDictionary *launch_options) {
	firebase_launch_notification_seen = YES;
	configure_firebase_if_possible();
	if (firebase_original_did_finish_imp != nil) {
		typedef BOOL (*DidFinishFn)(id, SEL, UIApplication *, NSDictionary *);
		return ((DidFinishFn)firebase_original_did_finish_imp)(self, _cmd, application, launch_options);
	}
	return YES;
}

static void firebase_swizzle_delegate_launch_methods(id delegate) {
	if (delegate == nil) {
		return;
	}
	Class delegate_class = [delegate class];
	if (firebase_swizzled_delegate_class == delegate_class) {
		return;
	}
	firebase_swizzled_delegate_class = delegate_class;

	SEL will_finish_selector = @selector(application:willFinishLaunchingWithOptions:);
	SEL did_finish_selector = @selector(application:didFinishLaunchingWithOptions:);

	Method will_finish_method = class_getInstanceMethod(delegate_class, will_finish_selector);
	if (will_finish_method != nullptr) {
		firebase_original_will_finish_imp = method_getImplementation(will_finish_method);
		method_setImplementation(will_finish_method, (IMP)firebase_delegate_will_finish);
	} else {
		class_addMethod(delegate_class, will_finish_selector, (IMP)firebase_delegate_will_finish, "c@:@@");
		firebase_original_will_finish_imp = nil;
	}

	Method did_finish_method = class_getInstanceMethod(delegate_class, did_finish_selector);
	if (did_finish_method != nullptr) {
		firebase_original_did_finish_imp = method_getImplementation(did_finish_method);
		method_setImplementation(did_finish_method, (IMP)firebase_delegate_did_finish);
	} else {
		class_addMethod(delegate_class, did_finish_selector, (IMP)firebase_delegate_did_finish, "c@:@@");
		firebase_original_did_finish_imp = nil;
	}
}

static void firebase_set_delegate(id self, SEL _cmd, id delegate) {
	if (firebase_original_set_delegate_imp != nil) {
		typedef void (*SetDelegateFn)(id, SEL, id);
		((SetDelegateFn)firebase_original_set_delegate_imp)(self, _cmd, delegate);
	}
	firebase_swizzle_delegate_launch_methods(delegate);
}

static void install_firebase_launch_observer() {
	if (firebase_launch_observer_installed) {
		return;
	}
	firebase_launch_observer_installed = YES;

	dispatch_async(dispatch_get_main_queue(), ^{
		Method set_delegate_method = class_getInstanceMethod([UIApplication class], @selector(setDelegate:));
		if (set_delegate_method != nullptr && firebase_original_set_delegate_imp == nil) {
			firebase_original_set_delegate_imp = method_getImplementation(set_delegate_method);
			method_setImplementation(set_delegate_method, (IMP)firebase_set_delegate);
		}

		firebase_swizzle_delegate_launch_methods(UIApplication.sharedApplication.delegate);

		[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
														  object:nil
														   queue:[NSOperationQueue mainQueue]
													  usingBlock:^(__unused NSNotification *note) {
			firebase_launch_notification_seen = YES;
			configure_firebase_if_possible();
		}];
	});
}

__attribute__((constructor)) static void firebase_plugin_static_constructor() {
	install_firebase_launch_observer();
}

@interface FirebasePluginAutoConfigurator : NSObject
@end

@implementation FirebasePluginAutoConfigurator

+ (void)load {
	install_firebase_launch_observer();
}

@end

void init_firebase_plugin() {
	install_firebase_launch_observer();
	if (firebase_launch_notification_seen) {
		configure_firebase_if_possible();
	}
	firebase_plugin = memnew(FirebasePlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("GodotFirebase", firebase_plugin));
}

void deinit_firebase_plugin() {
	if (firebase_plugin != nullptr) {
		memdelete(firebase_plugin);
		firebase_plugin = nullptr;
	}
}
