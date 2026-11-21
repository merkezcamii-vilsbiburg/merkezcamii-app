package de.merkezcamii.vilsbiburg

import android.Manifest
import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import java.net.HttpURLConnection
import java.net.URL

/** Firebase-Daten aus google-services.json (keine Geheimnisse). Leer = Push aus. */
object FcmConfig {
    const val APP_ID = ""
    const val API_KEY = ""
    const val PROJECT_ID = ""
    const val SENDER_ID = ""
    val enabled get() = APP_ID.isNotEmpty() && API_KEY.isNotEmpty() && PROJECT_ID.isNotEmpty()
}

const val CH_CAMI = "cami_duyurulari"
const val CH_LOKAL = "genclik_lokal"

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        AppState.init(this)
        createChannels(this)
        initPush(this)
    }
}

fun createChannels(ctx: Context) {
    val nm = ctx.getSystemService(NotificationManager::class.java)
    nm.createNotificationChannel(
        NotificationChannel(CH_CAMI, "Cami duyuruları", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Merkez Camii duyuruları"
        }
    )
    nm.createNotificationChannel(
        NotificationChannel(CH_LOKAL, "Gençlik / Lokal", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Gençlik duyuruları ve lokal maçları"
        }
    )
}

fun initPush(ctx: Context) {
    if (!FcmConfig.enabled) return
    try {
        if (FirebaseApp.getApps(ctx).isEmpty()) {
            FirebaseApp.initializeApp(
                ctx,
                FirebaseOptions.Builder()
                    .setApplicationId(FcmConfig.APP_ID)
                    .setApiKey(FcmConfig.API_KEY)
                    .setProjectId(FcmConfig.PROJECT_ID)
                    .setGcmSenderId(FcmConfig.SENDER_ID)
                    .build()
            )
        }
        val fm = FirebaseMessaging.getInstance()
        fm.subscribeToTopic("cami")
        fm.subscribeToTopic("lokal")
    } catch (e: Exception) {
        // Push nicht verfügbar (z. B. ohne Google-Dienste) – App läuft trotzdem
    }
}

class PushService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        // Topics neu abonnieren
        try {
            FirebaseMessaging.getInstance().subscribeToTopic("cami")
            FirebaseMessaging.getInstance().subscribeToTopic("lokal")
        } catch (e: Exception) { }
    }

    override fun onMessageReceived(msg: RemoteMessage) {
        val d = msg.data
        val kind = d["kind"] ?: return
        val isCami = kind == "cami"
        val title = d["title"].orEmpty().ifBlank { if (isCami) "Merkez Camii" else "Gençlik Kolları" }
        val body = d["body"].orEmpty()
        val photo = d["photo"]?.takeIf { it.isNotBlank() }?.let { download(it) }
        show(this, isCami, title, body, photo, d["id"].orEmpty())
    }

    private fun download(url: String): Bitmap? = try {
        val c = URL(url).openConnection() as HttpURLConnection
        c.connectTimeout = 8000; c.readTimeout = 8000
        val bytes = c.inputStream.use { it.readBytes() }
        c.disconnect()
        val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, o)
        var s = 1
        while (o.outWidth / (s * 2) >= 1000) s *= 2
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = s })
    } catch (e: Exception) { null }
}

fun show(ctx: Context, isCami: Boolean, title: String, body: String, photo: Bitmap?, id: String) {
    if (Build.VERSION.SDK_INT >= 33 &&
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
    ) return
    val tab = if (isCami) 1 else 2
    val intent = Intent(ctx, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        putExtra("tab", tab)
    }
    val pi = PendingIntent.getActivity(
        ctx, (id.hashCode() and 0xffff) + tab * 100000, intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    val large = BitmapFactory.decodeResource(ctx.resources, if (isCami) R.drawable.notif_cami else R.drawable.notif_lokal)
    val b = NotificationCompat.Builder(ctx, if (isCami) CH_CAMI else CH_LOKAL)
        .setSmallIcon(if (isCami) R.drawable.ic_stat_cami else R.drawable.ic_stat_lokal)
        .setLargeIcon(large)
        .setColor(0xFFE3BF72.toInt())
        .setContentTitle(title)
        .setContentText(body)
        .setAutoCancel(true)
        .setPriority(NotificationCompat.PRIORITY_HIGH)
        .setContentIntent(pi)
    if (photo != null) {
        b.setStyle(NotificationCompat.BigPictureStyle().bigPicture(photo).setSummaryText(body))
    } else {
        b.setStyle(NotificationCompat.BigTextStyle().bigText(body))
    }
    try {
        NotificationManagerCompat.from(ctx).notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), b.build())
    } catch (e: SecurityException) { }
}
