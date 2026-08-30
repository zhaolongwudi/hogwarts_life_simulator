// ⚠️ 这个文件是「源码形状守卫」，不是行为测试。
//
// 名字里的 consistency 容易让人以为它在校验叙事一致性，实际上每一条断言
// 都只是 `读 lib/xxx.dart 的源码文本 → 查某个子串在不在`。它能抓住
// "这行注入被整个删掉了"，抓不住"注入了但注入错了"——改个变量名就红，
// 逻辑写反却全绿。第六次审查把它算进了「424 条虚假安全感」，第七轮改名
// 代价太大（要动 CI 与历史），所以在此显式标注，避免后来者继续误读。
//
// 迁移方向：新写的同类校验请直接写成行为测试，模板见
// test/audit_round7_test.dart（全程真跑代码，零源码文本断言）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _src(String path) => File(path).readAsStringSync();

void main() {
  // ------------------------------------------- R14：政治立场不要中途漂移
  group('R14 政治立场每回合重述', () {
    final src = _src('lib/mixins/mixin_narrative.dart');

    test('叙事 prompt 里注入了政治立场', () {
      expect(src.contains('p.politicalTendency'), isTrue);
      expect(src.contains('【政治立场】'), isTrue);
    });

    test('注入点在每回合重造的世界上下文里，不是开局那一次', () {
      // 【本局硬设定】是每回合 contextBuffer 里都会写的一行。
      // 立场紧跟其后，说明它走的是同一条每回合路径；
      // 若它落在开局专用的 system prompt 里，中期照样会漂。
      final setting = src.indexOf('【本局硬设定】');
      final stance = src.indexOf('【政治立场】');
      expect(setting, greaterThan(-1));
      expect(stance, greaterThan(setting));
      // 两处注入点不该隔着一整个函数
      expect(stance - setting, lessThan(1200));
    });

    test('立场为空时不写这一行，避免往 prompt 里塞 null', () {
      expect(src.contains("p.politicalTendency?.trim() ?? ''"), isTrue);
      expect(src.contains('stance.isNotEmpty'), isTrue);
    });
  });

  // ------------------------------------- R16：失败链终局日志要写得出来
  group('R16 路由日志的终局判定', () {
    final src = _src('lib/services/ai_router.dart');

    test('遍历的是真正会被尝试的候选，不是完整候选名单', () {
      // 完整名单末尾那位可能压根没配 key、会被 continue 跳过。
      expect(src.contains('for (final provider in attempted)'), isTrue);
      expect(src.contains('for (final provider in candidates)'), isFalse,
          reason: '改回 candidates 之后，末尾候选没配 key 时 isLastKey 永远为假');
    });

    test('终局判定用 attempted.last', () {
      // 只看非注释行：注释里留着对旧写法的说明，那是有价值的上下文。
      final codeLines = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(codeLines.contains('provider == attempted.last'), isTrue);
      expect(codeLines.contains('provider == candidates.last'), isFalse);
    });

    test('attempted 过滤掉了没配 service 的候选', () {
      // 过滤条件必须与循环里的跳过条件一致，否则两边的"最后一个"对不上。
      final def = src.substring(src.indexOf('final attempted ='));
      expect(def, contains('_services[p]'));
      expect(
        def,
        anyOf([contains('isNotEmpty'), contains('length ?? 0'), contains('> 0')]),
      );
    });

    test('attempted 之后不再重复判空', () {
      // 已经过滤过一遍，循环体里再判空会让两个集合再次错位。
      final loop = src.substring(src.indexOf('for (final provider in attempted)'));
      expect(
        loop.substring(0, 200).contains('services.isEmpty'),
        isFalse,
        reason: 'attempted 过滤过之后，循环体开头的判空是冗余且危险的',
      );
    });
  });

  // ------------------------------------------------- R19：第四面墙条款
  group('R19 第四面墙硬禁令', () {
    final src = _src('lib/data/world_rules.dart');

    test('完整版写明了第四面墙', () {
      expect(src.contains('第四面墙'), isTrue);
    });

    test('点名禁掉了最常见的几种破墙说法', () {
      for (final phrase in [
        '作为一个AI',
        '根据游戏规则',
        '在本作设定中',
      ]) {
        expect(src.contains(phrase), isTrue, reason: '禁令里没点名「$phrase」');
      }
    });

    test('禁止把数值写进正文', () {
      expect(src.contains('好感度'), isTrue);
      expect(src.contains('声望+3'), isTrue);
    });

    test('禁止替玩家做重大决定', () {
      expect(src.contains('替玩家做重大选择'), isTrue);
    });

    test('精简版也带了一条，切换开关时不会整条丢掉', () {
      // kUseFusedCompact 一旦翻过来，完整版那一段就整体不生效了。
      expect(src.contains('不提AI/游戏规则/好感度等系统术语'), isTrue);
    });

    test('禁令放在输出格式之前，AI 读顺序上是先立规矩再看格式', () {
      final wall = src.indexOf('第四面墙');
      final format = src.indexOf('━━━ 输出格式 ━━━');
      expect(wall, greaterThan(-1));
      expect(wall, lessThan(format));
    });
  });
}
