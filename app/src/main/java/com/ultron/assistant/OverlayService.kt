package com.ultron.assistant

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.LinearInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin

class WaveView(ctx: Context) : View(ctx) {
    private val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#FFFF2030"); strokeCap = Paint.Cap.ROUND
    }
    private var phase = 0f
    private var va: ValueAnimator? = null

    fun run(on: Boolean) {
        va?.cancel()
        if (on) {
            va = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 900; repeatCount = ValueAnimator.INFINITE; interpolator = LinearInterpolator()
                addUpdateListener { phase = it.animatedValue as Float; invalidate() }
                start()
            }
        }
    }

    override fun onDraw(c: Canvas) {
        val n = 9; val w = width.toFloat(); val h = height.toFloat()
        val gap = w / n
        p.strokeWidth = gap * 0.35f
        for (i in 0 until n) {
            val mid = (n - 1) / 2f
            val edge = 1f - abs(i - mid) / mid * 0.7f
            val v = abs(sin((phase * 2.0 * PI + i * 0.9).toFloat()))
            val hh = h * (0.12f + 0.88f * v * edge)
            val x = gap * (i + 0.5f)
            c.drawLine(x, h / 2 - hh / 2, x, h / 2 + hh / 2, p)
        }
    }
}

class OverlayService : Service() {
    private lateinit var wm: WindowManager
    private lateinit var root: LinearLayout
    private lateinit var icon: ImageView
    private lateinit var ring: View
    private lateinit var spin: View
    private lateinit var wave: WaveView
    private lateinit var label: TextView
    private lateinit var lp: WindowManager.LayoutParams
    private lateinit var ears: Ears
    private var state = "idle"
    private var anim: ObjectAnimator? = null
    private var spinAnim: ObjectAnimator? = null
    private var ringAnim: ValueAnimator? = null
    private val h = Handler(Looper.getMainLooper())
    private val hideLabel = Runnable {
        label.animate().alpha(0f).setDuration(300).withEndAction { label.visibility = View.GONE }.start()
    }

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
        val red = Color.parseColor("#FFFF2030")

        spin = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(dp(70), dp(70), Gravity.CENTER)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL; setColor(Color.TRANSPARENT)
                setStroke(dp(2), red, dp(10).toFloat(), dp(8).toFloat())
            }
            alpha = 0f
        }
        ring = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(dp(56), dp(56), Gravity.CENTER)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL; setColor(Color.TRANSPARENT); setStroke(dp(2), red)
            }
            alpha = 0f
        }
        icon = ImageView(this).apply {
            setImageResource(R.drawable.ic_overlay)
            scaleType = ImageView.ScaleType.FIT_CENTER
            layoutParams = FrameLayout.LayoutParams(dp(56), dp(56), Gravity.CENTER)
        }
        val frame = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(92), dp(92))
            addView(spin); addView(ring); addView(icon)
        }
        wave = WaveView(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(56), dp(24)).apply { gravity = Gravity.END; rightMargin = dp(18) }
            visibility = View.GONE
        }
        label = TextView(this).apply {
            setTextColor(Color.parseColor("#FFD0D4E0")); textSize = 11f
            background = GradientDrawable().apply {
                cornerRadius = dp(12).toFloat()
                setColor(Color.parseColor("#E6101014"))
                setStroke(dp(1), Color.parseColor("#66FF2030"))
            }
            setPadding(dp(10), dp(5), dp(10), dp(5))
            visibility = View.GONE; maxWidth = dp(220)
        }
        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.END
            addView(frame); addView(wave); addView(label)
        }
        lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.END; x = dp(4); y = dp(110) }

        var sx = 0f; var sy = 0f; var ox = 0; var oy = 0; var moved = false
        val longPress = Runnable { closeOverlay() }
        icon.setOnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    sx = e.rawX; sy = e.rawY; ox = lp.x; oy = lp.y; moved = false
                    h.postDelayed(longPress, 900)
                    icon.animate().scaleX(0.88f).scaleY(0.88f).setDuration(90).start()
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (e.rawX - sx).toInt(); val dy = (e.rawY - sy).toInt()
                    if (abs(dx) > 10 || abs(dy) > 10) { moved = true; h.removeCallbacks(longPress) }
                    if (moved) { lp.x = ox - dx; lp.y = oy + dy; wm.updateViewLayout(root, lp) }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    h.removeCallbacks(longPress)
                    icon.animate().scaleX(1f).scaleY(1f).setDuration(260)
                        .setInterpolator(OvershootInterpolator(3f)).start()
                    if (e.action == MotionEvent.ACTION_UP && !moved) tap()
                }
            }
            true
        }
        wm.addView(root, lp)
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

    private fun closeOverlay() {
        ears.stop(); Voice.stop()
        root.animate().alpha(0f).scaleX(0.6f).scaleY(0.6f).setDuration(350).withEndAction { stopSelf() }.start()
    }

    private fun onHeard(text: String) {
        val t = text.trim().lowercase()
        if (t.isBlank() || t == "stop" || t == "cancel") { Voice.stop(); setState("idle"); return }
        Agent.run(this, text, { setState(it) }, { setState("responding", it) })
    }

    private fun setState(s: String, text: String? = null) {
        state = s
        anim?.cancel(); spinAnim?.cancel(); ringAnim?.cancel(); wave.run(false)
        h.removeCallbacks(hideLabel)
        ring.alpha = 0f; spin.alpha = 0f; icon.alpha = 1f; spin.rotation = 0f
        when (s) {
            "idle" -> {
                icon.alpha = 0.85f; wave.visibility = View.GONE
                if (label.visibility == View.VISIBLE) h.postDelayed(hideLabel, 2200)
            }
            "listening" -> {
                showLabel("Listening…"); wave.visibility = View.VISIBLE; wave.run(true); ripple()
            }
            "processing" -> {
                showLabel("Thinking…"); wave.visibility = View.GONE; spin.alpha = 1f
                spinAnim = ObjectAnimator.ofFloat(spin, "rotation", 0f, 360f).apply {
                    duration = 1400; repeatCount = ObjectAnimator.INFINITE; interpolator = LinearInterpolator(); start()
                }
            }
            "responding" -> {
                showLabel((text ?: "").take(90)); wave.visibility = View.GONE; ring.alpha = 0.55f
            }
        }
    }

    private fun showLabel(t: String) {
        label.animate().cancel()
        label.text = t
        if (label.visibility != View.VISIBLE) { label.alpha = 0f; label.visibility = View.VISIBLE }
        label.animate().alpha(1f).setDuration(220).start()
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
        h.removeCallbacksAndMessages(null)
        ears.stop(); anim?.cancel(); spinAnim?.cancel(); ringAnim?.cancel(); wave.run(false)
        try { wm.removeView(root) } catch (_: Exception) {}
        super.onDestroy()
    }
}
