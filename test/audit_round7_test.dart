// 第七轮修复的行为测试。
//
// 与仓库里大量「读源码查子串」的断言不同，这里每一条都真的把代码跑一遍：
// AI 异常路径起一个本地 HTTP 服务喂畸形响应，记忆/地点/学院判定直接调用
// 生产函数。改坏了会红，改对了不会因为重命名一个变量就红。
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/data/house_data.dart';
import 'package:hogwarts_life_simulator/data/locations.dart';
import 'package:hogwarts_life_simulator/models/long_term_memory.dart';
import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/services/ai_router.dart';
import 'package:hogwarts_life_simulator/services/deepseek_service.dart';
import 'package:hogwarts_life_simulator/utils/narrative_section_parser.dart';

/// 一个假的 AI 端点：记录被打了几次、每次都返回什么。
class _FakeAiServer {
  _FakeAiServer._(this._server);

  final HttpServer _server;
  int hits = 0;

  int get port => _server.port;

  static Future<_FakeAiServer> start({
    required int status,
    required String body,
    String contentType = 'application/json',
    Duration delay = Duration.zero,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeAiServer._(server);
    server.listen((request) async {
      fake.hits++;
      // 整段包 try/catch：故意拖慢的响应会在用例结束后才写回，
      // 那时 socket 已关，不吞掉就会变成「用例结束后才报错」的脏失败。
      try {
        await request.drain<void>();
        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
        request.response.statusCode = status;
        // 必须显式带 charset=utf-8：HttpResponse 默认按 latin1 写，
        // 中文正文会直接抛 Invalid argument (string)。
        request.response.headers.contentType =
            ContentType.parse('$contentType; charset=utf-8');
        request.response.write(body);
        await request.response.close();
      } catch (_) {
        // 连接被客户端/超时掐断，属预期。
      }
    });
    return fake;
  }

  Future<void> close() => _server.close(force: true);
}

/// 构造一个指向 [server] 的 DeepSeekService。
///
/// Dio 从外面注入（生产代码不传，走真实 Dio）——以前 `_dio` 是构造函数里
/// 硬编码的私有 final，这套异常路径根本没法测，于是「AI 返回 HTML 错误页」
/// 在仓库里连一条测试都没有。
DeepSeekService _serviceOn(_FakeAiServer server, {String key = 'test-key'}) {
  final cfg = AiConfig(
    provider: AiProvider.deepseek,
    apiKey: key,
    baseUrl: 'http://127.0.0.1:${server.port}',
    model: 'test-model',
  );
  return DeepSeekService(
    config: cfg,
    dio: Dio(BaseOptions(
      baseUrl: 'http://127.0.0.1:${server.port}',
      receiveTimeout: const Duration(seconds: 5),
    )),
  );
}

String _chatBody(String content) => jsonEncode({
      'choices': [
        {'message': {'content': content}}
      ],
      'usage': {'prompt_tokens': 1, 'completion_tokens': 1, 'total_tokens': 2},
    });

void main() {
  // ==================== P0-1：AI 响应体畸形 ====================
  group('AI 响应畸形（P0-1）', () {
    test('返回 HTML 错误页时归一为可重试异常，而不是当成 Key 失效', () async {
      // 免费额度耗尽 / 被 WAF 拦时，服务商会返回 200 + HTML 错误页。
      // 这条路径以前抛的是 NoSuchMethodError，绕过 on DioException 的归类，
      // 在路由层被当成不可重试异常 → 整个 Key 当场弃用。
      final server = await _FakeAiServer.start(
        status: 200,
        body: '<html><body>502 Bad Gateway</body></html>',
        contentType: 'text/html',
      );
      addTearDown(server.close);

      final service = _serviceOn(server);
      await expectLater(
        service.chatComplete(prompt: 'hi'),
        throwsA(isA<AiRetryableException>()),
      );
      expect(server.hits, 1);
    });

    test('模型返回空内容同样可重试（偶发空输出不该被放大成 Key 失效）',
        () async {
      final server = await _FakeAiServer.start(
        status: 200,
        body: _chatBody(''),
      );
      addTearDown(server.close);

      await expectLater(
        _serviceOn(server).chatComplete(prompt: 'hi'),
        throwsA(isA<AiRetryableException>()),
      );
    });

    test('choices 结构缺失也归一为可重试，不会抛裸异常', () async {
      final server = await _FakeAiServer.start(
        status: 200,
        body: jsonEncode({'error': 'upstream unavailable'}),
      );
      addTearDown(server.close);

      await expectLater(
        _serviceOn(server).chatComplete(prompt: 'hi'),
        throwsA(isA<AiRetryableException>()),
      );
    });

    test('401 仍然是不可重试——Key 错了就该停下来让玩家改', () async {
      final server = await _FakeAiServer.start(
        status: 401,
        body: jsonEncode({'error': {'message': 'invalid api key'}}),
      );
      addTearDown(server.close);

      await expectLater(
        _serviceOn(server).chatComplete(prompt: 'hi'),
        throwsA(isA<AiNonRetryableException>()),
      );
    });

    test('正常响应照常解析出内容', () async {
      final server = await _FakeAiServer.start(
        status: 200,
        body: _chatBody('你推开教室的门。'),
      );
      addTearDown(server.close);

      final result = await _serviceOn(server).chatComplete(prompt: 'hi');
      expect(result.content, '你推开教室的门。');
    });

    test('Dio 超时被标记为 isTimeout（路由层据此换 Key 而不是干等重试）',
        () async {
      // 服务端故意拖 2 秒，客户端只等 300ms。
      final server = await _FakeAiServer.start(
        status: 200,
        body: _chatBody('迟到的回复'),
        delay: const Duration(seconds: 2),
      );
      addTearDown(server.close);

      final service = _serviceOn(server);
      final dio = Dio(BaseOptions(
        baseUrl: 'http://127.0.0.1:${server.port}',
        receiveTimeout: const Duration(milliseconds: 300),
      ));
      final fast = DeepSeekService(config: AiConfig(
        provider: AiProvider.deepseek,
        apiKey: 'k',
        baseUrl: 'http://127.0.0.1:${server.port}',
        model: 'm',
      ), dio: dio);
      expect(service, isNotNull);

      Object? thrown;
      try {
        await fast.chatComplete(prompt: 'hi');
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<AiRetryableException>());
      expect((thrown! as AiRetryableException).isTimeout, isTrue,
          reason: '超时必须带 isTimeout 标记，否则路由层会再花 35 秒重试同一把 Key');
    });
  });

  // ==================== P0-3：路由、超时与熔断 ====================
  group('AI 路由超时预算（P0-3）', () {
    test('全局超时容得下单个 Key 的完整惩罚序列', () {
      // 以前 narrative 写死 75 秒，而单 Key 的惩罚序列是
      // 35 + 2 + 35 + 4 + 35 = 111 秒 —— 第一个坏 Key 就能把时间耗光，
      // 后面的 Key 一次都轮不到，熔断也永远记不满 3 次。
      final single = AiRouter.globalTimeoutFor(AiScene.narrative, 1);
      expect(single.inSeconds, greaterThanOrEqualTo(41),
          reason: '1 个 Key 至少要有一份单 Key 预算（35s + 退避 6s）');
      expect(single, lessThanOrEqualTo(const Duration(seconds: 120)),
          reason: '也不能让玩家无限等');
    });

    test('Key 越多全局超时越长，但有上限', () {
      final one = AiRouter.globalTimeoutFor(AiScene.narrative, 1);
      final three = AiRouter.globalTimeoutFor(AiScene.narrative, 3);
      final many = AiRouter.globalTimeoutFor(AiScene.narrative, 10);
      expect(three, greaterThan(one), reason: '3 个 Key 该有 3 份预算');
      expect(many, lessThanOrEqualTo(const Duration(seconds: 120)));
    });

    test('摘要/闲聊的超时短于剧情', () {
      expect(AiRouter.globalTimeoutFor(AiScene.summary, 1),
          lessThan(AiRouter.globalTimeoutFor(AiScene.narrative, 1)));
    });
  });

  group('AI 故障转移与熔断（P0-3）', () {
    test('坏 Key 耗尽后切好 Key；第二次调用坏 Key 因熔断被直接跳过', () async {
      final bad = await _FakeAiServer.start(
        status: 500,
        body: jsonEncode({'error': {'message': 'server error'}}),
      );
      final good = await _FakeAiServer.start(status: 200, body: _chatBody('好'));
      addTearDown(bad.close);
      addTearDown(good.close);

      // 注意列表顺序：路由层有 `_roundRobinIndex`（每次调用前 +1），
      // 所以第一次调用是从 index 1 起步的——把坏 Key 放第二个，
      // 它才会先撞上去。这不是投机，正是生产里"多 Key 均匀分摊流量"的行为。
      final router = AiRouter(
        AiRouterConfig(
          narrativeProvider: AiProvider.deepseek,
          summaryProvider: AiProvider.deepseek,
          npcChatProvider: AiProvider.deepseek,
          choiceProvider: AiProvider.deepseek,
          fallbackOrder: const [AiProvider.deepseek],
        ),
        services: {
          AiProvider.deepseek: [
            _serviceOn(good, key: 'good-key'),
            _serviceOn(bad, key: 'bad-key'),
          ],
        },
      );

      final first = await router.chatComplete(
        scene: AiScene.narrative,
        prompt: '第一次',
      );
      expect(first.content, '好');
      expect(good.hits, 1);
      // 坏 Key 走完自己的重试（3 次尝试）后让位
      expect(bad.hits, 3);

      // 连续失败累计到阈值 → 熔断打开 → 第二次调用一次都不碰它
      final second = await router.chatComplete(
        scene: AiScene.narrative,
        prompt: '第二次',
      );
      expect(second.content, '好');
      expect(bad.hits, 3, reason: '熔断中的 Key 不该再被点卯');
      expect(good.hits, 2);
    });
  });

  // ==================== §3-D：声望区块被 AI 拆成两段 ====================
  group('声望解析（§3-D）', () {
    test('两个【声望变化】区块都要解析，不能只取第一个', () {
      // 好感侧早就改成 allMatches 了，声望侧一直是 firstMatch：
      // AI 先列主线再列支线时，第二个区块整段静默丢弃。
      const text = '''
【声望变化】
学术：+2
【好感度变化】
赫敏 +3
【声望变化】
战斗：+4
''';
      final deltas = extractReputationDeltas(text);
      expect(deltas.map((d) => d.dimension).toList(), ['学术', '战斗']);
      expect(deltas.first.delta, 2);
      expect(deltas.last.delta, 4);
    });

    test('兼容全角冒号、项目符号与全角加号', () {
      const text = '【声望变化】\n· 战斗：＋3\n  道德 +2';
      final deltas = extractReputationDeltas(text);
      expect(deltas.length, 2);
      expect(deltas.first.dimension, '战斗');
      expect(deltas.first.delta, 3);
    });

    test('没有声望区块时返回空列表，不抛异常', () {
      expect(extractReputationDeltas('今天什么都没发生'), isEmpty);
    });
  });

  // ==================== §3-F：学院 key 判空口径 ====================
  group('学院 key 归一化（§3-F）', () {
    test('未分院 / 空串 / AI 编的四院之外的词都不是有效学院', () {
      expect(normalizeHouseKey(null), isNull);
      expect(normalizeHouseKey(''), isNull);
      expect(normalizeHouseKey('   '), isNull);
      expect(normalizeHouseKey('阿兹卡班'), isNull,
          reason: 'AI 写出四院之外的名字时，不能被当成一支队伍写进年度榜');
    });

    test('四院 key 与大小写变体都能认出来', () {
      expect(normalizeHouseKey('Gryffindor'), 'Gryffindor');
      expect(normalizeHouseKey('gryffindor'), 'Gryffindor');
      expect(normalizeHouseKey(' Slytherin '), 'Slytherin');
      expect(normalizeHouseKey('Hufflepuff'), 'Hufflepuff');
      expect(normalizeHouseKey('Ravenclaw'), 'Ravenclaw');
    });
  });

  // ==================== §5.1：地点判定三套口径 ====================
  group('地点判定统一（§5.1）', () {
    test('细分教室与通用「教室」算同一处（父子地点）', () {
      // 以前 npcsInCurrentLocation 裸写 contains，两边都不归一：
      // 玩家在「霍格沃茨·教室」而教授在「霍格沃茨·变形术教室」时匹配不上，
      // 六位守教室的教授会从【在场】集体消失。
      expect(isSameLocation('霍格沃茨·变形术教室', '教室'), isTrue);
      expect(isSameLocation('变形术课', '教室'), isTrue);
      // 两间不同的细分教室不能互相冒充，否则占卜课上也能撞见麦格
      expect(isSameLocation('霍格沃茨·变形术教室', '霍格沃茨·占卜教室'), isFalse);
    });

    test('别名与主名互为同一处（黑湖 ↔ 霍格沃茨·场地）', () {
      expect(isSameLocation('霍格沃茨·场地', '黑湖'), isTrue);
      expect(isSameLocation('魁地奇球场', '草坪'), isTrue);
    });

    test('任一为空都算不在同一处', () {
      expect(isSameLocation('', '教室'), isFalse);
      expect(isSameLocation('教室', null), isFalse);
      expect(isSameLocation(null, null), isFalse);
    });

    test('真的不同地点不会误判', () {
      expect(isSameLocation('禁林', '霍格沃茨·走廊'), isFalse);
      expect(isSameLocation('对角巷', '霍格莫德村'), isFalse);
      // 父子树之外不做子串兜底，否则「图书馆」和「温室」也能凑成一对
      expect(isSameLocation('霍格沃茨·图书馆', '霍格沃茨·盥洗室'), isFalse);
    });
  });

  // ==================== §5.2：长程无界字段与读档容错 ====================
  group('存档与长程字段（§5.2）', () {
    test('一条损坏的记忆记录只丢它自己，不会清空整个记忆库', () {
      // 以前整包反序列化裹在一个 try/catch 里：一条记录缺 id → 抛异常 →
      // 返回空 LongTermMemory → 下次保存把「空」落盘固化，不可恢复。
      final mem = LongTermMemory.fromJson({
        'key_facts': [
          {'fact': '缺 id 的坏记录', 'importance': 5, 'timestamp': 't'},
          {'id': 'good', 'fact': '好记录', 'importance': 7, 'timestamp': 't'},
        ],
        'open_loops': [
          {'id': 'loop', 'description': '承诺', 'importance': 6},
        ],
        'world_events': [
          {'id': 'ev', 'title': '事件', 'description': '描述', 'importance': 6},
        ],
      });
      expect(mem.keyFacts.length, 1);
      expect(mem.keyFacts.single.fact, '好记录');
      expect(mem.openLoops.length, 1);
      expect(mem.worldEvents.length, 1);
    });

    test('关系锚的「秘密」「承诺」有容量上限', () {
      var mem = LongTermMemory();
      for (int i = 0; i < 20; i++) {
        mem = mem.upsertRelationshipAnchor(NpcRelationshipAnchor(
          npcId: 'npc',
          firstMeeting: '初见',
          secretsShared: ['秘密$i'],
          promisesExchanged: ['承诺$i'],
        ));
      }
      final anchor = mem.relationshipAnchors['npc']!;
      expect(anchor.secretsShared.length, kMaxRelationshipAnchorItems);
      expect(anchor.promisesExchanged.length, kMaxRelationshipAnchorItems);
      // 只留最新的
      expect(anchor.secretsShared.last, '秘密19');
      expect(anchor.secretsShared.first, '秘密8');
    });

    test('读档时日记条数收敛到上限', () {
      final diary = List.generate(
        kMaxDiaryEntries + 12,
        (i) => {
          'date': '1991年9月1日',
          'time': '9:00',
          'title': '第$i 篇',
          'content': '内容',
          'mood': '📖',
        },
      );
      final player = Player.fromJson({
        'name': '主角',
        'birth_year': '2008',
        'blood_status': 'halfblood',
        'birth_location': '伦敦',
        'diary': diary,
      });
      expect(player.diary.length, kMaxDiaryEntries);
    });

    test('存档缺 importance 时按原文重新判档，不把身份级事实降成日常', () {
      // 以前一律回填 5：一次结构变更丢了 importance 字段，
      // 「塞德里克死了」这类事实就被静默降成日常流水，永久失去永不淘汰豁免。
      // 现在读档侧与写入侧共用同一份 importanceForFact。
      final mem = LongTermMemory.fromJson({
        'key_facts': [
          {'id': 'a', 'fact': '塞德里克死了', 'timestamp': 't'},
          {'id': 'b', 'fact': '今天魔药课拿了优秀', 'timestamp': 't'},
        ],
      });
      final byId = {for (final f in mem.keyFacts) f.id: f};
      expect(byId['a']!.importance, kPersistentFactImportance);
      expect(byId['b']!.importance, 5);
      // 存档里写明的分数不受影响
      final kept = LongTermMemory.fromJson({
        'key_facts': [
          {'id': 'c', 'fact': '今天天气不错', 'importance': 10, 'timestamp': 't'},
        ],
      });
      expect(kept.keyFacts.single.importance, kIdentityFactImportance);
    });

    test('世界事件同分时淘汰结果稳定（不会每回合换一批）', () {
      var mem = LongTermMemory();
      // 自动提取的世界事件 importance 恒为 6、同一天写入：
      // 若排序只按 score，500 条全同分，取前 40 条会因 Dart 排序不稳定而漂移。
      for (int i = 0; i < 60; i++) {
        mem = mem.addWorldEvent(WorldEventRecord(
          id: 'ev$i',
          timestamp: '📅 1991年9月1日 星期一 09:00',
          title: '事件$i',
          description: '描述$i',
          importance: 6,
          category: 'wizarding',
        ), maxEvents: 50);
      }
      expect(mem.worldEvents.length, 50);
      // 同分情况下保留最后写入的（次级键：插入顺序倒序）
      expect(mem.worldEvents.map((e) => e.id).contains('ev59'), isTrue);
      expect(mem.worldEvents.map((e) => e.id).contains('ev0'), isFalse);
    });
  });
}
