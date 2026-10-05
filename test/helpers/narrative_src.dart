import 'dart:io';

/// 源码扫描测试的统一读取入口（阶段5 整理产物）。
///
/// 【为什么需要它】本项目有大量「接线检查」测试直接 `File(...).readAsStringSync()`
/// 扫 `lib/mixins/mixin_narrative.dart` 的源码，断言某个 prompt 锚点/调用真的存在。
/// 这类测试是把双刃剑：能防「功能被静默优化掉」，但每次拆分 mixin 都会让锚点
/// 失效。阶段3 已把摘要/记忆管线拆到 `mixin_summary_memory.dart`，之后还可能
/// 继续拆——所以扫描入口必须收口到这一处：**任何挂在 GameProvider 上的叙事侧
/// mixin 文件，都算同一份「叙事源码面」**。以后再拆文件，只需要在这里的
/// [_narrativeSideFiles] 清单里加一行，几十个测试零修改。
///
/// 使用方式（与旧写法等价，只是换了个来源）：
/// ```dart
/// final src = narrativeSideSource();        // 两个半区拼接
/// final srcOnly = narrativeSideSource(stripComments: true); // 去注释版
/// ```
final List<String> _narrativeSideFiles = [
  'lib/mixins/mixin_narrative.dart',
  'lib/mixins/mixin_narrative_canon.dart',
  'lib/mixins/mixin_story_wiring.dart',
  'lib/mixins/mixin_story_engine.dart',
  'lib/mixins/mixin_summary_memory.dart',
];

final List<String> _cache = [];

/// 读入全部叙事侧 mixin 源码并按清单顺序拼接（各文件间以换行分隔）。
String narrativeSideSource({bool stripComments = false}) {
  if (_cache.isEmpty) {
    for (final f in _narrativeSideFiles) {
      _cache.add(File(f).readAsStringSync());
    }
  }
  final joined = _cache.join('\n');
  return stripComments ? _stripDartComments(joined) : joined;
}

/// 去除 Dart 行注释与块注释（保留字符串字面量原样——接线扫描不关心这个精度，
/// 与各测试文件里既有的 `_stripComments` 行为一致）。
String _stripDartComments(String src) {
  final noBlock = src.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  final lineRe = RegExp(r'//.*$');
  return noBlock.split('\n').map((l) => l.replaceFirst(lineRe, '')).join('\n');
}
