package com.ultron.assistant

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.ContactsContract

object Actions {
    private const val NEED_ACC = "Enable my accessibility access first, then ask again."

    /** Returns a spoken reply if this was a local command, or null to let the AI brain answer. */
    fun handle(ctx: Context, raw: String): String? {
        val t = raw.trim().lowercase().trimEnd('.', '!', '?')
        val acc = UltronAccess.inst
        Regex("^(open|launch|start)\\s+(.+)$").find(t)?.let { return openApp(ctx, it.groupValues[2]) }
        Regex("^call\\s+(.+)$").find(t)?.let { return call(ctx, it.groupValues[1]) }
        if (t in listOf("who called", "who called me", "missed calls", "any missed calls", "missed call")) {
            val m = Cfg.missed(ctx)
            return if (m.isEmpty()) "No missed calls on record." else m.take(3).joinToString(" ")
        }
        if (t == "go back" || t == "back") return acc?.let { it.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK); "Done." } ?: NEED_ACC
        if (t == "go home" || t == "home") return acc?.let { it.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME); "Done." } ?: NEED_ACC
        if (t == "recents" || t == "show recents") return acc?.let { it.performGlobalAction(AccessibilityService.GLOBAL_ACTION_RECENTS); "Done." } ?: NEED_ACC
        if (t == "scroll down") return acc?.let { if (it.scroll(true)) "Scrolling." else "Nothing to scroll." } ?: NEED_ACC
        if (t == "scroll up") return acc?.let { if (it.scroll(false)) "Scrolling." else "Nothing to scroll." } ?: NEED_ACC
        Regex("^(click|tap|press)\\s+(on\\s+)?(.+)$").find(t)?.let { m ->
            return acc?.let { if (it.clickText(m.groupValues[3])) "Done." else "I can't find that on screen." } ?: NEED_ACC
        }
        Regex("^type\\s+(.+)$").find(t)?.let { m ->
            return acc?.let { if (it.typeText(m.groupValues[1])) "Typed." else "No text field is focused." } ?: NEED_ACC
        }
        return null
    }

    private fun openApp(ctx: Context, name: String): String {
        val pm = ctx.packageManager
        val q = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val hit = pm.queryIntentActivities(q, 0).firstOrNull {
            it.loadLabel(pm).toString().lowercase().contains(name.trim())
        } ?: return "I can't find an app called $name."
        val i = pm.getLaunchIntentForPackage(hit.activityInfo.packageName) ?: return "I can't launch that."
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ctx.startActivity(i)
        return "Opening ${hit.loadLabel(pm)}."
    }

    private fun call(ctx: Context, who: String): String {
        val digits = who.filter { it.isDigit() || it == '+' }
        val num = if (digits.length >= 5 && who.none { it.isLetter() }) digits else Contacts.numberFor(ctx, who)
        ?: return "I can't find $who in your contacts."
        ctx.startActivity(Intent(Intent.ACTION_CALL, Uri.parse("tel:$num")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return "Calling $who."
    }
}

object Contacts {
    fun nameFor(c: Context, num: String?): String? {
        if (num.isNullOrBlank()) return null
        try {
            val u = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(num))
            c.contentResolver.query(u, arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) return it.getString(0)
            }
        } catch (_: Exception) {}
        return null
    }

    fun numberFor(c: Context, name: String): String? {
        try {
            c.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER),
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " LIKE ?",
                arrayOf("%$name%"), null
            )?.use { if (it.moveToFirst()) return it.getString(0) }
        } catch (_: Exception) {}
        return null
    }
}
