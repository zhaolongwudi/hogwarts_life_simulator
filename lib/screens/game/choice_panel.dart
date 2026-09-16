import 'package:flutter/material.dart';
import '../../models/game_systems.dart';
import '../../mixins/mixin_response_choices.dart';
import '../../theme/miuix_tokens.dart';
import '../../widgets/miuix_components.dart';

/// 剧情选项按钮（参考图 Screenshot_00-09-17 风格）。
///
/// 带 400ms 防抖：选项点击会触发一次 AI 请求，连点两下就会连发两条指令、
/// 既烧 token 又会把剧情推进两次。防抖期间按钮同时置灰给出视觉反馈。
class _ChoiceButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  /// 0 起编号：用于 A/B/C 徽章。
  final int index;

  const _ChoiceButton({
    required this.label,
    required this.onTap,
    required this.index,
  });

  @override
  State<_ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<_ChoiceButton> {
  bool _locked = false;

  Future<void> _handleTap() async {
    if (_locked) return;
    setState(() => _locked = true);
    widget.onTap();
    await Future<void>.delayed(MiuiDuration.fadeSlow);
    if (mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    final badge = String.fromCharCode(65 + widget.index);
    return MiuiPressFeedback(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedOpacity(
        opacity: _locked ? 0.5 : 1,
        duration: MiuiDuration.fadeFast,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: MiuiColors.surfaceContainerHigh.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: MiuiColors.outline.withValues(alpha: 0.5),
              width: MiuiSpace.dividerThickness,
            ),
          ),
          child: Row(
            children: [
              // A/B/C 金徽章（参考图风格：金色渐变底 + 白色字母）
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [MiuiColors.primaryVariant, MiuiColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: MiuiColors.primary.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: MiuiColors.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: MiuiColors.onSurface,
                    height: 1.3,
                  ),
                ),
              ),
              // 右箭头（参考图风格：主题色小箭头）
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: MiuiColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 9,
                  color: MiuiColors.primary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 剧情页底部的「可选行动」面板（参考图 Screenshot_00-09-17 风格）。
class ChoicePanel extends StatelessWidget {
  static const double chromeHeight = 50.0;

  final List<GameChoice> choices;
  final double maxHeight;
  final bool collapsed;
  final bool busy;
  final VoidCallback onToggleCollapse;
  final VoidCallback onShuffle;
  final ValueChanged<int> onPick;

  const ChoicePanel({
    required this.choices,
    required this.maxHeight,
    required this.collapsed,
    required this.busy,
    required this.onToggleCollapse,
    required this.onShuffle,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final listMax = (maxHeight - chromeHeight).clamp(0.0, double.infinity);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.0),
            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 7, 16, collapsed ? 7 : 0),
              child: Row(
                children: [
                  // 灯泡图标 + 标题（参考图风格：💡 可选行动）
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: MiuiColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      size: 13,
                      color: MiuiColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    collapsed ? '可选行动 · ${choices.length} 项' : '可选行动',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: MiuiColors.primary,
                    ),
                  ),
                  const Spacer(),
                  if (!collapsed)
                    Semantics(
                      button: true,
                      label: '换一批行动建议',
                      child: InkWell(
                        onTap: busy ? null : onShuffle,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shuffle,
                                  size: 14,
                                  color: busy
                                      ? MiuiColors.onSurfaceVariantActions
                                      : MiuiColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                '换一批',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: busy
                                      ? MiuiColors.onSurfaceVariantActions
                                      : MiuiColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Semantics(
                    button: true,
                    label: collapsed ? '展开行动选项' : '收起行动选项',
                    child: InkWell(
                      onTap: onToggleCollapse,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              collapsed ? '展开' : '收起',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: MiuiColors.onSurfaceVariantSummary),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              collapsed
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 14,
                              color: MiuiColors.onSurfaceVariantSummary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!collapsed) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: listMax),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: choices.asMap().entries.map((entry) {
                      final index = entry.key;
                      final displayText =
                          GameResponseChoiceMixin.sanitizeChoiceText(
                              entry.value.text);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _ChoiceButton(
                          label: displayText,
                          index: index,
                          onTap: () => onPick(index),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}