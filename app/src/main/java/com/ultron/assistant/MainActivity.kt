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
