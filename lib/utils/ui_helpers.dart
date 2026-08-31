import 'package:flutter/material.dart';
import '../models/npc.dart';
import '../data/house_data.dart';

/// 全局语义色 token：全项目统一从这里取，杜绝裸色值漂移。
///
/// 历史遗留：UI 层散落着 100+ 个硬编码色值，同一语义（危险红/成功绿/强调金）
/// 有 6~9 种写法，深色主题里还混着浅色主题残留的卡片底色。新代码一律用这里
/// 的 token；存量页面按审计清单逐步收敛。
class AppColors {
  // ===== 主题金 =====
  /// 主金：按钮/强调/选中态
  static const gold = Color(0xFFD3A625);
  /// 提亮金：深底上的文字/图标
  static const goldBright = Color(0xFFDDB54A);
  /// 深金：描边/次级强调
  static const goldDeep = Color(0xFFB8860B);

  // ===== 状态色 =====
  /// 危险/负面/伤害
  static const danger = Color(0xFFEF4444);
  /// 成功/正面/升温
  static const success = Color(0xFF10B981);
  /// 警告/中性偏负
  static const warning = Color(0xFFF59E0B);
  /// 信息/对话蓝
  static const info = Color(0xFF79C0FF);

  // ===== 文字三灰阶 =====
  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textMuted = Color(0xFF6B7280);

  // ===== 背景体系（GitHub Dark 风格） =====
  static const bg = Color(0xFF0D1117);
  static const surface = Color(0xFF161B22);
  static const card = Color(0xFF21262D);
  static const border = Color(0xFF30363D);
}

class UiHelpers {
  static Color getHouseColor(String house) {
    final key = house.toLowerCase();
    switch (key) {
      case 'gryffindor':
        return const Color(0xFF740001);
      case 'slytherin':
        return const Color(0xFF1A472A);
      case 'ravenclaw':
        return const Color(0xFF0E1A40);
      case 'hufflepuff':
        return const Color(0xFFECB939);
      default:
        return const Color(0xFF8B949E);
    }
  }

  /// 学院色（亮色版）：深色主题下文字/头像边框可读性更好的学院色。
  /// 深色学院（斯莱特林绿/拉文克劳蓝）提亮，其余保持品牌色。
  static Color getHouseColorBright(String house) {
    switch (house.toLowerCase()) {
      case 'gryffindor':
        return const Color(0xFFD3A625); // 金红 → 金色（深红在暗底太暗）
      case 'slytherin':
        return const Color(0xFF4CAF7D); // 深绿 → 亮绿
      case 'ravenclaw':
        return const Color(0xFF5B8DEF); // 深蓝 → 亮蓝
      case 'hufflepuff':
        return const Color(0xFFECB939);
      default:
        return const Color(0xFFD3A625);
    }
  }

  /// 学院中文名。映射本身在 lib/data/house_data.dart（数据层），
  /// 这里只是给 UI 层的一个命名顺手的转发，不再自己维护一份。
  static String getHouseLabel(String house) => houseDisplayName(house);

  static String getAffectionLabel(int affection) {
    if (affection >= 95) return '灵魂伴侣 💞';
    if (affection >= 85) return '深爱 ❤️';
    if (affection >= 70) return '亲密 💕';
    if (affection >= 50) return '信任 😊';
    if (affection >= 30) return '友好 🙂';
    if (affection >= 10) return '好感 😃';
    if (affection >= -9) return '中立 😐';
    if (affection >= -20) return '冷漠 😶';
    if (affection >= -50) return '反感 😒';
    if (affection >= -80) return '宿怨 😠';
    return '死敌 💀';
  }

  /// 好感度 → 颜色（8 档，与地图/通讯录/关系页共用同一套映射）。
  ///
  /// 历史遗留：地图页自己写了一份 8 档自定义色，通讯录用这里的 5 档——
  /// 同一好感值在两个页面颜色完全不同。统一收敛为 8 档 token 色：
  /// 敌对红 → 冷淡橙 → 未明灰 → 初识蓝 → 朋友绿 → 好友紫 → 亲密粉 → 灵魂品红。
  static Color getAffectionColor(int affection) {
    if (affection <= -30) return AppColors.danger;
    if (affection <= -10) return AppColors.warning;
    if (affection <= 10) return AppColors.textMuted;
    if (affection <= 30) return const Color(0xFF3B82F6);
    if (affection <= 50) return AppColors.success;
    if (affection <= 70) return const Color(0xFF8B5CF6);
    if (affection <= 90) return const Color(0xFFEC4899);
    return const Color(0xFFD946EF);
  }

  static Color getScoreColor(int score) {
    if (score >= 50) return AppColors.danger;
    if (score >= 35) return const Color(0xFFEC4899);
    return AppColors.warning;
  }

  // 典型 NPC 名字 → 工作/身份标签（剧情开始阶段一眼识别角色）
  static const Map<String, String> _canonicalRole = {
    '阿不思·邓布利多': '霍格沃茨校长',
    '米勒娃·麦格': '变形课教授·副校长',
    '西弗勒斯·斯内普': '魔药课教授',
    '鲁伯·海格': '钥匙与场地看守',
    '菲利乌斯·弗立维': '魔咒课教授',
    '波莫娜·斯普劳特': '草药课教授',
    '罗兰达·霍琦': '飞行课教授·魁地奇裁判',
    '西比尔·特里劳妮': '占卜课教授',
    '阿格斯·费尔奇': '霍格沃茨管理员',
    '伊尔玛·平斯': '图书馆管理员',
    '波比·庞弗雷': '校医院护士长',
    '宾斯教授': '魔法史教授',
    '霍拉斯·斯拉格霍恩': '魔药课教授·鼻涕虫俱乐部',
    '吉德罗·洛哈特': '黑魔法防御术教授',
    '多洛雷斯·乌姆里奇': '魔法部高级副部长',
    '莱姆斯·卢平': '黑魔法防御术教授·掠夺者',
    '尼法朵拉·唐克斯': '凤凰社·傲罗',
    '天狼星·布莱克': '凤凰社·教父',
    '詹姆·波特': '掠夺者·波特父亲',
    '莉莉·波特': '波特母亲',
    '亚瑟·韦斯莱': '魔法部·麻瓜保护司',
    '莫丽·韦斯莱': '韦斯莱家母亲',
    '珀西·韦斯莱': '级长·优等生',
    '弗雷德·韦斯莱': '韦斯莱孪生·搞怪王',
    '乔治·韦斯莱': '韦斯莱孪生·搞怪王',
    '奥利弗·伍德': '格兰芬多魁地奇队长',
    '李·乔丹': '魁地奇解说·格兰芬多',
    '哈利·波特': '大难不死的男孩',
    '赫敏·格兰杰': '万事通·年级第一',
    '罗恩·韦斯莱': '韦斯莱家六子·红发',
    '纳威·隆巴顿': '圆脸·胆小健忘',
    '金妮·韦斯莱': '韦斯莱家小妹',
    '卢娜·洛夫古德': '疯姑娘·拉文克劳',
    '塞德里克·迪戈里': '赫奇帕奇级长',
    '德拉科·马尔福': '斯莱特林·纯血家族',
    '文森特·克拉布': '马尔福跟班',
    '格雷戈里·高尔': '马尔福跟班',
    '潘西·帕金森': '斯莱特林·马尔福女友',
    '卢修斯·马尔福': '马尔福家主·校董',
    '纳西莎·马尔福': '马尔福夫人',
    '贝拉特里克斯·莱斯特兰奇': '黑巫师·食死徒',
    '小矮星彼得': '叛徒·食死徒',
    '弗农·德思礼': '麻瓜姨夫',
    '佩妮·德思礼': '麻瓜姨妈',
    '达力·德思礼': '麻瓜表哥',
  };

  /// 生成角色身份标签（不写外貌，3个标签让人一眼想起角色是谁）
  static List<String> npcRoleTags(NPC npc) {
    final tags = <String>[];
    // 1) 典型角色匹配
    final canonical = _canonicalRole[npc.name];
    if (canonical != null) tags.add(canonical);
    // 2) 年级 / 身份
    final gradeTag = npc.grade == 0 ? '教职工' : '${npc.grade}年级';
    tags.add(gradeTag);
    // 3) 学院（如果有的话）
    if (npc.house.isNotEmpty && npc.house.toLowerCase() != 'staff') {
      tags.add(getHouseLabel(npc.house));
    }
    // 4) 人格特质取前 2 个（不超过3个）
    if (npc.personality.isNotEmpty && tags.length < 3) {
      for (final trait in npc.personality) {
        if (tags.length >= 3) break;
        tags.add(trait);
      }
    }
    // 最多 3 个
    return tags.take(3).toList();
  }
}

/// 分隔线/描边颜色。
///
/// `Theme.of(context).dividerTheme.color` 是**可空**的，而默认构造的
/// ThemeData 并没有配 dividerColor。全项目十几处直接 `!` 强解包——
/// 只要主题一换（或某个测试环境没配），整页直接报错。
/// 描边一律从这里取，主题没配时按明暗给一个兜底色。
Color dividerColorOf(BuildContext context) =>
    Theme.of(context).dividerTheme.color ??
    (Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE));

/// 通用危险操作确认对话框。
///
/// 删除存档/删帖/删日记/清空数据等不可恢复操作统一走这里，
/// 返回 `true` 表示用户确认。确认按钮默认危险红。
Future<bool> confirmDangerDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '确定',
  Color confirmColor = AppColors.danger,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText, style: TextStyle(color: confirmColor)),
        ),
      ],
    ),
  );
  return ok ?? false;
}
