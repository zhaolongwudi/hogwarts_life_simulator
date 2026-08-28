import 'package:flutter/material.dart';
import 'settings/settings_body.dart';

/// 独立设置页：只是给共享的设置正文套一层带返回箭头的 Scaffold。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SettingsBody(
        onAfterNewGame: () => Navigator.pop(context),
      ),
    );
  }
}
