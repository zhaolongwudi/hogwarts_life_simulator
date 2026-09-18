import 'package:flutter/material.dart';
import '../models/npc.dart';
import '../data/house_data.dart';
import '../theme/miuix_tokens.dart';

/// 全局语义色 token。
///
/// 已收编：本类语义已由 `MiuiColors`（`lib/theme/miuix_tokens.dart`）统一接管，
/// 本类保留为**兼容别名**，供存量页面渐进过渡；**新代码一律改用 `MiuiColors`**。
/// 逐成员映射见 `docs/UI重构规范与台账.md` 的「色板收编映射表」。
///
/// 历史遗留：UI 层散落着 100+ 个硬编码色值，同一语义（危险红/成功绿/强调金）
/// 有 6~9 种写法，深色主题里还混着浅色主题残留的卡片底色。新代码一律用
/// `MiuiColors` 的 token；存量页面按「色板收编映射表」随 UI 打磨逐步替换。
class AppColors {
  // ===== 全局语义色（转发到 MiuiColors 单一来源） =====
  // 原字面量已按 `docs/UI重构规范与台账.md`「色板收编映射表」收归 MiuiColors：
  // 同值成员直接等价；近似成员收敛到 Miui 统一值（危险红→error、提亮金→primaryVariant、
  // 文字灰阶→onSurface 系、背景→background、描边→outline），保证全局一致。
  // 本类保留成员名，仅供存量页面过渡，新代码一律用 MiuiColors。
  /// 主金
  static const gold = MiuiColors.primary;
  /// 提亮金
  static const goldBright = MiuiColors.primaryVariant;
  /// 深金
  static const goldDeep = MiuiColors.primaryContainer;

  // ===== 状态色 =====
  static const danger = MiuiColors.error;
  static const success = MiuiColors.success;
  static const warning = MiuiColors.warning;
  static const info = MiuiColors.info;

  // ===== 文字三灰阶 =====
  static const textPrimary = MiuiColors.onSurface;
  static const textSecondary = MiuiColors.onSurfaceSecondary;
  static const textMuted = MiuiColors.onSurfaceVariantSummary;

  // ===== 背景体系 =====
  static const bg = MiuiColors.background;
  static const surface = MiuiColors.surface;
  static const card = MiuiColors.surfaceContainer;
  static const border = MiuiColors.outline;
}

class UiHelpers {
  /// 学院色（唯一来源）：统一收敛到 `MiuiColors` 的学院 token（亮色版，暗底可读）。
  ///
  /// 历史遗留：本方法曾用深品牌色（gryffindor#740001 / slytherin#1A472A / ravenclaw#0E1A40），
  /// 且 `game_world_tab` 自带另一套金/琥珀 switch（大小写敏感匹配），三方色值各不相同。
  /// 现已全部收口到 `MiuiColors` 单一来源，并顺带修正大小写匹配不到的问题。
  /// 未知/教职工统一用 `houseNeutral`。
  static Color getHouseColor(String house) {
    switch (house.toLowerCase()) {
      case 'gryffindor':
        return MiuiColors.gryffindor;
      case 'slytherin':
        return MiuiColors.slytherin;
      case 'ravenclaw':
        return MiuiColors.ravenclaw;
      case 'hufflepuff':
        return MiuiColors.hufflepuff;
      default:
        return MiuiColors.houseNeutral;
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

/// 统一页面跳转（D2 收口）。
///
/// 全项目 `Navigator.push(context, MaterialPageRoute(builder: ...))` 一律改用
/// 本函数：新建页面时的 Route 构造差异（全屏/动效/泛型）集中在一处维护，
/// 调用方只表达「去哪」不表达「怎么去」。
Future<T?> pushRoute<T extends Object?>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(builder: (_) => page),
  );
}

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
