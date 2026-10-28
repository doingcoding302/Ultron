package com.ultron.assistant

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class CallReceiver : BroadcastReceiver() {
    companion object {
        var last: String = TelephonyManager.EXTRA_STATE_IDLE
        var num: String? = null
        var answered = false
        var at = 0L
    }

    override fun onReceive(c: Context, i: Intent) {
        if (i.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return
        val s = i.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val n = i.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
        when (s) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                if (last != TelephonyManager.EXTRA_STATE_RINGING) { answered = false; at = System.currentTimeMillis(); num = null }
                if (!n.isNullOrBlank()) num = n
            }
            TelephonyManager.EXTRA_STATE_OFFHOOK -> if (last == TelephonyManager.EXTRA_STATE_RINGING) answered = true
            TelephonyManager.EXTRA_STATE_IDLE -> if (last == TelephonyManager.EXTRA_STATE_RINGING && !answered) report(c)
        }
        last = s
    }

    private fun report(c: Context) {
        val pr = goAsync()
        val who = Contacts.nameFor(c, num) ?: num ?: "an unknown number"
        val time = SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(at))
        val msg = "You missed a call from $who at $time."
        Cfg.addMissed(c, msg)
        try {
            val nm = c.getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(NotificationChannel("missed", "Missed calls", NotificationManager.IMPORTANCE_DEFAULT))
            nm.notify(2, Notification.Builder(c, "missed").setSmallIcon(R.drawable.ic_ultron)
                .setContentTitle("Ultron").setContentText(msg).build())
        } catch (_: Exception) {}
        Voice.speak(c, msg) { pr.finish() }
    }
}
