// v4 批次34 NPC 本地聊天词库加厚（P0 续）行为测试。
//
// 覆盖四件事:
//  - 话题感知:问候/食物等消息命中专属词库,不再是学院套话;
//  - 性格立场:勇敢NPC聊禁林用"敢闯"口吻,区别于通用词库;
//  - 关系历史:玩家与NPC有共同经历时,兜底偶尔引用那段记忆;
//  - 不变量:未传 player 不触发关系回声,冷淡/友好档仍互斥。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/npc_chat_wordbank.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/services/npc_chat_service.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  NpcChatService makeService() => NpcChatService(appProvider: AppProvider());

  NPC npc({
    String house = 'Gryffindor',
    int affection = 50,
    List<String> personality = const [],
  }) =>
      NPC(id: 'n1', name: '测试', house: house, affection: affection, personality: personality);

  group('P0 续 · NPC 本地聊天词库加厚', () {
    test('话题感知:问候消息命中专属词库,而非学院套话', () {
      final s = makeService();
      final r = s.localResponseFor(npc(), '你好');
      expect(kNpcTopicPool['greeting']!['warm']!, contains(r),
          reason: '问候应命中 greeting 专属词库');
    });

    test('话题感知:食物消息命中专属词库', () {
      final s = makeService();
      final r = s.localResponseFor(npc(), '食堂有什么好吃的吗？');
      expect(kNpcTopicPool['food']!['warm']!, contains(r),
          reason: '食物应命中 food 专属词库');
    });

    test('性格立场:勇敢NPC聊禁林用"敢闯"口吻,区别于通用词库', () {
      final s = makeService();
      final bold = s.localResponseFor(npc(personality: ['勇敢']), '禁林里有危险吗');
      final generic = s.localResponseFor(npc(personality: ['沉稳']), '禁林里有危险吗');
      expect(kNpcStanceTopicPool['bold']!['forest']!['warm']!, contains(bold),
          reason: '勇敢性格应命中「敢闯」定制口吻');
      expect(kNpcTopicPool['forest']!['warm']!, contains(generic),
          reason: '非定制性格应走通用禁林词库');
      expect(bold, isNot(equals(generic)), reason: '定制口吻与通用口吻应不同');
    });

    test('关系历史回声:玩家与NPC有共同经历时会偶尔引用', () async {
      final gp = await makeGame(offlineQuickMode: true);
      final p = gp.player!;
      p.relationships['n1'] = Relationship(
        targetId: 'n1',
        targetName: '测试',
        relationType: '挚友',
        level: 80,
        history: const ['一起击败过禁林的巨型蜘蛛'],
      );
      final s = makeService();
      final joined = <String>[];
      for (var i = 0; i < 9; i++) {
        joined.add(s.localResponseFor(npc(), '今天过得怎么样', player: p));
      }
      expect(joined.join('\n'), contains('那件事，我一直记着'),
          reason: '多轮抽样里至少一次应引用关系历史');
    });

    test('未传player时关系回声不触发,回复仍非空', () {
      final s = makeService();
      final r = s.localResponseFor(npc(), '今天天气不错');
      expect(r.trim(), isNotEmpty);
    });

    test('话题命中不破坏既有不变量:冷淡/友好档仍互斥', () {
      final s = makeService();
      final cold = <String>{
        for (var i = 0; i < 4; i++) s.localResponseFor(npc(affection: -50), 'hi-$i'),
      };
      final warm = <String>{
        for (var i = 0; i < 4; i++) s.localResponseFor(npc(affection: 50), 'hi-$i'),
      };
      expect(cold.intersection(warm), isEmpty,
          reason: 'Q14:不同好感档回复不该重复');
    });
  });

  group('P3 · NPC 聊天可选 AI 润色门控', () {
    test('未开启润色开关时,本地兜底回复原文不被改写', () async {
      final service = makeService();
      final npcx = npc();
      final text = '喂,你过来干什么？';
      // 无 AI router / 未开润色 → 原文返回
      expect(service.polishLocalReplyForTest(npcx, text),
          same(text),
          reason: '门控未开启时不得触发润色调用');
    });

    test('开启润色但无 AI 服务(未配 Key)时安全回退原文', () async {
      final app = AppProvider();
      await app.setNarrativePolishEnabled(true);
      final service = NpcChatService(appProvider: app);
      final npcx = npc();
      final text = '禁林那边,我劝你别去。';
      expect(service.polishLocalReplyForTest(npcx, text), same(text),
          reason: '无 AI 服务时润色必须安全回退原文');
    });
  });
}