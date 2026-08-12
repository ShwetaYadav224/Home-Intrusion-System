package com.homesecurity.home_security

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

class BackgroundMonitorService : Service() {
    companion object {
        private const val TAG = "BackgroundMonitor"
        private const val SERVICE_NOTIFICATION_ID = 7001
        private const val SERVICE_CHANNEL_ID = "security_background_service"
        private const val SECURITY_CHANNEL_ID = "security_alerts"
        private const val DOOR_CHANNEL_ID = "door_events"
        private const val POLL_INTERVAL_SECONDS = 10L

        fun start(context: Context) {
            val intent = Intent(context, BackgroundMonitorService::class.java)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, BackgroundMonitorService::class.java))
        }
    }

    private var scheduler: ScheduledExecutorService? = null
    private var pollingTask: ScheduledFuture<*>? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val config = BackgroundMonitorConfig.snapshot(this)
        if (!config.enabled || config.baseUrl.isBlank() || config.accessToken.isBlank()) {
            stopSelf()
            return START_NOT_STICKY
        }

        startForeground(SERVICE_NOTIFICATION_ID, buildServiceNotification())
        startPollingLoop()
        return START_STICKY
    }

    override fun onDestroy() {
        pollingTask?.cancel(true)
        scheduler?.shutdownNow()
        pollingTask = null
        scheduler = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startPollingLoop() {
        if (pollingTask?.isCancelled == false) {
            return
        }

        scheduler = Executors.newSingleThreadScheduledExecutor()
        pollingTask = scheduler?.scheduleWithFixedDelay(
            {
                try {
                    pollAlerts()
                    pollDoorEvents()
                } catch (error: Exception) {
                    Log.e(TAG, "Background polling failed", error)
                }
            },
            0,
            POLL_INTERVAL_SECONDS,
            TimeUnit.SECONDS,
        )
    }

    private fun pollAlerts() {
        val response = requestJson("/api/v1/alerts/?acknowledged=false&limit=10") ?: return
        val alerts = response.optJSONObject("data")?.optJSONArray("alerts") ?: JSONArray()
        val config = BackgroundMonitorConfig.snapshot(this)
        if (alerts.length() == 0) {
            if (!config.alertsInitialized) {
                BackgroundMonitorConfig.markAlertsInitialized(this)
            }
            return
        }

        val sortedAlerts = alerts.toSortedList()

        if (!config.alertsInitialized) {
            val baselineId = sortedAlerts.lastOrNull()?.optInt("id") ?: 0
            if (baselineId > 0) {
                BackgroundMonitorConfig.updateLastSeenAlertId(this, baselineId)
            } else {
                BackgroundMonitorConfig.markAlertsInitialized(this)
            }
            return
        }

        var maxSeenId = config.lastSeenAlertId
        sortedAlerts.forEach { alert ->
            val alertId = alert.optInt("id")
            if (alertId <= config.lastSeenAlertId) {
                return@forEach
            }

            maxSeenId = maxOf(maxSeenId, alertId)
            showSecurityNotification(
                notificationId = alertId,
                title = alert.optString("title", "Security alert"),
                body = alert.optString("message", "A new security alert was detected."),
            )
        }

        if (maxSeenId > config.lastSeenAlertId) {
            BackgroundMonitorConfig.updateLastSeenAlertId(this, maxSeenId)
        }
    }

    private fun pollDoorEvents() {
        val response = requestJson("/api/v1/door-events/?limit=10") ?: return
        val events = response.optJSONObject("data")?.optJSONArray("door_events") ?: JSONArray()
        val config = BackgroundMonitorConfig.snapshot(this)
        if (events.length() == 0) {
            if (!config.doorEventsInitialized) {
                BackgroundMonitorConfig.markDoorEventsInitialized(this)
            }
            return
        }

        val sortedEvents = events.toSortedList()

        if (!config.doorEventsInitialized) {
            val baselineId = sortedEvents.lastOrNull()?.optInt("id") ?: 0
            if (baselineId > 0) {
                BackgroundMonitorConfig.updateLastSeenDoorEventId(this, baselineId)
            } else {
                BackgroundMonitorConfig.markDoorEventsInitialized(this)
            }
            return
        }

        var maxSeenId = config.lastSeenDoorEventId
        sortedEvents.forEach { event ->
            val eventId = event.optInt("id")
            if (eventId <= config.lastSeenDoorEventId) {
                return@forEach
            }

            maxSeenId = maxOf(maxSeenId, eventId)
            val isOpen = event.optString("status").equals("open", ignoreCase = true)
            val title = if (isOpen) "Door opened" else "Door closed"
            val doorName = event.optString("device_name", "Door")
            val message = "$doorName was ${if (isOpen) "opened" else "closed"}."
            showDoorNotification(
                notificationId = 100000 + eventId,
                title = title,
                body = message,
            )
        }

        if (maxSeenId > config.lastSeenDoorEventId) {
            BackgroundMonitorConfig.updateLastSeenDoorEventId(this, maxSeenId)
        }
    }

    private fun requestJson(path: String, allowRefresh: Boolean = true): JSONObject? {
        val config = BackgroundMonitorConfig.snapshot(this)
        if (config.baseUrl.isBlank() || config.accessToken.isBlank()) {
            return null
        }

        val url = URL("${config.baseUrl}$path")
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 5000
            readTimeout = 5000
            setRequestProperty("Accept", "application/json")
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Authorization", "Bearer ${config.accessToken}")
        }

        return try {
            when (connection.responseCode) {
                HttpURLConnection.HTTP_OK -> {
                    val responseBody = connection.inputStream.bufferedReader().use { reader ->
                        reader.readText()
                    }
                    JSONObject(responseBody)
                }

                HttpURLConnection.HTTP_UNAUTHORIZED -> {
                    if (allowRefresh && refreshAccessToken()) {
                        requestJson(path, allowRefresh = false)
                    } else {
                        BackgroundMonitorConfig.clearAuth(this)
                        stopSelf()
                        null
                    }
                }

                else -> {
                    Log.w(TAG, "Request to $path failed with ${connection.responseCode}")
                    null
                }
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun refreshAccessToken(): Boolean {
        val config = BackgroundMonitorConfig.snapshot(this)
        if (config.baseUrl.isBlank() || config.refreshToken.isBlank()) {
            return false
        }

        val url = URL("${config.baseUrl}/api/v1/auth/token/refresh/")
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            connectTimeout = 5000
            readTimeout = 5000
            setRequestProperty("Accept", "application/json")
            setRequestProperty("Content-Type", "application/json")
        }

        return try {
            val body = JSONObject().put("refresh", config.refreshToken).toString()
            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(body)
                writer.flush()
            }

            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                Log.w(TAG, "Token refresh failed with ${connection.responseCode}")
                return false
            }

            val responseBody = connection.inputStream.bufferedReader().use { reader ->
                reader.readText()
            }
            val json = JSONObject(responseBody)
            val data = json.optJSONObject("data") ?: return false
            val accessToken = data.optString("access")
            if (accessToken.isBlank()) {
                return false
            }

            val refreshToken = data.optString("refresh").ifBlank { config.refreshToken }
            BackgroundMonitorConfig.updateAccessToken(this, accessToken, refreshToken)
            true
        } catch (error: Exception) {
            Log.e(TAG, "Token refresh failed", error)
            false
        } finally {
            connection.disconnect()
        }
    }

    private fun buildServiceNotification(): Notification {
        return NotificationCompat.Builder(this, SERVICE_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Home Security is monitoring")
            .setContentText("Local background notifications are active.")
            .setContentIntent(launchPendingIntent())
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .build()
    }

    private fun showSecurityNotification(notificationId: Int, title: String, body: String) {
        val notification = NotificationCompat.Builder(this, SECURITY_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(launchPendingIntent())
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        notify(notificationId, notification)
    }

    private fun showDoorNotification(notificationId: Int, title: String, body: String) {
        val notification = NotificationCompat.Builder(this, DOOR_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(launchPendingIntent())
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        notify(notificationId, notification)
    }

    private fun notify(notificationId: Int, notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "POST_NOTIFICATIONS permission not granted; skipping notification $notificationId")
            return
        }

        NotificationManagerCompat.from(this).notify(notificationId, notification)
    }

    private fun launchPendingIntent(): PendingIntent? {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        return PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(NotificationManager::class.java)
        val serviceChannel = NotificationChannel(
            SERVICE_CHANNEL_ID,
            "Background Monitoring",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps local security monitoring active when the app is closed."
            setShowBadge(false)
        }

        val securityChannel = NotificationChannel(
            SECURITY_CHANNEL_ID,
            "Security Alerts",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Critical stranger and security alerts."
            enableVibration(true)
        }

        val doorChannel = NotificationChannel(
            DOOR_CHANNEL_ID,
            "Door Events",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Door open and close events."
            enableVibration(true)
        }

        manager.createNotificationChannel(serviceChannel)
        manager.createNotificationChannel(securityChannel)
        manager.createNotificationChannel(doorChannel)
    }

    private fun JSONArray.toSortedList(): List<JSONObject> {
        val items = mutableListOf<JSONObject>()
        for (index in 0 until length()) {
            items.add(optJSONObject(index) ?: continue)
        }
        return items.sortedBy { it.optInt("id") }
    }
}
