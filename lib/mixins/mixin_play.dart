import '../data/item_data.dart';
import 'mixin_play_arena.dart';
import 'mixin_play_tools.dart';
import '../data/pet_data.dart';
import '../data/pet_narrative_config.dart';
import '../data/spell_data.dart';
import '../data/collectible_data.dart';
import '../data/club_minigames_data.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';
import '../utils/debug_log.dart';

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
  void addCollectibleSighting(StringBuffer buf) {
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
