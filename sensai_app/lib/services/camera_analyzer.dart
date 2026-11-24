// =====================================================================
// SensAI — CameraAnalyzer
// Uses the front camera + Google ML Kit Face Detection to:
//   1. Estimate crowd density from face count
//   2. Feed results back to SensorService

// =====================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

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
  String? _lastError;

  CameraResultCallback? onResult;

  // ─────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────

  Future<bool> initialize(List<CameraDescription> cameras) async {
    await stopAnalysis();
    _lastError = null;

    // Prefer front camera for facial analysis.
    CameraDescription? front;
    for (final cam in cameras) {
      if (cam.lensDirection == CameraLensDirection.front) {
        front = cam;
        break;
      }
    }
    final selected = front ?? (cameras.isNotEmpty ? cameras.first : null);
    if (selected == null) {
      _lastError = 'No camera was found on this device.';
      return false;
    }

    _controller = CameraController(
      selected,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
    } on CameraException catch (e) {
      _lastError = _cameraErrorMessage(e);
      debugPrint('[SensAI] Camera init error (${e.code}): ${e.description}');
      await _controller?.dispose();
      _controller = null;
      return false;
    } catch (e) {
      _lastError = 'Could not start the camera: $e';
      debugPrint('[SensAI] Camera init error: $e');
      await _controller?.dispose();
      _controller = null;
      return false;
    }

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // smile, eye open probabilities
        enableLandmarks: true, // nose, eyes position
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    return true;
  }

  /// Start periodic camera analysis (every 2 seconds to save battery).
  void startAnalysis() {
    if (_running || !isInitialized || _faceDetector == null) return;
    _running = true;
    unawaited(_analyzeFrame());
    _analysisTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_analyzeFrame());
    });
  }

  Future<void> stopAnalysis() async {
    _running = false;
    _analysisTimer?.cancel();
    _analysisTimer = null;
    final detector = _faceDetector;
    final controller = _controller;
    _faceDetector = null;
    _controller = null;
    await detector?.close();
    await controller?.dispose();
  }

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  String? get lastError => _lastError;

  // ─────────────────────────────────────────────────────────────────
  // Core analysis
  // ─────────────────────────────────────────────────────────────────

  Future<void> _analyzeFrame() async {
    if (_isAnalyzing) return;
    final controller = _controller;
    final detector = _faceDetector;
    if (controller == null ||
        detector == null ||
        !controller.value.isInitialized) {
      return;
    }
    _isAnalyzing = true;

    try {
      final XFile file = await controller.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await detector.processImage(inputImage);

      final result = _buildResult(faces);
      onResult?.call(result);
    } catch (e) {
      debugPrint('[SensAI] Frame analysis error: $e');
    } finally {
      _isAnalyzing = false;
    }
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Camera access is denied. Enable it in the app settings.';
      case 'AudioAccessDenied':
      case 'AudioAccessDeniedWithoutPrompt':
      case 'AudioAccessRestricted':
        return 'Camera audio access is denied.';
      default:
        return error.description == null || error.description!.isEmpty
            ? 'Could not start the camera (${error.code}).'
            : 'Could not start the camera: ${error.description}';
    }
  }

  CameraAnalysisResult _buildResult(List<Face> faces) {
    if (faces.isEmpty) {
      return CameraAnalysisResult(facesDetected: 0, timestamp: DateTime.now());
    }

    return CameraAnalysisResult(
      facesDetected: faces.length,
      timestamp: DateTime.now(),
    );
  }
}
