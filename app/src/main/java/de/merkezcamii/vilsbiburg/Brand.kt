package de.merkezcamii.vilsbiburg

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Hintergrund: Licht + langsam wanderndes Ornament-Muster (wie Webseite). */
@Composable
fun BrandBackground(modifier: Modifier = Modifier) {
    val inf = rememberInfiniteTransition(label = "drift")
    val drift by inf.animateFloat(
        0f, 1f,
        infiniteRepeatable(tween(90_000, easing = LinearEasing), RepeatMode.Restart),
        label = "drift"
    )
    Box(modifier.fillMaxSize().background(Bg)) {
        Canvas(Modifier.fillMaxSize()) {
            drawRect(Brush.verticalGradient(listOf(Color(0xFF081B14), Bg)))
            drawRect(
                Brush.radialGradient(
                    listOf(Color(0xFF0F3A2B), Color.Transparent),
                    center = Offset(size.width / 2, 0f), radius = size.width * 1.1f
                )
            )
            drawRect(
                Brush.radialGradient(
                    listOf(Gold.copy(alpha = 0.16f), Color.Transparent),
                    center = Offset(size.width / 2, size.height * 0.22f), radius = size.width * 0.75f
                )
            )
        }
        Canvas(
            Modifier
                .fillMaxSize()
                .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen; alpha = 0.16f }
        ) {
            val tile = 96.dp.toPx()
            val s = tile / 96f
            val sw = 1.dp.toPx()
            val shift = drift * tile - tile
            val diamond = Path().apply {
                moveTo(48f * s, 14.06f * s); lineTo(81.94f * s, 48f * s)
                lineTo(48f * s, 81.94f * s); lineTo(14.06f * s, 48f * s); close()
            }
            val cols = (size.width / tile).toInt() + 3
            val rows = (size.height / tile).toInt() + 3
            for (r in 0 until rows) for (c in 0 until cols) {
                translate(c * tile + shift, r * tile + shift) {
                    drawRect(Gold, Offset(24f * s, 24f * s), Size(48f * s, 48f * s), style = Stroke(sw))
                    drawPath(diamond, Gold, style = Stroke(sw))
                    drawCircle(Gold, 12f * s, Offset(48f * s, 48f * s), style = Stroke(sw))
                    drawLine(Gold, Offset(0f, 0f), Offset(24f * s, 24f * s), sw)
                    drawLine(Gold, Offset(96f * s, 0f), Offset(72f * s, 24f * s), sw)
                    drawLine(Gold, Offset(0f, 96f * s), Offset(24f * s, 72f * s), sw)
                    drawLine(Gold, Offset(96f * s, 96f * s), Offset(72f * s, 72f * s), sw)
                }
            }
            drawRect(
                Brush.radialGradient(
                    listOf(Color.Black, Color.Black.copy(alpha = 0.35f), Color.Transparent),
                    center = Offset(size.width / 2, size.height * 0.24f),
                    radius = size.width * 0.95f
                ),
                blendMode = BlendMode.DstIn
            )
        }
    }
}

private val EaseRise: Easing = CubicBezierEasing(0.65f, 0f, 0.25f, 1f)
private val EaseOut: Easing = CubicBezierEasing(0.2f, 0.8f, 0.2f, 1f)
private val EaseStd: Easing = CubicBezierEasing(0.25f, 0.1f, 0.25f, 1f)

private fun seg(t: Float, start: Float, dur: Float, e: Easing): Float =
    e.transform(((t - start) / dur).coerceIn(0f, 1f))

/**
 * Logo aus drei Ebenen wie auf der Webseite:
 * Kuppel steigt auf, Hilal senkt sich + leuchtet, Schrift wird scharf.
 * [t] = Zeit in ms (für statisches Logo einfach großen Wert übergeben).
 */
@Composable
fun AnimatedLogo(t: Float, modifier: Modifier = Modifier, glow: Boolean = true) {
    val dome = seg(t, 150f, 950f, EaseRise)
    val cres = seg(t, 950f, 650f, EaseOut)
    val txt = seg(t, 1250f, 650f, EaseStd)

    val inf = rememberInfiniteTransition(label = "glow")
    val pulse by inf.animateFloat(
        0.35f, 1f,
        infiniteRepeatable(tween(2000, easing = EaseStd), RepeatMode.Reverse),
        label = "pulse"
    )

    BoxWithConstraints(modifier.aspectRatio(2041f / 1271f)) {
        val w = maxWidth
        val h = maxHeight
        // Leuchten hinter dem Hilal
        if (glow) {
            Canvas(Modifier.fillMaxSize()) {
                val c = Offset(size.width * 0.523f, size.width * 168f / 1100f * 0.42f)
                drawCircle(
                    Brush.radialGradient(
                        listOf(Gold.copy(alpha = 0.55f * pulse * cres), Color.Transparent),
                        center = c, radius = size.width * 0.13f
                    ),
                    radius = size.width * 0.13f, center = c
                )
            }
        }
        Image(
            painterResource(R.drawable.logo_dome), null,
            contentScale = ContentScale.FillBounds,
            modifier = Modifier
                .fillMaxSize()
                .drawWithContent {
                    clipRect(top = size.height * (1f - dome)) { this@drawWithContent.drawContent() }
                }
        )
        Image(
            painterResource(R.drawable.logo_cres), null,
            contentScale = ContentScale.FillBounds,
            modifier = Modifier
                .width(w)
                .height(w * (168f / 1100f))
                .graphicsLayer {
                    alpha = cres
                    translationY = (1f - cres) * -14.dp.toPx()
                    val sc = 0.96f + 0.04f * cres
                    scaleX = sc; scaleY = sc
                }
        )
        Image(
            painterResource(R.drawable.logo_txt), null,
            contentScale = ContentScale.FillBounds,
            modifier = Modifier
                .offset(x = w * 0.2401f, y = h * 0.7002f)
                .width(w * 0.5242f)
                .aspectRatio(577f / 129f)
                .blur(((1f - txt) * 6f).dp)
                .alpha(txt)
        )
    }
}

const val SPLASH_MS = 2300f

/** Startanimation: Besmele → Kuppel → Hilal → Schrift. Antippen überspringt. */
@Composable
fun Splash(onDone: () -> Unit) {
    val time = remember { Animatable(0f) }
    var finished by remember { mutableStateOf(false) }
    fun finish() {
        if (!finished) { finished = true; onDone() }
    }
    LaunchedEffect(Unit) {
        time.animateTo(SPLASH_MS, tween(SPLASH_MS.toInt(), easing = LinearEasing))
        finish()
    }
    val t = time.value
    Box(
        Modifier
            .fillMaxSize()
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { finish() },
        contentAlignment = Alignment.Center
    ) {
        BrandBackground()
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            val b = seg(t, 0f, 700f, EaseStd)
            Text(
                "بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيمِ",
                style = TextStyle(fontFamily = Amiri, fontSize = 24.sp, color = Gold, textAlign = TextAlign.Center),
                modifier = Modifier.graphicsLayer { alpha = b; translationY = (1f - b) * 14.dp.toPx() }
            )
            Spacer(Modifier.size(26.dp))
            AnimatedLogo(t, Modifier.fillMaxWidth(0.86f))
            Spacer(Modifier.size(28.dp))
            val n = seg(t, 1600f, 600f, EaseStd)
            Text(
                "Muslimgemeinde Vilsbiburg e.V.",
                style = TextStyle(fontFamily = Marcellus, fontSize = 21.sp, color = TextC, letterSpacing = 1.2.sp),
                modifier = Modifier.graphicsLayer { alpha = n; translationY = (1f - n) * 14.dp.toPx() }
            )
        }
    }
}
