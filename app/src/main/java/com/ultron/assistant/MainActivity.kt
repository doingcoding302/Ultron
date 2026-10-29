package com.ultron.assistant

import android.Manifest
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.Toast
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
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
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
private const val HEAD_AR = 0.833f
private const val ELX = 0.283f
private const val ELY = 0.503f
private const val ERX = 0.669f
private const val ERY = 0.521f

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

    val inf = rememberInfiniteTransition(label = "t")
    val t by inf.animateFloat(0f, 1f, infiniteRepeatable(tween(12000, easing = LinearEasing)), label = "t")
    val intro = remember { Animatable(0f) }
    LaunchedEffect(Unit) { intro.animateTo(1f, tween(1800, easing = FastOutSlowInEasing)) }
    val energy by animateFloatAsState(
        when (status) { "listening" -> 1f; "processing" -> 0.9f; "responding" -> 0.75f; else -> 0.3f },
        tween(600), label = "energy"
    )
    var shown by remember { mutableStateOf("") }
    LaunchedEffect(line) {
        shown = ""
        for (c in line.uppercase()) { shown += c; delay(if (line.length > 80) 6L else 20L) }
    }
    val sub = when (status) { "listening" -> " · LISTENING"; "processing" -> " · THINKING"; "responding" -> " · SPEAKING"; else -> "" }

    Box(Modifier.fillMaxSize().background(Color.Black).statusBarsPadding().navigationBarsPadding()) {
        Canvas(Modifier.fillMaxSize()) {
            drawRect(Brush.radialGradient(
                listOf(Red.copy(alpha = 0.10f + 0.10f * energy), Color.Transparent),
                center = Offset(size.width / 2, size.height * 0.38f), radius = size.width * 0.95f))
        }

        Row(Modifier.fillMaxWidth().padding(horizontal = 26.dp, vertical = 28.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(7.dp).graphicsLayer { alpha = 0.6f + 0.4f * sin(t * TAU * 6) }
                .clip(CircleShape).background(Red))
            Spacer(Modifier.width(18.dp))
            Column(Modifier.weight(1f)) {
                Text("U.L.T.R.O.N.", color = Color(0xFFE6E8F0), fontSize = 19.sp, letterSpacing = 7.sp)
                Spacer(Modifier.height(4.dp))
                Text("AI ASSISTANT$sub", color = Dim, fontSize = 11.sp, letterSpacing = 3.sp)
            }
            Text("⚙", color = Dim, fontSize = 26.sp, modifier = Modifier.clickable { settings = true })
        }

        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
            Spacer(Modifier.height(84.dp))

            BoxWithConstraints(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                val s = if (maxWidth < maxHeight) maxWidth else maxHeight
                Box(Modifier.size(s * 0.96f), contentAlignment = Alignment.Center) {
                    Canvas(Modifier.fillMaxSize()) {
                        val r = size.minDimension / 2; val c = center; val a = intro.value
                        val rot = t * 360f
                        fun arc(f: Float, start: Float, sweep: Float, col: Color, w: Float) =
                            drawArc(col, start, sweep, false, Offset(c.x - r * f, c.y - r * f),
                                Size(2 * r * f, 2 * r * f), style = Stroke(w, cap = StrokeCap.Round))
                        drawCircle(Red.copy(alpha = 0.22f * a), r * 0.98f, style = Stroke(1.5f))
                        drawCircle(Red.copy(alpha = 0.14f * a), r * 0.84f, style = Stroke(1.5f))
                        for (i in 0 until 4) {
                            val ang = (i * 90f + 45f) * (PI.toFloat() / 180f)
                            drawLine(Red.copy(alpha = 0.6f * a),
                                Offset(c.x + cos(ang) * r * 0.955f, c.y + sin(ang) * r * 0.955f),
                                Offset(c.x + cos(ang) * r * 1.0f, c.y + sin(ang) * r * 1.0f), 3f)
                        }
                        arc(0.98f, rot, 75f, Red.copy(alpha = (0.45f + 0.5f * energy) * a), 4f)
                        arc(0.98f, rot + 180f, 40f, Red.copy(alpha = 0.35f * a), 3f)
                        arc(0.84f, -rot * 2, 50f, Red.copy(alpha = (0.35f + 0.4f * energy) * a), 3f)
                        arc(0.91f, rot * 3, 24f, Red.copy(alpha = ((energy - 0.3f).coerceAtLeast(0f) * 1.4f) * a), 3f)
                    }
                    Box(
                        Modifier.fillMaxWidth(0.62f).aspectRatio(HEAD_AR).graphicsLayer {
                            val sc = (0.8f + 0.2f * intro.value) * (1f + 0.010f * sin(t * TAU * 3))
                            scaleX = sc; scaleY = sc; alpha = intro.value
                        }
                    ) {
                        Image(painterResource(R.drawable.ultron_head), null, Modifier.matchParentSize(), contentScale = ContentScale.Fit)
                        Canvas(Modifier.matchParentSize()) {
                            val b = ((intro.value - 0.5f) * 2f).coerceIn(0f, 1f)
                            val fl = if (b < 1f && (b * 20).toInt() % 2 == 1) 0.3f else 1f
                            val g = (0.30f + 0.70f * energy * (0.8f + 0.2f * sin(t * TAU * 6))) * b * fl
                            for ((ex, ey) in listOf(ELX to ELY, ERX to ERY)) {
                                val c = Offset(size.width * ex, size.height * ey); val rr = size.width * 0.17f
                                drawCircle(
                                    Brush.radialGradient(listOf(Red.copy(alpha = (0.65f * g).coerceIn(0f, 1f)), Color.Transparent), center = c, radius = rr),
                                    rr, c, blendMode = BlendMode.Plus
                                )
                            }
                        }
                    }
                }
            }

            Text(
                shown + if (shown.length < line.length) "▌" else "",
                color = Dim, fontSize = 14.sp, letterSpacing = 3.sp, textAlign = TextAlign.Center, maxLines = 6,
                modifier = Modifier.padding(horizontal = 32.dp).heightIn(min = 52.dp).animateContentSize()
            )
            Spacer(Modifier.height(10.dp))
            Box(Modifier.width(36.dp).height(2.dp).background(Red))
            Spacer(Modifier.height(10.dp))

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

            Row(
                Modifier.fillMaxWidth().padding(start = 34.dp, end = 34.dp, top = 6.dp, bottom = 26.dp),
                horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically
            ) {
                Column(Modifier.clickable { mic() }.padding(8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Canvas(Modifier.size(26.dp)) {
                        val w = size.width; val h = size.height
                        drawCircle(Dim, w * .28f, Offset(w / 2, h * .38f), style = Stroke(2.5f))
                        drawLine(Dim, Offset(w / 2, h * .66f), Offset(w / 2, h * .92f), 2.5f)
                    }
                    Spacer(Modifier.height(8.dp))
                    Text("VOICE", color = Dim, fontSize = 11.sp, letterSpacing = 2.sp)
                }

                val src = remember { MutableInteractionSource() }
                val pressed by src.collectIsPressedAsState()
                val press by animateFloatAsState(if (pressed) 0.90f else 1f, spring(dampingRatio = 0.45f), label = "press")
                Box(Modifier.size(112.dp), contentAlignment = Alignment.Center) {
                    Canvas(Modifier.requiredSize(280.dp)) {
                        drawCircle(Red.copy(alpha = 0.12f), 66.dp.toPx(), style = Stroke(1.5f))
                        if (status == "listening") for (k in 0..1) {
                            val f = ((t * 6f) + k * 0.5f) % 1f
                            drawCircle(Red.copy(alpha = 0.45f * (1f - f)), 54.dp.toPx() + 70.dp.toPx() * f, style = Stroke(3f))
                        }
                    }
                    Box(
                        Modifier.size(112.dp).graphicsLayer { scaleX = press; scaleY = press }
                            .drawBehind {
                                val rc = size.minDimension / 2
                                val g = 0.55f + 0.45f * energy * (0.8f + 0.2f * sin(t * TAU * 6))
                                drawCircle(Color(0xFF12080B), rc - 12.dp.toPx())
                                drawCircle(Red.copy(alpha = 0.22f * g), rc - 3.dp.toPx(), style = Stroke(14.dp.toPx()))
                                drawCircle(Red.copy(alpha = 0.50f * g), rc - 5.dp.toPx(), style = Stroke(8.dp.toPx()))
                                drawCircle(Red.copy(alpha = g), rc - 7.dp.toPx(), style = Stroke(3.dp.toPx()))
                                drawCircle(Red.copy(alpha = 0.35f * g), rc - 18.dp.toPx(), style = Stroke(1.5f))
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

                Column(Modifier.clickable { typing = !typing }.padding(8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Canvas(Modifier.size(26.dp)) {
                        val w = size.width; val h = size.height
                        drawRoundRect(Dim, Offset(w * .12f, h * .08f), Size(w * .76f, h * .84f), CornerRadius(w * .12f), style = Stroke(2.5f))
                        for (i in 0..2) drawLine(Dim, Offset(w * .28f, h * (.32f + i * .18f)), Offset(w * .72f, h * (.32f + i * .18f)), 2.5f)
                    }
                    Spacer(Modifier.height(8.dp))
                    Text("TYPE", color = Dim, fontSize = 11.sp, letterSpacing = 2.sp)
                }
            }
        }
    }

    if (settings) SettingsDialog(ctx) { settings = false }
}

private fun toast(ctx: Context, msg: String) {
    Handler(Looper.getMainLooper()).post { Toast.makeText(ctx, msg, Toast.LENGTH_LONG).show() }
}

@Composable
fun SettingsDialog(ctx: Context, onClose: () -> Unit) {
    var gem by remember { mutableStateOf(Cfg.get(ctx, "gemini")) }
    var fish by remember { mutableStateOf(Cfg.get(ctx, "fish")) }
    var voice by remember { mutableStateOf(Cfg.get(ctx, "voice")) }
    var model by remember { mutableStateOf(Cfg.get(ctx, "model")) }
    fun open(i: Intent) = ctx.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    fun save() {
        Cfg.set(ctx, "gemini", gem.trim()); Cfg.set(ctx, "fish", fish.trim())
        Cfg.set(ctx, "voice", voice.trim()); Cfg.set(ctx, "model", model.trim())
    }
    AlertDialog(
        onDismissRequest = onClose,
        containerColor = Color(0xFF111114),
        title = { Text("ULTRON SETTINGS", color = Red, letterSpacing = 3.sp, fontSize = 16.sp) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                @Composable
                fun f(v: String, ch: (String) -> Unit, lbl: String) =
                    OutlinedTextField(v, ch, Modifier.fillMaxWidth().padding(vertical = 4.dp), singleLine = true, label = { Text(lbl) })
                f(gem, { gem = it }, "Google API key (brain)")
                f(model, { model = it }, "Model (leave blank)")
                f(fish, { fish = it }, "Fish Audio API key (voice)")
                f(voice, { voice = it }, "Voice model id")
                Spacer(Modifier.height(8.dp))
                TextButton({
                    save(); toast(ctx, "Testing brain…")
                    Thread { toast(ctx, Brain.ask(ctx, "Say hello in five words.")) }.start()
                }) { Text("TEST BRAIN", color = Red) }
                TextButton({
                    save(); toast(ctx, "Testing voice…")
                    Voice.speak(ctx, "I am Ultron. I am online.") { toast(ctx, Voice.lastError.ifBlank { "Voice played OK" }) }
                }) { Text("TEST VOICE", color = Red) }
                TextButton({ open(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + ctx.packageName))) }) { Text("1. Allow overlay", color = Red) }
                TextButton({ open(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }) { Text("2. Enable accessibility (control apps)", color = Red) }
                TextButton({
                    if (Settings.canDrawOverlays(ctx)) ctx.startForegroundService(Intent(ctx, OverlayService::class.java))
                    else open(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + ctx.packageName)))
                }) { Text("3. Start overlay", color = Red) }
                TextButton({ ctx.stopService(Intent(ctx, OverlayService::class.java)) }) { Text("Stop overlay", color = Dim) }
            }
        },
        confirmButton = { TextButton({ save(); onClose() }) { Text("SAVE", color = Red) } }
    )
}
