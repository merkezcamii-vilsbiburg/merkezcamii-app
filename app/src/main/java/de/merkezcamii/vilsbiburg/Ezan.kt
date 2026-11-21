package de.merkezcamii.vilsbiburg

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate

const val CH_EZAN = "ezan"
const val CH_VAKIT = "vakit_bildirimi"
const val CH_CUMA = "cuma"

/** Ezan-Einstellungen pro Vakit: "ezan" | "bildirim" | "kapali". Standard: Ezan an. */
object EzanSettings {
    val KEYS = listOf("imsak", "ogle", "ikindi", "aksam", "yatsi")
    val LABELS = mapOf("imsak" to "Sabah", "ogle" to "Öğle", "ikindi" to "İkindi", "aksam" to "Akşam", "yatsi" to "Yatsı")

    val modes = mutableStateMapOf<String, String>()
    var cuma by mutableStateOf(true)
    var silentToo by mutableStateOf(false)
    private var loaded = false

    private fun prefs(ctx: Context) = ctx.getSharedPreferences("ezan", Context.MODE_PRIVATE)

    fun load(ctx: Context) {
        if (loaded) return
        val p = prefs(ctx)
        KEYS.forEach { modes[it] = p.getString("mode_$it", "ezan") ?: "ezan" }
        cuma = p.getBoolean("cuma", true)
        silentToo = p.getBoolean("silentToo", false)
        loaded = true
    }

    fun mode(ctx: Context, key: String): String {
        load(ctx); return modes[key] ?: "ezan"
    }

    fun setMode(ctx: Context, key: String, m: String) {
        modes[key] = m
        prefs(ctx).edit().putString("mode_$key", m).apply()
        PrayerScheduler.scheduleNext(ctx)
    }

    fun setCuma(ctx: Context, v: Boolean) {
        cuma = v; prefs(ctx).edit().putBoolean("cuma", v).apply(); PrayerScheduler.scheduleNext(ctx)
    }

    fun setSilentToo(ctx: Context, v: Boolean) {
        silentToo = v; prefs(ctx).edit().putBoolean("silentToo", v).apply()
    }
}

fun createEzanChannels(ctx: Context) {
    val nm = ctx.getSystemService(NotificationManager::class.java)
    nm.createNotificationChannel(
        NotificationChannel(CH_EZAN, "Ezan", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Ezan okunurken gösterilir"
            setSound(null, null) // Ton kommt vom Ezan selbst
        }
    )
    nm.createNotificationChannel(
        NotificationChannel(CH_VAKIT, "Vakit bildirimi", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Ezan yerine sadece bildirim"
        }
    )
    nm.createNotificationChannel(
        NotificationChannel(CH_CUMA, "Cuma hatırlatması", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Cuma namazından önce hatırlatma"
        }
    )
}

// ---------------------------------------------------------------- Zeitplanung

object PrayerScheduler {
    private const val CUMA_MINUTES_BEFORE = 45L

    fun scheduleNext(ctx: Context) {
        EzanSettings.load(ctx)
        val now = Instant.now()
        val today = LocalDate.now(Prayer.ZONE)
        var best: Pair<Instant, String>? = null
        for (offset in 0L..2L) {
            val d = today.plusDays(offset)
            val t = Prayer.compute(d)
            val cands = mutableListOf<Pair<Instant, String>>()
            for (k in EzanSettings.KEYS) {
                if (EzanSettings.mode(ctx, k) != "kapali") cands.add(t[k]!! to k)
            }
            if (EzanSettings.cuma && d.dayOfWeek == DayOfWeek.FRIDAY) {
                cands.add(t["ogle"]!!.minusSeconds(CUMA_MINUTES_BEFORE * 60) to "cuma")
            }
            for (c in cands) {
                if (c.first.isAfter(now.plusSeconds(5)) && (best == null || c.first.isBefore(best!!.first))) best = c
            }
            if (best != null) break
        }
        val am = ctx.getSystemService(AlarmManager::class.java)
        val pi = PendingIntent.getBroadcast(
            ctx, 4711,
            Intent(ctx, PrayerAlarmReceiver::class.java).apply {
                if (best != null) {
                    putExtra("key", best!!.second)
                    putExtra("at", best!!.first.toEpochMilli())
                }
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        am.cancel(pi)
        val b = best ?: return
        val at = b.first.toEpochMilli()
        try {
            if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            }
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }
}

class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val key = intent.getStringExtra("key")
        val at = intent.getLongExtra("at", 0L)
        val late = System.currentTimeMillis() - at > 10 * 60 * 1000 // mehr als 10 min zu spät → kein Ezan mehr
        if (key != null && !late) {
            EzanSettings.load(ctx)
            if (key == "cuma") {
                val ogle = Prayer.fmt(Prayer.compute(LocalDate.now(Prayer.ZONE))["ogle"]!!)
                simpleNotify(ctx, CH_CUMA, 9001, "Bugün Cuma 🕌", "Cuma namazı $ogle'de. Hayırlı Cumalar!")
            } else {
                val name = EzanSettings.LABELS[key] ?: key
                val mode = EzanSettings.mode(ctx, key)
                val am = ctx.getSystemService(AudioManager::class.java)
                val silent = am.ringerMode != AudioManager.RINGER_MODE_NORMAL
                if (mode == "ezan" && (!silent || EzanSettings.silentToo)) {
                    val si = Intent(ctx, EzanService::class.java).putExtra("key", key)
                    try {
                        ContextCompat.startForegroundService(ctx, si)
                    } catch (e: Exception) {
                        simpleNotify(ctx, CH_VAKIT, 9000, "$name vakti", "$name ezanı vakti girdi.")
                    }
                } else if (mode != "kapali") {
                    simpleNotify(ctx, CH_VAKIT, 9000, "$name vakti", "$name namazı vakti girdi.")
                }
            }
        }
        PrayerScheduler.scheduleNext(ctx)
    }
}

/** Nach Neustart, Zeitänderung oder App-Update neu planen. */
class RescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        PrayerScheduler.scheduleNext(ctx)
    }
}

private fun canNotify(ctx: Context) = Build.VERSION.SDK_INT < 33 ||
    ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

private fun openAppIntent(ctx: Context, req: Int): PendingIntent = PendingIntent.getActivity(
    ctx, req,
    Intent(ctx, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        putExtra("tab", 0)
    },
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
)

fun simpleNotify(ctx: Context, channel: String, id: Int, title: String, text: String) {
    if (!canNotify(ctx)) return
    val n = NotificationCompat.Builder(ctx, channel)
        .setSmallIcon(R.drawable.ic_stat_cami)
        .setLargeIcon(BitmapFactory.decodeResource(ctx.resources, R.drawable.notif_cami))
        .setColor(0xFFE3BF72.toInt())
        .setContentTitle(title)
        .setContentText(text)
        .setAutoCancel(true)
        .setPriority(NotificationCompat.PRIORITY_HIGH)
        .setContentIntent(openAppIntent(ctx, id))
        .build()
    try { NotificationManagerCompat.from(ctx).notify(id, n) } catch (e: SecurityException) { }
}

// ---------------------------------------------------------------- Ezan abspielen

class EzanService : Service() {
    private var player: MediaPlayer? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) { stopEzan(); return START_NOT_STICKY }
        val key = intent?.getStringExtra("key") ?: "ogle"
        val name = EzanSettings.LABELS[key] ?: key
        val notif = buildNotification(name)
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIF_ID, notif)
        }
        play(key)
        return START_NOT_STICKY
    }

    private fun buildNotification(name: String): Notification {
        val stopPi = PendingIntent.getService(
            this, 1, Intent(this, EzanService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CH_EZAN)
            .setSmallIcon(R.drawable.ic_stat_cami)
            .setLargeIcon(BitmapFactory.decodeResource(resources, R.drawable.notif_cami))
            .setColor(0xFFE3BF72.toInt())
            .setContentTitle("$name ezanı")
            .setContentText("$name vakti girdi · Merkez Camii Vilsbiburg")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setContentIntent(openAppIntent(this, 9100))
            .setDeleteIntent(stopPi)
            .addAction(0, "Ezanı durdur", stopPi)
            .build()
    }

    private fun soundRes(key: String): Int {
        val sabah = resources.getIdentifier("ezan_sabah", "raw", packageName)
        val normal = resources.getIdentifier("ezan", "raw", packageName)
        return if (key == "imsak" && sabah != 0) sabah else if (normal != 0) normal else sabah
    }

    private fun play(key: String) {
        val res = soundRes(key)
        if (res == 0) {
            // Keine Ezan-Datei vorhanden → nur Benachrichtigung
            simpleNotify(this, CH_VAKIT, 9000, "${EzanSettings.LABELS[key]} vakti", "Namaz vakti girdi.")
            stopEzan(); return
        }
        try {
            player?.release()
            val afd = resources.openRawResourceFd(res)
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                setOnCompletionListener { stopEzan() }
                setOnErrorListener { _, _, _ -> stopEzan(); true }
                prepare()
                start()
            }
        } catch (e: Exception) {
            stopEzan()
        }
    }

    private fun stopEzan() {
        try { player?.stop() } catch (e: Exception) { }
        player?.release(); player = null
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
        stopSelf()
    }

    override fun onDestroy() {
        player?.release(); player = null
        super.onDestroy()
    }

    companion object {
        const val ACTION_STOP = "de.merkezcamii.vilsbiburg.STOP_EZAN"
        const val NOTIF_ID = 9200
    }
}
