/// P12 宠物小插曲系统：让宠物在离线的世界里偶尔有自己的生活。
///
/// 【它解决什么问题】宠物此前只在玩家主动 `/宠物 喂食/玩耍/训练` 时存在；不互动
/// 的时候，这只养在身边的伙伴就像从世界里消失了。本层让宠物偶尔在离线日常里
/// 冒出来一下——既有门槛低、会重播的日常小插曲（给一点羁绊，暖场不做主角），
/// 也有亲和跨过 25/55/85 三道坎时各演一次的羁绊里程碑（演过不重播）。它让宠物
/// 「被看见」，也和奇遇/羁绊小剧场一起把「世界在动」补得更丰满。
///
/// 数据全在 `pet_story_data.dart`；本 mixin 只做三层事：
///   ① 命中一段可播的插曲（日常候选 / 最高未播里程碑优先）`maybeTriggerPetStory`；
///   ② 结算（羁绊/加隆/学院杯/声望）；
///   ③ 冷却与互斥（不和奇遇/羁绊抢戏，自带冷却）。
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/house_data.dart';
import '../data/pet_data.dart';
import '../data/pet_story_data.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';

/// P12 宠物小插曲 mixin。挂在 [GameProviderBase] 上。
mixin GamePetStoryMixin on GameProviderBase {
  bool get _petStoryOn => appProvider.petStoryEnabled;

  /// 已播过的里程碑插曲 id（保 once-only）。
  List<String> get petStoriesPlayed => player?.petStoriesPlayed ?? const [];

  /// 最近一次播插曲的回合号（冷却用）。
  int get petLastStoryTurn => player?.petLastStoryTurn ?? -1;

  /// 已拥有一只宠物。
  bool get _hasPet => player?.petId != null;

  /// 对当前可开演的插曲做门控过滤。
  ///
  /// [milestonesOnly] 为 true 时只看还没播过、亲和已达门槛的里程碑（供最高优先
  /// 挑选）；false 时为日常候选（亲和高一点，越不容易腻）。
  @visibleForTesting
  List<PetStoryDef> eligiblePetStories({bool milestonesOnly = false}) {
    final p = player;
    if (p == null) return const [];
    final played = petStoriesPlayed.toSet();
    final out = <PetStoryDef>[];
    for (final s in kPetStories) {
      if (s.milestone != milestonesOnly) continue;
      if (s.minBond > p.petBond) continue;
      if (s.milestone && played.contains(s.id)) continue; // 里程碑只播一次
      if (s.petIds.isNotEmpty && !s.petIds.contains(p.petId)) continue;
      out.add(s);
    }
    return out;
  }

  /// 命中一段本回合要播的插曲；无法触发返回空串。
  ///
  /// 优先级：① 未播且亲和已达标的最**高**门槛里程碑（先把它补上，别和日常抢）；
  /// ② 否则日常候选里加权（亲和高者更常腻歪）。全程受开关/冷却/互斥门控。
  @override
  String maybeTriggerPetStory() {
    if (!_petStoryOn) return '';
    final p = player;
    if (p == null || !_hasPet) return '';
    // 有在等的奇遇/羁绊最终幕先讲完，不让小事抢戏。
    if (hasPendingHappenstance) return '';
    if (hasPendingCompanionClimax) return '';
    // 冷却：避免连续几回合都在涌小插曲。
    final turn = turnCount;
    if (turn - petLastStoryTurn < kPetStoryCooldownTurns) return '';

    // 1) 未播的里程碑：亲和越高优先。
    final milestones = eligiblePetStories(milestonesOnly: true);
    PetStoryDef? story;
    if (milestones.isNotEmpty) {
      milestones.sort((a, b) => b.minBond.compareTo(a.minBond));
      story = milestones.first;
    } else {
      // 2) 日常候选：亲和越高越腻歪（加权随机）。
      final daily = eligiblePetStories(milestonesOnly: false);
      if (daily.isNotEmpty) {
        daily.sort((a, b) => a.minBond.compareTo(b.minBond)); // 低门槛优先稳定手感
        final pick = daily[Random().nextInt(daily.length)];
        story = pick;
      }
    }
    if (story == null) return '';

    // 记冷却 + 里程碑标记 once。
    p.petLastStoryTurn = turn;
    if (story.milestone && !p.petStoriesPlayed.contains(story.id)) {
      p.petStoriesPlayed = List<String>.from(p.petStoriesPlayed)..add(story.id);
    }

    // 结算。
    _applyStoryEffect(p, story);

    final house = houseDisplayName(p.house ?? '', fallback: '霍格沃茨');
    final petName = (p.petName != null && p.petName!.isNotEmpty)
        ? p.petName!
        : (petById(p.petId!)?.name ?? '宠物');
    final buf = StringBuffer();
    buf.writeln('———————🐾 与$petName 的一点日常🐾———————');
    buf.writeln(fillPetStoryText(story.scene, house: house, pet: petName));
    final notes = _storyNotes(p, story);
    if (notes.isNotEmpty) {
      buf.writeln();
      buf.writeln('（$petName${notes.join('、')}）');
    }
    return buf.toString().trim();
  }

  void _applyStoryEffect(Player p, PetStoryDef story) {
    final e = story.effect;
    if (e.petBond != 0) p.petBond = (p.petBond + e.petBond).clamp(0, 100);
    if (e.galleons > 0) p.galleons += e.galleons;
    if (e.housePoints > 0) addHouseCupPoints(e.housePoints, '宠物小插曲·${story.id}');
    if (e.reputationDim != null && e.reputationValue != 0) {
      p.playerReputation.add(e.reputationDim!, e.reputationValue);
    }
  }

  List<String> _storyNotes(Player p, PetStoryDef story) {
    final e = story.effect;
    final notes = <String>[];
    if (e.petBond != 0) notes.add(' 羁绊 +${e.petBond}');
    if (e.galleons > 0) notes.add(' ${e.galleons} 加隆');
    if (e.housePoints > 0) notes.add(' 学院杯积分 +${e.housePoints}');
    if (e.reputationDim != null && e.reputationValue != 0) {
      notes.add(' ${p.playerReputation.labelOf(e.reputationDim!)} +${e.reputationValue}');
    }
    return notes;
  }
}