import 'package:flutter/material.dart';
import '../widgets/miui_magic_backdrop.dart';
import 'settings/settings_body.dart';

/// 独立设置页：给共享的设置正文套一层带返回箭头的 Scaffold。
/// 注意：本文件有行数上限（防"正文塞回调用壳"的回归测试），只许做壳。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: MiuiMagicBackdrop(density: 0.55)),
          SettingsBody(
            onAfterNewGame: () => Navigator.pop(context),
            bottomPadding: 48,
          ),
        ],
      ),
    );
  }
}
