/// Batch 10 · Issue #23：CI 静态扫描纯计数增量必须配套字符串实体。
///
/// 审查报告 §23 明确指出：论坛评论只 +1 数字无文本是"通病"，同类问题很可能
/// 存在于其他地方。本测试扫描 lib/ 下所有社交类计数器的增量点，强制要求：
///
///   ① 配套实体写入（如 `post.commentList.add(...)` / `xxxList.add(...)`）；
///   ② 或所在函数前 15 行内有显式豁免注释（含「仅计数的展示指标」或
///      「Batch 10 · Issue #23 豁免」标记）。
///
/// 这样"计数增长但不写实体"的 bug 会直接导致 CI 构建失败，而不是等玩家反馈。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 需要强制"计数+实体"配套的社交类计数器字段名。
/// 新增字段时请同步扩展此列表。
const List<String> kTrackedCounters = <String>[
  'comments',
  'likes',
  'reposts',
  'shares',
  'views',
  'upvotes',
  'downvotes',
  'followers',
  'subscribers',
  'watchers',
  'impressions',
];

/// 豁免注释的必需关键词（任一命中即视为豁免）。
const List<String> kExemptionMarkers = <String>[
  '仅计数的展示指标',
  'Batch 10 · Issue #23 豁免',
];

/// 实体写入的识别模式（任一命中即视为配套实体）。
/// 匹配形如 `xxxList.add(...)`、`xxxEntries.add(...)`、`xxxList.insert(...)`。
final RegExp _entityWritePattern = RegExp(
  r'\.\w+\s*\.(add|insert)\s*\(',
);

/// 计数增量识别模式：`xxx += 1` / `xxx++` / `xxx -= 1` / `xxx--`。
/// 允许 `xxx += post.liked ? 1 : -1` 这种三元表达式形式。
final RegExp _counterIncrementPattern = RegExp(
  r'\.(comments|likes|reposts|shares|views|upvotes|downvotes|followers|subscribers|watchers|impressions)\s*(\+=|-=|\+\+|--)',
);

/// 找出 lib/ 下所有 .dart 文件。
List<File> _libDartFiles() {
  final files = <File>[];
  final libDir = Directory('lib');
  if (!libDir.existsSync()) return files;
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files.add(entity);
    }
  }
  return files;
}

/// 在文件内容中找出所有计数增量点。
/// 返回 (行号, 字段名, 所在行完整内容)。
List<(int, String, String)> _findCounterIncrements(List<String> lines) {
  final results = <(int, String, String)>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    // 跳过纯注释行
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
    for (final m in _counterIncrementPattern.allMatches(line)) {
      results.add((i + 1, m.group(1)!, line));
    }
  }
  return results;
}

/// 判断增量点是否配套实体写入。
/// 检查增量点所在行 + 前后 8 行内是否有 `xxxList.add(...)` 类实体写入。
bool _hasEntityWriteNearby(List<String> lines, int lineIndex1Based) {
  final start = (lineIndex1Based - 8).clamp(1, lines.length);
  final end = (lineIndex1Based + 8).clamp(1, lines.length);
  for (var i = start; i <= end; i++) {
    if (_entityWritePattern.hasMatch(lines[i - 1])) return true;
  }
  return false;
}

/// 判断增量点所在函数前 15 行内是否有豁免注释。
/// 向上回溯查找最近的函数定义，然后检查该函数定义前 15 行内是否含豁免标记。
bool _hasExemptionMarkerNearby(List<String> lines, int lineIndex1Based) {
  final funcDefPattern = RegExp(r'^\s*(void|int|bool|String|double|Future|dynamic)\s+\w+\s*\(');
  var funcLine = -1;
  for (var i = lineIndex1Based - 1; i >= 0 && i >= lineIndex1Based - 40; i--) {
    if (funcDefPattern.hasMatch(lines[i])) {
      funcLine = i;
      break;
    }
  }
  if (funcLine < 0) return false;
  final start = (funcLine - 15).clamp(0, lines.length - 1);
  for (var i = start; i <= funcLine; i++) {
    for (final marker in kExemptionMarkers) {
      if (lines[i].contains(marker)) return true;
    }
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Batch 10 · Issue #23：计数增量必须配套实体或豁免', () {
    test('lib/ 下所有社交类计数增量点均配套实体写入或豁免注释', () {
      final files = _libDartFiles();
      final violations = <String>[];

      for (final file in files) {
        final lines = file.readAsStringSync().split('\n');
        final increments = _findCounterIncrements(lines);
        for (final inc in increments) {
          final lineNo = inc.$1;
          final field = inc.$2;
          final lineContent = inc.$3;
          if (_hasEntityWriteNearby(lines, lineNo)) continue;
          if (_hasExemptionMarkerNearby(lines, lineNo)) continue;
          violations.add(
            '${file.path}:$lineNo  `.$field` 计数增量无配套实体写入也无豁免注释\n'
            '        行内容: $lineContent',
          );
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            '以下计数增量点未配套实体写入，也无豁免注释：\n${violations.join('\n')}\n\n'
            '修法：\n'
            '  ① 配套实体写入（如 xxxList.add(...)）；或\n'
            '  ② 在所在函数前 15 行内加豁免注释（含「仅计数的展示指标」或「Batch 10 · Issue #23 豁免」）。',
      );
    });

    test('ForumComment 实体类存在（Batch 7 · Issue #11 修复产物）', () {
      final playerDart = File('lib/models/player.dart').readAsStringSync();
      expect(playerDart.contains('class ForumComment'), isTrue,
          reason: 'ForumComment 类应存在（Batch 7 Issue #11 修复）');
      expect(playerDart.contains('List<ForumComment> commentList'), isTrue,
          reason: 'ForumPost 应有 commentList 字段承载实体');
    });

    test('addForumPostComment 配套实体写入（Batch 7 Issue #11 修复验证）', () {
      final mixinSystems = File('lib/mixins/mixin_systems.dart').readAsStringSync();
      final idx = mixinSystems.indexOf('void addForumPostComment');
      expect(idx, greaterThan(0),
          reason: 'addForumPostComment 函数应存在');
      final funcBody = mixinSystems.substring(idx, (idx + 800).clamp(0, mixinSystems.length));
      expect(funcBody.contains('post.commentList.add'), isTrue,
          reason: 'addForumPostComment 应写入 commentList 实体');
      expect(funcBody.contains('ForumComment('), isTrue,
          reason: 'addForumPostComment 应构造 ForumComment 实体');
    });

    test('toggleForumPostLike 有显式豁免注释（Batch 10 Issue #23）', () {
      final mixinSystems = File('lib/mixins/mixin_systems.dart').readAsStringSync();
      final lines = mixinSystems.split('\n');
      var funcLine = -1;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('void toggleForumPostLike')) {
          funcLine = i;
          break;
        }
      }
      expect(funcLine, greaterThan(0),
          reason: 'toggleForumPostLike 函数应存在');
      final start = (funcLine - 15).clamp(0, lines.length - 1);
      var hasMarker = false;
      for (final marker in kExemptionMarkers) {
        for (var i = start; i <= funcLine; i++) {
          if (lines[i].contains(marker)) {
            hasMarker = true;
            break;
          }
        }
        if (hasMarker) break;
      }
      expect(hasMarker, isTrue,
          reason:
              'toggleForumPostLike 的 post.likes += 是纯计数增量，'
              '应在函数前 15 行内加豁免注释（含「仅计数的展示指标」或「Batch 10 · Issue #23 豁免」）');
    });

    test('kTrackedCounters 列表非空且去重', () {
      expect(kTrackedCounters, isNotEmpty);
      expect(kTrackedCounters.toSet().length, kTrackedCounters.length,
          reason: 'kTrackedCounters 不应有重复项');
    });

    test('豁免标记列表非空', () {
      expect(kExemptionMarkers, isNotEmpty);
    });

    test('实体写入识别模式可匹配 commentList.add', () {
      expect(_entityWritePattern.hasMatch('post.commentList.add(ForumComment(...))'), isTrue);
      expect(_entityWritePattern.hasMatch('post.entries.insert(0, item)'), isTrue);
      expect(_entityWritePattern.hasMatch('post.list.insert(0, item)'), isTrue);
      expect(_entityWritePattern.hasMatch('obj.likes += 1'), isFalse,
          reason: '纯计数增量不应被误判为实体写入');
      expect(_entityWritePattern.hasMatch('obj.likes++'), isFalse,
          reason: '纯计数增量不应被误判为实体写入');
      expect(_entityWritePattern.hasMatch('obj.score = 10'), isFalse,
          reason: '普通赋值不应被误判为实体写入');
    });

    test('计数增量识别模式可匹配所有追踪字段', () {
      for (final field in kTrackedCounters) {
        expect(_counterIncrementPattern.hasMatch('obj.$field += 1'), isTrue,
            reason: '应识别 obj.$field += 1');
        expect(_counterIncrementPattern.hasMatch('obj.$field++'), isTrue,
            reason: '应识别 obj.$field++');
      }
      expect(_counterIncrementPattern.hasMatch('obj.score += 1'), isFalse);
      expect(_counterIncrementPattern.hasMatch('obj.turnCount++'), isFalse);
    });
  });

  group('Batch 10 · Issue #23：扫描覆盖度自检', () {
    test('lib/ 目录存在且含 .dart 文件', () {
      final files = _libDartFiles();
      expect(files, isNotEmpty, reason: 'lib/ 下应有 .dart 文件');
      expect(files.length, greaterThan(20),
          reason: 'lib/ 下 .dart 文件数应 > 20（防止扫描路径错误）');
    });

    test('扫描能识别 mixin_systems.dart 中的计数增量点', () {
      final mixinSystems = File('lib/mixins/mixin_systems.dart').readAsStringSync();
      final lines = mixinSystems.split('\n');
      final increments = _findCounterIncrements(lines);
      expect(increments, isNotEmpty,
          reason: 'mixin_systems.dart 应至少有一个计数增量点（toggleForumPostLike）');
      final hasLikesIncrement = increments.any((t) => t.$2 == 'likes');
      expect(hasLikesIncrement, isTrue,
          reason: '应识别出 post.likes 增量点');
    });

    test('扫描能识别 player.dart 中的 ForumComment 实体写入', () {
      final playerDart = File('lib/models/player.dart').readAsStringSync();
      final lines = playerDart.split('\n');
      var commentListLine = -1;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('List<ForumComment> commentList')) {
          commentListLine = i;
          break;
        }
      }
      expect(commentListLine, greaterThan(0),
          reason: 'player.dart 应含 commentList 字段定义');
    });
  });
}
