import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appProvider = AppProvider();
  await appProvider.loadSettings();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: appProvider),
        ChangeNotifierProvider<GameProvider>(
          create: (_) => GameProvider(appProvider),
        ),
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
    const kPrimary = Color(0xFF6B4423);
    const kSecondary = Color(0xFFC9A86C);
    const kBackground = Color(0xFFF5F0E8);
    const kSurface = Color(0xFFFBF8F3);
    const kCard = Color(0xFFFFFBF5);
    const kText = Color(0xFF3D2914);
    const kTextLight = Color(0xFF8B7355);
    const kBorder = Color(0xFFE5D5C0);

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: kPrimary,
      scaffoldBackgroundColor: kBackground,
      colorScheme: const ColorScheme.light(
        primary: kPrimary,
        secondary: kSecondary,
        surface: kSurface,
        onSurface: kText,
        outline: kBorder,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: kPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: kText,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: kText,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: kText),
        bodyMedium: TextStyle(fontSize: 14, color: kTextLight),
        bodySmall: TextStyle(fontSize: 12, color: kTextLight),
      ),
      cardTheme: CardTheme(
        color: kCard,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPrimary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: kPrimary,
        unselectedItemColor: kTextLight,
        backgroundColor: kSurface,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kSurface,
        foregroundColor: kText,
        elevation: 1,
        centerTitle: true,
      ),
      dividerTheme: const DividerThemeData(
        color: kBorder,
        thickness: 1,
      ),
    );
  }
}
