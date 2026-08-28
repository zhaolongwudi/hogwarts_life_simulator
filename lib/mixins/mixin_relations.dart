import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../data/cg_data.dart';
import '../data/cg_unlock_conditions.dart';
import '../data/era_data.dart';
import '../data/game_config_rules.dart';
import '../data/world_rules.dart';
import '../data/job_data.dart';
import '../models/player.dart';
import '../data/course_data.dart';
import '../data/balance_constants.dart';
import '../services/ai_router.dart';
import '../providers/game_provider_base.dart';

mixin GameRelationsMixin on GameProviderBase {
  void generateNewNPC() {
    final p = player;
    if (p == null) return;

    // 学年制上限：每学年最多生成4位新NPC，跨学年自动重置计数
    final sy = worldState.time.month >= 9 ? worldState.time.year : worldState.time.year - 1;
    if (npcGenerationSchoolYear != sy) {
      npcGenerationSchoolYear = sy;
      npcGeneratedThisSchoolYear = 0;
    }
    if (npcGeneratedThisSchoolYear >= 4) {
      currentNarrative = '新NPC数量已达到上限（每学年最多新增4位）。';
      choices = [GameChoice(text: '返回', action: '继续')];
      return;
    }

    final surnames = [
      '布莱克', '隆巴顿', '洛夫古德', '迪戈里', '波特', '马尔福',
      '沙比尼', '韦斯莱', '克鲁姆', '安德森', '塞尔温', '罗斯',
      '阿什福德', '格雷', '芬尼甘', '博恩斯', '艾博', '普莱斯',
    ];
    final givenMale = [
      '西奥多', '塞巴斯蒂安', '艾德里安', '卡斯珀', '伊万', '诺亚',
      '奥利弗', '利奥', '马库斯', '朱利安', '塞缪尔', '内森',
    ];
    final givenFemale = [
      '塞西莉亚', '艾拉', '薇奥拉', '罗莎琳', '埃洛伊斯', '伊莎贝拉',
      '莉莉安', '海伦娜', '卡珊德拉', '奥利维亚', '克洛伊', '斯嘉丽',
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
      'Hufflepuff': [
        '棕色的直发垂到肩际，笑容温暖而真诚',
        '体格健壮，给人踏实可靠的感觉',
        '圆圆的脸蛋，金色的眼睛里满是善意',
      ],
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
    final name = '${givenNames[random.nextInt(givenNames.length)]}·${surnames[random.nextInt(surnames.length)]}';
    final houses = ['Gryffindor', 'Slytherin', 'Ravenclaw', 'Hufflepuff'];
    final house = houses[random.nextInt(houses.length)];
    final id = 'generated_${DateTime.now().millisecondsSinceEpoch}';
    final grade = p.grade ?? 1;

    final archetypes = personalityTemplates.keys.toList();
    final archetype = archetypes[random.nextInt(archetypes.length)];
    final personality = List<String>.from(personalityTemplates[archetype] ?? ['友善', '独立']);
    final appearanceDesc = (appearanceTemplates[house] ?? ['面容清秀，眼神里带着好奇'])[random.nextInt((appearanceTemplates[house] ?? ['面容清秀，眼神里带着好奇']).length)];
    final houseLabel = houseNames[house] ?? house;

    // NPC 取向：必须包含玩家性别（NPC 喜欢玩家），否则永远无法向玩家表白。
    // 玩家性别已知 → 取向为玩家性别或'双性'（各50%）；未知 → '双性'。
    final String sexOrientation;
    if (p.gender == '男' || p.gender == '女') {
      sexOrientation = random.nextBool() ? p.gender : '双性';
    } else {
      sexOrientation = '双性';
    }

    final npc = NPC(
      id: id,
      name: name,
      house: house,
      grade: grade,
      bloodStatus: 'unknown',
      personality: personality,
      appearance: '$appearanceDesc。这位$houseLabel的${isMale ? '男生' : '女生'}，属于$archetype气质。',
      gender: npcGender,
      sexOrientation: sexOrientation,
      mood: roll(40, 70),
      affection: roll(5, 15),
      isGenerated: true,
      generatedProfile: '$archetype气质｜$houseLabel｜${isMale ? '男' : '女'}生｜与你同年级',
      giftPrefs: _generateGiftPrefs(archetype),
      personalGoal: _generatePersonalGoal(archetype, house),
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

    _checkGenerationArtistAchievement();
  }

  Map<String, int> _generateGiftPrefs(String archetype) {
    switch (archetype) {
      case '勇敢型':
        return {'魁地奇徽章': 8, '勇气勋章': 6, '巧克力蛙': 2};
      case '智慧型':
        return {'旧书': 8, '羽毛笔': 5, '巧克力蛙': 2};
      case '温柔型':
        return {'花束': 7, '手写贺卡': 5, '巧克力蛙': 3};
      case '野心型':
        return {'计划书': 7, '银色钢笔': 6, '巧克力蛙': 2};
      case '忠诚型':
        return {'编织围巾': 8, '自制点心': 5, '巧克力蛙': 3};
      case '神秘型':
        return {'神秘符号': 8, '魔法道具': 6, '巧克力蛙': 2};
      case '幽默型':
        return {'恶作剧玩具': 7, '笑话集': 5, '巧克力蛙': 3};
      case '叛逆型':
        return {'朋克饰品': 8, '摇滚专辑': 6, '巧克力蛙': 2};
      default:
        return {'巧克力蛙': 2};
    }
  }

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
    return schedules[house] ?? {
      '早晨': '在教室',
      '上午': '在上课',
      '下午': '在公共休息室',
      '晚上': '在图书馆',
    };
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

  String _generateNpcBackstoryFlavor(String archetype, bool isMale, String house) {
    final prefix = isMale ? '他' : '她';
    final flavors = <String, List<String>>{
      '勇敢型': [
        '$prefix的父亲曾是${house}的魁地奇队长，$prefix从小就梦想着继承这份荣耀。',
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
        '$prefix的家族代代都在${house}，家族传统让$prefix对学院有着深厚的感情。',
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

  int get totalWealth {
    final p = player;
    if (p == null) return 0;
    return p.galleons + p.bankGalleons;
  }

  bool purchaseItem(String itemName, int price, {String type = 'item', String description = ''}) {
    final p = player;
    if (p == null) return false;
    if (p.galleons < price) return false;
    p.galleons -= price;
    p.inventory.add(InventoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: itemName,
      type: type,
      description: description.isEmpty ? '购买的$itemName' : description,
    ));
    notifications.add('💰 购买了 $itemName，花费 $price 加隆');
    notifyListeners();
    autoSave();
    return true;
  }

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
    autoSave();
    return true;
  }

  bool depositToBank(int amount) {
    final p = player;
    if (p == null || amount <= 0) return false;
    if (p.galleons < amount) return false;
    p.galleons -= amount;
    p.bankGalleons += amount;
    notifications.add('🏦 存入古灵阁 $amount 加隆');
    notifyListeners();
    autoSave();
    return true;
  }

  bool withdrawFromBank(int amount) {
    final p = player;
    if (p == null || amount <= 0) return false;
    if (p.bankGalleons < amount) return false;
    p.bankGalleons -= amount;
    p.galleons += amount;
    notifications.add('🏦 从古灵阁取出 $amount 加隆');
    notifyListeners();
    autoSave();
    return true;
  }

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
    final pay = job?.pay ?? 10;
    final energyCost = job?.energyCost ?? 2;
    final minutes = job?.minutes ?? 120;
    final title = job?.title ?? jobId;
    p.galleons += pay;
    p.jobHistory.add('$title: +$pay加隆 (${worldState.time.month}月${worldState.time.day}日)');
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
    autoSave();
    return pay;
  }

  // ==================== 指令格式化 ====================

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

    final header = '╔══════════════════════════════════════╗\n'
        '  《终章报告》· ${p.name}的魔法人生\n'
        '╚══════════════════════════════════════╝\n\n'
        '【时代】${eraLabel(appProvider.era)}\n'
        '【学院】${p.house ?? '未分院'} · ${p.grade ?? 1}年级\n'
        '【爱情】${p.loveState.status}${p.loveState.partnerName != null ? '（${p.loveState.partnerName}）' : ''}\n'
        '【财富】${p.galleons}金加隆 · 银行${p.bankGalleons}\n'
        '【世界线变动率】${(p.worldLineDeviation * 100).toStringAsFixed(1)}%\n'
        '【人生目标】${p.currentGoal ?? '未设定'}\n'
        '【声望】$repSummary\n'
        '【成就】${unlockedNames.isEmpty ? '尚无' : unlockedNames.join('、')}\n'
        '【重要羁绊】${relationSnapshot.isEmpty ? '暂无深入关系' : relationSnapshot}\n';

    // 本地回退（无 AI 或调用失败时使用）
    final localFallback = header +
        '\n这段魔法人生走到终点。你曾站在九又四分之三站台，见证过霍格沃茨的晨昏，'
        '也与一些人结下过或深或浅的羁绊。无论结局如何，那些选择都已化作你独有的世界线，'
        '在无数平行世界里继续生长。\n\n'
        '—— 你的故事，到此暂告一段落。\n\n（提示：配置 AI 提供商后，/结局 可生成更完整的终章评语。）';

    var ending = localFallback;
    try {
      if (router != null && router!.hasNarrativeService) {
        final prompt = '''请为玩家撰写一份《终章报告》的评语部分，作为这段魔法人生的结局回顾。用第二人称"你"，小说化文笔，情感克制而有温度，600字以内。

  【玩家档案】
  姓名：${p.name}｜${p.gender}｜${bloodStatusLabel(p.bloodType)}｜${p.house ?? '未分院'}｜时代：${eraLabel(appProvider.era)}

  【人生目标】${p.currentGoal ?? '未设定'}（评价：是否实现、以怎样的方式实现或错失）

  【重要羁绊】${relationSnapshot.isEmpty ? '暂无深入关系' : relationSnapshot}

  【声望】$repSummary
  【成就】${unlockedNames.isEmpty ? '尚无' : unlockedNames.join('、')}

  【前情摘要】
  ${narrativeSummary.isNotEmpty ? narrativeSummary : '（这是一段从一年级开始的旅程）'}

  请按此结构输出：
  一、命运回响
  二、重要羁绊
  三、人生目标达成
  四、终章评语''';

        final result = await callDeepSeek(
          prompt,
          scene: AiScene.summary,
        );
        final content = result.content.trim();
        if (content.isNotEmpty) {
          ending = header + '\n' + content;
        }
      }
    } catch (e) {
      debugPrint('终章生成失败，使用本地回退: $e');
    }

    currentNarrative = ending;
    choices = [GameChoice(text: '继续旅程', action: '继续')];
    isLoading = false;
    loadingStage = '';
    notifyListeners();
    autoSave();
  }

  String formatRelationships() {
    // 只显示本局正式见过面/有过互动的人（introduced）：
    // 注册表开局会预注册整个时代的原典角色，不过滤的话新开局
    // 也会列出全员，看起来像上一局的残留
    final met = npcRegistry.values
        .where((n) => n.isAlive && n.introduced)
        .toList()
      ..sort((a, b) => b.affection.compareTo(a.affection));
    if (met.isEmpty) {
      return '暂无认识的人。在剧情中与其他角色互动后会自动登记。';
    }
    final buf = StringBuffer('【关系列表】（已认识 ${met.length} 人）\n');
    for (final n in met.take(15)) {
      buf.writeln('· ${n.name}：好感 ${n.affection}（${n.affectionStage}）');
    }
    return buf.toString();
  }

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
        .map((n) => '· ${n.name}（好感 ${n.affection}）${n.isConsideringConfession ? '—— 似乎正在酝酿着什么……' : ''}')
        .toList();
    if (hints.isEmpty) return '还没有人对你表现出特别的好感。';
    return '对你有较高好感的NPC：\n${hints.join('\n')}';
  }

  // ==================== 恋爱等待状态 ====================

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
        .where((n) =>
            n.affection >= 60 &&
            n.isAlive &&
            !love.relationshipStages.containsKey(n.name) &&
            n.name != love.partnerName)
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

  String formatNpcRelationship(String npc1, String npc2) {
    if (player == null) return '【关系网络】\n尚未创建角色。';
    NPC findNpc(String keyword) {
      return npcRegistry.values.firstWhere(
        (n) => n.name.contains(keyword) || keyword.contains(n.name),
        orElse: () => NPC(id: '', name: '「$keyword」', house: ''),
      );
    }

    final a = findNpc(npc1);
    final b = findNpc(npc2);
    if (a.id.isEmpty || b.id.isEmpty) {
      return '【${a.name} 与 ${b.name} 的关系】\n其中有 NPC 不在你的社交圈中，信息不足。';
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
    final aIsBlood = bloodRel.any((name) => name == a.name || a.name.contains(name) || name.contains(a.name));
    final bIsBlood = bloodRel.any((name) => name == b.name || b.name.contains(name) || name.contains(b.name));
    if (aIsBlood && bIsBlood) tags.add('两人都是你的血缘亲属');
    return '【${a.name} 与 ${b.name} 的关系】\n'
        '标签：${tags.isEmpty ? '无特殊关联' : tags.join(' · ')}\n'
        '${a.house.isNotEmpty ? '${a.name}：${a.house}\n' : ''}'
        '${b.house.isNotEmpty ? '${b.name}：${b.house}\n' : ''}'
        '\n基于目前观察，他们属于${tags.length >= 2 ? '有交集的' : '普通的'}同学/熟人关系。';
  }

  // ==================== 骨科模式状态 ====================

  String formatBoneMode() {
    if (player == null) return '【骨科模式】\n尚未创建角色。';
    final bloodRel = player!.bloodRelatives;
    final buf = StringBuffer(player!.boneMode
        ? '【骨科模式】已开启\n允许与血缘亲属发展浪漫关系。\n\n'
        : '【骨科模式】已关闭\n无法与血缘亲属发展浪漫关系。\n\n');
    if (bloodRel.isEmpty) {
      buf.writeln('当前血缘亲属列表：（暂无记录）');
    } else {
      buf.writeln('当前血缘亲属列表：');
      for (final name in bloodRel.take(10)) {
        final npc = npcRegistry.values.firstWhere(
          (n) => n.name == name || name.contains(n.name) || n.name.contains(name),
          orElse: () => NPC(id: '', name: name, house: ''),
        );
        final extra = npc.house.isNotEmpty ? ' · ${npc.house}' : '';
        buf.writeln('· $name$extra');
      }
      if (bloodRel.length > 10) buf.writeln('  ……等共 ${bloodRel.length} 位');
    }
    return buf.toString();
  }

  /// 阵营倾向的文字解读，让「阵营声望」这个派生数字有实际含义
  String _factionLeanLabel(int lean) {
    if (lean >= 40) return '（黑暗阵营一方颇有名气）';
    if (lean >= 15) return '（被黑暗势力注意到）';
    if (lean <= -40) return '（凤凰社一方的可靠盟友）';
    if (lean <= -15) return '（偏向邓布利多一方）';
    return '（尚未明确站位）';
  }

  String formatReputation() {
    final rep = player!.playerReputation;
    final p = player!;
    return '''【声望档案】
  学术声望：${rep.academic}（${reputationGrade(rep.academic)}）
  社交声望：${rep.social}（${reputationGrade(rep.social)}）
  战斗声望：${rep.combat}（${reputationGrade(rep.combat)}）
  道德声望：${rep.moral}（${reputationGrade(rep.moral)}）
  领导声望：${rep.leadership}（${reputationGrade(rep.leadership)}）
  黑魔法声望：${rep.dark}（${reputationGrade(rep.dark)}）

  学院声望：${p.houseReputation}
  魔法界声望：${p.wizardingReputation}（五维均值，黑魔法不计入）
  阵营声望：${p.factionReputation}${_factionLeanLabel(p.factionReputation)}
  （阵营声望 = 黑魔法声望 − 道德声望）''';
  }

  /// 舆论/传闻系统（设定文档 7.3 / 第十三部分）

  String formatRumors() {
    final rumors = player!.rumors;
    if (rumors.isEmpty) {
      return '【舆论】\n目前校园里还没有关于你的传闻。你只是个普通学生——至少现在还是。';
    }
    final buf = StringBuffer('【舆论 / 传闻】\n');
    for (final r in rumors) {
      buf.writeln('· $r');
    }
    buf.writeln('\n（输入 /cheat 舆论 清除 可删除传闻）');
    return buf.toString();
  }

  /// 追加一条传闻（去重 + 保留最近 20 条，避免无限膨胀）

  void _addRumor(String text) {
    final p = player;
    if (p == null) return;
    if (p.rumors.contains(text)) return;
    p.rumors.insert(0, text);
    if (p.rumors.length > 20) {
      p.rumors.removeRange(20, p.rumors.length);
    }
  }

  String formatCourses() {
    final era = appProvider.era;
    final buf = StringBuffer('【课程系统】\n必修课：\n');
    for (final c in requiredCourses) {
      buf.writeln('· ${c.name}（${professorName(c.id, c.professor, era)}）');
    }
    buf.writeln('\n选修课（三年级起，至少选2门）：');
    for (final c in electiveCourses) {
      buf.writeln('· ${c.name}（${professorName(c.id, c.professor, era)}）');
    }
    buf.writeln('\n（输入 /课堂 互动 进入当前课堂的互动环节）');
    return buf.toString();
  }

  /// 课堂互动（设定 10.3，全程本地判定，零 token 消耗）

  void classroomInteraction() {
    final p = player;
    if (p == null) return;
    final roll = random.nextInt(100);
    String result;

    if (roll < 40) {
      // 教授提问：影响学术声望
      final correct = random.nextBool();
      if (correct) {
        p.playerReputation.add('academic', 2);
        result = '【课堂互动 · 教授提问】\n'
            '教授的目光扫过教室，最后停在你身上，抛出一个刁钻的问题。\n'
            '你略一思索，给出了答案。教室里响起几声低低的惊叹，教授罕见地点了点头。\n'
            '\n学术声望 +2';
      } else {
        result = '【课堂互动 · 教授提问】\n'
            '教授突然点你的名。你心头一跳，答案卡在喉咙里，最后只好摇了摇头。\n'
            '几个同学投来同情的目光，你决定下次好好预习。\n'
            '\n（本次无变化）';
      }
    } else if (roll < 70) {
      // 实践操作：影响技能熟练度
      const skills = ['魔咒学', '变形术', '魔药学', '草药学'];
      const skillAttrs = {
        '魔咒学': 'spell_understanding',
        '变形术': 'transfiguration',
        '魔药学': 'potions',
        '草药学': 'herbology',
      };
      final skill = skills[random.nextInt(skills.length)];
      final attr = skillAttrs[skill]!;
      p.attributes[attr] = ((p.attributes[attr] ?? 50) + 1).clamp(0, 100);
      result = '【课堂互动 · 实践操作】\n'
          '你握紧魔杖，全神贯注地练习$skill。魔杖尖端的光芒稳定而流畅，眼前的材料随着你的咒语乖巧地变化。\n'
          '\n$skill 熟练度 +1';
    } else if (roll < 90) {
      // 同桌互动：影响 NPC 好感
      final alive = npcRegistry.values.where((n) => n.isAlive).toList();
      if (alive.isNotEmpty) {
        final npc = alive[random.nextInt(alive.length)];
        final delta = 1 + random.nextInt(2); // +1 ~ +2
        npc.affection = (npc.affection + delta).clamp(-100, 100);
        result = '【课堂互动 · 同桌】\n'
            '趁教授转身，${npc.name}悄悄递来一张纸条，上面写着刚才没听懂的笔记要点。\n'
            '你冲对方感激地笑了笑。\n'
            '\n与 ${npc.name} 的好感 +$delta';
      } else {
        result = '【课堂互动 · 同桌】\n你环顾四周，身边的座位空着，只得独自琢磨刚才的内容。';
      }
    } else {
      // 特殊意外：R12 使用 classAccidentPool（支持科目筛选 + 通用池，去除「斯内普教授」硬编码特判）
      // 注意：WorldState 没有持久化 currentCourse 字段（玩家可以任何时间点调用 /课堂 互动），
      //       此处从全量课程表里随机抽 1 门课名作为"当前课"做科目筛选，和同函数"实践操作"分支保持一致。
      final allCourseNames = [
        ...requiredCourses.map((c) => c.name),
        ...electiveCourses.map((c) => c.name),
      ];
      final currentCourse = allCourseNames[random.nextInt(allCourseNames.length)];
      final candidates = classAccidentPool.where((e) {
        if (e.subjectFilter.isEmpty) return true;
        return e.subjectFilter.any(
          (k) => currentCourse.contains(k) || k.contains(currentCourse),
        );
      }).toList();
      final pool = candidates.isNotEmpty ? candidates : classAccidentPool;
      final text = pool[random.nextInt(pool.length)].text;
      result = '【课堂互动 · 意外】\n$text\n\n（一段课堂上的小插曲，世界线纹丝不动）';
    }

    currentNarrative = result;
    choices = [GameChoice(text: '继续', action: '继续')];
  }

  String formatCollection() {
    if (player!.collection.isEmpty) {
      return '【收藏】\n暂无收藏品。在冒险中收集独特物品，如巧克力蛙画片、日记本等。';
    }
    return '【收藏】\n${player!.collection.map((c) => '· $c').join('\n')}';
  }

  /// [parts] 为「去掉 /信 命令本身」后的子参数列表，parts[0] 即子命令。
  void handleLetterCommand(List<String> parts) {
    final back = () {
      choices = [GameChoice(text: '返回', action: '继续')];
    };

    if (parts.isEmpty) {
      currentNarrative = _formatLetters();
      back();
      return;
    }

    switch (parts[0]) {
      case '读':
        final idx = int.tryParse(parts.length > 1 ? parts[1] : '');
        currentNarrative = idx == null
            ? '【信件】\n请输入信件编号：/信 读 [编号]'
            : _formatLetterDetail(idx);
        back();
        return;
      case '回':
        final idx = int.tryParse(parts.length > 1 ? parts[1] : '');
        if (idx == null) {
          currentNarrative = '【回信】\n请输入：/信 回 [编号] [回信内容]';
        } else {
          final content = parts.length > 2 ? parts.sublist(2).join(' ') : '';
          currentNarrative = _replyToLetter(idx, content);
        }
        back();
        return;
      case '寄':
        final name = parts.length > 1 ? parts[1] : '';
        final content = parts.length > 2 ? parts.sublist(2).join(' ') : '';
        currentNarrative = name.isEmpty
            ? '【寄信】\n请输入：/信 寄 [NPC名字] [信件内容]'
            : _sendLetterToNpc(name, content);
        back();
        return;
      default:
        currentNarrative = _formatLetters();
        back();
        return;
    }
  }

  String _formatLetters() {
    final letters = player!.letters;
    if (letters.isEmpty) {
      return '【信件】\n暂无信件。\n\n你可以通过猫头鹰给某人寄信：/信 寄 [NPC名字] [内容]';
    }
    final buf = StringBuffer()
      ..writeln('【信件】共 ${letters.length} 封（✉ 表示未读）')
      ..writeln();
    for (int i = 0; i < letters.length; i++) {
      final l = letters[i];
      final mark = l.read ? '　' : '✉';
      buf.writeln('[$mark ${i + 1}] ${l.sender}（${l.date}）');
      final preview = l.content.length > 26 ? '${l.content.substring(0, 26)}…' : l.content;
      buf.writeln('      $preview');
      buf.writeln();
    }
    buf.writeln('用法：/信 读 [编号] · /信 回 [编号] [内容] · /信 寄 [NPC名字] [内容]');
    return buf.toString();
  }

  String _formatLetterDetail(int index) {
    final letters = player!.letters;
    if (index < 1 || index > letters.length) {
      return '【信件】\n没有第 $index 封信。当前共 ${letters.length} 封。';
    }
    final l = letters[index - 1];
    l.read = true;
    return '【书信】\n寄信人：${l.sender}\n日期：${l.date}\n\n${l.content}';
  }

  /// 寄信给 NPC（本地逻辑，不消耗 AI token）

  String _sendLetterToNpc(String npcName, String content) {
    final p = player;
    if (p == null) return '【寄信】\n尚未创建角色。';
    if (content.trim().isEmpty) {
      return '【寄信】\n请写明信件内容：/信 寄 [$npcName] [信件内容]';
    }

    NPC? npc;
    for (final n in npcRegistry.values) {
      if (n.name.contains(npcName) || npcName.contains(n.name)) {
        npc = n;
        break;
      }
    }
    if (npc == null) {
      return '【寄信】\n你没有找到名叫「$npcName」的人。可输入 /关系 查看已认识的NPC。';
    }
    if (!npc.isAlive) {
      return '【寄信】\n${npc.name}已经无法收到你的信了……';
    }

    // 寄信耗时（猫头鹰往返）
    worldState.time.advanceMinutes(15);

    // 信件是低成本的维系方式：好感小幅提升
    final stage = affectionStageFor(npc.affection);
    int change = 1;
    if (stage == '友好' || stage == '信任') change = 2;
    if (stage == '亲密' || stage == '深爱' || stage == '灵魂伴侣') change = 3;
    updateNpcAffection(npc.id, change, reason: '寄信联络');

    // 对方回信（本地模板，不消耗 AI token）
    _addLetter(sender: npc.name, content: _generateLetterReply(npc));

    final warm = stage == '死敌' || stage == '宿怨' || stage == '反感'
        ? '（对方似乎并不领情）'
        : '（你们的关系似乎更近了一点）';
    return '【寄信】\n你把写好的信交给猫头鹰，目送它振翅飞向${npc.name}。$warm\n\n几天后，猫头鹰带回了回信——输入 /信 读 查看最新一封。';
  }

  /// 回信给某封信的寄信人

  String _replyToLetter(int index, String content) {
    final letters = player!.letters;
    if (index < 1 || index > letters.length) {
      return '【回信】\n没有第 $index 封信。当前共 ${letters.length} 封。';
    }
    final letter = letters[index - 1];
    letter.read = true;
    return _sendLetterToNpc(letter.sender, content);
  }

  /// 添加一封来信
  /// 上限保护：最多保留 50 封信，超出时优先删除最旧的已读信件
  void _addLetter({required String sender, required String content}) {
    player!.letters.add(Letter(
      id: 'L${DateTime.now().microsecondsSinceEpoch}',
      sender: sender,
      content: content,
      date: worldState.time.formatDate(),
    ));
    if (player!.letters.length > 50) {
      // 优先删除最旧的已读信件；若全部未读则删除最旧的
      final readIdx = player!.letters.indexWhere((l) => l.read);
      if (readIdx >= 0) {
        player!.letters.removeAt(readIdx);
      } else {
        player!.letters.removeAt(0);
      }
    }
    notifications.add('📬 收到来自 $sender 的信');
  }

  /// 根据好感阶段生成 NPC 回信（本地模板）

  String _generateLetterReply(NPC npc) {
    final stage = affectionStageFor(npc.affection);
    final name = npc.name;
    switch (stage) {
      case '死敌':
      case '宿怨':
      case '反感':
        return '（${name}读完你的信后，随手把它揉成一团扔进了壁炉。）\n你对${name}的来信，只换来了冷冰冰的沉默。';
      case '冷漠':
      case '中立':
        return '几天后，一只猫头鹰送来${name}的回信，措辞礼貌而疏远：\n「来信收悉，谢谢。祝好。」';
      case '好感':
      case '友好':
        return '${name}的回信语气轻快：\n「收到你的信啦，很高兴。等我忙完这阵子，我们在礼堂一起喝杯南瓜汁吧。」';
      case '信任':
      case '亲密':
        return '${name}的回信写得很长，字里行间透着真诚与信任，末了还留了一句：「有什么心事，随时告诉我。」';
      case '深爱':
      case '灵魂伴侣':
        return '${name}的回信字迹微微颤抖，情意几乎溢出纸面：「你的信我读了一遍又一遍……等见面时，我有话想亲口对你说。」';
      default:
        return '几天后，${name}简短地回了信。';
    }
  }

  String formatBloodRelatives() {
    if (player!.bloodRelatives.isEmpty) {
      return '【血缘】\n未设定血缘亲属关系。三代内血亲不可攻略（除非开启骨科模式）。';
    }
    return '【血缘】\n${player!.bloodRelatives.join('、')}\n${player!.boneMode ? '（骨科模式已开启，禁忌限制解除）' : '（三代内血亲不可攻略）'}';
  }

  /// 月度世界演化报告（第47章）

  String formatWorldEvolution() {
    final w = worldState;
    final eraName = eraLabel(appProvider.era);
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《月度世界演化报告》')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln('【当前时代】$eraName')
      ..writeln('【时间】${w.timestamp}')
      ..writeln('【学年】${w.academicYear}')
      ..writeln()
      ..writeln('【九大文明支柱状态】');
    for (int i = 0; i < kCivilizationPillars.length; i++) {
      buf.writeln('  ${i + 1}. ${kCivilizationPillars[i]}');
    }
    buf
      ..writeln()
      ..writeln('【世界五层结构】');
    for (final layer in kWorldLayers) {
      buf.writeln('  $layer');
    }
    buf
      ..writeln()
      ..writeln('【区域危险度】');
    for (final zone in kDangerZones) {
      buf.writeln('  $zone');
    }
    buf
      ..writeln()
      ..writeln('【货币体系】$kCurrencyRate')
      ..writeln()
      ..writeln('【当前地点】${w.currentLocation ?? '未知'}')
      ..writeln('【天气】${w.weather ?? '晴朗'}')
      ..writeln()
      ..writeln('【近期世界事件】')
      ..writeln(w.recentEvents.isEmpty ? '暂无记录' : w.recentEvents.map((e) => '· ${e.text}').join('\n'))
      ..writeln()
      ..writeln('【世界线变动率】${(player?.worldLineDeviation ?? 0) * 100}%')
      ..writeln()
      ..writeln('【终极原则】');
    for (final principle in kUltimatePrinciples) {
      buf.writeln('  $principle');
    }
    return buf.toString();
  }

  String formatAffections({int maxEntries = 8}) {
    final list = player == null
        ? const <NPC>[]
        : npcRegistry.values
            .where((n) => n.introduced && (n.affection.abs() >= 30 || player!.relationships.containsKey(n.id)))
            .toList()
          ..sort((a, b) => b.affection.compareTo(a.affection));
    if (list.isEmpty) return '暂无深入关系';
    final entries = list.take(maxEntries).map((n) => '${n.name}(${n.affection})').join('、');
    if (list.length > maxEntries) return '$entries 等${list.length}人';
    return entries;
  }

  // ==================== NPC 主动表白机制 ====================

  /// 恋爱链路接线：记录一次浪漫事件（表白机制要求暧昧期≥2次浪漫事件）。
  /// 只记录发生在暧昧/亲密阶段或已确定恋爱关系中的互动，纯友情不算。
  void recordRomanticEventFor(NPC npc) {
    final p = player;
    if (p == null) return;
    final love = p.loveState;
    final stage = love.stageFor(npc.name);
    if (love.status == '恋爱' && love.partnerId == npc.id) {
      love.recordRomanticEvent(npc.name);
      return;
    }
    if (stage == '暧昧' || stage == '亲密') {
      love.recordRomanticEvent(npc.name);
      worldState.addNarrativeEvent('💗 你和${npc.name}之间多了一段心动回忆。', turn: turnCount);
    }
  }

  void checkNPCConfessions() {
    final p = player;
    if (p == null || p.loveState.status != '单身') return;
    if (p.loveState.awaitingConfession) return;

    for (final n in npcRegistry.values) {
      n.isConsideringConfession = false;
    }

    // 融合版条件：好感≥85 + 关系阶段为"暧昧" + 浪漫事件≥2次 + 持续≥2周
    // 使用 absoluteDayIndex（跨年单调递增），避免 dayOfYear 跨年相减为负
    final currentDay = worldState.time.absoluteDayIndex;
    final candidates = npcRegistry.values.where((n) {
      if (!n.isAlive || n.affection < Balance.confessionMinAffection || n.confessed) return false;
      // 取向双向校验：NPC 喜欢玩家性别 且 玩家喜欢 NPC 性别（详见 NPC.orientationMatches）
      if (!NPC.orientationMatches(
        npcGender: n.gender,
        npcOrientation: n.sexOrientation,
        playerGender: p.gender,
        playerOrientation: p.sexOrientation,
      )) {
        return false;
      }
      // 检查关系阶段
      final stage = p.loveState.stageFor(n.name);
      if (stage != '暧昧' && stage != '亲密') return false;
      // 检查浪漫事件计数
      if (p.loveState.romanticEventsFor(n.name) < Balance.confessionMinRomanticEvents) return false;
      // 检查暧昧持续时间
      if (p.loveState.currentCrushName == n.name && !p.loveState.isCrushMature(currentDay)) {
        return false;
      }
      return true;
    }).toList();

    if (candidates.isEmpty) return;

    // 融合版：概率触发（基础20% + 条件达标加成）
    double triggerProb = Balance.confessionBaseProbability;
    // 好感超过90%时概率增加
    for (final c in candidates) {
      if (c.affection >= Balance.confessionHighAffectionThreshold) {
        triggerProb += Balance.confessionHighAffectionBonus;
      }
    }
    triggerProb = triggerProb.clamp(0.0, Balance.confessionMaxProbability);

    if (random.nextDouble() > triggerProb) {
      // 标记"正在考虑"
      final npc = candidates[random.nextInt(candidates.length)];
      npc.isConsideringConfession = true;
      return;
    }

    // 选择好感最高的候选者（更合理的表白对象）
    candidates.sort((a, b) => b.affection.compareTo(a.affection));
    final npc = candidates.first;
    npc.isConsideringConfession = true;
    npc.isAlive = true;

    final originalNarrative = currentNarrative;
    currentNarrative =
        (originalNarrative.isEmpty ? '' : '$originalNarrative\n\n') +
            _buildConfessionNarrative(npc, p);
    choices = [
      GameChoice(text: '接受这份心意', action: '接受${npc.name}的表白'),
      GameChoice(text: '婉拒，但保持朋友关系', action: '婉拒${npc.name}，希望保持朋友关系'),
    ];
    p.loveState.awaitingConfession = true;
    p.loveState.consideringNpcName = npc.name;
  }

  /// 融合版表白叙事：根据NPC人格生成不同风格

  String _buildConfessionNarrative(NPC npc, Player p) {
    final personality = npc.personality;
    final traits = personality.join('');

    // 根据NPC特质选择表白风格
    if (traits.contains('勇敢') || traits.contains('直率')) {
      return '${npc.name}鼓起勇气走到你面前，眼睛里闪烁着坚定的光。\n\n'
          '"${p.name}，我有件事藏在心里很久了。" 他/她深吸一口气，\n'
          '"我喜欢你。不是一时兴起，是真的想和你在一起。"\n\n'
          '走廊里的烛光轻轻摇曳，你的心跳似乎漏了一拍。';
    } else if (traits.contains('理性') || traits.contains('聪明')) {
      return '${npc.name}似乎经过了一番深思熟虑才找到你。\n\n'
          '"${p.name}，我一直在想，该怎么说这件事才合适。" 他/她的声音平稳，\n'
          '"经过这么久的相处，我确定——我想和你在一起。不是因为冲动，而是因为我想认真地走下去。"\n\n'
          '理性的话语下，是一颗同样在跳动的心。';
    } else if (traits.contains('害羞') || traits.contains('内向')) {
      return '${npc.name}的脸涨得通红，低着头不敢看你。\n\n'
          '"${p.name}…我…" 他/她的声音很小，几乎被风声盖过，\n'
          '"我喜欢你…可以吗？"\n\n'
          '月光下，${npc.name}的耳朵尖都红了，你第一次发现原来害羞的人表白时这么可爱。';
    } else {
      return '${npc.name}站在你面前，深深地吸了一口气。\n\n'
          '"${p.name}，有件事我想让你知道。" 他/她的眼神认真而温柔，\n'
          '"我喜欢你。如果你愿意，我想和你一起走下去。"\n\n'
          '夜风拂过，一切仿佛都在等待你的回答。';
    }
  }

  /// 处理表白回应

  void resolveConfession(bool accepted, String npcName) {
    final p = player;
    if (p == null) return;
    late final NPC npc;
    try {
      npc = npcRegistry.values.firstWhere((n) => n.name == npcName);
    } catch (_) {
      try {
        npc = npcRegistry.values.firstWhere(
          (n) => n.name.contains(npcName) || npcName.contains(n.name),
        );
      } catch (_) {
        return;
      }
    }
    npc.confessed = true;
    npc.isConsideringConfession = false;
    p.loveState.awaitingConfession = false;
    p.loveState.consideringNpcName = null;

    if (accepted) {
      p.loveState.status = '恋爱';
      p.loveState.partnerId = npc.id;
      p.loveState.partnerName = npc.name;
      p.loveState.history.add({
        'date': worldState.timestamp,
        'event': '接受了${npc.name}的表白',
      });
      unlockCG(cgById('CG-010'));
      unlockCG(cgById('CG-CF-001'));
      if (p.boneMode) unlockCG(cgById('CG-BONE-002'));
      unlockAchievement('first_confession');
      unlockAchievement('in_love');
      notifications.add('💕 你与${npc.name}开始了恋爱！');
      worldState.addNarrativeEvent('💕 你与${npc.name}开始了恋爱！', turn: turnCount);
      _addRumor('你与${npc.name}正在交往的消息，像野火一样传遍了霍格沃茨。');
      bumpImpactScore(npc.isCanon ? 0.08 : 0.04, debugReason: '接受${npc.name}表白${npc.isCanon?'(原著NPC)':''}');
      currentNarrative =
          '你点了点头，${npc.name}的眼睛瞬间亮了起来，像被月光点亮。\n\n'
          '他/她握住你的手，声音里带着掩饰不住的喜悦："真的吗？太好了……"\n\n'
          '你们在月色下相视而笑，霍格沃茨的钟声在远处敲响，仿佛在为这段感情祝福。';
    } else {
      npc.affection -= 5;
      unlockCG(cgById('CG-CF-002'));
      _addRumor('听说${npc.name}向你表白，却被你拒绝了。');
      bumpImpactScore(npc.isCanon ? 0.03 : 0.015, debugReason: '婉拒${npc.name}表白');
      currentNarrative =
          '你温和地摇了摇头。${npc.name}的眼神黯淡了一下，但很快挤出一个微笑。\n\n'
          '"我明白了……那我们，还是朋友吧？"\n\n'
          '他/她松开手，向你露出一个勉强却真心的笑容。月光依旧明亮，只是空气里多了一丝惆怅。';
    }
    choices = [GameChoice(text: '继续', action: '继续')];
  }
  // ==================== 时间格式化 ====================

  String _formatDate() {
    final t = worldState.time;
    final year = t.year;
    final months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
    final month = (t.month >= 1 && t.month <= 12) ? months[t.month - 1] : '${t.month}月';
    final day = worldState.dayOfMonth;
    final weekday = worldState.dayOfWeek;
    final hour = t.hour.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    return '📅 $year年$month$day日，$weekday，[$hour:$minute]';
  }


  // ==================== CG 解锁 ====================

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

  void unlockAchievement(String id) {
    final p = player;
    if (p == null) return;
    if (p.achievements.contains(id)) return;
    final ach = achievementCatalog.firstWhere(
      (a) => a.id == id,
      orElse: () => Achievement(id: id, name: id, description: ''),
    );
    p.achievements.add(id);
    notifications.add('🏆 解锁成就：${ach.name}');
    worldState.addNarrativeEvent('🏆 解锁成就：${ach.name}', turn: turnCount);
  }

  void checkAffectionAchievements(NPC npc) {
    if (npc.affection >= 20) {
      unlockAchievement('first_friend');
    }
    checkCGUnlockByEvaluator(npc);
  }

  /// R5：好感→CG 解锁统一入口（由 CgUnlockEvaluator 做数据驱动判定）
  /// 旧实现：20+ 条 if 硬编码散在 `_checkCGUnlockByAffection` 里；
  /// 新实现：新增 CG = 加 1 条 CgUnlockCondition，零代码改动。
  void checkCGUnlockByEvaluator(NPC npc) {
    final p = player;
    if (p == null) return;
    final aff = npc.affection;
    final isCrush = p.loveState.currentCrushName == npc.name;
    final isPartner = p.loveState.partnerId == npc.id;

    final cgIds = CgUnlockEvaluator.allSatisfiedIds(
      npcAffection: aff,
      npcIsCrush: isCrush,
      npcIsPartner: isPartner,
      npcConfessed: npc.confessed,
      boneMode: p.boneMode,
    );
    for (final cgId in cgIds) {
      unlockCG(cgById(cgId));
    }
  }

  void checkSkillAchievements() {
    final p = player;
    if (p == null) return;
    for (final s in p.learnedSpells.values) {
      if (s.level >= 90) {
        unlockAchievement('honor_student');
        return;
      }
    }
  }

  void checkWorldChangerAchievement() {
    final p = player;
    if (p == null) return;
    // 双条件判据：玩家影响力(>=0.5) 与 世界线偏移(>=0.1) 同时满足才解锁
    // 防止只靠时间堆积或只改一条剧情线就拿成就——需要真正从 NPC 关系/原著事件/关键锚点三路都撼动世界
    if (p.worldLineDeviation >= 0.1 && worldState.playerImpactScore >= 0.5) {
      unlockAchievement('world_changer');
    }
  }

  void checkWarHeroAchievement() {
    final p = player;
    if (p == null) return;
    final combat = p.playerReputation.get('combat');
    if (combat >= 80) {
      unlockAchievement('war_hero');
    }
  }

  void _checkExplorerAchievement() {
    final p = player;
    if (p == null) return;
    // 记录当前地点到访问历史（若不同）
    final loc = worldState.currentLocation?.trim();
    if (loc != null && loc.isNotEmpty) {
      worldState.visitedLocations.add(loc);
    }
    if (worldState.visitedLocations.length >= 5) unlockAchievement('explorer');
  }

  void _checkRichWizardAchievement() {
    final p = player;
    if (p == null) return;
    // 小富翁=累计持有 ≥1500 加隆（player.dart默认500+节俭特质+100=约600开局）
    // 原门槛100完全无意义，500还是开局秒解——1500要求玩家通过打工/交易真正积累财富。
    if (totalWealth >= 1500) unlockAchievement('rich_wizard');
  }

  void _checkBookwormAchievement() {
    final p = player;
    if (p == null) return;
    if (p.learnedSpells.length >= 10) unlockAchievement('bookworm');
  }

  void _checkSocialButterflyAchievement() {
    final p = player;
    if (p == null) return;
    // 社交蝴蝶=真正结识过的NPC ≥ 10 位（introduced=true，必须剧情中正式见面/产生过互动）
    // 不再用"NPC总数≥10"——NPC注册表初始化就有几十个，开局秒解锁是bug。
    final friendCount = npcRegistry.values.where((n) => n.isAlive && n.introduced).length;
    if (friendCount >= 10) unlockAchievement('social_butterfly');
  }

  void _checkDeepRelationshipAchievement() {
    for (final npc in npcRegistry.values) {
      if (npc.affection >= 80) {
        unlockAchievement('deep_relationship');
        return;
      }
    }
  }

  void _checkBetrayalSurvivorAchievement() {
    for (final npc in npcRegistry.values) {
      if (npc.hasGrudge && npc.affection > npc.maxAffectionReached * 0.8) {
        unlockAchievement('betrayal_survivor');
        return;
      }
    }
  }

  void _checkMonthlyEvolutionAchievement() {
    if (worldState.recentEvents.where((e) => e.text.contains('月度世界演化')).length >= 3) {
      unlockAchievement('monthly_evolution');
    }
  }

  void _checkGenerationArtistAchievement() {
    final count = npcRegistry.values.where((n) => n.isGenerated).length;
    if (count >= 5) unlockAchievement('generation_artist');
  }

  void _checkCGCollectorAchievement() {
    final p = player;
    if (p == null) return;
    if (p.cgRecords.length >= 10) unlockAchievement('cg_collector');
  }

  void _checkRelationshipMasterAchievement() {
    final highAffectionCount = npcRegistry.values
        .where((n) => n.affection >= 60)
        .length;
    if (highAffectionCount >= 3) unlockAchievement('relationship_master');
  }

  void _checkTimeMasterAchievement() {
    // 修复：起始年份必须取自当前时代的 EraDef，不能硬编码 1991。
    // 旧实现导致 1892 时代永远无法解锁（年份差为负）、2020 时代开局即解锁。
    final startYear = eraDefByEra(appProvider.era).startYear;
    final currentYear = worldState.time.year;
    if (currentYear - startYear >= 2) unlockAchievement('time_master');
  }

  void checkAllAchievements() {
    checkSkillAchievements();
    checkWorldChangerAchievement();
    checkWarHeroAchievement();
    _checkExplorerAchievement();
    _checkRichWizardAchievement();
    _checkBookwormAchievement();
    _checkSocialButterflyAchievement();
    _checkDeepRelationshipAchievement();
    _checkBetrayalSurvivorAchievement();
    _checkMonthlyEvolutionAchievement();
    _checkGenerationArtistAchievement();
    _checkCGCollectorAchievement();
    _checkRelationshipMasterAchievement();
    _checkTimeMasterAchievement();
  }

  void incrementWorldLineDeviation(double delta) {
    final p = player;
    if (p == null) return;
    p.worldLineDeviation = (p.worldLineDeviation + delta).clamp(0.0, 1.0);
    checkWorldChangerAchievement();
  }

  // ==================== 时间推进 ====================

  void adjustAffection(String npcId, int delta, {String? reason}) {
    updateNpcAffection(npcId, delta, reason: reason);
    final npc = npcRegistry[npcId];
    if (npc != null) {
      checkLocks(npc);
      syncRelationshipLevel(npc);
    }
  }

  void syncRelationshipLevel(NPC npc) {
    final p = player;
    if (p == null) return;
    final rel = p.relationships[npc.id];
    if (rel != null) {
      rel.level = npc.affection.clamp(0, 100);
    }
  }

  // ==================== DeepSeek 调用 ====================
}
