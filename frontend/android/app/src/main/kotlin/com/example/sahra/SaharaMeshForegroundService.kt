package com.example.sahra

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Android Foreground Service responsible for keeping SAHARA's process alive
 * and responsive to Bluetooth / Nearby Connections packets when the phone's
 * screen is turned off and the device is locked.
 *
 * Uses [ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE] for Android 14+ / 16 (API 36).
 */
class SaharaMeshForegroundService : Service() {

    companion object {
        const val NOTIFICATION_ID = 9001
        const val SERVICE_CHANNEL_ID = "mesh_service"

        @Volatile
        var isScreenOff: Boolean = false
            private set

        @Volatile
        var isServiceRunning: Boolean = false
            private set

        fun start(context: Context) {
            try {
                val intent = Intent(context, SaharaMeshForegroundService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.e("SAHARA-BG", "[SAHARA-BG] FAILED_TO_START_SERVICE: ${e.message}")
            }
        }

        fun stop(context: Context) {
            try {
                val intent = Intent(context, SaharaMeshForegroundService::class.java)
                context.stopService(intent)
            } catch (e: Exception) {
                Log.e("SAHARA-BG", "[SAHARA-BG] FAILED_TO_STOP_SERVICE: ${e.message}")
            }
        }

        fun isDeviceLocked(context: Context): Boolean {
            val km = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            return km?.isKeyguardLocked == true || km?.isDeviceLocked == true
        }

        fun isDeviceInteractive(context: Context): Boolean {
            val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            return pm?.isInteractive == true
        }

        /**
         * Acquires a temporary bright wake lock with ACQUIRE_CAUSES_WAKEUP to
         * physically turn on the phone's screen when an emergency alert arrives.
         */
        fun wakeScreen(context: Context, durationMs: Long = 10000L) {
            try {
                val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                @Suppress("DEPRECATION")
                val wakeLock = pm?.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                    "sahara:emergency_screen_wake"
                )
                wakeLock?.acquire(durationMs)
                Log.i("SAHARA-BG", "[SAHARA-BG] SCREEN_WAKE_ACQUIRED duration=${durationMs}ms")
            } catch (e: Exception) {
                Log.e("SAHARA-BG", "[SAHARA-BG] SCREEN_WAKE_FAILED: ${e.message}")
            }
        }
    }

    private var screenReceiver: BroadcastReceiver? = null
    private var partialWakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        Log.i("SAHARA-BG", "[SAHARA-BG] SERVICE_START")

        // 1. Maintain CPU partial wake lock so BLE/Nearby Connections socket stays active
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            partialWakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "sahara:mesh_background_wakelock")
            partialWakeLock?.acquire()
        } catch (e: Exception) {
            Log.e("SAHARA-BG", "[SAHARA-BG] PARTIAL_WAKELOCK_FAILED: ${e.message}")
        }

        // 2. Register dynamic receiver for real-time screen & lock state detection
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_SCREEN_OFF -> {
                        isScreenOff = true
                        Log.i("SAHARA-BG", "[SAHARA-BG] SCREEN_STATE=OFF")
                        if (isDeviceLocked(this@SaharaMeshForegroundService)) {
                            Log.i("SAHARA-BG", "[SAHARA-BG] DEVICE_LOCKED")
                        }
                    }
                    Intent.ACTION_SCREEN_ON -> {
                        isScreenOff = false
                        Log.i("SAHARA-BG", "[SAHARA-BG] SCREEN_STATE=ON")
                        if (isDeviceLocked(this@SaharaMeshForegroundService)) {
                            Log.i("SAHARA-BG", "[SAHARA-BG] DEVICE_LOCKED")
                        }
                    }
                    Intent.ACTION_USER_PRESENT -> {
                        isScreenOff = false
                        Log.i("SAHARA-BG", "[SAHARA-BG] DEVICE_UNLOCKED")
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenReceiver, filter)

        // Initialize current screen state
        isScreenOff = !isDeviceInteractive(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createServiceNotificationChannel()

        val notification = buildForegroundNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        isServiceRunning = true
        Log.i("SAHARA-BG", "[SAHARA-BG] SERVICE_RUNNING")
        Log.i("SAHARA-BG", "[SAHARA-BG] MESH_LISTENER_ACTIVE")

        return START_STICKY
    }

    private fun createServiceNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                SERVICE_CHANNEL_ID,
                "Sahara Mesh Background Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps Bluetooth mesh communication active while screen is locked"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_SECRET
            }
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, SERVICE_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("SAHARA Emergency Mesh Active")
            .setContentText("Listening for emergency broadcasts and mesh messages")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.i("SAHARA-BG", "[SAHARA-BG] TASK_REMOVED - maintaining mesh listener in background")
    }

    override fun onDestroy() {
        Log.i("SAHARA-BG", "[SAHARA-BG] SERVICE_DESTROY")
        isServiceRunning = false

        try {
            if (screenReceiver != null) {
                unregisterReceiver(screenReceiver)
                screenReceiver = null
            }
        } catch (_: Exception) {}

        try {
            if (partialWakeLock?.isHeld == true) {
                partialWakeLock?.release()
                partialWakeLock = null
            }
        } catch (_: Exception) {}

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
