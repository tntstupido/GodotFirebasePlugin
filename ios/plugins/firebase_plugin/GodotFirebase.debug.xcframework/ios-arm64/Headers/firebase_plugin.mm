#import "firebase_plugin.h"

#import <FirebaseAnalytics/FIRAnalytics.h>
#import <FirebaseCore/FIRApp.h>
#import <FirebaseCore/FIROptions.h>
#import <FirebaseCrashlytics/FIRCrashlytics.h>

static const char *FIREBASE_READY_SIGNAL = "firebase_ready";
static const char *FIREBASE_ERROR_SIGNAL = "firebase_error";

static NSString *StringToNSString(const String &value) {
	CharString utf8 = value.utf8();
	return [NSString stringWithUTF8String:utf8.get_data()];
}

static String NSStringToString(NSString *value) {
	if (value == nil) {
		return "";
	}
	return String::utf8([value UTF8String]);
}

static NSString *TruncateNSString(NSString *value, NSUInteger max_length) {
	if (value == nil) {
		return @"";
	}
	if (value.length <= max_length) {
		return value;
	}
	return [value substringToIndex:max_length];
}

static BOOL IsASCIILetter(unichar c) {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

static BOOL IsASCIIDigit(unichar c) {
	return c >= '0' && c <= '9';
}

static NSString *SanitizeFirebaseIdentifier(NSString *value, NSString *fallback_prefix, NSUInteger max_length) {
	NSString *lower = [[value ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
	if (lower.length == 0) {
		return @"";
	}

	NSMutableString *cleaned = [NSMutableString stringWithCapacity:lower.length + fallback_prefix.length];
	for (NSUInteger i = 0; i < lower.length; i++) {
		unichar c = [lower characterAtIndex:i];
		if (IsASCIILetter(c) || IsASCIIDigit(c) || c == '_') {
			[cleaned appendFormat:@"%C", c];
		} else {
			[cleaned appendString:@"_"];
		}
	}

	if (cleaned.length == 0) {
		return @"";
	}

	unichar first = [cleaned characterAtIndex:0];
	if (!IsASCIILetter(first)) {
		[cleaned insertString:fallback_prefix atIndex:0];
	}

	if ([cleaned hasPrefix:@"firebase_"] || [cleaned hasPrefix:@"google_"] || [cleaned hasPrefix:@"ga_"]) {
		[cleaned insertString:fallback_prefix atIndex:0];
	}

	if (cleaned.length > max_length) {
		return [cleaned substringToIndex:max_length];
	}
	return cleaned;
}

static NSString *SanitizeEventName(NSString *value) {
	return SanitizeFirebaseIdentifier(value, @"e_", 40);
}

static NSString *SanitizeParamName(NSString *value) {
	return SanitizeFirebaseIdentifier(value, @"p_", 40);
}

static NSString *SanitizeUserPropertyName(NSString *value) {
	return SanitizeFirebaseIdentifier(value, @"u_", 24);
}

static NSString *SanitizeCrashlyticsKey(NSString *value) {
	return SanitizeFirebaseIdentifier(value, @"c_", 64);
}

static NSObject *NSObjectForAnalyticsVariant(const Variant &value) {
	switch (value.get_type()) {
		case Variant::BOOL:
			return [NSNumber numberWithInt:bool(value) ? 1 : 0];
		case Variant::INT:
			return [NSNumber numberWithLongLong:int64_t(value)];
		case Variant::FLOAT:
			return [NSNumber numberWithDouble:double(value)];
		case Variant::STRING:
			return TruncateNSString(StringToNSString(String(value)), 100);
		default:
			return TruncateNSString(StringToNSString(String(value)), 100);
	}
}

static NSObject *NSObjectForCrashlyticsVariant(const Variant &value) {
	switch (value.get_type()) {
		case Variant::BOOL:
			return [NSNumber numberWithBool:bool(value)];
		case Variant::INT:
			return [NSNumber numberWithLongLong:int64_t(value)];
		case Variant::FLOAT:
			return [NSNumber numberWithDouble:double(value)];
		case Variant::STRING:
			return TruncateNSString(StringToNSString(String(value)), 256);
		default:
			return TruncateNSString(StringToNSString(String(value)), 256);
	}
}

static NSDictionary<NSString *, id> *AnalyticsDictionaryFromGodot(const Dictionary &params) {
	NSMutableDictionary<NSString *, id> *result = [NSMutableDictionary dictionary];
	Array keys = params.keys();
	for (int i = 0; i < keys.size(); i++) {
		Variant key_variant = keys[i];
		NSString *key = SanitizeParamName(StringToNSString(String(key_variant)));
		if (key.length == 0) {
			continue;
		}
		NSObject *value = NSObjectForAnalyticsVariant(params[key_variant]);
		if (value != nil) {
			result[key] = value;
		}
	}
	return result.count > 0 ? result : nil;
}

static NSDictionary<NSString *, id> *CrashlyticsUserInfoFromGodot(const Dictionary &details, NSString *message) {
	NSMutableDictionary<NSString *, id> *result = [NSMutableDictionary dictionary];
	if (message.length > 0) {
		result[NSLocalizedDescriptionKey] = TruncateNSString(message, 256);
	}
	Array keys = details.keys();
	for (int i = 0; i < keys.size(); i++) {
		Variant key_variant = keys[i];
		NSString *key = SanitizeCrashlyticsKey(StringToNSString(String(key_variant)));
		if (key.length == 0) {
			continue;
		}
		NSObject *value = NSObjectForCrashlyticsVariant(details[key_variant]);
		if (value != nil) {
			result[key] = value;
		}
	}
	return result;
}

static void RunOnMainSync(dispatch_block_t block) {
	if ([NSThread isMainThread]) {
		block();
		return;
	}
	dispatch_sync(dispatch_get_main_queue(), block);
}

@interface FirebaseBridge : NSObject
@property(nonatomic, assign) FirebasePlugin *plugin;
@property(nonatomic, assign) BOOL ready;
@property(nonatomic, assign) BOOL readySignalEmitted;
@property(nonatomic, assign) NSInteger lastErrorCode;
@property(nonatomic, strong) NSString *lastErrorMessage;
- (instancetype)initWithPlugin:(FirebasePlugin *)plugin;
- (BOOL)ensureConfigured;
- (BOOL)isReady;
- (void)logEventNamed:(NSString *)eventName parameters:(NSDictionary<NSString *, id> *)parameters;
- (void)setUserID:(NSString *)userID;
- (void)setUserProperty:(NSString *)value name:(NSString *)name;
- (void)setCrashlyticsCustomKey:(NSString *)name value:(NSObject *)value;
- (void)logCrashlyticsMessage:(NSString *)message;
- (void)recordNonfatal:(NSString *)message details:(NSDictionary<NSString *, id> *)details;
- (void)triggerTestCrash;
@end

FirebasePlugin *FirebasePlugin::instance = nullptr;

@implementation FirebaseBridge

- (instancetype)initWithPlugin:(FirebasePlugin *)plugin {
	self = [super init];
	if (self != nil) {
		self.plugin = plugin;
		self.ready = NO;
		self.readySignalEmitted = NO;
		self.lastErrorCode = 0;
		self.lastErrorMessage = @"";
		[self ensureConfigured];
	}
	return self;
}

- (void)emitReadyIfNeeded {
	if (!self.ready || self.readySignalEmitted) {
		return;
	}
	self.readySignalEmitted = YES;
	self.plugin->notify_firebase_ready();
}

- (void)emitErrorWithCode:(NSInteger)code message:(NSString *)message {
	NSString *resolved_message = message ?: @"Firebase configuration failed";
	if (self.lastErrorCode == code && [self.lastErrorMessage isEqualToString:resolved_message]) {
		return;
	}
	self.lastErrorCode = code;
	self.lastErrorMessage = resolved_message;
	self.plugin->notify_firebase_error(int(code), NSStringToString(resolved_message));
}

- (BOOL)ensureConfigured {
	__block BOOL configured = NO;
	RunOnMainSync(^{
		if ([FIRApp defaultApp] != nil) {
			self.ready = YES;
			[self emitReadyIfNeeded];
			configured = YES;
			return;
		}

		FIROptions *options = [FIROptions defaultOptions];
		if (options == nil) {
			self.ready = NO;
			[self emitErrorWithCode:1 message:@"GoogleService-Info.plist not found in app bundle"];
			configured = NO;
			return;
		}

		@try {
			[FIRApp configureWithOptions:options];
			self.ready = ([FIRApp defaultApp] != nil);
			if (!self.ready) {
				[self emitErrorWithCode:2 message:@"Firebase configured returned no default app"];
				configured = NO;
				return;
			}
			[FIRCrashlytics crashlytics];
			[self emitReadyIfNeeded];
			configured = YES;
		} @catch (NSException *exception) {
			self.ready = NO;
			NSString *message = [NSString stringWithFormat:@"Firebase configure exception: %@", exception.reason ?: @"unknown"];
			[self emitErrorWithCode:3 message:message];
			configured = NO;
		}
	});
	return configured;
}

- (BOOL)isReady {
	return [self ensureConfigured];
}

- (void)logEventNamed:(NSString *)eventName parameters:(NSDictionary<NSString *, id> *)parameters {
	if (![self ensureConfigured]) {
		return;
	}
	NSString *sanitized = SanitizeEventName(eventName);
	if (sanitized.length == 0) {
		return;
	}
	RunOnMainSync(^{
		[FIRAnalytics logEventWithName:sanitized parameters:parameters];
	});
}

- (void)setUserID:(NSString *)userID {
	if (![self ensureConfigured]) {
		return;
	}
	NSString *sanitized = userID.length > 0 ? TruncateNSString(userID, 256) : nil;
	RunOnMainSync(^{
		[FIRAnalytics setUserID:sanitized];
		[[FIRCrashlytics crashlytics] setUserID:sanitized];
	});
}

- (void)setUserProperty:(NSString *)value name:(NSString *)name {
	if (![self ensureConfigured]) {
		return;
	}
	NSString *sanitized_name = SanitizeUserPropertyName(name);
	if (sanitized_name.length == 0) {
		return;
	}
	NSString *sanitized_value = value.length > 0 ? TruncateNSString(value, 36) : nil;
	RunOnMainSync(^{
		[FIRAnalytics setUserPropertyString:sanitized_value forName:sanitized_name];
	});
}

- (void)setCrashlyticsCustomKey:(NSString *)name value:(NSObject *)value {
	if (![self ensureConfigured]) {
		return;
	}
	NSString *sanitized_name = SanitizeCrashlyticsKey(name);
	if (sanitized_name.length == 0) {
		return;
	}
	RunOnMainSync(^{
		[[FIRCrashlytics crashlytics] setCustomValue:value forKey:sanitized_name];
	});
}

- (void)logCrashlyticsMessage:(NSString *)message {
	if (![self ensureConfigured]) {
		return;
	}
	NSString *resolved = TruncateNSString(message ?: @"", 512);
	if (resolved.length == 0) {
		return;
	}
	RunOnMainSync(^{
		[[FIRCrashlytics crashlytics] logWithFormat:@"%@", resolved];
	});
}

- (void)recordNonfatal:(NSString *)message details:(NSDictionary<NSString *, id> *)details {
	if (![self ensureConfigured]) {
		return;
	}
	NSString *resolved = TruncateNSString(message ?: @"Nonfatal error", 256);
	NSDictionary<NSString *, id> *user_info = details ?: @{ NSLocalizedDescriptionKey: resolved };
	NSError *error = [NSError errorWithDomain:@"GodotFirebase" code:1 userInfo:user_info];
	RunOnMainSync(^{
		[[FIRCrashlytics crashlytics] recordError:error userInfo:user_info];
	});
}

- (void)triggerTestCrash {
	if (![self ensureConfigured]) {
		return;
	}
	RunOnMainSync(^{
		FIRCrashlytics *crashlytics = [FIRCrashlytics crashlytics];
		[crashlytics logWithFormat:@"%@", @"GodotFirebase trigger_test_crash invoked"];
		[crashlytics setCustomValue:@"debug_menu" forKey:@"fatal_test_origin"];
		volatile int *crash_ptr = (volatile int *)NULL;
		*crash_ptr = 1337;
	});
}

@end

FirebasePlugin::FirebasePlugin() {
	instance = this;
	bridge = [[FirebaseBridge alloc] initWithPlugin:this];
}

FirebasePlugin::~FirebasePlugin() {
	bridge = nil;
	if (instance == this) {
		instance = nullptr;
	}
}

FirebasePlugin *FirebasePlugin::get_singleton() {
	return instance;
}

bool FirebasePlugin::is_ready() const {
	return bridge != nil ? [bridge isReady] : false;
}

bool FirebasePlugin::isReady() const {
	return is_ready();
}

void FirebasePlugin::log_event(String event_name, Dictionary params) {
	if (bridge == nil) {
		return;
	}
	[bridge logEventNamed:StringToNSString(event_name) parameters:AnalyticsDictionaryFromGodot(params)];
}

void FirebasePlugin::logEvent(String event_name, Dictionary params) {
	log_event(event_name, params);
}

void FirebasePlugin::set_user_id(String user_id) {
	if (bridge == nil) {
		return;
	}
	[bridge setUserID:StringToNSString(user_id)];
}

void FirebasePlugin::setUserId(String user_id) {
	set_user_id(user_id);
}

void FirebasePlugin::set_user_property(String name, String value) {
	if (bridge == nil) {
		return;
	}
	[bridge setUserProperty:StringToNSString(value) name:StringToNSString(name)];
}

void FirebasePlugin::setUserProperty(String name, String value) {
	set_user_property(name, value);
}

void FirebasePlugin::set_crashlytics_custom_key(String name, Variant value) {
	if (bridge == nil) {
		return;
	}
	[bridge setCrashlyticsCustomKey:StringToNSString(name) value:NSObjectForCrashlyticsVariant(value)];
}

void FirebasePlugin::setCrashlyticsCustomKey(String name, Variant value) {
	set_crashlytics_custom_key(name, value);
}

void FirebasePlugin::log_crashlytics_message(String message) {
	if (bridge == nil) {
		return;
	}
	[bridge logCrashlyticsMessage:StringToNSString(message)];
}

void FirebasePlugin::logCrashlyticsMessage(String message) {
	log_crashlytics_message(message);
}

void FirebasePlugin::record_nonfatal(String message, Dictionary details) {
	if (bridge == nil) {
		return;
	}
	[bridge recordNonfatal:StringToNSString(message) details:CrashlyticsUserInfoFromGodot(details, StringToNSString(message))];
}

void FirebasePlugin::recordNonfatal(String message, Dictionary details) {
	record_nonfatal(message, details);
}

void FirebasePlugin::trigger_test_crash() {
	if (bridge == nil) {
		return;
	}
	[bridge triggerTestCrash];
}

void FirebasePlugin::triggerTestCrash() {
	trigger_test_crash();
}

void FirebasePlugin::notify_firebase_ready() {
	emit_signal(FIREBASE_READY_SIGNAL);
}

void FirebasePlugin::notify_firebase_error(int code, const String &message) {
	emit_signal(FIREBASE_ERROR_SIGNAL, code, message);
}

void FirebasePlugin::_bind_methods() {
	ClassDB::bind_method("is_ready", &FirebasePlugin::is_ready);
	ClassDB::bind_method("isReady", &FirebasePlugin::isReady);
	ClassDB::bind_method("log_event", &FirebasePlugin::log_event, DEFVAL(Dictionary()));
	ClassDB::bind_method("logEvent", &FirebasePlugin::logEvent, DEFVAL(Dictionary()));
	ClassDB::bind_method("set_user_id", &FirebasePlugin::set_user_id);
	ClassDB::bind_method("setUserId", &FirebasePlugin::setUserId);
	ClassDB::bind_method("set_user_property", &FirebasePlugin::set_user_property);
	ClassDB::bind_method("setUserProperty", &FirebasePlugin::setUserProperty);
	ClassDB::bind_method("set_crashlytics_custom_key", &FirebasePlugin::set_crashlytics_custom_key);
	ClassDB::bind_method("setCrashlyticsCustomKey", &FirebasePlugin::setCrashlyticsCustomKey);
	ClassDB::bind_method("log_crashlytics_message", &FirebasePlugin::log_crashlytics_message);
	ClassDB::bind_method("logCrashlyticsMessage", &FirebasePlugin::logCrashlyticsMessage);
	ClassDB::bind_method("record_nonfatal", &FirebasePlugin::record_nonfatal, DEFVAL(Dictionary()));
	ClassDB::bind_method("recordNonfatal", &FirebasePlugin::recordNonfatal, DEFVAL(Dictionary()));
	ClassDB::bind_method("trigger_test_crash", &FirebasePlugin::trigger_test_crash);
	ClassDB::bind_method("triggerTestCrash", &FirebasePlugin::triggerTestCrash);

	ADD_SIGNAL(MethodInfo(FIREBASE_READY_SIGNAL));
	ADD_SIGNAL(MethodInfo(FIREBASE_ERROR_SIGNAL, PropertyInfo(Variant::INT, "code"), PropertyInfo(Variant::STRING, "message")));
}
