/// 时代定义（R3：数据化，替代 mixin_init.dart 中 5 处 Era switch）
///
/// 同一个 Era（dumbledore/marauders/harry_same...）的：
///   - 入学年份（startYear）
///   - 学年标签（academicYear）
///   - 长描述（label）
///   - 短描述（shortLabel）
///   - NPC 池 key（eraKey）
/// 统一定义在一张表。新增时代 = 新增 1 条 EraDef。
import '../models/world_rules.dart';

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
const EraDef _fallback = allEraDefs[1]; // marauders

EraDef eraDefByEra(Era era) {
  for (final d in allEraDefs) {
    if (d.era == era) return d;
  }
  return _fallback;
}

EraDef eraDefByKey(String eraKey) {
  final lower = eraKey.toLowerCase();
  for (final d in allEraDefs) {
    if (d.era.name == lower) return d;
  }
  return _fallback;
}
