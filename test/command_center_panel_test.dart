/// 指令中心面板测试：数据驱动渲染 / 搜索过滤 / 分组 / 执行与填参
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/command_registry.dart';
import 'package:hogwarts_life_simulator/screens/game/command_center_panel.dart';

void main() {
  setUp(() {
    CommandRegistry.instance.resetForTesting();
    CommandRegistry.instance.registerAll(const [
      CommandDef(
        primary: '状态',
        group: '基础信息',
        helpText: '查看完整角色面板',
        handler: _noopHandler,
      ),
      CommandDef(
        primary: '送礼',
        group: '关系&情感',
        helpText: '把背包里的东西送给NPC：/送礼 [名字] [物品]',
        handler: _noopHandler,
      ),
      CommandDef(
        primary: 'cheat',
        group: '作弊',
        helpText: '作弊指令总入口，详情见 /cheat',
        permission: 'cheat',
        handler: _noopHandler,
      ),
    ]);
    CommandRegistry.instance.seal();
  });

  testWidgets('面板打开：标题 + 全部指令分组展示', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.byIcon(Icons.terminal));
    await tester.pumpAndSettle();

    expect(find.text('⚡ 指令中心'), findsOneWidget);
    expect(find.text('共 3 条指令'), findsOneWidget);
    // 分组标题都在
    expect(find.text('基础信息'), findsOneWidget);
    expect(find.text('关系&情感'), findsOneWidget);
    // 指令条目
    expect(find.text('/状态'), findsOneWidget);
    expect(find.text('/送礼（/送、/赠、/赠送、/给）'), findsNothing); // 无别名注册
    expect(find.text('/送礼'), findsOneWidget);
  });

  testWidgets('搜索：按名称/说明实时过滤', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.byIcon(Icons.terminal));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '送礼');
    await tester.pumpAndSettle();
    expect(find.text('/送礼'), findsOneWidget);
    expect(find.text('/状态'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '角色面板');
    await tester.pumpAndSettle();
    expect(find.text('/状态'), findsOneWidget);
    expect(find.text('/送礼'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '不存在的指令');
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的指令'), findsOneWidget);
  });

  testWidgets('无参指令点运行：直接执行', (tester) async {
    String? executed;
    await tester.pumpWidget(_host((cmd) { executed = cmd; }));
    await tester.tap(find.byIcon(Icons.terminal));
    await tester.pumpAndSettle();

    // 精准定位 /状态 那一行的「运行」按钮
    final statusRow = find.ancestor(of: find.text('/状态'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: statusRow, matching: find.text('运行')));
    await tester.pumpAndSettle();
    expect(executed, '/状态');
    // 面板已关闭
    expect(find.text('⚡ 指令中心'), findsNothing);
  });

  testWidgets('带参指令点填参：填入输入框并关闭', (tester) async {
    String? filled;
    await tester.pumpWidget(_host(null, (t) { filled = t; }));
    await tester.tap(find.byIcon(Icons.terminal));
    await tester.pumpAndSettle();

    // 「填参」只有 /送礼 一个（其余注册指令均无参数）
    await tester.tap(find.text('填参'));
    await tester.pumpAndSettle();
    expect(filled, '/送礼 ');
    expect(find.text('⚡ 指令中心'), findsNothing);
  });

  testWidgets('作弊分区折叠后隐藏', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.byIcon(Icons.terminal));
    await tester.pumpAndSettle();

    // 作弊组默认折叠：标题可见，条目隐藏
    expect(find.textContaining('作弊'), findsWidgets);
    expect(find.text('/cheat'), findsNothing);
  });
}

bool _noopHandler(CommandContext ctx) => true;

Widget _host([void Function(String)? exec, void Function(String)? fill]) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: IconButton(
            icon: const Icon(Icons.terminal),
            onPressed: () => showCommandCenter(
              context,
              onExecute: exec ?? (_) {},
              onFillInput: fill ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}
