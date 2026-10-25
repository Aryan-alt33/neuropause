import 'dart:async';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'services/android_notification_service.dart';

enum NotificationPriority {
  urgent,
  important,
  canWait,
}

class PauseNotificationItem {
  final String id;
  final String sender;
  final String appName;
  final IconData appIcon;
  final String title;
  final String message;
  final String timestamp;
  final NotificationPriority priority;
  final String policyLabel;
  bool isDelivered;
  bool isDismissed;

  PauseNotificationItem({
    required this.id,
    required this.sender,
    required this.appName,
    required this.appIcon,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.priority,
    required this.policyLabel,
    this.isDelivered = false,
    this.isDismissed = false,
  });
}

class NotificationPauseScreen extends StatefulWidget {
  static const String routeName = '/notification-pause';

  const NotificationPauseScreen({super.key});

  @override
  State<NotificationPauseScreen> createState() => _NotificationPauseScreenState();
}

class _NotificationPauseScreenState extends State<NotificationPauseScreen>
    with WidgetsBindingObserver {
  bool _isPauseActive = true;
  String _selectedFilter = 'All';
  String _selectedDuration = '1 hour';

  bool _hasPermission = false;
  bool _isDemoMode = false;
  bool _isLoading = false;

  List<PauseNotificationItem> _notifications = [];
  List<PauseNotificationItem> _sampleNotifications = [];
  List<PauseNotificationItem> _realNotifications = [];
  StreamSubscription<Map<String, dynamic>>? _liveSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSampleNotifications();
    _checkPermissionAndRefresh();
    _listenToLiveNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndRefresh();
    }
  }

  void _initSampleNotifications() {
    _sampleNotifications = [
      PauseNotificationItem(
        id: '1',
        sender: 'Dr. Elena Vance (Family Clinic)',
        appName: 'Health & Care',
        appIcon: Icons.local_hospital_rounded,
        title: 'Appointment Confirmation Needed',
        message:
            'Please confirm your lab review scheduled for tomorrow at 9:30 AM.',
        timestamp: '2m ago',
        priority: NotificationPriority.urgent,
        policyLabel: 'Allowed Through • Sound & Alert ON',
      ),
      PauseNotificationItem(
        id: '2',
        sender: 'Sarah Jenkins (Project Lead)',
        appName: 'Work Slack',
        appIcon: Icons.work_outline_rounded,
        title: 'Quarterly Review Deck',
        message:
            'Could you review slides 4-8 before our 3:30 PM client strategy sync?',
        timestamp: '18m ago',
        priority: NotificationPriority.important,
        policyLabel: 'Batched for Break • Next batch in 42m',
      ),
      PauseNotificationItem(
        id: '3',
        sender: 'Mindful Reads Digest',
        appName: 'Newsletter',
        appIcon: Icons.menu_book_rounded,
        title: 'Weekly Mindfulness Digest',
        message:
            '5 research-backed strategies to declutter your evening digital habits.',
        timestamp: '1h ago',
        priority: NotificationPriority.canWait,
        policyLabel: 'Silenced • Kept in Evening Digest',
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
        final mapped = rawList.map(_mapNativeNotification).toList();
        setState(() {
          _realNotifications = mapped;
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
      final item = _mapNativeNotification(raw);
      setState(() {
        _realNotifications.removeWhere((n) => n.id == item.id);
        _realNotifications.insert(0, item);
        if (!_isDemoMode) {
          _notifications.removeWhere((n) => n.id == item.id);
          _notifications.insert(0, item);
        }
      });
    });
  }

  PauseNotificationItem _mapNativeNotification(Map<String, dynamic> raw) {
    final title = (raw['title'] as String?)?.trim() ?? '';
    final message = (raw['message'] as String?)?.trim() ?? '';
    final appName = (raw['appName'] as String?)?.trim() ?? 'App';
    final pkg = (raw['packageName'] as String?)?.toLowerCase() ?? '';
    final postTime = raw['postTime'] is int
        ? raw['postTime'] as int
        : DateTime.now().millisecondsSinceEpoch;

    final combined = '$title $message'.toLowerCase();
    NotificationPriority priority;
    String policyLabel;

    if (combined.contains('urgent') ||
        combined.contains('emergency') ||
        combined.contains('otp') ||
        combined.contains('verification') ||
        combined.contains('security alert') ||
        combined.contains('code:')) {
      priority = NotificationPriority.urgent;
      policyLabel = 'Allowed Through • Sound & Alert ON';
    } else if (pkg.contains('whatsapp') ||
        pkg.contains('slack') ||
        pkg.contains('teams') ||
        pkg.contains('gm') ||
        pkg.contains('mail') ||
        pkg.contains('messaging') ||
        pkg.contains('mms') ||
        pkg.contains('discord') ||
        pkg.contains('telegram')) {
      priority = NotificationPriority.important;
      policyLabel = 'Batched for Break • Next batch in 42m';
    } else {
      priority = NotificationPriority.canWait;
      policyLabel = 'Silenced • Kept in Evening Digest';
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

    return PauseNotificationItem(
      id: (raw['id'] as String?) ?? UniqueKey().toString(),
      sender: title.isNotEmpty ? title : appName,
      appName: appName,
      appIcon: icon,
      title: title.isNotEmpty ? title : appName,
      message: message.isNotEmpty ? message : 'New notification',
      timestamp: timeStr,
      priority: priority,
      policyLabel: policyLabel,
    );
  }

  List<PauseNotificationItem> get _filteredNotifications {
    final active = _notifications.where((n) => !n.isDismissed).toList();
    if (_selectedFilter == 'Urgent') {
      return active
          .where((n) => n.priority == NotificationPriority.urgent)
          .toList();
    }
    if (_selectedFilter == 'Important') {
      return active
          .where((n) => n.priority == NotificationPriority.important)
          .toList();
    }
    if (_selectedFilter == 'Can Wait') {
      return active
          .where((n) => n.priority == NotificationPriority.canWait)
          .toList();
    }
    return active;
  }

  int _countForPriority(NotificationPriority priority) {
    return _notifications
        .where((n) => !n.isDismissed && n.priority == priority)
        .length;
  }

  int get _batchedCount {
    return _notifications
        .where((n) =>
            !n.isDismissed &&
            !n.isDelivered &&
            n.priority != NotificationPriority.urgent)
        .length;
  }

  void _deliverAllBatched() {
    setState(() {
      for (final n in _notifications) {
        if (!n.isDismissed && n.priority != NotificationPriority.urgent) {
          n.isDelivered = true;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Delivered all batched notifications to your inbox.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.sagePrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _dismissNotification(PauseNotificationItem item) {
    setState(() {
      item.isDismissed = true;
    });

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
            });
          },
        ),
      ),
    );
  }

  void _deliverSingleNotification(PauseNotificationItem item) {
    setState(() {
      item.isDelivered = true;
    });
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

  @override
  Widget build(BuildContext context) {
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: _isDemoMode
                  ? const Color(0xFFF0F5F2)
                  : AppColors.paleMintSurface,
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
                        ? 'Showing Demo / Fallback notifications.'
                        : 'Switched to Live Real notifications.'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isDemoMode
                          ? Icons.play_arrow_outlined
                          : Icons.sensors_rounded,
                      size: 14,
                      color: _isDemoMode
                          ? AppColors.forestTextSecondary
                          : AppColors.sagePrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isDemoMode ? 'Demo' : 'Live',
                      style: TextStyle(
                        color: _isDemoMode
                            ? AppColors.forestTextSecondary
                            : AppColors.sagePrimary,
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
                : const Icon(Icons.refresh_rounded,
                    color: AppColors.sagePrimary),
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
                  'Incoming Feed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestTextPrimary,
                  ),
                ),
                Text(
                  '${_filteredNotifications.length} of ${_notifications.where((n) => !n.isDismissed).length} active',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.forestTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Filter Pills
            _buildFilterTabs(),

            const SizedBox(height: 16),

            // Notifications List
            if (_filteredNotifications.isEmpty)
              _buildEmptyState()
            else
              ..._filteredNotifications.map(_buildNotificationCard),

            const SizedBox(height: 20),

            // Batch action button if any items batched
            if (_batchedCount > 0 && _isPauseActive)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton.icon(
                  onPressed: _deliverAllBatched,
                  icon: const Icon(Icons.unarchive_outlined, size: 18),
                  label: Text('Deliver Batched Items Now ($_batchedCount)'),
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

            // Mindful info box
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
                          ? 'Protecting your focus & calm'
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
                        ? 'Urgent alerts break through. Important & Can Wait are paused.'
                        : 'All incoming notifications will buzz normally.',
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
    final durations = ['30 mins', '1 hour', '2 hours', 'Until 6 PM'];
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
                      });
                    }
                  },
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
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
      {'label': 'All', 'count': _notifications.where((n) => !n.isDismissed).length},
      {'label': 'Urgent', 'count': _countForPriority(NotificationPriority.urgent)},
      {'label': 'Important', 'count': _countForPriority(NotificationPriority.important)},
      {'label': 'Can Wait', 'count': _countForPriority(NotificationPriority.canWait)},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final label = tab['label'] as String;
          final count = tab['count'] as int;
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.paleMintSurface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.sagePrimary
                        : AppColors.borderSage,
                    width: isSelected ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? AppColors.sageDeep
                            : AppColors.forestTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.sagePrimary
                            : AppColors.paleMintSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : AppColors.forestTextSecondary,
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

  Widget _buildNotificationCard(PauseNotificationItem item) {
    final styling = _categoryStyle(item.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: styling.borderColor,
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSage,
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: App icon, sender, time, category badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: styling.iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.appIcon, color: styling.badgeText, size: 20),
                ),
                const SizedBox(width: 12),
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
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.timestamp,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.forestTextMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.appName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.forestTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Badge Row
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: styling.badgeBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: styling.badgeBorder, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(styling.icon, size: 13, color: styling.badgeText),
                      const SizedBox(width: 4),
                      Text(
                        styling.name,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: styling.badgeText,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (item.isDelivered)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.importantBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.importantBorder),
                    ),
                    child: const Text(
                      'Delivered',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.importantText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Message Title & Body
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.forestTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.message,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: AppColors.forestTextSecondary,
              ),
            ),

            const SizedBox(height: 12),

            // Bottom Policy pill & quick actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.paleMintBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    item.priority == NotificationPriority.urgent
                        ? Icons.bolt_rounded
                        : item.priority == NotificationPriority.important
                            ? Icons.pause_circle_outline_rounded
                            : Icons.bedtime_outlined,
                    size: 14,
                    color: styling.badgeText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.policyLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: styling.badgeText,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Action row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (item.priority != NotificationPriority.urgent &&
                    !item.isDelivered)
                  TextButton.icon(
                    onPressed: () => _deliverSingleNotification(item),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                    label: const Text('Deliver Now'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.sagePrimary,
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (item.priority == NotificationPriority.urgent)
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Calling back ${item.sender}...'),
                          backgroundColor: AppColors.sagePrimary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 14),
                    label: const Text('Acknowledge'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.urgentText,
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.forestTextMuted),
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

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSage),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.paleMintSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.sagePrimary,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'All quiet in this category',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.forestTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enjoy your peace of mind.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.forestTextSecondary,
            ),
          ),
        ],
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
                  'How NeuroPause Triaging Works',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestTextPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '• Urgent: Time-sensitive health, family, or critical alerts ring right away.\n• Important: Batched and delivered during your mindful breaks.\n• Can Wait: Non-urgent newsletters and updates kept for evening review.',
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

  _CategoryConfig _categoryStyle(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.urgent:
        return _CategoryConfig(
          name: 'Urgent',
          icon: Icons.error_outline_rounded,
          badgeBg: AppColors.urgentBg,
          badgeBorder: AppColors.urgentBorder,
          badgeText: AppColors.urgentText,
          iconBg: AppColors.urgentBg,
          borderColor: const Color(0xFFF9DDD7),
        );
      case NotificationPriority.important:
        return _CategoryConfig(
          name: 'Important',
          icon: Icons.star_rounded,
          badgeBg: AppColors.importantBg,
          badgeBorder: AppColors.importantBorder,
          badgeText: AppColors.importantText,
          iconBg: AppColors.importantBg,
          borderColor: const Color(0xFFD4E8DC),
        );
      case NotificationPriority.canWait:
        return _CategoryConfig(
          name: 'Can Wait',
          icon: Icons.hourglass_empty_rounded,
          badgeBg: AppColors.canWaitBg,
          badgeBorder: AppColors.canWaitBorder,
          badgeText: AppColors.canWaitText,
          iconBg: AppColors.canWaitBg,
          borderColor: const Color(0xFFE2ECE5),
        );
    }
  }
}

class _CategoryConfig {
  final String name;
  final IconData icon;
  final Color badgeBg;
  final Color badgeBorder;
  final Color badgeText;
  final Color iconBg;
  final Color borderColor;

  _CategoryConfig({
    required this.name,
    required this.icon,
    required this.badgeBg,
    required this.badgeBorder,
    required this.badgeText,
    required this.iconBg,
    required this.borderColor,
  });
}
