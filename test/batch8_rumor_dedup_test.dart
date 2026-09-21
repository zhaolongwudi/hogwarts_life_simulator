/// Batch 8 · Issue #12：传闻生成缺去重 → 加近 7 天去重 + 「已被传闻化」标记 + 每日 1 条节流。
///
/// 覆盖：
///  - 数据完整性：kDailyActivityLimits 含 rumor:1；
///  - 源码检查：_maybeGenerateRumor 含 canDoDaily('rumor') 节流、
///    rumoredEventDays 7 天去重、recordDailyActivity('rumor') 计数；
///  - 存档：rumoredEventDays 字段在 _saveExtraData 里持久化 + 读档时恢复；
///  - 行为：rumoredEventDays 字段存在且可读写（通过 GameProvider 实例）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('kDailyActivityLimits 数据完整性', () {
    test('含 rumor:1 条目', () {
      final src = File('lib/mixins/mixin_systems.dart').readAsStringSync();
      expect(RegExp(r"'rumor':\s*1").hasMatch(src), isTrue,
          reason: 'kDailyActivityLimits 应含 rumor:1');
    });
  });

  group('_maybeGenerateRumor 源码检查', () {
    late String src;

    setUpAll(() {
      src = File('lib/mixins/mixin_systems.dart').readAsStringSync();
    });

    test('含 canDoDaily(\'rumor\') 每日节流', () {
      expect(src.contains("canDoDaily('rumor')"), isTrue,
          reason: '_maybeGenerateRumor 应含 canDoDaily(\'rumor\') 节流');
    });

    test('含 recordDailyActivity(\'rumor\') 计数', () {
      expect(src.contains("recordDailyActivity('rumor')"), isTrue,
          reason: '_maybeGenerateRumor 应含 recordDailyActivity(\'rumor\') 计数');
    });

    test('含 rumoredEventDays 7 天去重判定', () {
      expect(src.contains('rumoredEventDays'), isTrue,
          reason: '_maybeGenerateRumor 应使用 rumoredEventDays 做去重');
      expect(src.contains('(today - lastDay) >= 7'), isTrue,
          reason: '应含 7 天去重判定');
    });

    test('使用 recentNarrativeEvents 而不是 recentEvents', () {
      // recentEvents 是死字段（addNarrativeEvent 只写 recentNarrativeEvents）
      // 旧实现读 recentEvents 永远为空，传闻生成实际从未触发
      final fnStart = src.indexOf('void _maybeGenerateRumor');
      final fnEnd = src.indexOf('void advanceTimeForAction');
      final fnBody = src.substring(fnStart, fnEnd);
      expect(fnBody.contains('recentNarrativeEvents'), isTrue,
          reason: '_maybeGenerateRumor 应读 recentNarrativeEvents');
      expect(fnBody.contains('worldState.recentEvents'), isFalse,
          reason: '_maybeGenerateRumor 不应再读死字段 recentEvents');
    });
  });

  group('rumoredEventDays 存档', () {
    late String src;

    setUpAll(() {
      src = File('lib/mixins/mixin_systems.dart').readAsStringSync();
    });

    test('_saveExtraData 含 rumored_event_days 字段', () {
      expect(src.contains("'rumored_event_days': rumoredEventDays"), isTrue,
          reason: '_saveExtraData 应持久化 rumoredEventDays');
    });

    test('读档时恢复 rumoredEventDays', () {
      expect(src.contains("extraData['rumored_event_days']"), isTrue,
          reason: '读档时应从 extraData 恢复 rumoredEventDays');
    });

    test('读档前清空 rumoredEventDays（避免串档）', () {
      expect(src.contains('rumoredEventDays.clear()'), isTrue,
          reason: '读档前应清空 rumoredEventDays');
    });
  });

  group('rumoredEventDays 字段行为', () {
    test('GameProvider 实例含 rumoredEventDays 字段且可读写', () async {
      final gp = await makeGame(offlineQuickMode: true);
      // 初始为空
      expect(gp.rumoredEventDays, isEmpty);
      // 可写入
      gp.rumoredEventDays['测试事件'] = 100;
      expect(gp.rumoredEventDays['测试事件'], 100);
      // 可清空
      gp.rumoredEventDays.clear();
      expect(gp.rumoredEventDays, isEmpty);
    });

    test('rumor 每日节流初始可用', () async {
      final gp = await makeGame(offlineQuickMode: true);
      expect(gp.canDoDaily('rumor'), isTrue,
          reason: '开局时 rumor 每日节流应可用');
    });
  });
}