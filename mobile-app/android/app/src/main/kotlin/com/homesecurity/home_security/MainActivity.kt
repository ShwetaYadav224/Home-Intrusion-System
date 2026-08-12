package com.homesecurity.home_security

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.homesecurity.home_security/background_monitor"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bootstrap" -> {
                        BackgroundMonitorConfig.bootstrap(
                            context = this,
                            baseUrl = call.argument<String>("baseUrl"),
                            accessToken = call.argument<String>("accessToken"),
                            refreshToken = call.argument<String>("refreshToken"),
                            lastSeenAlertId = call.argument<Int>("lastSeenAlertId") ?: 0,
                            lastSeenDoorEventId = call.argument<Int>("lastSeenDoorEventId") ?: 0,
                        )
                        result.success(true)
                    }

                    "updateAuth" -> {
                        BackgroundMonitorConfig.updateAuth(
                            context = this,
                            baseUrl = call.argument<String>("baseUrl"),
                            accessToken = call.argument<String>("accessToken"),
                            refreshToken = call.argument<String>("refreshToken"),
                        )
                        result.success(true)
                    }

                    "clearAuth" -> {
                        BackgroundMonitorConfig.clearAuth(this)
                        BackgroundMonitorService.stop(this)
                        result.success(true)
                    }

                    "start" -> {
                        BackgroundMonitorConfig.setEnabled(this, true)
                        BackgroundMonitorService.start(this)
                        result.success(true)
                    }

                    "stop" -> {
                        val resetState = call.argument<Boolean>("resetState") ?: false
                        BackgroundMonitorConfig.setEnabled(this, false)
                        if (resetState) {
                            BackgroundMonitorConfig.resetSeenState(this)
                        }
                        BackgroundMonitorService.stop(this)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
