package com.example.neuropause

import android.app.Notification
import android.content.pm.PackageManager
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.Collections

class NeuroNotificationListenerService : NotificationListenerService() {

    companion object {
        var instance: NeuroNotificationListenerService? = null
            private set

        private val capturedNotificationsList = Collections.synchronizedList(mutableListOf<Map<String, Any>>())
        var onNotificationReceived: ((Map<String, Any>) -> Unit)? = null
        var onNotificationRemovedCallback: ((Map<String, Any>) -> Unit)? = null

        fun getCapturedNotifications(): List<Map<String, Any>> {
            synchronized(capturedNotificationsList) {
                return capturedNotificationsList.toList()
            }
        }

        fun clearNotifications() {
            capturedNotificationsList.clear()
        }

        fun isConnected(): Boolean = instance != null
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        fetchActiveNotifications()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        if (instance == this) {
            instance = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) {
            instance = null
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return
        processNotification(sbn, emitLive = true)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        if (sbn == null) return
        val id = sbn.key ?: "${sbn.packageName}_${sbn.id}_${sbn.postTime}"
        onNotificationRemovedCallback?.invoke(
            mapOf(
                "eventType" to "removed",
                "id" to id,
                "packageName" to (sbn.packageName ?: "")
            )
        )
    }

    fun fetchActiveNotifications() {
        try {
            val active = activeNotifications ?: return
            for (sbn in active) {
                processNotification(sbn, emitLive = false)
            }
        } catch (_: Exception) {
        }
    }

    private fun processNotification(sbn: StatusBarNotification, emitLive: Boolean) {
        try {
            val pkg = sbn.packageName ?: return
            // Ignore self notifications
            if (pkg == packageName) return

            val notification = sbn.notification ?: return
            val extras = notification.extras ?: return

            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim()
            val text = (extras.getCharSequence(Notification.EXTRA_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT))?.toString()?.trim()
            val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()?.trim()

            // Filter out completely empty items
            if ((title.isNullOrEmpty()) && (text.isNullOrEmpty())) {
                return
            }

            var appLabel = pkg
            try {
                val pm = applicationContext.packageManager
                val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    pm.getApplicationInfo(pkg, PackageManager.ApplicationInfoFlags.of(0))
                } else {
                    @Suppress("DEPRECATION")
                    pm.getApplicationInfo(pkg, 0)
                }
                appLabel = pm.getApplicationLabel(appInfo).toString()
            } catch (_: Exception) {
            }

            // Android native importance / priority
            val nativePriority = notification.priority
            val nativeImportanceLabel = when (nativePriority) {
                Notification.PRIORITY_MAX -> "Max"
                Notification.PRIORITY_HIGH -> "High"
                Notification.PRIORITY_LOW -> "Low"
                Notification.PRIORITY_MIN -> "Min"
                else -> "Default"
            }
            val nativeChannelId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                notification.channelId ?: ""
            } else {
                ""
            }

            val item = mapOf(
                "eventType" to "posted",
                "id" to (sbn.key ?: "${pkg}_${sbn.id}_${sbn.postTime}"),
                "packageName" to pkg,
                "appName" to appLabel,
                "title" to (title ?: appLabel),
                "message" to (text ?: subText ?: ""),
                "postTime" to sbn.postTime,
                "category" to (notification.category ?: ""),
                "nativeImportance" to nativeImportanceLabel,
                "nativeChannelId" to nativeChannelId,
                "isClearable" to sbn.isClearable
            )

            synchronized(capturedNotificationsList) {
                capturedNotificationsList.removeAll { it["id"] == item["id"] }
                capturedNotificationsList.add(0, item)
                if (capturedNotificationsList.size > 100) {
                    capturedNotificationsList.removeAt(capturedNotificationsList.size - 1)
                }
            }

            if (emitLive) {
                onNotificationReceived?.invoke(item)
            }
        } catch (_: Exception) {
        }
    }
}
