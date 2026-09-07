import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hogwarts_life_simulator/providers/game_provider.dart';
import 'package:hogwarts_life_simulator/screens/game/game_bottom_input.dart';
import 'package:hogwarts_life_simulator/screens/game/game_top_bar.dart';

import 'helpers/test_fixtures.dart';

/// 批 16：F21 UI 测试补全 —— 两个游戏主界面高频组件用测试 fixture 渲染。
///
/// 同时回批 14 的 F24 工作：用 `bySemanticsLabel` 断言「主界面已补语义标签」，
/// 读屏用户依赖的 label 一旦被删，这里立刻红。
Widget _wrap(GameProvider gp, Widget child) {
  return ChangeNotifierProvider<GameProvider>.value(
    value: gp,
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

/// 顶栏/输入栏都是较宽的横向排列，放大到手机尺寸避免溢出误报。
void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('GameTopBar 渲染玩家姓名与快速存档语义标签', (tester) async {
    _phoneSize(tester);
    final gp = await makeGame(); // 默认全属性 50 的「测试巫师」，不跑 AI 不走网络

    await tester.pumpWidget(_wrap(gp, const GameTopBar()));

    expect(find.text('测试巫师'), findsOneWidget);
    // 批次 14 补的快速存档语义标签
    expect(find.bySemanticsLabel('快速存档'), findsOneWidget);
  });

  testWidgets('GameTopBar 存档按钮写入后弹 SnackBar', (tester) async {
    _phoneSize(tester);
    final gp = await makeGame();

    await tester.pumpWidget(_wrap(gp, const GameTopBar()));

    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(find.text('✅ 已存档'), findsOneWidget);
  });

  testWidgets('GameBottomInput 渲染推进/指令中心/发送语义标签', (tester) async {
    _phoneSize(tester);
    final gp = await makeGame();
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(
      gp,
      GameBottomInput(
        inputController: controller,
        onHandleFreeAction: () {},
      ),
    ));

    expect(find.bySemanticsLabel('推进剧情'), findsOneWidget);
    expect(find.bySemanticsLabel('打开指令中心'), findsOneWidget);
    expect(find.bySemanticsLabel('发送行动'), findsOneWidget);
    expect(find.text('输入行动或 /命令'), findsOneWidget);
  });

  testWidgets('GameBottomInput 发送按钮触发行动回调', (tester) async {
    _phoneSize(tester);
    final gp = await makeGame();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var fired = false;

    await tester.pumpWidget(_wrap(
      gp,
      GameBottomInput(
        inputController: controller,
        onHandleFreeAction: () => fired = true,
      ),
    ));

    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(fired, isTrue);
  });
}