#import "firebase_plugin.h"
#import "firebase_plugin_bootstrap.h"

#include "core/config/engine.h"

static FirebasePlugin *firebase_plugin = nullptr;

void init_firebase_plugin() {
	firebase_plugin = memnew(FirebasePlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("GodotFirebase", firebase_plugin));
}

void deinit_firebase_plugin() {
	if (firebase_plugin != nullptr) {
		memdelete(firebase_plugin);
		firebase_plugin = nullptr;
	}
}
