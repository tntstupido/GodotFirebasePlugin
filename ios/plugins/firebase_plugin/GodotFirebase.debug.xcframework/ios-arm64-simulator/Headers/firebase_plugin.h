#ifndef FIREBASE_PLUGIN_H
#define FIREBASE_PLUGIN_H

#import <Foundation/Foundation.h>

#include "core/object/class_db.h"
#include "core/object/object.h"
#include "core/string/ustring.h"
#include "core/variant/dictionary.h"
#include "core/variant/variant.h"

@class FirebaseBridge;

class FirebasePlugin : public Object {
	GDCLASS(FirebasePlugin, Object);

private:
	static FirebasePlugin *instance;
	__strong FirebaseBridge *bridge;

	static void _bind_methods();

public:
	static FirebasePlugin *get_singleton();

	FirebasePlugin();
	~FirebasePlugin();

	bool is_ready() const;
	bool isReady() const;
	void log_event(String event_name, Dictionary params = Dictionary());
	void logEvent(String event_name, Dictionary params = Dictionary());
	void set_user_id(String user_id);
	void setUserId(String user_id);
	void set_user_property(String name, String value);
	void setUserProperty(String name, String value);
	void set_crashlytics_custom_key(String name, Variant value);
	void setCrashlyticsCustomKey(String name, Variant value);
	void log_crashlytics_message(String message);
	void logCrashlyticsMessage(String message);
	void record_nonfatal(String message, Dictionary details = Dictionary());
	void recordNonfatal(String message, Dictionary details = Dictionary());

	void notify_firebase_ready();
	void notify_firebase_error(int code, const String &message);
};

#endif
