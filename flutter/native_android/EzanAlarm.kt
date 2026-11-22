package de.merkezcamii.merkezcamii

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray

/** Ezan im Lautlos-Modus: Weckalarme, die einen Dienst mit Alarm-Ton starten. */
object EzanAlarm {
    private const val PREFS = "ezan_alarm"
    private const val BASE = 70000

    private fun pi(ctx: Context, i: Int, title: String?, body: String?, sabah: Boolean): PendingIntent {
        val it = Intent(ctx, EzanAlarmReceiver::class.java).apply {
            action = "de.merkezcamii.EZAN_$i"
            putExtra("title", title)
            putExtra("body", body)
            putExtra("sabah", sabah)
        }
        return PendingIntent.getBroadcast(ctx, BASE + i, it,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    /** json: [{at: millis, sabah: bool, title, body}] – ersetzt alle bisherigen Alarme. */
    fun replaceAll(ctx: Context, json: String) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val old = prefs.getInt("count", 0)
        for (i in 0 until maxOf(old, 0)) am.cancel(pi(ctx, i, null, null, false))
        val arr = JSONArray(json)
        val now = System.currentTimeMillis()
        var n = 0
        for (k in 0 until arr.length()) {
            val o = arr.getJSONObject(k)
            val at = o.getLong("at")
            if (at <= now) continue
            val p = pi(ctx, n, o.optString("title"), o.optString("body"), o.optBoolean("sabah"))
            try {
                if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, p)
                } else {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, p)
                }
            } catch (e: SecurityException) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, p)
            }
            n++
        }
        prefs.edit().putInt("count", n).putString("json", json).apply()
    }

    fun restore(ctx: Context) {
        val json = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("json", null) ?: return
        replaceAll(ctx, json)
    }
}

class EzanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        EzanService.start(ctx, intent.getStringExtra("title") ?: "Ezan",
            intent.getStringExtra("body") ?: "", intent.getBooleanExtra("sabah", false))
    }
}

class EzanBootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        EzanAlarm.restore(ctx)
    }
}
