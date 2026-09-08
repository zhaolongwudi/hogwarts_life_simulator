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

/// 批 16：F21 UI 测试补全 —— 两个游戏主界面高频组件冒烟 + Semantics 回归。
///
/// 同时回批 14 的 F24 工作：用读「Semantics 组件的 label」断言主界面语义标签
/// 仍在 —— 读屏用户依赖的 label 一旦被删，这里立刻红。不用 `bySemanticsLabel`
/// 是因为它依赖 semantics 树启用（testWidgets 默认关闭且 ensureSemantics 在
/// 本项目自动化绑定下不稳定），而直接读 widget 的 `properties.label` 不依赖
/// 语义树，既可靠又不引入额外句柄生命周期负担。
///
/// 注意：**绝不能走 `makeGame()` / `initializeGame`**。其内部异步链（Shared-
/// Preferences / secure_storage 读取链）在 `testWidgets` 的 fake-async zone 不
/// 会被真实推进，先前 CI 实测首用例卡满 10 分钟 `TimeoutException`。改为「构造
/// provider → 手动注入最小玩家」的静态方案：渲染/交互所需状态全同步就绪，
/// 写盘/quickSave 由 `SharedPreferences.setMockInitialValues` 承接（内存微任务）。
///
/// 取舍：存档按钮的「写入成功 → SnackBar」反馈交互未覆盖——quickSave 底层经
/// path_provider 读真实文档目录，测试环境无插件实现必然抛 MissingPluginException，
/// 属测试环境对真实文件系统的固有依赖，而非 UI 逻辑问题；渲染、语义标签与
/// 核心回调已充分覆盖。
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
///  · 注入「测试巫师」玩家；isLoading 默认 false；
///  · mock SharedPreferences，quickSave/写盘走内存微任务即可完成。
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

/// 读离 [icon] 最近的一层显式 `Semantics` 的语义标签。
/// 不依赖 semantics 树启用，直接读 widget 实例属性。
String? _semLabel(WidgetTester tester, IconData icon) {
  final sem = tester.widget<Semantics>(
    find
        .ancestor(
          of: find.byIcon(icon),
          matching: find.byType(Semantics),
        )
        .first,
  );
  return sem.properties?.label;
}

void main() {
  testWidgets('GameTopBar 渲染玩家姓名与快速存档语义标签', (tester) async {
    _phoneSize(tester);
    final gp = _buildGame();
    await tester.pumpWidget(_wrap(gp, const GameTopBar()));

    expect(find.text('测试巫师'), findsOneWidget);
    // 批次 14 补的快速存档语义标签
    expect(_semLabel(tester, Icons.save), '快速存档');
  });

  testWidgets('GameBottomInput 渲染推进/指令中心/发送语义标签', (tester) async {
    _phoneSize(tester);
    final gp = _buildGame();
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(
      gp,
      GameBottomInput(
        inputController: controller,
        onHandleFreeAction: () {},
      ),
    ));

    expect(_semLabel(tester, Icons.skip_next), '推进剧情');
    expect(_semLabel(tester, Icons.terminal), '打开指令中心');
    expect(_semLabel(tester, Icons.send), '发送行动');
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