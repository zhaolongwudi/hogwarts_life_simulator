// 日志出口与脱敏的行为测试（审查 F26 / S2 / S3 的回归网）。
//
// 这里全部是行为断言：真的调函数、看返回值，不读源码文本。
// 脱敏很容易"看起来对"——正则写宽了把正常内容吃掉、写窄了把真 Key 放过，
// 两种情况都不会报错，只能靠断言钉住边界。
import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/utils/debug_log.dart';

void main() {
  group('redactSecrets — 凭证必须被吃掉', () {
    test('Bearer / Basic 认证头', () {
      final out = redactSecrets('请求头: Authorization: Bearer abcdef1234567890xyz');
      expect(out, isNot(contains('abcdef1234567890xyz')));
      expect(out, contains('Bearer')); // 凭证种类要留着，方便判断是什么被吃了
    });

    test('sk- 开头的 Key', () {
      final out = redactSecrets('key=sk-AbCdEf1234567890QwErTy');
      expect(out, isNot(contains('sk-AbCdEf1234567890QwErTy')));
      expect(out, contains('sk-'));
    });

    test('api_key / token / password 的键值写法', () {
      for (final kv in [
        'apiKey: A1b2C3d4E5f6G7h8',
        'api_key=Zx9Yw8Vu7Ts6Rq5',
        'token: eyJhbGciOiJIUzI1NiJ9abcd',
        'password: myPlainTextPass123',
        'secret: s3cr3tV4lu3Here',
      ]) {
        final out = redactSecrets(kv);
        expect(out, contains('***'), reason: '未脱敏: $kv');
        // 键名必须保留，否则日志里看不出是哪种凭证被吃掉了
        expect(out.split(RegExp(r'[:=]')).first.trim(), isNotEmpty);
      }
    });

    test('URL query 里的 key / token 参数', () {
      final out = redactSecrets(
        'POST https://api.example.com/v1/chat?key=SUPERSECRET1234&model=x',
      );
      expect(out, isNot(contains('SUPERSECRET1234')));
      expect(out, contains('model=x')); // 无关参数不能被误伤
    });

    // 这条专门钉住「大小写不敏感」——Dart 的 RegExp 不认 (?i) 内联标志
    // （构造时抛 FormatException: Invalid group），只能靠 caseSensitive: false。
    // 曾经因为写了 (?i) 且规则表是懒初始化，7 个用例在 CI 上集体变红、
    // 本地却毫无察觉。别再改回 (?i)。
    test('大小写混写也要脱敏（钉住 (?i) 的等价实现）', () {
      final cases = <String, String>{
        'authorization: BEARER Zm9vYmFyYmF6cXV1eA': 'Zm9vYmFyYmF6cXV1eA',
        'Authorization: basic dXNlcjpwYXNzd29yZA': 'dXNlcjpwYXNzd29yZA',
        'APIKEY: A1b2C3d4E5f6G7h8': 'A1b2C3d4E5f6G7h8',
        'Token=QwErTy1234567890': 'QwErTy1234567890',
        'PASSWD: myPlainTextPass123': 'myPlainTextPass123',
      };
      for (final entry in cases.entries) {
        final out = redactSecrets(entry.key);
        expect(out, isNot(contains(entry.value)),
            reason: '未脱敏（大小写不敏感失效）: ${entry.key}');
      }
    });
  });

  group('redactSecrets — 正常内容不能被误伤', () {
    test('堆栈里的文件路径与行号要原样保留', () {
      const stack =
          '#0 Foo.bar (package:hogwarts_life_simulator/screens/game/game_narrative_tab.dart:1731:5)\n'
          '#1 Baz.qux (package:flutter/src/widgets/framework.dart:5200:12)';
      expect(redactSecrets(stack), stack);
    });

    test('普通中文与 UUID 不受影响', () {
      const text = '玩家在霍格莫德遇到了 550e8400-e29b-41d4-a716 号事件';
      expect(redactSecrets(text), text);
    });

    test('空串与无凭证文本原样返回', () {
      expect(redactSecrets(''), '');
      expect(redactSecrets('一切正常'), '一切正常');
    });
  });

  group('debugLog', () {
    test('调用不抛异常（release 下静默，debug 下走 debugPrint）', () {
      expect(() => debugLog('hello'), returnsNormally);
      expect(() => debugLog(null), returnsNormally);
      expect(() => debugLog('long' * 100, wrapWidth: 40), returnsNormally);
    });
  });
}
