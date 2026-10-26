import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'services/android_notification_service.dart';

enum NotificationPriority {
  critical, // P1: deliver immediately and bypass batching
  high,     // P2: deliver after a short configurable delay
  normal,   // P3: deliver in the regular scheduled batch
  low,      // P4: hold until the next break or scheduled review
}

extension NotificationPriorityExt on NotificationPriority {
  String get code {
    switch (this) {
      case NotificationPriority.critical:
        return 'P1';
      case NotificationPriority.high:
        return 'P2';
      case NotificationPriority.normal:
        return 'P3';
      case NotificationPriority.low:
        return 'P4';
    }
  }

  String get label {
    switch (this) {
      case NotificationPriority.critical:
        return 'P1 Critical';
      case NotificationPriority.high:
        return 'P2 High';
      case NotificationPriority.normal:
        return 'P3 Normal';
      case NotificationPriority.low:
        return 'P4 Low';
    }
  }

  String get shortTitle {
    switch (this) {
      case NotificationPriority.critical:
        return 'Critical';
      case NotificationPriority.high:
        return 'High';
      case NotificationPriority.normal:
        return 'Normal';
      case NotificationPriority.low:
        return 'Low';
    }
  }

  String get description {
    switch (this) {
      case NotificationPriority.critical:
        return 'Immediate bypass • Delivers without pause delay';
      case NotificationPriority.high:
        return 'Short delay batch • Fast-tracked review';
      case NotificationPriority.normal:
        return 'Regular scheduled batch • Paused for focus';
      case NotificationPriority.low:
        return 'Held for mindful break or evening review';
    }
  }

  Color get color {
    switch (this) {
      case NotificationPriority.critical:
        return const Color(0xFFDC2626); // Red
      case NotificationPriority.high:
        return const Color(0xFFD97706); // Amber
      case NotificationPriority.normal:
        return const Color(0xFF2E7D32); // Sage / Forest Green
      case NotificationPriority.low:
        return const Color(0xFF5A6E63); // Muted Slate
    }
  }

  Color get bgColor {
    switch (this) {
      case NotificationPriority.critical:
        return const Color(0xFFFFF1F1);
      case NotificationPriority.high:
        return const Color(0xFFFFFBEB);
      case NotificationPriority.normal:
        return const Color(0xFFF0FDF4);
      case NotificationPriority.low:
        return const Color(0xFFF1F5F3);
    }
  }

  Color get borderColor {
    switch (this) {
      case NotificationPriority.critical:
        return const Color(0xFFFECACA);
      case NotificationPriority.high:
        return const Color(0xFFFDE68A);
      case NotificationPriority.normal:
        return const Color(0xFFBBF7D0);
      case NotificationPriority.low:
        return const Color(0xFFD5DFD9);
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationPriority.critical:
        return Icons.emergency_rounded;
      case NotificationPriority.high:
        return Icons.priority_high_rounded;
      case NotificationPriority.normal:
        return Icons.schedule_rounded;
      case NotificationPriority.low:
        return Icons.spa_outlined;
    }
  }
}

class PauseNotificationItem {
  final String id;
  final String packageName;
  final String sender;
  final String appName;
  final IconData appIcon;
  final String title;
  final String message;
  final int postTime;
  final String timestamp;
  NotificationPriority priority;
  final String nativeImportance;
  final String nativeChannelId;
  bool isDelivered;
  bool isDismissed;

  PauseNotificationItem({
    required this.id,
    required this.packageName,
    required this.sender,
    required this.appName,
    required this.appIcon,
    required this.title,
    required this.message,
    required this.postTime,
    required this.timestamp,
    required this.priority,
    required this.nativeImportance,
    this.nativeChannelId = '',
    this.isDelivered = false,
    this.isDismissed = false,
  });

  String getPolicyLabel(int p2DelayMinutes, {DateTime? pauseEndTime, bool isPauseActive = true}) {
    if (!isPauseActive) {
      return 'Delivered • Pause inactive';
    }
    if (isDelivered) {
      return 'Delivered • Ready in your notifications';
    }
    switch (priority) {
      case NotificationPriority.critical:
        return 'Allowed Through • Immediate Bypass';
      case NotificationPriority.high:
        final ageSeconds = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(postTime))
            .inSeconds;
        final remainingSeconds = (p2DelayMinutes * 60) - ageSeconds;
        if (remainingSeconds > 60) {
          final remMins = (remainingSeconds / 60).ceil();
          return 'Batched • Delivers in ${remMins}m (Short Delay)';
        } else if (remainingSeconds > 0) {
          return 'Batched • Delivers in <1m (Short Delay)';
        } else {
          return 'Ready for delivery • Short Delay elapsed';
        }
      case NotificationPriority.normal:
        if (pauseEndTime != null) {
          final diff = pauseEndTime.difference(DateTime.now());
          if (diff.inSeconds > 0) {
            if (diff.inMinutes >= 60) {
              final hrs = diff.inHours;
              final remMins = diff.inMinutes % 60;
              return 'Batched • Delivers in ${hrs}h ${remMins}m (Pause Batch)';
            } else if (diff.inMinutes > 0) {
              return 'Batched • Delivers in ${diff.inMinutes}m (Pause Batch)';
            } else {
              return 'Batched • Delivers in <1m (Pause Batch)';
            }
          }
        }
        return 'Batched for Break • Scheduled Pause Release';
      case NotificationPriority.low:
        return 'Silenced • Kept for Evening / Break Review';
    }
  }
}

class NotificationPauseScreen extends StatefulWidget {
  static const String routeName = '/notification-pause';

  const NotificationPauseScreen({super.key});

  @override
  State<NotificationPauseScreen> createState() => _NotificationPauseScreenState();
}

class _NotificationPauseScreenState extends State<NotificationPauseScreen>
    with WidgetsBindingObserver {
  static const String _prefPrioritiesKey = 'neuropause_priority_overrides_v2';
  static const String _prefDismissedKey = 'neuropause_dismissed_ids_v2';
  static const String _prefDeliveredKey = 'neuropause_delivered_ids_v2';
  static const String _prefP2DelayKey = 'neuropause_p2_delay_minutes';

  bool _isPauseActive = true;
  String _selectedFilter = 'All';
  String _selectedDuration = '1 hour';
  DateTime? _pauseEndTime;
  Timer? _lifecycleTimer;

  int _p2DelayMinutes = 5; // Default short delay for P2 High

  bool _hasPermission = false;
  bool _isDemoMode = false;
  bool _isLoading = false;

  Map<String, String> _persistedPriorities = {};
  Set<String> _dismissedIds = {};
  Set<String> _deliveredIds = {};

  List<PauseNotificationItem> _notifications = [];
  List<PauseNotificationItem> _sampleNotifications = [];
  List<PauseNotificationItem> _realNotifications = [];
  StreamSubscription<Map<String, dynamic>>? _liveSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pauseEndTime = _calculatePauseEndTime(_selectedDuration);
    _initSampleNotifications();
    _loadPreferences().then((_) {
      _checkPermissionAndRefresh();
    });
    _listenToLiveNotifications();
    _lifecycleTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkScheduledDeliveries();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveSubscription?.cancel();
    _lifecycleTimer?.cancel();
    super.dispose();
  }

  DateTime _calculatePauseEndTime(String duration) {
    final now = DateTime.now();
    switch (duration) {
      case '15 mins':
        return now.add(const Duration(minutes: 15));
      case '30 mins':
        return now.add(const Duration(minutes: 30));
      case '1 hour':
        return now.add(const Duration(hours: 1));
      case '2 hours':
        return now.add(const Duration(hours: 2));
      case 'Until 6 PM':
        final sixPm = DateTime(now.year, now.month, now.day, 18, 0);
        if (now.isBefore(sixPm)) {
          return sixPm;
        } else {
          return sixPm.add(const Duration(days: 1));
        }
      default:
        return now.add(const Duration(hours: 1));
    }
  }

  String _getScheduledReleaseText() {
    if (!_isPauseActive || _pauseEndTime == null) return '';
    final diff = _pauseEndTime!.difference(DateTime.now());
    if (diff.isNegative || diff.inSeconds <= 0) return ' (ready for batch release)';
    if (diff.inMinutes < 1) return ' (releases in <1m)';
    return ' (releases in ${diff.inMinutes}m)';
  }

  void _checkScheduledDeliveries() {
    if (!mounted) return;
    final now = DateTime.now();

    // 1. Check if scheduled pause duration has elapsed (release P2/P3 batch)
    if (_isPauseActive && _pauseEndTime != null && now.isAfter(_pauseEndTime!)) {
      int released = 0;
      for (final n in _notifications) {
        if (!n.isDismissed && !n.isDelivered &&
            (n.priority == NotificationPriority.high || n.priority == NotificationPriority.normal)) {
          n.isDelivered = true;
          _deliveredIds.add(n.id);
          released++;
        }
      }
      if (released > 0) {
        _savePreferences();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scheduled pause batch delivered ($released notifications).'),
            backgroundColor: AppColors.sagePrimary,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      // Reset cycle for next scheduled batch interval
      _pauseEndTime = _calculatePauseEndTime(_selectedDuration);
    }

    // 2. Check P2 High notifications: deliver if _p2DelayMinutes passed since postTime
    bool p2Changed = false;
    for (final n in _notifications) {
      if (!n.isDismissed && !n.isDelivered && n.priority == NotificationPriority.high) {
        final postDateTime = DateTime.fromMillisecondsSinceEpoch(n.postTime);
        final elapsedSeconds = now.difference(postDateTime).inSeconds;
        if (elapsedSeconds >= _p2DelayMinutes * 60) {
          n.isDelivered = true;
          _deliveredIds.add(n.id);
          p2Changed = true;
        }
      }
    }
    if (p2Changed) {
      _savePreferences();
    }

    // Refresh timestamps and policy status labels periodically
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndRefresh();
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _p2DelayMinutes = prefs.getInt(_prefP2DelayKey) ?? 5;

      final rawPriorities = prefs.getString(_prefPrioritiesKey);
      if (rawPriorities != null && rawPriorities.isNotEmpty) {
        final decoded = jsonDecode(rawPriorities);
        if (decoded is Map) {
          _persistedPriorities = Map<String, String>.from(decoded);
        }
      }

      final rawDismissed = prefs.getStringList(_prefDismissedKey);
      if (rawDismissed != null) {
        _dismissedIds = Set<String>.from(rawDismissed);
      }

      final rawDelivered = prefs.getStringList(_prefDeliveredKey);
      if (rawDelivered != null) {
        _deliveredIds = Set<String>.from(rawDelivered);
      }
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefP2DelayKey, _p2DelayMinutes);
      await prefs.setString(
          _prefPrioritiesKey, jsonEncode(_persistedPriorities));
      await prefs.setStringList(
          _prefDismissedKey, _dismissedIds.toList());
      await prefs.setStringList(
          _prefDeliveredKey, _deliveredIds.toList());
    } catch (_) {}
  }

  void _initSampleNotifications() {
    _sampleNotifications = [
      PauseNotificationItem(
        id: 'sample_p1_1',
        packageName: 'com.healthcare.emergency',
        sender: 'Dr. Elena Vance (Family Clinic)',
        appName: 'Health & Care',
        appIcon: Icons.local_hospital_rounded,
        title: 'Appointment Confirmation Needed',
        message:
            'Please confirm your lab review scheduled for tomorrow at 9:30 AM.',
        postTime: DateTime.now().subtract(const Duration(minutes: 2)).millisecondsSinceEpoch,
        timestamp: '2m ago',
        priority: NotificationPriority.critical,
        nativeImportance: 'High',
        isDelivered: true,
      ),
      PauseNotificationItem(
        id: 'sample_p2_1',
        packageName: 'com.whatsapp',
        sender: 'Sarah Jenkins (Project Lead)',
        appName: 'WhatsApp',
        appIcon: Icons.chat_bubble_outline_rounded,
        title: 'Quarterly Review Sync',
        message:
            'Could you review slides 4-8 before our strategy call in 15m?',
        postTime: DateTime.now().subtract(const Duration(minutes: 6)).millisecondsSinceEpoch,
        timestamp: '6m ago',
        priority: NotificationPriority.high,
        nativeImportance: 'High',
        isDelivered: false,
      ),
      PauseNotificationItem(
        id: 'sample_p3_1',
        packageName: 'com.slack',
        sender: 'Work Workspace #team-dev',
        appName: 'Slack',
        appIcon: Icons.work_outline_rounded,
        title: 'Sprint Planning Updates',
        message:
            'Sprint 14 backlog refinement is finalized. Please review Jira tickets.',
        postTime: DateTime.now().subtract(const Duration(minutes: 25)).millisecondsSinceEpoch,
        timestamp: '25m ago',
        priority: NotificationPriority.normal,
        nativeImportance: 'Default',
        isDelivered: false,
      ),
      PauseNotificationItem(
        id: 'sample_p4_1',
        packageName: 'com.medium.reader',
        sender: 'Mindful Reads Weekly Digest',
        appName: 'Medium',
        appIcon: Icons.menu_book_rounded,
        title: 'Declutter Your Evening Digital Habits',
        message:
            '5 research-backed strategies to reduce stress before bedtime.',
        postTime: DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
        timestamp: '1h ago',
        priority: NotificationPriority.low,
        nativeImportance: 'Low',
        isDelivered: false,
      ),
    ];
    _notifications = List.from(_sampleNotifications);
  }

  Future<void> _checkPermissionAndRefresh() async {
    final granted =
        await AndroidNotificationService.isNotificationAccessGranted();
    if (!mounted) return;
    setState(() {
      _hasPermission = granted;
    });

    if (granted && !_isDemoMode) {
      await _fetchRealNotifications();
    } else if (_isDemoMode || _realNotifications.isEmpty) {
      setState(() {
        _notifications = List.from(_sampleNotifications);
      });
    }
  }

  Future<void> _fetchRealNotifications() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final rawList = await AndroidNotificationService.getNotifications();
      if (!mounted) return;
      if (rawList.isNotEmpty) {
        final List<PauseNotificationItem> updated = [];
        for (final raw in rawList) {
          final id = (raw['id'] as String?) ?? '';
          if (_dismissedIds.contains(id)) continue;
          final item = _mapNativeNotification(raw);
          // Preserve in-memory delivered state across refreshes
          final wasDelivered = _notifications.any((n) =>
              (n.id == item.id ||
                  (n.packageName == item.packageName &&
                      n.title == item.title &&
                      n.message == item.message)) &&
              n.isDelivered);
          if (wasDelivered || _deliveredIds.contains(item.id)) {
            item.isDelivered = true;
          }
          // Duplicate prevention: avoid inserting duplicate items with same package, title, and message
          final isDuplicate = updated.any((existing) =>
              existing.id == item.id ||
              (existing.packageName == item.packageName &&
                  existing.title == item.title &&
                  existing.message == item.message));
          if (!isDuplicate) {
            updated.add(item);
          }
        }
        setState(() {
          _realNotifications = updated;
          if (!_isDemoMode) {
            _notifications = List.from(_realNotifications);
          }
        });
      } else {
        if (!_isDemoMode && _notifications.isEmpty) {
          setState(() {
            _notifications = List.from(_sampleNotifications);
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _listenToLiveNotifications() {
    _liveSubscription =
        AndroidNotificationService.onNotificationReceived.listen((raw) {
      if (!mounted) return;

      final eventType = raw['eventType'] as String? ?? 'posted';
      final id = (raw['id'] as String?) ?? '';

      if (eventType == 'removed') {
        setState(() {
          _realNotifications.removeWhere((n) => n.id == id);
          _notifications.removeWhere((n) => n.id == id);
        });
        return;
      }

      if (_dismissedIds.contains(id)) return;

      final item = _mapNativeNotification(raw);
      setState(() {
        // Handle notification update in-place safely with duplicate prevention
        final existingRealIndex = _realNotifications.indexWhere((n) =>
            n.id == item.id ||
            (n.packageName == item.packageName &&
                n.title == item.title &&
                n.message == item.message));
        if (existingRealIndex >= 0) {
          final existing = _realNotifications[existingRealIndex];
          // Preserve manual priority, isDelivered, isDismissed
          item.priority = existing.priority;
          item.isDelivered = existing.isDelivered;
          item.isDismissed = existing.isDismissed;
          _realNotifications[existingRealIndex] = item;
        } else {
          _realNotifications.insert(0, item);
        }

        if (!_isDemoMode) {
          final displayIndex = _notifications.indexWhere((n) =>
              n.id == item.id ||
              (n.packageName == item.packageName &&
                  n.title == item.title &&
                  n.message == item.message));
          if (displayIndex >= 0) {
            final existing = _notifications[displayIndex];
            item.priority = existing.priority;
            item.isDismissed = existing.isDismissed;
            if (item.priority == NotificationPriority.critical) {
              item.isDelivered = true;
            } else if (existing.message == item.message &&
                existing.postTime == item.postTime) {
              item.isDelivered = existing.isDelivered;
            } else {
              item.isDelivered = !_isPauseActive;
            }
            _notifications[displayIndex] = item;
          } else {
            _notifications.insert(0, item);
          }
        }
      });
    });
  }

  PauseNotificationItem _mapNativeNotification(Map<String, dynamic> raw) {
    final id = (raw['id'] as String?) ?? UniqueKey().toString();
    final title = (raw['title'] as String?)?.trim() ?? '';
    final message = (raw['message'] as String?)?.trim() ?? '';
    final appName = (raw['appName'] as String?)?.trim() ?? 'App';
    final pkg = (raw['packageName'] as String?)?.toLowerCase() ?? '';
    final postTime = raw['postTime'] is int
        ? raw['postTime'] as int
        : DateTime.now().millisecondsSinceEpoch;
    final nativeImportance = (raw['nativeImportance'] as String?) ?? 'Default';
    final nativeChannelId = (raw['nativeChannelId'] as String?) ?? '';

    final senderName = title.isNotEmpty ? title : appName;
    final combined = '$title $message $appName'.toLowerCase();

    // Check if user manually assigned priority previously for this stable ID or sender
    NotificationPriority priority;
    final savedCode = _persistedPriorities[id] ??
        _persistedPriorities['$pkg:$senderName'];

    if (savedCode != null) {
      priority = NotificationPriority.values.firstWhere(
        (p) => p.name == savedCode,
        orElse: () => _classifyDefault(combined, pkg),
      );
    } else {
      priority = _classifyDefault(combined, pkg);
    }

    IconData icon;
    if (pkg.contains('whatsapp') ||
        pkg.contains('messaging') ||
        pkg.contains('mms') ||
        pkg.contains('telegram')) {
      icon = Icons.chat_bubble_outline_rounded;
    } else if (pkg.contains('mail') || pkg.contains('gm')) {
      icon = Icons.mail_outline_rounded;
    } else if (pkg.contains('slack') || pkg.contains('teams')) {
      icon = Icons.work_outline_rounded;
    } else if (pkg.contains('hospital') ||
        pkg.contains('health') ||
        combined.contains('clinic')) {
      icon = Icons.local_hospital_rounded;
    } else {
      icon = Icons.notifications_none_rounded;
    }

    final diff = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(postTime));
    String timeStr;
    if (diff.inMinutes < 1) {
      timeStr = 'Just now';
    } else if (diff.inMinutes < 60) {
      timeStr = '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      timeStr = '${diff.inHours}h ago';
    } else {
      timeStr = '${diff.inDays}d ago';
    }

    // Critical notifications bypass batching immediately, delivered IDs stay delivered
    final isDelivered = priority == NotificationPriority.critical ||
        _deliveredIds.contains(id) ||
        !_isPauseActive;

    return PauseNotificationItem(
      id: id,
      packageName: pkg,
      sender: senderName,
      appName: appName,
      appIcon: icon,
      title: title.isNotEmpty ? title : appName,
      message: message.isNotEmpty ? message : 'New notification',
      postTime: postTime,
      timestamp: timeStr,
      priority: priority,
      nativeImportance: nativeImportance,
      nativeChannelId: nativeChannelId,
      isDelivered: isDelivered,
    );
  }

  NotificationPriority _classifyDefault(String combined, String pkg) {
    if (combined.contains('urgent') ||
        combined.contains('emergency') ||
        combined.contains('otp') ||
        combined.contains('verification') ||
        combined.contains('security alert') ||
        combined.contains('hospital') ||
        combined.contains('doctor') ||
        combined.contains('code:')) {
      return NotificationPriority.critical; // P1
    } else if (pkg.contains('whatsapp') ||
        pkg.contains('slack') ||
        pkg.contains('teams') ||
        pkg.contains('telegram') ||
        pkg.contains('messaging') ||
        combined.contains('chat') ||
        combined.contains('message') ||
        combined.contains('whatsapp')) {
      return NotificationPriority.high; // P2 (communication)
    } else if (pkg.contains('gm') ||
        pkg.contains('mail') ||
        pkg.contains('discord') ||
        pkg.contains('work') ||
        combined.contains('mail') ||
        combined.contains('digest') ||
        combined.contains('newsletter') ||
        combined.contains('sprint')) {
      return NotificationPriority.normal; // P3 (work/mail batch)
    } else {
      return NotificationPriority.low; // P4 (digest/can wait)
    }
  }

  void _updatePriority(PauseNotificationItem item, NotificationPriority newPriority) {
    setState(() {
      item.priority = newPriority;
      if (newPriority == NotificationPriority.critical) {
        item.isDelivered = true;
      }
    });

    // Persist classification by stable ID and package/sender
    _persistedPriorities[item.id] = newPriority.name;
    _persistedPriorities['${item.packageName}:${item.sender}'] = newPriority.name;
    _savePreferences();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(newPriority.icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Moved "${item.sender}" to ${newPriority.label}.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: newPriority.color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _deliverSingleNotification(PauseNotificationItem item) {
    setState(() {
      item.isDelivered = true;
      _deliveredIds.add(item.id);
    });
    _savePreferences();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Delivered "${item.title}" immediately.'),
        backgroundColor: AppColors.sagePrimary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _deliverSection(NotificationPriority priority) {
    int count = 0;
    setState(() {
      for (final n in _notifications) {
        if (!n.isDismissed && n.priority == priority && !n.isDelivered) {
          n.isDelivered = true;
          _deliveredIds.add(n.id);
          count++;
        }
      }
    });
    _savePreferences();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Delivered $count ${priority.label} notifications now.'),
        backgroundColor: priority.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _deliverAllBatched() {
    int count = 0;
    setState(() {
      for (final n in _notifications) {
        if (!n.isDismissed && !n.isDelivered && n.priority != NotificationPriority.critical) {
          n.isDelivered = true;
          _deliveredIds.add(n.id);
          count++;
        }
      }
    });
    _savePreferences();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Delivered $count batched notifications across all levels.'),
        backgroundColor: AppColors.sagePrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _dismissNotification(PauseNotificationItem item) {
    setState(() {
      item.isDismissed = true;
      _dismissedIds.add(item.id);
    });
    _savePreferences();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dismissed notification from ${item.sender}.'),
        backgroundColor: AppColors.forestTextPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.paleMintSurface,
          onPressed: () {
            setState(() {
              item.isDismissed = false;
              _dismissedIds.remove(item.id);
            });
            _savePreferences();
          },
        ),
      ),
    );
  }

  List<PauseNotificationItem> get _activeNotifications =>
      _notifications.where((n) => !n.isDismissed).toList();

  List<PauseNotificationItem> _itemsForPriority(NotificationPriority p) =>
      _activeNotifications.where((n) => n.priority == p).toList();

  int get _batchedCount => _activeNotifications
      .where((n) => !n.isDelivered && n.priority != NotificationPriority.critical)
      .length;

  @override
  Widget build(BuildContext context) {
    final activeCount = _activeNotifications.length;

    return Scaffold(
      backgroundColor: AppColors.paleMintBg,
      appBar: AppBar(
        backgroundColor: AppColors.paleMintBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.forestTextPrimary,
            size: 20,
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/');
            }
          },
          tooltip: 'Back',
        ),
        title: const Text(
          'Notification Pause',
          style: TextStyle(
            color: AppColors.forestTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: _isDemoMode ? const Color(0xFFF0F5F2) : AppColors.paleMintSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderSage),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _isDemoMode = !_isDemoMode;
                  if (_isDemoMode) {
                    _notifications = List.from(_sampleNotifications);
                  } else {
                    if (_realNotifications.isNotEmpty) {
                      _notifications = List.from(_realNotifications);
                    } else {
                      _checkPermissionAndRefresh();
                    }
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isDemoMode
                        ? 'Showing Demo / Fallback 4-level notifications.'
                        : 'Switched to Live Real notifications.'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isDemoMode ? Icons.play_arrow_outlined : Icons.sensors_rounded,
                      size: 14,
                      color: _isDemoMode ? AppColors.forestTextSecondary : AppColors.sagePrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isDemoMode ? 'Demo' : 'Live',
                      style: TextStyle(
                        color: _isDemoMode ? AppColors.forestTextSecondary : AppColors.sagePrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.sagePrimary,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: AppColors.sagePrimary),
            tooltip: 'Refresh Notifications',
            onPressed: () {
              if (_isDemoMode) {
                setState(() {
                  _initSampleNotifications();
                  _isPauseActive = true;
                });
              } else {
                _checkPermissionAndRefresh();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_hasPermission) ...[
              _buildPermissionBanner(),
              const SizedBox(height: 14),
            ],

            // Status hero card
            _buildStatusHeroCard(),

            const SizedBox(height: 20),

            // Duration selector pills
            if (_isPauseActive) ...[
              _buildDurationSelector(),
              const SizedBox(height: 24),
            ],

            // Section header & filter chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '4-Tier Priority Feed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestTextPrimary,
                  ),
                ),
                Text(
                  '$activeCount active notifications',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.forestTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Filter Tabs (All, P1, P2, P3, P4)
            _buildFilterTabs(),

            const SizedBox(height: 16),

            // Four clearly separated sections or single filtered section
            if (_selectedFilter == 'All') ...[
              _buildSectionBlock(NotificationPriority.critical),
              const SizedBox(height: 18),
              _buildSectionBlock(NotificationPriority.high),
              const SizedBox(height: 18),
              _buildSectionBlock(NotificationPriority.normal),
              const SizedBox(height: 18),
              _buildSectionBlock(NotificationPriority.low),
            ] else if (_selectedFilter == 'P1 Critical') ...[
              _buildSectionBlock(NotificationPriority.critical, isExpanded: true),
            ] else if (_selectedFilter == 'P2 High') ...[
              _buildSectionBlock(NotificationPriority.high, isExpanded: true),
            ] else if (_selectedFilter == 'P3 Normal') ...[
              _buildSectionBlock(NotificationPriority.normal, isExpanded: true),
            ] else if (_selectedFilter == 'P4 Low') ...[
              _buildSectionBlock(NotificationPriority.low, isExpanded: true),
            ],

            const SizedBox(height: 20),

            // Batch action button if any items batched
            if (_batchedCount > 0 && _isPauseActive)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton.icon(
                  onPressed: _deliverAllBatched,
                  icon: const Icon(Icons.unarchive_outlined, size: 18),
                  label: Text('Deliver All Batched Items Now ($_batchedCount)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.sagePrimary,
                    elevation: 0,
                    side: const BorderSide(color: AppColors.borderSage, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

            // Mindful info guide
            _buildMindfulGuideBox(),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0D59D), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14795548),
            offset: Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFBE6BF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFF9E6539),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Notification Access Needed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF5A390C),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Allow NeuroPause to pause & batch incoming notifications in Android Settings.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A5826),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () async {
              await AndroidNotificationService.openNotificationSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9E6539),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Enable',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isPauseActive ? AppColors.sagePrimary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: _isPauseActive
            ? null
            : Border.all(color: AppColors.borderSage, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSage,
            offset: Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isPauseActive
                      ? const Color(0x2EFFFFFF)
                      : AppColors.paleMintSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isPauseActive
                      ? Icons.notifications_paused_rounded
                      : Icons.notifications_active_rounded,
                  color: _isPauseActive ? Colors.white : AppColors.sagePrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPauseActive ? 'Pause is Active' : 'Pause is Off',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isPauseActive
                            ? Colors.white
                            : AppColors.forestTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isPauseActive
                          ? 'Protecting your focus with 4-tier filtering'
                          : 'Standard notification delivery',
                      style: TextStyle(
                        fontSize: 13,
                        color: _isPauseActive
                            ? const Color(0xD9FFFFFF)
                            : AppColors.forestTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _isPauseActive,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.sageSwitchTrack,
                inactiveThumbColor: AppColors.sagePrimary,
                inactiveTrackColor: AppColors.sageInactive,
                onChanged: (val) {
                  setState(() {
                    _isPauseActive = val;
                    if (val) {
                      _pauseEndTime = _calculatePauseEndTime(_selectedDuration);
                    } else {
                      // Turning pause OFF releases all batched items immediately
                      for (final n in _notifications) {
                        if (!n.isDismissed && !n.isDelivered) {
                          n.isDelivered = true;
                        }
                      }
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _isPauseActive
                  ? const Color(0x24FFFFFF)
                  : AppColors.paleMintBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: _isPauseActive
                      ? const Color(0xE6FFFFFF)
                      : AppColors.sagePrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isPauseActive
                        ? 'P1 bypasses pause. P2 delivers in ${_p2DelayMinutes}m. P3 batches${_getScheduledReleaseText()}. P4 holds for break.'
                        : 'Pause is Off. All notifications deliver immediately.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: _isPauseActive
                          ? const Color(0xF2FFFFFF)
                          : AppColors.forestTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSelector() {
    final durations = ['15 mins', '30 mins', '1 hour', '2 hours', 'Until 6 PM'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pause Duration',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.forestTextSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: durations.map((d) {
              final isSelected = _selectedDuration == d;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(d),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedDuration = d;
                        _pauseEndTime = _calculatePauseEndTime(d);
                      });
                    }
                  },
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : AppColors.forestTextSecondary,
                  ),
                  selectedColor: AppColors.sagePrimary,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.sagePrimary
                        : AppColors.borderSage,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    final tabs = [
      {'label': 'All', 'count': _activeNotifications.length, 'color': AppColors.sagePrimary},
      {'label': 'P1 Critical', 'count': _itemsForPriority(NotificationPriority.critical).length, 'color': NotificationPriority.critical.color},
      {'label': 'P2 High', 'count': _itemsForPriority(NotificationPriority.high).length, 'color': NotificationPriority.high.color},
      {'label': 'P3 Normal', 'count': _itemsForPriority(NotificationPriority.normal).length, 'color': NotificationPriority.normal.color},
      {'label': 'P4 Low', 'count': _itemsForPriority(NotificationPriority.low).length, 'color': NotificationPriority.low.color},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final label = tab['label'] as String;
          final count = tab['count'] as int;
          final color = tab['color'] as Color;
          final isSelected = _selectedFilter == label;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _selectedFilter = label;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : AppColors.borderSage,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? color : AppColors.forestTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? color : AppColors.paleMintSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.forestTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Four clearly separated sections on screen
  Widget _buildSectionBlock(NotificationPriority priority, {bool isExpanded = false}) {
    final items = _itemsForPriority(priority);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: priority.borderColor, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSage,
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: priority.bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: priority.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(priority.icon, color: priority.color, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                priority.label,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: priority.color,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: priority.color,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${items.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            priority.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.forestTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Section-level release/override button
                    if (items.any((i) => !i.isDelivered) && priority != NotificationPriority.critical)
                      TextButton.icon(
                        onPressed: () => _deliverSection(priority),
                        icon: const Icon(Icons.flash_on_rounded, size: 14),
                        label: Text('Deliver ${priority.code}'),
                        style: TextButton.styleFrom(
                          foregroundColor: priority.color,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                // Extra configurable delay bar specifically for P2 High
                if (priority == NotificationPriority.high) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: priority.borderColor),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFD97706)),
                          const SizedBox(width: 6),
                          const Text(
                            'P2 Delay:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ...[3, 5, 10, 15].map((mins) {
                            final isSelected = _p2DelayMinutes == mins;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  setState(() {
                                    _p2DelayMinutes = mins;
                                    _checkScheduledDeliveries();
                                  });
                                  _savePreferences();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFD97706) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFD97706) : AppColors.borderSage,
                                    ),
                                  ),
                                  child: Text(
                                    '${mins}m',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.white : AppColors.forestTextSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Cards inside this section
          Padding(
            padding: const EdgeInsets.all(14),
            child: items.isEmpty
                ? _buildEmptySectionPlaceholder(priority)
                : Column(
                    children: items.map(_buildNotificationCard).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySectionPlaceholder(NotificationPriority priority) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.paleMintBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSage.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 18, color: priority.color.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Text(
            'No ${priority.label} notifications',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.forestTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(PauseNotificationItem item) {
    final priority = item.priority;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: priority.borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: App Icon, Sender, Time, Native Importance Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: priority.bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.appIcon, color: priority.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.sender,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.forestTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            item.timestamp,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.forestTextMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.appName,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.forestTextSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Native Android importance (separate from custom priority)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.android_rounded, size: 10, color: Color(0xFF64748B)),
                                const SizedBox(width: 3),
                                Text(
                                  'Native: ${item.nativeImportance}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Notification Message
            Text(
              item.message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.forestTextSecondary,
                height: 1.35,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 10),

            // Policy / Delivery state banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: priority.bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    item.isDelivered ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    size: 13,
                    color: priority.color,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.getPolicyLabel(
                        _p2DelayMinutes,
                        pauseEndTime: _pauseEndTime,
                        isPauseActive: _isPauseActive,
                      ),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: priority.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 4-Level Priority Selector (Responsive 2x2 on phones, 1x4 on wide displays)
            _buildPrioritySelector(item),

            const SizedBox(height: 8),

            // Bottom Actions: Deliver Now Override and Dismiss
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!item.isDelivered && priority != NotificationPriority.critical)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _deliverSingleNotification(item),
                        icon: const Icon(Icons.flash_on_rounded, size: 14),
                        label: const Text(
                          'Deliver Now (Override)',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: priority.color,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.forestTextMuted),
                  tooltip: 'Dismiss',
                  onPressed: () => _dismissNotification(item),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrioritySelector(PauseNotificationItem item) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.paleMintBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSage.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                size: 13,
                color: AppColors.forestTextSecondary,
              ),
              const SizedBox(width: 5),
              const Text(
                'Assign Level',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.forestTextSecondary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.priority.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.priority.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: item.priority.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 380;
              if (isWide) {
                return Row(
                  children: NotificationPriority.values.map((p) {
                    final isSelected = item.priority == p;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _buildPriorityButton(item, p, isSelected),
                      ),
                    );
                  }).toList(),
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildPriorityButton(
                          item,
                          NotificationPriority.critical,
                          item.priority == NotificationPriority.critical,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildPriorityButton(
                          item,
                          NotificationPriority.high,
                          item.priority == NotificationPriority.high,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPriorityButton(
                          item,
                          NotificationPriority.normal,
                          item.priority == NotificationPriority.normal,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildPriorityButton(
                          item,
                          NotificationPriority.low,
                          item.priority == NotificationPriority.low,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityButton(
    PauseNotificationItem item,
    NotificationPriority p,
    bool isSelected,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _updatePriority(item, p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? p.color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? p.color : AppColors.borderSage.withValues(alpha: 0.8),
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: p.color.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                p.icon,
                size: 12,
                color: isSelected ? Colors.white : p.color,
              ),
              const SizedBox(width: 4),
              Text(
                p.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.forestTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMindfulGuideBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paleMintSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSage),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.spa_outlined,
            color: AppColors.sagePrimary,
            size: 22,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NeuroPause 4-Tier Priority Model',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestTextPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '• P1 Critical: Time-sensitive emergencies deliver immediately with sound/vibration.\n'
                  '• P2 High: Fast-tracked batch delivered after a short delay (3-15m).\n'
                  '• P3 Normal: Regular batch delivered at scheduled pause breaks.\n'
                  '• P4 Low: Non-urgent newsletters and notifications held for evening digest.\n\n'
                  'Tap any P1/P2/P3/P4 badge on a card to instantly reassign its level and move it between sections.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.forestTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
