import 'dart:async';
import 'package:flutter/material.dart';
import 'app_theme.dart';

enum BreathPhase { inhale, exhale, idle }

class MindfulBreakScreen extends StatefulWidget {
  static const String routeName = '/mindful-break';

  const MindfulBreakScreen({super.key});

  @override
  State<MindfulBreakScreen> createState() => _MindfulBreakScreenState();
}

class _MindfulBreakScreenState extends State<MindfulBreakScreen>
    with SingleTickerProviderStateMixin {
  static const int _totalSessionSeconds = 60;

  bool _isRunning = false;
  bool _isCompleted = false;
  int _remainingSeconds = _totalSessionSeconds;
  Timer? _sessionTimer;

  late AnimationController _breathController;
  late Animation<double> _scaleAnimation;
  BreathPhase _currentPhase = BreathPhase.idle;

  @override
  void initState() {
    super.initState();
    // 4 seconds inhale, 4 seconds exhale
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(
        parent: _breathController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _breathController.addStatusListener((status) {
      if (!_isRunning) return;
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentPhase = BreathPhase.exhale;
        });
        _breathController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        setState(() {
          _currentPhase = BreathPhase.inhale;
        });
        _breathController.forward();
      }
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _breathController.dispose();
    super.dispose();
  }

  void _startOrResumeSession() {
    if (_isCompleted) {
      _resetSession();
    }

    setState(() {
      _isRunning = true;
      if (_currentPhase == BreathPhase.idle) {
        _currentPhase = BreathPhase.inhale;
        _breathController.forward();
      } else if (_currentPhase == BreathPhase.exhale) {
        _breathController.reverse();
      } else {
        _breathController.forward();
      }
    });

    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _completeSession();
      }
    });
  }

  void _pauseSession() {
    setState(() {
      _isRunning = false;
    });
    _sessionTimer?.cancel();
    _breathController.stop();
  }

  void _resetSession() {
    _sessionTimer?.cancel();
    _breathController.reset();
    setState(() {
      _isRunning = false;
      _isCompleted = false;
      _remainingSeconds = _totalSessionSeconds;
      _currentPhase = BreathPhase.idle;
    });
  }

  void _completeSession() {
    _sessionTimer?.cancel();
    _breathController.stop();
    setState(() {
      _isRunning = false;
      _isCompleted = true;
      _remainingSeconds = 0;
      _currentPhase = BreathPhase.idle;
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get _phaseLabel {
    if (_isCompleted) return 'Restored';
    switch (_currentPhase) {
      case BreathPhase.inhale:
        return 'Inhale...';
      case BreathPhase.exhale:
        return 'Exhale...';
      case BreathPhase.idle:
        return 'Ready to breathe';
    }
  }

  String get _phaseGuidance {
    if (_isCompleted) {
      return 'Great job! You made space for your mind.';
    }
    switch (_currentPhase) {
      case BreathPhase.inhale:
        return 'Breathe in slowly through your nose (4s)';
      case BreathPhase.exhale:
        return 'Release gently through your mouth (4s)';
      case BreathPhase.idle:
        return 'Press Start to begin your 60-second reset';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_totalSessionSeconds - _remainingSeconds) /
        _totalSessionSeconds;

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
          'Take a Mindful Break',
          style: TextStyle(
            color: AppColors.forestTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.replay_rounded, color: AppColors.sagePrimary),
            tooltip: 'Reset Timer',
            onPressed: _resetSession,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Top header card with session countdown
            _buildSessionTimerCard(progress),

            const SizedBox(height: 16),

            // Animated breathing circle
            _buildBreathingCircle(),

            const SizedBox(height: 16),

            // Main guidance text
            Text(
              _phaseLabel,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.forestTextPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _phaseGuidance,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.forestTextSecondary,
                height: 1.35,
              ),
            ),

            const SizedBox(height: 20),

            // Start / Pause & Reset controls
            _buildActionButtons(),

            const SizedBox(height: 20),

            // Mindful breathing tip
            _buildMindfulTipBox(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTimerCard(double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: AppColors.sagePrimary,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '60-Second Reset',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forestTextPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isRunning
                      ? AppColors.importantBg
                      : AppColors.paleMintSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isRunning
                        ? AppColors.importantBorder
                        : AppColors.borderSage,
                  ),
                ),
                child: Text(
                  _formatTime(_remainingSeconds),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: _isRunning
                        ? AppColors.sageDeep
                        : AppColors.forestTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.paleMintSurface,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.sagePrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreathingCircle() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        final scale = _scaleAnimation.value;

        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer soothing ambient aura
              Transform.scale(
                scale: scale * 1.08,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.sageLight.withAlpha(26),
                  ),
                ),
              ),

              // Middle mint halo
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.paleMintSurface,
                    border: Border.all(
                      color: AppColors.borderSage,
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowSage,
                        offset: Offset(0, 6),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),

              // Core breathing circle with sage gradient
              Transform.scale(
                scale: scale * 0.92,
                child: Container(
                  width: 125,
                  height: 125,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.sageLight,
                        AppColors.sagePrimary,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowSageHero,
                        offset: Offset(0, 8),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.spa_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),

              // Dynamic 4s indicator badge inside
              if (_isRunning)
                Positioned(
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderSage,
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadowSage,
                          offset: Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      _currentPhase == BreathPhase.inhale
                          ? 'Inhale (4s)'
                          : 'Exhale (4s)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sagePrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Main Start / Pause button
        ElevatedButton.icon(
          onPressed: _isRunning ? _pauseSession : _startOrResumeSession,
          icon: Icon(
            _isCompleted
                ? Icons.replay_rounded
                : _isRunning
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
            size: 22,
          ),
          label: Text(
            _isCompleted
                ? 'Restart Break'
                : _isRunning
                    ? 'Pause'
                    : (_remainingSeconds < _totalSessionSeconds
                        ? 'Resume'
                        : 'Start 60s Break'),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sagePrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ),

        const SizedBox(width: 14),

        // Reset button
        OutlinedButton.icon(
          onPressed: _resetSession,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reset'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.forestTextSecondary,
            side: const BorderSide(color: AppColors.borderSage, width: 1.2),
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMindfulTipBox() {
    return Container(
      width: double.infinity,
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
            Icons.self_improvement_rounded,
            color: AppColors.sagePrimary,
            size: 22,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '4-4 Rhythm Science',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestTextPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Four seconds of deep inhalation followed by four seconds of slow exhalation slows your heart rate and activates calm parasympathetic neural pathways.',
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
