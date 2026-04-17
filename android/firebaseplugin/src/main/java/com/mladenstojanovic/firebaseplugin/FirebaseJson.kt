package com.mladenstojanovic.firebaseplugin

import android.os.Bundle
import org.json.JSONObject

object FirebaseJson {
    fun bundleFromJson(json: String): Bundle {
        val bundle = Bundle()
        if (json.isBlank()) {
            return bundle
        }
        val obj = JSONObject(json)
        val keys = obj.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = obj.get(key)
            when (value) {
                is Boolean -> bundle.putBoolean(key, value)
                is Int -> bundle.putInt(key, value)
                is Long -> bundle.putLong(key, value)
                is Double -> bundle.putDouble(key, value)
                is Float -> bundle.putFloat(key, value)
                is String -> bundle.putString(key, value)
                else -> bundle.putString(key, value.toString())
            }
        }
        return bundle
    }
}
