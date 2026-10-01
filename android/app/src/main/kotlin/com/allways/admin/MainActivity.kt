package com.allways.admin

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    "allways_updates",
                    "ALLways Updates",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Order, delivery and ALLways alerts"
                    enableVibration(true)
                }
            )
        }
    }
}
