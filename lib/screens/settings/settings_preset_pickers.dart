import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';

class ModeOption {
  final String value;
  final String label;
  final String desc;
  final IconData? icon;
  final Color? color;
  const ModeOption(this.value, {required this.label, this.icon, this.color, required this.desc});
}

class EraOption {
  final String label;
  final String value;
  final String desc;
  const EraOption(this.label, this.value, this.desc);
}

class SettingsPresetPickers {
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
        final isSelected = current == m.value;
        final itemColor = m.color ?? (isSelected ? const Color(0xFFD3A625) : const Color(0xFF8B949E));
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: isSelected
                ? (m.color?.withValues(alpha: 0.2) ?? const Color(0xFF740001).withValues(alpha: 0.2))
                : const Color(0xFF21262d),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: isDisabled ? null : () => onSelect?.call(m.value),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? (m.color ?? const Color(0xFFD3A625)) : const Color(0xFF30363d),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    if (m.icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: itemColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(m.icon, size: 20, color: itemColor),
                      ),
                      const SizedBox(width: 12),
                    ] else
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? (m.color ?? const Color(0xFFD3A625)) : const Color(0xFF8B949E),
                        size: 20,
                      ),
                    if (m.icon == null) const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDisabled ? const Color(0xFF484f58) : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.desc,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: isSelected ? const Color(0xFF740001).withValues(alpha: 0.2) : const Color(0xFF21262d),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (onSelect != null) {
                  onSelect(e.value);
                } else {
                  if (e.value == 'dumbledore') {
                    context.read<AppProvider>().setEra(Era.dumbledore);
                  } else if (e.value == 'marauders') {
                    context.read<AppProvider>().setEra(Era.marauders);
                  } else if (e.value == 'first_war') {
                    context.read<AppProvider>().setEra(Era.first_war);
                  } else if (e.value == 'harry_same') {
                    context.read<AppProvider>().setEra(Era.harry_same);
                  } else if (e.value == 'post_war') {
                    context.read<AppProvider>().setEra(Era.post_war);
                  } else {
                    context.read<AppProvider>().setEra(Era.random);
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFD3A625) : const Color(0xFF30363d),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? const Color(0xFFD3A625) : const Color(0xFF8B949E),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFFE6EDF3),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.desc,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
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
      }).toList(),
    );
  }
}
