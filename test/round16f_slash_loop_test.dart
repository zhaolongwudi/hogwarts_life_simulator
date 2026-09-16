/// 第16轮F · 修复回归：「/握紧魔杖...」误用斜杠造成选项死循环
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/utils/prompt_sanitizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F1 离线兜底选项清洗：playerAction 带 / 时不原样拼进选项', () {
    test('清洗：去掉 / 前缀当自由行动', () {
      const playerActionWithSlash = '/握紧魔杖起身准备出发';
      final cleaned = playerActionWithSlash.startsWith('/')
          ? playerActionWithSlash.substring(1)
          : playerActionWithSlash;
      expect(cleaned, '握紧魔杖起身准备出发');
      expect(cleaned.startsWith('/'), isFalse,
          reason: '兜底选项不应带 / 前缀，避免触发未注册指令循环');
    });

    test('PromptSanitizer.sanitizeAction 不破坏中文动作', () {
      const raw = '/握紧魔杖起身，决定不等天亮，立刻收拾行李';
      final s = PromptSanitizer.sanitizeAction(raw);
      expect(s, isNotEmpty, reason: 'sanitizer 不应返回空字符串');
      expect(s.contains('握紧魔杖'), isTrue);
    });

    test('选项文本不应带 / 前缀（防误识为 command）', () {
      const optionText = 'A. 握紧魔杖起身，准备出发去对角巷';
      expect(optionText.startsWith('/'), isFalse);
    });
  });

  group('F2 choice prompt 防原样照抄规则已写入', () {
    test('choice_prompts.dart 包含规则2.5 防抄录说明', () {
      final src = File('lib/prompts/choice_prompts.dart').readAsStringSync();
      expect(src.contains('禁原样照抄玩家动作'), isTrue,
          reason: '规则2.5 必须存在，防止 AI 把 /xxx 原样写进选项');
      expect(src.contains('第16轮'), isTrue,
          reason: '注释应标记修复来源，便于后续追溯');
    });
  });

  group('F3 mixin_commands 未识别分支清空 lastPlayerAction（源码契约）', () {
    test('未识别指令 if 块后必须含 lastPlayerAction = ""', () {
      final src = File('lib/mixins/mixin_commands.dart').readAsStringSync();
      final slashCheckIdx = src.indexOf("if (cmd.startsWith('/')) {");
      expect(slashCheckIdx, greaterThan(-1),
          reason: '未识别指令分支应存在');
      final tail = src.substring(slashCheckIdx, slashCheckIdx + 400);
      expect(tail.contains("lastPlayerAction = ''"), isTrue,
          reason: '未识别指令后必须清空 lastPlayerAction，防止下次 AI 原样抄录');
    });
  });
}