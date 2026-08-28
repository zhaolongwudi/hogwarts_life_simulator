import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/item_data.dart';
import '../data/bestiary_data.dart';
import '../data/quest_data.dart';
import '../data/pet_data.dart';
import '../data/pet_narrative_config.dart';
import '../models/player.dart';
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../models/long_term_memory.dart';
import '../providers/game_provider_base.dart';

/// 新玩法 Mixin（v1.10）：物品使用 / 宠物互动 / 装备穿戴 / 魁地奇 / 决斗 /
/// 禁林探险 / 魔法生物图鉴 / 支线委托板 / 学院杯积分。
/// 全部本地判定、零 token 消耗，叙事结果走 currentNarrative + choices 通道。
mixin GamePlayMixin on GameProviderBase {
  /// 已被击败过的 NPC id（打赢只加一次好感，避免反复刷同一个对手）
  final Set<String> _duelBeatenNpcIds = {};

  // ==================== 通用工具 ====================

  void _finishLocal(String narrative) {
    currentNarrative = narrative;
    choices = [GameChoice(text: '返回', action: '继续')];
    notifyListeners();
    unawaited(autoSave());
  }

  bool _hasItem(String name) =>
      (player?.inventory ?? []).any((e) => e.name == name);

  void _removeItem(String name) {
    final inv = player?.inventory;
    if (inv == null) return;
    final idx = inv.indexWhere((e) => e.name == name);
    if (idx >= 0) inv.removeAt(idx);
  }

  void _addItem(String name, {String? type, String? desc}) {
    final def = itemDefByName(name);
    player!.inventory.add(InventoryItem(
      id: def?.id ?? name,
      name: name,
      type: type ?? def?.type ?? 'item',
      description: desc ?? def?.desc ?? '',
    ));
  }

  /// 获得一件物品并自动推进 gather 类委托
  void _gainItem(String name) {
    _addItem(name);
    _progressQuest('gather', name, 1);
  }

  int _attr(String key) => (player?.attributes[key]) ?? 50;

  int _equipmentCombatBonus() {
    final p = player;
    if (p == null) return 0;
    int sum = 0;
    p.equipped.forEach((slot, name) {
      final def = itemDefByName(name);
      if (def != null) sum += def.combatBonus;
    });
    return sum;
  }

  int _equipmentCastBonus() {
    final p = player;
    if (p == null) return 0;
    int sum = 0;
    p.equipped.forEach((slot, name) {
      final def = itemDefByName(name);
      if (def != null) sum += def.castBonus;
    });
    return sum;
  }

  /// 决斗战力：技能熟练度均值 + 装备加成 + 宠物助战（羁绊≥40）
  double _playerPower() {
    final p = player!;
    final base = (_attr('dda') + _attr('spell_understanding') + _attr('magic_control')) / 3;
    var power = base + _equipmentCombatBonus();
    if (p.petBond >= 40) power += 3;
    return power;
  }

  void _progressQuest(String type, String target, int amount) {
    final qs = player?.quests;
    if (qs == null) return;
    for (final q in qs) {
      if (q.status != 'active' || q.type != type || q.target != target) continue;
      q.progress = (q.progress + amount).clamp(0, q.targetCount);
      if (q.isDone) {
        q.status = 'completed';
        notifications.add('📜 委托完成：${q.title}（/委托 交付 领取奖励）');
      }
    }
  }

  // ==================== 1. 物品使用 ====================

  String formatItemUseHelp() {
    final p = player;
    final usable = usableItems();
    final buf = StringBuffer()
      ..writeln('【物品使用】')
      ..writeln('输入 /使用 <物品名> 消耗背包中的物品。可使用的物品：');
    if (p == null || p.inventory.isEmpty) {
      buf.writeln('（背包空空如也，去对角巷逛逛吧）');
      return buf.toString();
    }
    final owned = <String, int>{};
    for (final e in p.inventory) {
      owned[e.name] = (owned[e.name] ?? 0) + 1;
    }
    var hasUsable = false;
    for (final def in usable) {
      final count = owned[def.name] ?? 0;
      final mark = count > 0 ? '✅ x$count' : '（未持有）';
      buf.writeln('· ${def.name} $mark — ${def.desc}');
      if (count > 0) hasUsable = true;
    }
    if (!hasUsable) buf.writeln('（你尚未持有任何可使用的物品）');
    buf.writeln('装备类物品请使用 /装备，见 /状态 下装备栏。');
    return buf.toString();
  }

  void useItem(String name) {
    final p = player;
    if (p == null) return;
    final def = itemDefByName(name);
    if (def == null || !def.usable) {
      _finishLocal('「$name」无法使用。\n\n${formatItemUseHelp()}');
      return;
    }
    if (!_hasItem(name)) {
      _finishLocal('你的背包里没有「$name」。\n\n${formatItemUseHelp()}');
      return;
    }

    final effects = def.effect;
    final buf = StringBuffer();
    buf.writeln('【使用 · $name】\n');

    // 比比多味豆：随机效果（含彩蛋毒豆）
    if (effects.containsKey('special')) {
      const flavors = [
        ('草莓味，甜得眯起眼睛。', {'satiety': 10}),
        ('青草味，有点像刚从草坪上薅下来的。', {'satiety': 6}),
        ('耳屎味！你干呕了一下。', {'health': -3, 'satiety': 5}),
        ('鼻涕虫味，冰凉黏滑。', {'spirit': -2}),
        ('神奇地是黄油啤酒味。', {'satiety': 8, 'spirit': 4}),
      ];
      final picked = flavors[random.nextInt(flavors.length)];
      buf.writeln('你丢了一颗进嘴里——${picked.$1}');
      _applyEffects(p, picked.$2, buf);
      _removeItem(name);
      _finishLocal(buf.toString());
      return;
    }

    // 标准咒语书：提升魔咒理解，未学咒时自动学会漂浮咒
    if (effects.containsKey('learn_spell')) {
      if (p.learnedSpells.isEmpty) {
        p.learnedSpells['漂浮咒'] = SpellLevel(spellName: '漂浮咒', level: 1, practiceCount: 1);
        buf.writeln('你翻开《标准咒语书》，第一次学会了「漂浮咒」！');
      } else {
        buf.writeln('你温习了《标准咒语书》，许多细节豁然开朗。');
      }
    }

    buf.writeln('你把「$name」${_useActionVerb(name)}。');
    _applyEffects(p, effects, buf);
    _removeItem(name);
    _finishLocal(buf.toString());
  }

  String _useActionVerb(String name) {
    final def = itemDefByName(name);
    if (def == null) return '处理了一下';
    switch (def.type) {
      case '食品':
        return '吃（喝）了下去';
      case '药水':
        return '一饮而尽';
      case '书籍':
        return '研读了一遍';
      default:
        return '使用了一下';
    }
  }

  void _applyEffects(Player p, Map<String, int> effects, StringBuffer buf) {
    if (effects.isEmpty) return;
    final changes = <String>[];
    effects.forEach((key, value) {
      if (value == 0) return;
      switch (key) {
        case 'health':
          p.health = (p.health + value).clamp(0, 100);
          changes.add('生命 ${value > 0 ? '+' : ''}$value');
          break;
        case 'magic':
          p.magic = (p.magic + value).clamp(0, 100);
          changes.add('魔力 ${value > 0 ? '+' : ''}$value');
          break;
        case 'spirit':
          p.spirit = (p.spirit + value).clamp(0, 100);
          changes.add('精神力 ${value > 0 ? '+' : ''}$value');
          break;
        case 'satiety':
          p.satiety = (p.satiety + value).clamp(0, 100);
          changes.add('饱食度 ${value > 0 ? '+' : ''}$value');
          break;
        case 'energy':
          p.energy = (p.energy + value).clamp(0, 100);
          changes.add('精力 ${value > 0 ? '+' : ''}$value');
          break;
        default:
          // 只认真正的属性键。effect map 里混有控制标记：
          //   'learn_spell'（学咒）— 已在 useItem 里单独处理
          //   'special'（随机口味）— 已走随机分支早退
          // 若落到这里会被当成属性写进存档，产生 attributes['learn_spell']=51
          // 这类垃圾键，还会被一致性检查当成合法属性钳制。
          if (!Player.isAttributeKey(key)) {
            debugPrint('⚠️ 物品效果含非属性 key「$key」，已忽略（控制标记或拼写错误）');
            return;
          }
          p.attributes[key] = ((p.attributes[key] ?? 50) + value).clamp(0, 100);
          changes.add('${_attrLabelZh(key)} ${value > 0 ? '+' : ''}$value');
      }
    });
    if (changes.isNotEmpty) {
      buf.writeln('\n效果：${changes.join(' · ')}');
    }
  }

  String _attrLabelZh(String key) {
    const map = {
      'spell_understanding': '魔咒理解',
      'transfiguration': '变形术',
      'potions': '魔药学',
      'herbology': '草药学',
      'dda': '黑魔法防御',
      'flying': '飞行',
      'magic_control': '魔力控制',
      'reaction_time': '反应速度',
      'observation': '洞察力',
    };
    return map[key] ?? key;
  }

  // ==================== 2. 宠物互动 ====================

  void petInteract(String action) {
    final p = player;
    if (p == null) return;
    if (p.petId == null && p.petName == null) {
      _finishLocal('你还没有宠物，无法互动。可以去对角巷挑选一只猫头鹰、猫或蟾蜍。');
      return;
    }
    final def = p.petId != null ? petById(p.petId!) : null;
    final petName = (p.petName != null && p.petName!.isNotEmpty) ? p.petName! : (def?.name ?? '宠物');
    final day = worldState.time.absoluteDayIndex;
    final buf = StringBuffer('【宠物互动 · $petName】\n');

    if (action == '喂食' || action == '喂' || action == '食物') {
      if (p.petLastFedDay == day) {
        _finishLocal('$petName 今天已经吃饱喝足，肚皮圆滚滚地直打瞌睡，明天再喂吧。');
        return;
      }
      p.petLastFedDay = day;
      final gain = 2 + random.nextInt(3); // +2~+4
      p.petBond = (p.petBond + gain).clamp(0, 100);
      buf.writeln('你拿出准备好的食物，$petName 立刻凑了上来，温热的小脑袋在你手心里蹭了又蹭。');
      buf.writeln('\n羁绊 +$gain（当前 ${p.petBond}/100）');
    } else if (action == '玩耍' || action == '玩') {
      if (p.petInteractDay == day) {
        _finishLocal('$petName 今天已经陪你玩过、练过，现在只想赖在窝里休息。明天再来吧。');
        return;
      }
      p.petInteractDay = day;
      p.energy = (p.energy - 5).clamp(0, 100);
      final gain = 1 + random.nextInt(3); // +1~+3
      p.petBond = (p.petBond + gain).clamp(0, 100);
      buf.writeln('你陪$petName 在草地上追逐打闹，它银铃般的小动作把你的疲惫都冲淡了几分。');
      buf.writeln('\n羁绊 +$gain（当前 ${p.petBond}/100）');
    } else if (action == '训练' || action == '练') {
      if (p.petInteractDay == day) {
        _finishLocal('$petName 今天已经累坏了，训练只能等明天。');
        return;
      }
      p.petInteractDay = day;
      final success = random.nextInt(100) < 65;
      final gain = success ? 1 + random.nextInt(2) : 1;
      p.petBond = (p.petBond + gain).clamp(0, 100);
      if (success) {
        const pool = ['observation', 'reaction_time', 'flying', 'intuition'];
        final skill = pool[random.nextInt(pool.length)];
        p.attributes[skill] = ((p.attributes[skill] ?? 50) + 1).clamp(0, 100);
        buf.writeln('你引导$petName 完成了几组指令，它领悟得飞快，尾巴都得意地翘了起来。');
        buf.writeln('\n羁绊 +$gain（当前 ${p.petBond}/100），${_attrLabelZh(skill)} +1');
      } else {
        buf.writeln('今天的训练不太顺利，$petName 总是被旁边的动静分心。不过关系也算拉近了一些。');
        buf.writeln('\n羁绊 +$gain（当前 ${p.petBond}/100）');
      }
    } else {
      _finishLocal('宠物互动指令：/宠物 喂食 ｜ /宠物 玩耍 ｜ /宠物 训练\n\n'
          '喂食每日一次，玩耍/训练每日共一次。羁绊提升后宠物能提供更多帮助。');
      return;
    }

    // R8：化人形事件（一次性，由 PetNarrativeConfig 统一判定门槛 + 是否开启化形）
    // 旧实现：petId == 'kyuubi' && petBond >= 60 硬编码特判；
    // 新实现：新增"会化形的特殊宠物"只改 PetNarrativeConfig 数据，不改 mixin。
    final petCfg = petNarrativeConfig(p.petId ?? '');
    if (!p.petTransformDone &&
        petCfg.bondGatedTransform &&
        p.petBond >= petCfg.specialInteractionBondThreshold) {
      p.petTransformDone = true;
      final species = petById(p.petId ?? '')?.species ?? '神奇生物';
      final hint = petCfg.specialInteractionHint ?? '化为与主角同龄的人形陪伴左右。';
      buf.writeln('\n—— 一道柔和的光晕忽然从$petName 身上漾开，它的身影在光芒中缓缓拔高，'
          '幻化作一个与你年纪相仿的少男/少女。绯色光晕笼罩周身，它/他静静看着你，轻声唤出你的名字。\n\n'
          '【羁绊已达】${species}$petName：$hint');
      // 修复：化形只是为宠物新增一条关系，绝不能清空玩家与所有 NPC 的既有关系
      final petRelId = p.petId ?? petName;
      p.relationships[petRelId] = Relationship(
        targetId: petRelId,
        targetName: petName,
        relationType: '化形羁绊',
        level: 60,
      );
      notifications.add('✨ $petName 展现了新的形态：羁绊的奇迹在你眼前展开');
    }

    // 羁绊成就 + pet 类委托进度
    if (p.petBond >= 50) unlockAchievement('pet_bond_50');
    for (final q in p.quests) {
      if (q.status == 'active' && q.type == 'pet') {
        q.progress = q.progress < p.petBond ? p.petBond : q.progress;
        if (q.progress > q.targetCount) q.progress = q.targetCount;
        if (q.isDone && q.status == 'active') {
          q.status = 'completed';
          notifications.add('📜 委托完成：${q.title}（/委托 交付 领取奖励）');
        }
      }
    }
    _finishLocal(buf.toString());
  }

  // ==================== 3. 装备穿戴 ====================

  String formatEquip() {
    final p = player;
    if (p == null) return '';
    const slots = [
      ('robe', '袍子'),
      ('hat', '帽子'),
      ('broom', '扫帚'),
      ('amulet', '饰品'),
    ];
    final buf = StringBuffer()
      ..writeln('【装备栏】')
      ..writeln('输入 /装备 <物品名> 穿戴，/卸下 <部位> 脱下。');
    for (final s in slots) {
      final name = p.equipped[s.$1];
      buf.writeln('${s.$2}：${name ?? '（空）'}');
    }
    final cb = _equipmentCombatBonus();
    final cast = _equipmentCastBonus();
    buf.writeln('\n当前加成：战斗 +$cb ｜ 施法成功率 +${(cast / 10).toStringAsFixed(1)}%');
    final items = equippableItems();
    buf.writeln('\n【可穿戴装备】');
    for (final it in items) {
      final owned = _hasItem(it.name) ? '✅' : ' ';
      buf.writeln('$owned ${it.name}（$priceLabel(it.price) 加隆，${slotLabel(it.equipSlot!)}）— ${it.desc}');
    }
    buf.writeln('\n装备在 /决斗 提供战力加成，施法成功率的提升来自装备的 castBonus。');
    return buf.toString();
  }

  String slotLabel(String slot) => switch (slot) {
        'robe' => '袍子',
        'hat' => '帽子',
        'broom' => '扫帚',
        'amulet' => '饰品',
        _ => '装备',
      };

  String priceLabel(int p) => p >= 0 ? p.toString() : '';

  void equipItem(String name) {
    final p = player;
    if (p == null) return;
    final def = itemDefByName(name);
    if (def == null || !def.isEquippable) {
      _finishLocal('「$name」不是可穿戴的装备。输入 /装备 查看可穿戴列表。');
      return;
    }
    if (!_hasItem(name)) {
      _finishLocal('你的背包里没有「$name」，需要先去对角巷购买。');
      return;
    }
    final slot = def.equipSlot!;
    final old = p.equipped[slot];

    // 装备实体从背包移入装备栏（否则它同时存在于两处：
    // 玩家可以把它卖掉，而装备栏仍留着名字 → 继续白嫖属性/施法加成）。
    _removeItem(name);
    p.equipped[slot] = name;

    final buf = StringBuffer('【穿戴 · $name】\n');
    if (old != null && old != name) {
      buf.writeln('你换下了原来的${slotLabel(slot)}「$old」，穿上了「$name」。');
      // 换下的旧装备回到背包（旧存档里它可能仍在背包中，避免重复添加）
      if (!_hasItem(old)) _addItem(old);
    } else {
      buf.writeln('你装备上了「$name」（${slotLabel(slot)}）。');
    }
    if (def.statBonus.isNotEmpty) {
      buf.writeln('\n属性加成：${def.statBonus.entries.map((e) => '${_attrLabelZh(e.key)} +${e.value}').join(' · ')}');
    }
    if (def.combatBonus > 0) {
      buf.writeln('战斗加成：+${def.combatBonus}');
    }
    if (def.castBonus > 0) {
      buf.writeln('施法加成：+${(def.castBonus / 10).toStringAsFixed(1)}%');
    }
    if (p.equipped.length >= 2) unlockAchievement('well_equipped');
    _finishLocal(buf.toString());
  }

  void unequipItem(String slotOrName) {
    final p = player;
    if (p == null) return;
    String? slot = p.equipped.containsKey(slotOrName) ? slotOrName : null;
    if (slot == null) {
      for (final s in ['robe', 'hat', 'broom', 'amulet']) {
        if (slotLabel(s) == slotOrName || s == slotOrName) {
          slot = s;
          break;
        }
      }
    }
    if (slot == null) {
      _finishLocal('没有这个装备部位（袍子/帽子/扫帚/饰品）。输入 /装备 查看当前穿戴。');
      return;
    }
    final name = p.equipped.remove(slot);
    if (name == null) {
      _finishLocal('${slotLabel(slot)}本来就空着，没有可卸下的装备。');
      return;
    }
    // 装备实体回到背包（若背包里已有一件——比如旧存档——就不再重复添加）
    if (!_hasItem(name)) _addItem(name);
    _finishLocal('【卸下 · $name】\n你卸下了${slotLabel(slot)}「$name」，它回到你的背包里。');
  }

  // ==================== 4. 魁地奇 ====================

  String formatQuidditch() {
    final p = player;
    if (p == null) return '';
    final broom = p.equipped['broom'];
    final buf = StringBuffer()
      ..writeln('【魁地奇】')
      ..writeln('位置：${p.qPosition}')
      ..writeln('技巧：${p.qSkill}/100')
      ..writeln('战绩：${p.qWins}胜 / ${p.qMatches}场')
      ..writeln('扫帚：${broom ?? '（未装备）'}');
    if (broom == null) {
      buf.writeln('\n⚠️ 参加比赛需要先装备一把飞天扫帚（对角巷购买后 /装备）。');
    } else {
      buf.writeln('\n输入 /魁地奇 比赛 开始一场比赛（每周一次，消耗 2 小时）。');
      buf.writeln('输入 /魁地奇 位置 <找球手|追球手|守门员|击球手> 调整位置。');
    }
    buf.writeln('\n赢下一场为学院赢得 30 分学院杯积分，输球也有 5 分。');
    return buf.toString();
  }

  void setQuidditchPosition(String pos) {
    const positions = ['找球手', '追球手', '守门员', '击球手'];
    final p = player!;
    if (!positions.contains(pos)) {
      _finishLocal('位置可选：找球手/追球手/守门员/击球手。当前位置：${p.qPosition}');
      return;
    }
    p.qPosition = pos;
    _finishLocal('【位置调整】\n你在队内试训后被安排为「$pos」。训练中你不断调整握法，$pos 的职责逐渐得心应手。');
  }

  void playQuidditch() {
    final p = player;
    if (p == null) return;
    final broom = p.equipped['broom'];
    if (broom == null) {
      _finishLocal('你还没有飞天扫帚！对角巷的「飞天扫帚·横扫」或「飞天扫帚·彗星」可以购买，买到后 /装备 即可参赛。');
      return;
    }
    if (p.qLastWeek == gameWeek) {
      _finishLocal('本周你已经打过一场了，教练让你好好休息、加练技巧。下周再来吧。');
      return;
    }
    if (p.energy < 20) {
      _finishLocal('你的精力所剩无几（${p.energy}/100），扫帚都握不太稳，先休息一晚吧。');
      return;
    }

    p.qLastWeek = gameWeek;
    advanceTimeForAction('魁地奇比赛');
    p.energy = (p.energy - 20).clamp(0, 100);
    p.qMatches++;

    // 双方实力
    final skill = p.qSkill +
        ((_attr('flying') - 50) ~/ 3) +
        ((_attr('reaction_time') - 50) ~/ 5) +
        (itemDefByName(broom)?.statBonus['flying'] ?? 0);
    const opponents = ['格兰芬多', '斯莱特林', '拉文克劳', '赫奇帕奇'];
    final myHouseCn = switch (p.house) {
      'Gryffindor' => '格兰芬多',
      'Slytherin' => '斯莱特林',
      'Ravenclaw' => '拉文克劳',
      'Hufflepuff' => '赫奇帕奇',
      _ => '对手',
    };
    // 修复：对手池必须排除自己学院，避免"格兰芬多 对 格兰芬多"的荒谬叙事
    final pool = opponents.where((h) => h != myHouseCn).toList();
    final opp = pool[random.nextInt(pool.length)];
    final myScore = 90 + skill ~/ 2 + random.nextInt(31);
    final oppScore = 70 + random.nextInt(81); // 对手 ~70-150
    final win = myScore >= oppScore;

    p.qSkill = (p.qSkill + 1 + random.nextInt(2)).clamp(0, 100);
    final buf = StringBuffer('【魁地奇比赛 · $myHouseCn 对 $opp】\n');
    buf.writeln('哨声响起，$myHouseCn 队的${p.qPosition}——你，骑着$broom 冲上云霄。'
        '雨后的空气带着草屑和松脂味，金色飞贼在不远处闪烁。');
    final posDetail = switch (p.qPosition) {
      '找球手' => '你在球场上盘旋，目光锁定那颗疾驰的金色飞贼，一个俯冲……',
      '追球手' => '鬼飞球在你腋下稳稳夹住，你闪开两名对方击球手的防守，奋力掷向球门。',
      '守门员' => '你守在三个圆环前，紧盯游走球与鬼飞球的轨迹，飞身扑救。',
      _ => '你抡起球棒，狠狠把游走球抽向对方阵型。',
    };
    buf.writeln(posDetail);
    buf.writeln('\n最终比分：$myHouseCn $myScore — $oppScore $opp');

    if (win) {
      p.qWins++;
      p.playerReputation.add('combat', 6);
      p.playerReputation.add('social', 4);
      addHouseCupPoints(30, '魁地奇取胜');
      p.galleons += 15;
      buf.writeln('\n欢呼声如浪涌来，你为$myHouseCn 赢下了这一场！');
      buf.writeln('战斗声望 +6 · 社交声望 +4 · 学院杯积分 +30 · 队内奖金 15 加隆');
      unlockAchievement('first_quidditch_win');
    } else {
      addHouseCupPoints(5, '魁地奇惜败');
      p.galleons += 5;
      p.playerReputation.add('social', 2);
      buf.writeln('\n对方守住了最后的攻势，$myHouseCn 惜败。队友拍了拍你的肩：下周赢回来。');
      buf.writeln('虽败犹荣：社交声望 +2 · 学院杯积分 +5 · 辛苦费 5 加隆');
    }
    buf.writeln('\n魁地奇技巧 +1~2（当前 ${p.qSkill}）');
    _finishLocal(buf.toString());
  }

  // ==================== 5. 决斗 ====================

  void duelNpc(String? name) {
    final p = player;
    if (p == null) return;
    // 每日次数上限：旧实现无冷却，一场决斗只花 10 分钟 + 10 精力，
    // 赢了给 10~25 加隆 + 6~11 战斗声望 → 十几场就能把战斗声望刷满、
    // 加隆花不完，学院杯与声望系统全部失去意义。
    if (!this.canDoDaily('duel')) {
      _finishLocal(
          '你今天已经比了 ${this.dailyLimitOf('duel')} 场决斗，手臂酸得连魔杖都快握不住了。'
          '麦格教授远远瞥了你一眼——再打下去就要被请去喝茶了。\n\n'
          '明天再来吧。');
      return;
    }
    // 修复：决斗对象仅限在校生（grade >= 1），排除教职/成人（grade == 0）。
    // 旧实现只过滤 isAlive && !graduated，导致可以"决斗邓布利多/麦格教授"，
    // 违背"一年级打不过强者"的设计初衷与原著常识。
    final alive = npcRegistry.values
        .where((n) => n.isAlive && !n.graduated && n.grade >= 1)
        .toList();
    NPC? opponent;
    if (name != null && name.trim().isNotEmpty) {
      final kw = name.trim();
      for (final n in alive) {
        if (n.name.contains(kw)) {
          opponent = n;
          break;
        }
      }
      if (opponent == null) {
        _finishLocal('没有找到可以挑战的「$kw」。输入 /决斗 随机挑战，或输入认识的同学生名。');
        return;
      }
    } else {
      if (alive.isEmpty) {
        _finishLocal('眼前没有可以挑战的对象。');
        return;
      }
      opponent = alive[random.nextInt(alive.length)];
    }

    final oppPower = 30 +
        opponent.reputation.combat +
        opponent.grade * 3 +
        random.nextInt(25);

    // 防崩坏：一年级无法正面对抗明显强大的对手
    if ((p.grade ?? 1) <= 1 && oppPower >= 75) {
      _finishLocal(
          '你握着魔杖的手有些发冷——${opponent.name}的气场远远压过了你。'
          '一年级的新生正面对上这样的对手只有送人头的份。\n\n'
          '你决定把逃跑当成最明智的咒语。');
      return;
    }
    if (p.energy < 10) {
      _finishLocal('你太疲惫了（精力 ${p.energy}/100），连魔杖都举不太稳。改天再战吧。');
      return;
    }
    // 同一天里连续找同一个人决斗，对方也会烦（也防止刷好感）
    if (lastDuelOpponentId == opponent.id) {
      _finishLocal(
          '${opponent.name} 摆了摆手：「今天已经比过一场了，改天吧。」\n\n'
          '你收拾魔杖，决定换个对手，或者等明天。');
      return;
    }

    // 决斗按 60 分钟计（旧实现传的是'对话'，只推进 10 分钟）
    advanceTimeForAction('决斗');
    this.recordDailyActivity('duel');
    lastDuelOpponentId = opponent.id;
    p.energy = (p.energy - 10).clamp(0, 100);
    p.magic = (p.magic - 12).clamp(0, 100);

    // 施法成功率公式：熟练度 × 环境 × 心理 × 装备（简化本地判定）
    final mastery = (_attr('dda') + _attr('spell_understanding')) / 200;
    final env = 0.85 + random.nextDouble() * 0.3;
    final mental = (p.spirit / 100) * 0.5 + 0.5;
    final equipFactor = 1 + _equipmentCastBonus() / 1000.0;
    final castChance = (mastery * env * mental * equipFactor).clamp(0.05, 0.95);

    final myPower = _playerPower();
    final myScore = myPower * castChance + random.nextInt(16);
    final oppScore = oppPower * 0.6 + random.nextInt(21);
    final win = myScore >= oppScore;

    final buf = StringBuffer('【巫师决斗 · ${opponent.name}】\n');
    buf.writeln('你们在场地中央互相致礼，${opponent.name}的眼神带着一丝跃跃欲试。'
        '你握紧魔杖，心跳与咒语几乎同时升起。');
    if (castChance < 0.4) {
      buf.writeln('你的前两记咒语都偏得离谱——紧张让魔杖尖的光晕抖得像风里的烛火。');
    } else if (castChance >= 0.75) {
      buf.writeln('咒语一个接一个精准地飞出去，观战的同学发出压低了的惊叹。');
    } else {
      buf.writeln('施法有来有回，你稳住了节奏，寻找着对方的破绽。');
    }

    if (win) {
      p.health = (p.health - 5 - random.nextInt(6)).clamp(1, 100);
      // 当日第 N 场递减：越往后对手越有准备、观战的人越少，收益自然下降。
      // 旧实现每场收益恒定，一天刷十几场就能吃满所有成长曲线。
      final nth = this.dailyCountOf('duel'); // 已 recordDailyActivity，1 表示当天第一场
      final decay = nth <= 1 ? 1.0 : (nth == 2 ? 0.6 : 0.3);
      final repGain = ((6 + random.nextInt(6)) * decay).round().clamp(1, 11);
      final reward = ((10 + random.nextInt(16)) * decay).round().clamp(1, 25);
      p.playerReputation.add('combat', repGain);
      p.playerReputation.add('moral', 2);
      addHouseCupPoints((10 * decay).round().clamp(1, 10), '决斗获胜');
      p.galleons += reward;
      // 打赢对方会让人更服气，但只加一次：反复刷同一个人不该刷出满好感
      if (!_duelBeatenNpcIds.contains(opponent.id)) {
        _duelBeatenNpcIds.add(opponent.id);
        this.updateNpcAffection(opponent.id, 2, reason: '决斗获胜');
      }
      buf.writeln('\n最后一击命中！${opponent.name} 踉跄着抬起魔杖认输。');
      buf.writeln('胜利：战斗声望 +$repGain · 道德声望 +2 · 学院杯 +${(10 * decay).round().clamp(1, 10)} · 赌注 $reward 加隆');
      if (nth > 1) {
        buf.writeln('（今日第 $nth 场，对手已有准备，收获比第一场少）');
      }
      unlockAchievement('first_duel_win');
    } else {
      p.health = (p.health - 12 - random.nextInt(14)).clamp(1, 100);
      p.playerReputation.add('combat', 2 + random.nextInt(3));
      buf.writeln('\n你被${opponent.name}的咒语击中，好在只是擦伤。对方收杖向你点了点头。');
      buf.writeln('落败：战斗声望 +2~4 · 你受了些轻伤（生命 ${p.health}/100）');
    }
    _finishLocal(buf.toString());
  }

  // ==================== 6. 禁林探险 ====================

  void exploreForbiddenForest() {
    final p = player;
    if (p == null) return;
    if (p.energy < 15) {
      _finishLocal('你的精力所剩无几（${p.energy}/100）。禁林不是能空手而归的地方，先休息吧。');
      return;
    }
    if (p.satiety < 15) {
      _finishLocal('你饿得前胸贴后背（饱食度 ${p.satiety}/100），进禁林之前先吃点东西吧。');
      return;
    }
    // 每日次数上限：禁林是材料/生物图鉴的主要来源，不设限的话
    // 一个下午就能把图鉴刷满、材料堆成山，后期采集玩法直接失去意义。
    if (!this.canDoDaily('forest')) {
      _finishLocal(
          '海格远远朝你摆手：「今天进去 ${this.dailyLimitOf('forest')} 趟啦，林子也得喘口气。」\n\n'
          '天色确实不早了，明天再来吧。');
      return;
    }

    this.recordDailyActivity('forest');
    advanceTimeForAction('禁林探险');
    p.energy = (p.energy - 15).clamp(0, 100);
    p.satiety = (p.satiety - 5).clamp(0, 100);

    final grade = p.grade ?? 1;
    final rollValue = random.nextInt(100);
    final buf = StringBuffer('【禁林探险】\n');

    // 可遭遇生物：按年级限制危险度上限（防崩坏）
    final maxDanger = grade >= 5
        ? 5
        : grade >= 3
            ? 4
            : grade >= 2
                ? 3
                : 2;
    final pool = kCreatureCatalog
        .where((c) => c.danger <= maxDanger)
        .toList();

    if (rollValue < 30 && pool.isNotEmpty) {
      // 遭遇生物
      // 委托目标加成：活跃委托（gather 看掉落、defeat 看生物名）对应的生物
      // 获得额外权重，避免高价值委托因低危生物权重碾压而永远推不动。
      final wantedLoot = <String>{};
      final wantedCreatures = <String>{};
      for (final q in p.quests) {
        if (q.status != 'active') continue;
        if (q.type == 'gather') wantedLoot.add(q.target);
        if (q.type == 'defeat') wantedCreatures.add(q.target);
      }
      final weighted = <CreatureDef>[];
      for (final c in pool) {
        var w = (6 - c.danger).clamp(1, 4);
        final isWanted = c.loot.any(wantedLoot.contains) ||
            wantedCreatures.contains(c.name);
        if (isWanted) w += 3; // 委托目标显著加权
        for (var i = 0; i < w; i++) {
          weighted.add(c);
        }
      }
      final creature = weighted[random.nextInt(weighted.length)];
      _recordCreature(creature);
      buf.writeln('密林深处传来窸窣声。你屏住呼吸，看到了——${creature.name}。');
      buf.writeln('${creature.desc}');
      buf.writeln('\n【图鉴更新】${creature.name}（${dangerLabel(creature.danger)}）已收录');

      if (creature.danger >= 3) {
        // 对抗判定
        final escapeP = (0.35 +
                (_attr('reaction_time') - 50) / 500 +
                (_attr('observation') - 50) / 500 +
                (p.petBond >= 40 ? 0.1 : 0) +
                _equipmentCastBonus() / 1000)
            .clamp(0.15, 0.85);
        if (random.nextDouble() < escapeP) {
          buf.writeln('\n${creature.name} 向你逼近，你抓住它停顿的一瞬，闪身躲进树根后，'
              '贴着地面退了回去。心跳如擂鼓，但你没受伤。');
        } else {
          final creaturePower = creature.danger * 18 + 10;
          final myPower = _playerPower();
          final win = (myPower + random.nextInt(21)) >= (creaturePower + random.nextInt(16));
          if (win) {
            p.health = (p.health - 5 * creature.danger).clamp(1, 100);
            p.playerReputation.add('combat', 4 + creature.danger * 2);
            addHouseCupPoints(5, '禁林战胜危险生物');
            buf.writeln('\n你抽出魔杖迎战。经过几个来回，${creature.name} 终于哀鸣着退入黑暗。'
                '战斗声望 +${4 + creature.danger * 2} · 学院杯 +5');
            if (creature.loot.isNotEmpty) {
              final drop = creature.loot[random.nextInt(creature.loot.length)];
              _gainItem(drop);
              buf.writeln('你在战利品中找到了「$drop」，收进背包。');
            }
            _progressQuest('defeat', creature.name, 1);
          } else {
            p.health = (p.health - 15 - 5 * creature.danger).clamp(1, 100);
            buf.writeln('\n你没能拦住${creature.name}的冲击，被重重撞飞。'
                '好在它没有追杀，你拖着受伤的身体逃回了城堡。'
                '（生命 ${p.health}/100，可去校医院用白鲜香精治疗）');
          }
        }
      } else {
        if (creature.loot.isNotEmpty) {
          final drop = creature.loot[random.nextInt(creature.loot.length)];
          _gainItem(drop);
          buf.writeln('它并不怕你，还在附近留下了「$drop」——你小心翼翼地收了起来。');
        }
        buf.writeln('\n你悄悄退开，没有惊扰它。');
      }
    } else if (rollValue < 55) {
      // 采集材料
      final material = kCommonLootMaterials[random.nextInt(kCommonLootMaterials.length)];
      _gainItem(material);
      buf.writeln('你在树根与岩石之间仔细翻找，收获了一份「$material」，塞进背包。');
    } else if (rollValue < 70) {
      // 金币
      final coins = 5 + random.nextInt(16);
      p.galleons += coins;
      buf.writeln('你在一条干涸的溪流边捡到一个小皮袋，里面装着 $coins 加隆。'
          '大概是哪个倒霉鬼掉的。');
    } else if (rollValue < 85) {
      buf.writeln('这一趟有惊无险——除了几只不咬人的护树罗锅远远望着你，禁林安静得不像话。'
          '你几乎空手而归，但至少熟悉了这片林子。');
    } else {
      p.health = (p.health - 8 - random.nextInt(8)).clamp(1, 100);
      if (!p.injuries.contains('禁林擦伤')) p.injuries.add('禁林擦伤');
      buf.writeln('你在湿滑的苔藓上滑了一跤，撞上裸露的树根，额头擦破了皮。'
          '（生命 ${p.health}/100，注意包扎）');
    }

    buf.writeln('\n禁林入口的风从你身后吹来，你决定先返回城堡。');
    _finishLocal(buf.toString());
  }

  void _recordCreature(CreatureDef c) {
    final p = player!;
    if (!p.bestiary.contains(c.id)) {
      p.bestiary.add(c.id);
    }
    if (p.bestiary.length >= 3) unlockAchievement('bestiary_3');
  }

  // ==================== 7. 魔法生物图鉴 ====================

  String formatBestiary() {
    final p = player;
    final buf = StringBuffer('【魔法生物图鉴】（${p?.bestiary.length ?? 0}/${kCreatureCatalog.length}）\n');
    if (p == null || p.bestiary.isEmpty) {
      buf.writeln('\n尚未发现任何生物。去 /禁林 探险，或观察身边的花园与城堡，'
          '与神奇生物相遇吧。');
      return buf.toString();
    }
    for (final c in kCreatureCatalog) {
      final found = p.bestiary.contains(c.id);
      if (!found) continue;
      buf.writeln('\n『${c.name}』 ${dangerLabel(c.danger)}');
      buf.writeln('栖息地：${c.habitat}');
      buf.writeln('${c.desc}');
      if (c.loot.isNotEmpty) {
        buf.writeln('可获材料：${c.loot.join('、')}');
      }
    }
    buf.writeln('\n已发现 ${p.bestiary.length} 种。继续探索可解锁全部图鉴。');
    return buf.toString();
  }

  // ==================== 8. 支线委托板 ====================

  /// 列出板上 3 个当前可接取的模板。
  /// 结果会缓存进 [questBoardIds]，保证「看到的编号」与「接到的委托」一致；
  /// 只有 [forceRefresh] 为 true（玩家显式 /委托 刷新）或缓存条目已失效时才重排。
  List<QuestTemplate> _board({bool forceRefresh = false}) {
    final p = player;
    final taken = <String>{};
    for (final q in p?.quests ?? const <QuestRecord>[]) {
      taken.add(q.templateId);
    }
    final grade = p?.grade ?? 1;

    // 跨周自动补货，让委托板随时间变化而不是一进游戏就定死
    if (questBoardWeek != gameWeek) {
      questBoardWeek = gameWeek;
      forceRefresh = true;
    }

    if (!forceRefresh && questBoardIds.isNotEmpty) {
      final cached = questBoardIds
          .map(questTemplateById)
          .whereType<QuestTemplate>()
          .where((t) => !taken.contains(t.id) && t.minGrade <= grade)
          .take(3)
          .toList();
      if (cached.isNotEmpty) return cached;
    }

    final available = kQuestTemplates
        .where((t) => !taken.contains(t.id) && (t.minGrade <= grade))
        .toList()
      ..shuffle(random);
    final picked = available.take(3).toList();
    questBoardIds = picked.map((t) => t.id).toList();
    return picked;
  }

  void refreshQuestBoard() {
    final board = _board(forceRefresh: true);
    final buf = StringBuffer('【委托板 · 已刷新】\n');
    if (board.isEmpty) {
      buf.writeln('板子上暂时没有适合你的委托。之后再来看看，或者去禁林碰碰运气。');
    } else {
      buf.writeln('（可接受的委托）');
      for (var i = 0; i < board.length; i++) {
        final q = board[i];
        buf.writeln('\n${i + 1}. ${q.title}（${_questTypeLabel(q.type)}）');
        buf.writeln('   ${q.desc}');
        buf.writeln('   目标：${q.target} ×${q.targetCount} ｜ 奖励：${q.rewardGalleons}加隆 + ${q.rewardHousePoints}分');
      }
      buf.writeln('\n输入 /委托 接受 [编号] 接下委托。');
    }
    _finishLocal(buf.toString());
  }

  String _questTypeLabel(String type) => switch (type) {
        'gather' => '收集',
        'defeat' => '讨伐',
        'pet' => '培养',
        _ => '委托',
      };

  String formatQuests() {
    final p = player;
    final buf = StringBuffer('【支线委托】\n');
    if (p == null || p.quests.isEmpty) {
      buf.writeln('你还没有接下任何委托。');
    } else {
      for (var i = 0; i < p.quests.length; i++) {
        final q = p.quests[i];
        final done = q.isDone;
        final claimed = q.status == 'claimed';
        buf.writeln('\n${i + 1}. [${claimed ? '已领取' : done ? '可交付' : '进行中'}] ${q.title}');
        buf.writeln('   ${q.desc}');
        buf.writeln('   进度：${q.progress}/${q.targetCount}（${q.target}）');
        if (claimed) {
          buf.writeln('   ✅ 奖励已领取');
        } else if (done) {
          buf.writeln('   ⭐ 目标达成，/委托 交付 ${i + 1} 领取奖励！');
        }
      }
    }
    buf.writeln('\n/委托 查看 ｜ /委托 刷新 ｜ /委托 接受 [编号] ｜ /委托 交付 [编号]');
    buf.writeln('收集与讨伐类委托会在禁林探险中自动推进，培养类随宠物互动增长。');
    return buf.toString();
  }

  void acceptQuest(int index) {
    final board = _board();
    if (index < 0 || index >= board.length) {
      _finishLocal('编号无效。板子上目前有 ${board.length} 条可接受委托（/委托 刷新 查看）。');
      return;
    }
    acceptQuestTemplate(board[index].id);
  }

  /// 按模板 ID 接取委托（委托板独立页面使用，避免与随机刷板索引不一致）
  void acceptQuestTemplate(String id) {
    final p = player;
    if (p == null) return;
    final t = questTemplateById(id);
    if (t == null) {
      _finishLocal('这个委托似乎已经从板子上撤下了。');
      return;
    }
    if ((p.grade ?? 1) < t.minGrade) {
      _finishLocal('「${t.title}」的难度超出了你现在的年级（要求 ${t.minGrade} 年级以上）。先成长一阵子再来吧。');
      return;
    }
    final taken = <String>{};
    for (final q in p.quests) {
      taken.add(q.templateId);
    }
    if (taken.contains(t.id)) {
      _finishLocal('你已经接过「${t.title}」这个委托了。');
      return;
    }
    p.quests.add(QuestRecord.fromTemplate(t, week: gameWeek));
    // ====== 长线记忆写入：T1 未完结事项（委托接取） ======
    // 委托是"承诺/约定"类未完结事项，必须写入 T1 防止 AI 数百回合后遗忘。
    final ts = worldState.time.format();
    memory = memory.addOrUpdateOpenLoop(OpenLoopRecord(
      id: 'quest_${t.id}',
      description: '接取委托「${t.title}」：需收集${t.target}×${t.targetCount}，奖励${t.rewardGalleons}加隆+${t.rewardHousePoints}分',
      status: 'open',
      importance: 5,
      openedAt: ts,
      loopType: 'quest',
      openedTurn: turnCount,
    ));
    _finishLocal('【已接取委托】\n${t.title}\n\n${t.desc}\n\n'
        '目标：${t.target} ×${t.targetCount} ｜ 奖励：${t.rewardGalleons}加隆 + ${t.rewardHousePoints}分\n\n'
        '完成后输入 /委托 交付 领取奖励。');
  }

  void deliverQuest(int index) {
    final p = player;
    if (p == null) return;
    final qs = p.quests;
    if (index < 0 || index >= qs.length) {
      _finishLocal('编号无效。输入 /委托 查看当前委托清单。');
      return;
    }
    final q = qs[index];
    if (q.status == 'claimed') {
      _finishLocal('「${q.title}」的奖励你已经领过了。');
      return;
    }
    if (!q.isDone) {
      _finishLocal('「${q.title}」还未完成：${q.progress}/${q.targetCount}（${q.target}）。继续加油。');
      return;
    }
    q.status = 'claimed';
    p.galleons += q.rewardGalleons;
    addHouseCupPoints(q.rewardHousePoints, '完成委托');
    p.playerReputation.add('academic', 2);
    p.playerReputation.add('moral', 3);
    // ====== 长线记忆写入：关闭 T1 委托事项 + T3 世界事件 ======
    memory = memory.addOrUpdateOpenLoop(OpenLoopRecord(
      id: 'quest_${q.templateId}',
      description: '完成委托「${q.title}」：收集${q.target}×${q.targetCount}，获得${q.rewardGalleons}加隆+${q.rewardHousePoints}分',
      status: 'done',
      importance: 5,
      openedAt: worldState.time.format(),
      closedAt: worldState.time.format(),
      loopType: 'quest',
      openedTurn: turnCount,
    ));
    memory = memory.addWorldEvent(WorldEventRecord(
      id: 'quest_done_${q.templateId}_$turnCount',
      timestamp: worldState.time.format(),
      title: '完成委托',
      description: '主角完成委托「${q.title}」，获得${q.rewardGalleons}加隆与${q.rewardHousePoints}学院分',
      importance: 4,
      category: 'personal',
    ));
    final buf = StringBuffer('【委托交付 · ${q.title}】\n');
    buf.writeln('你带着${q.target}（${q.progress}/${q.targetCount}）交回委托板，负责的老巫师仔细清点后露出赞许的笑容。');
    buf.writeln('\n奖励：${q.rewardGalleons} 加隆 · 学院杯 +${q.rewardHousePoints} 分 · 学术声望 +2 · 道德声望 +3');
    unlockAchievement('first_quest');
    _finishLocal(buf.toString());
  }

  // ==================== 9. 学院杯 ====================

  /// 学院杯加分的唯一入口。
  ///
  /// 此前 5 个加分点全都直接写 `p.houseCupPoints += n`，这个方法反而一个调用者
  /// 都没有。统一到这里之后 `reason` 会累计进来源明细，`/学院杯` 就能告诉玩家
  /// 这一年分数是从哪儿挣来的，而不是只列一份"有哪些加分途径"的静态说明。
  void addHouseCupPoints(int amount, String reason) {
    final p = player;
    if (p == null || amount == 0) return;
    p.houseCupPoints += amount;
    p.houseCupSources[reason] = (p.houseCupSources[reason] ?? 0) + amount;
  }

  String formatHouseCup() {
    final p = player;
    if (p == null) return '';
    final myCn = switch (p.house) {
      'Gryffindor' => '格兰芬多',
      'Slytherin' => '斯莱特林',
      'Ravenclaw' => '拉文克劳',
      'Hufflepuff' => '赫奇帕奇',
      _ => '（未分院）',
    };
    final buf = StringBuffer('【学院杯】\n');
    if (p.house == null) {
      buf.writeln('你还没有被分院，暂未参与学院杯竞争。');
      return buf.toString();
    }
    buf.writeln('$myCn 学院杯积分（你的贡献）：${p.houseCupPoints} 分\n');

    if (p.houseCupSources.isEmpty) {
      buf.writeln('你还没有为学院挣下任何一分。可加分的途径：');
      buf.writeln('· 魁地奇取胜 +30，惜败 +5');
      buf.writeln('· 巫师决斗获胜 +1~10');
      buf.writeln('· 禁林战胜危险生物 +5');
      buf.writeln('· 完成支线委托 +3~10');
    } else {
      final sources = p.houseCupSources.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      buf.writeln('本学年得分构成：');
      for (final e in sources) {
        buf.writeln('· ${e.key} +${e.value}');
      }
    }
    buf.writeln('\n学年结束时将结算排名，榜首学院获得学院杯。');
    buf.writeln('其他学院也在暗自较劲——格兰芬多的勇气、斯莱特林的算计、'
        '拉文克劳的智慧、赫奇帕奇的踏实，各有各的赢法。');
    return buf.toString();
  }

  /// 学年结算（由 mixin_systems 学年切换时调用）
  void settleHouseCup() {
    final p = player;
    if (p == null || p.house == null || p.houseCupPoints <= 0) return;
    final myCn = switch (p.house) {
      'Gryffindor' => '格兰芬多',
      'Slytherin' => '斯莱特林',
      'Ravenclaw' => '拉文克劳',
      'Hufflepuff' => '赫奇帕奇',
      _ => p.house!,
    };
    // 其它三院基准分（随机），本学院 = 基准 + 玩家贡献
    final others = ['格兰芬多', '斯莱特林', '拉文克劳', '赫奇帕奇']
        .where((h) => h != myCn)
        .toList();
    final scores = <String, int>{
      for (final o in others) o: 120 + random.nextInt(80),
      myCn: 130 + p.houseCupPoints,
    };
    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final rank = ranked.indexWhere((e) => e.key == myCn) + 1;

    final buf = StringBuffer('【学院杯 · 学年结算】\n');
    ranked.forEach((e) {
      buf.writeln('${e.key == myCn ? '★ ' : '  '}${e.key}：${e.value} 分');
    });
    buf.writeln('\n你在本学年为$myCn 赢得了 ${p.houseCupPoints} 分。');

    if (rank == 1) {
      p.galleons += 50;
      p.playerReputation.add('leadership', 10);
      p.playerReputation.add('social', 6);
      p.houseReputation += 15;
      unlockAchievement('house_cup_winner');
      buf.writeln('\n$myCn 夺得学院杯！你站在欢呼的人群中央，彩带和掌声淹没了你。');
      buf.writeln('奖励：50 加隆 · 领导声望 +10 · 社交声望 +6 · 学院声望 +15');
    } else if (rank == 2) {
      p.galleons += 20;
      p.playerReputation.add('social', 4);
      p.houseReputation += 5;
      buf.writeln('\n$myCn 获得第二名，离学院杯一步之遥。你的贡献有目共睹。');
      buf.writeln('奖励：20 加隆 · 社交声望 +4 · 学院声望 +5');
    } else {
      p.playerReputation.add('social', 2);
      buf.writeln('\n$myCn 与学院杯失之交臂。队长拍拍你的肩：明年把金色奖杯搬回来。');
      buf.writeln('奖励：社交声望 +2');
    }
    p.houseCupPoints = 0;
    p.houseCupSources.clear();
    notifications.add('🏆 学院杯学年结算：$myCn 排名第$rank 名');
    _finishLocal(buf.toString());
  }
}
