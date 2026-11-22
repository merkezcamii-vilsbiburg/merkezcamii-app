package de.merkezcamii.merkezcamii

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/** Spielt den Ezan über den Alarm-Kanal – hörbar auch im Lautlos-/Vibrationsmodus. */
class EzanService : Service() {
    private var player: MediaPlayer? = null

    companion object {
        private const val CH = "ezan_sessiz_modda"
        private const val NID = 4711
        private const val STOP = "de.merkezcamii.EZAN_STOP"

        fun start(ctx: Context, title: String, body: String, sabah: Boolean) {
            val i = Intent(ctx, EzanService::class.java)
                .putExtra("title", title).putExtra("body", body).putExtra("sabah", sabah)
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, EzanService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        val title = intent?.getStringExtra("title") ?: "Ezan"
        val body = intent?.getStringExtra("body") ?: ""
        val sabah = intent?.getBooleanExtra("sabah", false) ?: false

        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CH) == null) {
            val c = NotificationChannel(CH, "Ezan (sessiz modda)", NotificationManager.IMPORTANCE_HIGH)
            c.description = "Telefon sessizdeyken okunan ezan"
            c.setSound(null, null)
            nm.createNotificationChannel(c)
        }
        val flagsPi = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val stopPi = PendingIntent.getService(this, 1, Intent(this, EzanService::class.java).setAction(STOP), flagsPi)
        val open = packageManager.getLaunchIntentForPackage(packageName)
        val openPi = PendingIntent.getActivity(this, 2, open, flagsPi)
        val icon = resources.getIdentifier("ic_stat_cami", "drawable", packageName)
        val large = resources.getIdentifier("notif_cami", "drawable", packageName)
        val b = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CH) else Notification.Builder(this))
            .setSmallIcon(if (icon != 0) icon else android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setColor(0xFFE3BF72.toInt())
            .setCategory(Notification.CATEGORY_ALARM)
            .setContentIntent(openPi)
            .setDeleteIntent(stopPi)
            .addAction(Notification.Action.Builder(null, "Ezanı durdur", stopPi).build())
            .setOngoing(true)
        if (large != 0) b.setLargeIcon(BitmapFactory.decodeResource(resources, large))
        val n = b.build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NID, n)
        }

        player?.release()
        val res = resources.getIdentifier(if (sabah) "ezan_sabah" else "ezan", "raw", packageName)
        if (res == 0) {
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            val mp = MediaPlayer()
            mp.setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            resources.openRawResourceFd(res).use { fd -> mp.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length) }
            mp.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
            mp.setOnCompletionListener { stopSelf() }
            mp.setOnErrorListener { _, _, _ -> stopSelf(); true }
            mp.prepare()
            mp.start()
            player = mp
        } catch (e: Exception) {
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        player?.let { try { it.stop() } catch (_: Exception) {}; it.release() }
        player = null
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
        super.onDestroy()
    }
}
