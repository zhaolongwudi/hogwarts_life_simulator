/// 时代定义（R3：数据化，替代 mixin_init.dart 中 5 处 Era switch）
///
/// 同一个 Era（dumbledore/marauders/harry_same...）的：
///   - 入学年份（startYear）
///   - 学年标签（academicYear）
///   - 长描述（label）
///   - 短描述（shortLabel）
///   - NPC 池 key（eraKey）
/// 统一定义在一张表。新增时代 = 新增 1 条 EraDef。
import '../providers/app_provider.dart';

class EraDef {
  final Era era;
  final int startYear;
  final String academicYear;
  final String label;
  final String shortLabel;
  final String eraKey;

  const EraDef({
    required this.era,
    required this.startYear,
    required this.academicYear,
    required this.label,
    required this.shortLabel,
    required this.eraKey,
  });
}

const List<EraDef> allEraDefs = [
  EraDef(
    era: Era.dumbledore,
    startYear: 1892,
    academicYear: '1892-1893',
    label: '邓布利多时代（1892-1899）：少年阿不思·邓布利多在霍格沃茨求学，认识盖勒特·格林德沃。',
    shortLabel: '邓布利多时代 1892（少年邓布利多求学）',
    eraKey: 'dumbledore',
  ),
  EraDef(
    era: Era.marauders,
    startYear: 1971,
    academicYear: '1971-1972',
    label: '亲世代（1971-1978）：掠夺者四人组与莉莉·伊万斯同窗的时代。',
    shortLabel: '亲世代 1971（掠夺者同窗）',
    eraKey: 'marauders',
  ),
  EraDef(
    era: Era.first_war,
    startYear: 1976,
    academicYear: '1976-1977',
    label: '第一次巫师战争（1970s后期）：社会氛围紧张，伏地魔崛起的阴影笼罩魔法界。',
    shortLabel: '一战末期 1976（伏地魔崛起）',
    eraKey: 'first_war',
  ),
  EraDef(
    era: Era.harry_same,
    startYear: 1991,
    academicYear: '1991-1992',
    label: '子世代（1991-1998）：哈利·波特在霍格沃茨的求学时期。',
    shortLabel: '子世代 1991（哈利入学）',
    eraKey: 'harry_same',
  ),
  EraDef(
    era: Era.post_war,
    startYear: 2020,
    academicYear: '2020-2021',
    label: '现代（2020+）：战后重建的魔法世界，阿不思·波特与斯科皮·马尔福的时代。',
    shortLabel: '战后 2020（阿不思·波特时代）',
    eraKey: 'post_war',
  ),
  EraDef(
    era: Era.random,
    startYear: 1991,
    academicYear: '1991-1992',
    label: '随机时代：由叙事开始时随机决定。',
    shortLabel: '随机时代',
    eraKey: 'random',
  ),
];

/// 当字符串解析失败时的回退（与旧 switch orElse 分支一致）
/// 注：不能用 const allEraDefs[1] —— List 的 [] 操作不是 compile-time constant expression。
final EraDef _fallback = allEraDefs[1]; // marauders

EraDef eraDefByEra(Era era) {
  for (final d in allEraDefs) {
    if (d.era == era) return d;
  }
  return _fallback;
}

/// 「随机时代」能掷到哪些时代——不含 [Era.random] 自己。
///
/// 顺序无意义，骰子掷到哪个就是哪个。
const List<Era> kRandomEraChoices = <Era>[
  Era.dumbledore,
  Era.marauders,
  Era.first_war,
  Era.harry_same,
  Era.post_war,
];

/// 把「随机时代」落定成一个具体时代。
///
/// 这个函数看着多余，但它是必需的：**`Era.random` 从来没有被解析过。**
/// 选了它的玩家拿到的是一个 `era` 字符串为 `'random'` 的存档，
/// 而 `'random'` 不是任何一个时代的 eraKey，于是——
///
/// | 受影响的地方 | 后果 |
/// |---|---|
/// | 事件锚点 | `anchorsFor(era: 'random')` 一条时代专属锚点都筛不出来 |
/// | NPC 种子 | `eraNpcSeeds['random']` 为空，开局一个时代专属 NPC 都没有 |
/// | 违禁词 / 校长 / 学年 | 全走 `eraDefByEra(Era.random)` 那条占位定义 |
///
/// 也就是说："随机时代"不是随机，是**没有时代**。
/// 玩家在设置里选了它，得到的是一个空了一半的世界，
/// 而不报任何错、不给任何提示。
///
/// [roll] 取 [0, 1)。抽成纯函数是为了能测分布——开局只掷一次骰子，
/// 落定之后这一整局都固定在这个时代，不该每回合重掷。
Era resolveEra(Era chosen, double roll) {
  if (chosen != Era.random) return chosen;
  final n = kRandomEraChoices.length;
  final idx = (roll * n).floor().clamp(0, n - 1);
  return kRandomEraChoices[idx];
}

// 注：eraDefByKey 已删——它按字符串反查，而字符串本来就是从
// eraDefByEra(era).eraKey 来的，再反查回去是绕圈子，全项目零调用。
