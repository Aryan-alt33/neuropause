import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'mindful_break_screen.dart';
import 'mood_check_screen.dart';
import 'notification_pause_screen.dart';

void main() {
  runApp(const NeuroPauseApp());
}

class NeuroPauseApp extends StatelessWidget {
  const NeuroPauseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NeuroPause',
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
      routes: {
        NotificationPauseScreen.routeName: (context) =>
            const NotificationPauseScreen(),
        MindfulBreakScreen.routeName: (context) => const MindfulBreakScreen(),
        MoodCheckScreen.routeName: (context) => const MoodCheckScreen(),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _storageKey = 'neuropause_mood_entries_v1';
  final List<MoodEntry> _savedReflections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedReflections();
  }

  Future<void> _loadSavedReflections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      _savedReflections.clear();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _savedReflections.add(MoodEntry.fromJson(item));
          } else if (item is Map) {
            _savedReflections.add(
              MoodEntry.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
    } catch (_) {
      // Graceful fallback
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  MoodEntry? get _todayMoodEntry =>
      _savedReflections.isNotEmpty ? _savedReflections.first : null;

  Future<void> _navigateToNotificationPause() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: NotificationPauseScreen.routeName),
        builder: (context) => const NotificationPauseScreen(),
      ),
    );
    _loadSavedReflections();
  }

  Future<void> _navigateToMindfulBreak() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: MindfulBreakScreen.routeName),
        builder: (context) => const MindfulBreakScreen(),
      ),
    );
    _loadSavedReflections();
  }

  Future<void> _navigateToMoodCheck() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: MoodCheckScreen.routeName),
        builder: (context) => const MoodCheckScreen(),
      ),
    );
    _loadSavedReflections();
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[dt.month - 1];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month ${dt.day} • $hour:$minute $period';
  }

  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'Happy':
        return const Color(0xFF387A49);
      case 'Calm':
        return AppColors.sagePrimary;
      case 'Okay':
        return const Color(0xFF567262);
      case 'Anxious':
        return const Color(0xFF9E6539);
      case 'Overwhelmed':
        return const Color(0xFF8F5454);
      default:
        return AppColors.sagePrimary;
    }
  }

  Color _getMoodBg(String mood) {
    switch (mood) {
      case 'Happy':
        return const Color(0xFFE9F5ED);
      case 'Calm':
        return AppColors.paleMintSurface;
      case 'Okay':
        return const Color(0xFFEEF3F0);
      case 'Anxious':
        return const Color(0xFFF9F0E9);
      case 'Overwhelmed':
        return const Color(0xFFF7ECEC);
      default:
        return AppColors.paleMintSurface;
    }
  }

  IconData _getMoodIcon(String mood) {
    switch (mood) {
      case 'Happy':
        return Icons.sentiment_very_satisfied_rounded;
      case 'Calm':
        return Icons.spa_rounded;
      case 'Okay':
        return Icons.sentiment_satisfied_rounded;
      case 'Anxious':
        return Icons.psychology_alt_rounded;
      case 'Overwhelmed':
        return Icons.waves_rounded;
      default:
        return Icons.mood_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paleMintBg,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.spa_rounded, color: AppColors.sagePrimary, size: 24),
            SizedBox(width: 8),
            Text(
              'NeuroPause',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.forestTextPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.paleMintBg,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.paleMintSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSage),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: AppColors.sagePrimary,
                ),
                SizedBox(width: 5),
                Text(
                  'Focus Calm',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.sageDeep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 780;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32 : 18,
              vertical: 16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Welcoming Header
                    _buildWelcomingHeader(),

                    const SizedBox(height: 20),

                    // 2. Today's Mood Summary Card
                    _buildTodayMoodSummaryCard(),

                    const SizedBox(height: 24),

                    // Section: Quick Action Shortcuts
                    const Text(
                      'Wellbeing Shortcuts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.forestTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3 & 4. Notification Pause, Mindful Break, and Mood Check
                    if (isWide)
                      _buildWideShortcuts()
                    else
                      _buildStackedShortcuts(),

                    const SizedBox(height: 24),

                    // 5. Daily Wellbeing Tip
                    _buildDailyWellbeingTipCard(),

                    const SizedBox(height: 24),

                    // 6. Recent Mood Reflections Section
                    _buildRecentReflectionsSection(),

                    const SizedBox(height: 32),

                    // Mindful Footer
                    const Center(
                      child: Text(
                        'Your attention matters 🌿',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.forestTextSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 1. Welcoming Header
  Widget _buildWelcomingHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSage, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSage,
            offset: Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.importantBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Daily Companion',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.importantText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Make space for your mind.',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.forestTextPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your personal digital wellbeing companion.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.forestTextSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // 2. Today's Mood Summary Card
  Widget _buildTodayMoodSummaryCard() {
    final entry = _todayMoodEntry;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _navigateToMoodCheck,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderSage, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowSage,
              offset: Offset(0, 4),
              blurRadius: 14,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.favorite_outline_rounded,
                      color: AppColors.sagePrimary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Today\'s Mood Summary',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.forestTextPrimary,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: _navigateToMoodCheck,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      entry != null ? 'Update Mood' : 'Check In',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sagePrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (entry != null) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getMoodBg(entry.mood),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getMoodColor(entry.mood).withAlpha(80),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getMoodIcon(entry.mood),
                          size: 14,
                          color: _getMoodColor(entry.mood),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Feeling ${entry.mood}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getMoodColor(entry.mood),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatDate(entry.timestamp),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.forestTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.paleMintBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '"${entry.response}"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.forestTextPrimary,
                    height: 1.35,
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.paleMintBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_note_rounded,
                      color: AppColors.sagePrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'No check-in recorded today. Take 60 seconds to reflect on how you feel.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.forestTextSecondary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _navigateToMoodCheck,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.sagePrimary,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Log Mood'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 3 & 4. Shortcuts (Stacked)
  Widget _buildStackedShortcuts() {
    return Column(
      children: [
        _buildShortcutCard(
          title: 'Notification Pause',
          subtitle: 'Choose what deserves your attention.',
          badge: '3 Categorized Items',
          icon: Icons.notifications_active_outlined,
          onTap: _navigateToNotificationPause,
        ),
        const SizedBox(height: 12),
        _buildShortcutCard(
          title: 'Take a Mindful Break',
          subtitle: 'Pause, breathe, and reset.',
          badge: '60s 4-4 Rhythm',
          icon: Icons.self_improvement,
          onTap: _navigateToMindfulBreak,
        ),
        const SizedBox(height: 12),
        _buildShortcutCard(
          title: 'Mood Check',
          subtitle: 'Reflect on how you feel right now.',
          badge: 'CBT Reflection',
          icon: Icons.mood_rounded,
          onTap: _navigateToMoodCheck,
        ),
      ],
    );
  }

  // 3 & 4. Shortcuts (Wide screen)
  Widget _buildWideShortcuts() {
    return Row(
      children: [
        Expanded(
          child: _buildShortcutCard(
            title: 'Notification Pause',
            subtitle: 'Choose what deserves your attention.',
            badge: 'Noise Control',
            icon: Icons.notifications_active_outlined,
            onTap: _navigateToNotificationPause,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildShortcutCard(
            title: 'Take a Mindful Break',
            subtitle: 'Pause, breathe, and reset.',
            badge: '4-4 Breathing',
            icon: Icons.self_improvement,
            onTap: _navigateToMindfulBreak,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildShortcutCard(
            title: 'Mood Check',
            subtitle: 'Reflect on how you feel right now.',
            badge: 'CBT Check-in',
            icon: Icons.mood_rounded,
            onTap: _navigateToMoodCheck,
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutCard({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Card(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderSage, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.paleMintSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.sagePrimary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.forestTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.forestTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.forestTextMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 5. Daily Wellbeing Tip Card
  Widget _buildDailyWellbeingTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.paleMintSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSage),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: AppColors.sagePrimary,
            size: 22,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Wellbeing Tip',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestTextPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Single-tasking for even 20 minutes reduces cognitive load and quiets mental chatter. Give your attention one home at a time.',
                  style: TextStyle(
                    fontSize: 12.5,
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

  // 6. Recent Mood Reflections Section
  Widget _buildRecentReflectionsSection() {
    final recentList = _savedReflections.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Reflections',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.forestTextPrimary,
              ),
            ),
            InkWell(
              onTap: _navigateToMoodCheck,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  _savedReflections.isNotEmpty ? 'View All / Add' : 'Add First',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.sagePrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.sagePrimary),
            ),
          )
        else if (recentList.isEmpty)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _navigateToMoodCheck,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSage),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.sagePrimary,
                    size: 26,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No recent reflections yet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.forestTextPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tap here to check in with how you are feeling.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.forestTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppColors.forestTextMuted,
                  ),
                ],
              ),
            ),
          )
        else
          ...recentList.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _navigateToMoodCheck,
                child: Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(
                      color: AppColors.borderSage,
                      width: 1.2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    onTap: _navigateToMoodCheck,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getMoodBg(entry.mood),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getMoodColor(entry.mood)
                                        .withAlpha(80),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getMoodIcon(entry.mood),
                                      size: 13,
                                      color: _getMoodColor(entry.mood),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      entry.mood,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: _getMoodColor(entry.mood),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatDate(entry.timestamp),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.forestTextMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.paleMintBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              entry.response,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.forestTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
