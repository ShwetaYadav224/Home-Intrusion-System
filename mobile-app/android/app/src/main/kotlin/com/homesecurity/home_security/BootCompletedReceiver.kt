package com.homesecurity.home_security

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) {
            return
        }

        val config = BackgroundMonitorConfig.snapshot(context)
        if (!config.enabled || config.baseUrl.isBlank() || config.accessToken.isBlank()) {
            return
        }

        BackgroundMonitorService.start(context)
    }
}
