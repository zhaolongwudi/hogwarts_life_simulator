// Batch 44：AI 配置重构——托底备用模型 + 商汤 deepseek-v4-pro。
//
// 覆盖：
//  1. fallbackProvider 默认值 = Atria（AiProvider.deepseek 枚举），可关闭、可改选。
//  2. fallback_provider 的持久化往返（索引 / 空字符串 = 关闭）。
//  3. deepseek-v4-pro 进入商汤出厂模型列表与免费策展清单。
//  4. setFallbackProvider 后 refreshClient 不崩（路由层已有 fallback 行为测试，
//     这里只守 AppProvider 这一层）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/data/provider_defaults.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('托底备用模型（AppProvider 层）', () {
    test('默认值 = Atria（deepseek 枚举），且是可空字段', () async {
      SharedPreferences.setMockInitialValues({});
      final app = AppProvider();
      await app.loadSettings();
      expect(app.fallbackProvider, AiProvider.deepseek,
          reason: '未显式配置时，托底备用模型应默认指向 Atria（最稳定的付费模型）');
    });

    test('可改选其它提供商，并持久化为枚举索引', () async {
      SharedPreferences.setMockInitialValues({});
      final app = AppProvider();
      await app.loadSettings();
      await app.setFallbackProvider(AiProvider.sensenova);
      expect(app.fallbackProvider, AiProvider.sensenova);

      // 重新 load 应读回相同值
      final app2 = AppProvider();
      await app2.loadSettings();
      expect(app2.fallbackProvider, AiProvider.sensenova);
    });

    test('可关闭托底（null），持久化为空字符串', () async {
      SharedPreferences.setMockInitialValues({});
      final app = AppProvider();
      await app.loadSettings();
      await app.setFallbackProvider(null);
      expect(app.fallbackProvider, isNull);

      final app2 = AppProvider();
      await app2.loadSettings();
      expect(app2.fallbackProvider, isNull,
          reason: '关闭托底后重新启动应保持关闭，不能回落到默认值');
    });
  });

  group('商汤模型清单', () {
    test('deepseek-v4-pro 进入商汤出厂可选列表', () {
      final d = defaultsForProvider('sensenova');
      expect(d.models.contains('deepseek-v4-pro'), isTrue,
          reason: 'Operit 里的 deepseek-v4-pro（商汤托管）应补进可选列表');
    });

    test('deepseek-v4-pro 在免费策展清单里（500次/5h 免费额度）', () {
      final app = AppProvider();
      final free = app.freeModelsFor(AiProvider.sensenova);
      expect(free.contains('deepseek-v4-pro'), isTrue);
      // 必须是出厂列表的子集（守 progression_fix_test 里的同一性质）
      final all = defaultsForProvider('sensenova').models;
      for (final m in free) {
        expect(all.contains(m), isTrue, reason: '免费清单含 $m，但出厂列表没有');
      }
    });
  });
}
