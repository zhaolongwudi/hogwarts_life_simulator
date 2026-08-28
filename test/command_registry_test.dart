import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/command_registry.dart';
import 'package:hogwarts_life_simulator/providers/game_provider_base.dart';

void main() {
  // ==================== CommandContext 参数语义契约 ====================
  //
  // 背景（v2.3.9 重构引入的回归）：
  //   handleLocalCommand 用 `CommandContext(parts.sublist(1), ...)` 构造上下文，
  //   即 parts **已经去掉命令本身**。但各 handler 仍按旧 switch-case 时代的
  //   约定取参（`parts[1]` 才是第一个参数），导致所有带参数指令集体失效：
  //     `/使用 福灵剂`  → parts=['福灵剂']，length<2 → 只弹帮助，永不执行
  //     `/决斗 金妮`    → length<2 → arg=null → 变成随机决斗
  //     `/禁林 探险`    → length<2 → 探险永远进不去
  //     `/委托 接受 1`  → parts[2] 越界/错位 → 委托无法推进
  //   固定写法：handler 内一律用 arg(0)/arg(1)/tailFrom(0)，不直接下标访问 parts。
  group('CommandContext 参数语义', () {
    test('arg(0) 是第一个子参数（命令本身已被剥离）', () {
      final ctx = CommandContext(['金妮', '认真一点'], _FakeProvider());
      expect(ctx.arg(0), '金妮');
      expect(ctx.arg(1), '认真一点');
    });

    test('越界访问返回 null 而不是抛异常', () {
      final ctx = CommandContext([], _FakeProvider());
      expect(ctx.arg(0), isNull);
      expect(ctx.arg(-1), isNull);
    });

    test('tailFrom 正确拼接剩余参数（支持带空格的物品名）', () {
      final ctx = CommandContext(['福灵剂'], _FakeProvider());
      expect(ctx.tailFrom(0), '福灵剂');

      final ctx2 = CommandContext(['标准', '咒语书'], _FakeProvider());
      expect(ctx2.tailFrom(0), '标准 咒语书');
    });

    test('单参数场景：length==1 即表示「用户给了参数」（旧代码误判为无参）', () {
      final ctx = CommandContext(['探险'], _FakeProvider());
      expect(ctx.parts.length, 1);
      expect(ctx.parts.length >= 1, isTrue, reason: '单参数必须视为有效参数');
      expect(ctx.arg(0), '探险');
    });
  });

  // ==================== 源码契约回归扫描 ====================
  //
  // 这是一道「防呆闸门」：上面那类错位 bug 靠运行时测试很难覆盖
  // （handler 依赖完整 GameProvider 状态，测试环境构造成本极高），
  // 但它在源码上有非常清晰的指纹。这里直接扫描源码，禁止旧约定写法回潮。
  group('指令 handler 取参契约（源码扫描）', () {
    final commandsSrc = File(
      'lib/mixins/mixin_commands.dart',
    ).readAsStringSync();
    final relationsSrc = File(
      'lib/mixins/mixin_relations.dart',
    ).readAsStringSync();

    test('handler 内不得再出现 ctx.parts[1] 等旧下标约定', () {
      expect(
        commandsSrc.contains(RegExp(r'ctx\.parts\[\s*\d+\s*\]')),
        isFalse,
        reason: 'handler 必须用 ctx.arg(i)，直接下标说明又按「含命令名」取参了',
      );
    });

    test('handler 内不得再出现 ctx.parts.sublist(1)（会吞掉第一个真实参数）', () {
      expect(
        commandsSrc.contains('ctx.parts.sublist(1)'),
        isFalse,
        reason: '应改用 ctx.tailFrom(0)',
      );
    });

    test('「用户没给参数」的判定必须用 isEmpty，不得沿用 < 2', () {
      // 注意：>= 2 是合法写法（如 `/委托 接受 1` = 子命令 + 1 个参数），
      // 这里只禁止 < 2 —— 它意味着把命令名也算进参数个数。
      expect(
        commandsSrc.contains('ctx.parts.length < 2'),
        isFalse,
        reason: '子参数列表为空即无参数，阈值应为 isEmpty（< 2 会让单参数指令退化成帮助）',
      );
    });

    test('handleLetterCommand / _handleCheat 的调用点必须传子参数列表', () {
      // 注册表 handler：ctx.parts 本身就是子参数，直接透传即可
      expect(commandsSrc.contains('handleLetterCommand(ctx.parts)'), isTrue);
      expect(commandsSrc.contains('_handleCheat(ctx.parts)'), isTrue);
      // fallback switch：parts 含命令名，必须 sublist(1) 剥离
      expect(commandsSrc.contains('handleLetterCommand(parts.sublist(1))'), isTrue);
      expect(commandsSrc.contains('_handleCheat(parts.sublist(1))'), isTrue);
    });

    test('信件指令按子参数约定取参', () {
      expect(
        relationsSrc.contains(RegExp(r'switch \(parts\[1\]\)')),
        isFalse,
        reason: 'handleLetterCommand 收到的是子参数列表，第一个元素即子命令',
      );
    });
  });
}

/// 最小 Provider 桩。
///
/// GameProviderBase 是承载字段的抽象基类，有几十个供 6 个 Mixin 实现的抽象成员，
/// 逐个 stub 不现实。这里借助 Dart 的 noSuchMethod 转发：类显式声明 noSuchMethod 后，
/// 未实现的抽象成员会被编译器自动生成转发调用，因此可直接实例化。
/// 本测试只验证参数语义，不会访问 provider 的任何成员。
class _FakeProvider extends GameProviderBase {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
