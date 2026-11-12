package com.example.campusos_mobile

import android.Manifest
import android.content.pm.PackageManager
import android.app.NotificationManager
import io.flutter.plugin.common.MethodChannel.Result
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingNotificationResult: Result? = null

    private fun notificationsAllowed(): Boolean {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        return (Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) &&
            (Build.VERSION.SDK_INT < 24 || manager.areNotificationsEnabled())
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1701) {
            pendingNotificationResult?.success(notificationsAllowed())
            pendingNotificationResult = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "campusos/reminders")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            if (pendingNotificationResult != null) {
                                result.error("BUSY", "Permission request already in progress", null)
                            } else {
                                pendingNotificationResult = result
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1701)
                            }
                        } else result.success(notificationsAllowed())
                    }
                    "permissionStatus" -> result.success(notificationsAllowed())
                    "recentDelivered" -> result.success(ReminderReceiver.recentDelivered(this))
                    "clearHistory" -> { ReminderReceiver.clearHistory(this); result.success(true) }
                    "replaceSchedule" -> {
                        @Suppress("UNCHECKED_CAST")
                        val entries = call.arguments as? List<Map<String, Any?>>
                        if (entries == null) result.error("INVALID", "Expected reminders list", null)
                        else {
                            ReminderReceiver.replace(this, entries)
                            result.success(true)
                        }
                    }
                    "cancelAll" -> { ReminderReceiver.replace(this, emptyList()); result.success(true) }
                    else -> result.notImplemented()
                }
            }
    }
}
