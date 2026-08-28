import 'dart:ui' show Color;

/// 主角政治立场的唯一定义处。
///
/// 此前六个立场的名称写在 intro_screen，描述/图标/配色又各写一份在
/// settings_screen 与 game_settings_tab，共三处。改动立场名需要同步改三个
/// 文件，已经漏过。这里收敛为一张表，UI 层只负责把它转成自己的选项类型。
class PoliticalStance {
  final String name;
  final String desc;

  /// 图标名的稳定标识，由 UI 层映射为 IconData，避免 data 层感知具体图标集。
  final String iconKey;

  /// ARGB，用 int 存以保持本文件不依赖 Flutter 的 Color 构造之外的东西。
  final int argb;

  /// 该立场是否明确反对"纯血至上"。
  ///
  /// 恋爱声望要判断"跨阵营"，而 NPC 手上只有 bloodSupremacist 一个标记，
  /// 玩家这边就得有个对应的口径。语义放在这里而不是调用方，是为了让立场名
  /// 只出现在 data 层——调用方一写「{'血统平等', '凤凰社支持'}」就等于又抄
  /// 了一份名单。
  final bool opposesBloodSupremacy;

  const PoliticalStance(this.name, this.desc, this.iconKey, this.argb,
      {this.opposesBloodSupremacy = false});

  /// 供 Flutter 侧直接使用的颜色。
  Color get color => Color(argb);

  @override
  String toString() => name;
}

/// 顺序即设置页与开局问卷中的展示顺序。
const List<PoliticalStance> kPoliticalStances = [
  PoliticalStance('血统平等', '相信血统不决定能力，混血麻瓜一样伟大', 'balance', 0xFF2980B9,
      opposesBloodSupremacy: true),
  PoliticalStance('纯血保守', '维护纯血传统，但不走向极端暴力', 'shield', 0xFFD4A017),
  PoliticalStance('中立投机', '审时度势，哪边有利倒向哪边', 'tune', 0xFF7F8C8D),
  PoliticalStance('凤凰社支持', '支持邓布利多阵营，积极对抗黑魔法', 'brightness', 0xFFD98880,
      opposesBloodSupremacy: true),
  PoliticalStance('食死徒同情', '同情或追随伏地魔的力量与理念', 'bolt', 0xFF111111),
  // 不站队 ≠ 反对纯血至上，恋爱声望里不算"跨阵营"
  PoliticalStance('自由独立', '不站队，坚持自己的判断与良知行事', 'allInclusive', 0xFF27AE60),
];

/// 未选择任何立场时的落点，与 Player 的默认值保持一致。
const String kDefaultPoliticalStance = '自由独立';

/// 纯名称列表，供不需要描述/配色的下拉与问卷使用。
///
/// 这里写死而不是从 kPoliticalStances 派生，是因为调用方要在 const 上下文里用。
/// 一致性由 test/progression_fix_test.dart 的断言守住。
const List<String> kPoliticalStanceNames = [
  '血统平等',
  '纯血保守',
  '中立投机',
  '凤凰社支持',
  '食死徒同情',
  '自由独立',
];

/// [name] 这个立场是否明确反对"纯血至上"。
///
/// 未知名字回落到默认立场（自由独立，不算反对），语义同 [stanceFor]。
bool opposesBloodSupremacy(String name) => stanceFor(name).opposesBloodSupremacy;

/// 按名字取立场，未知名字回落到默认立场而不是 null——调用方都是 UI，
/// 拿 null 只会退化成空白文案。
PoliticalStance stanceFor(String name) => kPoliticalStances.firstWhere(
      (s) => s.name == name,
      orElse: () => kPoliticalStances.firstWhere(
        (s) => s.name == kDefaultPoliticalStance,
      ),
    );
