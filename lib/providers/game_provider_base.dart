import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'app_provider.dart';
import '../models/player.dart';
import '../models/npc.dart';
import '../models/world_state.dart';
import '../models/game_systems.dart';
import '../models/long_term_memory.dart';
import '../services/save_service.dart';
import '../services/npc_chat_service.dart';
import '../services/ai_router.dart';

/// GameProviderBase: 字段承载抽象基类。
/// 必须放在 `with` 6个Mixin 之前被 6个Mixin 的 `on GameProviderBase` 引用，
/// 从而打破 Dart 3 中 recursive_interface_inheritance 继承环。
abstract class GameProviderBase extends ChangeNotifier {
  // ====== 依赖注入（构造时提供） ======
  AppProvider get appProvider;
  AiRouter? get router;
  set router(AiRouter? v);
  SaveService get saveService;
  Random get random;
  NpcChatService get chatService;

  // ====== 预编译正则（避免循环内重复编译） ======
  static final RegExp reChoiceOption = RegExp(
    r'^\s*(?:[A-Ea-e]|[Ａ-Ｅａ-ｅ]|[\d]{1,2}|[一二三四五六七八九十]{1,3})\s*(?:[\.\．、\)）:：])\s*',
  );
  static final RegExp reMultiNewline = RegExp(r'\n{3,}');
  static final RegExp reAffectionSection = RegExp(r'【好感(?:度)?变化?】[\s\S]*?(?=【|$)');
  static final RegExp reReputationSection = RegExp(r'【声望变化?】[\s\S]*?(?=【|$)');
  static final RegExp reChoiceMultiLine = RegExp(
    r'(?:^|\n)\s*(?:[A-Ea-e]|[Ａ-Ｅａ-ｅ]|[\d]{1,2}|[一二三四五六七八九十]{1,3})\s*(?:[\.\．、\)）:：])\s+\S',
    multiLine: true,
  );

  // ====== 核心状态字段（已从私有 _xxx public 化，Mixin 需要直接访问） ======
  Player? player;
  WorldState worldState = WorldState();
  final Map<String, NPC> npcRegistry = {};
  LongTermMemory memory = LongTermMemory();

  String currentNarrative = '';
  String narrativeSummary = '';
  String pendingSummary = '';
  final List<String> recentTurns = [];
  static const int maxRecentTurns = 12;
  List<GameChoice> choices = [];
  String? commandResult;
  bool isLoading = false;
  bool isInitializing = false;
  String? error;
  int turnCount = 0;
  String lastPlayerAction = '';
  String? systemPrompt;
  String loadingStage = '';
  List<String> lastAffectionSections = [];
  final List<String> notifications = [];

  int totalPromptTokens = 0;
  int totalCompletionTokens = 0;
  int totalTokens = 0;
  int lastRoundTokens = 0;
  int apiCalls = 0;
  int gameWeek = 1;
  int lastSchoolYearStart = 0;
  String? pendingAnchorDirective;
  String openingScene = 'station';
}
