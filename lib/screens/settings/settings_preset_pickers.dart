import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../theme/miuix_tokens.dart';

class ModeOption {
  final String value;
  final String label;
  final String desc;
  final IconData? icon;
  final Color? color;
  const ModeOption(this.value, {required this.label, required this.desc, this.icon, this.color});
}

class EraOption {
  final String label;
  final String value;
  final String desc;
  const EraOption(this.label, this.value, this.desc);
}

/// 「显示模式」与「穿越时代」两个选择器的共用卡片渲染。
///
/// 两选择器的卡片结构（Material → InkWell → Container → Row[前导 + 标题/说明]）
/// 与选中态配色完全一致，历史上一份 copies 成两份、各自长了不同的边角
/// （标题色、图标强调差异）。此处抽成单一实现：
/// - icon 非空 → 前导为「强调图标块」；否则为「单选圆点」；
/// - accent 为该项品牌强调色（可空，空则回落主题金）。
///
/// 注意：选中底仍用历史遗留的 `0xFF740001 @ 20%` 半透明红（见 [_selectedBackdrop]），
/// 这是既有外观约定，不在本次重构中改变。
class SettingsPresetPickers {
  /// 选中卡片底色。历史遗留硬编码 `0xFF740001` 的 20% 透明（== 0x33 alpha）。
  /// 仅当选项未携带品牌强调色时使用；带强调色时用该色的淡色底。
  static const Color _selectedBackdrop = Color(0x33740001);

  /// 单个选择项的卡片。
  static Widget _optionCard({
    required bool isSelected,
    required bool isDisabled,
    required IconData? icon,
    required Color? accent,
    required String title,
    required String desc,
    required VoidCallback? onTap,
  }) {
    // 前导强调：图标模式下为该项品牌色（空→选中用主题金、未选中用灰）；单选模式下用 hl.
    final fg = accent ?? MiuiColors.primary;
    final iconItemColor =
        accent ?? (isSelected ? MiuiColors.primary : MiuiColors.onSurfaceVariantSummary);
    final backdrop = accent != null ? accent.withValues(alpha: 0.2) : _selectedBackdrop;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? backdrop : MiuiColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isDisabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? fg : MiuiColors.outline,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconItemColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: iconItemColor),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? fg : MiuiColors.onSurfaceVariantSummary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDisabled ? MiuiColors.disabledOnSurface : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 12,
                          color: MiuiColors.onSurfaceVariantSummary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget buildModePicker(
    String current, {
    List<ModeOption>? modes,
    Set<String>? disabled,
    ValueChanged<String>? onSelect,
  }) {
    final items = modes ?? const [
      ModeOption('magazine', label: '魔法手账', desc: '默认推荐，显示日期/地点/状态'),
      ModeOption('compact', label: '简洁', desc: '信息密度更高'),
      ModeOption('immersive', label: '沉浸', desc: '纯小说叙事，无UI标签'),
    ];
    return Column(
      children: items.map((m) {
        final isDisabled = disabled?.contains(m.value) ?? false;
        return _optionCard(
          isSelected: current == m.value,
          isDisabled: isDisabled,
          icon: m.icon,
          accent: m.color,
          title: m.label,
          desc: m.desc,
          onTap: isDisabled ? null : () => onSelect?.call(m.value),
        );
      }).toList(),
    );
  }

  static Widget buildEraPicker(
    BuildContext context,
    String current, {
    ValueChanged<String>? onSelect,
  }) {
    final eras = const [
      EraOption('邓布利多时代', 'dumbledore', '1892-1899 · 少年邓布利多与格林德沃'),
      EraOption('掠夺者时代', 'marauders', '詹姆、小天狼星、卢平、斯内普的学生时代'),
      EraOption('第一次巫师战争', 'first_war', '社会氛围紧张'),
      EraOption('哈利同期', 'harry_same', '与哈利同一年入学（默认）'),
      EraOption('战后时代', 'post_war', '伏地魔战争结束后'),
      EraOption('随机时代', 'random', '系统随机选择'),
    ];
    return Column(
      children: eras.map((e) {
        final isSelected = current == e.value;
        return _optionCard(
          isSelected: isSelected,
          isDisabled: false,
          icon: null,
          accent: null,
          title: e.label,
          desc: e.desc,
          onTap: () {
            if (onSelect != null) {
              onSelect(e.value);
            } else {
              _applyEra(context, e.value);
            }
          },
        );
      }).toList(),
    );
  }

  /// 无 onSelect 时直接写时代设置（旧行为，AppProvider.setEra 按枚举赋值）。
  static void _applyEra(BuildContext context, String value) {
    final app = context.read<AppProvider>();
    switch (value) {
      case 'dumbledore':
        app.setEra(Era.dumbledore);
      case 'marauders':
        app.setEra(Era.marauders);
      case 'first_war':
        app.setEra(Era.first_war);
      case 'harry_same':
        app.setEra(Era.harry_same);
      case 'post_war':
        app.setEra(Era.post_war);
      default:
        app.setEra(Era.random);
    }
  }
}