import 'package:flutter/material.dart';
import '../settings/settings_body.dart';

/// 游戏过程中的设置 Tab。
///
/// 此前这里维护了一份与独立 SettingsScreen 逐行 86% 相同的 460 行副本，
/// 现在直接复用同一份正文，只保留 Tab 内嵌不需要 AppBar 这一点差异
/// （不传 onAfterNewGame，确认新游戏后留在 Tab 里）。
class GameSettingsInlineTab extends StatelessWidget {
  const GameSettingsInlineTab({super.key});

  @override
  Widget build(BuildContext context) => const SettingsBody();
}
