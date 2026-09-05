import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'utils/crash_logger.dart';
import 'utils/ai_debug_logger.dart';
import 'theme/miuix_theme.dart';

void main() async {
  // runZonedGuarded 包裹整个 main 体：
  // 1) 接住 FlutterError.onError 还没安装好之前（WidgetsFlutterBinding 前）的异常；
  // 2) 接住底层 Platform 层（isolate）的 unhandled async error；
  // 3) app 标识写入所有崩溃记录 extra，方便用户在自己的"应用信息→崩溃"里找到本 app。
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await CrashLogger.instance.load();

      // 捕获 Flutter 框架错误（例如 Widget build 抛出）
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        // 同步写：崩溃瞬间进程可能马上被杀，异步 record 没机会完成
        CrashLogger.instance.recordSync(
          details.exception,
          details.stack,
          screen: 'FlutterFrame',
          extra: _appTag() + ' | ' +
              (details.context?.toString() ?? details.library ?? ''),
        );
      };

      // 捕获 Dart 层未处理的 async 错误
      PlatformDispatcher.instance.onError = (error, stack) {
        CrashLogger.instance.recordSync(
          error,
          stack,
          screen: 'PlatformDispatcher',
          extra: _appTag(),
        );
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
    },
    (error, stack) {
      // 任何 zone 兜不住的错误都落盘崩溃日志
      FlutterError.presentError(FlutterErrorDetails(exception: error, stack: stack));
      CrashLogger.instance.recordSync(
        error,
        stack,
        screen: 'runZonedGuarded',
        extra: _appTag(),
      );
    },
  );
}

/// 当前 app 标识（包名 + 版本）：所有崩溃日志 extra 里都带这个，
/// 用户在系统"应用信息 → 崩溃"里找不到本 app 时，可以用这串标识搜索匹配。
String _appTag() {
  // 这里不引入 package_info_plus 依赖（避免 APK 增大），直接读编译期常量。
  // pubspec.yaml 是单一事实源，runtime 用 const 兜底，
  // 如需精确值可后续加 PackageInfo.fromPlatform()。
  return 'app=hogwarts_life_simulator v=${const String.fromEnvironment("APP_VERSION", defaultValue: "3.5.x")}';
}

class HogwartsLifeSimulator extends StatelessWidget {
  const HogwartsLifeSimulator({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '魔法人生模拟器',
      debugShowCheckedModeBanner: false,
      theme: MiuiTheme.build(),
      // 全局套用 Miuix 的弹性滚动手感
      builder: (context, child) => MiuiScrollConfiguration(
        child: child ?? const SizedBox.shrink(),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/intro': (context) => const IntroScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/game': (context) => const GameScreen(),
      },
    );
  }
}
