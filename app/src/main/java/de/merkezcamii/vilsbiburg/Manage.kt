package de.merkezcamii.vilsbiburg

import androidx.activity.compose.BackHandler
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
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

data class AdminEntry(val id: Long, val name: String, val roles: List<String>)

object ManageApi {
    private fun arr(l: List<String>) = JSONArray().apply { l.forEach { put(it) } }

    suspend fun list(): List<AdminEntry> = withContext(Dispatchers.IO) {
        val o = JSONObject(Backend.rpc("admin_list", JSONObject().put("p_pin", AppState.pin())))
        val a = o.getJSONArray("admins")
        (0 until a.length()).map { i ->
            val x = a.getJSONObject(i)
            val r = x.getJSONArray("roles")
            AdminEntry(x.getLong("id"), x.getString("name"), (0 until r.length()).map { r.getString(it) })
        }
    }

    /** Gibt (Name, neue PIN) zurück. */
    suspend fun add(name: String, roles: List<String>): Pair<String, String> = withContext(Dispatchers.IO) {
        val o = JSONObject(Backend.rpc("admin_add", JSONObject().put("p_pin", AppState.pin()).put("p_name", name).put("p_roles", arr(roles))))
        o.getString("name") to o.getString("pin")
    }

    suspend fun remove(id: Long) = withContext(Dispatchers.IO) {
        Backend.rpc("admin_remove", JSONObject().put("p_pin", AppState.pin()).put("p_id", id)); Unit
    }

    suspend fun resetPin(id: Long): Pair<String, String> = withContext(Dispatchers.IO) {
        val o = JSONObject(Backend.rpc("admin_reset_pin", JSONObject().put("p_pin", AppState.pin()).put("p_id", id)))
        o.getString("name") to o.getString("pin")
    }

    suspend fun setRoles(id: Long, roles: List<String>) = withContext(Dispatchers.IO) {
        Backend.rpc("admin_set_roles", JSONObject().put("p_pin", AppState.pin()).put("p_id", id).put("p_roles", arr(roles))); Unit
    }
}

private fun roleText(r: List<String>) = buildList {
    if ("super" in r) add("Ana yönetici")
    if ("cami" in r) add("Cami")
    if ("lokal" in r) add("Lokal")
}.joinToString(" · ")

/** Nur für Kerim (Rolle "super"): Yöneticiler verwalten. */
@Composable
fun ManageScreen(onClose: () -> Unit) {
    BackHandler { onClose() }
    val scope = rememberCoroutineScope()
    val admins = remember { mutableStateListOf<AdminEntry>() }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var newName by remember { mutableStateOf("") }
    var newCami by remember { mutableStateOf(false) }
    var newLokal by remember { mutableStateOf(true) }
    var busy by remember { mutableStateOf(false) }
    var shownPin by remember { mutableStateOf<Pair<String, String>?>(null) }
    var confirmDelete by remember { mutableStateOf<Long?>(null) }

    suspend fun reload() {
        try {
            val l = ManageApi.list()
            admins.clear(); admins.addAll(l); error = null
        } catch (e: Exception) {
            error = e.message ?: "Yüklenemedi"
        }
        loading = false
    }
    LaunchedEffect(Unit) { reload() }

    fun act(block: suspend () -> Unit) {
        if (busy) return
        busy = true
        scope.launch {
            try { block(); reload() } catch (e: Exception) { error = e.message ?: "Hata" }
            busy = false
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { }
    ) {
        BrandBackground()
        Column(
            Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .windowInsetsPadding(WindowInsets.ime)
                .padding(horizontal = 20.dp)
                .verticalScroll(rememberScrollState())
        ) {
            Row(Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 18.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Yöneticiler", style = TextStyle(fontFamily = Marcellus, fontSize = 25.sp, color = TextC), modifier = Modifier.weight(1f))
                Box(
                    Modifier.size(44.dp).clip(CircleShape).border(1.dp, Line, CircleShape).clickable(onClick = onClose),
                    contentAlignment = Alignment.Center
                ) { Text("✕", style = TextStyle(fontSize = 18.sp, color = TextC)) }
            }

            // Neue PIN anzeigen
            shownPin?.let { (name, pin) ->
                Column(
                    Modifier.fillMaxWidth().glass().padding(22.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text("$name için PIN", style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 14.sp, color = Gold))
                    Text(pin, style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.ExtraBold, fontSize = 44.sp, color = TextC, letterSpacing = 6.sp), modifier = Modifier.padding(vertical = 8.dp))
                    Text(
                        "Bu PIN'i $name'e iletin. Güvenlik için tekrar gösterilmez.",
                        style = TextStyle(fontFamily = Manrope, fontSize = 13.sp, color = Muted, textAlign = TextAlign.Center)
                    )
                    Spacer(Modifier.height(14.dp))
                    SmallGoldButton("Tamam, not aldım") { shownPin = null }
                }
                Spacer(Modifier.height(18.dp))
            }

            error?.let {
                Text(it, style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = ClosedRed, textAlign = TextAlign.Center),
                    modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp))
            }

            // Liste
            if (loading) {
                Text("Yükleniyor…", style = TextStyle(fontFamily = Manrope, fontSize = 14.sp, color = Muted))
            }
            admins.forEach { a ->
                val self = "super" in a.roles
                Column(Modifier.fillMaxWidth().glass(RoundedCornerShape(20.dp)).padding(16.dp)) {
                    Text(a.name, style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 18.sp, color = TextC))
                    Text(roleText(a.roles), style = TextStyle(fontFamily = Manrope, fontSize = 13.sp, color = Gold), modifier = Modifier.padding(top = 2.dp))
                    if (!self) {
                        Row(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            RoleChip("Cami", "cami" in a.roles) {
                                val r = a.roles.toMutableSet().apply { if ("cami" in this) remove("cami") else add("cami") }
                                act { ManageApi.setRoles(a.id, r.toList()) }
                            }
                            RoleChip("Lokal", "lokal" in a.roles) {
                                val r = a.roles.toMutableSet().apply { if ("lokal" in this) remove("lokal") else add("lokal") }
                                act { ManageApi.setRoles(a.id, r.toList()) }
                            }
                        }
                        Row(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            ActionText("Yeni PIN", Gold, Modifier.weight(1f)) { act { shownPin = ManageApi.resetPin(a.id) } }
                            if (confirmDelete == a.id) {
                                ActionText("Emin misiniz? SİL", ClosedRed, Modifier.weight(1f)) { confirmDelete = null; act { ManageApi.remove(a.id) } }
                            } else {
                                ActionText("Sil", ClosedRed, Modifier.weight(1f)) { confirmDelete = a.id }
                            }
                        }
                    }
                }
                Spacer(Modifier.height(10.dp))
            }

            // Neu anlegen
            Text("YENİ YÖNETİCİ", style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 12.sp, color = Gold, letterSpacing = 2.sp),
                modifier = Modifier.padding(start = 4.dp, top = 18.dp, bottom = 8.dp))
            BasicTextField(
                value = newName,
                onValueChange = { newName = it.take(40) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
                textStyle = TextStyle(fontFamily = Manrope, fontSize = 19.sp, color = TextC),
                cursorBrush = SolidColor(Gold),
                modifier = Modifier.fillMaxWidth().glass(RoundedCornerShape(20.dp), elevated = false).padding(horizontal = 18.dp, vertical = 16.dp),
                decorationBox = { inner ->
                    Box {
                        if (newName.isEmpty()) Text("İsim (örn. Fatih)", style = TextStyle(fontFamily = Manrope, fontSize = 19.sp, color = Muted.copy(alpha = 0.5f)))
                        inner()
                    }
                }
            )
            Row(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                RoleChip("Cami duyuruları", newCami) { newCami = !newCami }
                RoleChip("Lokal", newLokal) { newLokal = !newLokal }
            }
            Spacer(Modifier.height(16.dp))
            BigButton(if (busy) "…" else "EKLE", enabled = newName.isNotBlank() && (newCami || newLokal) && !busy) {
                val roles = buildList { if (newCami) add("cami"); if (newLokal) add("lokal") }
                val n = newName.trim()
                act { shownPin = ManageApi.add(n, roles); newName = "" }
            }
            Spacer(Modifier.height(40.dp))
        }
    }
}

@Composable
private fun RoleChip(label: String, on: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(50)
    Text(
        (if (on) "✓ " else "") + label,
        style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 14.sp, color = if (on) Bg else Muted),
        modifier = Modifier
            .clip(shape)
            .background(if (on) GoldGradient else Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.04f), Color.White.copy(alpha = 0.04f))))
            .border(1.dp, if (on) Color.Transparent else Line, shape)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp)
    )
}

@Composable
private fun ActionText(label: String, color: Color, modifier: Modifier, onClick: () -> Unit) {
    Text(
        label,
        style = TextStyle(fontFamily = Manrope, fontWeight = FontWeight.Bold, fontSize = 14.sp, color = color, textAlign = TextAlign.Center),
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .border(1.dp, color.copy(alpha = 0.4f), RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 11.dp)
    )
}

@Suppress("unused")
private val unusedWidth = Modifier.width(0.dp)
