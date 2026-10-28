package com.ultron.assistant

import android.content.Context

object Cfg {
    const val DEFAULT_VOICE = "23866d1d2134461cbcefe95d1bd8bfcf"
    private fun sp(c: Context) = c.getSharedPreferences("ultron", Context.MODE_PRIVATE)
    fun get(c: Context, k: String): String =
        sp(c).getString(k, if (k == "voice") DEFAULT_VOICE else "") ?: ""
    fun set(c: Context, k: String, v: String) { sp(c).edit().putString(k, v).apply() }

    fun addMissed(c: Context, line: String) {
        val all = (listOf(line) + get(c, "missed").split("\n").filter { it.isNotBlank() }).take(20)
        set(c, "missed", all.joinToString("\n"))
    }
    fun missed(c: Context): List<String> = get(c, "missed").split("\n").filter { it.isNotBlank() }
}
