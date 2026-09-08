import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hogwarts_life_simulator/models/game_systems.dart' show GameTime;
import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';
import 'package:hogwarts_life_simulator/screens/game/game_bottom_input.dart';
import 'package:hogwarts_life_simulator/screens/game/game_top_bar.dart';
import 'package:hogwarts_life_simulator/theme/miuix_tokens.dart';

/// 批 16：F21 UI 测试补全 —— 两个游戏主界面高频组件冒烟 + Semantics 回归。
///
/// 同时回批 14 的 F24 工作：用 `bySemanticsLabel` 断言「主界面已补语义标签」，
/// 读屏用户依赖的 label 一旦被删，这里立刻红。
///
/// 注意：**绝不能走 `makeGame()` / `initializeGame`**。它们内部的异步链
/// （如 SharedPreferences / Clear 链）在 `testWidgets` 的 fake-async zone 里
/// 不会被真实推进，导致用例卡到 10 分钟超时（先前 CI 实测崩溃点就在这里）。
/// 因此这里改为「构造 provider → 手动注入最小玩家」的静态方案，渲染与
/// 交互所需的状态全部同步就绪，而后写盘路径则由 `SharedPreferences.mock`
/// 承接（内存微任务，`pump` 即可落地；0 个 pending 定时器）。
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

/// 静态构造一个最小可渲染的 GameProvider：
///  · 不调用 initializeGame（避免 fake-async 挂起）；
///  · 注入一个「测试巫师」玩家；isLoading 默认为 false；
///  · mock SharedPreferences，使 quickSave/写盘走内存微任务即可完成。
GameProvider _buildGame() {
  SharedPreferences.setMockInitialValues({});
  final app = AppProvider();
  final gp = GameProvider(app);
  gp.worldState.time = GameTime(
    year: 1991,
    month: 9,
    day: 1,
    hour: 9,
    minute: 0,
  );
  gp.player = Player(
    name: '测试巫师',
    birthYear: '1980',
    bloodType: 'halfblood',
    birthLocation: '伦敦',
  );
  return gp;
}

void main() {
  testWidgets('GameTopBar 渲染玩家姓名与快速存档语义标签', (tester) async {
    _phoneSize(tester);
    final gp = _buildGame();
    // testWidgets 默认关闭 semantics，`bySemanticsLabel` 前必须先显式开启
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pumpWidget(_wrap(gp, const GameTopBar()));

    expect(find.text('测试巫师'), findsOneWidget);
    // 批次 14 补的快速存档语义标签
    expect(find.bySemanticsLabel('快速存档'), findsOneWidget);
  });

  testWidgets('GameTopBar 存档按钮写入后弹 SnackBar', (tester) async {
    _phoneSize(tester);
    final gp = _buildGame();
    await tester.pumpWidget(_wrap(gp, const GameTopBar()));

    await tester.tap(find.byIcon(Icons.save));
    await tester.pump(); // quickSave → 内存写档（微任务即完成）→ showSnackBar
    await tester.pump(const Duration(milliseconds: 300)); // SnackBar 入场动画
    expect(find.text('✅ 已存档'), findsOneWidget);

    // 消化 SnackBar 1s 自动隐藏定时器，避免用例结束报「A Timer is still pending」
    await tester.pump(MiuiDuration.snackbarShort + const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('GameBottomInput 渲染推进/指令中心/发送语义标签', (tester) async {
    _phoneSize(tester);
    final gp = _buildGame();
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
  });

  testWidgets('GameBottomInput 发送按钮触发行动回调', (tester) async {
    _phoneSize(tester);
    final gp = _buildGame();
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
  });
}