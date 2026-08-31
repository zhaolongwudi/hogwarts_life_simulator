import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'utils/crash_logger.dart';
import 'utils/ai_debug_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CrashLogger.instance.load();

  // 捕获 Flutter 框架错误（例如 Widget build 抛出）
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    unawaited(CrashLogger.instance.record(
      details.exception,
      details.stack,
      screen: 'FlutterFrame',
      extra: details.context?.toString() ?? details.library ?? '',
    ));
  };

  // 捕获 Dart 层未处理的 async 错误
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(CrashLogger.instance.record(error, stack, screen: 'PlatformDispatcher'));
    return true;
  };

  final appProvider = AppProvider();
  await appProvider.loadSettings();
  // 应用启动时恢复 AI 调试日志开关（之前被清回false的根因）
  await AiDebugLogger.instance.initialize(enabled: appProvider.aiDebugLogEnabled);
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
      theme: _buildDarkTheme(),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/intro': (context) => const IntroScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/game': (context) => const GameScreen(),
      },
    );
  }

  ThemeData _buildDarkTheme() {
    const bgBase = Color(0xFF0d1117);
    const surface = Color(0xFF161b22);
    const card = Color(0xFF21262d);
    const border = Color(0xFF30363d);
    const gold = Color(0xFFD3A625);
    const deepRed = Color(0xFF740001);
    const textPrimary = Color(0xFFE6EDF3);
    const textSecondary = Color(0xFF8B949E);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgBase,
      canvasColor: bgBase,
      primaryColor: gold,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        onPrimary: Color(0xFF0d1117),
        secondary: deepRed,
        surface: surface,
        onSurface: textPrimary,
        outline: border,
        tertiary: gold,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: gold),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: gold),
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textPrimary),
        bodySmall: TextStyle(fontSize: 12, color: textSecondary),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        labelMedium: TextStyle(fontSize: 12, color: textSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary),
        shape: Border(bottom: BorderSide(color: border)),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: const Color(0xFF0d1117),
          disabledBackgroundColor: const Color(0xFF484f58),
          disabledForegroundColor: textSecondary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: gold, width: 2)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: gold,
        unselectedItemColor: textSecondary,
        backgroundColor: surface,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
      dividerColor: border,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: const TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: gold,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(color: textPrimary),
        secondaryLabelStyle: const TextStyle(color: textPrimary),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: gold,
        textColor: textPrimary,
        minLeadingWidth: 40,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(border),
        trackColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
