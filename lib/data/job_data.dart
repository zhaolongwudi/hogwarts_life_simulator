/// 打工岗位统一数据源
///
/// 供 job_screen.dart（岗位展示）与 mixin_relations.acceptJob（结算）共用，
/// 避免「界面显示 pay 25-50，实际结算恒为 10」这类接口与实现脱节的问题。

class JobDef {
  final String id;
  final String title;
  final String location;
  final int pay;
  final int energyCost;
  final int minutes;
  final String requirements;
  final String description;

  const JobDef({
    required this.id,
    required this.title,
    required this.location,
    required this.pay,
    required this.energyCost,
    required this.minutes,
    required this.requirements,
    required this.description,
  });
}

const List<JobDef> jobCatalog = [
  JobDef(
    id: 'ministry_clerk',
    title: '魔法部临时文员',
    location: '魔法部',
    pay: 30,
    energyCost: 2,
    minutes: 120,
    requirements: '基础魔法知识',
    description: '帮助魔法部整理文件、归档记录。需要细心和基本的魔咒能力。',
  ),
  JobDef(
    id: 'hogsmeade_waiter',
    title: '霍格莫德村服务生',
    location: '霍格莫德村·三把扫帚',
    pay: 25,
    energyCost: 3,
    minutes: 180,
    requirements: '社交能力',
    description: '在三把扫帚酒吧帮忙招待客人，可以听到各种八卦消息。',
  ),
  JobDef(
    id: 'diagon_assistant',
    title: '对角巷采购助理',
    location: '对角巷',
    pay: 40,
    energyCost: 4,
    minutes: 240,
    requirements: '识别魔法物品',
    description: '协助老顾客挑选魔杖、药水等魔法用品，有机会获得折扣。',
  ),
  JobDef(
    id: 'gringotts_carrier',
    title: '古灵阁金币搬运工',
    location: '古灵阁',
    pay: 50,
    energyCost: 5,
    minutes: 300,
    requirements: '力量·无巫术干扰',
    description: '帮妖精搬运金币和贵重物品。报酬丰厚但体力消耗大。',
  ),
  JobDef(
    id: 'creature_keeper',
    title: '神奇动物照看员',
    location: '海格小屋',
    pay: 35,
    energyCost: 4,
    minutes: 180,
    requirements: '对生物有耐心',
    description: '帮忙照顾巴克比克等神奇动物，可能被啄伤但很有价值。',
  ),
];
