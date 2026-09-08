import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hogwarts_life_simulator/providers/game_provider.dart';
import 'package:hogwarts_life_simulator/screens/game/game_bottom_input.dart';
import 'package:hogwarts_life_simulator/screens/game/game_top_bar.dart';
import 'package:hogwarts_life_simulator/theme/miuix_tokens.dart';

import 'helpers/test_fixtures.dart';

/// 批 16：F21 UI 测试补全 —— 两个游戏主界面高频组件用测试 fixture 渲染。
///
/// 同时回批 14 的 F24 工作：用 `bySemanticsLabel` 断言「主界面已补语义标签」，
/// 读屏用户依赖的 label 一旦被删，这里立刻红。
///
/// 时序注意：`makeGame()` 尾部的 `unawaited(autoSave())` 会注册一个 300ms
/// 防抖定时器，而 `testWidgets` 运行在 fake-async zone——用例结束时若还有
/// 残留定时器会直接报错，且 `pumpAndSettle` 会与 SnackBar 的自动隐藏定时器
/// 纠缠到超时。因此这里一律用「显式 `pump(时长)` 推进时钟」，并在用例结尾
/// 用 `_flushTimers` 把所有残留定时器消费完。
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

/// 消费掉 fake-async zone 里的残留定时器：
///  · makeGame 尾部 autoSave 的 300ms 防抖定时器；
///  · (SnackBar 用例里) 1s 自动隐藏定时器。
/// 分次 pump 是让「定时器触发 → 写盘微任务 → notifyListeners → 帧」这段
/// 异步链完整落地，避免用例结束时报「A Timer is still pending」。
Future<void> _flushTimers(WidgetTester tester, {Duration extra = Duration.zero}) async {
  await tester.pump(const Duration(milliseconds: 400) + extra);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump();
}

void main() {
  testWidgets('GameTopBar 渲染玩家姓名与快速存档语义标签', (tester) async {
    _phoneSize(tester);
    final gp = await makeGame(); // 默认全属性 50 的「测试巫师」，不跑 AI 不走网络
    // testWidgets 默认关闭 semantics，`bySemanticsLabel` 前必须先显式开启
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pumpWidget(_wrap(gp, const GameTopBar()));

    expect(find.text('测试巫师'), findsOneWidget);
    // 批次 14 补的快速存档语义标签
    expect(find.bySemanticsLabel('快速存档'), findsOneWidget);

    await _flushTimers(tester);
  });

  testWidgets('GameTopBar 存档按钮写入后弹 SnackBar', (tester) async {
    _phoneSize(tester);
    final gp = await makeGame();
    await tester.pumpWidget(_wrap(gp, const GameTopBar()));

    await tester.tap(find.byIcon(Icons.save));
    await tester.pump(); // quickSave 走 writeSave（微任务即完成）→ showSnackBar
    await tester.pump(const Duration(milliseconds: 300)); // SnackBar 入场动画
    expect(find.text('✅ 已存档'), findsOneWidget);

    // 把 autoSave 防抖(300ms)与 SnackBar 自动隐藏(1s)定时器都消费掉
    await _flushTimers(tester, extra: MiuiDuration.snackbarShort);
  });

  testWidgets('GameBottomInput 渲染推进/指令中心/发送语义标签', (tester) async {
    _phoneSize(tester);
    final gp = await makeGame();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

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

    await _flushTimers(tester);
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
    await tester.pump();
    expect(fired, isTrue);

    await _flushTimers(tester);
  });
}