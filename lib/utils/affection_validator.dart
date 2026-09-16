import '../models/npc.dart';

class AffectionValidator {
  const AffectionValidator._();
  static const AffectionValidator instance = AffectionValidator._();

  static final RegExp _negRe = RegExp(
    r'(侮辱|羞辱|嘲笑|讥讽|嘲讽|骂|叱责|指责|当众.*丢脸|陷害|背叛|出卖|偷窃|恶意|骗了|欺骗|勒索|霸凌|针对|敌对|决斗|攻击|施咒伤害|下咒|诅咒)',
  );

  static final RegExp _hugePositiveRe = RegExp(
    r'(救了.*命|舍身|挡在.*前面|替.*挡|救命|以身犯险|告白|求婚|说出了真心话|坦白|赠予.*贵重|赠送.*传家|为.*背叛.*|不惜.*帮助)',
  );

  /// 统一好感校验入口。
  /// [npcRegistry] 传当前的 NPC 注册表（用于按 name 反查 NPC 状态）
  /// [npcName] 要校验的 NPC 名称（含别名/昵称均可）
  /// [narrative] 完整叙事，用于匹配正向/负向关键词判断互动属性
  /// [delta] 玩家（AI）声称的好感变化值
  ///
  /// return true = 校验通过，允许写入；false = 逻辑不合理，直接丢弃此条变化（不打回整段剧情）
  bool validate(
    Map<String, NPC> npcRegistry,
    String npcName,
    String narrative,
    int delta,
  ) {
    if (delta == 0) return false;
    if (npcName.isEmpty || npcRegistry.isEmpty) return false;

    // 先定位目标 NPC —— 规则 1/2 需要用它圈定上下文范围
    NPC? target;
    for (final n in npcRegistry.values) {
      if (n.nameMatches(npcName)) {
        target = n;
        break;
      }
    }

    // 判定范围：正文中「提到该 NPC」的句子。
    // 旧实现直接对整段叙事做负面词匹配，于是
    //   「马尔福嘲笑你，但你救了罗恩」
    // 里罗恩的 +3 会因为别人那半句的「嘲笑」被一起丢弃。
    // 冲突密集的 HP 剧情下，这会让正向好感系统性漏计。
    final scoped = _contextFor(narrative, npcName, target);
    final scope = scoped.isEmpty ? narrative : scoped;

    // 规则1：负面互动关键词 → 不允许正向 delta
    if (_negRe.hasMatch(scope)) {
      if (delta > 0) {
        return false;
      }
    }

    // 规则2：|delta| ≥ 8 必须有救命/告白/挡刀 等重大事件支撑
    if (delta.abs() >= 8 && !_hugePositiveRe.hasMatch(scope)) {
      return false;
    }

    // 规则3：大幅正向（≥+4）需匹配 NPC 当前阶段（是否登场、是否敌对）
    if (delta >= 4 && target != null) {
      if (!target.introduced) return false;
      if (target.affection <= -20) return false;
    }

    return true;
  }

  /// 抽出正文中提到该 NPC 的句子（上下文窗口）。
  ///
  /// 抽不到（AI 用代词指代）时返回空串，调用方会退回全文判定。
  static String _contextFor(String narrative, String npcName, NPC? target) {
    final names = <String>{npcName};
    if (target != null) {
      names.addAll(target.allNames);
    }
    // 兜底：中文名取后两字（"德拉科·马尔福" → "尔福"）这类截断意义不大，
    // 这里只补「3 字及以上名字去掉姓氏前缀」的常见称呼（"哈利·波特" → "哈利"）
    if (npcName.contains('·')) {
      final first = npcName.split('·').first;
      if (first.length >= 2) names.add(first);
    }

    final sentences = narrative.split(RegExp(r'(?<=[。！？!?])|\n'));
    final hits = sentences
        .where((s) => names.any((n) => n.length >= 2 && s.contains(n)))
        .toList();
    return hits.join('\n');
  }
}
