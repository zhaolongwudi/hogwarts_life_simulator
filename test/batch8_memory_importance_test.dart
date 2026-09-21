import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/memory_importance_config.dart';
import 'package:hogwarts_life_simulator/models/long_term_memory.dart';

/// Issue #18：长期记忆 importance 按事件类型集中配置。
///
/// 验证：
/// 1. 所有常量值与预期分级一致
/// 2. 源码中无残留硬编码 importance 值
/// 3. 所有使用处已替换为命名常量
void main() {
  group('importance 常量值', () {
    test('10 级：超越永不遗忘层', () {
      expect(kImportancePlayerDeath, 10);
      expect(kImportancePlayerImprisoned, 10);
    });

    test('9 级：永不遗忘层', () {
      expect(kImportanceStoryEnding, kPersistentFactImportance);
      expect(kImportanceCheatSecret, kPersistentFactImportance);
    });

    test('8 级：里程碑', () {
      expect(kImportanceStoryBegin, 8);
    });

    test('7 级：重要', () {
      expect(kImportanceStoryStart, 7);
      expect(kImportanceAiExtractedLoop, 7);
      expect(kImportanceRivalEnded, 7);
    });

    test('6 级：一般', () {
      expect(kImportanceOfflineWorldEvent, 6);
      expect(kImportanceStoryEffectLoop, 6);
      expect(kImportanceAiForeshadowLoop, 6);
      expect(kImportanceAiWorldEvent, 6);
      expect(kImportanceWhatIf, 6);
    });

    test('5 级：次要', () {
      expect(kImportanceOfflineNpcRelation, 5);
      expect(kImportanceMeetNpc, 5);
      expect(kImportanceQuestOpen, 5);
      expect(kImportanceQuestDone, 5);
    });

    test('4 级：极低', () {
      expect(kImportanceOfflineFlagLoop, 4);
      expect(kImportanceQuestDoneEvent, 4);
    });

    test('分级单调性：10 > 9 > 8 > 7 > 6 > 5 > 4', () {
      expect(kImportancePlayerDeath, greaterThan(kImportanceStoryEnding));
      expect(kImportanceStoryEnding, greaterThan(kImportanceStoryBegin));
      expect(kImportanceStoryBegin, greaterThan(kImportanceStoryStart));
      expect(kImportanceStoryStart, greaterThan(kImportanceOfflineWorldEvent));
      expect(kImportanceOfflineWorldEvent, greaterThan(kImportanceMeetNpc));
      expect(kImportanceMeetNpc, greaterThan(kImportanceOfflineFlagLoop));
    });
  });

  group('源码无残留硬编码', () {
    test('lib/ 下无 importance: 数字 硬编码', () {
      final files = _findDartFiles('lib');
      for (final file in files) {
        final content = File(file).readAsStringSync();
        final lines = content.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          // 跳过注释行
          if (line.startsWith('//')) continue;
          // 检查 importance: 数字
          final match = RegExp(r'importance:\s*[0-9]+').firstMatch(line);
          if (match != null) {
            fail('硬编码 importance 值: ${file}:${i + 1}: ${match.group(0)}');
          }
        }
      }
    });
  });

  group('所有使用处已替换为命名常量', () {
    test('mixin_narrative.dart 使用 kImportance* 常量', () {
      final content = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      expect(content, contains('kImportanceOfflineWorldEvent'));
      expect(content, contains('kImportanceOfflineNpcRelation'));
      expect(content, contains('kImportanceStoryBegin'));
      expect(content, contains('kImportanceStoryEnding'));
      expect(content, contains('kImportanceStoryEffectLoop'));
      expect(content, contains('kImportanceAiExtractedLoop'));
      expect(content, contains('kImportanceStoryStart'));
      expect(content, contains('kImportanceAiForeshadowLoop'));
      expect(content, contains('kImportanceAiWorldEvent'));
      expect(content, contains('kImportanceOfflineFlagLoop'));
    });

    test('mixin_death.dart 使用 kImportance* 常量', () {
      final content = File('lib/mixins/mixin_death.dart').readAsStringSync();
      expect(content, contains('kImportancePlayerDeath'));
      expect(content, contains('kImportancePlayerImprisoned'));
    });

    test('mixin_play.dart 使用 kImportance* 常量', () {
      final content = File('lib/mixins/mixin_play.dart').readAsStringSync();
      expect(content, contains('kImportanceQuestOpen'));
      expect(content, contains('kImportanceQuestDone'));
      expect(content, contains('kImportanceQuestDoneEvent'));
    });

    test('mixin_init.dart 使用 kImportance* 常量', () {
      final content = File('lib/mixins/mixin_init.dart').readAsStringSync();
      expect(content, contains('kImportanceMeetNpc'));
    });

    test('mixin_systems.dart 使用 kImportance* 常量', () {
      final content = File('lib/mixins/mixin_systems.dart').readAsStringSync();
      expect(content, contains('kImportanceWhatIf'));
    });

    test('mixin_commands.dart 使用 kImportance* 常量', () {
      final content = File('lib/mixins/mixin_commands.dart').readAsStringSync();
      expect(content, contains('kImportanceCheatSecret'));
    });

    test('mixin_response.dart 使用 kImportance* 常量', () {
      final content = File('lib/mixins/mixin_response.dart').readAsStringSync();
      expect(content, contains('kImportanceRivalEnded'));
    });
  });

  group('配置文件完整性', () {
    test('memory_importance_config.dart 存在且包含所有常量', () {
      final content = File('lib/data/memory_importance_config.dart').readAsStringSync();
      // 检查所有常量定义
      expect(content, contains('kImportancePlayerDeath'));
      expect(content, contains('kImportancePlayerImprisoned'));
      expect(content, contains('kImportanceStoryEnding'));
      expect(content, contains('kImportanceCheatSecret'));
      expect(content, contains('kImportanceStoryBegin'));
      expect(content, contains('kImportanceStoryStart'));
      expect(content, contains('kImportanceAiExtractedLoop'));
      expect(content, contains('kImportanceRivalEnded'));
      expect(content, contains('kImportanceOfflineWorldEvent'));
      expect(content, contains('kImportanceStoryEffectLoop'));
      expect(content, contains('kImportanceAiForeshadowLoop'));
      expect(content, contains('kImportanceAiWorldEvent'));
      expect(content, contains('kImportanceWhatIf'));
      expect(content, contains('kImportanceOfflineNpcRelation'));
      expect(content, contains('kImportanceMeetNpc'));
      expect(content, contains('kImportanceQuestOpen'));
      expect(content, contains('kImportanceQuestDone'));
      expect(content, contains('kImportanceOfflineFlagLoop'));
      expect(content, contains('kImportanceQuestDoneEvent'));
    });

    test('配置文件包含分级标准注释', () {
      final content = File('lib/data/memory_importance_config.dart').readAsStringSync();
      expect(content, contains('10 级'));
      expect(content, contains('9 级'));
      expect(content, contains('8 级'));
      expect(content, contains('7 级'));
      expect(content, contains('6 级'));
      expect(content, contains('5 级'));
      expect(content, contains('4 级'));
    });
  });
}

/// 递归查找目录下所有 .dart 文件
List<String> _findDartFiles(String dir) {
  final result = <String>[];
  final directory = Directory(dir);
  if (!directory.existsSync()) return result;
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      result.add(entity.path);
    }
  }
  return result;
}
