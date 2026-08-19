import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: const HogwartsLifeSimulator(),
    ),
  );
}

class HogwartsLifeSimulator extends StatelessWidget {
  const HogwartsLifeSimulator({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '魔法人生模拟器',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/intro': (context) => const IntroScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/game': (context) => const GameScreen(),
      },
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF740001),
      scaffoldBackgroundColor: const Color(0xFF0d1117),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF740001),
        secondary: Color(0xFFD3A625),
        surface: Color(0xFF161b22),
        onSurface: Color(0xFFe6edf3),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Color(0xFFD3A625),
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFe6edf3)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF8b949e)),
      ),
    );
  }
}
