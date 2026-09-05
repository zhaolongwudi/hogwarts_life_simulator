import 'package:flutter/material.dart';
import '../theme/miuix_tokens.dart';
import '../widgets/miui_magic_backdrop.dart';
import 'settings/settings_body.dart';

/// 独立设置页：给共享的设置正文套一层带返回箭头的 Scaffold。
/// HyperOS 风格：背景透出魔法辉光，AppBar 无底色让位给内容区。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: MiuiColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 魔法辉光背景（与首页/游戏页同一层视觉语言）
          const Positioned.fill(child: MiuiMagicBackdrop(density: 0.55)),
          Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight + 8),
            child: SettingsBody(
              onAfterNewGame: () => Navigator.pop(context),
              bottomPadding: 48,
            ),
          ),
        ],
      ),
    );
  }
}
