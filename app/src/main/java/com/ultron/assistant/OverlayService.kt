package com.ultron.assistant

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

class OverlayService : Service() {
    private lateinit var wm: WindowManager
    private lateinit var root: LinearLayout
    private lateinit var icon: ImageView
    private lateinit var ring: View
    private lateinit var label: TextView
    private lateinit var lp: WindowManager.LayoutParams
    private lateinit var ears: Ears
    private var state = "idle"
    private var anim: ObjectAnimator? = null
    private var ringAnim: ValueAnimator? = null

    override fun onBind(i: Intent?) = null
    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    override fun onCreate() {
        super.onCreate()
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel("ultron", "Ultron", NotificationManager.IMPORTANCE_MIN))
        val n = Notification.Builder(this, "ultron").setSmallIcon(R.drawable.ic_ultron)
            .setContentTitle("Ultron is online").build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(1, n)

        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        ears = Ears(this) { text -> onHeard(text) }

        ring = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(dp(52), dp(52), Gravity.CENTER)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL; setColor(Color.TRANSPARENT)
                setStroke(dp(2), Color.parseColor("#FFFF2030"))
            }
            alpha = 0f
        }
        icon = ImageView(this).apply {
            setImageResource(R.drawable.ic_ultron)
            setPadding(dp(8), dp(8), dp(8), dp(8))
            layoutParams = FrameLayout.LayoutParams(dp(52), dp(52), Gravity.CENTER)
        }
        val frame = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(86), dp(86))
            addView(ring); addView(icon)
        }
        label = TextView(this).apply {
            setTextColor(Color.parseColor("#FFD0D4E0")); textSize = 11f
            background = GradientDrawable().apply {
                cornerRadius = dp(12).toFloat()
                setColor(Color.parseColor("#D9101014"))
                setStroke(dp(1), Color.parseColor("#66FF2030"))
            }
            setPadding(dp(10), dp(5), dp(10), dp(5))
            visibility = View.GONE; maxWidth = dp(220)
        }
        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.END
            addView(frame); addView(label)
        }
        lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.END; x = dp(6); y = dp(110) }

        var sx = 0f; var sy = 0f; var ox = 0; var oy = 0; var moved = false
        icon.setOnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    sx = e.rawX; sy = e.rawY; ox = lp.x; oy = lp.y; moved = false
                    icon.animate().scaleX(0.88f).scaleY(0.88f).setDuration(90).start()
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (e.rawX - sx).toInt(); val dy = (e.rawY - sy).toInt()
                    if (abs(dx) > 10 || abs(dy) > 10) moved = true
                    if (moved) { lp.x = ox - dx; lp.y = oy + dy; wm.updateViewLayout(root, lp) }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    icon.animate().scaleX(1f).scaleY(1f).setDuration(260)
                        .setInterpolator(OvershootInterpolator(3f)).start()
                    if (e.action == MotionEvent.ACTION_UP && !moved) tap()
                }
            }
            true
        }
        wm.addView(root, lp)
        // pop-in
        root.scaleX = 0f; root.scaleY = 0f
        root.animate().scaleX(1f).scaleY(1f).setDuration(520).setInterpolator(OvershootInterpolator(2.2f)).start()
        setState("idle")
    }

    private fun tap() {
        when (state) {
            "idle" -> { setState("listening"); ears.start() }
            else -> { ears.stop(); Voice.stop(); setState("idle") }   // quick exit
        }
    }

    private fun onHeard(text: String) {
        val t = text.trim().lowercase()
        if (t.isBlank() || t == "stop" || t == "cancel") { Voice.stop(); setState("idle"); return }
        Agent.run(this, text, { setState(it) }, { setState("responding", it) })
    }

    private fun setState(s: String, text: String? = null) {
        state = s
        anim?.cancel(); icon.alpha = 1f
        ringAnim?.cancel(); ring.alpha = 0f
        val red = Color.parseColor("#FFFF2030")
        icon.background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.parseColor("#E6000000"))
            setStroke(dp(if (s == "idle") 1 else 2), if (s == "idle") Color.parseColor("#66FF2030") else red)
        }
        when (s) {
            "idle" -> {
                icon.alpha = 0.75f
                label.animate().alpha(0f).setDuration(250).withEndAction { label.visibility = View.GONE }.start()
            }
            "listening" -> { showLabel("Listening…"); pulse(); ripple() }
            "processing" -> { showLabel("Thinking…"); pulse() }
            "responding" -> showLabel((text ?: "").take(90))
        }
    }

    private fun showLabel(t: String) {
        label.animate().cancel()
        label.text = t
        if (label.visibility != View.VISIBLE) { label.alpha = 0f; label.visibility = View.VISIBLE }
        label.animate().alpha(1f).setDuration(220).start()
    }

    private fun pulse() {
        anim = ObjectAnimator.ofFloat(icon, "alpha", 0.45f, 1f).apply {
            duration = 700; repeatCount = ObjectAnimator.INFINITE; repeatMode = ObjectAnimator.REVERSE; start()
        }
    }

    private fun ripple() {
        ringAnim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 1100; repeatCount = ValueAnimator.INFINITE
            addUpdateListener {
                val f = it.animatedValue as Float
                ring.scaleX = 1f + 0.6f * f; ring.scaleY = 1f + 0.6f * f; ring.alpha = 0.7f * (1f - f)
            }
            start()
        }
    }

    override fun onStartCommand(i: Intent?, f: Int, id: Int) = START_STICKY

    override fun onDestroy() {
        ears.stop(); anim?.cancel(); ringAnim?.cancel()
        try { wm.removeView(root) } catch (_: Exception) {}
        super.onDestroy()
    }
}
