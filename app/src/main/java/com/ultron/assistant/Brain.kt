package com.ultron.assistant

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

object Brain {
    private const val SYS = "You are ULTRON, the user's personal AI assistant living on their tablet. " +
        "Calm, dry, confident, with a faint menacing wit, but always loyal and genuinely helpful. " +
        "Your replies are spoken aloud, so keep them to 1-3 short sentences. Plain text only, no markdown."

    fun ask(ctx: Context, q: String): String {
        val key = Cfg.get(ctx, "gemini")
        if (key.isBlank()) return "Open my settings and give me an API key first."
        val model = Cfg.get(ctx, "model").ifBlank { "gemini-2.5-flash" }
        val body = JSONObject()
            .put("systemInstruction", JSONObject().put("parts", JSONArray().put(JSONObject().put("text", SYS))))
            .put("contents", JSONArray().put(JSONObject().put("role", "user")
                .put("parts", JSONArray().put(JSONObject().put("text", q)))))
        val c = URL("https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent")
            .openConnection() as HttpURLConnection
        c.requestMethod = "POST"
        c.setRequestProperty("Content-Type", "application/json")
        c.setRequestProperty("x-goog-api-key", key)
        c.connectTimeout = 15000; c.readTimeout = 30000
        c.doOutput = true
        c.outputStream.use { it.write(body.toString().toByteArray()) }
        if (c.responseCode >= 400) return "The request failed with code ${c.responseCode}. Check the key."
        val txt = c.inputStream.bufferedReader().readText()
        val out = JSONObject(txt).getJSONArray("candidates").getJSONObject(0)
            .getJSONObject("content").getJSONArray("parts").getJSONObject(0).getString("text")
        return out.replace(Regex("[*#`]"), "").trim()
    }
}
