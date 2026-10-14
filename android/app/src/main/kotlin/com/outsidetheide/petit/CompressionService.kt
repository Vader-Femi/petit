package com.outsidetheide.petit

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Keeps Petit running while it compresses in the background.
 *
 * A foreground service (with its notification) stops Android from killing the
 * app when the user switches away, and a partial wake lock stops the CPU
 * sleeping with the screen off. The compression itself still runs in Flutter;
 * this only keeps the process alive and shows progress.
 *
 * Driven from [MainActivity] through a method channel: [begin] / [update] /
 * [end].
 */
class CompressionService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Compressing"
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: ""
        instance = this
        createChannel()
        val notification = buildNotification(title, text, percent = 0, indeterminate = true)
        startAsForeground(notification)
        acquireWakeLock()
        currentTitle = title
        // If the system restarts the service after killing it, the job is gone
        // with the process, so there is nothing to resume.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releaseWakeLock()
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun startAsForeground(notification: Notification) {
        when {
            // Android 15+: the type made for this job.
            Build.VERSION.SDK_INT >= 35 ->
                startForeground(NOTIFICATION_ID, notification, TYPE_MEDIA_PROCESSING)
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ->
                startForeground(
                    NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            else -> startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Compression progress",
            // Low: shown, but silent. The progress bar is the point.
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Shows while Petit is compressing your files"
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(
        title: String,
        text: String,
        percent: Int,
        indeterminate: Boolean
    ): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val openApp = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE)
        }

        return builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setProgress(100, percent, indeterminate)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openApp)
            .build()
    }

    private fun updateNotification(percent: Int, text: String) {
        val notification = buildNotification(currentTitle, text, percent, indeterminate = false)
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "petit:compression").apply {
            // A safety net so a lost job can never hold the CPU awake forever.
            acquire(WAKE_LOCK_TIMEOUT_MS)
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
    }

    companion object {
        private const val CHANNEL_ID = "petit_compression"
        private const val NOTIFICATION_ID = 4711
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val WAKE_LOCK_TIMEOUT_MS = 3L * 60 * 60 * 1000

        // ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING (API 35), written
        // out so this compiles whichever compileSdk the project uses.
        private const val TYPE_MEDIA_PROCESSING = 0x00002000

        @Volatile
        private var instance: CompressionService? = null

        @Volatile
        private var currentTitle: String = "Compressing"

        /** Starts the service. Call while the app is in the foreground. */
        fun begin(context: Context, title: String, text: String) {
            val intent = Intent(context, CompressionService::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Moves the progress bar. Ignored when the service is not running. */
        fun update(percent: Int, text: String) {
            instance?.updateNotification(percent.coerceIn(0, 100), text)
        }

        /** Stops the service and removes its notification. */
        fun end(context: Context) {
            context.stopService(Intent(context, CompressionService::class.java))
        }
    }
}
