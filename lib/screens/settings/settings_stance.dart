import 'package:flutter/material.dart';
import '../../data/political_stance.dart';
import 'settings_preset_pickers.dart';

/// 把 lib/data/political_stance.dart 的纯数据翻译成设置用的 ModeOption。
///
/// 图标映射单独放这里，是为了让 data 层不必 import material。
IconData stanceIcon(String iconKey) {
  switch (iconKey) {
    case 'balance':
      return Icons.balance_outlined;
    case 'shield':
      return Icons.shield_outlined;
    case 'tune':
      return Icons.tune_outlined;
    case 'brightness':
      return Icons.brightness_7_outlined;
    case 'bolt':
      return Icons.bolt_outlined;
    case 'allInclusive':
    default:
      return Icons.all_inclusive_outlined;
  }
}

/// 政治立场选择器所需的选项列表。
List<ModeOption> get stanceModeOptions => [
      for (final s in kPoliticalStances)
        ModeOption(
          s.name,
          label: s.name,
          desc: s.desc,
          icon: stanceIcon(s.iconKey),
          color: s.color,
        ),
    ];
