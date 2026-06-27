// =====================================================================
// SensAI — ApiService
// Posts enriched sensor data to the FastAPI backend.
// Falls back to an offline rule-based prediction if server unreachable.
// =====================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Change to your machine's LAN IP when testing on a physical device.
  // e.g. 'http://192.168.1.100:8000'
  static const String _baseUrl = 'http://127.0.0.1:8000';

  static Future<String> predictRisk({
    required int noise,
    required int light,
    required int heartRate,
    required int time,
    double motionIntensity = 0.5,
    int crowdDensity = 0,
  }) async {

    final url = Uri.parse('$_baseUrl/predict');
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'noise': noise,
              'light': light,
              'heartRate': heartRate,
              'time': time,
              'motionIntensity': motionIntensity,

              'crowdDensity': crowdDensity,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['risk'] as String;
      }
      return 'Error';
    } catch (_) {
      return _offlineFallback(
          noise, light, heartRate, motionIntensity);
    }

  }

  /// Rule-based fallback (offline mode).
  static String _offlineFallback(int noise, int light, int heartRate,
      double motion) {

    int score = 0;
    if (noise > 85) score += 3;
    else if (noise > 70) score += 2;
    else if (noise > 55) score += 1;

    if (light > 1000) score += 3;
    else if (light > 600) score += 2;
    else if (light > 300) score += 1;

    if (heartRate > 110) score += 3;
    else if (heartRate > 90) score += 2;
    else if (heartRate > 80) score += 1;

    if (motion > 4) score += 2;
    else if (motion > 2) score += 1;

    if (score >= 8) return 'High';

    if (score >= 4) return 'Medium';
    return 'Low';
  }
}
