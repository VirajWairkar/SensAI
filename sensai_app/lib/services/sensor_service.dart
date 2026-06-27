// =====================================================================
// SensAI — SensorService
// Aggregates microphone (noise dB), device light sensor, accelerometer
// motion intensity, and camera-based facial analysis data.
// =====================================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:light/light.dart';
import 'package:permission_handler/permission_handler.dart';

/// Live snapshot of all sensor readings.
class SensorSnapshot {
  final double noiseDb;        // 0–120 dB
  final int lightLux;          // 0–100 000+ lux
  final double motionIntensity;// 0–10 (derived from accelerometer magnitude)
  final int heartRateEstimate; // 60–180 BPM (camera-derived or fallback)
  final DateTime timestamp;

  const SensorSnapshot({
    required this.noiseDb,
    required this.lightLux,
    required this.motionIntensity,
    required this.heartRateEstimate,
    required this.timestamp,
  });

}

/// Callback types.
typedef SensorCallback = void Function(SensorSnapshot snapshot);
typedef PermissionCallback = void Function(String message);

class SensorService {
  // ── Streams & subscriptions ─────────────────────────────────────
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<int>? _lightSub;

  // ── Current readings ────────────────────────────────────────────
  double _noiseDb = 45.0;
  int _lightLux = 300;
  double _motionIntensity = 0.5;
  int _heartRate = 72;


  // ── Accelerometer ring buffer for smoothing ──────────────────────
  final List<double> _accelBuffer = [];
  static const int _accelBufferSize = 10;

  // ── Callbacks ───────────────────────────────────────────────────
  SensorCallback? onSnapshot;
  PermissionCallback? onPermissionError;

  // ── Periodic broadcast timer ─────────────────────────────────────
  Timer? _broadcastTimer;

  bool _running = false;
  bool get isRunning => _running;

  // ─────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────

  /// Request all required permissions (mic, camera).
  Future<Map<Permission, PermissionStatus>> requestPermissions() async {
    return await [
      Permission.microphone,
      Permission.camera,
    ].request();
  }

  /// Start all sensors.
  Future<void> start() async {
    if (_running) return;
    _running = true;

    await _startMicrophone();
    _startAccelerometer();
    _startLightSensor();

    // Broadcast a merged snapshot every second.
    _broadcastTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      onSnapshot?.call(_buildSnapshot());
    });
  }

  /// Stop all sensors and cancel subscriptions.
  Future<void> stop() async {
    _running = false;
    await _noiseSub?.cancel();
    _accelSub?.cancel();
    _lightSub?.cancel();
    _broadcastTimer?.cancel();
    _noiseSub = null;
    _accelSub = null;
    _lightSub = null;
    _broadcastTimer = null;
  }



  /// Update heart rate from camera PPG or wearable bridge (BPM).
  void updateHeartRate(int bpm) {
    _heartRate = bpm.clamp(40, 220);
  }

  // ─────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────

  Future<void> _startMicrophone() async {
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      onPermissionError?.call('Microphone permission denied — noise monitoring disabled.');
      return;
    }
    try {
      _noiseMeter = NoiseMeter();
      _noiseSub = _noiseMeter!.noise.listen(
        (reading) {
          // meanDecibel is available on NoiseReading
          final db = reading.meanDecibel;
          if (db.isFinite && db > 0) {
            _noiseDb = db.clamp(0, 120);
          }
        },
        onError: (e) => debugPrint('[SensAI] Noise meter error: $e'),
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[SensAI] Could not start noise meter: $e');
    }
  }

  void _startAccelerometer() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen(
      (event) {
        // Magnitude of acceleration vector (gravity ~9.8 m/s²; subtract it
        // by tracking deviation from baseline).
        final mag = sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z,
        );
        // Deviation from gravitational rest (~9.8). Clamp to 0–10.
        final deviation = (mag - 9.81).abs().clamp(0.0, 10.0);

        _accelBuffer.add(deviation);
        if (_accelBuffer.length > _accelBufferSize) {
          _accelBuffer.removeAt(0);
        }
        // Rolling average for smooth reading.
        _motionIntensity =
            _accelBuffer.reduce((a, b) => a + b) / _accelBuffer.length;
      },
      onError: (e) => debugPrint('[SensAI] Accelerometer error: $e'),
      cancelOnError: false,
    );
  }

  void _startLightSensor() {
    try {
      final light = Light();
      _lightSub = light.lightSensorStream.listen(
        (lux) {
          if (lux >= 0) _lightLux = lux;
        },
        onError: (e) => debugPrint('[SensAI] Light sensor error: $e'),
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[SensAI] Light sensor unavailable: $e');
      // Many emulators/devices lack a light sensor — keep default value.
    }
  }

  SensorSnapshot _buildSnapshot() {
    return SensorSnapshot(
      noiseDb: _noiseDb,
      lightLux: _lightLux,
      motionIntensity: double.parse(_motionIntensity.toStringAsFixed(2)),
      heartRateEstimate: _heartRate,
      timestamp: DateTime.now(),

    );
  }
}
