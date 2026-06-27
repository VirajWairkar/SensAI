// =====================================================================
// SensAI — BreathingExercise Widget
// 4-7-8 breathing technique with animated visual guide.
// =====================================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

enum BreathPhase { inhale, hold, exhale, rest }

class BreathingExercise extends StatefulWidget {
  const BreathingExercise({super.key});

  @override
  State<BreathingExercise> createState() => _BreathingExerciseState();
}

class _BreathingExerciseState extends State<BreathingExercise>
    with SingleTickerProviderStateMixin {
  // 4-7-8 cycle durations (seconds)
  static const _phaseDurations = {
    BreathPhase.inhale: 4,
    BreathPhase.hold: 7,
    BreathPhase.exhale: 8,
    BreathPhase.rest: 2,
  };

  static const _phaseLabels = {
    BreathPhase.inhale: 'Breathe In',
    BreathPhase.hold: 'Hold',
    BreathPhase.exhale: 'Breathe Out',
    BreathPhase.rest: 'Rest',
  };

  static const _phaseColors = {
    BreathPhase.inhale: Color(0xFF4FC3F7),
    BreathPhase.hold: Color(0xFFFFD54F),
    BreathPhase.exhale: Color(0xFF81C784),
    BreathPhase.rest: Color(0xFFCE93D8),
  };

  BreathPhase _phase = BreathPhase.inhale;
  int _countdown = 4;
  int _cycleCount = 0;
  Timer? _timer;
  bool _running = false;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scaleController.dispose();
    super.dispose();
  }

  void _startExercise() {
    setState(() {
      _running = true;
      _phase = BreathPhase.inhale;
      _countdown = _phaseDurations[BreathPhase.inhale]!;
    });
    _scaleController.duration = Duration(seconds: _phaseDurations[BreathPhase.inhale]!);
    _scaleController.forward();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _stopExercise() {
    _timer?.cancel();
    _scaleController.stop();
    _scaleController.reset();
    setState(() => _running = false);
  }

  void _tick(Timer t) {
    setState(() {
      _countdown--;
      if (_countdown <= 0) {
        _nextPhase();
      }
    });
  }

  void _nextPhase() {
    final phases = BreathPhase.values;
    final idx = phases.indexOf(_phase);
    _phase = phases[(idx + 1) % phases.length];
    if (_phase == BreathPhase.inhale) _cycleCount++;
    _countdown = _phaseDurations[_phase]!;

    _scaleController.reset();
    _scaleController.duration = Duration(seconds: _countdown);
    if (_phase == BreathPhase.inhale) {
      _scaleController.forward();
    } else if (_phase == BreathPhase.exhale) {
      _scaleAnim = Tween<double>(begin: 1.0, end: 0.5)
          .animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut));
      _scaleController.forward();
    } else {
      _scaleAnim = Tween<double>(begin: _scaleController.value, end: _scaleController.value)
          .animate(_scaleController);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _phaseColors[_phase] ?? Colors.blue;
    final label = _phaseLabels[_phase] ?? '';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.indigo.shade900,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              '🧘 Breathing Exercise',
              style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '4-7-8 Calming Technique',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 24),
            if (_running) ...[
              AnimatedBuilder(
                animation: _scaleController,
                builder: (_, __) {
                  final scale = 0.5 + (_scaleController.value * 0.5);
                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.2),
                      border: Border.all(color: color, width: 3),
                    ),
                    child: Center(
                      child: Container(
                        width: 60 * scale,
                        height: 60 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withOpacity(0.6),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 22, fontWeight: FontWeight.bold)),
              Text('$_countdown s',
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Cycles completed: $_cycleCount',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                onPressed: _stopExercise,
                child: const Text('Stop'),
              ),
            ] else ...[
              const Icon(Icons.air, color: Colors.white38, size: 60),
              const SizedBox(height: 16),
              const Text(
                'Feeling overwhelmed? Start the\n4-7-8 breathing technique.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700),
                onPressed: _startExercise,
                child: const Text('Start Breathing Exercise'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
