package de.merkezcamii.vilsbiburg

import android.graphics.Color as AColor
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(AColor.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(AColor.TRANSPARENT)
        )
        super.onCreate(savedInstanceState)
        setContent { App() }
    }
}

@Composable
fun App() {
    var splashDone by rememberSaveable { mutableStateOf(false) }
    Box(Modifier.fillMaxSize().background(Bg)) {
        AnimatedContent(
            targetState = splashDone,
            transitionSpec = { fadeIn(tween(600)) togetherWith fadeOut(tween(450)) },
            label = "splash"
        ) { done ->
            if (done) MainScreen() else Splash { splashDone = true }
        }
    }
}

private data class Tab(val label: String, val icon: ImageVector?)

private val TABS = listOf(
    Tab("Vakitler", Icons.Clock),
    Tab("Duyurular", Icons.Speaker),
    Tab("Lokal", null), // Gençlik-Hilal
    Tab("Hakkımızda", Icons.Mosque),
)

@Composable
fun MainScreen() {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    BackHandler(enabled = tab != 0) { tab = 0 }

    Box(Modifier.fillMaxSize()) {
        BrandBackground()
        AnimatedContent(
            targetState = tab,
            transitionSpec = { fadeIn(tween(380)) togetherWith fadeOut(tween(200)) },
            label = "tabs",
            modifier = Modifier.fillMaxSize()
        ) { t ->
            when (t) {
                0 -> VakitlerPage()
                1 -> DuyurularPage()
                2 -> LokalPage()
                else -> HakkimizdaPage()
            }
        }
        TabBar(tab, { tab = it }, Modifier.align(Alignment.BottomCenter))
    }
}

@Composable
private fun TabBar(selected: Int, onSelect: (Int) -> Unit, modifier: Modifier) {
    var shown by remember { mutableStateOf(false) }
    androidx.compose.runtime.LaunchedEffect(Unit) { shown = true }
    val appear by animateFloatAsState(if (shown) 1f else 0f, tween(700, delayMillis = 250), label = "bar")

    Box(
        modifier
            .fillMaxWidth()
            .windowInsetsPadding(WindowInsets.navigationBars)
            .padding(bottom = 12.dp)
            .graphicsLayer { alpha = appear; translationY = (1f - appear) * 20.dp.toPx() },
        contentAlignment = Alignment.Center
    ) {
        Row(
            Modifier
                .fillMaxWidth(0.94f)
                .widthIn(max = 440.dp)
                .glass(RoundedCornerShape(22.dp))
                .padding(6.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            TABS.forEachIndexed { i, t ->
                TabItem(t, i == selected, Modifier.weight(1f)) { onSelect(i) }
            }
        }
    }
}

@Composable
private fun TabItem(t: Tab, on: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val content by animateColorAsState(if (on) Bg else Muted, tween(300), label = "c")
    val bgAlpha by animateFloatAsState(if (on) 1f else 0f, tween(300), label = "a")
    Column(
        modifier
            .clip(RoundedCornerShape(16.dp))
            .background(GoldGradient, alpha = bgAlpha)
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onClick)
            .padding(vertical = 8.dp, horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        if (t.icon != null) {
            Icon(t.icon, t.label, tint = content, modifier = Modifier.size(22.dp))
        } else {
            Image(
                painterResource(R.drawable.hilal_icon), t.label,
                colorFilter = ColorFilter.tint(content),
                modifier = Modifier.size(22.dp)
            )
        }
        Text(
            t.label,
            maxLines = 1,
            style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.SemiBold, fontSize = 11.sp, color = content),
            modifier = Modifier.padding(top = 2.dp)
        )
    }
}
