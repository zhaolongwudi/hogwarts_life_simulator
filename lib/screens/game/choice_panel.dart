import 'package:flutter/material.dart';
import '../../models/game_systems.dart';
import '../../mixins/mixin_response_choices.dart';
import '../../theme/miuix_tokens.dart';
import '../../widgets/miuix_components.dart';

/// 剧情选项按钮。
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
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    final badge = String.fromCharCode(65 + widget.index);
    return MiuiPressFeedback(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedOpacity(
        opacity: _locked ? 0.5 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 8, 9, 8),
          decoration: BoxDecoration(
            color: MiuiColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: MiuiColors.outline.withValues(alpha: 0.7),
              width: MiuiSpace.dividerThickness,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [MiuiColors.primaryVariant, MiuiColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: MiuiColors.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 9),
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
              Icon(
                Icons.arrow_forward_ios,
                size: 10,
                color: MiuiColors.primary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 剧情页底部的「可选行动」面板。
///
/// 这里唯一要紧的是**高度**。两条规则：
///
/// 1. **限高只夹列表，不夹整个面板。**
///    以前是 ConstrainedBox 夹外层 Column、里面塞 Flexible，
///    而 Flexible 在有界约束下会吃掉全部剩余空间——
///    于是 2 个选项和 6 个选项一样顶满 maxHeight，
///    正文白丢一截。现在外层 Column 是 mainAxisSize.min 且没有任何
///    flexible 子项，面板高度 = 标题栏 + min(列表实际高度, listMax)。
///
/// 2. **可以收起。**
///    正文才是这个页面的主角。收起后面板只剩一条标题栏（约 44px），
///    六百字的正文能多出两百多像素，够多看十来行。
///    默认展开——每回合结束都要先点一下才能行动反而更烦。
class ChoicePanel extends StatelessWidget {
  /// 面板的固定开销：标题栏（上边距 10 + 文字 20 + 下间距 8）+ 列表底部 12。
  ///
  /// 拿它从 maxHeight 里减掉，剩下的才是列表能用的高度。
  static const double chromeHeight = 50.0;

  final List<GameChoice> choices;
  final double maxHeight;

  /// 收起时只显示标题栏
  final bool collapsed;

  /// AI 在跑：换一批不可用
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
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
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
                  Text(
                    collapsed ? '可选行动 · ${choices.length} 项' : '可选行动',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: MiuiColors.primary),
                  ),
                  const Spacer(),
                  // 「换一批」走本地词库，不消耗 token。
                  // 之前这套生成器写好了却没有任何入口，玩家被 AI 给的
                  // 三个选项卡住时只能硬选一个。
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
                                      ? Colors.grey
                                      : MiuiColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                '换一批',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: busy
                                      ? Colors.grey
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
                                  fontSize: 12.5, color: MiuiColors.onSurfaceVariantSummary),
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
