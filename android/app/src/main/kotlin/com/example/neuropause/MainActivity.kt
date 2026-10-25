package com.example.neuropause

import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.example.neuropause/notifications"
    private val EVENT_CHANNEL = "com.example.neuropause/notification_events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationAccessGranted" -> {
                    val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(context)
                    val isGranted = enabledPackages.contains(context.packageName)
                    result.success(isGranted)
                }
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getNotifications" -> {
                    try {
                        NeuroNotificationListenerService.instance?.fetchActiveNotifications()
                    } catch (_: Exception) {
                    }
                    result.success(NeuroNotificationListenerService.getCapturedNotifications())
                }
                "clearNotifications" -> {
                    NeuroNotificationListenerService.clearNotifications()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NeuroNotificationListenerService.onNotificationReceived = { item ->
                        runOnUiThread {
                            events?.success(item)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    NeuroNotificationListenerService.onNotificationReceived = null
                }
            }
        )
    }
}
