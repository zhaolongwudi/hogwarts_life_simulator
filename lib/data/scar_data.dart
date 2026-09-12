/// 重伤的代价：疤痕与后遗症
///
/// ## 现在的伤是怎么处理的
///
/// `player.injuries` 是一个 `List<String>`，全项目**只有一处写入**
/// （禁林探索给了个「禁林擦伤」），**没有任何一处清除**，
/// 也没有任何一处读取它来做判定。
///
/// 而叙事里那个 `injuryRe` 提取的只是**短期断言**
/// （"本回合动作描写要考虑伤势限制"），一回合就过期。
///
/// 于是：受伤就是扣几点血躺两天，**七年里没有任何事真正留下了痕迹**。
/// 报告 §3-7 的原话是「有了不可逆，玩家的选择才有重量」——
/// 现在的选择正好缺这个。
///
/// ## 落盘存什么
///
/// 存**事实**（哪个部位留了疤），不存**数值**（惩罚多少）。
///
/// 数值全部在 [kScarDefs] 里查表算出来。这样调平衡不用迁移存档——
/// 老存档读进来的还是那几个部位 key，但惩罚值已经是新的了。
/// 反过来做（把 -3 写进存档）的话，任何一次数值调整都会让
/// 玩家的旧档带着过时的惩罚，或者干脆读不出来。
///
/// ## 后遗症不全是负面的
///
/// 每条疤都配一正一负。胸口受过伤的人会怕，也会更谨慎；
/// 腿上留了疤的人飞不快了，但落地比谁都稳。
///
/// 这不是为了"平衡"——只给惩罚的话，疤就是个 debuff 图标。
/// 有了这一正一负，它才像是**发生在这具身体上的一件事**。

/// 疤痕部位
enum ScarSite {
  wandArm,
  leg,
  head,
  chest,
  back,
  face,
}

/// 一处疤
class ScarDef {
  final ScarSite site;

  /// 存盘用的 key
  final String key;

  /// 玩家可见的名字
  final String label;

  /// 后遗症的描述。这句会进 prompt 和结局回望，
  /// 所以得是读得懂的话，不能是 "-3 飞行"。
  final String aftermath;

  /// 属性影响。**允许有正值**——见文件头的说明。
  final Map<String, int> penalties;

  /// 从叙事里认出这个部位用的模式串
  final String pattern;

  const ScarDef({
    required this.site,
    required this.key,
    required this.label,
    required this.aftermath,
    required this.penalties,
    required this.pattern,
  });
}

/// 六个部位。
///
/// **顺序即优先级**：[scarFromNarrative] 按顺序取第一个命中的，
/// 所以 `face` 必须排在 `head` 前面——"脸颊"里也含"脸"，
/// 但"额头"和"脸颊"是两种完全不同的疤。
const List<ScarDef> kScarDefs = [
  ScarDef(
    site: ScarSite.face,
    key: 'face',
    label: '脸上的疤',
    aftermath: '别人看你的第一眼会停在那道疤上，然后才看到你。',
    penalties: {'social': -3, 'emotional_stability': 2},
    pattern: r'(脸|脸颊|面颊|眼睛|眼|鼻|嘴|下巴|眉骨)',
  ),
  ScarDef(
    site: ScarSite.wandArm,
    key: 'wand_arm',
    label: '持杖的手',
    aftermath: '举杖的动作慢了半拍——那半拍你一辈子都在找回来。',
    penalties: {'spell_understanding': -3, 'magic_control': -2, 'caution': 2},
    pattern: r'(手臂|胳膊|手腕|手掌|手指|肩膀|锁骨|右臂|左臂)',
  ),
  ScarDef(
    site: ScarSite.leg,
    key: 'leg',
    label: '腿上的旧伤',
    aftermath: '变天就疼。你再也没能飞得像从前那样快，'
        '但落地比谁都稳。',
    penalties: {'flying': -3, 'reaction_time': -2, 'caution': 2},
    pattern: r'(腿|膝盖|脚踝|脚|大腿|小腿|胫骨|跟腱)',
  ),
  ScarDef(
    site: ScarSite.head,
    key: 'head',
    label: '头上的伤',
    aftermath: '有些事想不起来了，有些事忘不掉。',
    penalties: {'memory': -3, 'theory': -2, 'intuition': 2},
    pattern: r'(头|额头|太阳穴|后脑|颅|脑)',
  ),
  ScarDef(
    site: ScarSite.chest,
    key: 'chest',
    label: '胸口的伤',
    aftermath: '你比从前怕了，也因此比从前更懂得什么时候该退。',
    penalties: {'courage': -2, 'caution': 3, 'emotional_stability': -2},
    pattern: r'(胸口|胸|腹部|肚子|肋骨|心脏|肺)',
  ),
  ScarDef(
    site: ScarSite.back,
    key: 'back',
    label: '背上的疤',
    aftermath: '你看不见它，但你知道它在那儿。',
    penalties: {'emotional_stability': -2, 'willpower': 2},
    pattern: r'(背|脊背|后背|肩胛|腰部)',
  ),
];

ScarDef? scarDefByKey(String key) {
  for (final d in kScarDefs) {
    if (d.key == key) return d;
  }
  return null;
}

// ============================================================ 认出重伤

/// 够得上"留疤"的那些伤。
///
/// 判定标准不是"疼"，是**会不会留下永久的痕迹**。
/// 擦伤、瘀青、流点血——这些会好，不留疤。
final RegExp kSevereInjuryRe = RegExp(
  r'(骨折|骨头断|断了|断裂|贯穿|穿透|烧焦|灼伤|碳化|深度|深可见骨|'
  r'诅咒留下|不可治愈|无法愈合|失去了|失去知觉|昏迷|毒已侵入|'
  r'留下了一道|留下一道|永久|再也|废了|瞎了|聋了|瘸)',
);

/// 会好的那些伤
final RegExp kMinorInjuryRe = RegExp(
  r'(擦伤|瘀青|淤青|青肿|青了一块|青了|划破|蹭破|流了点血|有点疼|'
  r'酸痛|扭伤|麻了一下|火辣辣|一阵疼|小伤|皮外伤)',
);

/// 认出一段叙事里留下的疤。
///
/// 必须**同时**满足两件事：伤得够重、说得出在哪个部位。
/// 只说"他受了重伤"不知道伤在哪，只说"手臂疼"不知道够不够重——
/// 两种情况都不该留疤。
///
/// 返回 null 表示这一句里没有值得留下的伤。
ScarDef? scarFromNarrative(String text) {
  if (text.isEmpty) return null;
  if (!_severeRe.hasMatch(text)) return null;
  for (final d in kScarDefs) {
    if (_siteRe(d).hasMatch(text)) return d;
  }
  return null;
}

// 这几个正则提在这里，是为了不在 [scarFromNarrative] 里反复编译——
// 这个函数每回合都要跑，而它是被逐条叙事调用的。
final RegExp _severeRe = kSevereInjuryRe;

/// 部位模式串的缓存。按 [kScarDefs] 的顺序，命中即返回。
final Map<ScarSite, RegExp> _siteReCache = {};

RegExp _siteRe(ScarDef d) =>
    _siteReCache[d.site] ??= RegExp('(${d.pattern})');

/// 这一句描述的是不是"会好"的那种伤。
/// 用来避免把「手臂擦破点皮」也记成疤。
bool isMinorInjury(String text) =>
    text.isNotEmpty && kMinorInjuryRe.hasMatch(text);

// ============================================================ 结算

/// 一处疤在玩家身上的记录
class Scar {
  final ScarSite site;

  /// 什么时候留下的（游戏内时间文本）
  final String since;

  const Scar({required this.site, required this.since});

  ScarDef get def => kScarDefs.firstWhere((d) => d.site == site);

  String get key => def.key;

  Map<String, dynamic> toJson() => {'site': def.key, 'since': since};

  static Scar? fromJson(Map<String, dynamic> json) {
    final d = scarDefByKey(json['site']?.toString() ?? '');
    if (d == null) return null;
    return Scar(site: d.site, since: json['since']?.toString() ?? '');
  }
}

/// 累计惩罚的封顶。
///
/// 七年里可能受好几次伤，不封顶的话受够三四次就废了——
/// 那不是"有重量"，那是劝退。
///
/// 定在 16 是按"三处疤完全不打折"算的：最重的三处是 5+5+5=15，
/// 第四处才越过这条线。也就是说**正常的几次受伤一分不少，
/// 只有真正把自己搞得浑身是伤才开始打折**。
const int kScarPenaltyCap = 16;

/// 把身上的疤换算成属性影响。
///
/// 两步防失控，都是在保护"受伤该有重量，但不该变成劝退"：
///
///   1. **同一个属性不累加，取最重的那一条**——
///      两条疤都影响记忆力的话，罚的是 -3 不是 -6。
///      累加会让重复受伤变成灾难，而"同一个地方再伤一次"
///      本来就不该比第一次更糟。
///
///      正负**分开**取：同一个属性可能既被罚又被补
///      （胸口受伤让人畏缩 -2，脸上留疤反而让人沉得住气 +2），
///      两条各自取最重的一条再相加，可以互相抵消。
///      这个细节很要紧——如果不分开，结果会取决于传入顺序，
///      同一副身体换个遍历顺序就换一套数值。
///   2. **负面总量超封顶就整体按比例压缩**。
///      只压负的那一半，正面的（谨慎 +3、直觉 +2 那些）原样保留——
///      那些是伤带来的东西，不是惩罚。
Map<String, int> scarPenaltiesOf(
  Iterable<Scar> scars, {
  int cap = kScarPenaltyCap,
}) {
  final worst = <String, int>{}; // 最重的负面（值是负的）
  final best = <String, int>{}; // 最大的正面
  for (final s in scars) {
    for (final e in s.def.penalties.entries) {
      if (e.value < 0) {
        final cur = worst[e.key];
        if (cur == null || e.value < cur) worst[e.key] = e.value;
      } else if (e.value > 0) {
        final cur = best[e.key];
        if (cur == null || e.value > cur) best[e.key] = e.value;
      }
    }
  }

  var total = 0;
  for (final v in worst.values) {
    total += -v;
  }
  // 按比例压缩，而不是截断：截断会让"多受一次伤"的惩罚凭空消失，
  // 按比例则始终保持着"多一处就更重一点"的手感，只是边际递减。
  final scale = total > cap ? cap / total : 1.0;

  final out = <String, int>{};
  for (final e in worst.entries) {
    // 用 truncate 而不是 round：round(-2.8) 是 -3，会把压缩原样吐回去，
    // 压完之后总量还是超（15 压到 14，舍入完又变回 15）。
    // truncate 对负数即向零取整，每一项的绝对值都不会变大，
    // 于是"压完必然不超"这件事是数学上成立的，不用再校验一遍。
    out[e.key] = (e.value * scale).truncate();
  }
  for (final e in best.entries) {
    out[e.key] = (out[e.key] ?? 0) + e.value;
  }
  return out;
}

/// 负面惩罚加起来有多少（压缩**之后**的值）。
int scarPenaltyTotal(Iterable<Scar> scars) {
  var total = 0;
  for (final v in scarPenaltiesOf(scars).values) {
    if (v < 0) total += -v;
  }
  return total;
}

/// 写进 prompt 的那一段。
///
/// 不写这一段，AI 会把你当成一个完好的人——
/// 让你健步如飞、举杖如常，那道疤就白留了。
String scarPromptBlock(Iterable<Scar> scars) {
  final list = scars.toList(growable: false);
  if (list.isEmpty) return '';
  final buf = StringBuffer()..writeln('【身上的伤（永远不会好）】');
  for (final s in list) {
    buf.writeln('· ${s.def.label}：${s.def.aftermath}');
  }
  buf.writeln('这些是永久的。描写动作、施法、奔跑时要记得它们，'
      '不要写你已经做不到的事。');
  return buf.toString();
}

/// 记一笔伤疤时给玩家看的话。
///
/// 用「留下了」而不是「受到了」——前者是结果，
/// 后者听起来像一条战斗日志。
String scarNoticeFor(ScarDef def) => '🩹 ${def.label}：${def.aftermath}';

/// 结局回望里那一句
String scarEpilogueFor(ScarDef def) => '${def.label}——${def.aftermath}';
