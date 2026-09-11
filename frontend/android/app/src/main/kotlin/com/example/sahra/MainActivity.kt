package com.example.sahra

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.BatteryManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.sahra/native"
    private val PICK_IMAGE_REQUEST = 1001
    private var pendingPhotoResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
                else -> result.notImplemented()
            }
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
