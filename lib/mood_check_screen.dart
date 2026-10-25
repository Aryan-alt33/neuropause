import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class MoodOption {
  final String label;
  final String description;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final String cbtQuestion;

  const MoodOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.cbtQuestion,
  });
}

class MoodEntry {
  final String id;
  final String mood;
  final String question;
  final String response;
  final DateTime timestamp;

  MoodEntry({
    required this.id,
    required this.mood,
    required this.question,
    required this.response,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'mood': mood,
        'question': question,
        'response': response,
        'timestamp': timestamp.toIso8601String(),
      };

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
        id: json['id'] as String,
        mood: json['mood'] as String,
        question: json['question'] as String,
        response: json['response'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class MoodCheckScreen extends StatefulWidget {
  static const String routeName = '/mood-check';

  const MoodCheckScreen({super.key});

  @override
  State<MoodCheckScreen> createState() => _MoodCheckScreenState();
}

class _MoodCheckScreenState extends State<MoodCheckScreen> {
  static const String _storageKey = 'neuropause_mood_entries_v1';

  final TextEditingController _reflectionController = TextEditingController();
  final List<MoodEntry> _savedEntries = [];
  bool _isLoading = true;

  final List<MoodOption> _moodOptions = const [
    MoodOption(
      label: 'Happy',
      description: 'Grateful, joyful, uplifted',
      icon: Icons.sentiment_very_satisfied_rounded,
      accentColor: Color(0xFF387A49),
      bgColor: Color(0xFFE9F5ED),
      cbtQuestion:
          'What is bringing you joy today, and how can you savor this feeling throughout your day?',
    ),
    MoodOption(
      label: 'Calm',
      description: 'Centered, peaceful, steady',
      icon: Icons.spa_rounded,
      accentColor: AppColors.sagePrimary,
      bgColor: AppColors.paleMintSurface,
      cbtQuestion:
          'What helped you find stillness right now, and how can you return to this quiet center later?',
    ),
    MoodOption(
      label: 'Okay',
      description: 'Balanced, neutral, grounded',
      icon: Icons.sentiment_satisfied_rounded,
      accentColor: Color(0xFF567262),
      bgColor: Color(0xFFEEF3F0),
      cbtQuestion:
          'What is one small, gentle thing that would make your day feel 5% lighter or more nourishing?',
    ),
    MoodOption(
      label: 'Anxious',
      description: 'Uneasy, worried, restless',
      icon: Icons.psychology_alt_rounded,
      accentColor: Color(0xFF9E6539),
      bgColor: Color(0xFFF9F0E9),
      cbtQuestion:
          'What thought is creating worry right now? Is it an absolute certainty, or simply a feeling you can observe without judgment?',
    ),
    MoodOption(
      label: 'Overwhelmed',
      description: 'Pressured, scattered, exhausted',
      icon: Icons.waves_rounded,
      accentColor: Color(0xFF8F5454),
      bgColor: Color(0xFFF7ECEC),
      cbtQuestion:
          'If you could hit pause on everything and choose just one tiny, kind thing to do for yourself right now, what would it be?',
    ),
  ];

  MoodOption? _selectedMood;

  @override
  void initState() {
    super.initState();
    _loadEntriesFromStorage();
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _loadEntriesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final loaded = <MoodEntry>[];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            loaded.add(MoodEntry.fromJson(item));
          } else if (item is Map) {
            loaded.add(MoodEntry.fromJson(Map<String, dynamic>.from(item)));
          }
        }
        if (mounted) {
          setState(() {
            _savedEntries.clear();
            _savedEntries.addAll(loaded);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading mood entries from SharedPreferences: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _persistEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized =
          jsonEncode(_savedEntries.map((e) => e.toJson()).toList());
      return await prefs.setString(_storageKey, serialized);
    } catch (e) {
      debugPrint('Error saving mood entries to SharedPreferences: $e');
      return false;
    }
  }

  void _onSelectMood(MoodOption mood) {
    setState(() {
      _selectedMood = mood;
    });
  }

  Future<void> _saveEntry() async {
    if (_selectedMood == null) return;

    final responseText = _reflectionController.text.trim();
    if (responseText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write a short reflection before saving.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final newEntry = MoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mood: _selectedMood!.label,
      question: _selectedMood!.cbtQuestion,
      response: responseText,
      timestamp: DateTime.now(),
    );

    setState(() {
      _savedEntries.insert(0, newEntry);
      _reflectionController.clear();
      _selectedMood = null;
    });

    await _persistEntries();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Mood reflection saved locally 🌿',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.sagePrimary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteEntry(String id) async {
    setState(() {
      _savedEntries.removeWhere((e) => e.id == id);
    });
    await _persistEntries();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reflection entry removed.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  String _formatDateTime(DateTime dt) {
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
      'Dec'
    ];
    final month = months[dt.month - 1];
    final hour = dt.hour == 0
        ? 12
        : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month ${dt.day}, ${dt.year} • $hour:$minute $period';
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
          'Mood Check',
          style: TextStyle(
            color: AppColors.forestTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top greeting banner
            _buildHeaderBanner(),

            const SizedBox(height: 20),

            // 5 Mood Selector
            const Text(
              'How are you feeling right now?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.forestTextPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _buildMoodOptionsGrid(),

            const SizedBox(height: 24),

            // CBT Reflection Card (shown when mood selected)
            if (_selectedMood != null) ...[
              _buildCbtReflectionCard(),
              const SizedBox(height: 28),
            ],

            // Past Reflections Log
            _buildPastEntriesSection(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
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
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.paleMintSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.self_improvement_rounded,
              color: AppColors.sagePrimary,
              size: 24,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A Moment for Self-Check',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestTextPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Notice your emotion without pressure or judgment. Naming your state helps untangle cognitive tension.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
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

  Widget _buildMoodOptionsGrid() {
    return Column(
      children: _moodOptions.map((mood) {
        final isSelected = _selectedMood?.label == mood.label;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _onSelectMood(mood),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? mood.bgColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? mood.accentColor : AppColors.borderSage,
                  width: isSelected ? 1.6 : 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowSage,
                    offset: Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white
                          : AppColors.paleMintSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      mood.icon,
                      color: mood.accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mood.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.forestTextPrimary
                                : AppColors.forestTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mood.description,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.forestTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected
                        ? mood.accentColor
                        : AppColors.forestTextMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCbtReflectionCard() {
    final mood = _selectedMood!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSage, width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSage,
            offset: Offset(0, 6),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: mood.bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: mood.accentColor.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(mood.icon, size: 14, color: mood.accentColor),
                    const SizedBox(width: 6),
                    Text(
                      'Reflection for ${mood.label}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: mood.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.forestTextMuted),
                tooltip: 'Cancel',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    _selectedMood = null;
                    _reflectionController.clear();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mood.cbtQuestion,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.forestTextPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reflectionController,
            maxLines: 4,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.forestTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Take a slow breath and write down your thoughts here...',
              hintStyle: const TextStyle(
                fontSize: 13.5,
                color: AppColors.forestTextMuted,
              ),
              filled: true,
              fillColor: AppColors.paleMintBg,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.borderSage),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.borderSage),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.sagePrimary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveEntry,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save Reflection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sagePrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastEntriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Past Reflections',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.forestTextPrimary,
              ),
            ),
            if (_savedEntries.isNotEmpty)
              Text(
                '${_savedEntries.length} logged',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.forestTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.sagePrimary),
            ),
          )
        else if (_savedEntries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSage),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.paleMintSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.sagePrimary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No reflections saved yet',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pick a mood above to write your first check-in.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.forestTextSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ..._savedEntries.map(_buildPastEntryCard),
      ],
    );
  }

  Widget _buildPastEntryCard(MoodEntry entry) {
    final moodObj = _moodOptions.firstWhere(
      (m) => m.label == entry.mood,
      orElse: () => _moodOptions[1],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSage),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSage,
            offset: Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: moodObj.bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: moodObj.accentColor.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(moodObj.icon, size: 14, color: moodObj.accentColor),
                    const SizedBox(width: 5),
                    Text(
                      entry.mood,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: moodObj.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _formatDateTime(entry.timestamp),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.forestTextMuted,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.forestTextMuted,
                ),
                tooltip: 'Delete reflection',
                visualDensity: VisualDensity.compact,
                onPressed: () => _deleteEntry(entry.id),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.question,
            style: const TextStyle(
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              color: AppColors.forestTextSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.paleMintBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              entry.response,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.forestTextPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
