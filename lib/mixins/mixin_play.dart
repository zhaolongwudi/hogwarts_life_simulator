import '../data/item_data.dart';
import 'mixin_play_arena.dart';
import 'mixin_play_tools.dart';
import '../data/house_data.dart';
import '../data/house_cup_data.dart';
import '../data/club_data.dart';
import '../data/bestiary_data.dart';
import '../data/quest_data.dart';
import '../data/pet_data.dart';
import '../data/pet_narrative_config.dart';
import '../data/spell_data.dart';
import '../data/collectible_data.dart';
import '../data/balance_constants.dart';
import '../data/offline_extras_data.dart';
import '../data/club_minigames_data.dart';
import '../models/player.dart';
import '../models/long_term_memory.dart';
import '../providers/game_provider_base.dart';
import '../utils/debug_log.dart';
import '../data/memory_importance_config.dart';

/// 新玩法 Mixin（v1.10）：物品使用 / 宠物互动 / 装备穿戴 / 魁地奇 / 决斗 /
/// 禁林探险 / 魔法生物图鉴 / 支线委托板 / 学院杯积分。
/// 全部本地判定、零 token 消耗，叙事结果走 currentNarrative + choices 通道。
mixin GamePlayMixin on GameProviderBase, GamePlayToolsMixin, GamePlayArenaMixin {
  // ==================== 1. 物品使用 ====================

  @override
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

  @override
  void useItem(String name) {
    final p = player;
    if (p == null) return;
    // 魔药部酿造药水兜底：酿造产出不进 kItemCatalog（商店买不到红线），
    // 这里按配方 effectKey/effectValue 直接生效，复用 /使用 药水链路。
    final recipe = potionRecipeByProduct(name);
    if (recipe != null) {
      final buf = StringBuffer('【使用 · $name】\n');
      buf.writeln('你拧开瓶塞，把这瓶魔药一饮而尽。温热的药力顺着喉咙蔓延开。');
      _applyEffects(p, {recipe.effectKey: recipe.effectValue}, buf);
      removeItem(name);
      finishLocal(buf.toString());
      return;
    }
    final def = itemDefByName(name);
    if (def == null || !def.usable) {
      finishLocal('「$name」无法使用。\n\n${formatItemUseHelp()}');
      return;
    }
    if (!hasItem(name)) {
      finishLocal('你的背包里没有「$name」。\n\n${formatItemUseHelp()}');
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
      removeItem(name);
      finishLocal(buf.toString());
      return;
    }

    // 标准咒语书：提升魔咒理解，未学咒时自动学会漂浮咒
    if (effects.containsKey('learn_spell')) {
      if (p.learnedSpells.isEmpty) {
        p.learnedSpells['漂浮咒'] = SpellLevel(
          spellName: '漂浮咒',
          level: 1,
          practiceCount: 1,
        );
        buf.writeln('你翻开《标准咒语书》，第一次学会了「漂浮咒」！');
        buf.writeln('（以后学新咒语用 /咒语 学习，练熟用 /咒语 练习）');
      } else {
        // 以前这句只是句空话——读完什么都没发生，"豁然开朗"没有对应的数值。
        // 现在它真的推进魔咒理解：书是给已经会咒的人磨熟练度用的。
        p.attributes['spell_understanding'] =
            ((p.attributes['spell_understanding'] ?? 50) + 2).clamp(0, 100);
        buf.writeln('你温习了《标准咒语书》，许多细节豁然开朗。');
        buf.writeln('魔咒理解 +2（当前 ${p.attributes['spell_understanding']}）');
      }
    }

    // 会掉收藏品的物品（巧克力蛙 → 著名巫师画片）。
    // 巧克力蛙的物品描述写着「附赠著名巫师卡片」，而收藏栏此前永远是空的
    // ——全项目对 collection 的写入一处都没有。这里把那句话兑现掉。
    final series = collectibleSeriesForUse[name];
    if (series != null) {
      _addCollectibleFromSeries(series, buf);
    }

    buf.writeln('你把「$name」${_useActionVerb(name)}。');
    _applyEffects(p, effects, buf);
    removeItem(name);
    finishLocal(buf.toString());
  }

  /// 从 [series] 里抽一张还没拥有的收藏品，抽不到就给张重复的。
  ///
  /// 权重按稀有度反过来算：★ 越多越难抽到。全收齐之后提示一句，不再重复
  /// 掉落——否则吃一百只蛙会看到一百句「又是邓布利多」。
  void _addCollectibleFromSeries(String series, StringBuffer buf) {
    final p = player;
    if (p == null) return;
    final all = collectiblesInSeries(series);
    if (all.isEmpty) return;
    final missing = all.where((c) => !p.collection.contains(c.id)).toList();
    if (missing.isEmpty) {
      buf.writeln('（「$series」你已经收齐了，这一包是重复的。）');
      return;
    }
    var total = 0;
    for (final c in missing) {
      total += 6 - c.rarity;
    }
    var pick = random.nextInt(total);
    CollectibleDef chosen = missing.last;
    for (final c in missing) {
      pick -= 6 - c.rarity;
      if (pick < 0) {
        chosen = c;
        break;
      }
    }
    p.collection.add(chosen.id);
    buf.writeln();
    buf.writeln('包装纸里滑出一张卡片——${chosen.name}（${chosen.starText}）');
    buf.writeln(chosen.desc);
    final owned = all.where((c) => p.collection.contains(c.id)).length;
    buf.writeln('「$series」收集进度：$owned/${all.length}　（/收藏 查看）');
    notifications.add('🃏 获得收藏品：${chosen.name}');
  }

  /// 禁林里偶然撞见的纪念品（独角兽尾毛）。
  void _addCollectibleSighting(StringBuffer buf) {
    if (!addCollectible('souvenir_forest')) return;
    buf.writeln(
      '正要走，林子深处闪过一道银白。你追过去只看見几丛被压弯的草，'
      '草叶上挂着一根独角兽的尾毛——泛着很淡的光。',
    );
  }

  /// 直接入册一件收藏品（开局、分院、禁林这类一次性来源）。
  ///
  /// 返回 true 表示这是第一次拿到，false 表示已经有了——调用方据此决定要不
  /// 要播报，免得读档或重复触发时刷屏。
  ///
  /// 声明在基类上是给其他 mixin（购买入册在 mixin_relations）用的：私有方法
  /// 跨文件访问不到，而 collection 的写入点分散在几个 mixin 里。
  @override
  bool addCollectible(String id) {
    final p = player;
    if (p == null) return false;
    final def = collectibleById(id);
    if (def == null) return false;
    if (p.collection.contains(id)) return false;
    p.collection.add(id);
    notifications.add('🗂️ 获得收藏品：${def.name}');
    worldState.addNarrativeEvent('🗂️ 获得收藏品：${def.name}', turn: turnCount);
    return true;
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
            debugLog('⚠️ 物品效果含非属性 key「$key」，已忽略（控制标记或拼写错误）');
            return;
          }
          p.attributes[key] = ((p.attributes[key] ?? 50) + value).clamp(0, 100);
          changes.add('${attrLabelZh(key)} ${value > 0 ? '+' : ''}$value');
      }
    });
    if (changes.isNotEmpty) {
      buf.writeln('\n效果：${changes.join(' · ')}');
    }
  }

  /// 属性 key → 中文名。表本身在 lib/data/attribute_data.dart
  /// （attrLabel 那边共用同一份，两边翻译曾经互相矛盾过）。

  // ==================== 1b. 咒语学习与练习 ====================

  /// 咒语一览：已学会的按等级排，再列当前年级还能学的。
  ///
  /// 这是玩家唯一能看到「哪些咒语存在」的地方。以前没有这张表，learnedSpells
  /// 里最多躺着一条「漂浮咒」，成就「书虫」要求学会 10 个——玩家连第 2 个咒
  /// 的名字都无从得知。
  @override
  String formatSpells() {
    final p = player;
    if (p == null) return '你还没有开始学业。';
    final grade = p.grade ?? 1;
    final buf = StringBuffer(
      '【魔咒】（已学 ${p.learnedSpells.length}/${spellCatalog.length}）\n',
    );

    if (p.learnedSpells.isEmpty) {
      buf.writeln('你还一个咒语都没学会。/咒语 学习 咒语名 可以开始。');
    } else {
      final known = p.learnedSpells.values.toList()
        ..sort((a, b) => b.level.compareTo(a.level));
      for (final s in known) {
        final def = spellByName(s.spellName);
        final cap = def == null ? 100 : def.levelCapFor(attr(def.attribute));
        final full = s.level >= cap;
        buf.writeln(
          '· ${s.spellName}　Lv.${s.level}'
          '${full ? '（已达当前上限 $cap，先提高${def == null ? '熟练度' : attrLabelZh(def.attribute)}）' : '（上限 $cap）'}'
          '　练过 ${s.practiceCount} 次',
        );
      }
    }

    final locked = spellsLearnableAt(
      grade,
    ).where((s) => !p.learnedSpells.containsKey(s.name)).toList();
    buf.writeln();
    if (locked.isEmpty) {
      buf.writeln('$grade 年级能学的咒语你都学过了。');
    } else {
      buf.writeln('当前年级还可以学：');
      for (final s in locked) {
        final lv = attr(s.attribute);
        final ok = lv >= s.requiredAttribute;
        buf.writeln(
          '· ${s.name}（${s.incantation}）'
          '　${attrLabelZh(s.attribute)} $lv/${s.requiredAttribute}${ok ? '' : '（不够）'}'
          '　${s.effect}',
        );
      }
    }
    buf.writeln();
    buf.write(
      '用法：/咒语 学习 咒语名 ｜ /咒语 练习 咒语名 ｜ /咒语 详情 咒语名\n'
      '每天学 1 个新咒、练 ${dailyLimitOf('spell')} 次。',
    );
    return buf.toString();
  }

  @override
  String formatSpellDetail(String name) {
    final s = spellByName(name);
    if (s == null) return '没有「$name」这个咒语。输入 /咒语 看看能学什么。';
    final p = player;
    final learned = p?.learnedSpells[s.name];
    final buf = StringBuffer('【${s.name}】\n')
      ..writeln('咒文：${s.incantation}')
      ..writeln('类别：${s.category.label}　难度：${'★' * s.difficulty}')
      ..writeln('最低年级：${s.minGrade} 年级')
      ..writeln(
        '关联熟练度：${attrLabelZh(s.attribute)}（需 ${s.requiredAttribute} 才能学，也决定等级上限）',
      )
      ..writeln('效果：${s.effect}');
    if (learned != null) {
      buf.writeln(
        '你的进度：Lv.${learned.level}（上限 ${s.levelCapFor(attr(s.attribute))}），练过 ${learned.practiceCount} 次',
      );
    } else {
      buf.writeln('你还没有学会这个咒语。');
    }
    return buf.toString();
  }

  /// 学一个新咒语。
  ///
  /// 年级与熟练度两道门槛是必要的：咒语等级会被关联属性压着，让一年级新生
  /// 直接学走杀戮咒，既不符合设定，也会让「一年级禁咒」的一致性检查失去意义
  /// （那条检查正是拿 learnedSpells 当白名单的）。
  @override
  void learnSpell(String name) {
    final p = player;
    if (p == null) return;
    final def = spellByName(name);
    if (def == null) {
      finishLocal('没有「$name」这个咒语。输入 /咒语 看看当前年级能学什么。');
      return;
    }
    if (p.learnedSpells.containsKey(def.name)) {
      finishLocal('你已经会「${def.name}」了，想提高等级就 /咒语 练习 ${def.name}。');
      return;
    }
    final grade = p.grade ?? 1;
    if (grade < def.minGrade) {
      finishLocal(
        '「${def.name}」是 $grade 年级还够不着的内容（需 ${def.minGrade} 年级）。\n'
        '现在练好手上这几个咒，比硬啃难的更有用。',
      );
      return;
    }
    final lv = attr(def.attribute);
    if (lv < def.requiredAttribute) {
      finishLocal(
        '你试了几次，杖尖只是冒了点烟。\n\n'
        '「${def.name}」需要${attrLabelZh(def.attribute)}达到 ${def.requiredAttribute}'
        '（当前 $lv）。先去 /课堂 互动 练练基本功。',
      );
      return;
    }
    if (!canDoDaily('learn_spell')) {
      finishLocal(
        '一天啃一个新咒已经够呛了，明天再学吧。\n\n'
        '（每天只能学 1 个新咒语；已学会的可以练 ${dailyLimitOf('spell')} 次）',
      );
      return;
    }
    if (p.energy < 10) {
      finishLocal('你的精力只剩 ${p.energy}/100，握着魔杖的手都在晃。先休息吧。');
      return;
    }

    // 学习失败态（框架2 §44：第一次学一个咒语，失败很正常）：
    // 门槛刚好达标时失败率 30%，熟练度远超门槛时降到 5%——不是必成功。
    // 失败同样消耗每日学习次数与精力，防止「反复试到成功」刷掉失败设定；
    // 但只扣一半精力，鼓励明天再来。
    final gap = lv - def.requiredAttribute;
    final failRate = gap >= 15 ? 0.05 : (gap >= 5 ? 0.15 : 0.30);
    if (random.nextDouble() < failRate) {
      recordDailyActivity('learn_spell');
      advanceTimeForAction('学习魔咒');
      p.energy = (p.energy - 5).clamp(0, 100);
      final buf = StringBuffer('【学咒失败】\n')
        ..writeln('你对着垫子反复念出「${def.incantation}」，杖尖却始终只有零星的火花。')
        ..writeln('发音、挥杖、意念——总差着那么一口气。')
        ..writeln()
        ..writeln(
          '「${def.name}」还没学会。休息一下，明天再试；'
          '或者先去 /课堂 互动 把${attrLabelZh(def.attribute)}练上去。',
        )
        ..writeln('精力 -5（失败的尝试同样消耗精力）');
      finishLocal(buf.toString());
      return;
    }

    recordDailyActivity('learn_spell');
    advanceTimeForAction('学习魔咒');
    p.energy = (p.energy - 10).clamp(0, 100);
    p.learnedSpells[def.name] = SpellLevel(
      spellName: def.name,
      level: 1,
      practiceCount: 1,
    );

    final buf = StringBuffer('【学会新咒语】\n')
      ..writeln('你对着垫子念出「${def.incantation}」，杖尖终于给了回应。')
      ..writeln(def.effect)
      ..writeln()
      ..writeln('学会：${def.name}（Lv.1，等级上限 ${def.levelCapFor(lv)}）')
      ..writeln('精力 -10');
    notifications.add('✨ 学会新咒语：${def.name}');
    worldState.addNarrativeEvent('✨ 学会新咒语：${def.name}', turn: turnCount);
    checkAllAchievements();
    finishLocal(buf.toString());
  }

  /// 练习一个已学会的咒语，提高它的等级。
  ///
  /// 等级被关联熟练度封顶（SpellDef.levelCapFor），所以「反复练同一个咒」
  /// 顶不出满级；熟练度不够时得回头去上课。练习本身也有小概率推进熟练度，
  /// 让「练咒 → 变强 → 等级上限抬高」形成闭环，而不是各涨各的。
  @override
  void practiseSpell(String name) {
    final p = player;
    if (p == null) return;
    final def = spellByName(name);
    if (def == null) {
      finishLocal('没有「$name」这个咒语。输入 /咒语 看看能学什么。');
      return;
    }
    final cur = p.learnedSpells[def.name];
    if (cur == null) {
      finishLocal('你还不会「${def.name}」。先 /咒语 学习 ${def.name}。');
      return;
    }
    if (!canDoDaily('spell')) {
      finishLocal(
        '今天已经练了 ${dailyLimitOf('spell')} 次，手腕酸得抬不起来。\n\n'
        '（练习次数每天重置；学新咒另有 1 次）',
      );
      return;
    }
    if (p.energy < 8) {
      finishLocal('你的精力只剩 ${p.energy}/100，再挥杖要伤到自己了。先休息吧。');
      return;
    }

    recordDailyActivity('spell');
    advanceTimeForAction('练习魔咒');
    p.energy = (p.energy - 8).clamp(0, 100);

    final cap = def.levelCapFor(attr(def.attribute));
    final grown = cur.level < cap;
    var gain = 0;
    if (grown) {
      gain = 1 + random.nextInt((6 - def.difficulty).clamp(1, 5));
      // 高段位成长放缓：Lv.60 之后每次只有一半，避免几十次就顶到上限。
      if (cur.level >= 60) gain = (gain / 2).ceil().clamp(1, 5);
    }

    // 练咒反过来磨熟练度——顺便让「优等生」这条成就真正够得着。
    final attrGain = random.nextInt(100) < 35 ? 1 : 0;
    if (attrGain > 0) {
      p.attributes[def.attribute] =
          ((p.attributes[def.attribute] ?? 50) + attrGain).clamp(0, 100);
    }

    final level = (cur.level + gain).clamp(0, cap);
    p.learnedSpells[def.name] = SpellLevel(
      spellName: def.name,
      level: level,
      practiceCount: cur.practiceCount + 1,
    );

    final buf = StringBuffer('【练习 · ${def.name}】\n')
      ..writeln(
        grown
            ? '你一遍遍念着「${def.incantation}」，第 ${cur.practiceCount + 1} 次总算稳住了。'
            : '你又练了一遍「${def.incantation}」，手感还在，可等级已经顶到当前上限了。',
      )
      ..writeln()
      ..writeln(grown ? '等级 ${cur.level} → $level' : '等级 $level（已达上限 $cap）');
    if (attrGain > 0) {
      buf.writeln(
        '${attrLabelZh(def.attribute)} +$attrGain（当前 ${attr(def.attribute)}）',
      );
    } else if (!grown) {
      buf.writeln('想继续提高，得先把${attrLabelZh(def.attribute)}练上去（/课堂 互动）。');
    }
    buf.writeln('精力 -8');
    checkAllAchievements();
    finishLocal(buf.toString());
  }

  // ==================== 2. 宠物互动 ====================

  @override
  void petInteract(String action) {
    final p = player;
    if (p == null) return;
    if (p.petId == null && p.petName == null) {
      // 以前这句让人「去对角巷挑选」，但商店里根本没有宠物卖，是一条死路。
      // 现在有 /宠物 购买 了，直接把可执行的指令给出来。
      finishLocal('你还没有宠物，无法互动。\n\n${formatPetShop()}');
      return;
    }
    final def = p.petId != null ? petById(p.petId!) : null;
    final petName = (p.petName != null && p.petName!.isNotEmpty)
        ? p.petName!
        : (def?.name ?? '宠物');
    final day = worldState.time.absoluteDayIndex;
    final buf = StringBuffer('【宠物互动 · $petName】\n');

    if (action == '喂食' || action == '喂' || action == '食物') {
      if (p.petLastFedDay == day) {
        finishLocal('$petName 今天已经吃饱喝足，肚皮圆滚滚地直打瞌睡，明天再喂吧。');
        return;
      }
      p.petLastFedDay = day;
      final gain = 2 + random.nextInt(3); // +2~+4
      p.petBond = (p.petBond + gain).clamp(0, 100);
      buf.writeln('你拿出准备好的食物，$petName 立刻凑了上来，温热的小脑袋在你手心里蹭了又蹭。');
      buf.writeln('\n羁绊 +$gain（当前 ${p.petBond}/100）');
    } else if (action == '玩耍' || action == '玩') {
      if (p.petInteractDay == day) {
        finishLocal('$petName 今天已经陪你玩过、练过，现在只想赖在窝里休息。明天再来吧。');
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
        finishLocal('$petName 今天已经累坏了，训练只能等明天。');
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
        buf.writeln(
          '\n羁绊 +$gain（当前 ${p.petBond}/100），${attrLabelZh(skill)} +1',
        );
      } else {
        buf.writeln('今天的训练不太顺利，$petName 总是被旁边的动静分心。不过关系也算拉近了一些。');
        buf.writeln('\n羁绊 +$gain（当前 ${p.petBond}/100）');
      }
    } else {
      finishLocal(
        '宠物互动指令：/宠物 喂食 ｜ /宠物 玩耍 ｜ /宠物 训练\n\n'
        '喂食每日一次，玩耍/训练每日共一次。羁绊提升后宠物能提供更多帮助。',
      );
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
      buf.writeln(
        '\n—— 一道柔和的光晕忽然从$petName 身上漾开，它的身影在光芒中缓缓拔高，'
        '幻化作一个与你年纪相仿的少男/少女。绯色光晕笼罩周身，它/他静静看着你，轻声唤出你的名字。\n\n'
        '【羁绊已达】$species$petName：$hint',
      );
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
    finishLocal(buf.toString());
  }

  /// 「咿啦猫头鹰商店」的在售清单。
  ///
  /// 之前 /宠物 在没有宠物时会说「可以去对角巷挑选一只猫头鹰、猫或蟾蜍」，
  /// 但商店里没有宠物卖——开局问卷跳过宠物的玩家会被指到一条死路上，
  /// 喂食/玩耍/训练三个子指令和宠物助战、羁绊化形全废。
  @override
  String formatPetShop() {
    final buf = StringBuffer()
      ..writeln('【咿啦猫头鹰商店】')
      ..writeln('输入 /宠物 购买 <名字> 带一只回家，例如 /宠物 购买 猫头鹰');
    for (final pet in purchasablePets) {
      final price = kPetPrices[pet.id]!;
      final owned = player?.petId == pet.id ? '（你已拥有）' : '';
      buf.writeln('· ${pet.name}（${pet.species}）$price 加隆$owned');
      buf.writeln('    ${pet.description.split('\n').first}');
    }
    buf.writeln('\n你身上有 ${player?.galleons ?? 0} 加隆。');
    return buf.toString();
  }

  /// 买一只宠物。[keyword] 为空时只列出在售清单。
  @override
  String buyPet(String keyword) {
    final p = player;
    if (p == null) return '还没开始游戏。';

    final kw = keyword.trim();
    if (kw.isEmpty) return formatPetShop();

    final pet = findPet(kw);
    if (pet == null) {
      return '咿啦猫头鹰商店里没有「$kw」。\n\n${formatPetShop()}';
    }
    final price = kPetPrices[pet.id];
    if (price == null) {
      return '${pet.name}是契约灵兽，不卖。它只在入学前的缘分里出现——'
          '若你开新档时在问卷里结缘过，它才会在你身边。\n\n${formatPetShop()}';
    }
    if (p.petId != null) {
      final cur = petById(p.petId!)?.name ?? p.petName ?? '现在的伙伴';
      return '你已经有 $cur 了。对角巷的老规矩：一只巫师一生只认一个伙伴，'
          '换宠会让它带着所有羁绊离开。';
    }
    if (p.galleons < price) {
      return '${pet.name}要 $price 加隆，你身上只有 ${p.galleons} 加隆。'
          '先去禁林采集点材料卖钱，或者把用不上的东西拿到对角巷出手。';
    }

    p.galleons -= price;
    p.petId = pet.id;
    p.petName = kPetDefaultNames[pet.id];
    p.petBond = 0;
    notifyListeners();

    return '【咿啦猫头鹰商店】\n'
        '你花 $price 加隆带走了${pet.name}（${pet.species}）。\n'
        '${pet.description.split('\n').first}\n\n'
        '它从笼子里跳到你肩上，用小脑袋蹭了蹭你的耳朵。\n'
        '互动：/宠物 喂食 ｜ /宠物 玩耍 ｜ /宠物 训练（羁绊≥40 可在决斗与探险中助战）';
  }

  // ==================== 3. 装备穿戴 ====================

  @override
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
    final cb = equipmentCombatBonus();
    final cast = equipmentCastBonus();
    buf.writeln('\n当前加成：战斗 +$cb ｜ 施法成功率 +${(cast / 10).toStringAsFixed(1)}%');
    final items = equippableItems();
    buf.writeln('\n【可穿戴装备】');
    for (final it in items) {
      final owned = hasItem(it.name) ? '✅' : ' ';
      buf.writeln(
        '$owned ${it.name}（$priceLabel(it.price) 加隆，${slotLabel(it.equipSlot!)}）— ${it.desc}',
      );
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

  @override
  void equipItem(String name) {
    final p = player;
    if (p == null) return;
    final def = itemDefByName(name);
    if (def == null || !def.isEquippable) {
      finishLocal('「$name」不是可穿戴的装备。输入 /装备 查看可穿戴列表。');
      return;
    }
    if (!hasItem(name)) {
      finishLocal('你的背包里没有「$name」，需要先去对角巷购买。');
      return;
    }
    final slot = def.equipSlot!;
    final old = p.equipped[slot];

    // 装备实体从背包移入装备栏（否则它同时存在于两处：
    // 玩家可以把它卖掉，而装备栏仍留着名字 → 继续白嫖属性/施法加成）。
    removeItem(name);
    p.equipped[slot] = name;

    final buf = StringBuffer('【穿戴 · $name】\n');
    if (old != null && old != name) {
      buf.writeln('你换下了原来的${slotLabel(slot)}「$old」，穿上了「$name」。');
      // 换下的旧装备回到背包（旧存档里它可能仍在背包中，避免重复添加）
      if (!hasItem(old)) addItem(old);
    } else {
      buf.writeln('你装备上了「$name」（${slotLabel(slot)}）。');
    }
    if (def.statBonus.isNotEmpty) {
      buf.writeln(
        '\n属性加成：${def.statBonus.entries.map((e) => '${attrLabelZh(e.key)} +${e.value}').join(' · ')}',
      );
    }
    if (def.combatBonus > 0) {
      buf.writeln('战斗加成：+${def.combatBonus}');
    }
    if (def.castBonus > 0) {
      buf.writeln('施法加成：+${(def.castBonus / 10).toStringAsFixed(1)}%');
    }
    if (p.equipped.length >= 2) unlockAchievement('well_equipped');
    finishLocal(buf.toString());
  }

  @override
  void unequipItem(String slot) {
    final p = player;
    if (p == null) return;
    String? resolved = p.equipped.containsKey(slot) ? slot : null;
    if (resolved == null) {
      for (final s in ['robe', 'hat', 'broom', 'amulet']) {
        if (slotLabel(s) == slot || s == slot) {
          resolved = s;
          break;
        }
      }
    }
    if (resolved == null) {
      finishLocal('没有这个装备部位（袍子/帽子/扫帚/饰品）。输入 /装备 查看当前穿戴。');
      return;
    }
    final name = p.equipped.remove(resolved);
    if (name == null) {
      finishLocal('${slotLabel(resolved)}本来就空着，没有可卸下的装备。');
      return;
    }
    // 装备实体回到背包（若背包里已有一件——比如旧存档——就不再重复添加）
    if (!hasItem(name)) addItem(name);
    finishLocal('【卸下 · $name】\n你卸下了${slotLabel(resolved)}「$name」，它回到你的背包里。');
  }

  // ==================== 6. 禁林探险 ====================

  @override
  void exploreForbiddenForest() {
    final p = player;
    if (p == null) return;
    if (p.energy < 15) {
      finishLocal('你的精力所剩无几（${p.energy}/100）。禁林不是能空手而归的地方，先休息吧。');
      return;
    }
    if (p.satiety < 15) {
      finishLocal('你饿得前胸贴后背（饱食度 ${p.satiety}/100），进禁林之前先吃点东西吧。');
      return;
    }
    // 每日次数上限：禁林是材料/生物图鉴的主要来源，不设限的话
    // 一个下午就能把图鉴刷满、材料堆成山，后期采集玩法直接失去意义。
    if (!canDoDaily('forest')) {
      finishLocal(
        '海格远远朝你摆手：「今天进去 ${dailyLimitOf('forest')} 趟啦，林子也得喘口气。」\n\n'
        '天色确实不早了，明天再来吧。',
      );
      return;
    }

    recordDailyActivity('forest');
    advanceTimeForAction('禁林探险');
    p.energy = (p.energy - 15).clamp(0, 100);
    p.satiety = (p.satiety - 5).clamp(0, 100);

    final grade = p.grade ?? 1;
    final rollValue = random.nextInt(100);
    final buf = StringBuffer('【禁林探险】\n');

    // P8：特殊遭遇——按年级门控解锁的剧情事件（人马/独角兽/巨蛛巢等）。
    // 15% 概率命中；只挑当前年级可解锁的事件，同一次探险至多触发一条。
    final specials = kForestSpecialEncounters
        .where((e) => grade >= e.minGrade)
        .toList();
    if (specials.isNotEmpty && rollValue < 15) {
      final ev = specials[random.nextInt(specials.length)];
      buf.writeln(ev.text);
      // 剧情遭遇附带的战利品：人马尾鬃 / 月长石花 / 凤凰羽毛 入背包
      switch (ev.id) {
        case 'forest_centaur':
          gainItem('月长石粉');
          buf.writeln('\n【收获】月长石粉 已收入背包');
        case 'forest_golden_flower':
          gainItem('曼德拉草叶');
          buf.writeln('\n【收获】曼德拉草叶 已收入背包');
        case 'forest_phoenix_feather':
          gainItem('凤羽');
          buf.writeln('\n【收获】凤羽 已收入背包');
        case 'forest_treasure':
          final coins = 8 + random.nextInt(15);
          p.galleons += coins;
          gainItem('夜骐尾羽');
          buf.writeln('\n【收获】$coins 加隆 · 夜骐尾羽 已收入背包');
      }
      if (grade >= 3) {
        p.playerReputation.add('explore', 2);
        buf.writeln('探索声望 +2（你在这片林子里越来越游刃有余了）');
      }
      buf.writeln('\n禁林入口的风从你身后吹来，你决定先返回城堡。');
      finishLocal(buf.toString());
      return;
    }

    // 可遭遇生物：按年级限制危险度上限（防崩坏）
    final maxDanger = grade >= 5
        ? 5
        : grade >= 3
        ? 4
        : grade >= 2
        ? 3
        : 2;
    final pool = kCreatureCatalog.where((c) => c.danger <= maxDanger).toList();

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
        final isWanted =
            c.loot.any(wantedLoot.contains) || wantedCreatures.contains(c.name);
        if (isWanted) w += 3; // 委托目标显著加权
        for (var i = 0; i < w; i++) {
          weighted.add(c);
        }
      }
      final creature = weighted[random.nextInt(weighted.length)];
      _recordCreature(creature);
      buf.writeln('密林深处传来窸窣声。你屏住呼吸，看到了——${creature.name}。');
      buf.writeln(creature.desc);
      buf.writeln(
        '\n【图鉴更新】${creature.name}（${dangerLabel(creature.danger)}）已收录',
      );

      if (creature.danger >= 3) {
        // 对抗判定
        final escapeP =
            (0.35 +
                    (attr('reaction_time') - 50) / 500 +
                    (attr('observation') - 50) / 500 +
                    (p.petBond >= 40 ? 0.1 : 0) +
                    equipmentCastBonus() / 1000)
                .clamp(0.15, 0.85);
        if (random.nextDouble() < escapeP) {
          buf.writeln(
            '\n${creature.name} 向你逼近，你抓住它停顿的一瞬，闪身躲进树根后，'
            '贴着地面退了回去。心跳如擂鼓，但你没受伤。',
          );
        } else {
          final creaturePower = creature.danger * 18 + 10;
          final myPower = playerPower();
          final win =
              (myPower + random.nextInt(21)) >=
              (creaturePower + random.nextInt(16));
          if (win) {
            p.health = (p.health - 5 * creature.danger).clamp(1, 100);
            p.playerReputation.add('combat', 4 + creature.danger * 2);
            addHouseCupPoints(5, '禁林战胜危险生物');
            buf.writeln(
              '\n你抽出魔杖迎战。经过几个来回，${creature.name} 终于哀鸣着退入黑暗。'
              '战斗声望 +${4 + creature.danger * 2} · 学院杯 +5',
            );
            if (creature.loot.isNotEmpty) {
              final drop = creature.loot[random.nextInt(creature.loot.length)];
              gainItem(drop);
              buf.writeln('你在战利品中找到了「$drop」，收进背包。');
            }
            progressQuest('defeat', creature.name, 1);
          } else {
            p.health = (p.health - 15 - 5 * creature.danger).clamp(0, 100);
            pendingDeathCause = '禁林中${creature.name}的致命袭击';
            buf.writeln(
              '\n你没能拦住${creature.name}的冲击，被重重撞飞。'
              '好在它没有追杀，你拖着受伤的身体逃回了城堡。'
              '（生命 ${p.health}/100，可去校医院用白鲜香精治疗）',
            );
          }
        }
      } else {
        if (creature.loot.isNotEmpty) {
          final drop = creature.loot[random.nextInt(creature.loot.length)];
          gainItem(drop);
          buf.writeln('它并不怕你，还在附近留下了「$drop」——你小心翼翼地收了起来。');
        }
        buf.writeln('\n你悄悄退开，没有惊扰它。');
      }
    } else if (rollValue < 55) {
      // 采集材料：稀有档单独摇一次，让「再翻一次」值得期待
      final material = rollLootMaterial(random.nextInt(1000));
      final rare = kRareLootMaterials.contains(material);
      gainItem(material);
      if (rare) {
        buf.writeln(
          '你拨开一丛暗色的苔藓，底下的东西让你屏住了呼吸——「$material」。'
          '这种东西可不是随便就能碰上的，你小心翼翼地收好。',
        );
      } else {
        buf.writeln('你在树根与岩石之间仔细翻找，收获了一份「$material」，塞进背包。');
      }
    } else if (rollValue < 70) {
      // 金币
      final coins = 5 + random.nextInt(16);
      p.galleons += coins;
      buf.writeln(
        '你在一条干涸的溪流边捡到一个小皮袋，里面装着 $coins 加隆。'
        '大概是哪个倒霉鬼掉的。',
      );
    } else if (rollValue < 85) {
      buf.writeln(
        '这一趟有惊无险——除了几只不咬人的护树罗锅远远望着你，禁林安静得不像话。'
        '你几乎空手而归，但至少熟悉了这片林子。',
      );
      // 空手而归的这一档给一次收藏品机会：独角兽尾毛是禁林里唯一拿得到的
      // 纪念品，不给个明确来源的话它就永远是「看得见拿不到」。
      if (random.nextInt(100) < 12) _addCollectibleSighting(buf);
    } else {
      p.health = (p.health - 8 - random.nextInt(8)).clamp(1, 100);
      if (!p.injuries.contains('禁林擦伤')) p.injuries.add('禁林擦伤');
      buf.writeln(
        '你在湿滑的苔藓上滑了一跤，撞上裸露的树根，额头擦破了皮。'
        '（生命 ${p.health}/100，注意包扎）',
      );
    }

    buf.writeln('\n禁林入口的风从你身后吹来，你决定先返回城堡。');
    finishLocal(buf.toString());
  }

  void _recordCreature(CreatureDef c) {
    final p = player!;
    if (!p.bestiary.contains(c.id)) {
      p.bestiary.add(c.id);
    }
    if (p.bestiary.length >= 3) unlockAchievement('bestiary_3');
  }

  // ==================== 7. 魔法生物图鉴 ====================

  @override
  String formatBestiary() {
    final p = player;
    final buf = StringBuffer(
      '【魔法生物图鉴】（${p?.bestiary.length ?? 0}/${kCreatureCatalog.length}）\n',
    );
    if (p == null || p.bestiary.isEmpty) {
      buf.writeln(
        '\n尚未发现任何生物。去 /禁林 探险，或观察身边的花园与城堡，'
        '与神奇生物相遇吧。',
      );
      return buf.toString();
    }
    for (final c in kCreatureCatalog) {
      final found = p.bestiary.contains(c.id);
      if (!found) continue;
      buf.writeln('\n『${c.name}』 ${dangerLabel(c.danger)}');
      buf.writeln('栖息地：${c.habitat}');
      buf.writeln(c.desc);
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

    final available =
        kQuestTemplates
            .where((t) => !taken.contains(t.id) && (t.minGrade <= grade))
            .toList()
          ..shuffle(random);
    final picked = available.take(3).toList();
    questBoardIds = picked.map((t) => t.id).toList();
    return picked;
  }

  @override
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
        buf.writeln(
          '   目标：${q.target} ×${q.targetCount} ｜ 奖励：${q.rewardGalleons}加隆 + ${q.rewardHousePoints}分',
        );
      }
      buf.writeln('\n输入 /委托 接受 [编号] 接下委托。');
    }
    finishLocal(buf.toString());
  }

  /// 委托类型 → 中文名。表在 lib/data/quest_data.dart（委托板 UI 共用）。
  String _questTypeLabel(String type) => questTypeLabel(type);

  @override
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
        buf.writeln(
          '\n${i + 1}. [${claimed
              ? '已领取'
              : done
              ? '可交付'
              : '进行中'}] ${q.title}',
        );
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

  @override
  void acceptQuest(int index) {
    final board = _board();
    if (index < 0 || index >= board.length) {
      finishLocal('编号无效。板子上目前有 ${board.length} 条可接受委托（/委托 刷新 查看）。');
      return;
    }
    acceptQuestTemplate(board[index].id);
  }

  /// 按模板 ID 接取委托（委托板独立页面使用，避免与随机刷板索引不一致）
  @override
  void acceptQuestTemplate(String id) {
    final p = player;
    if (p == null) return;
    final t = questTemplateById(id);
    if (t == null) {
      finishLocal('这个委托似乎已经从板子上撤下了。');
      return;
    }
    if ((p.grade ?? 1) < t.minGrade) {
      finishLocal(
        '「${t.title}」的难度超出了你现在的年级（要求 ${t.minGrade} 年级以上）。先成长一阵子再来吧。',
      );
      return;
    }
    final taken = <String>{};
    for (final q in p.quests) {
      taken.add(q.templateId);
    }
    if (taken.contains(t.id)) {
      finishLocal('你已经接过「${t.title}」这个委托了。');
      return;
    }
    p.quests.add(QuestRecord.fromTemplate(t, week: gameWeek));
    // ====== 长线记忆写入：T1 未完结事项（委托接取） ======
    // 委托是"承诺/约定"类未完结事项，必须写入 T1 防止 AI 数百回合后遗忘。
    final ts = worldState.time.format();
    memory = memory.addOrUpdateOpenLoop(
      OpenLoopRecord(
        id: 'quest_${t.id}',
        description:
            '接取委托「${t.title}」：需收集${t.target}×${t.targetCount}，奖励${t.rewardGalleons}加隆+${t.rewardHousePoints}分',
        status: 'open',
        importance: kImportanceQuestOpen,
        openedAt: ts,
        loopType: 'quest',
        openedTurn: turnCount,
      ),
    );
    finishLocal(
      '【已接取委托】\n${t.title}\n\n${t.desc}\n\n'
      '目标：${t.target} ×${t.targetCount} ｜ 奖励：${t.rewardGalleons}加隆 + ${t.rewardHousePoints}分\n\n'
      '完成后输入 /委托 交付 领取奖励。',
    );
  }

  @override
  void deliverQuest(int index) {
    final p = player;
    if (p == null) return;
    final qs = p.quests;
    if (index < 0 || index >= qs.length) {
      finishLocal('编号无效。输入 /委托 查看当前委托清单。');
      return;
    }
    final q = qs[index];
    if (q.status == 'claimed') {
      finishLocal('「${q.title}」的奖励你已经领过了。');
      return;
    }
    if (!q.isDone) {
      finishLocal(
        '「${q.title}」还未完成：${q.progress}/${q.targetCount}（${q.target}）。继续加油。',
      );
      return;
    }
    q.status = 'claimed';
    p.galleons += q.rewardGalleons;
    addHouseCupPoints(q.rewardHousePoints, '完成委托');
    p.playerReputation.add('academic', 2);
    p.playerReputation.add('moral', 3);
    // ====== 长线记忆写入：关闭 T1 委托事项 + T3 世界事件 ======
    memory = memory.addOrUpdateOpenLoop(
      OpenLoopRecord(
        id: 'quest_${q.templateId}',
        description:
            '完成委托「${q.title}」：收集${q.target}×${q.targetCount}，获得${q.rewardGalleons}加隆+${q.rewardHousePoints}分',
        status: 'done',
        importance: kImportanceQuestDone,
        openedAt: worldState.time.format(),
        closedAt: worldState.time.format(),
        loopType: 'quest',
        openedTurn: turnCount,
      ),
    );
    memory = memory.addWorldEvent(
      WorldEventRecord(
        id: 'quest_done_${q.templateId}_$turnCount',
        timestamp: worldState.time.format(),
        title: '完成委托',
        description:
            '主角完成委托「${q.title}」，获得${q.rewardGalleons}加隆与${q.rewardHousePoints}学院分',
        importance: kImportanceQuestDoneEvent,
        category: 'personal',
      ),
    );
    final buf = StringBuffer('【委托交付 · ${q.title}】\n');
    buf.writeln(
      '你带着${q.target}（${q.progress}/${q.targetCount}）交回委托板，负责的老巫师仔细清点后露出赞许的笑容。',
    );
    buf.writeln(
      '\n奖励：${q.rewardGalleons} 加隆 · 学院杯 +${q.rewardHousePoints} 分 · 学术声望 +2 · 道德声望 +3',
    );
    unlockAchievement('first_quest');
    finishLocal(buf.toString());
  }

  // ==================== 9. 学院杯 ====================

  /// 学院杯加分的唯一入口。
  ///
  /// 此前 5 个加分点全都直接写 `p.houseCupPoints += n`，这个方法反而一个调用者
  /// 都没有。统一到这里之后 `reason` 会累计进来源明细，`/学院杯` 就能告诉玩家
  /// 这一年分数是从哪儿挣来的，而不是只列一份"有哪些加分途径"的静态说明。
  @override
  void addHouseCupPoints(int amount, String reason) {
    final p = player;
    if (p == null || amount == 0) return;
    p.houseCupPoints += amount;
    p.houseCupSources[reason] = (p.houseCupSources[reason] ?? 0) + amount;
    // 年度榜同步：玩家的学院行 = 基准 + 玩家本学年贡献，随贡献实时更新，
    // /学院杯 的榜单才不会被"学期初那个初始值"卡住。
    //
    // 必须同时排除空串：p.house 是 String?，但 mixin_response 从叙事里解析
    // 分院结果时走 `en ??= 首字母大写(matched)`，AI 一旦写出四院之外的词，
    // house 就会是个认不出来的值，houseDisplayName 回落到 '未分院'——
    // 那会在 houseCupYearly 里多出第 5 个 key，而 formatHouseCup 的奖牌表
    // 定长 4，按下标取就会 RangeError 崩溃。
    final house = houseKeyOrNull;
    if (house != null) {
      worldState.houseCupYearly[houseDisplayName(house)] =
          kHouseCupBaseScore + p.houseCupPoints;
    }
  }

  /// 懒初始化年度榜：四院都以 [kHouseCupBaseScore] 起步，并把玩家学院行
  /// 同步为「基准 + 玩家本学年贡献」。
  ///
  /// 老存档没有 houseCupYearly 字段，第一次读到是空表；玩家还没分院时
  /// （开场一路到分院帽前）不参与榜单，四院保持基准分。
  Map<String, int> _ensureHouseCupYearly() {
    final yearly = worldState.houseCupYearly;
    // 四院缺谁补谁（putIfAbsent 不动已有的行）：
    // 玩家可能先挣分把自家学院行写进去，再点开 /学院杯——
    // 不能因为表非空就把另外三院漏掉。
    if (yearly.length < kHouseNames.length) {
      for (final h in kHouseNames) {
        yearly.putIfAbsent(h, () => kHouseCupBaseScore);
      }
    }
    final p = player;
    final house = houseKeyOrNull;
    if (p != null && house != null) {
      yearly[houseDisplayName(house)] = kHouseCupBaseScore + p.houseCupPoints;
    }
    return yearly;
  }

  @override
  String formatHouseCup() {
    final p = player;
    if (p == null) return '';
    final houseKey = houseKeyOrNull;
    final myCn = houseDisplayName(houseKey, fallback: '（未分院）');
    final buf = StringBuffer('【学院杯】\n');
    if (houseKey == null) {
      buf.writeln('你还没有被分院，暂未参与学院杯竞争。');
      return buf.toString();
    }

    // 年度榜：四院实时排名。玩家的学院行已经由 _ensureHouseCupYearly 同步。
    final yearly = _ensureHouseCupYearly();
    final ranked = yearly.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const medal = ['🥇', '🥈', '🥉', '  '];
    buf.writeln('本学年四院累计（你的贡献已计入你的学院）：');
    for (var i = 0; i < ranked.length; i++) {
      final e = ranked[i];
      final isMine = e.key == myCn;
      final extra = isMine ? '（你 +${p.houseCupPoints}）' : '';
      // 越界保护：ranked 来自 houseCupYearly，正常是四院。但历史存档或
      // 异常数据可能让这张表多出一行（例如 '未分院'），按下标取定长奖牌表
      // 会 RangeError 直接崩在玩家点 /学院杯 的瞬间。宁可少一块奖牌。
      final badge = i < medal.length ? medal[i] : '  ';
      buf.writeln('$badge${isMine ? '★ ' : '  '}${e.key}：${e.value} 分$extra');
    }

    // 历届年度榜：让玩家看见七年榜单的走向
    if (worldState.houseCupYearHistory.isNotEmpty) {
      buf.writeln('\n历届年度榜：');
      worldState.houseCupYearHistory.forEach((year, summary) {
        buf.writeln('· $year：$summary');
      });
    }

    buf.writeln('\n你的本学年贡献：${p.houseCupPoints} 分');
    if (p.houseCupSources.isEmpty) {
      buf.writeln('可加分的途径：');
      buf.writeln(
        '· 魁地奇取胜 +${Balance.houseCupActivityPoints['quidditch_win']}，惜败 +5',
      );
      buf.writeln('· 巫师决斗获胜 +${Balance.houseCupActivityPoints['duel_win']}');
      buf.writeln(
        '· 禁林战胜危险生物 +${Balance.houseCupActivityPoints['forbidden_forest']}',
      );
      buf.writeln(
        '· 完成支线委托 +${Balance.houseCupActivityPoints['quest_complete']}',
      );
      buf.writeln('· 课堂表现优异 +${Balance.houseCupActivityPoints['classroom']}');
      buf.writeln('· 期末考试年级前十 +${Balance.houseCupActivityPoints['exam_top']}');
      buf.writeln(
        '· 日常：课堂上答对的问题、替同学解的围、'
        '还有你夜游被抓时扣掉的那些分（每天最多 +$kHouseNarrativeGainDailyCap）',
      );
    } else {
      final sources = p.houseCupSources.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      buf.writeln('本学年得分构成：');
      for (final e in sources) {
        // 扣分的时候"日常扣分 +-5"读不通
        final sign = e.value >= 0 ? '+' : '';
        buf.writeln('· ${e.key} $sign${e.value}');
      }
    }
    buf.writeln('\n学年结束时将结算排名，榜首学院获得学院杯。');
    buf.writeln(
      '其他学院也在暗自较劲——格兰芬多的勇气、斯莱特林的算计、'
      '拉文克劳的智慧、赫奇帕奇的踏实，各有各的赢法。',
    );
    return buf.toString();
  }

  /// 学年结算（由 mixin_systems 学年切换时调用）
  @override
  void settleHouseCup() {
    final p = player;
    // 未分院就不参与学院杯。注意这里不再有「零分拦截」：
    // 年度榜是四院全程累计的真实排名，玩家就算一分没挣，自己的学院也
    // 有基准分和对手在竞争，学年末该揭晓的榜单必须揭晓。
    if (p == null) return;
    // 未分院（含空串 / AI 写出的非四院名称）不参与结算。
    // 用 houseKeyOrNull 而不是 `p.house == null`：空串会被 houseDisplayName
    // 兜成「未分院」当成一支队伍写进榜单。
    final houseKey = houseKeyOrNull;
    if (houseKey == null) return;
    final myCn = houseDisplayName(houseKey);
    final yearly = _ensureHouseCupYearly();
    final ranked = yearly.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final rank = ranked.indexWhere((e) => e.key == myCn) + 1;

    // 记入历届年度榜（key=刚结束的学年，如 1991-1992）
    final winner = ranked.first.key;
    final summary = ranked
        .map((e) => e.key == winner ? '${e.key} 夺冠' : '${e.key} ${e.value}')
        .join('｜');
    worldState.houseCupYearHistory[worldState.academicYear] = summary;

    final buf = StringBuffer('【学院杯 · 学年结算】\n');
    for (var e in ranked) {
      buf.writeln('${e.key == myCn ? '★ ' : '  '}${e.key}：${e.value} 分');
    }
    // 净分为负的时候"赢得了 -20 分"读不通，而且那本来也不是一回事：
    // 一年下来净扣分，值得单独说一句，不该混在同一句话里。
    if (p.houseCupPoints > 0) {
      buf.writeln('\n你在本学年为$myCn 赢得了 ${p.houseCupPoints} 分。');
    } else if (p.houseCupPoints < 0) {
      buf.writeln(
        '\n你在本学年给$myCn 净扣掉了 ${-p.houseCupPoints} 分。'
        '没有人当众说起这件事，但账是记着的。',
      );
    } else {
      buf.writeln('\n你在本学年没有为$myCn 挣到分，但榜单还是照常揭晓了。');
    }

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
    // ===== Batch 11 · 社团 × 学院杯反向半环 =====
    // 本学年为社团挣的学院分（houseCupSources 里「社团·/社团任务·」前缀的
    // 正分）在结算时单独拎出来按档位追加「社团荣光」叙事与奖励。
    // 让「你属于什么」反过来成为学院杯里看得见的分量（规划第一梯队）。
    final clubCupContributed = clubContributedCupPoints(p.houseCupSources);
    if (clubCupContributed > 0) {
      final tier = clubCupTierFor(clubCupContributed);
      if (tier != null) {
        // 不依赖 memberClub（跨 mixin 非抽象成员不可见），直接查 clubId。
        final club = p.clubId == null ? null : clubById(p.clubId!);
        final clubName = club?.name ?? '你的社团';
        p.galleons += tier.galleons;
        p.houseReputation += tier.houseReputation;
        final note = tier.note
            .replaceAll(r'$club', clubName)
            .replaceAll(r'$points', '$clubCupContributed');
        buf.writeln();
        buf.writeln('【社团荣光 · $clubName】$note');
        if (tier.galleons > 0 || tier.houseReputation > 0) {
          final parts = <String>[
            if (tier.galleons > 0) '${tier.galleons} 加隆',
            if (tier.houseReputation > 0) '学院声望 +${tier.houseReputation}',
          ];
          buf.writeln('奖励：${parts.join(' · ')}');
        }
      }
    }
    p.houseCupPoints = 0;
    p.houseCupSources.clear();
    worldState.houseCupYearly.clear();
    notifications.add('🏆 学院杯学年结算：$myCn 排名第$rank 名');
    finishLocal(buf.toString());
  }

  // ==================== P7 玩法意图路由 ====================

  /// 把自然语言行动路由到完整玩法系统。
  ///
  /// 【它解决什么问题】离线模式下玩家输入「去打魁地奇」「找哈利决斗」这类
  /// 自然语言时，此前只被 P6 后果引擎归类为「运动/社交」做数值加减，
  /// 完整的比赛/决斗/禁林/宠物玩法永远触发不了——玩法系统只认斜杠指令。
  /// 本方法在离线回合入口做意图识别，命中即把整回合交给对应玩法函数
  /// （时间/精力/奖励/叙事全由玩法系统结算并写好选项）。
  ///
  /// 【匹配纪律】只匹配足够独特的关键词（魁地奇/禁林/决斗/宠物互动），
  /// 宁可漏判落回 P6 数值后果，不可误判把无关行动劫持进玩法系统。
  /// 选项面板生成的玩法入口（action 带 [kGameplayActionPrefix] 标记）由
  /// `processChoice` 先解析成自然文本，再走这里的同一套关键词路由——
  /// 两条入口共用一份判定，行为天然一致。
  ///
  /// 【为什么是 public】触发方在 `GameNarrativeMixin._runOfflineQuickTurn`，
  /// 实现在本 mixin。Dart 的 mixin 私有成员跨 mixin 不可见，因此方法对外
  /// 可见、但只在离线回合入口调用，AI 路径与斜杠指令路径都不经过这里。
  @override
  bool tryRouteGameplayIntent(String action) {
    final a = action.trim();
    if (a.isEmpty) return false;

    // 1) 魁地奇：词足够独特，出现即视为参赛意图。
    if (a.contains('魁地奇')) {
      playQuidditch();
      return true;
    }

    // 2) 禁林：词独一无二，直接进完整探险。
    if (a.contains('禁林')) {
      exploreForbiddenForest();
      return true;
    }

    // 3) 决斗：决斗/切磋/比试/对练 都是「开打」意图；但「切磋功课/对练咒语」
    //    这类学习语境不算（交回 P6 后果引擎按学习结算）。
    //    若行动里点名了已认识 NPC，就挑战那个人，否则随机挑一个在校生。
    if (_containsAny(a, const ['决斗', '切磋', '比试', '对练']) &&
        !_containsAny(a, const ['功课', '学习', '复习', '读书', '论文', '作业'])) {
      duelNpc(_duelTargetFromAction(a));
      return true;
    }

    // 4) 宠物互动：已有宠物 + 明确互动意图（喂/玩/训练/逗/陪/撸/抱）。
    //    购买/商店意图不路由（那是想买宠物，不是和已有宠物互动）。
    final p = player;
    final petName = (p?.petName?.isNotEmpty ?? false) ? p!.petName! : null;
    if (petName != null) {
      final mentionsPet =
          a.contains('宠物') || (petName != '宠物' && a.contains(petName));
      final wantsInteraction =
          _containsAny(a, const ['喂', '玩', '训练', '逗', '陪', '互动', '撸', '抱']);
      final isShopping =
          _containsAny(a, const ['买', '购买', '商店', '挑选', '领养']);
      if (mentionsPet && wantsInteraction && !isShopping) {
        if (_containsAny(a, const ['喂', '吃'])) {
          petInteract('喂食');
        } else if (_containsAny(a, const ['训练', '练'])) {
          petInteract('训练');
        } else {
          petInteract('玩耍');
        }
        return true;
      }
    }

    return false;
  }

  /// 从行动文本里提取决斗目标（已认识的在读 NPC）；没点名返回 null（随机）。
  String? _duelTargetFromAction(String action) {
    for (final npc in npcRegistry.values) {
      if (npc.name.isEmpty) continue;
      if (action.contains(npc.name)) return npc.name;
    }
    return null;
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final n in needles) {
      if (text.contains(n)) return true;
    }
    return false;
  }
}

/// P7 玩法入口指令前缀（选项面板生成的玩法选项专用标记）。
///
/// 选项的 action 形如 `@@gameplay:quidditch`，点击后由 `processChoice`
/// 在分发之前解析成可读自然文本（见 `kGameplayActionToText`），再走
/// `tryRouteGameplayIntent` 的同一套关键词路由。标记本身绝不出现在
/// 叙事 / Prompt / 存档 / 记忆里；`pickAutoAdvanceChoice` 用它把玩法
/// 入口从「自动推进」候选里排除（玩法是玩家主动选择的出口）。
const String kGameplayActionPrefix = '@@gameplay:';

/// 玩法入口标记 → 可读自然行动（供 processChoice 解析后当作玩家行动）。
const Map<String, String> kGameplayActionToText = {
  'quidditch': '参加魁地奇训练赛，骑着扫帚为学院争取胜利',
  'duel': '到决斗场地找一位实力相当的同学来一场巫师决斗，点到为止',
  'forest': '前往禁林边缘探险，小心采集魔法材料',
  'pet_feed': '拿出食物给宠物喂食，增进与它的羁绊',
  'pet_play': '陪宠物玩耍互动，增进与它的羁绊',
  'pet_train': '带宠物做一轮训练，增进与它的羁绊',
};
