package com.homesecurity.home_security

import android.content.Context

object BackgroundMonitorConfig {
    private const val PREFS_NAME = "background_monitor"
    private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
    private const val FLUTTER_ACCESS_TOKEN_KEY = "flutter.access_token"
    private const val FLUTTER_REFRESH_TOKEN_KEY = "flutter.refresh_token"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_BASE_URL = "base_url"
    private const val KEY_ACCESS_TOKEN = "access_token"
    private const val KEY_REFRESH_TOKEN = "refresh_token"
    private const val KEY_LAST_SEEN_ALERT_ID = "last_seen_alert_id"
    private const val KEY_LAST_SEEN_DOOR_EVENT_ID = "last_seen_door_event_id"
    private const val KEY_ALERTS_INITIALIZED = "alerts_initialized"
    private const val KEY_DOOR_EVENTS_INITIALIZED = "door_events_initialized"

    data class Snapshot(
        val enabled: Boolean,
        val baseUrl: String,
        val accessToken: String,
        val refreshToken: String,
        val lastSeenAlertId: Int,
        val lastSeenDoorEventId: Int,
        val alertsInitialized: Boolean,
        val doorEventsInitialized: Boolean,
    )

    fun bootstrap(
        context: Context,
        baseUrl: String?,
        accessToken: String?,
        refreshToken: String?,
        lastSeenAlertId: Int,
        lastSeenDoorEventId: Int,
    ) {
        val prefs = prefs(context)
        prefs.edit().apply {
            if (!baseUrl.isNullOrBlank()) {
                putString(KEY_BASE_URL, baseUrl.trimEnd('/'))
            }
            if (!accessToken.isNullOrBlank()) {
                putString(KEY_ACCESS_TOKEN, accessToken)
            }
            if (!refreshToken.isNullOrBlank()) {
                putString(KEY_REFRESH_TOKEN, refreshToken)
            }
            if (!prefs.contains(KEY_LAST_SEEN_ALERT_ID) && lastSeenAlertId > 0) {
                putInt(KEY_LAST_SEEN_ALERT_ID, lastSeenAlertId)
                putBoolean(KEY_ALERTS_INITIALIZED, true)
            }
            if (!prefs.contains(KEY_LAST_SEEN_DOOR_EVENT_ID) && lastSeenDoorEventId > 0) {
                putInt(KEY_LAST_SEEN_DOOR_EVENT_ID, lastSeenDoorEventId)
                putBoolean(KEY_DOOR_EVENTS_INITIALIZED, true)
            }
            apply()
        }
    }

    fun updateAuth(
        context: Context,
        baseUrl: String?,
        accessToken: String?,
        refreshToken: String?,
    ) {
        val prefs = prefs(context)
        prefs.edit().apply {
            if (!baseUrl.isNullOrBlank()) {
                putString(KEY_BASE_URL, baseUrl.trimEnd('/'))
            }
            if (accessToken != null) {
                putString(KEY_ACCESS_TOKEN, accessToken)
            }
            if (refreshToken != null) {
                putString(KEY_REFRESH_TOKEN, refreshToken)
            }
            apply()
        }
    }

    fun clearAuth(context: Context) {
        prefs(context).edit().apply {
            remove(KEY_ACCESS_TOKEN)
            remove(KEY_REFRESH_TOKEN)
            remove(KEY_ENABLED)
            apply()
        }
        context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(FLUTTER_ACCESS_TOKEN_KEY)
            .remove(FLUTTER_REFRESH_TOKEN_KEY)
            .apply()
    }

    fun resetSeenState(context: Context) {
        prefs(context).edit().apply {
            remove(KEY_LAST_SEEN_ALERT_ID)
            remove(KEY_LAST_SEEN_DOOR_EVENT_ID)
            remove(KEY_ALERTS_INITIALIZED)
            remove(KEY_DOOR_EVENTS_INITIALIZED)
            apply()
        }
    }

    fun setEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    fun updateAccessToken(context: Context, accessToken: String, refreshToken: String? = null) {
        prefs(context).edit().apply {
            putString(KEY_ACCESS_TOKEN, accessToken)
            if (!refreshToken.isNullOrBlank()) {
                putString(KEY_REFRESH_TOKEN, refreshToken)
            }
            apply()
        }
        syncFlutterTokens(context, accessToken, refreshToken)
    }

    fun updateLastSeenAlertId(context: Context, alertId: Int) {
        prefs(context).edit()
            .putInt(KEY_LAST_SEEN_ALERT_ID, alertId)
            .putBoolean(KEY_ALERTS_INITIALIZED, true)
            .apply()
    }

    fun updateLastSeenDoorEventId(context: Context, eventId: Int) {
        prefs(context).edit()
            .putInt(KEY_LAST_SEEN_DOOR_EVENT_ID, eventId)
            .putBoolean(KEY_DOOR_EVENTS_INITIALIZED, true)
            .apply()
    }

    fun markAlertsInitialized(context: Context) {
        prefs(context).edit().putBoolean(KEY_ALERTS_INITIALIZED, true).apply()
    }

    fun markDoorEventsInitialized(context: Context) {
        prefs(context).edit().putBoolean(KEY_DOOR_EVENTS_INITIALIZED, true).apply()
    }

    fun snapshot(context: Context): Snapshot {
        val prefs = prefs(context)
        return Snapshot(
            enabled = prefs.getBoolean(KEY_ENABLED, false),
            baseUrl = prefs.getString(KEY_BASE_URL, "").orEmpty(),
            accessToken = prefs.getString(KEY_ACCESS_TOKEN, "").orEmpty(),
            refreshToken = prefs.getString(KEY_REFRESH_TOKEN, "").orEmpty(),
            lastSeenAlertId = prefs.getInt(KEY_LAST_SEEN_ALERT_ID, 0),
            lastSeenDoorEventId = prefs.getInt(KEY_LAST_SEEN_DOOR_EVENT_ID, 0),
            alertsInitialized = prefs.getBoolean(KEY_ALERTS_INITIALIZED, false),
            doorEventsInitialized = prefs.getBoolean(KEY_DOOR_EVENTS_INITIALIZED, false),
        )
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun syncFlutterTokens(context: Context, accessToken: String, refreshToken: String?) {
        context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .apply {
                putString(FLUTTER_ACCESS_TOKEN_KEY, accessToken)
                if (!refreshToken.isNullOrBlank()) {
                    putString(FLUTTER_REFRESH_TOKEN_KEY, refreshToken)
                }
                apply()
            }
    }
}
