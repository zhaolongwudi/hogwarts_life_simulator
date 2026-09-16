import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 防止「循环里现编译 RegExp」这类热路径浪费回潮。
///
/// 背景：叙事校验、好感解析、正文渲染这些函数**每回合都要跑**，而它们内部
/// 有不少 for 循环。原先有人把 `RegExp(...)` 直接写在循环体里，于是
/// 「每校验一个 NPC / 每解析一行好感 / 每渲染一行正文」都要重新编译一遍正则。
/// 这些开销不报错、不崩溃，只在低端机上表现为卡顿，靠 review 很难发现。
///
/// 这里用源码扫描把它钉住：任何处于 for/while 或 .map/.where/.every 之类
/// 迭代回调内部的 `RegExp(` 构造都算违规。
void main() {
  group('循环内不得现编译正则', () {
    test('lib/ 下没有写在循环体里的 RegExp 构造', () {
      final offenders = <String>[];
      for (final path in _allLibFiles()) {
        offenders.addAll(_regexInLoops(path));
      }
      expect(offenders, isEmpty,
          reason: '下面这些位置在循环里现编译 RegExp，应提到 '
              'static final 字段或按模式串 memo 缓存：\n${offenders.join('\n')}');
    });

    test('扫描器本身能识别出循环里现编译的正则', () {
      // 自检：如果扫描器坏了，上面那条断言会永远通过，形同虚设
      final probe = Directory.systemTemp.createTempSync('regex_probe');
      final f = File('${probe.path}${Platform.pathSeparator}a.dart')
        ..writeAsStringSync('''
void f(List<String> xs) {
  for (final x in xs) {
    final re = RegExp(r'^\\d+\$');
    if (re.hasMatch(x)) print(x);
  }
}
''');
      expect(_regexInLoops(f.path), hasLength(1));
      probe.deleteSync(recursive: true);
    });

    test('扫描器不会把循环外的正则误判为违规', () {
      final probe = Directory.systemTemp.createTempSync('regex_probe2');
      final f = File('${probe.path}${Platform.pathSeparator}b.dart')
        ..writeAsStringSync('''
class A {
  static final RegExp re = RegExp(r'^\\d+\$');
  bool hit(String s) => re.hasMatch(s);
}
''');
      expect(_regexInLoops(f.path), isEmpty);
      probe.deleteSync(recursive: true);
    });
  });
}

/// 迭代回调：这些闭包体里构造正则同样会被反复执行。
final RegExp _iterCallback = RegExp(
    r'\.(map|forEach|where|any|every|expand|fold|firstWhere|skip|take|retainWhere|removeWhere|indexed)\s*\(');

final RegExp _loopKeyword = RegExp(r'\b(for|while|do)\s*\(');

/// 扫描 [path]，返回「位于循环体内部的 RegExp 构造」列表。
List<String> _regexInLoops(String path) {
  final raw = File(path).readAsStringSync();
  final src = raw.split('\n').map(_stripLineComment).join('\n');

  final found = <String>[];
  // scopes 的长度就是当前花括号深度，元素标记该层作用域是否是循环体
  final scopes = <bool>[];
  var line = 1;

  for (var i = 0; i < src.length; i++) {
    final ch = src[i];
    if (ch == '\n') {
      line++;
      continue;
    }
    if (ch == '{') {
      scopes.add(_headerIsLoop(src, i));
      continue;
    }
    if (ch == '}') {
      if (scopes.isNotEmpty) scopes.removeLast();
      continue;
    }
    if (ch == 'R' && src.startsWith('RegExp(', i)) {
      if (scopes.any((isLoop) => isLoop)) {
        final snippet = src
            .substring(i, i + 60 > src.length ? src.length : i + 60)
            .replaceAll('\n', ' ');
        found.add('$path:$line  $snippet');
      }
      i += 'RegExp('.length - 1;
      continue;
    }
  }
  return found;
}

/// 往回找这个 `{` 前面的头部片段，判断它是不是循环/迭代回调的开头。
bool _headerIsLoop(String src, int braceAt) {
  final buf = StringBuffer();
  for (var k = braceAt - 1; k >= 0 && braceAt - k < 400; k--) {
    final c = src[k];
    if (c == '{' || c == '}' || c == ';') break;
    buf.write(c);
  }
  final header = buf.toString().split('').reversed.join('');
  return _loopKeyword.hasMatch(header) || _iterCallback.hasMatch(header);
}

/// 去掉行注释，但保留 URL（`https://…`）里的双斜杠。
String _stripLineComment(String line) {
  for (var i = 0; i < line.length - 1; i++) {
    if (line[i] == '/' && line[i + 1] == '/') {
      if (i > 0 && line[i - 1] == ':') continue;
      return line.substring(0, i);
    }
  }
  return line;
}

List<String> _allLibFiles() {
  final out = <String>[];
  void walk(Directory d) {
    for (final e in d.listSync(followLinks: false)) {
      if (e is Directory) {
        walk(e);
      } else if (e is File && e.path.endsWith('.dart')) {
        out.add(e.path);
      }
    }
  }

  walk(Directory('lib'));
  return out;
}
