import 'package:flutter/material.dart';
import '../../models/game_systems.dart';
import '../../mixins/mixin_response_choices.dart';

/// 剧情选项按钮。
///
/// 带 400ms 防抖：选项点击会触发一次 AI 请求，连点两下就会连发两条指令、
/// 既烧 token 又会把剧情推进两次。防抖期间按钮同时置灰给出视觉反馈。
class _ChoiceButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ChoiceButton({required this.label, required this.onTap});

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
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedOpacity(
        opacity: _locked ? 0.5 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2D333B),
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(
                color: const Color(0xFFD3A625).withValues(alpha: 0.5),
                width: 2.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFE6EDF3),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: const Color(0xFFD3A625).withValues(alpha: 0.6),
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
              padding: EdgeInsets.fromLTRB(16, 10, 16, collapsed ? 10 : 0),
              child: Row(
                children: [
                  Text(
                    collapsed ? '可选行动 · ${choices.length} 项' : '可选行动',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD3A625)),
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
                                  size: 15,
                                  color: busy
                                      ? Colors.grey
                                      : const Color(0xFFD3A625)),
                              const SizedBox(width: 4),
                              Text(
                                '换一批',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: busy
                                      ? Colors.grey
                                      : const Color(0xFFD3A625),
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
                                  fontSize: 13, color: Color(0xFF8B949E)),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              collapsed
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 16,
                              color: const Color(0xFF8B949E),
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
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: listMax),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: choices.asMap().entries.map((entry) {
                      final index = entry.key;
                      final displayText =
                          GameResponseChoiceMixin.sanitizeChoiceText(
                              entry.value.text);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ChoiceButton(
                          label:
                              '${String.fromCharCode(65 + index)}. $displayText',
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
