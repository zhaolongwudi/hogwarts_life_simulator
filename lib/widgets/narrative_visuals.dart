import 'package:flutter/material.dart';
import '../data/scene_illustration_data.dart';
import '../utils/story_text_renderer.dart';
import 'npc_avatar.dart';

/// 场景插图横幅：根据剧情地点渲染氛围渐变横幅。
/// 无外部图片依赖，渐变+图标+地点标题营造沉浸感。
class SceneIllustrationBanner extends StatelessWidget {
  final String? location;
  final String? timestamp;

  const SceneIllustrationBanner({
    super.key,
    required this.location,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final scene = resolveSceneIllustration(location);
    final loc = location?.trim() ?? '';
    final displayTitle = loc.isNotEmpty ? loc : scene.title;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: scene.gradient,
          ),
        ),
        child: Stack(
          children: [
            // 背景大图标（装饰）
            Positioned(
              right: -12,
              bottom: -18,
              child: Opacity(
                opacity: 0.16,
                child: Icon(scene.icon, size: 110, color: Colors.white),
              ),
            ),
            // emoji 点缀
            if (scene.emoji != null)
              Positioned(
                right: 18,
                top: 12,
                child: Text(
                  scene.emoji!,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            // 前景标题
            Positioned(
              left: 16,
              bottom: 12,
              right: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(scene.icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          displayTitle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(blurRadius: 6, color: Colors.black54),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (timestamp != null && timestamp!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      timestamp!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 对话气泡：渲染单个「说话人 + 台词」气泡。
/// 头像在左，气泡带说话人名字与神态标签。
class DialogueBubble extends StatelessWidget {
  final String speaker;
  final String mood;
  final String text;
  final String? npcId;
  final Color houseColor;

  const DialogueBubble({
    super.key,
    required this.speaker,
    required this.text,
    this.mood = '',
    this.npcId,
    this.houseColor = const Color(0xFFD3A625),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 头像
        NpcAvatar(
          npcId: npcId ?? '',
          npcName: speaker,
          houseColor: houseColor,
          size: 36,
        ),
        const SizedBox(width: 8),
        // 气泡
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 说话人 + 神态
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 3),
                child: Row(
                  children: [
                    Text(
                      speaker,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: houseColor,
                      ),
                    ),
                    if (mood.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        mood,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8B949E),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF232A36),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  border: Border.all(
                    color: houseColor.withValues(alpha: 0.25),
                  ),
                ),
                child: RichText(
                  text: TextSpan(
                    children: StoryTextRenderer.parse(text),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
