import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SensAIApp());
}

class SensAIApp extends StatelessWidget {
  const SensAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SensAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.purpleAccent,
          surface: const Color(0xFF12122A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
        cardColor: Colors.grey.shade900,
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
