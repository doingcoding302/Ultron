package com.ultron.assistant

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        if (i.action == Intent.ACTION_BOOT_COMPLETED && Settings.canDrawOverlays(c)) {
            try { c.startForegroundService(Intent(c, OverlayService::class.java)) } catch (_: Exception) {}
        }
    }
}
