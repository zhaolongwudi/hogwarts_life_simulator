import 'package:flutter/material.dart';

/// NPC 头像 Widget
/// 优先加载 assets/images/avatars/{npcId}.jpg 等本地图片
/// 加载失败时回退为圆形+首字（原有设计）
class NpcAvatar extends StatelessWidget {
  final String npcId;
  final String npcName;
  final Color houseColor;
  final double size;

  /// 可选：自定义图片路径（覆盖默认的 assets/images/avatars/{npcId}.* 推断逻辑）
  final String? imagePath;

  const NpcAvatar({
    super.key,
    required this.npcId,
    required this.npcName,
    required this.houseColor,
    this.size = 44,
    this.imagePath,
  });

  /// 已下载的角色头像映射表（NPC ID → 资源路径）
  /// 新增角色图片后在此追加即可
  static const Map<String, String> _avatarAssets = {
    'harry': 'assets/images/avatars/harry.jpg',
    'hermione': 'assets/images/avatars/hermione.jpeg',
    'ron': 'assets/images/avatars/ron.jpg',
    'neville': 'assets/images/avatars/neville.jpg',
    'ginny': 'assets/images/avatars/ginny.jpg',
    'draco': 'assets/images/avatars/draco.jpg',
    'crabbe': 'assets/images/avatars/crabbe.jpg',
    'goyle': 'assets/images/avatars/goyle.jpg',
    'cho': 'assets/images/avatars/cho.jpg',
    'luna': 'assets/images/avatars/luna.jpg',
    'cedric': 'assets/images/avatars/cedric.png',
    'sirius': 'assets/images/avatars/sirius.JPG',
    'remus': 'assets/images/avatars/remus.jpg',
    'mcgonagall': 'assets/images/avatars/mcgonagall.jpg',
    'snape': 'assets/images/avatars/snape.jpg',
    'hagrid': 'assets/images/avatars/hagrid.png',
    'filch': 'assets/images/avatars/filch.jpg',
  };

  String? get _resolvedPath {
    if (imagePath != null) return imagePath;
    return _avatarAssets[npcId];
  }

  @override
  Widget build(BuildContext context) {
    final path = _resolvedPath;
    final initial = npcName.isNotEmpty ? npcName[0] : '?';

    if (path != null) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // 图片加载失败 → 回退到圆形首字
              return _buildCircleAvatar(initial);
            },
          ),
        ),
      );
    }

    // 没有图片资源 → 直接显示圆形首字
    return _buildCircleAvatar(initial);
  }

  Widget _buildCircleAvatar(String initial) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: houseColor.withValues(alpha: 0.12),
        border: Border.all(
          color: houseColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
          color: houseColor,
        ),
      ),
    );
  }
}
