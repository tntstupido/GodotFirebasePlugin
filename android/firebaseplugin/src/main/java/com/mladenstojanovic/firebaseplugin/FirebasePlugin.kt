package com.mladenstojanovic.firebaseplugin

import android.app.Activity
import android.util.Log
import android.view.View
import com.google.firebase.FirebaseApp
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.crashlytics.FirebaseCrashlytics
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.remoteconfig.FirebaseRemoteConfig
import com.google.firebase.remoteconfig.FirebaseRemoteConfigSettings
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

@Suppress("unused")
class FirebasePlugin(godot: Godot) : GodotPlugin(godot) {

    companion object {
        private const val TAG = "FirebasePlugin"
    }

    private var analytics: FirebaseAnalytics? = null
    private var crashlytics: FirebaseCrashlytics? = null
    private var remoteConfig: FirebaseRemoteConfig? = null

    override fun getPluginName(): String = "FirebasePlugin"

    override fun getPluginSignals(): Set<SignalInfo> {
        return setOf(
            SignalInfo("firebase_initialized", Boolean::class.javaObjectType, String::class.java),
            SignalInfo("remote_config_updated", Boolean::class.javaObjectType, String::class.java),
            SignalInfo("messaging_token_received", String::class.java),
            SignalInfo("firebase_error", Long::class.javaObjectType, String::class.java)
        )
    }

    override fun onMainCreate(activity: Activity?): View? {
        if (activity == null) {
            emitSignalSafe("firebase_error", -1L, "Activity unavailable")
            return null
        }

        try {
            FirebaseApp.initializeApp(activity)
            analytics = FirebaseAnalytics.getInstance(activity)
            crashlytics = FirebaseCrashlytics.getInstance()

            val rc = FirebaseRemoteConfig.getInstance()
            rc.setConfigSettingsAsync(
                FirebaseRemoteConfigSettings.Builder()
                    .setMinimumFetchIntervalInSeconds(3600)
                    .build()
            )
            remoteConfig = rc

            emitSignalSafe("firebase_initialized", true, "Firebase initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Initialization failed", e)
            emitSignalSafe("firebase_initialized", false, "Initialization failed: ${e.message}")
            emitSignalSafe("firebase_error", -2L, "Initialization failed: ${e.message}")
        }

        return null
    }

    @UsedByGodot
    fun initialize() {
        val activity = getActivity()
        if (activity == null) {
            emitSignalSafe("firebase_initialized", false, "Activity unavailable")
            emitSignalSafe("firebase_error", -1L, "Activity unavailable")
            return
        }
        onMainCreate(activity)
    }

    @UsedByGodot
    fun logEvent(name: String, paramsJson: String = "") {
        val instance = analytics ?: run {
            emitSignalSafe("firebase_error", -3L, "Analytics unavailable")
            return
        }
        val bundle = FirebaseJson.bundleFromJson(paramsJson)
        instance.logEvent(name, bundle)
    }

    @UsedByGodot
    fun setUserProperty(name: String, value: String) {
        analytics?.setUserProperty(name, value)
    }

    @UsedByGodot
    fun setUserId(userId: String) {
        analytics?.setUserId(userId)
    }

    @UsedByGodot
    fun setCrashlyticsEnabled(enabled: Boolean) {
        crashlytics?.setCrashlyticsCollectionEnabled(enabled)
    }

    @UsedByGodot
    fun setCustomKey(key: String, value: String) {
        crashlytics?.setCustomKey(key, value)
    }

    @UsedByGodot
    fun recordError(message: String) {
        val ex = RuntimeException(message)
        crashlytics?.recordException(ex)
    }

    @UsedByGodot
    fun remoteConfigFetchAndActivate() {
        val rc = remoteConfig ?: run {
            emitSignalSafe("remote_config_updated", false, "Remote Config unavailable")
            emitSignalSafe("firebase_error", -4L, "Remote Config unavailable")
            return
        }
        rc.fetchAndActivate()
            .addOnSuccessListener {
                emitSignalSafe("remote_config_updated", true, "Fetch and activate succeeded")
            }
            .addOnFailureListener { e ->
                emitSignalSafe("remote_config_updated", false, "Fetch failed: ${e.message}")
                emitSignalSafe("firebase_error", -5L, "Fetch failed: ${e.message}")
            }
    }

    @UsedByGodot
    fun remoteConfigGetString(key: String, fallback: String): String {
        val rc = remoteConfig ?: return fallback
        val value = rc.getString(key)
        return if (value.isEmpty()) fallback else value
    }

    @UsedByGodot
    fun remoteConfigGetBool(key: String, fallback: Boolean): Boolean {
        val rc = remoteConfig ?: return fallback
        return try {
            rc.getBoolean(key)
        } catch (_: Exception) {
            fallback
        }
    }

    @UsedByGodot
    fun remoteConfigGetInt(key: String, fallback: Long): Long {
        val rc = remoteConfig ?: return fallback
        return try {
            rc.getLong(key)
        } catch (_: Exception) {
            fallback
        }
    }

    @UsedByGodot
    fun messagingGetToken() {
        FirebaseMessaging.getInstance().token
            .addOnSuccessListener { token ->
                emitSignalSafe("messaging_token_received", token)
            }
            .addOnFailureListener { e ->
                emitSignalSafe("firebase_error", -6L, "Token failed: ${e.message}")
            }
    }

    @UsedByGodot
    fun messagingSubscribe(topic: String) {
        FirebaseMessaging.getInstance().subscribeToTopic(topic)
            .addOnFailureListener { e ->
                emitSignalSafe("firebase_error", -7L, "Subscribe failed: ${e.message}")
            }
    }

    @UsedByGodot
    fun messagingUnsubscribe(topic: String) {
        FirebaseMessaging.getInstance().unsubscribeFromTopic(topic)
            .addOnFailureListener { e ->
                emitSignalSafe("firebase_error", -8L, "Unsubscribe failed: ${e.message}")
            }
    }

    private fun emitSignalSafe(signalName: String, vararg args: Any?) {
        try {
            emitSignal(signalName, *args)
        } catch (e: Exception) {
            Log.e(TAG, "emitSignal failed for $signalName", e)
        }
    }
}
