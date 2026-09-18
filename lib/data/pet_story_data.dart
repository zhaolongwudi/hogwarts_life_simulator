/// P12 宠物小插曲库：给「世界在动」补上宠物自己的生活。
///
/// 现状：宠物只有玩家主动 `/宠物 喂食/玩耍/训练` 时才存在，不撒娇的时候，
/// 这只被养在家里的伙伴就像从世界里消失了一样。本层让宠物偶尔在离线的日常里
/// 冒出来一下——不是给玩家发任务，而是像身边真的有个小生命：早上窗台上的
/// 第一缕光、夜里钻进你袖口打盹、闯了祸还一脸无辜。
///
/// 两类插曲：
///   ① 日常小插曲（routine）：门槛低、会重复发生，给一点点羁绊，暖场不做主角；
///   ② 羁绊里程碑（milestone）：亲和跨过 25/55/85 三道坎时各演一次（演过不重播），
///      给一笔更实的分量，让「把一只宠物养大」这件事值得回忆。
///
/// 数据全收口在这里。mixin 只做「选插曲 + 结算」两层事；新增插曲只改这份文件。
library;

// ==================== 插曲效果 ====================

/// 一幕宠物插曲带来的结算（全部可选，0 = 不结算该项）。口径对齐奇遇/羁绊。
class PetStoryEffect {
  final int petBond; // 羁绊加成
  final int galleons;
  final int housePoints;
  final String? reputationDim; // academic/social/combat/moral/leadership/dark
  final int reputationValue;
  const PetStoryEffect({
    this.petBond = 0,
    this.galleons = 0,
    this.housePoints = 0,
    this.reputationDim,
    this.reputationValue = 0,
  });
}

/// 一幕宠物插曲。
class PetStoryDef {
  final String id;
  final List<String> petIds; // 适用宠物 id；空 = 通用（任何已养宠物）
  final int minBond; // 亲和下限（>= 才可触发）
  final bool milestone; // 是否一次性里程碑（演过不重播）
  final String scene; // 场景叙事（可带 `\$pet`/`\$house` 占位符）
  final PetStoryEffect effect;
  const PetStoryDef({
    required this.id,
    this.petIds = const [],
    this.minBond = 0,
    this.milestone = false,
    required this.scene,
    this.effect = const PetStoryEffect(),
  });
}

/// 插曲默认冷却（回合）：连续几回合都在涌小插曲会抢戏，让它像现实一样偶尔发生。
const int kPetStoryCooldownTurns = 6;

/// 按 id 查插曲。
PetStoryDef? petStoryById(String id) {
  for (final s in kPetStories) {
    if (s.id == id) return s;
  }
  return null;
}

/// 占位符替换：`$house` → 学院名，`$pet` → 宠物名。
String fillPetStoryText(String text, {required String house, required String pet}) {
  return text
      .replaceAll(r'$house', house)
      .replaceAll(r'$pet', pet);
}

/// 通用插曲集合。日常小插曲可重播；里程碑（milestone==true）只播一次。
const List<PetStoryDef> kPetStories = [
  // ====== 日常小插曲（一步给一点羁绊，可重播）======
  PetStoryDef(
    id: 'pet_dawn',
    scene:
        '清晨，\$pet 已经醒了，趴在窗台望着落进城堡的第一缕光。听见你的响动，'
        '它转过头，眼睛亮晶晶地望着你，像是在等一句「真乖」。',
    effect: PetStoryEffect(petBond: 1),
  ),
  PetStoryDef(
    id: 'pet_home',
    scene:
        '夜里你回寝，\$pet 不知从哪个角落钻出来，毛茸茸地蹭着你的裤脚，'
        '喉咙里咕噜咕噜直响，一天的疲惫都被它主人的那份高兴冲淡了几分。',
    effect: PetStoryEffect(petBond: 1),
  ),
  PetStoryDef(
    id: 'pet_mail',
    scene:
        '一只猫头鹰扑棱棱落在你桌角，却是 \$pet 替你叼来一封信——'
        '是你几天前忘了寄给同学的回信，它竟记得。',
    effect: PetStoryEffect(petBond: 1, galleons: 2),
  ),
  PetStoryDef(
    id: 'pet_nap',
    scene:
        '\$pet 藏进你外套的袖口里打盹，只露出一小截尾巴。你假装没看见，'
        '它便安心地睡得更沉，呼吸一起一伏，把你的心都带软了。',
    effect: PetStoryEffect(petBond: 1),
  ),
  PetStoryDef(
    id: 'pet_mischief',
    scene:
        '\$pet 又把你的羽毛笔叼走，藏进它的小窝里。你找回来时，'
        '它一脸无辜地歪着头，仿佛在说「真的不是我」。',
    effect: PetStoryEffect(petBond: 1),
  ),

  // ====== 羁绊里程碑（亲和跨槛，各演一次）======
  PetStoryDef(
    id: 'pet_bond_family',
    milestone: true,
    minBond: 25,
    scene:
        '这些日子相处下来，\$pet 终于彻底相信了你。它在你面前露出最柔软的肚皮，'
        '瞳孔温柔地望过来，像是把你当成了这个世界上唯一的家人。',
    effect: PetStoryEffect(petBond: 5, housePoints: 5),
  ),
  PetStoryDef(
    id: 'pet_bond_trust',
    milestone: true,
    minBond: 55,
    scene:
        '一场风波过后的深夜，\$pet 没有离开你半步。它固执地窝在你膝头，'
        '用体温告诉你：无论发生什么，它都会陪着你。',
    effect: PetStoryEffect(
        petBond: 5, reputationDim: 'social', reputationValue: 2, housePoints: 3),
  ),
  PetStoryDef(
    id: 'pet_bond_devotion',
    milestone: true,
    minBond: 85,
    scene:
        '你与 \$pet 之间早已无需言语。它在人群里第一个认出你走路的脚步声，'
        '在你难过时轻轻把脑袋靠进你怀里——这世上最妥帖的默契，不过如此。',
    effect: PetStoryEffect(
        petBond: 5, reputationDim: 'moral', reputationValue: 3, galleons: 10),
  ),
];