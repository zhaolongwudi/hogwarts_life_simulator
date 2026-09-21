/// Batch 8 · Issue #16：scene_illustration Data Color(0xFF...) 收敛或显式豁免。
///
/// 决策：走「显式豁免」路线（不收敛到主题系统）。
/// 覆盖：
///  - 文件顶部含豁免声明（含「主题豁免声明」+「Batch 8 Issue #16」标记）；
///  - 所有 `Color(0xFF...)` 均出现在 `gradient:` 字段行内（不越界到其它字段）；
///  - 文件未引入 AppColors/Theme/ColorScheme（豁免后仍保持静态映射，不混入主题系统）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String src;
  late List<String> lines;

  setUpAll(() {
    src = File('lib/data/scene_illustration_data.dart').readAsStringSync();
    lines = src.split('\n');
  });

  group('豁免声明存在性', () {
    test('文件顶部含「主题豁免声明」标记', () {
      expect(src.contains('主题豁免声明'), isTrue,
          reason: 'scene_illustration_data.dart 顶部应含主题豁免声明');
    });

    test('豁免声明含 Batch 8 Issue #16 追踪标记', () {
      expect(src.contains('Batch 8 Issue #16'), isTrue,
          reason: '豁免声明应含 Batch 8 Issue #16 追踪标记');
    });

    test('豁免声明位于文件前 30 行内', () {
      final head = lines.take(30).join('\n');
      expect(head.contains('主题豁免声明'), isTrue,
          reason: '豁免声明应在文件顶部（前 30 行内），便于审阅');
    });

    test('豁免声明含「不参与 AppColors/Theme 主题切换」说明', () {
      expect(src.contains('不参与 AppColors/Theme 主题切换'), isTrue,
          reason: '豁免声明应明确说明不参与主题切换');
    });
  });

  group('Color(0xFF...) 使用范围', () {
    test('所有 Color(0xFF...) 均出现在 gradient: 字段行内', () {
      final violations = <int>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('Color(0xFF')) {
          // 允许 gradient: 字段行（含多色渐变）
          if (!line.contains('gradient:')) {
            violations.add(i + 1);
          }
        }
      }
      expect(violations, isEmpty,
          reason:
              'Color(0xFF...) 应仅出现在 gradient: 字段行内，越界行号：$violations');
    });

    test('Color(0xFF...) 总数 >= 30（豁免后仍保留场景氛围渐变）', () {
      final count = RegExp(r'Color\(0xFF').allMatches(src).length;
      expect(count, greaterThanOrEqualTo(30),
          reason: '豁免后应保留原有场景氛围渐变（>= 30 处）');
    });
  });

  group('未混入主题系统（仅检查代码使用，豁免声明中的文字提及不算）', () {
    test('文件未以代码形式引用 AppColors（如 AppColors.xxx）', () {
      expect(RegExp(r'AppColors\.\w+').hasMatch(src), isFalse,
          reason: '豁免后不应以代码形式引用 AppColors.xxx');
    });

    test('文件未以代码形式引用 Theme.of / ThemeData', () {
      expect(RegExp(r'Theme\.(of|Data)\s*\(').hasMatch(src), isFalse,
          reason: '豁免后不应以代码形式调用 Theme.of()/ThemeData()');
    });

    test('文件未以代码形式引用 ColorScheme', () {
      expect(RegExp(r'ColorScheme\.\w+').hasMatch(src), isFalse,
          reason: '豁免后不应以代码形式引用 ColorScheme.xxx');
    });
  });
}
