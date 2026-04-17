#include "firebase_plugin.h"
// Intentionally empty.
//
// The iOS bridge implementation lives in `firebase_plugin_bootstrap.mm`.
// Keeping this translation unit without init/deinit definitions avoids
// duplicate symbols during static archive linking.
