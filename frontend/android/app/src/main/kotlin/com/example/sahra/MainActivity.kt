package com.example.sahra

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Color
import android.location.LocationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.sahra/native"
    private val PICK_IMAGE_REQUEST = 1001
    private val PERMISSION_REQUEST_CODE = 2001
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 2002

    private var pendingPhotoResult: MethodChannel.Result? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingNotificationPermResult: MethodChannel.Result? = null
    private var methodChannel: MethodChannel? = null

    companion object {
        const val EMERGENCY_CHANNEL_ID = "emergency_alerts"
        const val FAMILY_CHANNEL_ID = "family_messages"
        const val PING_CHANNEL_ID = "ping_alerts"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        SaharaMeshForegroundService.start(this)
    }

    private fun triggerDeviceVibration(pattern: LongArray) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                val vibrator = vibratorManager?.defaultVibrator
                if (vibrator != null && vibrator.hasVibrator()) {
                    vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
                    Log.i("SAHARA-NOTIFY", "[SAHARA-NOTIFY] VIBRATION_TRIGGERED")
                }
            } else {
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (vibrator != null && vibrator.hasVibrator()) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
                    } else {
                        vibrator.vibrate(pattern, -1)
                    }
                    Log.i("SAHARA-NOTIFY", "[SAHARA-NOTIFY] VIBRATION_TRIGGERED")
                }
            }
        } catch (e: Exception) {
            Log.e("SAHARA-NOTIFY", "[SAHARA-NOTIFY] VIBRATION_FAILED: ${e.message}")
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                .build()

            // 0. Background Mesh Service Channel (Low Priority, Quiet)
            val meshChannel = NotificationChannel(
                SaharaMeshForegroundService.SERVICE_CHANNEL_ID,
                "Sahara Mesh Background Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps Bluetooth mesh communication active while screen is locked"
                setShowBadge(false)
                lockscreenVisibility = NotificationCompat.VISIBILITY_SECRET
            }

            // 1. Emergency Channel (High Priority, Loud Vibration, Public Lock Screen Visibility)
            val emergencyChannel = NotificationChannel(
                EMERGENCY_CHANNEL_ID,
                "Sahara Emergency Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Critical emergency broadcasts, disaster warnings, and evacuation notices"
                enableLights(true)
                lightColor = Color.RED
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500, 200, 800)
                setSound(soundUri, audioAttributes)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }

            // 2. Family Message Channel (High Priority, Public Lock Screen Visibility)
            val familyChannel = NotificationChannel(
                FAMILY_CHANNEL_ID,
                "Sahara Family Messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Incoming offline mesh messages from family members"
                enableLights(true)
                lightColor = Color.BLUE
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 150, 250)
                setSound(soundUri, audioAttributes)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }

            // 3. Ping Alert Channel (High Priority, Public Lock Screen Visibility)
            val pingChannel = NotificationChannel(
                PING_CHANNEL_ID,
                "Sahara Ping Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Radio connectivity check and peer ping alerts"
                enableLights(true)
                lightColor = Color.YELLOW
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 200, 100, 200)
                setSound(soundUri, audioAttributes)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }

            notificationManager.createNotificationChannel(meshChannel)
            Log.i("SAHARA-NOTIFY", "[SAHARA-NOTIFY] CHANNEL_CREATED mesh_service")
            notificationManager.createNotificationChannel(emergencyChannel)
            Log.i("SAHARA-NOTIFY", "[SAHARA-NOTIFY] CHANNEL_CREATED emergency_alerts")
            notificationManager.createNotificationChannel(familyChannel)
            Log.i("SAHARA-NOTIFY", "[SAHARA-NOTIFY] CHANNEL_CREATED family_messages")
            notificationManager.createNotificationChannel(pingChannel)
            Log.i("SAHARA-NOTIFY", "[SAHARA-NOTIFY] CHANNEL_CREATED ping_alerts")
        }
    }

    private fun getRequiredPermissions(): List<String> {
        val perms = mutableListOf<String>()
        perms.add(Manifest.permission.ACCESS_FINE_LOCATION)
        perms.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            perms.add(Manifest.permission.BLUETOOTH_SCAN)
            perms.add(Manifest.permission.BLUETOOTH_ADVERTISE)
            perms.add(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            perms.add(Manifest.permission.BLUETOOTH)
            perms.add(Manifest.permission.BLUETOOTH_ADMIN)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            perms.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        }
        return perms
    }

    private fun arePermissionsGranted(): Boolean {
        for (p in getRequiredPermissions()) {
            if (ContextCompat.checkSelfPermission(this, p) != PackageManager.PERMISSION_GRANTED) {
                return false
            }
        }
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.i("SAHARA-NOTIFY", "[SAHARA-NOTIFY] INITIALIZING")
        createNotificationChannels()

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBatteryLevel" -> {
                        try {
                            val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                            var level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                            if (level !in 0..100) {
                                val ifilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                                val batteryStatus = registerReceiver(null, ifilter)
                                val rawLevel = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                                val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                                if (rawLevel != -1 && scale > 0) {
                                    level = (rawLevel * 100 / scale.toFloat()).toInt()
                                }
                            }
                            result.success(level)
                        } catch (e: Exception) {
                            result.error("BATTERY_ERROR", e.message, null)
                        }
                    }
                    "pickProfilePhoto" -> {
                        pendingPhotoResult = result
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "image/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        try {
                            startActivityForResult(Intent.createChooser(intent, "Select Emergency Profile Photo"), PICK_IMAGE_REQUEST)
                        } catch (e: Exception) {
                            pendingPhotoResult = null
                            result.error("PICK_ERROR", e.message, null)
                        }
                    }
                    "saveProfile" -> {
                        val json = call.argument<String>("profileJson")
                        val prefs = getSharedPreferences("sahara_prefs", Context.MODE_PRIVATE)
                        prefs.edit().putString("user_profile", json).putBoolean("profile_completed", true).apply()
                        result.success(true)
                    }
                    "getProfile" -> {
                        val prefs = getSharedPreferences("sahara_prefs", Context.MODE_PRIVATE)
                        val json = prefs.getString("user_profile", null)
                        result.success(json)
                    }
                    "isProfileComplete" -> {
                        val prefs = getSharedPreferences("sahara_prefs", Context.MODE_PRIVATE)
                        val complete = prefs.getBoolean("profile_completed", false)
                        result.success(complete)
                    }
                    "clearProfile" -> {
                        val prefs = getSharedPreferences("sahara_prefs", Context.MODE_PRIVATE)
                        prefs.edit().clear().apply()
                        result.success(true)
                    }
                    "checkBluetoothPermissions" -> {
                        result.success(arePermissionsGranted())
                    }
                    "requestBluetoothPermissions" -> {
                        if (arePermissionsGranted()) {
                            result.success(true)
                        } else {
                            val missing = getRequiredPermissions().filter {
                                ContextCompat.checkSelfPermission(this@MainActivity, it) != PackageManager.PERMISSION_GRANTED
                            }.toTypedArray()
                            pendingPermissionResult = result
                            ActivityCompat.requestPermissions(this@MainActivity, missing, PERMISSION_REQUEST_CODE)
                        }
                    }
                    "isBluetoothEnabled" -> {
                        try {
                            val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                            val adapter = bm?.adapter ?: BluetoothAdapter.getDefaultAdapter()
                            result.success(adapter?.isEnabled == true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "enableBluetooth" -> {
                        try {
                            val intent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ENABLE_BT_ERROR", e.message, null)
                        }
                    }
                    "isLocationEnabled" -> {
                        try {
                            val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                            val isGps = lm?.isProviderEnabled(LocationManager.GPS_PROVIDER) ?: false
                            val isNet = lm?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ?: false
                            result.success(isGps || isNet)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "checkNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            val granted = ContextCompat.checkSelfPermission(
                                this@MainActivity,
                                Manifest.permission.POST_NOTIFICATIONS
                            ) == PackageManager.PERMISSION_GRANTED
                            result.success(granted)
                        } else {
                            result.success(true)
                        }
                    }
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            if (ContextCompat.checkSelfPermission(
                                    this@MainActivity,
                                    Manifest.permission.POST_NOTIFICATIONS
                                ) == PackageManager.PERMISSION_GRANTED
                            ) {
                                result.success(true)
                            } else {
                                pendingNotificationPermResult = result
                                ActivityCompat.requestPermissions(
                                    this@MainActivity,
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    NOTIFICATION_PERMISSION_REQUEST_CODE
                                )
                            }
                        } else {
                            result.success(true)
                        }
                    }
                    "startMeshForegroundService" -> {
                        SaharaMeshForegroundService.start(this@MainActivity)
                        result.success(true)
                    }
                    "stopMeshForegroundService" -> {
                        SaharaMeshForegroundService.stop(this@MainActivity)
                        result.success(true)
                    }
                    "isScreenOff" -> {
                        val isOff = SaharaMeshForegroundService.isScreenOff ||
                            !SaharaMeshForegroundService.isDeviceInteractive(this@MainActivity)
                        result.success(isOff)
                    }
                    "isDeviceLocked" -> {
                        val locked = SaharaMeshForegroundService.isDeviceLocked(this@MainActivity)
                        result.success(locked)
                    }
                    "showEmergencyNotification" -> {
                        try {
                            val title = call.argument<String>("title") ?: "Emergency Alert"
                            val message = call.argument<String>("message") ?: ""
                            val severity = call.argument<String>("severity") ?: "warning"
                            val broadcastId = call.argument<String>("id") ?: "broadcast_${System.currentTimeMillis()}"

                            val isBgOrLocked = SaharaMeshForegroundService.isScreenOff ||
                                SaharaMeshForegroundService.isDeviceLocked(this@MainActivity) ||
                                !SaharaMeshForegroundService.isDeviceInteractive(this@MainActivity)

                            Log.i("SAHARA-NOTIFY", "[SAHARA-NOTIFY] EMERGENCY_RECEIVED eventId=$broadcastId")
                            if (isBgOrLocked) {
                                Log.i("SAHARA-BG", "[SAHARA-BG] EMERGENCY_RECEIVED_BACKGROUND")
                            }
                            Log.i("SAHARA-NOTIFY", "[SAHARA-NOTIFY] POSTING_EMERGENCY_NOTIFICATION")

                            // Wake physical screen immediately for emergency
                            SaharaMeshForegroundService.wakeScreen(this@MainActivity, 10000L)

                            val formattedTitle = when (severity.lowercase()) {
                                "evacuation" -> "🚨 EVACUATION ALERT: $title"
                                "warning" -> "⚠️ EMERGENCY WARNING: $title"
                                "advisory" -> "ℹ️ ADVISORY: $title"
                                else -> "🚨 SAHARA ALERT: $title"
                            }

                            val intent = Intent(this@MainActivity, MainActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                                putExtra("action", "open_broadcast")
                                putExtra("broadcastId", broadcastId)
                            }
                            val pendingIntent = PendingIntent.getActivity(
                                this@MainActivity,
                                broadcastId.hashCode(),
                                intent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )

                            // Full screen intent specifically designed to show over lock screen
                            val fullScreenIntent = Intent(this@MainActivity, MainActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                                putExtra("action", "open_broadcast")
                                putExtra("broadcastId", broadcastId)
                            }
                            val fullScreenPendingIntent = PendingIntent.getActivity(
                                this@MainActivity,
                                broadcastId.hashCode() + 1,
                                fullScreenIntent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )

                            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                            val builder = NotificationCompat.Builder(this@MainActivity, EMERGENCY_CHANNEL_ID)
                                .setSmallIcon(R.mipmap.ic_launcher)
                                .setContentTitle(formattedTitle)
                                .setContentText(message)
                                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                                .setPriority(NotificationCompat.PRIORITY_MAX)
                                .setCategory(NotificationCompat.CATEGORY_ALARM)
                                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                                .setAutoCancel(true)
                                .setContentIntent(pendingIntent)
                                .setFullScreenIntent(fullScreenPendingIntent, true)
                                .setSound(soundUri)
                                .setVibrate(longArrayOf(0, 500, 200, 500, 200, 500, 200, 800))

                            // Always trigger explicit hardware vibration
                            triggerDeviceVibration(longArrayOf(0, 500, 200, 500, 200, 500, 200, 800))
                            if (isBgOrLocked) {
                                Log.i("SAHARA-BG", "[SAHARA-BG] VIBRATION_TRIGGERED_BACKGROUND")
                            }

                            val notifManager = NotificationManagerCompat.from(this@MainActivity)
                            if (!notifManager.areNotificationsEnabled()) {
                                Log.e("SAHARA-NOTIFY", "[SAHARA-NOTIFY] NOTIFICATION_FAILED reason=NOTIFICATIONS_DISABLED_GLOBALLY")
                                result.success(false)
                                return@setMethodCallHandler
                            }

                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                                ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                Log.e("SAHARA-NOTIFY", "[SAHARA-NOTIFY] NOTIFICATION_FAILED reason=POST_NOTIFICATIONS_PERMISSION_DENIED")
                                result.success(false)
                                return@setMethodCallHandler
                            }

                            notifManager.notify(broadcastId.hashCode(), builder.build())
                            Log.i("SAHARA-NOTIFY", "[SAHARA-NOTIFY] NOTIFICATION_POSTED")
                            if (isBgOrLocked) {
                                Log.i("SAHARA-BG", "[SAHARA-BG] NOTIFICATION_POSTED_BACKGROUND")
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("SAHARA-NOTIFY", "[SAHARA-NOTIFY] NOTIFICATION_FAILED reason=${e.message}")
                            result.error("NOTIFICATION_ERROR", e.message, null)
                        }
                    }
                    "showFamilyMessageNotification" -> {
                        try {
                            val senderName = call.argument<String>("senderName") ?: "Family Member"
                            val content = call.argument<String>("content") ?: ""
                            val personId = call.argument<String>("personId") ?: "family"
                            val notificationId = ("family_$personId").hashCode()

                            val isBgOrLocked = SaharaMeshForegroundService.isScreenOff ||
                                SaharaMeshForegroundService.isDeviceLocked(this@MainActivity) ||
                                !SaharaMeshForegroundService.isDeviceInteractive(this@MainActivity)

                            if (isBgOrLocked) {
                                Log.i("SAHARA-BG", "[SAHARA-BG] PACKET_RECEIVED_BACKGROUND")
                            }
                            Log.i("SAHARA-NOTIFY", "[SAHARA-NOTIFY] POSTING_FAMILY_NOTIFICATION sender=$senderName")

                            // Wake physical screen for family message
                            SaharaMeshForegroundService.wakeScreen(this@MainActivity, 3000L)

                            val intent = Intent(this@MainActivity, MainActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                                putExtra("action", "open_chat")
                                putExtra("personId", personId)
                            }
                            val pendingIntent = PendingIntent.getActivity(
                                this@MainActivity,
                                notificationId,
                                intent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )

                            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                            val builder = NotificationCompat.Builder(this@MainActivity, FAMILY_CHANNEL_ID)
                                .setSmallIcon(R.mipmap.ic_launcher)
                                .setContentTitle("Family: $senderName")
                                .setContentText(content)
                                .setStyle(NotificationCompat.BigTextStyle().bigText(content))
                                .setPriority(NotificationCompat.PRIORITY_HIGH)
                                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                                .setAutoCancel(true)
                                .setContentIntent(pendingIntent)
                                .setSound(soundUri)
                                .setVibrate(longArrayOf(0, 250, 150, 250))

                            // Always trigger explicit hardware vibration
                            triggerDeviceVibration(longArrayOf(0, 250, 150, 250))
                            if (isBgOrLocked) {
                                Log.i("SAHARA-BG", "[SAHARA-BG] VIBRATION_TRIGGERED_BACKGROUND")
                            }

                            val notifManager = NotificationManagerCompat.from(this@MainActivity)
                            if (notifManager.areNotificationsEnabled()) {
                                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                                    ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                                    notifManager.notify(notificationId, builder.build())
                                    Log.i("SAHARA-NOTIFY", "[SAHARA-NOTIFY] NOTIFICATION_POSTED")
                                    if (isBgOrLocked) {
                                        Log.i("SAHARA-BG", "[SAHARA-BG] NOTIFICATION_POSTED_BACKGROUND")
                                    }
                                } else {
                                    Log.w("SAHARA-NOTIFY", "[SAHARA-NOTIFY] NOTIFICATION_FAILED reason=POST_NOTIFICATIONS_PERMISSION_DENIED")
                                }
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("SAHARA-NOTIFY", "[SAHARA-NOTIFY] NOTIFICATION_FAILED reason=${e.message}")
                            result.error("NOTIFICATION_ERROR", e.message, null)
                        }
                    }
                    "showPingNotification" -> {
                        try {
                            val senderName = call.argument<String>("senderName") ?: "Nearby Peer"
                            val personId = call.argument<String>("personId") ?: "peer"
                            val pingId = call.argument<String>("id") ?: "ping_${System.currentTimeMillis()}"
                            val notificationId = ("ping_$personId").hashCode()

                            val isBgOrLocked = SaharaMeshForegroundService.isScreenOff ||
                                SaharaMeshForegroundService.isDeviceLocked(this@MainActivity) ||
                                !SaharaMeshForegroundService.isDeviceInteractive(this@MainActivity)

                            if (isBgOrLocked) {
                                Log.i("SAHARA-BG", "[SAHARA-BG] PACKET_RECEIVED_BACKGROUND")
                            }
                            Log.i("SAHARA-PING", "[SAHARA-PING] RECEIVED id=$pingId")

                            // Wake physical screen for ping
                            SaharaMeshForegroundService.wakeScreen(this@MainActivity, 3000L)

                            val intent = Intent(this@MainActivity, MainActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                                putExtra("action", "open_chat")
                                putExtra("personId", personId)
                            }
                            val pendingIntent = PendingIntent.getActivity(
                                this@MainActivity,
                                notificationId,
                                intent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )

                            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                            val builder = NotificationCompat.Builder(this@MainActivity, PING_CHANNEL_ID)
                                .setSmallIcon(R.mipmap.ic_launcher)
                                .setContentTitle("📡 Peer Ping Alert")
                                .setContentText("$senderName pinged you to verify radio connectivity")
                                .setStyle(NotificationCompat.BigTextStyle().bigText("$senderName is reachable within direct radio range."))
                                .setPriority(NotificationCompat.PRIORITY_HIGH)
                                .setCategory(NotificationCompat.CATEGORY_EVENT)
                                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                                .setAutoCancel(true)
                                .setContentIntent(pendingIntent)
                                .setSound(soundUri)
                                .setVibrate(longArrayOf(0, 200, 100, 200))

                            // Always trigger explicit hardware vibration
                            triggerDeviceVibration(longArrayOf(0, 200, 100, 200))
                            Log.i("SAHARA-PING", "[SAHARA-PING] VIBRATION_TRIGGERED")
                            if (isBgOrLocked) {
                                Log.i("SAHARA-BG", "[SAHARA-BG] VIBRATION_TRIGGERED_BACKGROUND")
                            }

                            val notifManager = NotificationManagerCompat.from(this@MainActivity)
                            if (notifManager.areNotificationsEnabled()) {
                                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                                    ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                                    notifManager.notify(notificationId, builder.build())
                                    Log.i("SAHARA-PING", "[SAHARA-PING] NOTIFICATION_POSTED")
                                    if (isBgOrLocked) {
                                        Log.i("SAHARA-BG", "[SAHARA-BG] NOTIFICATION_POSTED_BACKGROUND")
                                    }
                                }
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("SAHARA-PING", "[SAHARA-PING] FAILED: ${e.message}")
                            result.error("PING_NOTIF_ERROR", e.message, null)
                        }
                    }
                    "vibrateDevice" -> {
                        val patternList = call.argument<List<Int>>("pattern")
                        val pattern = patternList?.map { it.toLong() }?.toLongArray()
                            ?: longArrayOf(0, 300, 150, 300)
                        triggerDeviceVibration(pattern)
                        result.success(true)
                    }
                    "getInitialNotification" -> {
                        val currentIntent = intent
                        val action = currentIntent?.getStringExtra("action")
                        if (action != null) {
                            val map = HashMap<String, String>()
                            map["action"] = action
                            currentIntent.getStringExtra("personId")?.let { map["personId"] = it }
                            currentIntent.getStringExtra("broadcastId")?.let { map["broadcastId"] = it }
                            currentIntent.removeExtra("action") // Consume once
                            result.success(map)
                        } else {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = intent.getStringExtra("action")
        if (action != null) {
            val map = HashMap<String, String>()
            map["action"] = action
            intent.getStringExtra("personId")?.let { map["personId"] = it }
            intent.getStringExtra("broadcastId")?.let { map["broadcastId"] = it }
            methodChannel?.invokeMethod("onNotificationClicked", map)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val res = pendingPermissionResult ?: return
            pendingPermissionResult = null
            val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            res.success(allGranted)
        } else if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            val res = pendingNotificationPermResult ?: return
            pendingNotificationPermResult = null
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (granted) {
                Log.i("SAHARA-NOTIFY", "[SAHARA-NOTIFY] PERMISSION_GRANTED")
            } else {
                Log.w("SAHARA-NOTIFY", "[SAHARA-NOTIFY] PERMISSION_DENIED")
            }
            res.success(granted)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_IMAGE_REQUEST) {
            val result = pendingPhotoResult ?: return
            pendingPhotoResult = null

            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri: Uri = data.data!!
                try {
                    val inputStream: InputStream? = contentResolver.openInputStream(uri)
                    val outputFile = File(filesDir, "profile_photo.jpg")
                    val outputStream = FileOutputStream(outputFile)
                    inputStream?.use { input ->
                        outputStream.use { output ->
                            input.copyTo(output)
                        }
                    }
                    result.success(outputFile.absolutePath)
                } catch (e: Exception) {
                    result.error("SAVE_PHOTO_ERROR", e.message, null)
                }
            } else {
                result.success(null)
            }
        }
    }
}
