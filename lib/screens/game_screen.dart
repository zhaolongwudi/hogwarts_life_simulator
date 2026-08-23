import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/app_provider.dart';
import '../models/game_systems.dart';
import 'game/game_narrative_tab.dart';
import 'game/game_phone_tab.dart';
import 'game/game_world_tab.dart';
import 'game/game_top_bar.dart';
import 'game/game_bottom_input.dart';
import 'game/game_character_tab.dart';
import 'game/game_settings_tab.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _currentTab = 0;
  int _subTab = 0;
  int _tokenUsage = 0;
  final _inputController = TextEditingController();
  final _menuController = TextEditingController();
  final _scrollController = ScrollController();
  String? _lastNarrative;
  String? _lastCommandPanel;

  @override
  void dispose() {
    _inputController.dispose();
    _menuController.dispose();
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
              Text('正在加载存档...', style: TextStyle(color: Color(0xFF8B949E))),
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
              const Icon(Icons.error_outline, size: 64, color: Color(0xFF8B949E)),
              const SizedBox(height: 16),
              Text(gp.error ?? '没有找到存档', style: const TextStyle(color: Color(0xFF8B949E))),
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (!immersive) const GameTopBar(),
            Expanded(child: tabContent),
            _currentTab == 0 ? GameBottomInput(inputController: _inputController, menuController: _menuController, onHandleFreeAction: _handleFreeAction) : const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentTab,
      onTap: (index) {
        setState(() => _currentTab = index);
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: '剧情'),
        BottomNavigationBarItem(icon: Icon(Icons.phone_android), label: '手机'),
        BottomNavigationBarItem(icon: Icon(Icons.public), label: '世界'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
      ],
    );
  }
}
