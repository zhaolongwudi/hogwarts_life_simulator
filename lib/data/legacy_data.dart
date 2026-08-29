/// 家族传承：把上一周目交棒给下一代
///
/// ## 为什么要做这个
///
/// 报告 §4 的原话：「结婚生子后，下一代带着父母的姓氏、血统、声望开局。
/// 你现在是马尔福家的孩子，还是韦斯莱家的孩子，开局体验完全不同。」
///
/// 已有的婚育链路（求婚 → 订婚 → 结婚 → 怀孕 → 生育）会把孩子写进
/// `player.children`，然后——孩子的全部内容就是一行名字加几个特质，
/// 永远停在列表里，不会再长大，也不会有任何影响。
///
/// ## 传承什么，不传承什么
///
/// 这一栏是整个系统的设计核心。**全传就不叫传承了，那叫开挂。**
///
/// 传：
///   · 姓氏 —— 孩子的姓来自玩家，这是最直观的东西
///   · 血统 —— 父母双方混合，隔代会返祖
///   · 一小部分声望 —— 家族的名声确实跟着你，但只有四分之一
///   · 人脉 —— 父母处得好的人，孩子开局就认识，但只是"认识"
///   · **宿敌 —— 你这一生结下的梁子，会跟着你的姓传下去**
///   · 一笔遗产 —— 够你开局体面，不够你躺平
///
/// 不传：
///   · 学业属性 —— 那是你自己要学的东西
///   · 成就与 CG —— 那是上一代人自己的事
///   · 世界线变动率 —— 新的一代是新的人，世界从原典重新开始
///   · 教职 —— 你爸是教授不代表你也是
///   · 恋爱关系 —— 这条不用解释
///
/// 宿敌那条是刻意留下的。它让"你这一生怎么对待别人"这件事
/// 第一次有了跨周目的重量：你结下的梁子，你的孩子一进校门就得接着。

/// 血统权重（纯血 2、混血 1、麻瓜出身 0），用来算混合结果
const Map<String, int> kBloodRank = {
  'pureblood': 2,
  'halfblood': 1,
  'muggleborn': 0,
  'special': 1,
};

const List<String> kBloodTypes = ['pureblood', 'halfblood', 'muggleborn'];

/// 按血统权重（rank）索引的血统表：**下标就是 kBloodRank 的值**。
///
/// 别拿 kBloodTypes 去当下标用——那张表是按"血统高低"排的（纯血在前），
/// 用它索引会得到完全相反的结果：纯血 + 麻瓜出身的父母，
/// 那 20% 本该随低的一方的概率会跑出一个纯血孩子来。
const List<String> kBloodByRank = ['muggleborn', 'halfblood', 'pureblood'];

/// 子女继承父母的血统。
///
/// [roll] 是 0~99 的随机数，由调用方传入而不是内部随机——
/// 这样这个函数才是可测的，而不是每次跑出不同结果。
String mixBloodType(String parentA, String parentB, int roll) {
  final ra = kBloodRank[parentA] ?? 1;
  final rb = kBloodRank[parentB] ?? 1;
  final hi = ra > rb ? ra : rb;
  final lo = ra < rb ? ra : rb;

  // 双方都是纯血：血脉稳定，但小概率出混血（祖上总有一两个秘密）
  if (lo == 2) return roll < 85 ? 'pureblood' : 'halfblood';
  // 一方纯血：多数是混血，少数随低的那方
  if (hi == 2) return roll < 80 ? 'halfblood' : kBloodByRank[lo];
  // 双方混血：多数仍是混血，可能降一代、也可能隔代返祖
  if (lo == 1 && hi == 1) {
    if (roll < 70) return 'halfblood';
    if (roll < 90) return 'muggleborn';
    return 'pureblood';
  }
  // 有一方麻瓜出身
  if (hi == 1) return roll < 75 ? 'halfblood' : 'muggleborn';
  // 双方麻瓜出身：极小的概率出个哑炮之外的意外
  return roll < 92 ? 'muggleborn' : 'halfblood';
}

/// 声望继承比例。只传四分之一——家族的名声确实跟着你，
/// 但不该让你一进校就成了名人。
const double kReputationInheritRate = 0.25;

/// 黑魔法声望的继承比例。比正向声望低，但**不为零**：
/// 恶名也会跟着姓氏传下来，这是传承该有的分量。
const double kDarkReputationInheritRate = 0.20;

/// 人脉继承：只有好感达到这个数的人才算"世交"
const int kAllyAffectionMin = 50;

/// 人脉继承比例与上限。
/// 上限是为了不让玩家开局就带着一群死党——那不叫传承，那叫抄近路。
const double kAllyInheritRate = 0.40;
const int kAllyAffectionCap = 35;

/// 宿敌继承比例：梁子传下来，但传的是七成
const double kRivalInheritRate = 0.70;

/// 遗产：总资产的比例与上限
const double kInheritanceRate = 0.25;
const int kInheritanceCap = 2000;

/// 下一代开局的年龄（霍格沃茨入学年龄）
const int kHeirEntranceAge = 11;

/// 一份要交棒给下一代的东西
class LegacyCarryover {
  final String heirName;
  final String heirGender;
  final String surname;
  final String bloodType;
  final String familyBackground;

  /// 继承来的六维声望
  final Map<String, int> reputation;

  /// 世交：NPC 名 → 开局好感
  final Map<String, int> allies;

  /// 世仇：NPC 名。孩子一进校门这些人就已经记恨他了。
  final List<String> rivals;

  final int inheritance;

  /// 上一代的姓名（写进家族背景，也用于 T0 事实）
  final String parentName;

  /// 新周目的开局年份。孩子 11 岁那年入学。
  final int startYear;

  /// 一句话总结上一代是个什么样的人（写进家族背景）
  final String parentSummary;

  const LegacyCarryover({
    required this.heirName,
    required this.heirGender,
    required this.surname,
    required this.bloodType,
    required this.familyBackground,
    required this.reputation,
    required this.allies,
    required this.rivals,
    required this.inheritance,
    required this.parentName,
    required this.startYear,
    required this.parentSummary,
  });

  bool get hasRivals => rivals.isNotEmpty;
  bool get hasAllies => allies.isNotEmpty;
}

/// 上一代的六种声望 → 继承后的值
Map<String, int> inheritedReputation({
  required int academic,
  required int social,
  required int combat,
  required int moral,
  required int leadership,
  required int dark,
}) {
  int cut(int v, double rate) => (v * rate).floor();
  return {
    'academic': cut(academic, kReputationInheritRate),
    'social': cut(social, kReputationInheritRate),
    'combat': cut(combat, kReputationInheritRate),
    'moral': cut(moral, kReputationInheritRate),
    'leadership': cut(leadership, kReputationInheritRate),
    'dark': cut(dark, kDarkReputationInheritRate),
  };
}

/// 哪些 NPC 够格成为"世交"，以及继承后的好感
Map<String, int> inheritedAllies(Map<String, int> npcAffections) {
  final out = <String, int>{};
  for (final e in npcAffections.entries) {
    if (e.value < kAllyAffectionMin) continue;
    final v = (e.value * kAllyInheritRate).round();
    out[e.key] = v > kAllyAffectionCap ? kAllyAffectionCap : v;
  }
  return out;
}

/// 遗产：总资产的一定比例，封顶
int inheritedWealth(int totalWealth) {
  final v = (totalWealth * kInheritanceRate).round();
  return v > kInheritanceCap ? kInheritanceCap : v;
}

/// 用一句话概括上一代。
///
/// 这句话会写进下一代的家族背景，所以它会**跟着玩家整整七年**——
/// 不能写成干巴巴的"父亲是名人"，得让读到的人立刻知道那是个什么样的人。
String summarizeParent({
  required String parentName,
  required int academic,
  required int combat,
  required int moral,
  required int dark,
  required int leadership,
  required bool wasFaculty,
  required int worldLinePercent,
}) {
  final tags = <String>[];
  if (academic >= 70) tags.add('当年在课堂上出过风头');
  if (combat >= 70) tags.add('打过几场让人记住的架');
  if (leadership >= 70) tags.add('当过一阵子的头儿');
  if (dark >= 50) tags.add('走过一段没人愿意细说的弯路');
  if (moral >= 70) tags.add('在别人都躲开的时候站出来过');
  if (wasFaculty) tags.add('后来回了霍格沃茨教书');
  if (worldLinePercent >= 40) tags.add('据说还改过一些不该改的事');

  if (tags.isEmpty) {
    return '$parentName 平平静静地过完了一生，'
        '没什么人记得他，也没什么人记恨他——这本身也是一种本事。';
  }
  return '$parentName ${tags.join('，')}。';
}

/// 拼出下一代的家族背景。
///
/// 宿敌那条单独成句并且放在最后——它是这一整段里最该被看见的东西。
String buildFamilyBackground({
  required String surname,
  required String parentName,
  required String parentSummary,
  required List<String> rivals,
  required int inheritance,
}) {
  final buf = StringBuffer()
    ..write('「$surname」家的人。')
    ..write(parentSummary)
    ..write('你从小就听人拿这个名字跟你相认，')
    ..write('也从小就知道那是别人的功劳，不是你的。')
    ..write('他给你留了 $inheritance 加隆');
  if (rivals.isNotEmpty) {
    buf
      ..write('，也留了几个仇人：')
      ..write(rivals.take(3).join('、'))
      ..write(rivals.length > 3 ? '等 ${rivals.length} 人' : '')
      ..write('。他们不会因为你是孩子就算了——'
          '这笔账是记在你这个姓上的。');
  } else {
    buf.write('，没留下什么仇怨。');
  }
  return buf.toString();
}
