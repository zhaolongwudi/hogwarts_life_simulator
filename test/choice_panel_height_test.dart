import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/screens/game/choice_panel.dart';

/// 造 n 个选项，文案都是一句话长度——跟 AI 实际给的量级一致。
List<GameChoice> _choices(int n) => List.generate(
      n,
      (i) => GameChoice(text: '第 $i 个选项：把这件事做到底', action: 'do_$i'),
    );

/// 把面板放进一个固定高度的槽里 pump 出来，然后量它的高度。
///
/// 用 Column（而不是直接 Center）是为了拿到"剩余空间"的语义：
/// 面板嵌在正文 Expanded 下面，它撑多大，正文就少多少。
Future<double> _panelHeight(
  WidgetTester tester, {
  required int count,
  required bool collapsed,
  required double maxHeight,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 800,
        child: Column(
          children: [
            const Expanded(child: SizedBox.expand()),
            ChoicePanel(
              choices: _choices(count),
              maxHeight: maxHeight,
              collapsed: collapsed,
              busy: false,
              onToggleCollapse: () {},
              onShuffle: () {},
              onPick: (_) {},
            ),
          ],
        ),
      ),
    ),
  ));
  return tester.getSize(find.byType(ChoicePanel)).height;
}

void main() {
  // ============================================================ 不再顶满
  group('选项面板不再吃掉正文的空间', () {
    testWidgets('两个选项的时候不该占满 maxHeight', (tester) async {
      // 这是原来的 bug：ConstrainedBox 夹外层 Column + 里面塞 Flexible，
      // Flexible 在有界约束下会吃掉全部剩余空间——
      // 于是 2 个选项和 6 个选项一样顶满 maxHeight（屏高的 42%）。
      const max = 300.0;
      final h2 = await _panelHeight(tester, count: 2, collapsed: false, maxHeight: max);
      expect(h2, lessThan(max * 0.8),
          reason: '2 个选项占了 ${h2.toStringAsFixed(0)}px，上限才 $max');
    });

    testWidgets('选项越少占得越少', (tester) async {
      const max = 400.0;
      final h1 = await _panelHeight(tester, count: 1, collapsed: false, maxHeight: max);
      final h3 = await _panelHeight(tester, count: 3, collapsed: false, maxHeight: max);
      expect(h3, greaterThan(h1),
          reason: '3 个选项该比 1 个高，否则就是写死了');
      expect(h3 - h1, greaterThan(60),
          reason: '每个选项至少五六十像素，两个的差额不该只有 ${(h3 - h1).toStringAsFixed(0)}px');
    });

    testWidgets('选项再多也不越过 maxHeight', (tester) async {
      const max = 260.0;
      final h = await _panelHeight(tester, count: 12, collapsed: false, maxHeight: max);
      expect(h, lessThanOrEqualTo(max + 1),
          reason: '12 个选项也要夹在 $max 以内，多出来的内部滚动');
    });

    testWidgets('收起后只剩一条标题栏', (tester) async {
      final expanded =
          await _panelHeight(tester, count: 4, collapsed: false, maxHeight: 300);
      final collapsed =
          await _panelHeight(tester, count: 4, collapsed: true, maxHeight: 300);
      expect(collapsed, lessThan(60),
          reason: '收起后不该还占 ${collapsed.toStringAsFixed(0)}px');
      expect(expanded - collapsed, greaterThan(150),
          reason: '收起省下的 ${(expanded - collapsed).toStringAsFixed(0)}px 太少，'
              '正文区感觉不到差别');
    });
  });

  // ============================================================ 交互
  group('收起 / 展开', () {
    testWidgets('标题栏上的按钮能切换', (tester) async {
      var collapsed = false;
      var toggles = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (ctx, setState) => ChoicePanel(
              choices: _choices(3),
              maxHeight: 300,
              collapsed: collapsed,
              busy: false,
              onToggleCollapse: () => setState(() {
                collapsed = !collapsed;
                toggles++;
              }),
              onShuffle: () {},
              onPick: (_) {},
            ),
          ),
        ),
      ));

      expect(find.text('收起'), findsOneWidget);
      await tester.tap(find.text('收起'));
      await tester.pumpAndSettle();
      expect(toggles, 1);

      // 收起后标题要告诉玩家有几个选项，否则他不知道底下压着什么
      expect(find.text('可选行动 · 3 项'), findsOneWidget);
      // 收起时看不到选项，"换一批"也一并藏起来
      expect(find.text('换一批'), findsNothing);

      await tester.tap(find.text('展开'));
      await tester.pumpAndSettle();
      expect(toggles, 2);
      expect(find.text('换一批'), findsOneWidget);
    });

    testWidgets('点选项把下标传出去', (tester) async {
      final picked = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ChoicePanel(
            choices: _choices(3),
            maxHeight: 300,
            collapsed: false,
            busy: false,
            onToggleCollapse: () {},
            onShuffle: () {},
            onPick: picked.add,
          ),
        ),
      ));

      await tester.tap(find.textContaining('C. '));
      expect(picked, [2]);
      // 选项按钮点完会锁 400ms 防连点，等它走完，
      // 否则测试结束时留下一个 pending timer。
      await tester.pump(const Duration(milliseconds: 450));
    });

    testWidgets('AI 在跑的时候换一批点不动', (tester) async {
      var shuffles = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ChoicePanel(
            choices: _choices(3),
            maxHeight: 300,
            collapsed: false,
            busy: true,
            onToggleCollapse: () {},
            onShuffle: () => shuffles++,
            onPick: (_) {},
          ),
        ),
      ));

      await tester.tap(find.text('换一批'));
      expect(shuffles, 0);
    });
  });
}
