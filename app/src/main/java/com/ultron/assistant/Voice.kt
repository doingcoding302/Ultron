package com.ultron.assistant

import android.content.Context
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

object Voice {
    private var tts: TextToSpeech? = null
    private var ready = false
    private var player: MediaPlayer? = null
    private val bg = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    @Volatile var lastError = ""

    fun speak(ctx: Context, text: String, done: () -> Unit = {}) {
        val app = ctx.applicationContext
        bg.execute {
            val fk = Cfg.get(app, "fish").trim()
            lastError = ""
            if (fk.isNotBlank() && fish(app, text, fk)) { done(); return@execute }
            if (fk.isBlank()) lastError = "No Fish Audio key, using system voice"
            main.post { local(app, text, done) }
        }
    }

    fun stop() {
        try { player?.stop() } catch (_: Exception) {}
        try { tts?.stop() } catch (_: Exception) {}
    }

    // Fish Audio TTS with the Ultron voice model id
    private fun fish(app: Context, text: String, key: String): Boolean {
        for (m in listOf<String?>("s1", null)) {
            try {
                val c = URL("https://api.fish.audio/v1/tts").openConnection() as HttpURLConnection
                c.requestMethod = "POST"
                c.setRequestProperty("Authorization", "Bearer $key")
                c.setRequestProperty("Content-Type", "application/json")
                if (m != null) c.setRequestProperty("model", m)
                c.connectTimeout = 15000; c.readTimeout = 60000
                c.doOutput = true
                val body = JSONObject().put("text", text)
                    .put("reference_id", Cfg.get(app, "voice").trim()).put("format", "mp3")
                c.outputStream.use { it.write(body.toString().toByteArray()) }
                val code = c.responseCode
                if (code >= 400) { lastError = "Fish voice error $code"; continue }
                val f = File(app.cacheDir, "u.mp3")
                c.inputStream.use { i -> f.outputStream().use { o -> i.copyTo(o) } }
                val latch = CountDownLatch(1)
                val mp = MediaPlayer()
                player = mp
                mp.setDataSource(f.absolutePath)
                mp.setOnCompletionListener { latch.countDown() }
                mp.setOnErrorListener { _, _, _ -> latch.countDown(); true }
                mp.prepare(); mp.start()
                latch.await(90, TimeUnit.SECONDS)
                mp.release(); player = null
                lastError = ""
                return true
            } catch (e: Exception) { lastError = "Fish voice failed: ${e.message}" }
        }
        return false
    }

    // Fallback: deep, slow system voice
    private fun local(app: Context, text: String, done: () -> Unit) {
        fun go() {
            val t = tts ?: return done()
            t.setPitch(0.5f); t.setSpeechRate(0.88f)
            t.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(u: String?) {}
                override fun onDone(u: String?) { done() }
                @Deprecated("Deprecated in Java")
                override fun onError(u: String?) { done() }
            })
            t.speak(text, TextToSpeech.QUEUE_FLUSH, null, "u")
        }
        if (ready) go() else tts = TextToSpeech(app) { s ->
            if (s == TextToSpeech.SUCCESS) { ready = true; go() } else { lastError += " | no system voice engine"; done() }
        }
    }
}
