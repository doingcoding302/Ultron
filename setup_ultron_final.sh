#!/usr/bin/env bash
# FINAL BUILD (animated UI, overlay, call announcer, boot start)
# Run:  bash setup_ultron_final.sh   -> creates ./ultron-assistant (full Android project)
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
        versionCode = 2
        versionName = "1.1"
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
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

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

        <receiver android:name=".BootReceiver" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
            </intent-filter>
        </receiver>

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
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

val Red = Color(0xFFFF2030)
val Dim = Color(0xFF9AA0B0)
val TAU = 6.2831855f

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

    fun run(txt: String) {
        status = "processing"; line = "PROCESSING…"
        Agent.run(ctx, txt, { s ->
            status = s
            if (s == "idle") line = "HOW CAN I HELP YOU?"
        }, { r -> line = r })
    }
    val ears = remember {
        Ears(ctx) { txt ->
            if (txt.isBlank()) { status = "idle"; line = "I DIDN'T CATCH THAT" }
            else { line = txt; run(txt) }
        }
    }
    DisposableEffect(Unit) { onDispose { ears.stop() } }

    fun mic() {
        if (status == "listening") { ears.stop(); status = "idle"; line = "HOW CAN I HELP YOU?" }
        else { Voice.stop(); status = "listening"; line = "LISTENING…"; ears.start() }
    }

    // ---- animation drivers ----
    val inf = rememberInfiniteTransition(label = "t")
    val t by inf.animateFloat(0f, 1f, infiniteRepeatable(tween(12000, easing = LinearEasing)), label = "t")
    val intro = remember { Animatable(0f) }
    LaunchedEffect(Unit) { intro.animateTo(1f, tween(1800, easing = FastOutSlowInEasing)) }
    val energy by animateFloatAsState(
        when (status) { "listening" -> 1f; "processing" -> 0.9f; "responding" -> 0.75f; else -> 0.35f },
        tween(600), label = "energy"
    )
    var shown by remember { mutableStateOf("") }
    LaunchedEffect(line) {
        shown = ""
        for (c in line.uppercase()) { shown += c; delay(if (line.length > 80) 6L else 20L) }
    }
    val statusWord = when (status) { "listening" -> "LISTENING"; "processing" -> "THINKING"; "responding" -> "SPEAKING"; else -> "STANDBY" }

    Box(Modifier.fillMaxSize().background(Color.Black).statusBarsPadding().navigationBarsPadding()) {

        // drifting glow + rising ember particles
        Canvas(Modifier.fillMaxSize()) {
            val gx = size.width * (0.5f + 0.18f * sin(t * TAU))
            val gy = size.height * (0.38f + 0.05f * cos(t * TAU))
            drawRect(Brush.radialGradient(
                listOf(Red.copy(alpha = 0.14f + 0.10f * energy), Color.Transparent),
                center = Offset(gx, gy), radius = size.width * 1.1f))
            for (i in 0 until 30) {
                val seed = (i * 0.618f) % 1f
                val x = size.width * ((i * 0.37f + 0.11f) % 1f)
                val y = size.height * (1f - ((seed + t * (1 + i % 3)) % 1f))
                val tw = 0.5f + 0.5f * sin(t * TAU * (2 + i % 4) + i)
                drawCircle(Red.copy(alpha = (0.08f + 0.30f * tw).coerceIn(0f, 1f)), 1.5f + (i % 3), Offset(x, y))
            }
        }

        // header
        Row(Modifier.fillMaxWidth().padding(24.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(8.dp).graphicsLayer { alpha = 0.55f + 0.45f * sin(t * TAU * 6) }
                .clip(CircleShape).background(Red))
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text("U.L.T.R.O.N.", color = Color(0xFFE6E8F0), fontSize = 20.sp, letterSpacing = 6.sp)
                Text("AI ASSISTANT · $statusWord", color = Dim, fontSize = 11.sp, letterSpacing = 3.sp)
            }
            Text("⚙", color = Dim, fontSize = 26.sp, modifier = Modifier.clickable { settings = true })
        }

        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
            Spacer(Modifier.height(80.dp))

            // reactor rings + face
            Box(Modifier.size(310.dp), contentAlignment = Alignment.Center) {
                Canvas(Modifier.fillMaxSize()) {
                    val r = size.minDimension / 2; val c = center; val a = intro.value
                    val rot = t * 360f
                    fun arc(f: Float, start: Float, sweep: Float, col: Color, w: Float) =
                        drawArc(col, start, sweep, false, Offset(c.x - r * f, c.y - r * f),
                            Size(2 * r * f, 2 * r * f), style = Stroke(w, cap = StrokeCap.Round))
                    drawCircle(Red.copy(alpha = 0.20f * a), r * 0.97f, style = Stroke(2f))
                    drawCircle(Red.copy(alpha = 0.12f * a), r * 0.78f, style = Stroke(2f))
                    for (i in 0 until 72) {
                        val ang = (i * 5f + rot * 0.5f) * (PI.toFloat() / 180f)
                        val long = i % 6 == 0
                        val r1 = r * (if (long) 0.90f else 0.93f); val r2 = r * 0.95f
                        drawLine(Red.copy(alpha = (if (long) 0.55f else 0.20f) * a),
                            Offset(c.x + cos(ang) * r1, c.y + sin(ang) * r1),
                            Offset(c.x + cos(ang) * r2, c.y + sin(ang) * r2), 2f)
                    }
                    arc(0.97f, rot, 70f, Red.copy(alpha = (0.5f + 0.5f * energy) * a), 5f)
                    arc(0.78f, -rot * 2, 40f, Red.copy(alpha = 0.6f * a), 4f)
                    arc(0.86f, rot * 3, 28f, Red.copy(alpha = ((energy - 0.35f).coerceAtLeast(0f) * 1.4f) * a), 4f)
                }
                UltronFace(
                    Modifier.size(190.dp).graphicsLayer {
                        val s = (0.8f + 0.2f * intro.value) * (1f + 0.012f * sin(t * TAU * 3))
                        scaleX = s; scaleY = s; alpha = intro.value
                    },
                    glow = { 0.40f + 0.60f * energy * (0.8f + 0.2f * sin(t * TAU * 6)) },
                    boot = { ((intro.value - 0.5f) * 2f).coerceIn(0f, 1f) },
                    scan = { if (status == "processing" || status == "listening") (t * 4f) % 1f else -1f }
                )
            }

            // live waveform
            Canvas(Modifier.width(150.dp).height(36.dp)) {
                val n = 17; val bw = size.width / (n * 2f)
                val act = when (status) { "listening" -> 1f; "responding" -> 0.7f; "processing" -> 0.35f; else -> 0.08f }
                for (i in 0 until n) {
                    val v = abs(sin(t * TAU * (3 + i % 3) + i * 0.8f))
                    val hh = size.height * (0.08f + 0.92f * v * act)
                    drawRoundRect(Red.copy(alpha = 0.35f + 0.55f * act), Offset(bw * (2 * i) + bw / 2, (size.height - hh) / 2),
                        Size(bw, hh), CornerRadius(bw / 2))
                }
            }
            Spacer(Modifier.height(14.dp))

            // glass reply card with typewriter text
            Box(
                Modifier.padding(horizontal = 24.dp).fillMaxWidth().heightIn(min = 64.dp).animateContentSize()
                    .clip(RoundedCornerShape(22.dp))
                    .background(Brush.linearGradient(listOf(Color.White.copy(alpha = 0.09f), Color.White.copy(alpha = 0.02f))))
                    .border(1.dp, Brush.linearGradient(listOf(Red.copy(alpha = 0.6f), Color.Transparent, Red.copy(alpha = 0.3f))), RoundedCornerShape(22.dp))
                    .padding(18.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    shown + if (shown.length < line.length) "▌" else "",
                    color = Color(0xFFD0D4E0), fontSize = 14.sp, letterSpacing = 2.sp, textAlign = TextAlign.Center
                )
            }

            Spacer(Modifier.weight(1f))

            AnimatedVisibility(
                typing,
                enter = fadeIn() + slideInVertically { it / 2 },
                exit = fadeOut() + slideOutVertically { it / 2 }
            ) {
                Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(
                        input, { input = it }, Modifier.weight(1f), singleLine = true,
                        placeholder = { Text("Type a command…") },
                        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Red, unfocusedBorderColor = Red.copy(alpha = 0.4f))
                    )
                    TextButton({ if (input.isNotBlank()) { run(input); input = ""; typing = false } }) { Text("SEND", color = Red) }
                }
            }

            // bottom controls
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 28.dp, vertical = 24.dp),
                horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically
            ) {
                GlassChip("VOICE") { mic() }

                val src = remember { MutableInteractionSource() }
                val pressed by src.collectIsPressedAsState()
                val press by animateFloatAsState(if (pressed) 0.90f else 1f, spring(dampingRatio = 0.45f), label = "press")
                Box(Modifier.size(100.dp), contentAlignment = Alignment.Center) {
                    Canvas(Modifier.requiredSize(260.dp)) {
                        if (status == "listening") for (k in 0..1) {
                            val f = ((t * 6f) + k * 0.5f) % 1f
                            drawCircle(Red.copy(alpha = 0.45f * (1f - f)), 50.dp.toPx() + 65.dp.toPx() * f, style = Stroke(3f))
                        }
                    }
                    Box(
                        Modifier.size(100.dp).graphicsLayer { scaleX = press; scaleY = press }
                            .clip(CircleShape).background(Red.copy(alpha = 0.10f))
                            .drawBehind {
                                val g = 0.45f + 0.55f * energy * (0.8f + 0.2f * sin(t * TAU * 6))
                                drawCircle(Red.copy(alpha = 0.25f * g), size.minDimension / 2 + 6f, style = Stroke(10f))
                                drawCircle(Red.copy(alpha = g), size.minDimension / 2 - 2f, style = Stroke(4f))
                            }
                            .clickable(interactionSource = src, indication = null) { mic() },
                        contentAlignment = Alignment.Center
                    ) {
                        Canvas(Modifier.size(30.dp)) {
                            val w = size.width; val h = size.height; val c = Color(0xFFE0E0E8)
                            drawRoundRect(c, Offset(w * .35f, 0f), Size(w * .3f, h * .6f), CornerRadius(w * .15f))
                            drawArc(c, 0f, 180f, false, Offset(w * .2f, h * .2f), Size(w * .6f, h * .55f), style = Stroke(4f))
                            drawLine(c, Offset(w * .5f, h * .75f), Offset(w * .5f, h * .95f), 4f)
                        }
                    }
                }

                GlassChip("TYPE") { typing = !typing }
            }
        }
    }

    if (settings) SettingsDialog(ctx) { settings = false }
}

@Composable
fun GlassChip(label: String, onClick: () -> Unit) {
    Text(
        label, color = Dim, fontSize = 11.sp, letterSpacing = 2.sp,
        modifier = Modifier.clip(RoundedCornerShape(50))
            .background(Color.White.copy(alpha = 0.06f))
            .border(1.dp, Red.copy(alpha = 0.25f), RoundedCornerShape(50))
            .clickable { onClick() }.padding(horizontal = 16.dp, vertical = 9.dp)
    )
}

@Composable
fun UltronFace(mod: Modifier, glow: () -> Float, boot: () -> Float, scan: () -> Float) {
    Canvas(mod) {
        val w = size.width; val h = size.height
        val g = glow(); val b = boot(); val sc = scan()
        val head = Path().apply {
            moveTo(w * .5f, h * .02f)
            cubicTo(w * .8f, h * .05f, w * .92f, h * .35f, w * .85f, h * .6f)
            lineTo(w * .62f, h * .95f); lineTo(w * .38f, h * .95f); lineTo(w * .15f, h * .6f)
            cubicTo(w * .08f, h * .35f, w * .2f, h * .05f, w * .5f, h * .02f)
            close()
        }
        drawPath(head, Brush.verticalGradient(listOf(Color(0xFF3C3C42), Color(0xFF0C0C0E))))
        drawPath(head, Brush.linearGradient(listOf(Color.White.copy(alpha = 0.10f), Color.Transparent),
            start = Offset(0f, 0f), end = Offset(w, h)))
        drawPath(head, Red.copy(alpha = 0.30f + 0.40f * g * b), style = Stroke(w * .012f))
        drawLine(Red.copy(alpha = 0.4f * b), Offset(w * .5f, h * .05f), Offset(w * .5f, h * .38f), w * .01f)
        drawLine(Red.copy(alpha = 0.3f * b), Offset(w * .5f, h * .62f), Offset(w * .5f, h * .93f), w * .008f)
        val fl = if (b < 1f && (b * 20).toInt() % 2 == 1) 0.3f else 1f   // boot flicker
        for (l in listOf(true, false)) {
            fun x(v: Float) = w * (if (l) v else 1f - v)
            val e = Path().apply {
                moveTo(x(.24f), h * .40f); lineTo(x(.46f), h * .49f)
                lineTo(x(.41f), h * .55f); lineTo(x(.27f), h * .47f); close()
            }
            drawPath(e, Red.copy(alpha = (0.45f * g * b * fl).coerceIn(0f, 1f)), style = Stroke(w * .05f))
            drawPath(e, Red.copy(alpha = (0.30f * g * b * fl).coerceIn(0f, 1f)), style = Stroke(w * .025f))
            drawPath(e, Color(0xFFFF5060).copy(alpha = ((0.35f + 0.65f * g) * b * fl).coerceIn(0f, 1f)))
        }
        if (sc >= 0f) clipPath(head) {
            val y = h * (0.1f + 0.8f * sc); val band = h * 0.06f
            drawRect(
                Brush.verticalGradient(listOf(Color.Transparent, Red.copy(alpha = 0.55f), Color.Transparent),
                    startY = y - band, endY = y + band),
                Offset(0f, y - band), Size(w, band * 2)
            )
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

cat > $J/BootReceiver.kt <<'EOF'
package com.ultron.assistant

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        if (i.action == Intent.ACTION_BOOT_COMPLETED && Settings.canDrawOverlays(c)) {
            try { c.startForegroundService(Intent(c, OverlayService::class.java)) } catch (_: Exception) {}
        }
    }
}
EOF

cat > $P/README.md <<'EOF'
# Ultron Assistant
Push to GitHub -> Actions -> "Build APK" -> download the `Ultron-APK` artifact.
Keys are entered inside the app (Settings), never stored in the repo.
EOF

echo "Done. Project created in ./$P"
