// =====================================================================
// SensAI — DashboardScreen
// Real-time sensory stress monitoring with live sensor data:
//   • Microphone   → Noise level (dB)
//   • Device light → Ambient light (Lux)
//   • Accelerometer→ Motion intensity
//   • Camera       → Facial tension, crowd density
//   • API          → Overload risk prediction (Low / Medium / High)
// =====================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/sensor_service.dart';
import '../services/camera_analyzer.dart';
import '../services/api_service.dart';
import '../widgets/sensor_card.dart';
import '../widgets/breathing_exercise.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  // ── Services ──────────────────────────────────────────────────────
  final SensorService _sensorService = SensorService();
  final CameraAnalyzer _cameraAnalyzer = CameraAnalyzer();

  // ── State ─────────────────────────────────────────────────────────
  SensorSnapshot? _latest;
  CameraAnalysisResult? _cameraResult;
  String _risk = 'Unknown';
  bool _monitoring = false;
  bool _cameraReady = false;
  bool _showCameraPreview = false;
  String _statusMessage = 'Tap "Start Monitoring" to begin';

  // Prediction debounce
  Timer? _predictionTimer;

  // Risk history for mini-chart
  final List<String> _riskHistory = [];
  static const int _maxHistory = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sensorService.onSnapshot = _onSensorSnapshot;
    _sensorService.onPermissionError = (msg) {
      if (mounted) {
        setState(() => _statusMessage = msg);
      }
    };
    _cameraAnalyzer.onResult = _onCameraResult;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _predictionTimer?.cancel();
    _sensorService.stop();
    _cameraAnalyzer.stopAnalysis();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _monitoring) {
      _sensorService.stop();
    } else if (state == AppLifecycleState.resumed && _monitoring) {
      _sensorService.start();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Start / Stop
  // ─────────────────────────────────────────────────────────────────

  Future<void> _startMonitoring() async {
    setState(() => _statusMessage = 'Requesting permissions…');

    final permissions = await _sensorService.requestPermissions();

    // Check if we have at least microphone.
    final micGranted = permissions[Permission.microphone]?.isGranted ?? false;
    final camGranted = permissions[Permission.camera]?.isGranted ?? false;

    if (!micGranted && !camGranted) {
      setState(() {
        _statusMessage =
            'Permissions denied. Grant microphone / camera in Settings.';
      });
      return;
    }

    // Start hardware sensors.
    await _sensorService.start();

    // Initialize camera if permission granted.
    if (camGranted) {
      final cameras = await availableCameras();
      _cameraReady = await _cameraAnalyzer.initialize(cameras);
      if (_cameraReady) {
        _cameraAnalyzer.startAnalysis();
      }
    }

    setState(() {
      _monitoring = true;
      _statusMessage = 'Monitoring active';
    });
  }

  Future<void> _stopMonitoring() async {
    await _sensorService.stop();
    await _cameraAnalyzer.stopAnalysis();
    _predictionTimer?.cancel();
    setState(() {
      _monitoring = false;
      _cameraReady = false;
      _statusMessage = 'Monitoring stopped';
    });
  }

  // ─────────────────────────────────────────────────────────────────
  // Sensor callbacks
  // ─────────────────────────────────────────────────────────────────

  void _onSensorSnapshot(SensorSnapshot snapshot) {
    if (!mounted) return;
    setState(() => _latest = snapshot);

    // Debounce API calls to once per 3 seconds.
    _predictionTimer?.cancel();
    _predictionTimer = Timer(const Duration(seconds: 3), () {
      _fetchRisk(snapshot);
    });
  }

  void _onCameraResult(CameraAnalysisResult result) {
    if (!mounted) return;
    setState(() => _cameraResult = result);

  }

  Future<void> _fetchRisk(SensorSnapshot snap) async {
    final risk = await ApiService.predictRisk(
      noise: snap.noiseDb.round(),
      light: snap.lightLux,
      heartRate: snap.heartRateEstimate,
      time: DateTime.now().hour,
    );

    if (!mounted) return;
    setState(() {
      _risk = risk;
      _riskHistory.add(risk);
      if (_riskHistory.length > _maxHistory) _riskHistory.removeAt(0);
    });

    if (risk == 'High') _showHighRiskAlert();
  }

  // ─────────────────────────────────────────────────────────────────
  // UI helpers
  // ─────────────────────────────────────────────────────────────────

  Color _riskColor([String? r]) {
    switch (r ?? _risk) {
      case 'Low':
        return Colors.green.shade400;
      case 'Medium':
        return Colors.orange.shade400;
      case 'High':
        return Colors.red.shade400;
      default:
        return Colors.white38;
    }
  }

  void _showHighRiskAlert() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('⚠️ High Risk Detected',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          'Sensory overload risk is HIGH.\n\n'
          '• Move to a quieter space\n'
          '• Reduce screen brightness\n'
          '• Use noise-cancelling headphones\n'
          '• Try the breathing exercise below\n'
          '• Close your eyes for 30 seconds',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  // Facial-tension/eye-strain/head-tilt UI removed intentionally.


  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final snap = _latest;
    final cam = _cameraResult;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12122A),
        title: const Row(
          children: [
            Text('🧠 ', style: TextStyle(fontSize: 22)),
            Text('SensAI',
                style: TextStyle(
                    color: Colors.tealAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          // Camera preview toggle
          if (_cameraReady)
            IconButton(
              icon: Icon(
                _showCameraPreview ? Icons.videocam : Icons.videocam_off,
                color: Colors.tealAccent,
              ),
              tooltip: 'Toggle camera preview',
              onPressed: () =>
                  setState(() => _showCameraPreview = !_showCameraPreview),
            ),
          IconButton(
            icon: Icon(
              _monitoring ? Icons.stop_circle : Icons.play_circle,
              color: _monitoring ? Colors.red : Colors.tealAccent,
            ),
            tooltip: _monitoring ? 'Stop monitoring' : 'Start monitoring',
            onPressed: _monitoring ? _stopMonitoring : _startMonitoring,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status bar ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _monitoring
                    ? Colors.teal.withOpacity(0.15)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _monitoring ? Icons.sensors : Icons.sensors_off,
                    color: _monitoring ? Colors.tealAccent : Colors.white38,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_statusMessage,
                        style: TextStyle(
                            color:
                                _monitoring ? Colors.tealAccent : Colors.white38,
                            fontSize: 13)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Risk banner ─────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _riskColor().withOpacity(0.2),
                    _riskColor().withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _riskColor().withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  const Text('Overload Risk',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    _risk,
                    style: TextStyle(
                        color: _riskColor(),
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2),
                  ),
                  const SizedBox(height: 8),
                  // Mini risk history
                  if (_riskHistory.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _riskHistory
                          .map((r) => Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _riskColor(r).withOpacity(0.8),
                                ),
                              ))
                          .toList(),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Camera preview (optional) ───────────────────────────
            if (_showCameraPreview && _cameraReady)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 200,
                  child: CameraPreview(_cameraAnalyzer.controller!),
                ),
              ),

            const SizedBox(height: 12),

            // ── Sensor cards ────────────────────────────────────────
            const Text('  Live Sensors',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5)),
            const SizedBox(height: 6),

            // Microphone
            SensorCard(
              icon: Icons.mic,
              title: 'Noise Level',
              value: snap != null ? snap.noiseDb.toStringAsFixed(1) : '—',
              unit: 'dB',
              color: snap != null && snap.noiseDb > 85
                  ? Colors.redAccent
                  : Colors.lightBlueAccent,
              progress: snap != null ? (snap.noiseDb / 120) : null,
              subtitle: snap != null
                  ? (snap.noiseDb > 85
                      ? '🔴 Loud'
                      : snap.noiseDb > 65
                          ? '🟡 Moderate'
                          : '🟢 Quiet')
                  : null,
            ),

            // Light sensor
            SensorCard(
              icon: Icons.wb_sunny,
              title: 'Ambient Light',
              value: snap != null ? '${snap.lightLux}' : '—',
              unit: 'Lux',
              color: snap != null && snap.lightLux > 800
                  ? Colors.amberAccent
                  : Colors.yellowAccent,
              progress: snap != null
                  ? (snap.lightLux / 1000).clamp(0.0, 1.0)
                  : null,
              subtitle: snap != null
                  ? (snap.lightLux > 800
                      ? '🔴 Bright'
                      : snap.lightLux > 300
                          ? '🟡 Normal'
                          : '🟢 Dim')
                  : null,
            ),

            // Accelerometer / motion
            SensorCard(
              icon: Icons.waves,
              title: 'Motion Intensity',
              value: snap != null
                  ? snap.motionIntensity.toStringAsFixed(2)
                  : '—',
              unit: 'm/s²',
              color: snap != null && snap.motionIntensity > 2
                  ? Colors.orangeAccent
                  : Colors.greenAccent,
              progress: snap != null
                  ? (snap.motionIntensity / 10).clamp(0.0, 1.0)
                  : null,
              subtitle: snap != null
                  ? (snap.motionIntensity > 4
                      ? '🔴 High motion'
                      : snap.motionIntensity > 1
                          ? '🟡 Moving'
                          : '🟢 Still')
                  : null,
            ),

            // Heart rate
            SensorCard(
              icon: Icons.favorite,
              title: 'Heart Rate',
              value: snap != null ? '${snap.heartRateEstimate}' : '—',
              unit: 'BPM',
              color: snap != null && snap.heartRateEstimate > 100
                  ? Colors.pinkAccent
                  : Colors.redAccent,
              progress: snap != null
                  ? ((snap.heartRateEstimate - 40) / 140).clamp(0.0, 1.0)
                  : null,
              subtitle: snap != null
                  ? (snap.heartRateEstimate > 100
                      ? '🔴 Elevated'
                      : snap.heartRateEstimate > 80
                          ? '🟡 Normal-high'
                          : '🟢 Resting')
                  : null,
            ),

            const SizedBox(height: 12),

            // ── Camera / facial analysis ────────────────────────────
            const Text('  Camera Analysis',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5)),
            const SizedBox(height: 6),



            // Faces / crowd density
            SensorCard(
              icon: Icons.people,
              title: 'Faces Detected',
              value: cam != null ? '${cam.facesDetected}' : '—',
              unit: 'people',
              color: Colors.cyanAccent,
              subtitle: cam != null
                  ? (cam.facesDetected > 3
                      ? '🔴 Crowded area'
                      : cam.facesDetected > 0
                          ? '🟡 Some people'
                          : '🟢 Alone / clear')
                  : null,
            ),



            const SizedBox(height: 20),

            // ── Breathing exercise ──────────────────────────────────
            const BreathingExercise(),

            const SizedBox(height: 20),

            // ── Action buttons ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _monitoring
                          ? Colors.red.shade700
                          : Colors.teal.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(_monitoring ? Icons.stop : Icons.play_arrow),
                    label: Text(_monitoring
                        ? 'Stop Monitoring'
                        : 'Start Monitoring'),
                    onPressed:
                        _monitoring ? _stopMonitoring : _startMonitoring,
                  ),
                ),
                if (_monitoring && snap != null) ...[
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Predict'),
                    onPressed: () => _fetchRisk(snap),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // ── Calming tips ────────────────────────────────────────
            if (_risk == 'Medium' || _risk == 'High')
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade900.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.indigo.shade400.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tips_and_updates,
                            color: Colors.amberAccent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _risk == 'High'
                              ? 'Immediate Relief Suggestions'
                              : 'Preventive Suggestions',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ..._tips(_risk).map(
                      (tip) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text('• $tip',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  List<String> _tips(String risk) {
    if (risk == 'High') {
      return [
        'Move to a quieter, dimmer environment immediately',
        'Put on noise-cancelling headphones',
        'Perform the 4-7-8 breathing exercise above',
        'Reduce screen brightness to minimum',
        'Close your eyes and breathe for 60 seconds',
        'Inform a caregiver if available',
      ];
    }
    return [
      'Take short breaks every 20 minutes',
      'Reduce surrounding noise if possible',
      'Dim overhead lights slightly',
      'Stay hydrated and avoid caffeine',
      'Practice the breathing exercise proactively',
    ];
  }
}
