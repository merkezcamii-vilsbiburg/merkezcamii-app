package de.merkezcamii.vilsbiburg

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.util.LruCache
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.exifinterface.media.ExifInterface
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.UUID

/** Supabase-Zugang. Leer = Demo-Modus (Beispieldaten, Demo-PIN 1234). */
object Config {
    const val SUPABASE_URL = "https://eglsbxlvoqbkdqtyeghb.supabase.co"
    const val SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVnbHNieGx2b3Fia2RxdHllZ2hiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTUyNjU3MjAsImV4cCI6MjExMDg0MTcyMH0.vHiUapBqoaiWNqfUlbyCx6yX3K2QuMx_2Q1PcJ4UhVU"
    val demo: Boolean get() = SUPABASE_URL.isEmpty()
}

data class Ann(
    val id: Long,
    val section: String, // "cami" | "lokal"
    val title: String,
    val body: String,
    val photo: String?,
    val author: String?,
    val createdAt: Instant,
)

data class Team(val id: String, val name: String, val logo: String, val score: String?)

data class MatchItem(
    val id: String,
    val league: String, // "sl" | "cl"
    val date: Instant,
    val home: Team,
    val away: Team,
    val state: String, // pre | in | post
    val clock: String,
)

class ApiError(msg: String) : IOException(msg)

// ---------------------------------------------------------------- HTTP

object Backend {
    private fun open(url: String, method: String): HttpURLConnection {
        val c = URL(url).openConnection() as HttpURLConnection
        c.requestMethod = method
        c.connectTimeout = 12_000
        c.readTimeout = 20_000
        c.setRequestProperty("apikey", Config.SUPABASE_KEY)
        c.setRequestProperty("Authorization", "Bearer ${Config.SUPABASE_KEY}")
        return c
    }

    private fun readAll(c: HttpURLConnection): String {
        val code = c.responseCode
        val stream = if (code in 200..299) c.inputStream else c.errorStream
        val text = stream?.bufferedReader()?.use { it.readText() } ?: ""
        if (code !in 200..299) {
            val msg = try { JSONObject(text).optString("message", text) } catch (e: Exception) { text }
            throw ApiError(msg.ifBlank { "Sunucu hatası ($code)" })
        }
        return text
    }

    fun get(path: String): String {
        val c = open("${Config.SUPABASE_URL}/rest/v1/$path", "GET")
        return try { readAll(c) } finally { c.disconnect() }
    }

    /** RPC aufrufen; Antwort {"error": "..."} wird zu ApiError. */
    fun rpc(name: String, body: JSONObject): String {
        val c = open("${Config.SUPABASE_URL}/rest/v1/rpc/$name", "POST")
        c.doOutput = true
        c.setRequestProperty("Content-Type", "application/json")
        c.outputStream.use { it.write(body.toString().toByteArray()) }
        val txt = try { readAll(c) } finally { c.disconnect() }
        val err = try { JSONObject(txt).optString("error", "") } catch (e: Exception) { "" }
        if (err.isNotBlank()) throw ApiError(err)
        return txt
    }

    /** Lädt ein Foto in den öffentlichen Bucket "photos" und gibt die öffentliche Adresse zurück. */
    fun upload(bytes: ByteArray): String {
        val name = "${System.currentTimeMillis()}-${UUID.randomUUID().toString().take(8)}.jpg"
        val c = open("${Config.SUPABASE_URL}/storage/v1/object/photos/$name", "POST")
        c.doOutput = true
        c.setRequestProperty("Content-Type", "image/jpeg")
        c.setRequestProperty("x-upsert", "false")
        c.outputStream.use { it.write(bytes) }
        try { readAll(c) } finally { c.disconnect() }
        return "${Config.SUPABASE_URL}/storage/v1/object/public/photos/$name"
    }

    fun getUrl(url: String): String {
        val c = URL(url).openConnection() as HttpURLConnection
        c.connectTimeout = 12_000
        c.readTimeout = 20_000
        return try {
            if (c.responseCode !in 200..299) throw IOException("HTTP ${c.responseCode}")
            c.inputStream.bufferedReader().use { it.readText() }
        } finally { c.disconnect() }
    }
}

// ---------------------------------------------------------------- Bilder

object Images {
    private val cache = object : LruCache<String, Bitmap>(24 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }

    fun cached(url: String): Bitmap? = cache.get(url)

    suspend fun load(url: String, maxSize: Int = 1400): Bitmap? = withContext(Dispatchers.IO) {
        cache.get(url)?.let { return@withContext it }
        try {
            val c = URL(url).openConnection() as HttpURLConnection
            c.connectTimeout = 12_000
            c.readTimeout = 20_000
            val bytes = c.inputStream.use { it.readBytes() }
            c.disconnect()
            val bmp = decodeScaled(bytes, maxSize) ?: return@withContext null
            cache.put(url, bmp)
            bmp
        } catch (e: Exception) {
            null
        }
    }

    private fun decodeScaled(bytes: ByteArray, maxSize: Int): Bitmap? {
        val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, o)
        var sample = 1
        while (o.outWidth / (sample * 2) >= maxSize || o.outHeight / (sample * 2) >= maxSize) sample *= 2
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample })
    }

    /** Foto aus der Galerie: drehen (EXIF), auf max. 1600 px verkleinern, als JPEG. */
    fun prepareUpload(ctx: Context, uri: Uri): ByteArray {
        val cr = ctx.contentResolver
        val raw = cr.openInputStream(uri)?.use { it.readBytes() } ?: throw IOException("Fotoğraf okunamadı")
        var bmp = decodeScaled(raw, 1600) ?: throw IOException("Fotoğraf okunamadı")
        val rotation = try {
            when (ExifInterface(raw.inputStream()).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        } catch (e: Exception) { 0f }
        val maxSide = maxOf(bmp.width, bmp.height)
        if (maxSide > 1600) {
            val f = 1600f / maxSide
            bmp = Bitmap.createScaledBitmap(bmp, (bmp.width * f).toInt(), (bmp.height * f).toInt(), true)
        }
        if (rotation != 0f) {
            bmp = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, Matrix().apply { postRotate(rotation) }, true)
        }
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.JPEG, 82, out)
        return out.toByteArray()
    }

    fun previewBitmap(bytes: ByteArray): Bitmap? = decodeScaled(bytes, 900)
}

// ---------------------------------------------------------------- Zustand der App

object AppState {
    private lateinit var prefs: SharedPreferences

    val announcements = mutableStateListOf<Ann>()
    val locks = mutableStateMapOf<String, Boolean>()
    val matches = mutableStateListOf<MatchItem>()
    val turkishTeams = mutableStateMapOf<String, Boolean>()
    var matchesLoading by mutableStateOf(true)
    var matchesError by mutableStateOf<String?>(null)
    var loaded by mutableStateOf(false)

    var adminName by mutableStateOf<String?>(null)
    var adminRoles by mutableStateOf<Set<String>>(emptySet())
    private var adminPin: String? = null

    var seenCami by mutableLongStateOf(-1L)
    var seenLokal by mutableLongStateOf(-1L)

    fun init(ctx: Context) {
        if (::prefs.isInitialized) return
        prefs = ctx.getSharedPreferences("merkezcamii", Context.MODE_PRIVATE)
        adminPin = prefs.getString("pin", null)
        adminName = prefs.getString("adminName", null)
        adminRoles = prefs.getStringSet("roles", emptySet()) ?: emptySet()
        seenCami = prefs.getLong("seen_cami", -1L)
        seenLokal = prefs.getLong("seen_lokal", -1L)
        if (Config.demo) {
            announcements.addAll(DemoData.announcements())
            DemoData.locks.forEach { (k, v) -> locks[k] = v }
        }
    }

    fun isAdmin(role: String) = role in adminRoles

    fun list(section: String) = announcements.filter { it.section == section }.sortedByDescending { it.createdAt }

    private fun maxId(section: String) = announcements.filter { it.section == section }.maxOfOrNull { it.id } ?: 0L

    fun unread(section: String): Int {
        val seen = if (section == "cami") seenCami else seenLokal
        if (seen < 0) return 0
        return announcements.count { it.section == section && it.id > seen }
    }

    fun markSeen(section: String) {
        val m = maxId(section)
        if (section == "cami") seenCami = m else seenLokal = m
        prefs.edit().putLong("seen_$section", m).apply()
    }

    /** Beim allerersten Start alte Duyurular nicht als "neu" zählen. */
    private fun initSeenIfNeeded() {
        if (seenCami < 0) markSeen("cami")
        if (seenLokal < 0) markSeen("lokal")
    }

    suspend fun refresh() {
        if (Config.demo) { loaded = true; initSeenIfNeeded(); return }
        try {
            val (anns, lk) = withContext(Dispatchers.IO) {
                val a = JSONArray(Backend.get("announcements?select=*&deleted=eq.false&order=created_at.desc&limit=60"))
                val l = JSONArray(Backend.get("match_locks?select=match_id,open"))
                a to l
            }
            val list = (0 until anns.length()).map { i ->
                val o = anns.getJSONObject(i)
                Ann(
                    id = o.getLong("id"),
                    section = o.getString("section"),
                    title = o.optString("title", ""),
                    body = o.optString("body", ""),
                    photo = o.optString("photo_url", "").takeIf { it.isNotBlank() && it != "null" },
                    author = o.optString("author", "").takeIf { it.isNotBlank() && it != "null" },
                    createdAt = parseTime(o.optString("created_at")),
                )
            }
            announcements.clear(); announcements.addAll(list)
            val map = (0 until lk.length()).associate { i -> lk.getJSONObject(i).let { it.getString("match_id") to it.getBoolean("open") } }
            locks.keys.retainAll(map.keys); locks.putAll(map)
            loaded = true
            initSeenIfNeeded()
        } catch (e: Exception) {
            loaded = true
        }
    }

    private fun parseTime(s: String): Instant = try {
        OffsetDateTime.parse(s).toInstant()
    } catch (e: Exception) {
        Instant.now()
    }

    // ---------- Maçlar (gleiche Quelle wie die Webseite) ----------
    suspend fun refreshMatches() {
        val leagues = listOf("sl" to "tur.1", "cl" to "uefa.champions")
        val ymd = DateTimeFormatter.ofPattern("yyyyMMdd").withZone(ZoneOffset.UTC)
        val start = ymd.format(Instant.now().minusSeconds(6 * 3600))
        val end = ymd.format(Instant.now().plusSeconds(14 * 86400))
        val result = mutableListOf<MatchItem>()
        var okCount = 0
        withContext(Dispatchers.IO) {
            for ((k, code) in leagues) {
                try {
                    val url = "https://site.api.espn.com/apis/site/v2/sports/soccer/$code/scoreboard?limit=300&dates=$start-$end"
                    val events = JSONObject(Backend.getUrl(url)).optJSONArray("events") ?: JSONArray()
                    for (i in 0 until events.length()) {
                        val ev = events.getJSONObject(i)
                        val comp = ev.optJSONArray("competitions")?.optJSONObject(0) ?: continue
                        val cs = comp.optJSONArray("competitors") ?: continue
                        fun side(h: String): Team {
                            for (j in 0 until cs.length()) {
                                val x = cs.getJSONObject(j)
                                if (x.optString("homeAway") == h) {
                                    val t = x.optJSONObject("team") ?: JSONObject()
                                    return Team(
                                        id = t.optString("id"),
                                        name = t.optString("shortDisplayName", t.optString("displayName", "?")),
                                        logo = t.optString("logo", ""),
                                        score = x.optString("score", "").takeIf { it.isNotBlank() }
                                    )
                                }
                            }
                            return Team("", "?", "", null)
                        }
                        val st = ev.optJSONObject("status")
                        val type = st?.optJSONObject("type")
                        result.add(
                            MatchItem(
                                id = ev.optString("id"),
                                league = k,
                                date = parseTime(ev.optString("date").let { if (it.length == 17) it.replace("Z", ":00Z") else it }),
                                home = side("home"),
                                away = side("away"),
                                state = type?.optString("state", "pre") ?: "pre",
                                clock = st?.optString("displayClock", "") ?: "",
                            )
                        )
                    }
                    okCount++
                } catch (e: Exception) {
                    // Liga konnte nicht geladen werden
                }
            }
        }
        if (okCount == 0) {
            if (matches.isEmpty()) {
                if (Config.demo) { matches.addAll(DemoData.matches()); markTurkish() }
                else matchesError = "Maç listesi şu an yüklenemedi. Lütfen biraz sonra tekrar deneyin."
            }
        } else {
            matchesError = null
            val cutoff = Instant.now().minusSeconds(3 * 3600)
            matches.clear()
            matches.addAll(result.filter { !(it.state == "post" && it.date.isBefore(cutoff)) }.sortedBy { it.date })
            markTurkish()
        }
        matchesLoading = false
    }

    private fun markTurkish() {
        turkishTeams.clear()
        matches.filter { it.league == "sl" }.forEach { turkishTeams[it.home.id] = true; turkishTeams[it.away.id] = true }
    }

    fun isTurkish(m: MatchItem) = turkishTeams[m.home.id] == true || turkishTeams[m.away.id] == true

    // ---------- Yönetici ----------
    suspend fun login(pin: String) {
        val (name, roles) = if (Config.demo) {
            if (pin != "1234") throw ApiError("PIN yanlış")
            "Demo" to setOf("cami", "lokal")
        } else {
            val txt = withContext(Dispatchers.IO) { Backend.rpc("admin_login", JSONObject().put("p_pin", pin)) }
            val o = JSONObject(txt)
            val arr = o.optJSONArray("roles") ?: JSONArray()
            o.getString("name") to (0 until arr.length()).map { arr.getString(it) }.toSet()
        }
        adminPin = pin; adminName = name; adminRoles = roles
        prefs.edit().putString("pin", pin).putString("adminName", name).putStringSet("roles", roles).apply()
    }

    fun logout() {
        adminPin = null; adminName = null; adminRoles = emptySet()
        prefs.edit().remove("pin").remove("adminName").remove("roles").apply()
    }

    private fun handleAuthError(e: Exception) {
        if (e is ApiError && (e.message ?: "").contains("PIN", ignoreCase = true)) logout()
    }

    suspend fun post(section: String, title: String, body: String, photo: ByteArray?) {
        if (Config.demo) {
            val id = (announcements.maxOfOrNull { it.id } ?: 0L) + 1
            announcements.add(Ann(id, section, title, body, null, adminName, Instant.now()))
            markSeen(section)
            return
        }
        try {
            withContext(Dispatchers.IO) {
                val url = photo?.let { Backend.upload(it) }
                Backend.rpc(
                    "post_announcement",
                    JSONObject()
                        .put("p_pin", adminPin)
                        .put("p_section", section)
                        .put("p_title", title)
                        .put("p_body", body)
                        .put("p_photo_url", url ?: JSONObject.NULL)
                )
            }
            refresh()
            markSeen(section)
        } catch (e: Exception) {
            handleAuthError(e); throw e
        }
    }

    suspend fun delete(a: Ann) {
        if (Config.demo) { announcements.removeAll { it.id == a.id }; return }
        try {
            withContext(Dispatchers.IO) {
                Backend.rpc("delete_announcement", JSONObject().put("p_pin", adminPin).put("p_id", a.id))
            }
            announcements.removeAll { it.id == a.id }
        } catch (e: Exception) {
            handleAuthError(e); throw e
        }
    }

    suspend fun setLock(m: MatchItem, open: Boolean) {
        val before = locks[m.id] ?: false
        locks[m.id] = open
        if (Config.demo) return
        try {
            withContext(Dispatchers.IO) {
                Backend.rpc(
                    "set_lock",
                    JSONObject()
                        .put("p_pin", adminPin)
                        .put("p_match_id", m.id)
                        .put("p_open", open)
                        .put("p_label", "${m.home.name} - ${m.away.name}")
                )
            }
        } catch (e: Exception) {
            locks[m.id] = before
            handleAuthError(e); throw e
        }
    }

    @Suppress("unused")
    private fun enc(s: String) = URLEncoder.encode(s, "UTF-8")
}

// ---------------------------------------------------------------- Beispieldaten (Demo-Modus)

object DemoData {
    val locks = mapOf("demo1" to true, "demo5" to true)

    fun announcements(): List<Ann> {
        val now = Instant.now()
        fun ago(h: Long) = now.minusSeconds(h * 3600)
        return listOf(
            Ann(1, "cami", "Hayır çarşısı (Kermes)", "Cumartesi günü camimizin bahçesinde hayır çarşımız var. Gözlemeler, tatlılar ve çay sizi bekliyor. Tüm cemaatimiz ailesiyle davetlidir.", null, "Örnek", ago(3)),
            Ann(2, "cami", "Cuma Namazı", "Cuma namazına tüm cemaatimiz davetlidir. Hutbe öğle vaktinde başlar.", null, "Örnek", ago(30)),
            Ann(3, "cami", "Çocuklar için Kuran kursu", "Cumartesi ve pazar günleri çocuklarımız için Kuran ve din dersi verilmektedir. Kayıt için cami yönetimine başvurabilirsiniz.", null, "Örnek", ago(60)),
            Ann(4, "lokal", "Halı saha maçı", "Pazar günleri öğleden sonra gençlerimizle halı sahada buluşuyoruz. Katılmak isteyen herkes gelebilir.", null, "Örnek", ago(5)),
            Ann(5, "lokal", "PlayStation turnuvası", "Lokalimizde FIFA turnuvası düzenliyoruz. Kayıt lokalde yapılır.", null, "Örnek", ago(48)),
        )
    }

    fun matches(): List<MatchItem> {
        val base = java.time.LocalDate.now(Prayer.ZONE)
        fun at(day: Long, h: Int, m: Int) = base.plusDays(day).atTime(h, m).atZone(Prayer.ZONE).toInstant()
        fun t(id: String, n: String) = Team(id, n, "", null)
        return listOf(
            MatchItem("demo1", "sl", at(0, 19, 0), t("gs", "Galatasaray"), t("fb", "Fenerbahçe"), "pre", ""),
            MatchItem("demo2", "sl", at(0, 21, 45), t("bjk", "Beşiktaş"), t("ts", "Trabzonspor"), "pre", ""),
            MatchItem("demo3", "sl", at(1, 16, 0), t("sam", "Samsunspor"), t("goz", "Göztepe"), "pre", ""),
            MatchItem("demo5", "cl", at(3, 21, 0), t("fcb", "Bayern München"), t("gs", "Galatasaray"), "pre", ""),
            MatchItem("demo6", "cl", at(3, 21, 0), t("ars", "Arsenal"), t("psv", "PSV"), "pre", ""),
        )
    }
}
