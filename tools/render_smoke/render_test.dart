// UI 渲染冒烟测试（开发用，不进 CI）：
// 渲染设计系统 + 液态玻璃导航栏，用 golden 生成 PNG 供人工检查。
// 运行：flutter test tools/render_smoke/render_test.dart --update-goldens
// 然后查看 tools/render_smoke/goldens/*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hogwarts_life_simulator/theme/miuix_theme.dart';
import 'package:hogwarts_life_simulator/theme/miuix_tokens.dart';
import 'package:hogwarts_life_simulator/theme/miuix_typography.dart';
import 'package:hogwarts_life_simulator/widgets/liquid_glass_nav_bar.dart';
import 'package:hogwarts_life_simulator/widgets/miui_magic_backdrop.dart';
import 'package:hogwarts_life_simulator/widgets/miuix_components.dart';
import 'package:hogwarts_life_simulator/screens/intro_screen.dart';
import 'package:hogwarts_life_simulator/screens/save_load_screen.dart';
import 'package:hogwarts_life_simulator/screens/memory_screen.dart';
import 'package:hogwarts_life_simulator/screens/game/game_bottom_input.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: MiuiTheme.build(),
    home: Scaffold(body: child),
  );
}

/// 设计系统全组件陈列。
class _DesignSystemPage extends StatelessWidget {
  const _DesignSystemPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SizedBox(height: 12),
          MiuiSmallTitle('基础信息'),
          MiuiListSection(
            children: [
              MiuiListItem(
                title: '赫敏 · 格兰杰',
                subtitle: '格兰芬多 · 好感度 86',
                leading: Icon(Icons.person),
                trailing: Icon(Icons.chevron_right),
              ),
              MiuiListItem(
                title: '二年级 · 冬季',
                subtitle: '12 月 3 日 周二',
                leading: Icon(Icons.calendar_month),
                showDivider: false,
              ),
            ],
          ),
          MiuiSmallTitle('数值与进度'),
          _StatsDemo(),
          MiuiSmallTitle('按钮'),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                MiuiButton(label: '继续冒险', onPressed: null),
                MiuiButton(label: '继续冒险', onPressed: _noop),
                MiuiButton(label: '中性按钮', primary: false, onPressed: _noop),
                MiuiButton(label: '危险操作', danger: true, onPressed: _noop),
              ],
            ),
          ),
          SizedBox(height: 16),
          MiuiSmallTitle('分段控件'),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: MiuiSegmented<String>(
              segments: const {'a': '叙述', 'b': '对话', 'c': '状态'},
              selected: 'b',
              onChanged: _noop1,
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatsDemo extends StatelessWidget {
  const _StatsDemo();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: MiuiCard(
        child: Column(
          children: [
            _Row(label: '健康', value: 82, color: MiuiColors.success),
            _Row(label: '魔力', value: 64, color: MiuiColors.info),
            _Row(label: '声望', value: 41, color: MiuiColors.primaryVariant),
            _Row(label: '黑魔法声望', value: 12, color: MiuiColors.error),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: MiuiType.body2),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 6,
                backgroundColor: MiuiColors.sliderBackground,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text('$value', style: MiuiType.numeric),
          ),
        ],
      ),
    );
  }
}

/// 液态玻璃导航栏场景：底下是魔法辉光 + 一张"模拟背景"。
class _GlassNavPage extends StatelessWidget {
  const _GlassNavPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiuiColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: MiuiMagicBackdrop()),
          // 模拟滚动中的剧情文字，让玻璃有内容可折射
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text('对角巷的午后', style: MiuiType.title2),
                  const SizedBox(height: 8),
                  Text(
                    '魔杖店的橱窗里，奥利凡德正对着一位少年比划着什么。\n'
                    '一阵穿堂风掠过，拂动了丽痕书店门口的旧羊皮纸。\n'
                    '古灵阁的妖精们依然在柜台后忙碌地清点着加隆。\n'
                    '你握紧了口袋里的纳特，走进了这条喧嚣的巷子……\n'
                    '赫敏的信鸽在钟楼上盘旋，等待你的回信。\n'
                    '午后的阳光斜斜地洒在石板路上，拉出长长的影子。',
                    style: MiuiType.narrative,
                  ),
                ],
              ),
            ),
          ),
          // 液态玻璃悬浮导航栏
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LiquidGlassNavBar(
              currentIndex: 1,
              onTap: _noop1,
              items: [
                LiquidNavItem(icon: Icons.auto_stories_outlined, activeIcon: Icons.auto_stories, label: '剧情'),
                LiquidNavItem(icon: Icons.smartphone_outlined, activeIcon: Icons.smartphone, label: '手机'),
                LiquidNavItem(icon: Icons.public, label: '世界'),
                LiquidNavItem(icon: Icons.tune, label: '设置'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('design system gallery', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(_wrap(const _DesignSystemPage()));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(_DesignSystemPage),
      matchesGoldenFile('goldens/design_system.png'),
    );
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('liquid glass navbar over content', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(_wrap(const _GlassNavPage()));
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(_GlassNavPage),
      matchesGoldenFile('goldens/liquid_glass_nav.png'),
    );
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('intro wizard step 0 (era)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    final app = AppProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: app),
          ChangeNotifierProvider<GameProvider>(
            create: (_) => GameProvider(app),
          ),
        ],
        child: _wrap(const IntroScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(IntroScreen),
      matchesGoldenFile('goldens/intro_wizard.png'),
    );
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('save load screen empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    final app = AppProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: app),
          ChangeNotifierProvider<GameProvider>(
            create: (_) => GameProvider(app),
          ),
        ],
        child: _wrap(const SaveLoadScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(SaveLoadScreen),
      matchesGoldenFile('goldens/save_load_empty.png'),
    );
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('memory screen chronicle', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    final app = AppProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: app),
          ChangeNotifierProvider<GameProvider>(
            create: (_) => GameProvider(app),
          ),
        ],
        child: _wrap(const MemoryScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(MemoryScreen),
      matchesGoldenFile('goldens/memory_chronicle.png'),
    );
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('game bottom dock liquid glass', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 460));
    final app = AppProvider();
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: app),
          ChangeNotifierProvider<GameProvider>(
            create: (_) => GameProvider(app),
          ),
        ],
        child: _wrap(
          Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(child: MiuiMagicBackdrop(density: 0.85)),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 90),
                  child: GameBottomInput(
                    inputController: ctrl,
                    onHandleFreeAction: () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(GameBottomInput),
      matchesGoldenFile('goldens/game_dock_glass.png'),
    );
    await tester.binding.setSurfaceSize(null);
  });
}

void _noop() {}
void _noop1(dynamic _) {}
