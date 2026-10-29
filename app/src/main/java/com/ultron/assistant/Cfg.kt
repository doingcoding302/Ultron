package com.ultron.assistant

import android.content.Context

val LANGS = listOf(
    "auto" to "Auto", "en-US" to "English", "hi-IN" to "Hindi", "ur-PK" to "Urdu", "ar-SA" to "Arabic",
    "bn-IN" to "Bengali", "es-ES" to "Spanish", "fr-FR" to "French", "de-DE" to "German",
    "pt-BR" to "Portuguese", "ru-RU" to "Russian", "tr-TR" to "Turkish", "it-IT" to "Italian",
    "id-ID" to "Indonesian", "ja-JP" to "Japanese", "ko-KR" to "Korean", "zh-CN" to "Chinese"
)

object Cfg {
    private fun sp(c: Context) = c.getSharedPreferences("ultron", Context.MODE_PRIVATE)

    // Keys and the voice id are baked in at build time from GitHub Secrets (see build.gradle.kts).
    fun get(c: Context, k: String): String = when (k) {
        "gemini" -> BuildConfig.GOOGLE_KEY
        "fish" -> BuildConfig.FISH_KEY
        "voice" -> BuildConfig.VOICE_ID
        "model" -> ""
        else -> sp(c).getString(k, "") ?: ""
    }
    fun set(c: Context, k: String, v: String) { sp(c).edit().putString(k, v).apply() }

    fun addMissed(c: Context, line: String) {
        val all = (listOf(line) + get(c, "missed").split("\n").filter { it.isNotBlank() }).take(20)
        set(c, "missed", all.joinToString("\n"))
    }
    fun missed(c: Context): List<String> = get(c, "missed").split("\n").filter { it.isNotBlank() }
}
