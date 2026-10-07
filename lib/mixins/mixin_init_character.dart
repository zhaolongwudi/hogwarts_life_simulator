import 'dart:async';
import '../prompts/narrative_prompts.dart';
import '../providers/app_provider.dart';
import '../models/game_systems.dart';
import '../data/wand_data.dart';
import '../data/game_config_rules.dart';
import '../data/pet_data.dart';
import '../data/pet_narrative_config.dart';
import '../data/opening_scene_data.dart';
import '../data/era_data.dart';
import '../data/trait_data.dart';
import '../models/player.dart';
import '../utils/crash_logger.dart';
import '../providers/game_provider_base.dart';
import '../utils/debug_log.dart';

/// 角色生成与开场族（第十一轮 r11-1 拆分自 mixin_init.dart）。
///
/// 覆盖：出生年份 / 初始特质掷骰与加成 / 开场场景生成 / 宠物短描述 / 起点文案。
mixin GameInitCharacterMixin on GameProviderBase {
  String calculateBirthYear() {
    // 入学时11岁：出生年份 = 时代入学年份 - 11
    return (startYearForEra(appProvider.era) - 11).toString();
  }

  /// 时代对应的入学年份（游戏开始年份）

  int startYearForEra(Era era) => eraDefByEra(era).startYear;

  String _eraLabelShort(Era era) => eraDefByEra(era).shortLabel;

  // ==================== 开局特质抽取（软保底） ====================

  /// 抽取 3 个开局特质，稀有度软保底

  List<TraitDef> rollStartingTraits() {
    final byRarity = traitsByRarity();
    final commons = byRarity['common'] ?? [];
    final rares = byRarity['rare'] ?? [];
    final legendaries = byRarity['legendary'] ?? [];

    final picked = <TraitDef>[];
    final usedIds = <String>{};
    int pity = 0; // 连续未出稀有/传说的次数

    while (picked.length < 3) {
      // 软保底：连续未出高稀有度时提升概率
      final pityBoost =
          (pity ~/ TraitRarityWeights.pityThreshold) *
          TraitRarityWeights.pityBonus;
      final legendaryP = TraitRarityWeights.legendaryBase + pityBoost * 0.5;
      final rareP = TraitRarityWeights.rareBase + pityBoost;

      final roll = random.nextDouble();
      String rarity;
      if (roll < legendaryP && legendaries.isNotEmpty) {
        rarity = 'legendary';
      } else if (roll < legendaryP + rareP && rares.isNotEmpty) {
        rarity = 'rare';
      } else {
        rarity = 'common';
      }

      final pool = switch (rarity) {
        'legendary' => legendaries,
        'rare' => rares,
        _ => commons,
      };
      final available = pool.where((t) => !usedIds.contains(t.id)).toList();
      if (available.isEmpty) {
        // 该稀有度已抽完，回退到普通
        final fallback = commons.where((t) => !usedIds.contains(t.id)).toList();
        if (fallback.isEmpty) break;
        final t = fallback[random.nextInt(fallback.length)];
        picked.add(t);
        usedIds.add(t.id);
        continue;
      }

      final trait = available[random.nextInt(available.length)];
      picked.add(trait);
      usedIds.add(trait.id);
      if (rarity == 'common') {
        pity++;
      } else {
        pity = 0;
      }
    }
    return picked;
  }

  /// 应用特质属性加成

  void applyTraitBonuses(List<TraitDef> traits) {
    final p = player;
    if (p == null) return;
    for (final t in traits) {
      t.attributeBonus.forEach((key, bonus) {
        // energy/health 等是顶层字段，attributes 是技能属性
        switch (key) {
          case 'energy':
            p.energy = (p.energy + bonus).clamp(0, 100);
            break;
          case 'health':
            p.health = (p.health + bonus).clamp(0, 100);
            break;
          case 'moral':
            p.playerReputation.add('moral', bonus);
            break;
          case 'spirit':
            p.spirit = (p.spirit + bonus).clamp(0, 100);
            break;
          case 'social':
            // social 既是属性也是声望，这里加到属性
            p.attributes['social'] = ((p.attributes['social'] ?? 50) + bonus)
                .clamp(0, 100);
            break;
          default:
            p.attributes[key] = ((p.attributes[key] ?? 50) + bonus).clamp(
              0,
              100,
            );
        }
      });
      // 节俭特质：初始加隆略多
      if (t.id == 'thrifty') {
        p.galleons += 100;
      }
    }
    if (traits.isNotEmpty) {
      notifications.add('✨ 你获得了特质：${traits.map((t) => t.name).join('、')}');
    }
  }

  /// 特质叙事提示（注入系统提示词）

  String traitNarrativeHints() {
    final p = player;
    if (p == null || p.traits.isEmpty) return '';
    final hints = p.traits
        .map((id) => traitById(id))
        .where((t) => t != null && t.narrativeHint.isNotEmpty)
        .map((t) => t!.narrativeHint)
        .toList();
    if (hints.isEmpty) return '';
    return '【出身特质】${hints.join('；')}';
  }

  // ==================== 生成开场场景 ====================

  Future<void> generateOpeningScene() async {
    if (player == null) return;

    final p = player!;
    final wandData = p.wandId != null ? wandById(p.wandId!) : null;
    final wandInfo = wandData != null
        ? '${wandData.name}（${wandData.wood}·${wandData.core}·${wandData.length}）'
        : '尚未选择的魔杖';

    final petInfo = _buildPetDescriptionShort(p);
    final startPoint = _buildStartPointNarrative();

    // 只收集已设定字段，减少 token 噪声
    final profile = <String>[];
    profile.add(
      '姓名：${p.name}｜11岁｜${bloodStatusLabel(p.bloodType)}｜${p.birthLocation}',
    );
    if (p.personalityTraits.isNotEmpty) {
      profile.add('性格：${p.personalityTraits.join('、')}');
    }
    if (p.birthIdentity != null && p.birthIdentity!.isNotEmpty) {
      profile.add('出身：${p.birthIdentity}');
    }
    if (p.appearance != null && p.appearance!.isNotEmpty) {
      profile.add('外貌：${p.appearance}');
    }
    if (p.familyBackground != null && p.familyBackground!.isNotEmpty) {
      profile.add('家族：${p.familyBackground}');
    }
    if (p.childhoodExperiences.isNotEmpty) {
      profile.add('童年：${p.childhoodExperiences.join('；')}');
    }
    if (p.beliefs != null && p.beliefs!.isNotEmpty) {
      profile.add('信念：${p.beliefs}');
    }
    final resolvedAptitude = resolveMagicAptitude(p);
    if (resolvedAptitude.isNotEmpty) {
      profile.add('资质：$resolvedAptitude');
    }
    if (p.initialTalent != null && p.initialTalent!.isNotEmpty) {
      profile.add('天赋：${p.initialTalent}');
    }
    if (p.housePreference != null && p.housePreference!.isNotEmpty) {
      profile.add('学院倾向：${p.housePreference}');
    }
    if (p.traits.isNotEmpty) {
      final traitNames = p.traits
          .map((id) => traitById(id)?.name)
          .where((n) => n != null)
          .join('、');
      if (traitNames.isNotEmpty) profile.add('出身特质：$traitNames');
    }
    profile.add('时代：${_eraLabelShort(appProvider.era)}');
    profile.add('魔杖：$wandInfo');
    profile.add('宠物：$petInfo');

    final wandSourceLine =
        wandSources[kDefaultWandSourceId]?.narrativeLine ??
        '玩家的魔杖是奥利凡德先生在对角巷亲手选中的（魔杖选择巫师），绝不是捡来的木棍、祖传物品、或自己制作。';
    final wandDetail = wandData != null
        ? '${wandData.wood}木·${wandData.core}·${wandData.length}'
        : '指定魔杖';
    final prompt = buildOpeningNarrativePrompt(
      profileLine: profile.join('｜'),
      startPoint: startPoint,
      wandDetail: wandDetail,
      wandSourceLine: wandSourceLine,
    );

    if (router == null || !router!.hasNarrativeService) {
      currentNarrative =
          '${p.name}，你在${p.birthLocation}长大，等待来自霍格沃茨的信已经等了很久。\n\n📅 ${worldState.timestamp}\n\n魔法世界的大门即将为你打开。';
      choices = [
        GameChoice(text: '等待猫头鹰送来的信', action: '等待猫头鹰送来的信'),
        GameChoice(text: '收拾行李，准备出发', action: '收拾行李，准备出发'),
        GameChoice(text: '再检查一遍霍格沃茨的入学清单', action: '再检查一遍霍格沃茨的入学清单'),
      ];
      appendRecentTurn(currentNarrative);
      return;
    }

    try {
      final response = await callDeepSeek(prompt);
      parseResponse(response.content);
      // 开场的选项也走独立生成：system prompt 与开场 prompt 现在都明令
      // 「本轮不输出选项」，两边口径一致才不会让模型随机决定写不写
      // （以前是 system 要选项、user 说别写，于是 BUG-H 时有时无）。
      // 独立生成失败时保留 parseResponse 兜底出来的那几个。
      try {
        final openingChoices = await generateChoicesSeparately(
          currentNarrative,
        );
        if (openingChoices.isNotEmpty) choices = openingChoices;
      } catch (e) {
        debugLog('⚠️ 开场选项独立生成失败，沿用解析/兜底选项: $e');
      }
      accumulateForSummary(currentNarrative);
      appendRecentTurn(currentNarrative);
      notifyListeners();
      unawaited(autoSave());
    } catch (e) {
      error = e.toString();
      currentNarrative = '${p.name}，故事即将开始。请稍候，魔法正在酝酿。';
      choices = [GameChoice(text: '继续', action: '继续')];
      appendRecentTurn(currentNarrative);
      notifyListeners();
      unawaited(autoSave());
      unawaited(
        CrashLogger.instance.record(
          e,
          StackTrace.current,
          screen: 'generateOpeningScene',
          extra: 'player=${p.name}, era=${appProvider.era.name}',
        ),
      );
    }
  }

  // ==================== 开场辅助：宠物描述（短版，省token） ====================

  String _buildPetDescriptionShort(Player p) {
    final petId = p.petId;
    final petName = p.petName ?? '';
    if (petId == null) return '未饲养';
    // R8：优先使用 PetDef 数据层 + PetNarrativeConfig（去掉多处 switch/kyuubi 特判）
    final def = petById(petId);
    final cfg = petNarrativeConfig(petId);
    if (def != null) {
      final ab = def.abilities.take(3).join('·');
      final tf = cfg.bondGatedTransform
          ? '·可化人形（羁绊≥${cfg.specialInteractionBondThreshold}触发）'
          : (def.canTransform ? '·可化人形' : '');
      final nm = petName.isNotEmpty ? petName : def.name;
      return '$nm（${def.species}$tf，能力：$ab）';
    }
    return petName.isEmpty ? '$petName（特殊伙伴）' : '特殊伙伴';
  }

  // ==================== 开场辅助：开场剧情起点文案 ====================

  String _buildStartPointNarrative() {
    // R2：查表，替代 5-case switch
    return openingSceneById(openingScene).startNarrative;
  }
}
