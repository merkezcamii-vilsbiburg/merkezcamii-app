@file:OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)

package de.merkezcamii.vilsbiburg

import android.widget.Toast
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.LocalDate
import java.time.format.DateTimeFormatter

// ---------- gemeinsame Bausteine ----------

@Composable
fun PageColumn(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .windowInsetsPadding(WindowInsets.statusBars)
            .padding(horizontal = 18.dp)
            .padding(bottom = 130.dp),
        content = content
    )
}

@Composable
fun SectionHead(title: String, kicker: String, top: Int = 26) {
    Row(
        Modifier.fillMaxWidth().padding(top = top.dp, bottom = 16.dp),
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(title, style = TextStyle(fontFamily = Marcellus, fontSize = 26.sp, color = TextC, letterSpacing = 1.sp))
        Text(
            kicker.uppercase(Prayer.TR),
            style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 11.sp, color = Gold, letterSpacing = 2.sp),
            modifier = Modifier.padding(bottom = 5.dp)
        )
    }
}

@Composable
fun DemoTag() {
    Text(
        "ÖRNEK",
        style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 9.sp, color = Muted, letterSpacing = 0.8.sp),
        modifier = Modifier
            .border(1.dp, Line, RoundedCornerShape(50))
            .padding(horizontal = 8.dp, vertical = 2.dp)
    )
}

@Composable
fun GoldDivider() {
    Box(
        Modifier
            .width(120.dp)
            .height(1.dp)
            .background(Brush.horizontalGradient(listOf(Color.Transparent, Gold, Color.Transparent)))
    )
}

/** Sanftes Einblenden von unten beim Öffnen einer Seite. */
@Composable
fun FadeUp(delayMs: Int = 0, content: @Composable () -> Unit) {
    var shown by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { shown = true }
    val p by animateFloatAsState(if (shown) 1f else 0f, tween(700, delayMillis = delayMs), label = "fade")
    Box(Modifier.graphicsLayer { alpha = p; translationY = (1f - p) * 22.dp.toPx() }) { content() }
}

// ---------- 1) Vakitler ----------

@Composable
fun VakitlerPage() {
    var now by remember { mutableStateOf(Instant.now()) }
    LaunchedEffect(Unit) {
        while (true) {
            now = Instant.now()
            delay(1000L - (System.currentTimeMillis() % 1000L))
        }
    }
    val date = now.atZone(Prayer.ZONE).toLocalDate()
    val today = remember(date) { Prayer.compute(date) }
    val prevYatsi = remember(date) { Prayer.compute(date.minusDays(1))["yatsi"]!! }
    val tomImsak = remember(date) { Prayer.compute(date.plusDays(1))["imsak"]!! }
    val miladi = remember(date) { Prayer.miladi(date) }
    val hicri = remember(date) { Prayer.hicri(now) }

    val keys = Prayer.KEYS
    val nextIdx = keys.indexOfFirst { today[it]!!.isAfter(now) }
    val curIdx = if (nextIdx == -1) 5 else nextIdx - 1
    val nextT: Instant
    val startT: Instant
    val label: String
    if (nextIdx == -1) {
        nextT = tomImsak; startT = today["yatsi"]!!; label = "İmsak · yarın"
    } else {
        nextT = today[keys[nextIdx]]!!
        startT = if (curIdx >= 0) today[keys[curIdx]]!! else prevYatsi
        label = Prayer.NAMES[keys[nextIdx]]!!
    }
    val secs = ((nextT.toEpochMilli() - now.toEpochMilli()) / 1000L).coerceAtLeast(0L)
    val clock = "%02d:%02d:%02d".format(secs / 3600, secs % 3600 / 60, secs % 60)
    val pct = ((now.toEpochMilli() - startT.toEpochMilli()).toFloat() /
            (nextT.toEpochMilli() - startT.toEpochMilli()).toFloat()).coerceIn(0f, 1f)

    PageColumn {
        Column(Modifier.fillMaxWidth().padding(top = 22.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            FadeUp {
                Text(
                    "بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيمِ",
                    style = TextStyle(fontFamily = Amiri, fontSize = 21.sp, color = Gold, textAlign = TextAlign.Center)
                )
            }
            Spacer(Modifier.height(14.dp))
            AnimatedLogo(10_000f, Modifier.fillMaxWidth(0.66f))
            Spacer(Modifier.height(16.dp))
            Text(
                "Muslimgemeinde Vilsbiburg e.V.",
                style = TextStyle(fontFamily = Marcellus, fontSize = 19.sp, color = TextC, letterSpacing = 1.sp)
            )
            Text(
                "Camimize hoş geldiniz",
                style = TextStyle(fontFamily = Manrope, fontSize = 14.sp, color = Muted),
                modifier = Modifier.padding(top = 4.dp)
            )
            Spacer(Modifier.height(14.dp))
            GoldDivider()
        }
        Spacer(Modifier.height(24.dp))

        FadeUp(150) {
            Column(Modifier.fillMaxWidth().glass()) {
                Column(
                    Modifier.fillMaxWidth().padding(start = 22.dp, end = 22.dp, top = 22.dp, bottom = 16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        PulseDot()
                        Spacer(Modifier.width(8.dp))
                        Text(
                            "SIRADAKİ VAKİT",
                            style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 11.sp, color = Gold, letterSpacing = 2.4.sp)
                        )
                    }
                    Text(
                        "$label · ${Prayer.fmt(nextT)}",
                        style = TextStyle(fontFamily = Marcellus, fontSize = 25.sp, color = TextC),
                        modifier = Modifier.padding(top = 6.dp)
                    )
                    Text(
                        clock,
                        style = TextStyle(
                            fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 52.sp,
                            brush = Brush.verticalGradient(listOf(Color.White, Color.White, Gold)),
                            letterSpacing = 1.sp
                        ),
                        modifier = Modifier.padding(top = 2.dp)
                    )
                    Box(
                        Modifier
                            .padding(top = 12.dp, bottom = 6.dp)
                            .fillMaxWidth()
                            .height(4.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(Color.White.copy(alpha = 0.08f))
                    ) {
                        Box(
                            Modifier
                                .fillMaxHeight()
                                .fillMaxWidth(pct)
                                .clip(RoundedCornerShape(4.dp))
                                .background(Brush.horizontalGradient(listOf(Gold2, Gold)))
                        )
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(miladi, style = TextStyle(fontFamily = Manrope, fontSize = 12.sp, color = Muted))
                        Text(hicri, style = TextStyle(fontFamily = Manrope, fontSize = 12.sp, color = Muted))
                    }
                }
                Box(Modifier.fillMaxWidth().height(1.dp).background(Line))
                for (row in 0..1) {
                    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min)) {
                        for (col in 0..2) {
                            val i = row * 3 + col
                            val k = keys[i]
                            val past = i < curIdx || (i == curIdx && k == "gunes")
                            val active = i == curIdx && k != "gunes"
                            PrayerCell(k, Prayer.fmt(today[k]!!), past, active, Modifier.weight(1f))
                            if (col < 2) Box(Modifier.width(1.dp).fillMaxHeight().background(Line))
                        }
                    }
                    if (row == 0) Box(Modifier.fillMaxWidth().height(1.dp).background(Line))
                }
            }
        }
        Text(
            "Vilsbiburg için otomatik hesaplanır · Diyanet takviminden 1–2 dk farklı olabilir",
            style = TextStyle(fontFamily = Manrope, fontSize = 11.5.sp, color = Muted, textAlign = TextAlign.Center),
            modifier = Modifier.fillMaxWidth().padding(top = 12.dp)
        )
        EzanSettingsCard()
    }
}

@Composable
private fun PulseDot() {
    val inf = androidx.compose.animation.core.rememberInfiniteTransition(label = "dot")
    val p by inf.animateFloat(
        0f, 1f,
        androidx.compose.animation.core.infiniteRepeatable(tween(2000)),
        label = "dot"
    )
    Canvas(Modifier.size(18.dp)) {
        val c = Offset(size.width / 2, size.height / 2)
        drawCircle(Gold.copy(alpha = 0.7f * (1f - p)), radius = 3.5.dp.toPx() + p * 6.dp.toPx(), center = c)
        drawCircle(Gold, radius = 3.5.dp.toPx(), center = c)
    }
}

@Composable
private fun PrayerCell(key: String, time: String, past: Boolean, active: Boolean, modifier: Modifier) {
    Column(
        modifier
            .background(
                if (active) Brush.verticalGradient(listOf(Gold.copy(alpha = 0.22f), Gold.copy(alpha = 0.06f)))
                else Brush.verticalGradient(listOf(Bg.copy(alpha = 0.55f), Bg.copy(alpha = 0.55f)))
            )
            .graphicsLayer { alpha = if (past) 0.42f else 1f }
            .padding(vertical = 13.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(Icons.Prayer[key]!!, null, tint = Gold.copy(alpha = 0.75f), modifier = Modifier.size(18.dp))
        Text(
            Prayer.NAMES[key]!!,
            style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.SemiBold, fontSize = 12.sp, color = if (active) Gold else Muted),
            modifier = Modifier.padding(top = 3.dp)
        )
        Text(
            time,
            style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 19.sp, color = TextC),
            modifier = Modifier.padding(top = 1.dp)
        )
    }
}

// ---------- UI-Zustand für Overlays ----------

object Ui {
    var openTab by mutableStateOf<Int?>(null)
    var compose by mutableStateOf<String?>(null)
    var admin by mutableStateOf(false)
    var manage by mutableStateOf(false)
}

private val agoFmt = DateTimeFormatter.ofPattern("d MMMM, HH:mm", Prayer.TR).withZone(Prayer.ZONE)

private fun whenText(i: Instant): String {
    val d = i.atZone(Prayer.ZONE).toLocalDate()
    val today = LocalDate.now(Prayer.ZONE)
    val hm = Prayer.fmt(i)
    return when (d) {
        today -> "Bugün · $hm"
        today.minusDays(1) -> "Dün · $hm"
        else -> agoFmt.format(i)
    }
}

@Composable
private fun WriteButton(label: String, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(GoldGradient)
            .clickable(onClick = onClick),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        Text("＋  $label", style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp, color = Bg))
    }
}

@Composable
private fun EmptyNote(t: String) {
    Text(
        t,
        style = TextStyle(fontFamily = Manrope, fontSize = 14.sp, color = Muted, textAlign = TextAlign.Center),
        modifier = Modifier.fillMaxWidth().glass(RoundedCornerShape(20.dp), elevated = false).padding(vertical = 26.dp, horizontal = 16.dp)
    )
}

@Composable
private fun AnnList(section: String) {
    val list = AppState.list(section)
    if (!AppState.loaded) {
        EmptyNote("Yükleniyor…")
    } else if (list.isEmpty()) {
        EmptyNote(if (section == "cami") "Henüz duyuru yok." else "Henüz gençlik duyurusu yok.")
    }
    list.forEachIndexed { i, a ->
        FadeUp(minOf(i, 4) * 80) { AnnCard(a) }
        Spacer(Modifier.height(12.dp))
    }
}

// ---------- 2) Duyurular ----------

@Composable
fun DuyurularPage() {
    PageColumn {
        SectionHead("Duyurular", "Güncel")
        if (AppState.isAdmin("cami")) {
            WriteButton("Duyuru yaz") { Ui.compose = "cami" }
            Spacer(Modifier.height(14.dp))
        }
        AnnList("cami")
    }
}

@Composable
private fun AnnCard(a: Ann) {
    val scope = rememberCoroutineScope()
    val ctx = LocalContext.current
    var confirm by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().glass(RoundedCornerShape(20.dp))) {
        if (a.photo != null) {
            RemoteImage(a.photo, Modifier.fillMaxWidth().aspectRatio(16f / 10f))
        }
        Box(Modifier.fillMaxWidth()) {
            Box(
                Modifier
                    .padding(top = 18.dp)
                    .width(3.dp)
                    .height(60.dp)
                    .clip(RoundedCornerShape(3.dp))
                    .background(Brush.verticalGradient(listOf(Gold, Color.Transparent)))
            )
            Column(Modifier.padding(start = 20.dp, end = 18.dp, top = 18.dp, bottom = 16.dp)) {
                Text(
                    whenText(a.createdAt).uppercase(Prayer.TR),
                    style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 11.sp, color = Gold, letterSpacing = 1.6.sp)
                )
                if (a.title.isNotBlank()) {
                    Text(
                        a.title,
                        style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 17.sp, color = TextC),
                        modifier = Modifier.padding(top = 5.dp, bottom = 4.dp)
                    )
                }
                Text(a.body, style = TextStyle(fontFamily = Manrope, fontSize = 15.sp, color = Muted, lineHeight = 22.sp))
                if (AppState.isAdmin(a.section)) {
                    Row(Modifier.fillMaxWidth().padding(top = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            "Yayınlayan: ${a.author ?: "-"}",
                            style = TextStyle(fontFamily = Manrope, fontSize = 12.sp, color = Muted.copy(alpha = 0.7f)),
                            modifier = Modifier.weight(1f)
                        )
                        Text(
                            if (confirm) "Emin misiniz? SİL" else "Sil",
                            style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 13.sp, color = ClosedRed),
                            modifier = Modifier
                                .clip(RoundedCornerShape(10.dp))
                                .clickable {
                                    if (!confirm) confirm = true
                                    else scope.launch {
                                        try { AppState.delete(a) } catch (e: Exception) {
                                            Toast.makeText(ctx, "Silinemedi: ${e.message}", Toast.LENGTH_LONG).show()
                                        }
                                        confirm = false
                                    }
                                }
                                .padding(horizontal = 10.dp, vertical = 6.dp)
                        )
                    }
                }
            }
        }
    }
}

// ---------- 3) Lokal ----------

@Composable
fun LokalPage() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val lokalAdmin = AppState.isAdmin("lokal")
    var filter by remember { mutableStateOf("all") }
    var showAll by remember { mutableStateOf(false) }
    val shown = AppState.matches.filter {
        val open = AppState.locks[it.id] == true
        when (filter) {
            "tr" -> AppState.isTurkish(it)
            "sl" -> it.league == "sl"
            "cl" -> it.league == "cl"
            "open" -> open
            else -> true
        }
    }
    val limited = if (showAll) shown else shown.take(12)
    val dayFmt = DateTimeFormatter.ofPattern("d MMMM EEEE", Prayer.TR)
    val today = LocalDate.now(Prayer.ZONE)

    PageColumn {
        FadeUp {
            Column(Modifier.fillMaxWidth().padding(top = 26.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Image(
                    painterResource(R.drawable.logo_genclik), "Gençlik Kolları",
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.fillMaxWidth(0.88f).aspectRatio(992f / 321f)
                )
                Spacer(Modifier.height(16.dp))
                GoldDivider()
            }
        }

        SectionHead("Gençlik", "Duyurular", top = 22)
        if (lokalAdmin) {
            WriteButton("Gençlik duyurusu yaz") { Ui.compose = "lokal" }
            Spacer(Modifier.height(14.dp))
        }
        AnnList("lokal")

        SectionHead("Lokal · Maçlar", "Süper Lig · ŞL", top = 22)
        Row(
            Modifier.fillMaxWidth().glass(RoundedCornerShape(22.dp)).padding(horizontal = 18.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                Modifier
                    .size(44.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(Gold.copy(alpha = 0.12f))
                    .border(1.dp, Line, RoundedCornerShape(14.dp)),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Ball, null, tint = Gold, modifier = Modifier.size(24.dp))
            }
            Spacer(Modifier.width(14.dp))
            Column {
                Text(
                    if (lokalAdmin) "Yönetici: kilide dokunarak lokali açın veya kapatın."
                    else "Maçları gençlerimizle birlikte lokalimizde izliyoruz. Yeşil kilitli maçlarda lokal açık.",
                    style = TextStyle(fontFamily = Manrope, fontSize = 13.5.sp, color = Muted, lineHeight = 19.sp)
                )
                Row(Modifier.padding(top = 6.dp)) {
                    Text("🔓 Açık", style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 12.sp, color = OpenGreen))
                    Spacer(Modifier.width(14.dp))
                    Text("🔒 Kapalı", style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 12.sp, color = ClosedRed))
                }
            }
        }
        Row(
            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(top = 14.dp, bottom = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            listOf("all" to "Tümü", "tr" to "Türk takımları", "sl" to "Süper Lig", "cl" to "Şampiyonlar Ligi", "open" to "🔓 Lokal açık")
                .forEach { (k, l) -> Chip(l, filter == k) { filter = k; showAll = false } }
        }
        when {
            AppState.matchesLoading && AppState.matches.isEmpty() -> EmptyNote("Maçlar yükleniyor…")
            AppState.matchesError != null && AppState.matches.isEmpty() -> EmptyNote(AppState.matchesError!!)
            shown.isEmpty() -> EmptyNote(if (filter == "open") "Şu an lokal açık olarak işaretlenmiş maç yok." else "Önümüzdeki günlerde maç bulunamadı.")
        }
        var last: LocalDate? = null
        limited.forEach { m ->
            val d = m.date.atZone(Prayer.ZONE).toLocalDate()
            if (d != last) {
                last = d
                val title = when (d) {
                    today -> "Bugün"
                    today.plusDays(1) -> "Yarın"
                    else -> dayFmt.format(d)
                }
                Text(
                    title.uppercase(Prayer.TR),
                    style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 11.5.sp, color = Gold, letterSpacing = 2.sp),
                    modifier = Modifier.padding(start = 4.dp, top = 16.dp, bottom = 8.dp)
                )
            }
            val open = AppState.locks[m.id] == true
            MatchRow(m, open) {
                if (lokalAdmin) {
                    scope.launch {
                        try {
                            AppState.setLock(m, !open)
                            Toast.makeText(ctx, if (!open) "🔓 Lokal açıldı" else "🔒 Lokal kapatıldı", Toast.LENGTH_SHORT).show()
                        } catch (e: Exception) {
                            Toast.makeText(ctx, "Kaydedilemedi: ${e.message}", Toast.LENGTH_LONG).show()
                        }
                    }
                } else {
                    Toast.makeText(
                        ctx,
                        if (open) "🔓 Bu maçta lokal açık – herkesi bekliyoruz!" else "🔒 Lokal bu maç için henüz açık değil",
                        Toast.LENGTH_SHORT
                    ).show()
                }
            }
            Spacer(Modifier.height(8.dp))
        }
        if (shown.size > limited.size) {
            Text(
                "Tüm maçları göster (${shown.size})",
                style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = Gold, textAlign = TextAlign.Center),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 6.dp)
                    .clip(RoundedCornerShape(50))
                    .border(1.dp, Line, RoundedCornerShape(50))
                    .clickable { showAll = true }
                    .padding(vertical = 10.dp)
            )
        }
    }
}

@Composable
private fun Chip(label: String, on: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(50)
    Text(
        label,
        style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, color = if (on) Bg else Muted),
        modifier = Modifier
            .clip(shape)
            .background(if (on) GoldGradient else Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.04f), Color.White.copy(alpha = 0.04f))))
            .border(1.dp, if (on) Color.Transparent else Line, shape)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp)
    )
}

@Composable
private fun MatchRow(m: MatchItem, open: Boolean, onToggle: () -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    val border by animateColorAsState(if (open) OpenGreen.copy(alpha = 0.45f) else Line, tween(300), label = "b")
    val tr = AppState.isTurkish(m)
    Row(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Brush.linearGradient(listOf(Color.White.copy(alpha = 0.07f), Color.White.copy(alpha = 0.02f))))
            .border(1.dp, border, shape)
            .padding(start = 14.dp, end = 10.dp, top = 12.dp, bottom = 12.dp)
            .height(IntrinsicSize.Min),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.width(60.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            when (m.state) {
                "in" -> {
                    Text("CANLI", style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.ExtraBold, fontSize = 12.sp, color = OpenGreen))
                    Text(m.clock, style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 12.sp, color = TextC))
                }
                "post" -> Text("Bitti", style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 12.sp, color = Muted))
                else -> Text(Prayer.fmt(m.date), style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 16.sp, color = TextC))
            }
            val sl = m.league == "sl"
            Text(
                if (sl) "SÜPER LİG" else "ŞL",
                style = TextStyle(
                    fontFamily = Manrope, fontWeight = FontWeight.ExtraBold, fontSize = 9.sp,
                    color = if (sl) Color(0xFFFF8A8A) else Color(0xFFA9C1FF)
                ),
                modifier = Modifier
                    .padding(top = 3.dp)
                    .background(if (sl) Color(0x2EE31E24) else Color(0x2E608CFF), RoundedCornerShape(6.dp))
                    .padding(horizontal = 5.dp, vertical = 2.dp)
            )
        }
        Box(Modifier.width(1.dp).fillMaxHeight().background(Line))
        Column(Modifier.weight(1f).padding(start = 12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            TeamLine(m.home, AppState.turkishTeams[m.home.id] == true && tr, m.state != "pre")
            TeamLine(m.away, AppState.turkishTeams[m.away.id] == true && tr, m.state != "pre")
        }
        LockButton(open, onToggle)
    }
}

@Composable
private fun TeamLine(t: Team, tr: Boolean, showScore: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        if (t.logo.isNotBlank()) {
            RemoteImage(t.logo, Modifier.size(22.dp), contentScale = ContentScale.Fit, maxSize = 96)
        } else {
            Box(
                Modifier.size(22.dp).clip(CircleShape).background(Gold.copy(alpha = 0.12f)).border(1.dp, Line, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Text(t.name.take(1), style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 11.sp, color = Gold))
            }
        }
        Spacer(Modifier.width(8.dp))
        Text(
            if (tr) "${t.name} 🇹🇷" else t.name,
            maxLines = 1, overflow = TextOverflow.Ellipsis,
            style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, color = if (tr) Color.White else TextC),
            modifier = Modifier.weight(1f)
        )
        if (showScore && t.score != null) {
            Text(t.score, style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, color = Gold))
        }
    }
}

@Composable
private fun LockButton(open: Boolean, onClick: () -> Unit) {
    val color = if (open) OpenGreen else ClosedRed
    val shape = RoundedCornerShape(14.dp)
    Column(
        Modifier
            .width(60.dp)
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            Modifier
                .size(42.dp)
                .drawBehind {
                    if (open) drawCircle(
                        Brush.radialGradient(listOf(OpenGreen.copy(alpha = 0.35f), Color.Transparent)),
                        radius = size.width * 0.9f
                    )
                }
                .clip(shape)
                .background(color.copy(alpha = if (open) 0.16f else 0.14f))
                .border(1.dp, color.copy(alpha = if (open) 0.55f else 0.4f), shape),
            contentAlignment = Alignment.Center
        ) {
            Icon(if (open) Icons.LockOpen else Icons.LockClosed, null, tint = color, modifier = Modifier.size(22.dp))
        }
        Text(
            if (open) "AÇIK" else "KAPALI",
            style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 9.5.sp, color = color, letterSpacing = 0.5.sp),
            modifier = Modifier.padding(top = 3.dp)
        )
    }
}

// ---------- 4) Hakkımızda ----------

@Composable
fun HakkimizdaPage() {
    val years = LocalDate.now(Prayer.ZONE).year - 1982
    PageColumn {
        SectionHead("Hakkımızda", "Merkez Camii")
        FadeUp {
            Column(
                Modifier.fillMaxWidth().glass().padding(horizontal = 22.dp, vertical = 26.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                var taps by remember { mutableStateOf(0) }
                var lastTap by remember { mutableStateOf(0L) }
                Text(
                    "1982",
                    style = TextStyle(fontFamily = Marcellus, fontSize = 64.sp, brush = GoldGradient, lineHeight = 64.sp),
                    modifier = Modifier.clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {
                        val now = System.currentTimeMillis()
                        taps = if (now - lastTap < 1200) taps + 1 else 1
                        lastTap = now
                        if (taps >= 5) { taps = 0; Ui.admin = true }
                    }
                )
                Text(
                    "YILINDAN BERİ HİZMETİNİZDE",
                    style = TextStyle(fontFamily = Manrope, fontSize = 11.5.sp, color = Muted, letterSpacing = 3.sp),
                    modifier = Modifier.padding(top = 6.dp, bottom = 16.dp)
                )
                Text(
                    "Merkez Camii, Muslimgemeinde Vilsbiburg e.V. çatısı altında Vilsbiburg ve çevresindeki Müslümanlara hizmet vermektedir.",
                    style = TextStyle(fontFamily = Manrope, fontSize = 15.sp, color = TextC.copy(alpha = 0.82f), textAlign = TextAlign.Center, lineHeight = 23.sp)
                )
                Text(
                    "Camimiz beş vakit namaz, Cuma ve bayram namazları, Kuran kursları ve cemaat buluşmaları için herkese açıktır.",
                    style = TextStyle(fontFamily = Manrope, fontSize = 15.sp, color = TextC.copy(alpha = 0.82f), textAlign = TextAlign.Center, lineHeight = 23.sp),
                    modifier = Modifier.padding(top = 10.dp)
                )
                Row(Modifier.fillMaxWidth().padding(top = 20.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Stat("$years", "yıllık hizmet", Modifier.weight(1f))
                    Stat("5", "vakit namaz", Modifier.weight(1f))
                    Stat("Cuma", "& bayram", Modifier.weight(1f))
                }
            }
        }
        Column(Modifier.fillMaxWidth().padding(top = 44.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text("السَّلَامُ عَلَيْكُمْ", style = TextStyle(fontFamily = Amiri, fontSize = 20.sp, color = Gold))
            Text(
                "Merkez Camii Vilsbiburg",
                style = TextStyle(fontFamily = Marcellus, fontSize = 15.sp, color = TextC, letterSpacing = 1.sp),
                modifier = Modifier.padding(top = 8.dp)
            )
            Text(
                "© ${LocalDate.now(Prayer.ZONE).year} Muslimgemeinde Vilsbiburg e.V.",
                style = TextStyle(fontFamily = Manrope, fontSize = 13.sp, color = Muted),
                modifier = Modifier.padding(top = 2.dp)
            )
            Text(
                "Ezan kayıtları: sazman, RJStefanski (freesound.org, CC BY)",
                style = TextStyle(fontFamily = Manrope, fontSize = 10.5.sp, color = Muted.copy(alpha = 0.5f), textAlign = TextAlign.Center),
                modifier = Modifier.padding(top = 10.dp)
            )
            Text(
                "Sürüm 0.7",
                style = TextStyle(fontFamily = Manrope, fontSize = 11.sp, color = Muted.copy(alpha = 0.5f)),
                modifier = Modifier.padding(top = 10.dp)
            )
        }
    }
}

@Composable
private fun Stat(big: String, small: String, modifier: Modifier) {
    Column(
        modifier
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.03f))
            .border(1.dp, Line, RoundedCornerShape(16.dp))
            .padding(vertical = 14.dp, horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(big, style = TextStyle(fontFamily = Marcellus, fontSize = 20.sp, color = Gold))
        Text(small, style = TextStyle(fontFamily = Manrope, fontSize = 12.sp, color = Muted))
    }
}


// ---------- Ezan-Einstellungen (unter den Vakitler) ----------

@Composable
fun EzanSettingsCard() {
    val ctx = LocalContext.current
    LaunchedEffect(Unit) { EzanSettings.load(ctx) }
    var open by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().padding(top = 18.dp).glass(RoundedCornerShape(22.dp))) {
        Row(
            Modifier.fillMaxWidth().clickable { open = !open }.padding(horizontal = 18.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("🔊", style = TextStyle(fontSize = 18.sp))
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text("Ezan ve bildirim ayarları", style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 15.sp, color = TextC))
                val off = EzanSettings.KEYS.count { (EzanSettings.modes[it] ?: "ezan") != "ezan" }
                Text(
                    if (off == 0) "Tüm vakitlerde ezan açık" else "Bazı vakitlerde ezan kapalı",
                    style = TextStyle(fontFamily = Manrope, fontSize = 12.sp, color = Muted)
                )
            }
            Text(if (open) "▲" else "▼", style = TextStyle(fontSize = 13.sp, color = Gold))
        }
        if (open) {
            Box(Modifier.fillMaxWidth().height(1.dp).background(Line))
            Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                EzanSettings.KEYS.forEach { k ->
                    val m = EzanSettings.modes[k] ?: "ezan"
                    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(EzanSettings.LABELS[k]!!, style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = TextC), modifier = Modifier.width(62.dp))
                        Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            ModeChip("Ezan", m == "ezan", Modifier.weight(1f)) { EzanSettings.setMode(ctx, k, "ezan") }
                            ModeChip("Bildirim", m == "bildirim", Modifier.weight(1f)) { EzanSettings.setMode(ctx, k, "bildirim") }
                            ModeChip("Kapalı", m == "kapali", Modifier.weight(1f)) { EzanSettings.setMode(ctx, k, "kapali") }
                        }
                    }
                }
                Box(Modifier.fillMaxWidth().padding(vertical = 8.dp).height(1.dp).background(Line))
                ToggleRow("Cuma hatırlatması", "Cuma günü öğleden 45 dk önce", EzanSettings.cuma) { EzanSettings.setCuma(ctx, it) }
                ToggleRow("Sessiz modda da ezan oku", "Kapalıyken telefon sessizdeyse sadece bildirim gelir", EzanSettings.silentToo) { EzanSettings.setSilentToo(ctx, it) }
                Text(
                    "Ezan çalarken bildirimdeki \"Ezanı durdur\" ile susturabilirsiniz.",
                    style = TextStyle(fontFamily = Manrope, fontSize = 11.5.sp, color = Muted),
                    modifier = Modifier.padding(top = 8.dp)
                )
            }
        }
    }
}

@Composable
private fun ModeChip(label: String, on: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(12.dp)
    Text(
        label,
        maxLines = 1,
        style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 12.sp, color = if (on) Bg else Muted, textAlign = TextAlign.Center),
        modifier = modifier
            .clip(shape)
            .background(if (on) GoldGradient else Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.04f), Color.White.copy(alpha = 0.04f))))
            .border(1.dp, if (on) Color.Transparent else Line, shape)
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp)
    )
}

@Composable
private fun ToggleRow(title: String, sub: String, on: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable { onChange(!on) }.padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = TextC))
            Text(sub, style = TextStyle(fontFamily = Manrope, fontSize = 11.5.sp, color = Muted))
        }
        Spacer(Modifier.width(10.dp))
        Box(
            Modifier
                .width(46.dp)
                .height(26.dp)
                .clip(RoundedCornerShape(50))
                .background(if (on) GoldGradient else Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.12f), Color.White.copy(alpha = 0.12f)))),
            contentAlignment = if (on) Alignment.CenterEnd else Alignment.CenterStart
        ) {
            Box(Modifier.padding(3.dp).size(20.dp).clip(CircleShape).background(if (on) Bg else TextC))
        }
    }
}
