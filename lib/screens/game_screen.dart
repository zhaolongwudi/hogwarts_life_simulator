import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/app_provider.dart';
import '../models/game_systems.dart';
import '../theme/miuix_tokens.dart';
import '../widgets/liquid_glass_nav_bar.dart';
import '../widgets/miui_magic_backdrop.dart';
import 'game/game_narrative_tab.dart';
import 'game/game_phone_tab.dart';
import 'game/game_world_tab.dart';
import 'game/game_top_bar.dart';
import 'game/game_bottom_input.dart';
import 'game/game_settings_tab.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _currentTab = 0;
  int _subTab = 0;
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  String? _lastNarrative;
  String? _lastCommandPanel;

  /// 悬浮导航栏占据的底部空间（bottomPadding + 高度 + 与内容的间隙）。
  static const double _navSpace = 26 + MiuiSpace.floatingNavMinHeight + 8;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleFreeAction() {
    final gp = context.read<GameProvider>();
    if (gp.isLoading) return;
    final action = _inputController.text.trim();
    if (action.isEmpty) return;
    gp.processChoice(
          GameChoice(text: action, action: action),
        );
    _inputController.clear();
  }

  void _handleChoice(int index) {
    final gp = context.read<GameProvider>();
    if (gp.isLoading) return; // 防止快速双击导致并发 processChoice
    if (index < gp.choices.length) {
      gp.processChoice(gp.choices[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();

    if (gp.currentNarrative != _lastNarrative ||
        gp.commandResult != _lastCommandPanel) {
      _lastNarrative = gp.currentNarrative;
      _lastCommandPanel = gp.commandResult;
      _scrollToTop();
    }

    if (gp.isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在加载存档...', style: TextStyle(color: MiuiColors.onSurfaceVariantSummary)),
            ],
          ),
        ),
      );
    }

    if (gp.player == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: MiuiColors.onSurfaceVariantSummary),
              const SizedBox(height: 16),
              Text(gp.error ?? '没有找到存档', style: const TextStyle(color: MiuiColors.onSurfaceVariantSummary)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      );
    }

    final immersive = context.watch<AppProvider>().displayMode == DisplayMode.immersive;

    Widget tabContent;
    switch (_currentTab) {
      case 0:
        tabContent = NarrativeTab(onNarrativeTapChoice: _handleChoice, scrollController: _scrollController, subTab: _subTab, onSubTabChanged: (v) => setState(()=>_subTab = v));
        break;
      case 1:
        tabContent = PhoneTab(gp: context.watch<GameProvider>());
        break;
      case 2:
        tabContent = WorldTab(gp: context.watch<GameProvider>());
        break;
      case 3:
        tabContent = const GameSettingsInlineTab();
        break;
      default:
        tabContent = const SizedBox.shrink();
    }

    // 沉浸模式会隐藏顶栏、输入栏和底部导航，此时安卓返回键/侧滑返回
    // 会直接把玩家踢出游戏界面（没有"再按一次退出"的缓冲）。
    // 这里第一次返回先退出沉浸模式，第二次才真正返回。
    return PopScope<Object?>(
      canPop: !immersive,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!immersive) return;
        _exitImmersive();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已退出沉浸模式，再按一次返回'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 背景层：魔法辉光（同时是液态玻璃的折射取景）
              const Positioned.fill(child: MiuiMagicBackdrop(density: 0.85)),
              // 主内容列：顶部状态栏 + 页面内容 + （剧情页）输入栏
              Column(
                children: [
                  if (!immersive) const GameTopBar(),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: immersive || _currentTab == 0 ? 0 : _navSpace,
                      ),
                      child: tabContent,
                    ),
                  ),
                  if (!immersive && _currentTab == 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: _navSpace),
                      child: GameBottomInput(
                        inputController: _inputController,
                        onHandleFreeAction: _handleFreeAction),
                    ),
                ],
              ),

              // 悬浮液态玻璃导航栏：浮于内容之上，抓取正文做折射背景
              if (!immersive)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LiquidGlassNavBar(
                    currentIndex: _currentTab,
                    onTap: (index) {
                      setState(() => _currentTab = index);
                    },
                    items: const [
                      LiquidNavItem(
                        icon: Icons.auto_stories_outlined,
                        activeIcon: Icons.auto_stories,
                        label: '剧情',
                      ),
                      LiquidNavItem(
                        icon: Icons.smartphone_outlined,
                        activeIcon: Icons.smartphone,
                        label: '手机',
                      ),
                      LiquidNavItem(
                        icon: Icons.public,
                        label: '世界',
                      ),
                      LiquidNavItem(
                        icon: Icons.tune,
                        label: '设置',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // 沉浸模式下没有顶栏也没有返回键，给一个可点出的悬浮退出按钮
        floatingActionButton: immersive
            ? FloatingActionButton.small(
                heroTag: 'exit_immersive',
                onPressed: _exitImmersive,
                child: const Icon(Icons.fullscreen_exit),
              )
            : null,
      ),
    );
  }

  /// 退出沉浸模式。
  /// setDisplayMode 在「穿书模式」下会拒绝切回杂志模式，
  /// 这时再退一步到紧凑模式，否则玩家会被永久锁死在沉浸模式里出不来。
  void _exitImmersive() {
    final app = context.read<AppProvider>();
    app.setDisplayMode(DisplayMode.magazine);
    if (app.displayMode == DisplayMode.immersive) {
      app.setDisplayMode(DisplayMode.compact);
    }
  }
}
