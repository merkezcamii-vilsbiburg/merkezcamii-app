package de.merkezcamii.vilsbiburg

import android.graphics.Bitmap
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

// ---------- Bild aus dem Netz ----------

@Composable
fun RemoteImage(url: String, modifier: Modifier = Modifier, contentScale: ContentScale = ContentScale.Crop, maxSize: Int = 1400) {
    val bmp by produceState<Bitmap?>(Images.cached(url), url) { value = Images.load(url, maxSize) }
    Box(modifier.background(Color.White.copy(alpha = 0.04f))) {
        bmp?.let {
            Image(it.asImageBitmap(), null, contentScale = contentScale, modifier = Modifier.fillMaxSize())
        }
    }
}

// ---------- Goldenes Zähler-Abzeichen ----------

@Composable
fun GoldBadge(count: Int, modifier: Modifier = Modifier) {
    if (count <= 0) return
    Box(
        modifier
            .heightIn(min = 17.dp)
            .clip(RoundedCornerShape(50))
            .background(GoldGradient)
            .border(1.5.dp, Bg, RoundedCornerShape(50))
            .padding(horizontal = 5.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            if (count > 9) "9+" else "$count",
            style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.ExtraBold, fontSize = 10.sp, color = Bg)
        )
    }
}

// ---------- Großer Gold-Knopf ----------

@Composable
fun BigButton(text: String, enabled: Boolean = true, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier
            .fillMaxWidth()
            .height(62.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(if (enabled) GoldGradient else Brush.verticalGradient(listOf(Color(0xFF3A3A30), Color(0xFF2C2C24))))
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(text, style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp, color = if (enabled) Bg else Muted, letterSpacing = 2.sp))
    }
}

@Composable
fun SmallGoldButton(text: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier
            .fillMaxWidth()
            .height(52.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(GoldGradient)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(text, style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, color = Bg))
    }
}

// ---------- Vollbild-Ebene (dunkler Hintergrund) ----------

@Composable
private fun Overlay(onClose: () -> Unit, content: @Composable () -> Unit) {
    BackHandler { onClose() }
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.6f))
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { }
    ) {
        BrandBackground()
        content()
    }
}

@Composable
private fun OverlayHeader(title: String, onClose: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 18.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, style = TextStyle(fontFamily = Marcellus, fontSize = 25.sp, color = TextC), modifier = Modifier.weight(1f))
        Box(
            Modifier.size(44.dp).clip(CircleShape).border(1.dp, Line, CircleShape).clickable(onClick = onClose),
            contentAlignment = Alignment.Center
        ) {
            Text("✕", style = TextStyle(fontSize = 18.sp, color = TextC))
        }
    }
}

// ---------- Yönetici-Girişi / Panel ----------

@Composable
fun AdminGate(onClose: () -> Unit) {
    val scope = rememberCoroutineScope()
    var pin by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    val focus = remember { FocusRequester() }

    Overlay(onClose) {
        Column(
            Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .windowInsetsPadding(WindowInsets.ime)
                .padding(horizontal = 22.dp)
                .verticalScroll(rememberScrollState())
        ) {
            OverlayHeader("Yönetici", onClose)
            val name = AppState.adminName
            if (name != null) {
                Column(Modifier.fillMaxWidth().glass().padding(22.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Giriş yapıldı", style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 12.sp, color = Gold, letterSpacing = 2.sp))
                    Text(name, style = TextStyle(fontFamily = Marcellus, fontSize = 28.sp, color = TextC), modifier = Modifier.padding(top = 6.dp))
                    val roles = buildList {
                        if (AppState.isAdmin("cami")) add("Cami duyuruları")
                        if (AppState.isAdmin("lokal")) add("Lokal (duyurular ve kilitler)")
                    }
                    roles.forEach {
                        Text("✓ $it", style = TextStyle(fontFamily = Manrope, fontSize = 15.sp, color = Muted), modifier = Modifier.padding(top = 6.dp))
                    }
                    if (Config.demo) {
                        Text("Demo modu: veriler sadece bu telefonda.", style = TextStyle(fontFamily = Manrope, fontSize = 12.sp, color = Muted), modifier = Modifier.padding(top = 12.dp))
                    }
                }
                Spacer(Modifier.height(20.dp))
                SmallGoldButton("Tamam") { onClose() }
                Spacer(Modifier.height(12.dp))
                Text(
                    "Çıkış yap",
                    style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, color = ClosedRed, textAlign = TextAlign.Center),
                    modifier = Modifier.fillMaxWidth().clickable { AppState.logout(); onClose() }.padding(12.dp)
                )
            } else {
                LaunchedEffect(Unit) { delay(300); focus.requestFocus() }
                Text(
                    "Yönetici PIN'inizi girin",
                    style = TextStyle(fontFamily = Manrope, fontSize = 16.sp, color = Muted, textAlign = TextAlign.Center),
                    modifier = Modifier.fillMaxWidth().padding(top = 20.dp, bottom = 14.dp)
                )
                BasicTextField(
                    value = pin,
                    onValueChange = { v -> pin = v.filter { it.isDigit() }.take(8); error = null },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation('●'),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                    textStyle = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 34.sp, color = TextC, textAlign = TextAlign.Center, letterSpacing = 8.sp),
                    cursorBrush = SolidColor(Gold),
                    modifier = Modifier
                        .fillMaxWidth()
                        .focusRequester(focus)
                        .glass(RoundedCornerShape(20.dp), elevated = false)
                        .padding(vertical = 18.dp)
                )
                error?.let {
                    Text(it, style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, color = ClosedRed, textAlign = TextAlign.Center),
                        modifier = Modifier.fillMaxWidth().padding(top = 12.dp))
                }
                Spacer(Modifier.height(22.dp))
                BigButton(if (busy) "…" else "GİRİŞ", enabled = pin.length >= 4 && !busy) {
                    busy = true
                    scope.launch {
                        try {
                            AppState.login(pin)
                        } catch (e: Exception) {
                            error = if (e is ApiError) (e.message ?: "PIN yanlış") else "İnternet bağlantısı yok"
                            pin = ""
                        }
                        busy = false
                    }
                }
                if (Config.demo) {
                    Text("Demo PIN: 1234", style = TextStyle(fontFamily = Manrope, fontSize = 13.sp, color = Muted, textAlign = TextAlign.Center),
                        modifier = Modifier.fillMaxWidth().padding(top = 14.dp))
                }
            }
        }
    }
}

// ---------- Duyuru yazen ----------

@Composable
fun ComposeScreen(section: String, onClose: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var title by remember { mutableStateOf("") }
    var body by remember { mutableStateOf("") }
    var photo by remember { mutableStateOf<ByteArray?>(null) }
    var preview by remember { mutableStateOf<Bitmap?>(null) }
    var busy by remember { mutableStateOf(false) }
    var done by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) scope.launch {
            try {
                val bytes = withContext(Dispatchers.IO) { Images.prepareUpload(ctx, uri) }
                photo = bytes
                preview = withContext(Dispatchers.IO) { Images.previewBitmap(bytes) }
            } catch (e: Exception) {
                error = "Fotoğraf eklenemedi"
            }
        }
    }

    Overlay(onClose) {
        if (done) {
            LaunchedEffect(Unit) { delay(1600); onClose() }
            Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                Box(
                    Modifier.size(110.dp).clip(CircleShape).background(GoldGradient),
                    contentAlignment = Alignment.Center
                ) {
                    Text("✓", style = TextStyle(fontSize = 56.sp, color = Bg, fontWeight = FontWeight.Bold))
                }
                Text("Gönderildi", style = TextStyle(fontFamily = Marcellus, fontSize = 32.sp, color = TextC), modifier = Modifier.padding(top = 22.dp))
            }
            return@Overlay
        }
        Column(
            Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .windowInsetsPadding(WindowInsets.ime)
                .padding(horizontal = 20.dp)
                .verticalScroll(rememberScrollState())
        ) {
            OverlayHeader(if (section == "cami") "Cami duyurusu" else "Gençlik duyurusu", onClose)

            FieldLabel("Başlık")
            BigField(title, { title = it }, "Örn: Kermes", singleLine = true, minHeight = 60)
            Spacer(Modifier.height(16.dp))
            FieldLabel("Duyuru")
            BigField(body, { body = it }, "Duyurunuzu yazın…", singleLine = false, minHeight = 170)
            Spacer(Modifier.height(16.dp))

            if (preview != null) {
                Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp))) {
                    Image(preview!!.asImageBitmap(), null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxWidth().aspectRatio(16f / 10f))
                    Box(
                        Modifier.align(Alignment.TopEnd).padding(10.dp).size(40.dp).clip(CircleShape)
                            .background(Color.Black.copy(alpha = 0.55f)).clickable { photo = null; preview = null },
                        contentAlignment = Alignment.Center
                    ) { Text("✕", style = TextStyle(fontSize = 17.sp, color = Color.White)) }
                }
            } else {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .height(64.dp)
                        .glass(RoundedCornerShape(20.dp), elevated = false)
                        .clickable { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center
                ) {
                    Icon(Icons.Camera, null, tint = Gold, modifier = Modifier.size(26.dp))
                    Spacer(Modifier.width(10.dp))
                    Text("Fotoğraf ekle", style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 18.sp, color = TextC))
                }
            }

            error?.let {
                Text(it, style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, color = ClosedRed, textAlign = TextAlign.Center),
                    modifier = Modifier.fillMaxWidth().padding(top = 14.dp))
            }
            Spacer(Modifier.height(22.dp))
            BigButton(if (busy) "GÖNDERİLİYOR…" else "YAYINLA", enabled = body.isNotBlank() && !busy) {
                busy = true; error = null
                val t = title.trim().ifEmpty { body.trim().lineSequence().first().take(60) }
                scope.launch {
                    try {
                        AppState.post(section, t, body.trim(), photo)
                        done = true
                    } catch (e: Exception) {
                        error = if (e is ApiError) "Gönderilemedi: ${e.message}" else "Gönderilemedi. İnternet bağlantınızı kontrol edin."
                    }
                    busy = false
                }
            }
            Spacer(Modifier.height(30.dp))
        }
    }
}

@Composable
private fun FieldLabel(t: String) {
    Text(t.uppercase(Prayer.TR), style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 12.sp, color = Gold, letterSpacing = 2.sp),
        modifier = Modifier.padding(start = 4.dp, bottom = 8.dp))
}

@Composable
private fun BigField(value: String, onChange: (String) -> Unit, hint: String, singleLine: Boolean, minHeight: Int) {
    BasicTextField(
        value = value,
        onValueChange = onChange,
        singleLine = singleLine,
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
        textStyle = TextStyle(fontFamily = Manrope, fontSize = 19.sp, color = TextC, lineHeight = 27.sp),
        cursorBrush = SolidColor(Gold),
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = minHeight.dp)
            .glass(RoundedCornerShape(20.dp), elevated = false)
            .padding(horizontal = 18.dp, vertical = 16.dp),
        decorationBox = { inner ->
            Box {
                if (value.isEmpty()) Text(hint, style = TextStyle(fontFamily = Manrope, fontSize = 19.sp, color = Muted.copy(alpha = 0.5f)))
                inner()
            }
        }
    )
}
