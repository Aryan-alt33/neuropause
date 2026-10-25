import 'dart:async';
import 'package:flutter/services.dart';

class AndroidNotificationService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.neuropause/notifications');
  static const EventChannel _eventChannel =
      EventChannel('com.example.neuropause/notification_events');

  static Future<bool> isNotificationAccessGranted() async {
    try {
      final bool? granted =
          await _methodChannel.invokeMethod<bool>('isNotificationAccessGranted');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openNotificationSettings() async {
    try {
      final bool? opened =
          await _methodChannel.invokeMethod<bool>('openNotificationSettings');
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final List<dynamic>? raw =
          await _methodChannel.invokeMethod<List<dynamic>>('getNotifications');
      if (raw == null) return [];
      return raw.map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return <String, dynamic>{};
      }).where((m) => m.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearNotifications() async {
    try {
      await _methodChannel.invokeMethod('clearNotifications');
    } catch (_) {}
  }

  static Stream<Map<String, dynamic>> get onNotificationReceived {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{};
    });
  }
}
