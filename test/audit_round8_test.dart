// 第八轮审查记录的行为测试。
//
// 与仓库里大量「读源码查子串」的断言不同，这里每一条都真的把代码跑一遍。
// 三条纪律（前两条是第八轮审查用 24 条假绿测试换来的教训）：
//
//  1. **注入的参数必须与生产在同一侧**。第七轮把 Dio 的 receiveTimeout 调小到
//     300ms 以求测试跑得快，于是不知不觉把被测路径从「Dart timeout」换成了
//     「Dio timeout」——而这两条路径在生产配置下行为完全相反，P0 就是这么躲
//     过去的。所以这里注入时改的是**绝对值**，相对关系必须保持：
//     delay > perCallTimeout，且 receiveTimeout > perCallTimeout。
//  2. **断言目标性质，而不是实现的定义式**。`expect(budget, 41)` 只是把公式
//     抄了一遍，公式错了它也跟着错；该守的是「预算 ≥ 实际最坏耗时」。
//  3. **不锁死轮询 / 排序这类实现细节**，否则调参就假红、不调参又形同虚设。
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/data/locations.dart';
import 'package:hogwarts_life_simulator/data/npc_schedule_rules.dart';
import 'package:hogwarts_life_simulator/models/long_term_memory.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/services/ai_router.dart';
import 'package:hogwarts_life_simulator/services/deepseek_service.dart';
import 'package:hogwarts_life_simulator/services/rate_limiter.dart';

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
        // 连接被客户端 / 超时掐断，属预期。
      }
    });
    return fake;
  }

  Future<void> close() => _server.close(force: true);
}

/// 构造一个指向 [server] 的 DeepSeekService。
///
/// Dio 的 receiveTimeout 固定 5 秒——它必须**大于**用例注入的
/// perCallTimeout，否则测的就是另一条路径（见文件头第 1 条）。
DeepSeekService _serviceOn(
  _FakeAiServer server, {
  String key = 'test-key',
  String model = 'test-model',
}) {
  final cfg = AiConfig(
    provider: AiProvider.deepseek,
    apiKey: key,
    baseUrl: 'http://127.0.0.1:${server.port}',
    model: model,
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
        {
          'message': {'content': content}
        }
      ],
      'usage': {'prompt_tokens': 1, 'completion_tokens': 1, 'total_tokens': 2},
    });

/// 路由层给单个 provider 的 Dio 接收超时（与 DeepSeekService 保持同一份定义）。
Duration _receiveTimeoutFor(AiProvider p) =>
    p == AiProvider.sensenova
        ? DeepSeekService.receiveTimeoutSensenova
        : DeepSeekService.receiveTimeoutDefault;

AiRouter _routerWith(List<DeepSeekService> services) => AiRouter(
      AiRouterConfig(
        narrativeProvider: AiProvider.deepseek,
        summaryProvider: AiProvider.deepseek,
        npcChatProvider: AiProvider.deepseek,
        choiceProvider: AiProvider.deepseek,
        fallbackOrder: const [AiProvider.deepseek],
      ),
      services: {AiProvider.deepseek: services},
    );

void main() {
  // ==================== P0：单 Key 超时不再炸掉整条 Key 链 ====================
  group('P0 单 Key 超时（第八轮 §1）', () {
    test('慢 Key 超时后必须切到下一个 Key', () async {
      // 生产里 perCallTimeout(35/50s) 恒小于 receiveTimeout(45/60s)，所以任何
      // 一次真实网络超时都是 Dart 的 .timeout 先触发。注入时只缩小时长，
      // 相对关系保持不变（见文件头）。
      AiRouter.perCallTimeoutOverride = const Duration(milliseconds: 500);
      addTearDown(() => AiRouter.perCallTimeoutOverride = null);

      final slow = await _FakeAiServer.start(
        status: 200,
        body: _chatBody('慢 Key 的回答'),
        delay: const Duration(seconds: 3), // 远大于 perCall 500ms
      );
      final fast = await _FakeAiServer.start(
        status: 200,
        body: _chatBody('快 Key 的回答'),
      );
      addTearDown(slow.close);
      addTearDown(fast.close);

      final router = _routerWith([
        _serviceOn(slow, key: 'slow-key'),
        _serviceOn(fast, key: 'fast-key'),
      ]);

      // 起点每次调用都会轮换（_roundRobinIndex 先 +1 再取模），不能假定第一轮
      // 就从 slow 起步——那是在锁死轮询实现。连打几轮覆盖两个起点，抓住 slow
      // 真被点到的那一轮来验证「超时后让位」，这才是要守的性质。
      // 每轮换一个 prompt，避免命中同一 provider/model 的响应缓存。
      var slowHitRound = -1;
      String? contentOnSlowHit;
      for (var i = 0; i < 4; i++) {
        final before = slow.hits;
        final r = await router.chatComplete(
          scene: AiScene.narrative,
          prompt: 'ping$i',
        );
        if (slow.hits > before) {
          slowHitRound = i;
          contentOnSlowHit = r.content;
          break;
        }
      }

      // 修复前：per-call 超时取消的是整条链共享的那个 token，catch 里的
      // `isCancelled → rethrow` 于是直接跳出三层循环——不切下一个 Key、
      // 不记熔断，还抛出「已切换 Key」的假消息。
      expect(slowHitRound, greaterThanOrEqualTo(0),
          reason: '四轮覆盖了两个轮询起点，慢 Key 总该被点到一次');
      expect(contentOnSlowHit, '快 Key 的回答',
          reason: '慢 Key 超时后必须切到下一个 Key，而不是整条链一起放弃');
      expect(slow.hits, 1, reason: '慢 Key 一次调用里至多被点一次，超时后立刻让位');
      expect(fast.hits, greaterThanOrEqualTo(1));
    });

    test('超时也要记进熔断（以前 rethrow 跳过了 _recordFailure）', () async {
      AiRouter.perCallTimeoutOverride = const Duration(milliseconds: 300);
      addTearDown(() => AiRouter.perCallTimeoutOverride = null);

      final slow = await _FakeAiServer.start(
        status: 200,
        body: _chatBody('慢'),
        delay: const Duration(seconds: 2),
      );
      addTearDown(slow.close);

      final router = _routerWith([_serviceOn(slow, key: 'only-key')]);

      // 只有这一把 Key：每次调用超时一次就放弃（不再退避重试，
      // 见 AiRouter._maxRetriesPerService 的注释）。
      for (var i = 0; i < AiRouter.circuitThreshold; i++) {
        Object? thrown;
        try {
          await router.chatComplete(scene: AiScene.summary, prompt: 'p$i');
        } catch (e) {
          thrown = e;
        }
        expect(thrown, isNotNull,
            reason: '唯一的 Key 又慢、又没别人可切，最终应当报错');
      }

      // 累计到阈值 → 熔断打开 → 之后一个请求都不该再发出去。
      // 修复前超时走 rethrow，_recordFailure 永远执行不到，熔断计数涨不上去。
      final hitsBefore = slow.hits;
      try {
        await router.chatComplete(scene: AiScene.summary, prompt: '熔断后');
      } catch (_) {
        // 全部 Key 熔断中，抛错属预期
      }
      expect(slow.hits, hitsBefore,
          reason: '超时记进熔断后不该再打这把 Key——记不进去正是 P0 的老毛病');
    });
  });

  // ==================== P1-A：checkConnection 的非 JSON 防护 ====================
  group('P1-A checkConnection 与 chatComplete 一视同仁（§2.1）', () {
    test('返回 HTML 错误页时不抛 NoSuchMethodError', () async {
      final server = await _FakeAiServer.start(
        status: 200,
        body: '<html><body>502 Bad Gateway</body></html>',
        contentType: 'text/html',
      );
      addTearDown(server.close);

      Object? thrown;
      try {
        await _serviceOn(server).checkConnection();
      } catch (e) {
        thrown = e;
      }

      // 同一个文件、同一套 _dio、同一个端点，chatComplete 做了非 JSON 防护，
      // checkConnection 却没有：response.data 是 String 时，String 没有
      // operator [] → NoSuchMethodError，绕过 on DioException 直接冒泡到 UI。
      // 讽刺的是玩家点「测试连接」的恰恰就是 AI 连不上、返回错误页的那一刻。
      expect(thrown, isA<Exception>(),
          reason: '非 JSON 响应必须归一成普通 Exception，不能是 NoSuchMethodError');
      expect(thrown, isNot(isA<NoSuchMethodError>()));
      expect(thrown.toString(), contains('不是 JSON'),
          reason: '文案要能把人指向「对端返回的不是 AI 响应」');
    });

    test('checkConnection 的正常响应照常返回 true', () async {
      final server = await _FakeAiServer.start(
        status: 200,
        body: _chatBody('OK'),
      );
      addTearDown(server.close);

      expect(await _serviceOn(server).checkConnection(), isTrue);
    });
  });

  // ==================== P1-B：单次调用超时按 provider 取值 ====================
  group('P1-B 单次调用超时（§2.2）', () {
    test('perCallTimeout 必须短于该 provider 的 receiveTimeout', () {
      // 上层一刀切 35s 时，SenseNova 的 Dio receiveTimeout(60s) 永远等不到：
      // 「SenseNova 响应慢，需要更长超时」这条设计意图彻底落空。
      for (final p in AiProvider.values) {
        expect(AiRouter.perCallTimeoutFor(p), lessThan(_receiveTimeoutFor(p)),
            reason: '$p：perCallTimeout 短于 receiveTimeout，'
                'Dio 才有机会先于上层超时');
      }
    });

    test('SenseNova 的「慢」要真的落得到上层', () {
      // 光在 Dio 层特化不够，上层的 perCallTimeout 也得跟着放宽，
      // 否则那两个特化常量就是写给人看的。
      expect(
        AiRouter.perCallTimeoutFor(AiProvider.sensenova),
        greaterThan(AiRouter.perCallTimeoutFor(AiProvider.deepseek)),
        reason: 'Dio 给 SenseNova 特化了更长超时，上层必须同步放宽',
      );
    });
  });

  // ==================== P1-C：永不遗忘层的护栏是真的约束 ====================
  group('P1-C 永不遗忘层护栏（§2.3）', () {
    test('80 条 9 分事实 + 30 条日常：9 分层被压到护栏以内', () {
      var mem = LongTermMemory();
      for (int i = 0; i < 80; i++) {
        mem = mem.addKeyFact(KeyFactRecord(
          id: 'p$i',
          fact: '第$i 条誓言',
          importance: kPersistentFactImportance,
          timestamp: '📅 1991年9月${10 + (i % 20)}日 星期一 09:00',
        ));
      }
      for (int i = 0; i < 30; i++) {
        mem = mem.addKeyFact(KeyFactRecord(
          id: 'd$i',
          fact: '第$i 条日常流水',
          importance: 5,
          timestamp: '📅 1991年9月${10 + (i % 20)}日 星期一 09:00',
        ));
      }

      final persistent = mem.keyFacts
          .where((f) => f.importance >= kPersistentFactImportance)
          .length;

      // 修复前：护栏只在「总量超 maxKeyFacts」时才作为开关参与判断，而那时
      // 列表长度恒 ≥ 101 > 60，60 这个数字一次都没成为约束——9 分层一路涨到
      // 100 条（= maxKeyFacts）才被砍，注释承诺的 60 条从未兑现。
      expect(persistent, lessThanOrEqualTo(kMaxPersistentKeyFacts),
          reason: '9 分层该被护栏压到 $kMaxPersistentKeyFacts 条以内');
      expect(persistent, kMaxPersistentKeyFacts,
          reason: '护栏是限高不是清空：80 条输入应恰好保留 $kMaxPersistentKeyFacts 条');
      expect(mem.keyFacts.any((f) => f.importance < kPersistentFactImportance),
          isTrue,
          reason: '日常流水不该被连坐清空');
    });
  });

  // ==================== P1-D：全局超时容得下单 Key 序列 ====================
  group('P1-D 超时预算自洽（§2.4）', () {
    test('任何场景下 globalTimeoutFor(1) 都不小于单 Key 预算', () {
      // 守的是「全局超时 ≥ 单个 Key 的最坏耗时」这个性质。以前预算只算
      // 「1 次超时 + 退避」= 41s，而非超时错误还会重试 2 次，真实最坏序列是
      // 35+2+35+4+35 = 111s——据此倒推的全局超时(60s) 根本容不下。
      for (final scene in AiScene.values) {
        expect(
          AiRouter.globalTimeoutFor(scene, 1),
          greaterThanOrEqualTo(AiRouter.perKeyBudgetFor(1)),
          reason: '$scene：全局超时必须容得下单个 Key 走完它的完整序列，'
              '否则第一个坏 Key 就能吃光预算，后面的 Key 轮不到',
        );
      }
    });

    test('Key 越多全局超时越长，但有上限', () {
      final one = AiRouter.globalTimeoutFor(AiScene.narrative, 1);
      final three = AiRouter.globalTimeoutFor(AiScene.narrative, 3);
      expect(three, greaterThan(one), reason: '3 个 Key 该有 3 份预算');
      expect(AiRouter.globalTimeoutFor(AiScene.narrative, 10),
          lessThanOrEqualTo(const Duration(seconds: 120)),
          reason: '也不能让玩家无限等');
    });
  });

  // ==================== P1-E：上课时段守教室的教授不会集体消失 ====================
  group('P1-E 地点父子表（§2.5）', () {
    test('kStaffClassLocations 里的室内教学场所都收进了父子表', () {
      // 遍历数据表而不是手写几个字符串：以后新增一位教授 / 一间教室，
      // 忘了配父子边就会在这里红。
      for (final entry in kStaffClassLocations.entries) {
        final room = entry.value;
        if (room == kGroundsLocation) {
          // 户外场地（飞行课、保护神奇生物课）刻意不收：把「场地」
          // 并进「教室」等于说「站在教室里 = 站在黑湖边」。
          continue;
        }
        expect(isSameLocation(room, '霍格沃茨·教室'), isTrue,
            reason: '${entry.key} 上课的 $room 应当与通用「教室」算同一处，'
                '否则玩家在通用教室时这位教授会从【在场】里消失');
      }
    });

    test('斯内普与斯普劳特在通用教室时也算在场', () {
      // 第七轮修掉了六位里的四位，这两位因为上课地点名字里没有「教室」
      // 二字而漏掉——其中斯内普是主线核心 NPC。
      expect(isSameLocation('霍格沃茨·地窖', '霍格沃茨·教室'), isTrue);
      expect(isSameLocation('霍格沃茨·温室', '霍格沃茨·教室'), isTrue);
    });
  });

  // ==================== P1-F：缓存键覆盖生成者身份 ====================
  group('P1-F 响应缓存键（§2.6）', () {
    test('同一个 prompt 换 model / provider 不命中旧缓存', () {
      ResponseCache.instance.clear();
      addTearDown(ResponseCache.instance.clear);

      const prompt = '同一段 prompt';
      ResponseCache.instance.set(prompt, 'A 模型的答案',
          provider: 'sensenova', model: 'model-a');

      // 缓存键覆盖了生成参数却漏了生成者身份时，玩家在设置页换模型之后
      // 5 分钟 TTL 内同一 prompt 会命中旧模型的输出——「换了模型，内容一个字没变」。
      expect(
        ResponseCache.instance.get(prompt,
            provider: 'sensenova', model: 'model-b'),
        isNull,
        reason: '换了 model 必须重新生成',
      );
      expect(
        ResponseCache.instance.get(prompt,
            provider: 'deepseek', model: 'model-a'),
        isNull,
        reason: '换了 provider 也必须重新生成',
      );
      // 身份完全一致才命中
      expect(
        ResponseCache.instance.get(prompt,
            provider: 'sensenova', model: 'model-a'),
        'A 模型的答案',
      );
    });
  });
}
