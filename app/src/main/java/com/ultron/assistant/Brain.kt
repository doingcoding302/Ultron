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

    private fun call(url: String, key: String, vertex: Boolean, body: String): Pair<Int, String> {
        val c = URL(url).openConnection() as HttpURLConnection
        c.requestMethod = "POST"
        c.setRequestProperty("Content-Type", "application/json")
        if (!vertex) c.setRequestProperty("x-goog-api-key", key)
        c.connectTimeout = 15000; c.readTimeout = 40000
        c.doOutput = true
        c.outputStream.use { it.write(body.toByteArray()) }
        val code = c.responseCode
        val txt = (if (code < 400) c.inputStream else c.errorStream)?.bufferedReader()?.readText() ?: ""
        return Pair(code, txt)
    }

    fun ask(ctx: Context, q: String): String {
        val key = Cfg.get(ctx, "gemini").trim()
        if (key.isBlank()) return "Open my settings and give me an API key first."
        // Keys starting with "AQ." are Google Vertex AI keys; "AIza..." are AI Studio keys.
        val vertex = key.startsWith("AQ.")
        val userModel = Cfg.get(ctx, "model").trim()
        val models = if (userModel.isNotBlank()) listOf(userModel)
            else listOf("gemini-2.5-flash", "gemini-2.0-flash", "gemini-2.5-flash-lite")
        val body = JSONObject()
            .put("systemInstruction", JSONObject().put("parts", JSONArray().put(JSONObject().put("text", SYS))))
            .put("contents", JSONArray().put(JSONObject().put("role", "user")
                .put("parts", JSONArray().put(JSONObject().put("text", q)))))
            .toString()
        var last = ""
        for (m in models) {
            val url = if (vertex)
                "https://aiplatform.googleapis.com/v1/publishers/google/models/$m:generateContent?key=$key"
            else "https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent"
            val (code, txt) = try { call(url, key, vertex, body) } catch (e: Exception) { return "I can't reach the network: ${e.message}" }
            if (code < 400) {
                return try {
                    JSONObject(txt).getJSONArray("candidates").getJSONObject(0)
                        .getJSONObject("content").getJSONArray("parts").getJSONObject(0)
                        .getString("text").replace(Regex("[*#`]"), "").trim()
                } catch (e: Exception) { "I got an empty answer. Try again." }
            }
            val msg = try { JSONObject(txt).getJSONObject("error").getString("message").take(110) } catch (e: Exception) { "" }
            last = "Request failed, code $code. $msg"
            if (code != 404) break
        }
        return last
    }
}
