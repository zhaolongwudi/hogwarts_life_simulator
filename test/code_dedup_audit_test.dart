/// 批次9（D1/D2 代码重复收敛）结构护栏测试：
///   D2：lib/ 下不得再出现 `Navigator.push(context, MaterialPageRoute(...))`
///       直连模式 —— 一律走 `pushRoute`（lib/utils/ui_helpers.dart 收口）；
///   D1：test/ 下不得再出现第 2 份 `Future<GameProvider> makeGame` 重复定义
///       （唯一来源 = test/helpers/test_fixtures.dart）。
///
/// 护栏直接扫描源码文件，改动收口后若有人把旧模式写回去，CI 立即报错。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('D2 导航统一走 pushRoute', () {
    test('lib/ 下 MaterialPageRoute 只允许出现在 ui_helpers.dart', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('ui_helpers.dart')) continue;
        final src = File(entity.path).readAsStringSync();
        if (src.contains('MaterialPageRoute')) offenders.add(entity.path);
      }
      expect(offenders, isEmpty,
          reason: '新页面一律用 pushRoute 收口，Route 构造细节集中一处');
    });

    test('lib/ 下不再出现 Navigator.push( 直连（含跨行形态）', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('ui_helpers.dart')) continue;
        final src = File(entity.path).readAsStringSync();
        if (RegExp(r'Navigator\.push\(').hasMatch(src)) offenders.add(entity.path);
      }
      expect(offenders, isEmpty,
          reason: 'pushRoute 是唯一出口；pushNamed 属路由表命名跳转，不在此列');
    });
  });

  group('D1 测试 fixture 唯一来源', () {
    test('test/ 下 makeGame 只允许定义在 helpers/test_fixtures.dart', () {
      final offenders = <String>[];
      for (final entity in Directory('test').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('helpers/test_fixtures.dart')) continue;
        final src = File(entity.path).readAsStringSync();
        if (RegExp(r'Future<GameProvider>\s+makeGame\(').hasMatch(src)) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'makeGame 唯一来源 = test/helpers/test_fixtures.dart');
    });

    test('引用方统一从 helpers 引入（不再自建 AppProvider mock 前缀）', () {
      for (final f in [
        'provider_logic_test.dart',
        'round15_fixes_test.dart',
        'round16_fixes_test.dart',
        'round16c_repro_test.dart',
      ]) {
        final src = File('test/$f').readAsStringSync();
        expect(src.contains("import 'helpers/test_fixtures.dart';"), isTrue,
            reason: '$f 应引用共享 fixture 而非自建一份');
      }
    });
  });
}
