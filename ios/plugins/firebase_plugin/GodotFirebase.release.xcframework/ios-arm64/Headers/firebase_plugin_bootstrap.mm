#import "firebase_plugin.h"
#import "firebase_plugin_bootstrap.h"

#import <FirebaseAnalytics/FIRAnalytics.h>
#import <FirebaseCore/FIRApp.h>
#import <FirebaseCore/FIROptions.h>
#import <FirebaseCrashlytics/FIRCrashlytics.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#include "core/config/engine.h"
#include "core/object/object.h"

static Object *firebase_plugin = nullptr;
static BOOL firebase_launch_observer_installed = NO;
static BOOL firebase_launch_notification_seen = NO;
static dispatch_source_t firebase_queue_timer = nil;
static Class firebase_swizzled_delegate_class = Nil;
static IMP firebase_original_set_delegate_imp = nil;
static IMP firebase_original_will_finish_imp = nil;
static IMP firebase_original_did_finish_imp = nil;

static NSString *firebase_event_queue_path() {
	NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	if (paths.count == 0) {
		return nil;
	}
	return [paths[0] stringByAppendingPathComponent:@"firebase_events_queue.jsonl"];
}

static NSDictionary *sanitize_analytics_params(id raw_params) {
	if (![raw_params isKindOfClass:[NSDictionary class]]) {
		return @{};
	}
	NSDictionary *input = (NSDictionary *)raw_params;
	NSMutableDictionary *sanitized = [NSMutableDictionary dictionaryWithCapacity:input.count];
	for (id key in input) {
		id value = input[key];
		if (![key isKindOfClass:[NSString class]]) {
			continue;
		}
		if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
			sanitized[key] = value;
			continue;
		}
		if ([value isKindOfClass:[NSNull class]]) {
			continue;
		}
		sanitized[key] = [value description];
	}
	return sanitized;
}

static void flush_godot_event_queue() {
	NSString *queue_path = firebase_event_queue_path();
	if (queue_path == nil) {
		return;
	}
	NSData *data = [NSData dataWithContentsOfFile:queue_path];
	if (data == nil || data.length == 0) {
		return;
	}

	NSString *contents = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (contents == nil || contents.length == 0) {
		[@"" writeToFile:queue_path atomically:YES encoding:NSUTF8StringEncoding error:nil];
		return;
	}

	NSArray<NSString *> *lines = [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	int flushed_count = 0;
	for (NSString *line in lines) {
		if (line.length == 0) {
			continue;
		}
		NSData *line_data = [line dataUsingEncoding:NSUTF8StringEncoding];
		if (line_data == nil || line_data.length == 0) {
			continue;
		}

		NSError *parse_error = nil;
		id obj = [NSJSONSerialization JSONObjectWithData:line_data options:0 error:&parse_error];
		if (parse_error != nil || ![obj isKindOfClass:[NSDictionary class]]) {
			continue;
		}

		NSDictionary *dict = (NSDictionary *)obj;
		NSString *name = dict[@"name"];
		if (![name isKindOfClass:[NSString class]] || name.length == 0) {
			continue;
		}

		NSDictionary *params = sanitize_analytics_params(dict[@"params"]);
		[FIRAnalytics logEventWithName:name parameters:params];
		flushed_count += 1;
	}

	[@"" writeToFile:queue_path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static void start_event_queue_flush_timer() {
	if (firebase_queue_timer != nil) {
		return;
	}
	firebase_queue_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
	if (firebase_queue_timer == nil) {
		return;
	}
	dispatch_source_set_timer(firebase_queue_timer, dispatch_time(DISPATCH_TIME_NOW, 0), 2 * NSEC_PER_SEC, (200 * NSEC_PER_MSEC));
	dispatch_source_set_event_handler(firebase_queue_timer, ^{
		flush_godot_event_queue();
	});
	dispatch_resume(firebase_queue_timer);
}

static void configure_firebase_if_possible() {
	static dispatch_once_t once_token;
	dispatch_once(&once_token, ^{
		dispatch_async(dispatch_get_main_queue(), ^{
			FIROptions *options = [FIROptions defaultOptions];
			if (options == nil) {
				NSLog(@"[GodotFirebase] FIROptions defaultOptions is nil (GoogleService-Info.plist missing?)");
				return;
			}

			@try {
				[FIRApp configureWithOptions:options];
				FIRCrashlytics *crashlytics = [FIRCrashlytics crashlytics];
				[crashlytics setCrashlyticsCollectionEnabled:YES];
				[crashlytics sendUnsentReports];

				[FIRAnalytics logEventWithName:@"godot_plugin_init" parameters:@{ @"platform": @"ios" }];
				flush_godot_event_queue();
				start_event_queue_flush_timer();
				NSLog(@"[GodotFirebase] Firebase configured | app=%@ | analytics bootstrap event sent", [FIRApp defaultApp].name ?: @"(null)");
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
	// Force a configure attempt during plugin init as a fallback in case
	// launch delegate/notification hooks are missed in some app lifecycles.
	configure_firebase_if_possible();
	firebase_plugin = memnew(Object);
	Engine::get_singleton()->add_singleton(Engine::Singleton("GodotFirebase", firebase_plugin));
}

void deinit_firebase_plugin() {
	if (firebase_plugin != nullptr) {
		memdelete(firebase_plugin);
		firebase_plugin = nullptr;
	}
}
