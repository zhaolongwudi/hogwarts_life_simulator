import 'dart:async';
import 'mixin_achievements.dart';
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../data/cg_data.dart';
import '../data/archetype_data.dart';
import '../data/ending_review_data.dart';
import '../data/job_data.dart';
import '../models/player.dart';
import '../utils/npc_lookup.dart';
import '../data/wand_data.dart';
import '../data/collectible_data.dart';
import '../data/rivalry_data.dart';
import '../services/ai_router.dart';
import '../providers/game_provider_base.dart';
import '../utils/debug_log.dart';

import 'mixin_relation_gifts.dart';

mixin GameRelationsMixin on GameAchievementsMixin, GameProviderBase, GameRelationGiftsMixin {
  @override
  void generateNewNPC() {
    final p = player;
    if (p == null) return;

    // 学年制上限：每学年最多生成6位新NPC（原4位，加速填充社交圈），跨学年自动重置计数
    final sy = worldState.time.month >= 9
        ? worldState.time.year
        : worldState.time.year - 1;
    if (npcGenerationSchoolYear != sy) {
      npcGenerationSchoolYear = sy;
      npcGeneratedThisSchoolYear = 0;
    }
    if (npcGeneratedThisSchoolYear >= 6) {
      currentNarrative = '新NPC数量已达到上限（每学年最多新增6位）。';
      choices = [GameChoice(text: '返回', action: '继续')];
      return;
    }

    final surnames = [
      '布莱克',
      '隆巴顿',
      '洛夫古德',
      '迪戈里',
      '波特',
      '马尔福',
      '沙比尼',
      '韦斯莱',
      '克鲁姆',
      '安德森',
      '塞尔温',
      '罗斯',
      '阿什福德',
      '格雷',
      '芬尼甘',
      '博恩斯',
      '艾博',
      '普莱斯',
    ];
    final givenMale = [
      '西奥多',
      '塞巴斯蒂安',
      '艾德里安',
      '卡斯珀',
      '伊万',
      '诺亚',
      '奥利弗',
      '利奥',
      '马库斯',
      '朱利安',
      '塞缪尔',
      '内森',
    ];
    final givenFemale = [
      '塞西莉亚',
      '艾拉',
      '薇奥拉',
      '罗莎琳',
      '埃洛伊斯',
      '伊莎贝拉',
      '莉莉安',
      '海伦娜',
      '卡珊德拉',
      '奥利维亚',
      '克洛伊',
      '斯嘉丽',
    ];

    final houseNames = {
      'Gryffindor': '格兰芬多',
      'Slytherin': '斯莱特林',
      'Ravenclaw': '拉文克劳',
      'Hufflepuff': '赫奇帕奇',
    };

    final personalityTemplates = <String, List<String>>{
      '勇敢型': ['勇敢', '直率', '热情', '正义'],
      '智慧型': ['理性', '聪明', '好奇', '独立'],
      '温柔型': ['善良', '温柔', '体贴', '细腻'],
      '野心型': ['野心', '精明', '果断', '领导'],
      '忠诚型': ['忠诚', '正直', '勤勉', '耐心'],
      '神秘型': ['神秘', '内敛', '深沉', '敏感'],
      '幽默型': ['幽默', '乐观', '热情', '善于交际'],
      '叛逆型': ['叛逆', '独立', '直率', '挑战权威'],
    };

    final appearanceTemplates = <String, List<String>>{
      'Gryffindor': [
        '红棕色的头发在风中微扬，绿色的眼睛里闪着热情的光芒',
        '高大挺拔，肩膀宽阔，笑容明亮而坦荡',
        '一头金色的短发，脸上有几颗雀斑，眼神坚定',
      ],
      'Slytherin': [
        '乌黑的长发披在肩上，眼睛是深邃的灰绿色',
        '身材修长，举手投足间带着一种与生俱来的优雅',
        '皮肤苍白，深色的眼睛里藏着不易察觉的心思',
      ],
      'Ravenclaw': [
        '一头凌乱的棕色卷发，戴着一副圆形眼镜',
        '目光锐利而充满好奇，总是在观察着周围的一切',
        '纤细的身影，眼神中带着几分聪慧的狡黠',
      ],
      'Hufflepuff': ['棕色的直发垂到肩际，笑容温暖而真诚', '体格健壮，给人踏实可靠的感觉', '圆圆的脸蛋，金色的眼睛里满是善意'],
    };

    // NPC 性别：匹配玩家取向所偏好的性别，保证玩家有可能喜欢上 TA。
    // 玩家取向 '男'→生成男生；'女'→生成女生；'双性'/未设→随机。
    final String npcGender;
    switch (p.sexOrientation) {
      case '男':
        npcGender = '男';
        break;
      case '女':
        npcGender = '女';
        break;
      default:
        npcGender = random.nextBool() ? '男' : '女';
    }
    final isMale = npcGender == '男';
    final givenNames = isMale ? givenMale : givenFemale;
    final name =
        '${givenNames[random.nextInt(givenNames.length)]}·${surnames[random.nextInt(surnames.length)]}';
    final houses = ['Gryffindor', 'Slytherin', 'Ravenclaw', 'Hufflepuff'];
    final house = houses[random.nextInt(houses.length)];
    // BUG-FIX: id 只用毫秒时间戳时，同毫秒内连续生成（批量 /新NPC 生成 N、
    // 快速连点）会产生重复 id，后一次覆盖前一次 → 实际生成数少于请求数。
    // 追加随机后缀保证唯一。
    final id =
        'generated_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(100000)}';
    final grade = p.grade ?? 1;

    final archetypes = personalityTemplates.keys.toList();
    final archetype = archetypes[random.nextInt(archetypes.length)];
    final personality = List<String>.from(
      personalityTemplates[archetype] ?? ['友善', '独立'],
    );
    final appearanceDesc =
        (appearanceTemplates[house] ?? ['面容清秀，眼神里带着好奇'])[random.nextInt(
          (appearanceTemplates[house] ?? ['面容清秀，眼神里带着好奇']).length,
        )];
    final houseLabel = houseNames[house] ?? house;

    // NPC 取向：必须包含玩家性别（NPC 喜欢玩家），否则永远无法向玩家表白。
    // 玩家性别已知 → 取向为玩家性别或'双性'（各50%）；未知 → '双性'。
    final String sexOrientation;
    if (p.gender == '男' || p.gender == '女') {
      sexOrientation = random.nextBool() ? p.gender : '双性';
    } else {
      sexOrientation = '双性';
    }

    // P2#14：生成时就拼好档案的原料（背景/日程/目标），
    // generatedProfile 不再是一行干巴巴的标签。
    final backstory = _generateNpcBackstoryFlavor(archetype, isMale, house);
    final goal = _generatePersonalGoal(archetype, house);
    final schedule = _generateNpcSchedule(house, grade);
    final scheduleLine = schedule.entries
        .map((e) => '${e.key} ${e.value}')
        .join('；');

    /// 新 NPC 的完整档案文本（背景故事 + 日常日程 + 目标）。
    String buildGeneratedProfile({
      required String archetype,
      required String houseLabel,
      required bool isMale,
      required String backstory,
      required String scheduleLine,
      required String? goal,
    }) {
      final who = isMale ? '男生' : '女生';
      final buf = StringBuffer()
        ..writeln('$archetype气质｜$houseLabel｜$who｜与你同年级')
        ..writeln()
        ..writeln('【背景故事】$backstory');
      if (scheduleLine.isNotEmpty) {
        buf.writeln();
        buf.writeln('【日常日程】$scheduleLine');
      }
      buf.writeln();
      buf.writeln('【人生目标】${goal ?? '尚未明确'}');
      return buf.toString();
    }

    final npc = NPC(
      id: id,
      name: name,
      house: house,
      grade: grade,
      bloodStatus: 'unknown',
      personality: personality,
      appearance:
          '$appearanceDesc。这位$houseLabel的${isMale ? '男生' : '女生'}，属于$archetype气质。',
      gender: npcGender,
      sexOrientation: sexOrientation,
      mood: roll(40, 70),
      affection: roll(5, 15),
      isGenerated: true,
      // P2#14：新 NPC 档案补全「背景故事/日常日程」——此前 generatedProfile
      // 只有一行干巴巴的标签，/查看 档案看不到任何血肉。现在把背景故事、
      // 日程、目标一起写进档案，老档（null）由展示层兜底。
      generatedProfile: buildGeneratedProfile(
        archetype: archetype,
        houseLabel: houseLabel,
        isMale: isMale,
        backstory: backstory,
        scheduleLine: scheduleLine,
        goal: goal,
      ),
      giftPrefs: generateGiftPrefsFor(archetype),
      personalGoal: goal,
      schedule: _generateNpcSchedule(house, grade),
      knowsAbout: _generateKnownFacts(archetype),
      reputation: _generateNpcReputation(archetype, house),
    );

    npcRegistry[id] = npc;
    npcGeneratedThisSchoolYear++;
    p.relationships[id] = Relationship(
      targetId: id,
      targetName: name,
      relationType: '同学',
      level: 10,
    );
    notifications.add('📬 新同学加入了你的圈子：$name（$archetype）');
    currentNarrative =
        '一位新的同学出现在霍格沃茨的走廊里——$name，来自$houseLabel学院。\n\n'
        '$appearanceDesc。从他/她的言行举止来看，这是一位$archetype气质的人。\n\n'
        '${_generateNpcBackstoryFlavor(archetype, isMale, house)}\n\n'
        '也许你们会有一段值得书写的故事。';
    choices = [
      GameChoice(text: '上前与$name打招呼', action: '上前与$name打招呼'),
      GameChoice(text: '保持距离，暗中观察', action: '保持距离，暗中观察'),
      GameChoice(text: '请$name帮个小忙', action: '请$name帮个小忙'),
    ];

    checkGenerationArtistAchievement();
  }

  /// 原型 → 礼物偏好（数据层实现，见 lib/data/archetype_data.dart）
  Map<String, int> generateGiftPrefsFor(String archetype) =>
      giftPrefsForArchetype(archetype);

  String? _generatePersonalGoal(String archetype, String house) {
    final goals = <String, List<String>>{
      '勇敢型': ['成为魁地奇队长', '证明自己的勇气', '保护身边的朋友'],
      '智慧型': ['解开一个古老的魔法谜题', '成为级长', '研究禁忌咒文'],
      '温柔型': ['治愈所有受伤的生物', '建立一个温暖的朋友圈', '守护一段珍贵的友谊'],
      '野心型': ['成为学生会主席', '掌握高阶黑魔法防御术', '建立自己的魔法家族'],
      '忠诚型': ['为学院赢得学院杯', '成为朋友最可靠的依靠', '守护家族的荣誉'],
      '神秘型': ['探索霍格沃茨的秘密', '理解自己的魔法天赋', '找到传说中的密室'],
      '幽默型': ['成为霍格沃茨的笑话大王', '让所有人都开怀大笑', '发明新的恶作剧道具'],
      '叛逆型': ['打破陈规', '证明传统可以被挑战', '追随自己的道路'],
    };
    final houseGoals = <String, List<String>>{
      'Gryffindor': ['赢得魁地奇冠军', '成为格兰芬多的骄傲'],
      'Slytherin': ['在斯莱特林出人头地', '成为最优秀的蛇院学生'],
      'Ravenclaw': ['解开图书馆的秘密', '拉文克劳最聪明的学生'],
      'Hufflepuff': ['证明赫奇帕奇的价值', '成为最努力工作的学生'],
    };
    final pool = <String>[];
    pool.addAll(goals[archetype] ?? []);
    pool.addAll(houseGoals[house] ?? []);
    if (pool.isEmpty) return null;
    return pool[random.nextInt(pool.length)];
  }

  Map<String, String> _generateNpcSchedule(String house, int grade) {
    final schedules = <String, Map<String, String>>{
      'Gryffindor': {
        '早晨': '在魁地奇训练场练习',
        '上午': '在教室里认真听讲',
        '下午': '在格兰芬多公共休息室休息',
        '晚上': '在图书馆查阅魁地奇战术',
      },
      'Slytherin': {
        '早晨': '在黑魔法防御术教室',
        '上午': '在魔药课实验室',
        '下午': '在斯莱特林公共休息室',
        '晚上': '在有求必应屋学习',
      },
      'Ravenclaw': {
        '早晨': '在图书馆占座',
        '上午': '在教室积极发言',
        '下午': '在天文塔观察星象',
        '晚上': '在图书馆研读古籍',
      },
      'Hufflepuff': {
        '早晨': '在厨房准备早餐',
        '上午': '在草药课温室',
        '下午': '在赫奇帕奇公共休息室',
        '晚上': '在厨房帮家养小精灵',
      },
    };
    return schedules[house] ??
        {'早晨': '在教室', '上午': '在上课', '下午': '在公共休息室', '晚上': '在图书馆'};
  }

  List<String> _generateKnownFacts(String archetype) {
    final facts = <String, List<String>>{
      '勇敢型': ['听说过禁林的传说', '知道如何找到秘密通道', '认识魁地奇队的人'],
      '智慧型': ['读过大部分图书馆的书', '知道一些古老的咒语', '对霍格沃茨的历史很了解'],
      '温柔型': ['知道谁需要帮助', '了解霍格沃茨的家养小精灵', '认识医院的护士'],
      '野心型': ['了解魔法部的运作', '知道哪些教授有影响力', '认识一些高年级学生'],
      '忠诚型': ['知道如何让朋友开心', '了解每个同学的喜好', '认识所有家养小精灵的名字'],
      '神秘型': ['听说过密室的传说', '知道一些不为人知的咒语', '对霍格沃茨的秘密很感兴趣'],
      '幽默型': ['知道所有恶作剧的秘密', '认识弗雷德和乔治的粉丝', '了解霍格沃茨的笑话'],
      '叛逆型': ['知道哪些规则可以打破', '了解有求必应屋的秘密', '认识一些反叛的学生'],
    };
    return facts[archetype] ?? ['知道一些校园的小秘密'];
  }

  Reputation _generateNpcReputation(String archetype, String house) {
    final rep = Reputation();
    switch (archetype) {
      case '勇敢型':
        rep.setValue('combat', roll(40, 70));
        rep.setValue('moral', roll(30, 60));
        break;
      case '智慧型':
        rep.setValue('academic', roll(50, 80));
        rep.setValue('dark', roll(10, 30));
        break;
      case '温柔型':
        rep.setValue('moral', roll(50, 80));
        rep.setValue('social', roll(40, 70));
        break;
      case '野心型':
        rep.setValue('leadership', roll(40, 70));
        rep.setValue('dark', roll(20, 50));
        break;
      case '忠诚型':
        rep.setValue('moral', roll(50, 75));
        rep.setValue('social', roll(35, 65));
        break;
      case '神秘型':
        rep.setValue('dark', roll(30, 60));
        rep.setValue('academic', roll(30, 60));
        break;
      case '幽默型':
        rep.setValue('social', roll(50, 80));
        break;
      case '叛逆型':
        rep.setValue('dark', roll(40, 70));
        rep.setValue('combat', roll(30, 60));
        break;
      default:
        rep.setValue('social', roll(30, 60));
    }
    return rep;
  }

  String _generateNpcBackstoryFlavor(
    String archetype,
    bool isMale,
    String house,
  ) {
    final prefix = isMale ? '他' : '她';
    final flavors = <String, List<String>>{
      '勇敢型': [
        '$prefix的父亲曾是$house的魁地奇队长，$prefix从小就梦想着继承这份荣耀。',
        '据说$prefix在二年级时就独自面对过一只博格特，展现了超乎年龄的勇气。',
        '$prefix总是第一个冲入危险的人，朋友们常常担心$prefix的安全。',
      ],
      '智慧型': [
        '$prefix在入学前就已经读完了大部分霍格沃茨的教科书。',
        '$prefix的论文总是被教授们当作范本，据说连邓布利多都曾关注过$prefix的学业。',
        '$prefix喜欢独自在图书馆待上几个小时，研究那些被其他学生忽略的角落。',
      ],
      '温柔型': [
        '$prefix来自一个温暖的家庭，$prefix的母亲是一位治疗师。',
        '$prefix经常在医务室帮忙照顾受伤的同学，院长阿姨对$prefix赞不绝口。',
        '$prefix总是能察觉别人的情绪变化，是朋友圈里最好的倾听者。',
      ],
      '野心型': [
        '$prefix的父母都是魔法部的高级官员，$prefix从小就被培养成未来的领袖。',
        '据说$prefix已经在为自己的政治生涯做准备，学生会主席是$prefix的第一个目标。',
        '$prefix做事有条不紊，目标明确，很少有人能动摇$prefix的决心。',
      ],
      '忠诚型': [
        '$prefix的家族代代都在$house，家族传统让$prefix对学院有着深厚的感情。',
        '$prefix是朋友圈里最值得信赖的人，任何秘密告诉$prefix都绝对安全。',
        '$prefix喜欢在厨房帮家养小精灵的忙，认为尊重每一个生灵是最重要的品质。',
      ],
      '神秘型': [
        '$prefix身上有一种说不清的气质，似乎总是能感知到别人感知不到的东西。',
        '$prefix对霍格沃茨的历史了如指掌，甚至包括那些被官方历史遗漏的片段。',
        '据说$prefix在入学时就表现出特殊的魔法天赋，让分院帽犹豫了很长时间。',
      ],
      '幽默型': [
        '$prefix是霍格沃茨的笑话大王，几乎每一天都能让身边的人开怀大笑。',
        '$prefix和弗雷德、乔治是好友，经常一起策划各种恶作剧。',
        '$prefix有一个特殊的天赋，能在任何场合找到笑点。',
      ],
      '叛逆型': [
        '$prefix的家庭背景有些特殊，这让$prefix从小就对权威持怀疑态度。',
        '$prefix拒绝遵守一些在$prefix看来不合理的规定，这让$prefix在某些圈子里很有名。',
        '$prefix信奉"规则是用来被打破的"，但$prefix有自己的底线。',
      ],
    };
    final list = flavors[archetype] ?? ['$prefix是一个有故事的人。'];
    return list[random.nextInt(list.length)];
  }

  @override
  int calculateAge() {
    final p = player;
    if (p == null) return 11;
    try {
      final birthYear = int.parse(p.birthYear);
      return worldState.time.year - birthYear;
    } catch (_) {
      return 11;
    }
  }


  @override
  bool purchaseItem(
    String itemName,
    int price, {
    String type = 'item',
    String description = '',
  }) {
    final p = player;
    if (p == null) return false;
    if (p.galleons < price) return false;
    p.galleons -= price;
    p.inventory.add(
      InventoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: itemName,
        type: type,
        description: description.isEmpty ? '购买的$itemName' : description,
      ),
    );
    // 买了就收进册子（如魁地奇徽章）。/收藏 以前永远是空的——没有任何
    // 地方往 collection 里写过东西。
    final collectibleId = collectibleForPurchase[itemName];
    if (collectibleId != null) addCollectible(collectibleId);
    notifications.add('💰 购买了 $itemName，花费 $price 加隆');
    notifyListeners();
    unawaited(autoSave());
    return true;
  }

  @override
  bool sellItem(int index, int price) {
    final p = player;
    if (p == null) return false;
    if (index < 0 || index >= p.inventory.length) return false;
    final item = p.inventory.removeAt(index);

    // 兜底：若卖掉的正是身上穿着的装备，同步卸下，
    // 否则装备栏会残留已售物品的名字（继续享受属性/施法加成）。
    // 正常流程下装备不在背包里，这主要防护旧存档迁移过来的数据。
    final equippedSlot = p.equipped.entries
        .where((e) => e.value == item.name)
        .map((e) => e.key)
        .toList();
    for (final slot in equippedSlot) {
      p.equipped.remove(slot);
    }

    p.galleons += price;
    notifications.add('💰 出售了 ${item.name}，获得 $price 加隆');
    notifyListeners();
    unawaited(autoSave());
    return true;
  }

  @override
  bool depositToBank(int amount) {
    final p = player;
    if (p == null || amount <= 0) return false;
    if (p.galleons < amount) return false;
    p.galleons -= amount;
    p.bankGalleons += amount;
    notifications.add('🏦 存入古灵阁 $amount 加隆');
    notifyListeners();
    unawaited(autoSave());
    return true;
  }

  @override
  bool withdrawFromBank(int amount) {
    final p = player;
    if (p == null || amount <= 0) return false;
    if (p.bankGalleons < amount) return false;
    p.bankGalleons -= amount;
    p.galleons += amount;
    notifications.add('🏦 从古灵阁取出 $amount 加隆');
    notifyListeners();
    unawaited(autoSave());
    return true;
  }

  @override
  int acceptJob(String jobId) {
    final p = player;
    if (p == null) return 0;
    JobDef? job;
    for (final j in jobCatalog) {
      if (j.id == jobId) {
        job = j;
        break;
      }
    }
    // ====== 打工限制（防经济通胀 + 需求校验） ======
    if (!canDoDaily('job')) {
      notifications.add('💼 今天的零工已经做满了（每日 2 单），明天再来。');
      return 0;
    }
    if (job != null) {
      final grade = p.grade ?? 1;
      // 一年级新生：只能干最基础的活（魔法部文员），其他岗位有经验要求
      final isBasic = job.requirements.contains('基础');
      if (!worldState.graduated && grade < 2 && !isBasic) {
        notifications.add('💼 「${job.title}」要求一定经验——一年级新生只能先做基础岗位（魔法部临时文员）。');
        return 0;
      }
      // 需求属性抽查：requirements 里的关键词 → 属性门槛
      final req = job.requirements;
      String? needAttr;
      int needVal = 40;
      if (req.contains('社交')) {
        needAttr = 'social';
      } else if (req.contains('魔法物品') || req.contains('知识')) {
        needAttr = 'theory';
      } else if (req.contains('神奇动物')) {
        needAttr = 'observation';
      }
      if (needAttr != null) {
        final cur = p.attributes[needAttr] ?? 0;
        if (cur < needVal) {
          notifications.add(
            '💼 「${job.title}」需要$needVal点${needAttr == 'social'
                ? '社交'
                : needAttr == 'theory'
                ? '魔法知识'
                : '观察力'}（当前 $cur）。',
          );
          return 0;
        }
      }
    }
    recordDailyActivity('job');
    final pay = job?.pay ?? 10;
    final energyCost = job?.energyCost ?? 2;
    final minutes = job?.minutes ?? 120;
    final title = job?.title ?? jobId;
    p.galleons += pay;
    p.jobHistory.add(
      '$title: +$pay加隆 (${worldState.time.month}月${worldState.time.day}日)',
    );
    // 记下最近一次岗位：毕业后 /状态 的「职业」用它，否则那一行会去显示
    // initialTalent（天赋），和「主修天赋」重复。
    p.currentJobTitle = title;
    // 上限保护：最多保留最近 50 条打工记录，防止存档无限膨胀
    if (p.jobHistory.length > 50) {
      p.jobHistory.removeRange(0, p.jobHistory.length - 50);
    }
    worldState.time.advanceMinutes(minutes);
    // 同步旧字段，保持时间显示一致
    worldState.dayOfMonth = worldState.time.day;
    worldState.dayOfWeek = GameTime.weekdays[worldState.time.weekday];
    worldState.month = GameTime.months[worldState.time.month - 1];
    p.energy = (p.energy - energyCost).clamp(0, 100);
    notifications.add('💼 打工完成（$title），获得 $pay 加隆');
    notifyListeners();
    unawaited(autoSave());
    return pay;
  }

  // ==================== 指令格式化 ====================

  @override
  Future<void> generateEnding() async {
    final p = player;
    if (p == null) {
      isLoading = false;
      loadingStage = '';
      notifyListeners();
      return;
    }

    final relationSnapshot = buildRelationshipSnapshot();
    final unlockedNames = achievementCatalog
        .where((a) => p.achievements.contains(a.id))
        .map((a) => a.name)
        .toList();
    final rep = p.playerReputation;
    final repSummary =
        '学术${rep.academic} 社交${rep.social} 战斗${rep.combat} 道德${rep.moral} 领导${rep.leadership} 黑魔法${rep.dark}';

    // 结局类型标识（框架2 §118 三类坏结局 + 黑化定性）：
    // 死亡/囚禁在 header 已单独列【结局】；黑化（堕落）此前只藏在 AI 评语
    // 的提示里，本地回退玩家永远看不到，这里升格为明确标识。
    final corruptedMark =
        (!p.isDead && !p.isImprisoned && rep.dark >= 70 && rep.moral < 35)
        ? '【结局】你成为了自己曾经害怕的人——黑魔法声望压过了道德底线，'
              '这段人生以另一种方式走向了终结（仍在人间，但那份改变已经无法回头）。\n'
        : '';
    final header =
        '╔══════════════════════════════════════╗\n'
        '  《终章报告》· ${p.name}的魔法人生\n'
        '╚══════════════════════════════════════╝\n\n'
        '【时代】${eraLabel(appProvider.era)}\n'
        '【学院】${p.house ?? '未分院'} · ${p.grade ?? 1}年级\n'
        '【爱情】${p.loveState.status}${p.loveState.partnerName != null ? '（${p.loveState.partnerName}）' : ''}\n'
        '【财富】${p.galleons}金加隆 · 银行${p.bankGalleons}\n'
        '【世界线变动率】${(p.worldLineDeviation * 100).toStringAsFixed(1)}%\n'
        '【人生目标】${goalSteeringLine(p.currentGoal).isEmpty ? '未设定' : goalSteeringLine(p.currentGoal)}\n'
        '【声望】$repSummary\n'
        '【成就】${unlockedNames.isEmpty ? '尚无' : unlockedNames.join('、')}\n'
        '【重要羁绊】${relationSnapshot.isEmpty ? '暂无深入关系' : relationSnapshot}\n'
        '${p.isDead ? '【结局】已于 ${p.deadOn ?? '未知时间'} 去世（${p.deathCause ?? '原因不明'}）\n' : ''}'
        '$corruptedMark';

    // 回望：把七年编成一篇能读的文章。
    //
    // 上面那个 header 是一堆数字，AI 写的是一段评语，
    // 中间缺的正是**发生过的事**。没配 AI 的玩家只有本地回退，
    // 那恰恰是最需要这篇骨架的时候——否则终章就只剩一张成绩单。
    final retrospective = formatEndingReview(
      buildEndingReview(endingFactsOf(p)),
    );

    // 本地回退（无 AI 或调用失败时使用）
    // 框架2 §121「很多年以后」：把有数据的字段落成问答段，缺失字段不硬编。
    final wandLine = p.wandId != null
        ? (wandById(p.wandId!)?.name ?? p.wandId)
        : null;
    final treasureLine = p.inventory.isNotEmpty ? p.inventory.first.name : null;
    final manyYearsLater = StringBuffer()
      ..writeln()
      ..writeln('【七年之后，很多年以后】');
    if (p.patronus != null && p.patronus!.isNotEmpty) {
      manyYearsLater.writeln('· 你的守护神：${p.patronus}');
    }
    if (wandLine != null) {
      manyYearsLater.writeln('· 陪了你一辈子的魔杖：$wandLine');
    }
    if (treasureLine != null) {
      manyYearsLater.writeln('· 最珍贵的东西：$treasureLine');
    }
    if (p.worldLineDeviation > 0.3) {
      manyYearsLater.writeln(
        '· 你改变过历史：世界线变动率 ${(p.worldLineDeviation * 100).toStringAsFixed(1)}%，'
        '史书上没有你的名字，但有些人的命运确实被你改写。',
      );
    }
    if (p.children.isNotEmpty) {
      manyYearsLater.writeln(
        '· 你的孩子：${p.children.take(3).map((c) => c.name).join('、')}',
      );
    }
    if (p.loveState.partnerName != null) {
      manyYearsLater.writeln('· 陪你走到最后的人：${p.loveState.partnerName}');
    }
    manyYearsLater.writeln('· 如果十一岁的你，能够看见这一生——你觉得他会满意吗？');
    final localFallback =
        '$header${retrospective.isEmpty ? '' : '\n$retrospective\n\n'}$manyYearsLater\n这段魔法人生走到终点。你曾站在九又四分之三站台，见证过霍格沃茨的晨昏，也与一些人结下过或深或浅的羁绊。无论结局如何，那些选择都已化作你独有的世界线，在无数平行世界里继续生长。\n\n—— 你的故事，到此暂告一段落。\n\n（提示：配置 AI 提供商后，/结局 可生成更完整的终章评语。）';

    var ending = localFallback;
    try {
      if (router != null && router!.hasNarrativeService) {
        final prompt =
            '''请为玩家撰写一份《终章报告》的评语部分，作为这段魔法人生的结局回顾。用第二人称"你"，小说化文笔，情感克制而有温度，600字以内。

  【玩家档案】
  姓名：${p.name}｜${p.gender}｜${bloodStatusLabel(p.bloodType)}｜${p.house ?? '未分院'}｜时代：${eraLabel(appProvider.era)}

  【人生目标】${p.currentGoal ?? '未设定'}（评价：是否实现、以怎样的方式实现或错失）

  【重要羁绊】${relationSnapshot.isEmpty ? '暂无深入关系' : relationSnapshot}

  【结局状态】${p.isDead ? '主角已经去世：${p.deadOn}，${p.deathCause}。终章必须如实书写这场死亡，把它作为人生的句点。' : '主角仍在人间。'}${rep.dark >= 70 && rep.moral < 35 ? '【堕落】主角的黑魔法声望压过了道德底线，终章应诚实呈现"成为自己曾经害怕的人"的代价。' : ''}

  【声望】$repSummary
  【成就】${unlockedNames.isEmpty ? '尚无' : unlockedNames.join('、')}

  【前情摘要】
  ${narrativeSummary.isNotEmpty ? narrativeSummary : '（这是一段从一年级开始的旅程）'}

  请按此结构输出：
  一、命运回响
  二、重要羁绊
  三、人生目标达成
  四、终章评语''';

        final result = await callDeepSeek(prompt, scene: AiScene.summary);
        final content = result.content.trim();
        if (content.isNotEmpty) {
          // 顺序是：统计 → 回望（发生过什么）→ 评语（那意味着什么）。
          // 回望提供骨架，AI 的评语提供血肉，两件事不重复。
          ending =
              header +
              (retrospective.isEmpty ? '' : '\n$retrospective\n\n') +
              content;
        }
      }
    } catch (e) {
      debugLog('终章生成失败，使用本地回退: $e');
    }

    currentNarrative = ending;
    choices = [GameChoice(text: '继续旅程', action: '继续')];
    isLoading = false;
    loadingStage = '';
    notifyListeners();
    unawaited(autoSave());
  }

  @override
  String formatRelationships() {
    // 只显示本局正式见过面/有过互动的人（introduced）：
    // 注册表开局会预注册整个时代的原典角色，不过滤的话新开局
    // 也会列出全员，看起来像上一局的残留
    final met =
        npcRegistry.values.where((n) => n.isAlive && n.introduced).toList()
          ..sort((a, b) => b.affection.compareTo(a.affection));
    // P2#13：已故 NPC 不再从列表里消失——法则五（NPC 会死）要能被看见，
    // 玩家才能知道谁不在了，而不是某天突然发现少了一个人。
    final dead = npcRegistry.values
        .where((n) => !n.isAlive && n.introduced)
        .toList();
    if (met.isEmpty && dead.isEmpty) {
      return '暂无认识的人。在剧情中与其他角色互动后会自动登记。';
    }
    final today = worldState.time.absoluteDayIndex;
    final buf = StringBuffer('【关系列表】（已认识 ${met.length} 人）\n');
    for (final n in met.take(15)) {
      // 光看"好感 -22"看不出他是冷淡还是恨你。宿敌徽标补上这一层：
      // 同样 -22，芥蒂和死对头是两回事。
      final tag = n.formerRival
          ? '🤝旧怨已了'
          : (n.hasGrudge
                ? '${rivalryBadgeFor(n.rivalryTier(today))}${tierDefFor(n.rivalryTier(today)).label}'
                : '');
      buf.writeln(
        '· ${n.name}：好感 ${n.affection}（${n.affectionStage}）'
        '${tag.isEmpty ? '' : ' $tag'}',
      );
    }
    if (dead.isNotEmpty) {
      buf.writeln('\n☠️ 已故（${dead.length}）');
      for (final n in dead) {
        final cause = (n.deathCause == null || n.deathCause!.isEmpty)
            ? ''
            : '（${n.deathCause}）';
        final on = (n.diedOn == null || n.diedOn!.isEmpty)
            ? ''
            : ' ${n.diedOn}';
        buf.writeln('· ${n.name}$cause$on');
      }
    }
    return buf.toString();
  }

  @override
  String formatLove() {
    final love = player!.loveState;
    if (love.status == '单身') {
      return '【恋爱状态】单身\n'
          '${_formatHighAffectionHints()}';
    }
    return '【恋爱状态】${love.status}\n'
        '对象：${love.partnerName}\n'
        '${love.history.isEmpty ? '' : '恋爱历程：\n${love.history.map((h) => '· ${h['date']}：${h['event']}').join('\n')}'}';
  }

  String _formatHighAffectionHints() {
    final hints = npcRegistry.values
        .where((n) => n.affection >= 70 && n.isAlive && !n.confessed)
        .map(
          (n) =>
              '· ${n.name}（好感 ${n.affection}）${n.isConsideringConfession ? '—— 似乎正在酝酿着什么……' : ''}',
        )
        .toList();
    if (hints.isEmpty) return '还没有人对你表现出特别的好感。';
    return '对你有较高好感的NPC：\n${hints.join('\n')}';
  }

  /// P2#11：/恋爱 历史 —— 恋爱历程 + 心动事件时间线。
  ///
  /// formatLove 只展示当前状态；这里把 loveState.history（每个阶段的里程碑）
  /// 和 recentNarrativeEvents 里带情感标记的事件拼成一条时间线，让玩家能
  /// 回看这段关系是怎么一步步走到今天的。
  @override
  String formatLoveHistory() {
    final love = player?.loveState;
    final buf = StringBuffer('【恋爱历史】');
    if (love == null || love.status == '单身') {
      buf.writeln('\n你还没有恋爱经历。');
    } else {
      buf.writeln('\n当前：${love.status}（${love.partnerName ?? '?'}）');
      if (love.history.isNotEmpty) {
        buf.writeln('\n—— 恋爱历程 ——');
        for (final h in love.history) {
          buf.writeln('· ${h['date']}：${h['event']}');
        }
      }
      if (love.engagedDate != null) {
        buf.writeln('· ${love.engagedDate}：订婚');
      }
      if (love.marriedDate != null) {
        buf.writeln('· ${love.marriedDate}：结婚');
      }
    }
    const loveKws = [
      '💗',
      '心动',
      '告白',
      '表白',
      '约会',
      '恋人',
      '接吻',
      'kiss',
      '拥抱',
      '情书',
    ];
    final related = worldState.recentNarrativeEvents
        .where((e) => loveKws.any((k) => e.text.contains(k)))
        .take(8)
        .toList();
    if (related.isNotEmpty) {
      buf.writeln('\n—— 心动事件（最近的记录）——');
      for (final e in related) {
        buf.writeln('· ${e.turn != null ? '第${e.turn}回合' : '?'}：${e.text}');
      }
    }
    if (buf.toString() == '【恋爱历史】\n你还没有恋爱经历。') {
      buf.writeln('\n去和喜欢的人多说说话，好感到了一切都有可能。');
    }
    return buf.toString();
  }

  // ==================== 恋爱等待状态 ====================

  @override
  String formatLoveWaiting() {
    if (player == null) return '【恋爱等待】\n尚未创建角色。';
    final love = player!.loveState;
    final considering = npcRegistry.values
        .where((n) => n.isConsideringConfession && n.isAlive)
        .map((n) => '· ${n.name}（好感 ${n.affection}）')
        .toList();
    final buf = StringBuffer('【恋爱等待】\n');
    if (love.awaitingConfession && love.consideringNpcName != null) {
      buf.writeln('${love.consideringNpcName} 正在认真考虑向你表白……');
      buf.writeln('请耐心等待，或继续与 TA 互动来推一把。');
    } else if (considering.isNotEmpty) {
      buf.writeln('以下 NPC 似乎正在酝酿感情：');
      buf.writeln(considering.join('\n'));
      buf.writeln('\n多互动可以加快表白时机。');
    } else {
      buf.writeln('目前没有 NPC 正在考虑向你表白。');
      buf.writeln(_formatHighAffectionHints());
    }
    return buf.toString();
  }

  // ==================== 恋爱阶段一览 ====================

  @override
  String formatLoveStages() {
    if (player == null) return '【恋爱阶段】\n尚未创建角色。';
    final love = player!.loveState;
    final stages = <String>[];
    if (love.partnerName != null) {
      stages.add('· ${love.partnerName}：${love.status}（正式伴侣）');
    }
    for (final entry in love.relationshipStages.entries) {
      if (entry.key == love.partnerName) continue;
      final events = love.romanticEventsFor(entry.key);
      stages.add('· ${entry.key}：${entry.value}（浪漫事件 $events 次）');
    }
    final highAffection = npcRegistry.values
        .where(
          (n) =>
              n.affection >= 60 &&
              n.isAlive &&
              !love.relationshipStages.containsKey(n.name) &&
              n.name != love.partnerName,
        )
        .take(5)
        .map((n) => '· ${n.name}：${n.affectionStage}（好感 ${n.affection}）')
        .toList();
    if (stages.isEmpty && highAffection.isEmpty) {
      return '【恋爱阶段】\n暂无任何 NPC 关系记录。多多互动会建立各种缘分。';
    }
    final buf = StringBuffer('【恋爱阶段】\n');
    if (stages.isNotEmpty) {
      buf.writeln('已建立关系：');
      buf.writeln(stages.join('\n'));
    }
    if (highAffection.isNotEmpty) {
      if (stages.isNotEmpty) buf.writeln();
      buf.writeln('高好感潜力对象：');
      buf.writeln(highAffection.join('\n'));
    }
    return buf.toString();
  }

  // ==================== NPC 关系网络查询 ====================

  @override
  String formatNpcRelationship(String npc1, String npc2) {
    if (player == null) return '【关系网络】\n尚未创建角色。';
    final a = findNpcByKeyword(npcRegistry.values, npc1);
    final b = findNpcByKeyword(npcRegistry.values, npc2);
    if (a == null || b == null) {
      final missing = a == null ? npc1 : npc2;
      return '【关系网络】\n「$missing」不在你认识的人里，信息不足。';
    }
    // 基础关系推理
    final tags = <String>[];
    if (a.house.isNotEmpty && b.house.isNotEmpty) {
      tags.add(a.house == b.house ? '同学院' : '跨学院');
    }
    // 共同认识的人（通过玩家关系推断）
    final relMap = player!.relationships;
    final aKnows = relMap.containsKey(a.id);
    final bKnows = relMap.containsKey(b.id);
    if (aKnows && bKnows) {
      tags.add('你们有共同好友（你）');
    }
    // 好感差异
    final diff = (a.affection - b.affection).abs();
    final closeness = a.affection > b.affection ? a.name : b.name;
    tags.add('你对 $closeness 更亲近（好感差 $diff）');
    // 血缘亲属检查
    final bloodRel = player!.bloodRelatives;
    final aIsBlood = bloodRel.any(
      (name) =>
          name == a.name || a.name.contains(name) || name.contains(a.name),
    );
    final bIsBlood = bloodRel.any(
      (name) =>
          name == b.name || b.name.contains(name) || name.contains(b.name),
    );
    if (aIsBlood && bIsBlood) tags.add('两人都是你的血缘亲属');
    return '【${a.name} 与 ${b.name} 的关系】\n'
        '标签：${tags.isEmpty ? '无特殊关联' : tags.join(' · ')}\n'
        '${a.house.isNotEmpty ? '${a.name}：${a.house}\n' : ''}'
        '${b.house.isNotEmpty ? '${b.name}：${b.house}\n' : ''}'
        '\n基于目前观察，他们属于${tags.length >= 2 ? '有交集的' : '普通的'}同学/熟人关系。';
  }
  // ==================== 时间格式化 ====================

  String _formatDate() {
    final t = worldState.time;
    final year = t.year;
    final months = [
      '1月',
      '2月',
      '3月',
      '4月',
      '5月',
      '6月',
      '7月',
      '8月',
      '9月',
      '10月',
      '11月',
      '12月',
    ];
    final month = (t.month >= 1 && t.month <= 12)
        ? months[t.month - 1]
        : '${t.month}月';
    final day = worldState.dayOfMonth;
    final weekday = worldState.dayOfWeek;
    final hour = t.hour.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    return '📅 $year年$month$day日，$weekday，[$hour:$minute]';
  }
  // ==================== CG 解锁 ====================

  @override
  void unlockCG(CgDef? cg) {
    final p = player;
    if (cg == null || p == null) return;
    if (p.cgRecords.containsKey(cg.id)) return;
    p.cgRecords[cg.id] = CgRecord(
      cgId: cg.id,
      name: cg.name,
      unlockedDate: _formatDate(),
      chapter: cg.chapter,
    );
    notifications.add('📸 解锁CG：${cg.name}');
    worldState.addNarrativeEvent('📸 解锁CG：${cg.name}', turn: turnCount);
    bumpImpactScore(0.02, debugReason: '解锁CG：${cg.id}');
  }

  @override

  @override
  void incrementWorldLineDeviation(double delta) {
    final p = player;
    if (p == null) return;
    p.worldLineDeviation = (p.worldLineDeviation + delta).clamp(0.0, 1.0);
    checkWorldChangerAchievement();
  }

  // ==================== DeepSeek 调用 ====================
}
