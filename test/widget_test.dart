import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hogwarts_life_simulator/main.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    // 首页在默认 600px 高的测试窗口下会溢出，放大到手机常见尺寸避免误报
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final app = AppProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: app),
          ChangeNotifierProvider<GameProvider>(
            create: (_) => GameProvider(app),
          ),
        ],
        child: const HogwartsLifeSimulator(),
      ),
    );

    expect(find.text('魔法人生模拟器'), findsOneWidget);
    expect(find.text('开始新人生'), findsOneWidget);
  });
}
