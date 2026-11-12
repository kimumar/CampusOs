package com.example.campusos_mobile

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/** Offline reminders; no student data leaves the handset. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel("academic", "Academic reminders", NotificationManager.IMPORTANCE_DEFAULT))
        val builder = if (Build.VERSION.SDK_INT >= 26)
            Notification.Builder(context, "academic") else Notification.Builder(context)
        builder.setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(intent.getStringExtra("title") ?: "CampusOS")
            .setContentText(intent.getStringExtra("body") ?: "Your academic reminder is ready.")
            .setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) builder.setContentIntent(PendingIntent.getActivity(context, 0, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        manager.notify(intent.getIntExtra("id", 0), builder.build())
        val prefs = context.getSharedPreferences(STORAGE, Context.MODE_PRIVATE)
        val records = JSONArray()
        records.put(JSONObject().put("title", intent.getStringExtra("title") ?: "CampusOS")
            .put("body", intent.getStringExtra("body") ?: "")
            .put("deliveredAt", System.currentTimeMillis()))
        val older = JSONArray(prefs.getString("recent", "[]"))
        for (i in 0 until minOf(older.length(), 2)) records.put(older.getJSONObject(i))
        prefs.edit().putString("recent", records.toString()).apply()
    }

    companion object {
        private const val STORAGE = "campusos_local_reminders"

        fun recentDelivered(context: Context): List<Map<String, Any>> {
            val prefs = context.getSharedPreferences(STORAGE, Context.MODE_PRIVATE)
            val array = JSONArray(prefs.getString("recent", "[]"))
            return (0 until minOf(array.length(), 3)).map { i ->
                val obj = array.getJSONObject(i)
                mapOf("title" to obj.optString("title"),
                      "body" to obj.optString("body"),
                      "deliveredAt" to obj.optLong("deliveredAt"))
            }
        }

        fun clearHistory(context: Context) {
            context.getSharedPreferences(STORAGE, Context.MODE_PRIVATE).edit().remove("recent").apply()
        }
        private fun pending(context: Context, id: Int, title: String, body: String): PendingIntent {
            val intent = Intent(context, ReminderReceiver::class.java)
                .putExtra("id", id).putExtra("title", title).putExtra("body", body)
            return PendingIntent.getBroadcast(context, id, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        fun replace(context: Context, entries: List<Map<String, Any?>>) {
            val prefs = context.getSharedPreferences(STORAGE, Context.MODE_PRIVATE)
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val prior = JSONArray(prefs.getString("items", "[]"))
            for (i in 0 until prior.length()) {
                val item = prior.getJSONObject(i)
                alarm.cancel(pending(context, item.getInt("id"), item.optString("title"), item.optString("body")))
            }
            val saved = JSONArray()
            val now = System.currentTimeMillis()
            for (entry in entries.take(64)) {
                val id = (entry["id"] as? Number)?.toInt() ?: continue
                val at = (entry["epochMillis"] as? Number)?.toLong() ?: continue
                if (at <= now || at > now + 35L * 24 * 60 * 60 * 1000) continue
                val title = (entry["title"] as? String ?: "CampusOS").take(90)
                val body = (entry["body"] as? String ?: "Study reminder").take(180)
                val obj = JSONObject().put("id", id).put("epochMillis", at)
                    .put("title", title).put("body", body)
                saved.put(obj)
                alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending(context, id, title, body))
            }
            prefs.edit().putString("items", saved.toString()).apply()
        }

        fun restore(context: Context) {
            val prefs = context.getSharedPreferences(STORAGE, Context.MODE_PRIVATE)
            val items = JSONArray(prefs.getString("items", "[]"))
            val records = mutableListOf<Map<String, Any?>>()
            for (i in 0 until items.length()) {
                val o = items.getJSONObject(i)
                records.add(mapOf("id" to o.getInt("id"), "epochMillis" to o.getLong("epochMillis"),
                    "title" to o.optString("title"), "body" to o.optString("body")))
            }
            replace(context, records)
        }
    }
}

class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) ReminderReceiver.restore(context)
    }
}
