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
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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

// ---------- 2) Duyurular ----------

private data class News(val day: String, val title: String, val text: String, val photo: String? = null)

private val NEWS = listOf(
    News(
        "Cumartesi", "Hayır çarşısı (Kermes)",
        "Cumartesi günü camimizin bahçesinde hayır çarşımız var. Gözlemeler, tatlılar ve çay sizi bekliyor. Tüm cemaatimiz ailesiyle davetlidir.",
        photo = "Kermes"
    ),
    News("Her Cuma", "Cuma Namazı", "Cuma namazına tüm cemaatimiz davetlidir. Hutbe öğle vaktinde başlar."),
    News(
        "Hafta sonu", "Çocuklar için Kuran kursu",
        "Cumartesi ve pazar günleri çocuklarımız için Kuran ve din dersi verilmektedir. Kayıt için cami yönetimine başvurabilirsiniz."
    ),
    News("Duyuru", "Cemaat sohbeti", "Yatsı namazından sonra camimizde sohbet düzenlenecektir. Herkes davetlidir."),
)

@Composable
fun DuyurularPage() {
    PageColumn {
        SectionHead("Duyurular", "Güncel")
        NEWS.forEachIndexed { i, n ->
            FadeUp(i * 90) { NewsCard(n) }
            Spacer(Modifier.height(12.dp))
        }
    }
}

@Composable
private fun NewsCard(n: News) {
    Column(Modifier.fillMaxWidth().glass(RoundedCornerShape(20.dp))) {
        if (n.photo != null) DemoPhoto(n.photo)
        Box(Modifier.fillMaxWidth()) {
            Box(
                Modifier
                    .padding(top = 18.dp)
                    .width(3.dp)
                    .height(60.dp)
                    .clip(RoundedCornerShape(3.dp))
                    .background(Brush.verticalGradient(listOf(Gold, Color.Transparent)))
            )
            Column(Modifier.padding(start = 20.dp, end = 18.dp, top = 18.dp, bottom = 18.dp)) {
                Text(
                    n.day.uppercase(Prayer.TR),
                    style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 11.sp, color = Gold, letterSpacing = 1.8.sp)
                )
                Row(Modifier.padding(top = 5.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        n.title,
                        style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 17.sp, color = TextC),
                        modifier = Modifier.weight(1f, fill = false)
                    )
                    Spacer(Modifier.width(8.dp))
                    DemoTag()
                }
                Text(n.text, style = TextStyle(fontFamily = Manrope, fontSize = 15.sp, color = Muted, lineHeight = 22.sp))
            }
        }
    }
}

/** Platzhalter-"Foto" im Design der App (im echten Betrieb: Foto vom Verwalter). */
@Composable
private fun DemoPhoto(caption: String) {
    Box(
        Modifier
            .fillMaxWidth()
            .aspectRatio(16f / 8.5f)
            .background(
                Brush.linearGradient(listOf(Color(0xFF1B4D3A), Color(0xFF0B2A20), Color(0xFF3A2E14)))
            ),
        contentAlignment = Alignment.Center
    ) {
        Canvas(Modifier.fillMaxSize()) {
            val step = 34.dp.toPx()
            var x = -size.height
            while (x < size.width) {
                drawLine(Gold.copy(alpha = 0.08f), Offset(x, size.height), Offset(x + size.height, 0f), 1.dp.toPx())
                x += step
            }
            drawCircle(
                Brush.radialGradient(listOf(Gold.copy(alpha = 0.30f), Color.Transparent), center = Offset(size.width * 0.7f, size.height * 0.3f), radius = size.width * 0.5f),
                radius = size.width * 0.5f, center = Offset(size.width * 0.7f, size.height * 0.3f)
            )
        }
        Image(
            painterResource(R.drawable.logo_dome), null,
            contentScale = ContentScale.Fit,
            modifier = Modifier.fillMaxWidth(0.5f).graphicsLayer { alpha = 0.22f }
        )
        Row(
            Modifier
                .align(Alignment.BottomStart)
                .padding(12.dp)
                .background(Color.Black.copy(alpha = 0.35f), RoundedCornerShape(10.dp))
                .padding(horizontal = 10.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Camera, null, tint = Gold, modifier = Modifier.size(15.dp))
            Spacer(Modifier.width(6.dp))
            Text("Örnek fotoğraf · $caption", style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.SemiBold, fontSize = 11.sp, color = TextC))
        }
    }
}

// ---------- 3) Lokal ----------

private class Match(
    val id: Int, val dayOffset: Long, val time: String, val league: String,
    val home: String, val away: String, val homeTr: Boolean, val awayTr: Boolean, open: Boolean
) {
    var open by mutableStateOf(open)
    val turkish get() = homeTr || awayTr
}

private val ACTIVITIES = listOf(
    News("Her Pazar", "Halı saha maçı", "Pazar günleri öğleden sonra gençlerimizle halı sahada buluşuyoruz. Katılmak isteyen herkes gelebilir."),
    News("Cuma akşamı", "Gençlik sohbeti", "Yatsı namazından sonra lokalimizde çay eşliğinde gençlik sohbeti."),
    News("Ayın sonu", "PlayStation turnuvası", "Lokalimizde FIFA turnuvası düzenliyoruz. Kayıt lokalde yapılır."),
)

@Composable
fun LokalPage() {
    val ctx = LocalContext.current
    val matches = remember {
        mutableStateListOf(
            Match(1, 0, "19:00", "sl", "Galatasaray", "Fenerbahçe", true, true, true),
            Match(2, 0, "21:45", "sl", "Beşiktaş", "Trabzonspor", true, true, false),
            Match(3, 1, "16:00", "sl", "Samsunspor", "Göztepe", true, true, false),
            Match(4, 1, "19:00", "sl", "Başakşehir", "Kasımpaşa", true, true, false),
            Match(5, 3, "21:00", "cl", "Bayern München", "Galatasaray", false, true, true),
            Match(6, 3, "21:00", "cl", "Arsenal", "PSV", false, false, false),
            Match(7, 4, "18:45", "cl", "Real Madrid", "Juventus", false, false, false),
        )
    }
    var filter by remember { mutableStateOf("all") }
    val shown = matches.filter {
        when (filter) {
            "tr" -> it.turkish
            "sl" -> it.league == "sl"
            "cl" -> it.league == "cl"
            "open" -> it.open
            else -> true
        }
    }
    val today = LocalDate.now(Prayer.ZONE)
    val dayFmt = DateTimeFormatter.ofPattern("d MMMM EEEE", Prayer.TR)

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
        SectionHead("Lokal · Maçlar", "Süper Lig · ŞL", top = 22)
        FadeUp(100) {
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
                        "Maçları gençlerimizle birlikte lokalimizde izliyoruz. Yeşil kilitli maçlarda lokal açık.",
                        style = TextStyle(fontFamily = Manrope, fontSize = 13.5.sp, color = Muted, lineHeight = 19.sp)
                    )
                    Row(Modifier.padding(top = 6.dp)) {
                        Text("🔓 Açık", style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 12.sp, color = OpenGreen))
                        Spacer(Modifier.width(14.dp))
                        Text("🔒 Kapalı", style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 12.sp, color = ClosedRed))
                    }
                }
            }
        }
        Row(
            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(top = 14.dp, bottom = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            listOf("all" to "Tümü", "tr" to "Türk takımları", "sl" to "Süper Lig", "cl" to "Şampiyonlar Ligi", "open" to "🔓 Lokal açık")
                .forEach { (k, l) -> Chip(l, filter == k) { filter = k } }
        }
        if (shown.isEmpty()) {
            Text(
                "Bu filtrede maç yok.",
                style = TextStyle(fontFamily = Manrope, fontSize = 14.sp, color = Muted, textAlign = TextAlign.Center),
                modifier = Modifier.fillMaxWidth().padding(vertical = 26.dp)
            )
        }
        shown.groupBy { it.dayOffset }.toSortedMap().forEach { (off, list) ->
            val d = today.plusDays(off)
            val title = when (off) {
                0L -> "Bugün · " + dayFmt.format(d)
                1L -> "Yarın · " + dayFmt.format(d)
                else -> dayFmt.format(d)
            }
            Text(
                title.uppercase(Prayer.TR),
                style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 11.5.sp, color = Gold, letterSpacing = 2.sp),
                modifier = Modifier.padding(start = 4.dp, top = 16.dp, bottom = 8.dp)
            )
            list.forEach { m ->
                MatchRow(m) {
                    m.open = !m.open
                    Toast.makeText(
                        ctx,
                        if (m.open) "Lokal açık: ${m.home} – ${m.away}" else "Lokal kapalı: ${m.home} – ${m.away}",
                        Toast.LENGTH_SHORT
                    ).show()
                }
                Spacer(Modifier.height(8.dp))
            }
        }
        Text(
            "Demo: kilide dokunarak durumu değiştirebilirsiniz. Gerçek uygulamada bunu sadece yönetici yapar.",
            style = TextStyle(fontFamily = Manrope, fontSize = 11.5.sp, color = Muted, textAlign = TextAlign.Center),
            modifier = Modifier.fillMaxWidth().padding(top = 6.dp)
        )

        SectionHead("Gençlik", "Etkinlikler", top = 34)
        ACTIVITIES.forEach { a ->
            NewsCard(a)
            Spacer(Modifier.height(12.dp))
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
private fun MatchRow(m: Match, onToggle: () -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    val border by animateColorAsState(if (m.open) OpenGreen.copy(alpha = 0.45f) else Line, tween(300), label = "b")
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
            Text(m.time, style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 16.sp, color = TextC))
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
            TeamLine(m.home, m.homeTr)
            TeamLine(m.away, m.awayTr)
        }
        LockButton(m.open, onToggle)
    }
}

@Composable
private fun TeamLine(name: String, tr: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier.size(22.dp).clip(CircleShape).background(Gold.copy(alpha = 0.12f)).border(1.dp, Line, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(
                name.take(1),
                style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 11.sp, color = Gold)
            )
        }
        Spacer(Modifier.width(8.dp))
        Text(
            if (tr) "$name 🇹🇷" else name,
            maxLines = 1, overflow = TextOverflow.Ellipsis,
            style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, color = if (tr) Color.White else TextC)
        )
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
                Text(
                    "1982",
                    style = TextStyle(fontFamily = Marcellus, fontSize = 64.sp, brush = GoldGradient, lineHeight = 64.sp)
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
                "Demo sürümü 0.1",
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

