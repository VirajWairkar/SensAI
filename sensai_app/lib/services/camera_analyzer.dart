// =====================================================================
// SensAI — CameraAnalyzer
// Uses the front camera + Google ML Kit Face Detection to:
//   1. Estimate crowd density from face count
//   2. Feed results back to SensorService

// =====================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'sensor_service.dart';

/// Result of one camera frame analysis.
class CameraAnalysisResult {
  /// Face count proxy for crowd density.
  final int facesDetected;
  final DateTime timestamp;

  const CameraAnalysisResult({
    required this.facesDetected,
    required this.timestamp,
  });
}


typedef CameraResultCallback = void Function(CameraAnalysisResult result);

class CameraAnalyzer {
  CameraController? _controller;
  FaceDetector? _faceDetector;
  bool _isAnalyzing = false;
  bool _running = false;
  Timer? _analysisTimer;

  CameraResultCallback? onResult;

  // ─────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────

  Future<bool> initialize(List<CameraDescription> cameras) async {
    // Prefer front camera for facial analysis.
    CameraDescription? front;
    for (final cam in cameras) {
      if (cam.lensDirection == CameraLensDirection.front) {
        front = cam;
        break;
      }
    }
    final selected = front ?? (cameras.isNotEmpty ? cameras.first : null);
    if (selected == null) return false;

    _controller = CameraController(
      selected,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21, // Android-compatible
    );

    try {
      await _controller!.initialize();
    } catch (e) {
      debugPrint('[SensAI] Camera init error: $e');
      return false;
    }

    _faceDetector = GoogleMlKit.vision.faceDetector(
      FaceDetectorOptions(
        enableClassification: true,  // smile, eye open probabilities
        enableLandmarks: true,       // nose, eyes position
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    return true;
  }

  /// Start periodic camera analysis (every 2 seconds to save battery).
  void startAnalysis() {
    if (_running) return;
    _running = true;
    _analysisTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _analyzeFrame();
    });
  }

  Future<void> stopAnalysis() async {
    _running = false;
    _analysisTimer?.cancel();
    _analysisTimer = null;
    await _faceDetector?.close();
    await _controller?.dispose();
    _controller = null;
  }

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  // ─────────────────────────────────────────────────────────────────
  // Core analysis
  // ─────────────────────────────────────────────────────────────────

  Future<void> _analyzeFrame() async {
    if (_isAnalyzing) return;
    if (_controller == null || !(_controller!.value.isInitialized)) return;
    _isAnalyzing = true;

    try {
      final XFile file = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector!.processImage(inputImage);

      final result = _buildResult(faces);
      onResult?.call(result);
    } catch (e) {
      debugPrint('[SensAI] Frame analysis error: $e');
    } finally {
      _isAnalyzing = false;
    }
  }

  CameraAnalysisResult _buildResult(List<Face> faces) {
    if (faces.isEmpty) {
      return CameraAnalysisResult(
        facesDetected: 0,
        timestamp: DateTime.now(),
      );
    }


    return CameraAnalysisResult(
      facesDetected: faces.length,
      timestamp: DateTime.now(),
    );

  }
}
