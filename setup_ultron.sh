#!/usr/bin/env bash
# Run:  bash setup_ultron.sh   -> creates ./ultron-assistant (full Android project)
# Then: cd ultron-assistant && git init && git add . && git commit -m init
#       push to a GitHub repo -> Actions tab -> "Build APK" -> download artifact.
set -e
P=ultron-assistant
J=$P/app/src/main/java/com/ultron/assistant
R=$P/app/src/main/res
mkdir -p $J $R/values $R/xml $R/drawable $P/.github/workflows

cat > $P/.gitignore <<'EOF'
.gradle/
build/
local.properties
*.iml
.idea/
EOF

cat > $P/.github/workflows/build.yml <<'EOF'
name: Build APK
on:
  push:
    branches: [main, master]
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: android-actions/setup-android@v3
      - uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: 8.9
      - run: gradle assembleDebug --no-daemon
      - uses: actions/upload-artifact@v4
        with:
          name: Ultron-APK
          path: app/build/outputs/apk/debug/*.apk
EOF

cat > $P/settings.gradle.kts <<'EOF'
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "Ultron"
include(":app")
EOF

cat > $P/build.gradle.kts <<'EOF'
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}
EOF

cat > $P/gradle.properties <<'EOF'
org.gradle.jvmargs=-Xmx3g
android.useAndroidX=true
kotlin.code.style=official
EOF

cat > $P/app/build.gradle.kts <<'EOF'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}
android {
    namespace = "com.ultron.assistant"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.ultron.assistant"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.14" }
}
dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
}
EOF

cat > $P/app/src/main/AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.READ_PHONE_STATE"/>
    <uses-permission android:name="android.permission.READ_CALL_LOG"/>
    <uses-permission android:name="android.permission.READ_CONTACTS"/>
    <uses-permission android:name="android.permission.CALL_PHONE"/>
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES"/>

    <application
        android:label="Ultron"
        android:icon="@drawable/ic_ultron"
        android:theme="@style/Theme.Ultron"
        android:allowBackup="false">

        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <service android:name=".OverlayService" android:exported="false"
            android:foregroundServiceType="specialUse">
            <property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="floating assistant overlay"/>
        </service>

        <service android:name=".UltronAccess" android:exported="false"
            android:label="Ultron"
            android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
            <intent-filter>
                <action android:name="android.accessibilityservice.AccessibilityService"/>
            </intent-filter>
            <meta-data android:name="android.accessibilityservice"
                android:resource="@xml/accessibility"/>
        </service>

        <receiver android:name=".CallReceiver" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.PHONE_STATE"/>
            </intent-filter>
        </receiver>
    </application>
</manifest>
EOF

cat > $R/values/themes.xml <<'EOF'
<resources>
    <style name="Theme.Ultron" parent="android:Theme.Material.NoActionBar">
        <item name="android:windowBackground">@android:color/black</item>
        <item name="android:statusBarColor">@android:color/black</item>
        <item name="android:navigationBarColor">@android:color/black</item>
    </style>
</resources>
EOF

cat > $R/values/strings.xml <<'EOF'
<resources>
    <string name="app_name">Ultron</string>
    <string name="acc_desc">Lets Ultron tap, scroll, type and navigate other apps for you.</string>
</resources>
EOF

cat > $R/xml/accessibility.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeAllMask"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:canRetrieveWindowContent="true"
    android:notificationTimeout="100"
    android:description="@string/acc_desc"/>
EOF

cat > $R/drawable/ic_ultron.xml <<'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="48dp" android:height="48dp"
    android:viewportWidth="48" android:viewportHeight="48">
    <path android:fillColor="#FF14141A" android:strokeColor="#FFFF2030" android:strokeWidth="1"
        android:pathData="M24,3 C34,4 40,16 37,28 L30,44 L18,44 L11,28 C8,16 14,4 24,3 Z"/>
    <path android:fillColor="#FFFF2030" android:pathData="M13,19 L22,23 L20,26 L14,22 Z"/>
    <path android:fillColor="#FFFF2030" android:pathData="M35,19 L26,23 L28,26 L34,22 Z"/>
</vector>
EOF

# ---------------- Kotlin ----------------

cat > $J/Cfg.kt <<'EOF'
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
EOF

cat > $J/Brain.kt <<'EOF'
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
EOF

cat > $J/Voice.kt <<'EOF'
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

    fun speak(ctx: Context, text: String, done: () -> Unit = {}) {
        val app = ctx.applicationContext
        bg.execute {
            val fk = Cfg.get(app, "fish")
            if (fk.isNotBlank() && fish(app, text, fk)) { done(); return@execute }
            main.post { local(app, text, done) }
        }
    }

    fun stop() {
        try { player?.stop() } catch (_: Exception) {}
        try { tts?.stop() } catch (_: Exception) {}
    }

    // Fish Audio TTS using the Ultron voice model id
    private fun fish(app: Context, text: String, key: String): Boolean = try {
        val c = URL("https://api.fish.audio/v1/tts").openConnection() as HttpURLConnection
        c.requestMethod = "POST"
        c.setRequestProperty("Authorization", "Bearer $key")
        c.setRequestProperty("Content-Type", "application/json")
        c.doOutput = true
        val body = JSONObject().put("text", text)
            .put("reference_id", Cfg.get(app, "voice")).put("format", "mp3")
        c.outputStream.use { it.write(body.toString().toByteArray()) }
        if (c.responseCode >= 400) false else {
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
            true
        }
    } catch (e: Exception) { false }

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
            if (s == TextToSpeech.SUCCESS) { ready = true; go() } else done()
        }
    }
}
EOF

cat > $J/Ears.kt <<'EOF'
package com.ultron.assistant

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer

class Ears(private val ctx: Context, private val onText: (String) -> Unit) {
    private var sr: SpeechRecognizer? = null

    fun start() {
        if (!SpeechRecognizer.isRecognitionAvailable(ctx)) { onText(""); return }
        stop()
        val r = SpeechRecognizer.createSpeechRecognizer(ctx)
        sr = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(p: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(v: Float) {}
            override fun onBufferReceived(b: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onError(e: Int) { onText("") }
            override fun onResults(b: Bundle?) {
                onText(b?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: "")
            }
            override fun onPartialResults(b: Bundle?) {}
            override fun onEvent(t: Int, b: Bundle?) {}
        })
        r.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM))
    }

    fun stop() { try { sr?.destroy() } catch (_: Exception) {}; sr = null }
}
EOF

cat > $J/Agent.kt <<'EOF'
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
EOF

cat > $J/Actions.kt <<'EOF'
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
EOF

cat > $J/UltronAccess.kt <<'EOF'
package com.ultron.assistant

import android.accessibilityservice.AccessibilityService
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class UltronAccess : AccessibilityService() {
    companion object { var inst: UltronAccess? = null }

    override fun onServiceConnected() { inst = this }
    override fun onAccessibilityEvent(e: AccessibilityEvent?) {}
    override fun onInterrupt() {}
    override fun onDestroy() { inst = null; super.onDestroy() }

    fun clickText(t: String): Boolean {
        val root = rootInActiveWindow ?: return false
        for (n in root.findAccessibilityNodeInfosByText(t)) {
            var p: AccessibilityNodeInfo? = n
            while (p != null) {
                if (p.isClickable) return p.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                p = p.parent
            }
        }
        return false
    }

    fun scroll(forward: Boolean): Boolean {
        val s = findScrollable(rootInActiveWindow ?: return false) ?: return false
        return s.performAction(
            if (forward) AccessibilityNodeInfo.ACTION_SCROLL_FORWARD else AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
        )
    }

    fun typeText(t: String): Boolean {
        val f = rootInActiveWindow?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: return false
        val b = Bundle()
        b.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, t)
        return f.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, b)
    }

    private fun findScrollable(n: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (n.isScrollable) return n
        for (i in 0 until n.childCount) {
            val c = n.getChild(i) ?: continue
            findScrollable(c)?.let { return it }
        }
        return null
    }
}
EOF

cat > $J/CallReceiver.kt <<'EOF'
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
EOF

cat > $J/OverlayService.kt <<'EOF'
package com.ultron.assistant

import android.animation.ObjectAnimator
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
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

class OverlayService : Service() {
    private lateinit var wm: WindowManager
    private lateinit var root: LinearLayout
    private lateinit var icon: ImageView
    private lateinit var label: TextView
    private lateinit var lp: WindowManager.LayoutParams
    private lateinit var ears: Ears
    private var state = "idle"
    private var anim: ObjectAnimator? = null
    private val h = Handler(Looper.getMainLooper())

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

        icon = ImageView(this).apply {
            setImageResource(R.drawable.ic_ultron)
            setPadding(dp(8), dp(8), dp(8), dp(8))
            layoutParams = LinearLayout.LayoutParams(dp(52), dp(52))
        }
        label = TextView(this).apply {
            setTextColor(Color.parseColor("#FFB0B4C0")); textSize = 11f
            setBackgroundColor(Color.parseColor("#CC000000")); setPadding(dp(8), dp(3), dp(8), dp(3))
            visibility = View.GONE; maxWidth = dp(200)
        }
        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.END
            addView(icon); addView(label)
        }
        lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.END; x = dp(12); y = dp(120) }

        var sx = 0f; var sy = 0f; var ox = 0; var oy = 0; var moved = false
        icon.setOnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> { sx = e.rawX; sy = e.rawY; ox = lp.x; oy = lp.y; moved = false }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (e.rawX - sx).toInt(); val dy = (e.rawY - sy).toInt()
                    if (abs(dx) > 10 || abs(dy) > 10) moved = true
                    if (moved) { lp.x = ox - dx; lp.y = oy + dy; wm.updateViewLayout(root, lp) }
                }
                MotionEvent.ACTION_UP -> if (!moved) tap()
            }
            true
        }
        wm.addView(root, lp)
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
        val red = Color.parseColor("#FFFF2030")
        val bg = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.parseColor("#E6000000"))
            setStroke(dp(if (s == "idle") 1 else 2), if (s == "idle") Color.parseColor("#66FF2030") else red)
        }
        icon.background = bg
        when (s) {
            "idle" -> { icon.alpha = 0.75f; label.visibility = View.GONE }
            "listening" -> { label.text = "Listening…"; label.visibility = View.VISIBLE; pulse() }
            "processing" -> { label.text = "…"; label.visibility = View.VISIBLE; pulse() }
            "responding" -> {
                label.text = (text ?: "").take(90); label.visibility = View.VISIBLE
            }
        }
    }

    private fun pulse() {
        anim = ObjectAnimator.ofFloat(icon, "alpha", 0.45f, 1f).apply {
            duration = 700; repeatCount = ObjectAnimator.INFINITE; repeatMode = ObjectAnimator.REVERSE; start()
        }
    }

    override fun onStartCommand(i: Intent?, f: Int, id: Int) = START_STICKY

    override fun onDestroy() {
        ears.stop(); anim?.cancel()
        try { wm.removeView(root) } catch (_: Exception) {}
        super.onDestroy()
    }
}
EOF

cat > $J/MainActivity.kt <<'EOF'
package com.ultron.assistant

import android.Manifest
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

val Red = Color(0xFFFF2030)
val Dim = Color(0xFF9AA0B0)

class MainActivity : ComponentActivity() {
    override fun onCreate(b: Bundle?) {
        super.onCreate(b)
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {}.launch(
            arrayOf(
                Manifest.permission.RECORD_AUDIO, Manifest.permission.READ_PHONE_STATE,
                Manifest.permission.READ_CALL_LOG, Manifest.permission.READ_CONTACTS,
                Manifest.permission.CALL_PHONE, Manifest.permission.POST_NOTIFICATIONS
            )
        )
        setContent {
            MaterialTheme(colorScheme = darkColorScheme(primary = Red, background = Color.Black, surface = Color(0xFF111114))) {
                UltronApp()
            }
        }
    }
}

@Composable
fun UltronApp() {
    val ctx = LocalContext.current
    var status by remember { mutableStateOf("idle") }
    var line by remember { mutableStateOf("HOW CAN I HELP YOU?") }
    var typing by remember { mutableStateOf(false) }
    var input by remember { mutableStateOf("") }
    var settings by remember { mutableStateOf(false) }

    fun run(t: String) {
        status = "processing"; line = "PROCESSING…"
        Agent.run(ctx, t, { s ->
            status = s
            if (s == "idle") line = "HOW CAN I HELP YOU?"
        }, { r -> line = r })
    }
    val ears = remember {
        Ears(ctx) { t ->
            if (t.isBlank()) { status = "idle"; line = "I DIDN'T CATCH THAT" }
            else { line = t; run(t) }
        }
    }
    DisposableEffect(Unit) { onDispose { ears.stop() } }

    val inf = rememberInfiniteTransition(label = "p")
    val pulse by inf.animateFloat(0.5f, 1f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "pulse")
    val rot by inf.animateFloat(0f, 360f, infiniteRepeatable(tween(7000, easing = LinearEasing)), label = "rot")
    val glow = if (status == "idle") 0.6f else pulse

    Box(
        Modifier.fillMaxSize().background(
            Brush.radialGradient(listOf(Color(0xFF2A0509), Color.Black), radius = 1100f)
        ).statusBarsPadding().navigationBarsPadding()
    ) {
        Row(Modifier.fillMaxWidth().padding(24.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(8.dp).clip(CircleShape).background(Red))
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text("U.L.T.R.O.N.", color = Color(0xFFE6E8F0), fontSize = 20.sp, letterSpacing = 6.sp)
                Text("AI ASSISTANT", color = Dim, fontSize = 11.sp, letterSpacing = 3.sp)
            }
            Text("⚙", color = Dim, fontSize = 26.sp, modifier = Modifier.clickable { settings = true })
        }

        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
            Spacer(Modifier.height(110.dp))
            Box(Modifier.size(300.dp), contentAlignment = Alignment.Center) {
                Canvas(Modifier.fillMaxSize()) {
                    val r = size.minDimension / 2
                    drawCircle(Red.copy(alpha = 0.22f), r * 0.95f, style = Stroke(2f))
                    drawCircle(Red.copy(alpha = 0.15f), r * 0.80f, style = Stroke(2f))
                    drawArc(
                        Red.copy(alpha = 0.9f * glow), rot, 70f, false,
                        Offset(center.x - r * 0.95f, center.y - r * 0.95f), Size(r * 1.9f, r * 1.9f), style = Stroke(5f)
                    )
                    drawArc(
                        Red.copy(alpha = 0.6f * glow), -rot, 40f, false,
                        Offset(center.x - r * 0.80f, center.y - r * 0.80f), Size(r * 1.6f, r * 1.6f), style = Stroke(4f)
                    )
                }
                UltronFace(Modifier.size(190.dp), glow)
            }
            Spacer(Modifier.height(28.dp))
            Text(
                line.uppercase(), color = Dim, fontSize = 14.sp, letterSpacing = 3.sp,
                textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 32.dp).heightIn(min = 60.dp)
            )
            Box(Modifier.width(36.dp).height(2.dp).background(Red))

            Spacer(Modifier.weight(1f))

            if (typing) {
                Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(
                        input, { input = it }, Modifier.weight(1f), singleLine = true,
                        placeholder = { Text("Type a command…") },
                        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Red, unfocusedBorderColor = Red.copy(alpha = 0.4f))
                    )
                    TextButton({ if (input.isNotBlank()) { run(input); input = ""; typing = false } }) { Text("SEND", color = Red) }
                }
                Spacer(Modifier.height(12.dp))
            }

            Row(
                Modifier.fillMaxWidth().padding(horizontal = 36.dp, vertical = 24.dp),
                horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically
            ) {
                Text("VOICE", color = Dim, fontSize = 11.sp, letterSpacing = 2.sp)
                Box(
                    Modifier.size(100.dp).clip(CircleShape)
                        .background(Red.copy(alpha = 0.10f * glow))
                        .border(2.dp, Red.copy(alpha = glow), CircleShape)
                        .clickable {
                            if (status == "listening") { ears.stop(); status = "idle"; line = "HOW CAN I HELP YOU?" }
                            else { Voice.stop(); status = "listening"; line = "LISTENING…"; ears.start() }
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Canvas(Modifier.size(30.dp)) {
                        val w = size.width; val h = size.height; val c = Color(0xFFE0E0E8)
                        drawRoundRect(c, Offset(w * .35f, 0f), Size(w * .3f, h * .6f), CornerRadius(w * .15f))
                        drawArc(c, 0f, 180f, false, Offset(w * .2f, h * .2f), Size(w * .6f, h * .55f), style = Stroke(4f))
                        drawLine(c, Offset(w * .5f, h * .75f), Offset(w * .5f, h * .95f), 4f)
                    }
                }
                Text("TYPE", color = Dim, fontSize = 11.sp, letterSpacing = 2.sp,
                    modifier = Modifier.clickable { typing = !typing })
            }
        }
    }

    if (settings) SettingsDialog(ctx) { settings = false }
}

@Composable
fun UltronFace(mod: Modifier, glow: Float) {
    Canvas(mod) {
        val w = size.width; val h = size.height
        val head = Path().apply {
            moveTo(w * .5f, h * .02f)
            cubicTo(w * .8f, h * .05f, w * .92f, h * .35f, w * .85f, h * .6f)
            lineTo(w * .62f, h * .95f); lineTo(w * .38f, h * .95f); lineTo(w * .15f, h * .6f)
            cubicTo(w * .08f, h * .35f, w * .2f, h * .05f, w * .5f, h * .02f)
            close()
        }
        drawPath(head, Brush.verticalGradient(listOf(Color(0xFF3C3C42), Color(0xFF0C0C0E))))
        drawPath(head, Red.copy(alpha = 0.5f), style = Stroke(w * .012f))
        drawLine(Red.copy(alpha = 0.4f), Offset(w * .5f, h * .05f), Offset(w * .5f, h * .38f), w * .01f)
        drawLine(Red.copy(alpha = 0.3f), Offset(w * .5f, h * .62f), Offset(w * .5f, h * .93f), w * .008f)
        for (l in listOf(true, false)) {
            fun x(v: Float) = w * (if (l) v else 1f - v)
            val e = Path().apply {
                moveTo(x(.24f), h * .40f); lineTo(x(.46f), h * .49f)
                lineTo(x(.41f), h * .55f); lineTo(x(.27f), h * .47f); close()
            }
            drawPath(e, Red.copy(alpha = 0.35f * glow), style = Stroke(w * .035f))
            drawPath(e, Color(0xFFFF4050))
        }
    }
}

@Composable
fun SettingsDialog(ctx: Context, onClose: () -> Unit) {
    var gem by remember { mutableStateOf(Cfg.get(ctx, "gemini")) }
    var fish by remember { mutableStateOf(Cfg.get(ctx, "fish")) }
    var voice by remember { mutableStateOf(Cfg.get(ctx, "voice")) }
    var model by remember { mutableStateOf(Cfg.get(ctx, "model")) }
    fun open(i: Intent) = ctx.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    AlertDialog(
        onDismissRequest = onClose,
        containerColor = Color(0xFF111114),
        title = { Text("ULTRON SETTINGS", color = Red, letterSpacing = 3.sp, fontSize = 16.sp) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                @Composable
                fun f(v: String, ch: (String) -> Unit, lbl: String) =
                    OutlinedTextField(v, ch, Modifier.fillMaxWidth().padding(vertical = 4.dp), singleLine = true, label = { Text(lbl) })
                f(gem, { gem = it }, "Gemini API key (brain)")
                f(model, { model = it }, "Model (blank = gemini-2.5-flash)")
                f(fish, { fish = it }, "Fish Audio API key (voice)")
                f(voice, { voice = it }, "Voice model id")
                Spacer(Modifier.height(8.dp))
                TextButton({ open(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + ctx.packageName))) }) { Text("1. Allow overlay", color = Red) }
                TextButton({ open(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }) { Text("2. Enable accessibility (control apps)", color = Red) }
                TextButton({
                    if (Settings.canDrawOverlays(ctx)) ctx.startForegroundService(Intent(ctx, OverlayService::class.java))
                    else open(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + ctx.packageName)))
                }) { Text("3. Start overlay", color = Red) }
                TextButton({ ctx.stopService(Intent(ctx, OverlayService::class.java)) }) { Text("Stop overlay", color = Dim) }
            }
        },
        confirmButton = {
            TextButton({
                Cfg.set(ctx, "gemini", gem.trim()); Cfg.set(ctx, "fish", fish.trim())
                Cfg.set(ctx, "voice", voice.trim()); Cfg.set(ctx, "model", model.trim()); onClose()
            }) { Text("SAVE", color = Red) }
        }
    )
}
EOF

cat > $P/README.md <<'EOF'
# Ultron Assistant
Push to GitHub -> Actions -> "Build APK" -> download the `Ultron-APK` artifact.
Keys are entered inside the app (Settings), never stored in the repo.
EOF

echo "Done. Project created in ./$P"
