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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import kotlinx.coroutines.delay
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
import androidx.compose.ui.layout.ContentScale
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
        AppState.init(applicationContext)
        handleIntent(intent)
        setContent { AppRoot() }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(i: android.content.Intent?) {
        val t = i?.getIntExtra("tab", -1) ?: -1
        if (t in 0..3) Ui.openTab = t
    }
}

@Composable
fun AppRoot() {
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
    // Aus Benachrichtigung geöffnet → passenden Tab zeigen
    LaunchedEffect(Ui.openTab) {
        Ui.openTab?.let { tab = it; Ui.openTab = null; AppState.refresh() }
    }
    // Android 13+: Erlaubnis für Benachrichtigungen
    val permLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
    ) { }
    LaunchedEffect(Unit) {
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            delay(1200)
            permLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
        }
    }
    BackHandler(enabled = tab != 0 && Ui.compose == null && !Ui.admin && !Ui.manage) { tab = 0 }

    // Daten laden: Duyurular/Kilitler alle 30 s, Maçlar alle 2 min
    LaunchedEffect(Unit) {
        while (true) { AppState.refresh(); delay(30_000) }
    }
    LaunchedEffect(Unit) {
        while (true) { AppState.refreshMatches(); delay(120_000) }
    }
    // Gelesen markieren, solange man auf dem Tab ist
    val camiCount = AppState.announcements.count { it.section == "cami" }
    val lokalCount = AppState.announcements.count { it.section == "lokal" }
    LaunchedEffect(tab, camiCount, lokalCount, AppState.loaded) {
        if (!AppState.loaded) return@LaunchedEffect
        if (tab == 1) AppState.markSeen("cami")
        if (tab == 2) AppState.markSeen("lokal")
    }
    val badges = listOf(0, AppState.unread("cami"), AppState.unread("lokal"), 0)

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
        TabBar(tab, badges, { tab = it }, Modifier.align(Alignment.BottomCenter))

        Ui.compose?.let { sec -> ComposeScreen(sec) { Ui.compose = null } }
        if (Ui.admin) AdminGate { Ui.admin = false }
        if (Ui.manage) ManageScreen { Ui.manage = false }
    }
}

@Composable
private fun TabBar(selected: Int, badges: List<Int>, onSelect: (Int) -> Unit, modifier: Modifier) {
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
                TabItem(t, i == selected, badges[i], Modifier.weight(1f)) { onSelect(i) }
            }
        }
    }
}

@Composable
private fun TabItem(t: Tab, on: Boolean, badge: Int, modifier: Modifier, onClick: () -> Unit) {
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
        Box(contentAlignment = Alignment.Center) {
        if (t.icon != null) {
            Icon(t.icon, t.label, tint = content, modifier = Modifier.size(22.dp))
        } else {
            // Gençlik Kolları logosu, einfarbig wie die anderen Menü-Icons.
            Image(
                painterResource(R.drawable.logo_genclik), t.label,
                contentScale = ContentScale.Fit,
                colorFilter = ColorFilter.tint(content),
                modifier = Modifier.fillMaxWidth(0.82f).height(17.dp).padding(top = 3.dp, bottom = 1.dp)
            )
        }
        if (!on && badge > 0) {
            GoldBadge(badge, Modifier.align(Alignment.TopEnd).offset(x = 14.dp, y = (-6).dp))
        }
        }
        Text(
            t.label,
            maxLines = 1,
            style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.SemiBold, fontSize = 11.sp, color = content),
            modifier = Modifier.padding(top = 2.dp)
        )
    }
}
