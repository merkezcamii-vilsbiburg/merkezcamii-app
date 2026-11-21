@file:OptIn(ExperimentalTextApi::class)

package de.merkezcamii.vilsbiburg

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

// ---------- Farben (wie Webseite) ----------
val Bg = Color(0xFF06140F)
val Bg2 = Color(0xFF0B2A20)
val Gold = Color(0xFFE3BF72)
val Gold2 = Color(0xFFB8903F)
val TextC = Color(0xFFF4EFE4)
val Muted = Color(0x9EF4EFE4)
val Line = Color(0x38E3BF72)
val OpenGreen = Color(0xFF4ADE80)
val ClosedRed = Color(0xFFF87171)

// ---------- Schriften ----------
val Marcellus = FontFamily(Font(R.font.marcellus))
val Amiri = FontFamily(Font(R.font.amiri))
val Manrope = FontFamily(
    Font(R.font.manrope, FontWeight.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(400))),
    Font(R.font.manrope, FontWeight.Medium, variationSettings = FontVariation.Settings(FontVariation.weight(500))),
    Font(R.font.manrope, FontWeight.SemiBold, variationSettings = FontVariation.Settings(FontVariation.weight(600))),
    Font(R.font.manrope, FontWeight.Bold, variationSettings = FontVariation.Settings(FontVariation.weight(700))),
    Font(R.font.manrope, FontWeight.ExtraBold, variationSettings = FontVariation.Settings(FontVariation.weight(800))),
)

val GoldGradient = Brush.verticalGradient(listOf(Gold, Gold2))

// ---------- Glas-Karte ----------
fun Modifier.glass(shape: Shape = RoundedCornerShape(26.dp), elevated: Boolean = true): Modifier {
    val base = if (elevated) this.shadow(18.dp, shape, ambientColor = Color.Black, spotColor = Color.Black) else this
    return base
        .clip(shape)
        .background(Color(0xFF0C2119))
        .background(
            Brush.linearGradient(
                listOf(Color.White.copy(alpha = 0.09f), Color.White.copy(alpha = 0.03f)),
                start = Offset(0f, 0f),
                end = Offset(900f, 1400f)
            )
        )
        .border(1.dp, Line, shape)
}

// ---------- Strich-Icons (Pfade von der Webseite) ----------
private fun strokeIcon(vararg paths: String, width: Float = 1.7f): ImageVector {
    val b = ImageVector.Builder(
        defaultWidth = 24.dp, defaultHeight = 24.dp,
        viewportWidth = 24f, viewportHeight = 24f
    )
    paths.forEach { d ->
        b.addPath(
            pathData = addPathNodes(d),
            fill = null,
            stroke = SolidColor(Color.White),
            strokeLineWidth = width,
            strokeLineCap = StrokeCap.Round,
            strokeLineJoin = StrokeJoin.Round
        )
    }
    return b.build()
}

object Icons {
    val Clock = strokeIcon("M4,13a8,8 0 1,0 16,0a8,8 0 1,0 -16,0", "M12 9v4l2.5 2.5M9 2h6")
    val Speaker = strokeIcon("M4 10v4a1 1 0 0 0 1 1h3l6 4V5L8 9H5a1 1 0 0 0-1 1z", "M18 8.5a5 5 0 0 1 0 7")
    val Mosque = strokeIcon("M4 21V11a8 8 0 0 1 16 0v10M2 21h20M12 3V1M9 21v-5a3 3 0 0 1 6 0v5")
    val LockClosed = strokeIcon(
        "M7 11h10a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-6a2 2 0 0 1 2-2z",
        "M8 11V7a4 4 0 0 1 8 0v4", width = 2f
    )
    val LockOpen = strokeIcon(
        "M7 11h10a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-6a2 2 0 0 1 2-2z",
        "M8 11V7a4 4 0 0 1 7.5-2", width = 2f
    )
    val Ball = strokeIcon("M3,12a9,9 0 1,0 18,0a9,9 0 1,0 -18,0", "M12 7.5l3.8 2.8-1.5 4.4H9.7l-1.5-4.4z")
    val Camera = strokeIcon("M4 8h3l2-2.5h6L17 8h3a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1z", "M9,13a3,3 0 1,0 6,0a3,3 0 1,0 -6,0")

    private val moon = "M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"
    val Prayer = mapOf(
        "imsak" to strokeIcon(moon, width = 1.6f),
        "gunes" to strokeIcon("M3 18h18M6 18a6 6 0 0 1 12 0M12 6v3M5 11l2 1.5M19 11l-2 1.5", width = 1.6f),
        "ogle" to strokeIcon(
            "M8,12a4,4 0 1,0 8,0a4,4 0 1,0 -8,0",
            "M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.5 1.5M17.5 17.5L19 19M5 19l1.5-1.5M17.5 6.5L19 5", width = 1.6f
        ),
        "ikindi" to strokeIcon(
            "M8,13a4,4 0 1,0 8,0a4,4 0 1,0 -8,0",
            "M12 4v2M4 13h2M18 13h2M6.3 7.3l1.4 1.4M16.3 8.7l1.4-1.4M3 20h18", width = 1.6f
        ),
        "aksam" to strokeIcon("M3 18h18M7 18a5 5 0 0 1 10 0M12 9V5M9.5 7.5L12 5l2.5 2.5", width = 1.6f),
        "yatsi" to strokeIcon(moon, "M17 4l.5 1.5L19 6l-1.5.5L17 8l-.5-1.5L15 6l1.5-.5z", width = 1.6f),
    )
}
