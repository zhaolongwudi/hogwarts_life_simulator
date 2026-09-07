import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/game_provider.dart';
import '../../../theme/miuix_tokens.dart';
import '../../../utils/ui_helpers.dart';

/// 数值变化浮层：监听玩家关键资源在两次构建间的差值，
/// 变化时在对话区顶部飘出一行「生命 -15 · 精力 -10」的提示并渐隐。
class ResourceFloat extends StatefulWidget {
  const ResourceFloat({super.key});

  @override
  State<ResourceFloat> createState() => _ResourceFloatState();
}

class _ResourceFloatState extends State<ResourceFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: MiuiDuration.progressFill,
  );
  Map<String, int> _prev = const {};
  String _text = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _check(GameProvider gp) {
    final p = gp.player;
    if (p == null) return;
    final cur = <String, int>{
      '生命': p.health,
      '魔力': p.magic,
      '精神力': p.spirit,
      '饱食度': p.satiety,
      '精力': p.energy,
      '加隆': p.galleons,
    };
    if (_prev.isEmpty) {
      _prev = cur;
      return;
    }
    final parts = <String>[];
    cur.forEach((k, v) {
      final d = v - (_prev[k] ?? v);
      if (d != 0) parts.add('$k ${d > 0 ? '+' : ''}$d');
    });
    _prev = cur;
    if (parts.isEmpty) return;
    final text = parts.join(' · ');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _text = text);
      _ctrl
        ..stop()
        ..value = 0
        ..forward().then((_) async {
          if (!mounted) return;
          await Future.delayed(MiuiDuration.typewriterGap);
          if (!mounted) return;
          _ctrl.reverse();
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    _check(gp);
    final anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.3),
              end: Offset.zero,
            ).animate(anim),
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: MiuiColors.surfaceContainerHigh.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: MiuiColors.primary.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MiuiColors.onSurfaceVariantSummary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// AI 失败提示条。
///
/// 以前 AI 调用失败只会静默切本地兜底剧情，界面毫无提示，
/// 玩家会以为"这段剧情就是长这样"。这里显式告知 + 提供重试入口。
class AiErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  final VoidCallback? onRetry;

  const AiErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF5C2222),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: AppColors.danger.withValues(alpha: 0.7),
            width: 3.0,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFFFFDCD7)),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '重试',
                style: TextStyle(fontSize: 12, color: MiuiColors.primary),
              ),
            ),
          GestureDetector(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: Color(0xFFFFDCD7)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 剧情页顶部的圆形图标动作（回放/阅读模式）。
class PanelIconAction extends StatelessWidget {
  const PanelIconAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: MiuiColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: MiuiColors.outline.withValues(alpha: 0.8),
              width: MiuiSpace.dividerThickness,
            ),
          ),
          child: Icon(icon, size: 17, color: MiuiColors.onSurfaceSecondary),
        ),
      ),
    );
  }
}

/// 聊天气泡的"尾巴"装饰：指向气泡的小三角。
///
/// 使用 CustomPainter 绘制一个实心三角，颜色与气泡边框一致。
class BubbleTail extends StatelessWidget {
  const BubbleTail({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 8,
      height: 10,
      child: CustomPaint(
        painter: _TrianglePainter(
          color: MiuiColors.info.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height * 0.3)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.6)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}
