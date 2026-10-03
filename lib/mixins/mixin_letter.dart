/// P13 猫头鹰来信系统：让「世界那边的人」在离线日常里主动惦记你。
///
/// 【抽取说明 · 阶段2】全部「选信 + 落款 + 结算」逻辑已迁入独立领域类
/// `systems/letter_system.dart` 的 [LetterSystem]。本 mixin 只做薄委托：
///  1. 持有 LetterSystem 实例，把 GameProviderBase 的状态/能力
///     适配成 LetterDeps 窄接口；
///  2. 维持 GameProviderBase 抽象契约（maybeTriggerLetter 等），
///     委托给 LetterSystem —— 测试与叙事管线的调用路径零改动。
library;

import 'package:flutter/foundation.dart';

import '../data/letter_data.dart';
import '../models/game_systems.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';
import '../systems/letter_system.dart';

/// P13 猫头鹰来信 mixin。挂在 [GameProviderBase] 上。
mixin GameLetterMixin on GameProviderBase {
  LetterSystem? _letterSystem;

  /// 懒初始化的来信领域系统。
  LetterSystem get letterSystem =>
      _letterSystem ??= LetterSystem(_LetterDepsAdapter(this));

  /// 正待回的信 id。
  String? get pendingLetterId => player?.pendingLetterId;

  /// 是否有待回声的信。
  @override
  bool get hasPendingLetter => pendingLetterId != null;

  @override
  String maybeTriggerLetter({int? seed}) =>
      letterSystem.maybeTriggerLetter(seed: seed);

  @override
  List<GameChoice> letterReplyChoicesForPending() =>
      letterSystem.letterReplyChoicesForPending();

  @override
  String tryResolveLetterReplyChoice(String action) =>
      letterSystem.tryResolveLetterReplyChoice(action);

  @visibleForTesting
  NPC? letterSenderFor(LetterDef def) => letterSystem.letterSenderFor(def);
}

/// 把 GameProviderBase 适配成 LetterSystem 的窄依赖接口。
///
/// 只暴露 LetterSystem 需要的成员，领域类不再与整个 Provider
/// 状态空间耦合（阶段2 抽取的核心收益）。
class _LetterDepsAdapter implements LetterDeps {
  _LetterDepsAdapter(this._host);
  final GameProviderBase _host;

  @override
  bool get letterEnabled => _host.appProvider.letterEnabled;

  @override
  bool get clubEnabled => _host.appProvider.clubEnabled;

  @override
  Player? get player => _host.player;

  @override
  Map<String, NPC> get npcRegistry => _host.npcRegistry;

  @override
  int get currentMonth => _host.worldState.time.month;

  @override
  int get currentDayIndex => _host.worldState.time.absoluteDayIndex;

  @override
  List<String> get notifications => _host.notifications;

  @override
  int get turnCount => _host.turnCount;

  @override
  bool get hasPendingHappenstance => _host.hasPendingHappenstance;

  @override
  bool get hasPendingCompanionClimax => _host.hasPendingCompanionClimax;

  @override
  void addHouseCupPoints(int pts, String reason) =>
      _host.addHouseCupPoints(pts, reason);

  @override
  void updateNpcAffection(String npcId, int delta,
          {required String reason, bool quiet = false}) =>
      _host.updateNpcAffection(npcId, delta, reason: reason, quiet: quiet);

  @override
  String joinClub(String clubId) => _host.joinClub(clubId);

  @override
  String formatDate() => _host.worldState.time.formatDate();
}
