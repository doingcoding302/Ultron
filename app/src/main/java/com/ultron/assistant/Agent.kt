package com.ultron.assistant

import android.content.Context
import android.os.Handler
import android.os.Looper

object Agent {
    private val h = Handler(Looper.getMainLooper())

    /** States reported: processing -> responding -> idle. Callbacks run on main thread. */
    fun run(ctx: Context, text: String, onState: (String) -> Unit, onReply: (String) -> Unit) {
        val app = ctx.applicationContext
        onState("processing")
        Thread {
            val r = try { Actions.handle(app, text) ?: Brain.ask(app, text) }
            catch (e: Exception) { "Something went wrong: ${e.message}" }
            h.post { onReply(r); onState("responding") }
            Voice.speak(app, r) { h.post { onState("idle") } }
        }.start()
    }
}
