// v4 批次32 稳定性与隐私层:Q15 / Q16 行为测试。
//
// 覆盖两件事:
//  - Q15:AiDebugLogger 不把完整 systemPrompt 落盘(隐私脱敏)、
//        单日日志超限后分片追加而非覆写(不再丢历史)。
//  - Q16:HTTP 429 文案区分「服务商配额耗尽」与「速率限制」,
//        给玩家可行动的指引,而不是一句笼统的"稍后重试"。
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:hogwarts_life_simulator/services/deepseek_service.dart';
import 'package:hogwarts_life_simulator/utils/ai_debug_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Q16 HTTP 429 文案分型', () {
    test('服务商配额耗尽 → 提示等待窗口重置', () {
      final msg = DeepSeekService.classify429('Your quota is exceeded');
      expect(msg, contains('配额'));
      expect(msg, contains('窗口'));
      expect(msg, isNot(contains('频繁')));
    });

    test('速率限制 → 提示稍等再试', () {
      final msg = DeepSeekService.classify429('rate limit reached');
      expect(msg, contains('限流'));
      expect(msg, contains('稍等'));
    });

    test('"too many requests" 归速率分支', () {
      expect(DeepSeekService.classify429('too many requests'), contains('限流'));
    });

    test('中文"额度用尽"也识别为配额分支', () {
      expect(DeepSeekService.classify429('本日本平台额度已用尽'), contains('配额'));
    });

    test('未知 message → 通用文案且保留原文', () {
      final msg = DeepSeekService.classify429('some weird body');
      expect(msg, contains('429'));
      expect(msg, isNot(contains('配额')));
      expect(msg, isNot(contains('限流')));
    });
  });

  group('Q15 调试日志隐私与防覆写', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ai_log_test_');
    });

    tearDown(() async {
      // ignore: invalid_use_of_visible_for_testing_member
      AiDebugLogger.instance.resetForTest();
      if (tmp.existsSync()) {
        tmp.deleteSync(recursive: true);
      }
    });

    test('systemPrompt 只落首行摘要，不落完整档案', () async {
      // ignore: invalid_use_of_visible_for_testing_member
      await AiDebugLogger.instance.forceLogDirForTest(tmp.path);
      // ignore: invalid_use_of_visible_for_testing_member
      final callId = await AiDebugLogger.instance.logStart(
        timestamp: '2026-09-10 12:00',
        scene: 'npcChat',
        provider: 'sensenova',
        promptPreview: 'USER: hi',
        systemPrompt: '你是斯内普教授,玩家档案:姓名xx,关系:恋人,魔法能力:变形术专家 …（数百字）',
      );
      // ignore: invalid_use_of_visible_for_testing_member
      await AiDebugLogger.instance.logComplete(
        callId: callId,
        timestamp: '2026-09-10 12:00',
        scene: 'npcChat',
        provider: 'sensenova',
        action: 'RESPONSE',
        responsePreview: '嗯。',
      );

      final files = tmp.listSync().whereType<File>().toList();
      expect(files, isNotEmpty);
      final content = files.map((f) => f.readAsStringSync()).join('\n');
      expect(content, contains('【System Prompt】(隐私脱敏'));
      expect(content, contains('完整内容已脱敏'));
      // 完整档案(姓名/关系/能力)不得以明文出现在日志里
      expect(content, isNot(contains('姓名xx')));
      expect(content, isNot(contains('恋人')));
      expect(content, isNot(contains('变形术专家')));
      // 玩家输入 Prompt 预览仍可查(排查上下文污染仍需要)
      expect(content, contains('USER: hi'));
    });

    test('单日日志超限后分片追加，历史不被覆写', () async {
      // ignore: invalid_use_of_visible_for_testing_member
      await AiDebugLogger.instance.forceLogDirForTest(tmp.path);
      // 直接向主分片塞入超上限内容，模拟"当日已写满"
      final now = DateTime.now();
      final two = (int n) => n.toString().padLeft(2, '0');
      final base =
          '${now.year}${two(now.month)}${two(now.day)}';
      final mainFile = File('${tmp.path}/ai_log_$base.txt');
      mainFile.writeAsStringSync('filler' * (1024 * 1024 + 1));

      // ignore: invalid_use_of_visible_for_testing_member
      final callId = await AiDebugLogger.instance.logStart(
        timestamp: '2026-09-10 12:01',
        scene: 'npcChat',
        provider: 'agnes',
        promptPreview: 'USER: 在吗',
      );
      // ignore: invalid_use_of_visible_for_testing_member
      await AiDebugLogger.instance.logComplete(
        callId: callId,
        timestamp: '2026-09-10 12:01',
        scene: 'npcChat',
        provider: 'agnes',
        action: 'RESPONSE',
        responsePreview: '嗯?',
      );

      final files = tmp.listSync().whereType<File>().toList();
      // 主分片(已超限) + 新分片 _1 都应存在：历史未丢，新增落到新分片
      expect(files.length, greaterThanOrEqualTo(2));
      final shards = files.map((f) => f.path).where((p) => p.contains('ai_log_')).toList();
      final hasMain = shards.any((p) => p.endsWith('$base.txt'));
      final hasShard1 = shards.any((p) => p.endsWith('${base}_1.txt'));
      expect(hasMain, isTrue, reason: '历史主分片不应被删除');
      expect(hasShard1, isTrue, reason: '超限后应写入新的 _1 分片');
      // 主分片内容仍是"filler"(未被覆写)
      expect(mainFile.readAsStringSync(), startsWith('filler'));
      // 新分片包含本次回复
      final shard1 = File('${tmp.path}/ai_log_${base}_1.txt');
      expect(shard1.readAsStringSync(), contains('嗯?'));
    });
  });
}