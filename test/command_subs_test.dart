/// P2#11/#17 源码契约：二级指令结构化 + 指令缺口不得回潮。
///
/// 指令中心面板的「二级指令一键执行」依赖注册表里每一条带子命令的指令
/// 都声明了 subs（CommandSub）；一旦有人图省事只写 helpText、不写 subs，
/// 面板就退回"填参打字"的老交互。这里用源码扫描钉死：
///  · 高频子命令指令必须都有 subs
///  · P2#11 补的缺口子命令分支（/时间 快进、/时间 日程、/恋爱 历史、
///    /档案 回忆、/收藏 详情、/联动 状态）不得被后续重构删掉
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/mixins/mixin_commands.dart').readAsStringSync();

  group('二级指令结构化（P2 指令面板一键执行的前提）', () {
    test('高频子命令指令都必须声明 subs', () {
      // 这些指令的 helpText 里写了 ｜ 分隔的子命令，注册表就必须有对应 subs，
      // 否则面板上它们依然是"手动填参"，用户痛点未解决。
      const mustHaveSubs = [
        '快进', '城堡', '声望', '课程', '课堂', '咒语', '日记', '宠物',
        '魁地奇', '禁林', '委托', '新NPC', '信', '传承', '教职',
        '守护神', '阿尼马格斯', '职业', '计划', '目标', 'cheat',
        '时间', '恋爱', '档案', '联动',
      ];
      for (final cmd in mustHaveSubs) {
        final blockStart = src.indexOf("primary: '$cmd'");
        expect(blockStart, greaterThan(-1), reason: '找不到指令 $cmd');
        final blockEnd = src.indexOf('\n      ),', blockStart);
        final block =
            src.substring(blockStart, blockEnd == -1 ? blockStart + 600 : blockEnd);
        expect(
          block.contains('subs: ['),
          isTrue,
          reason: '指令 /$cmd 的子命令已写入 helpText 但没声明 subs，'
              '面板将退回"手动填参"',
        );
        expect(
          block.contains('CommandSub('),
          isTrue,
          reason: '指令 /$cmd 的 subs 列表为空',
        );
      }
    });

    test('每个 subs 的 keyword 都不为空字符串', () {
      expect(
        src.contains("CommandSub('',"),
        isFalse,
        reason: '子命令关键词不允许为空',
      );
    });

    test('面板渲染子命令按钮（chip 文本用 keyword 而非 help）', () {
      final panel = File('lib/screens/game/command_center_panel.dart')
          .readAsStringSync();
      expect(panel.contains('_buildSubChip'), isTrue,
          reason: '二级指令按钮渲染函数被删');
      expect(panel.contains('sub.argHint != null'), isTrue,
          reason: '带参子命令的"补参"分支被删');
      expect(panel.contains('widget.onExecute(text)'), isTrue,
          reason: '无参子命令的"直接执行"分支被删');
    });
  });

  group('P2#11 指令缺口不得回潮', () {
    test('/时间 快进 分支存在', () {
      expect(src.contains("sub == '快进'"), isTrue,
          reason: '/时间 快进 的分支被删');
      expect(src.contains('resolveFastForwardDays(ctx.tailFrom(1))'), isTrue,
          reason: '/时间 快进 未委托统一快进结算');
    });

    test('/时间 日程 分支存在', () {
      expect(src.contains("sub == '日程'"), isTrue,
          reason: '/时间 日程 的分支被删');
      expect(src.contains('formatDailySchedule'), isTrue,
          reason: '/时间 日程 的日程格式化方法被删');
    });

    test('/恋爱 历史 分支存在', () {
      expect(src.contains("ctx.arg(0) == '历史'"), isTrue,
          reason: '/恋爱 历史 的分支被删');
      expect(src.contains('formatLoveHistory'), isTrue,
          reason: 'formatLoveHistory 被删');
    });

    test('/档案 回忆 分支存在', () {
      expect(src.contains("ctx.arg(0) == '回忆'"), isTrue,
          reason: '/档案 回忆 的分支被删');
      expect(src.contains('formatMemories'), isTrue,
          reason: 'formatMemories 被删');
    });

    test('/收藏 [名称] 详情分支存在', () {
      expect(src.contains('kCollectibleCatalog'), isTrue,
          reason: '收藏目录引用被删');
      expect(src.contains('found.desc.isNotEmpty'), isTrue,
          reason: '/收藏 详情分支被删');
    });

    test('/联动 状态 注册为二级指令', () {
      expect(src.contains("CommandSub('状态', '查看当前时代与世界线详情')"), isTrue,
          reason: '/联动 状态 的 sub 被删');
    });

    test('缺口指令的格式化方法定义在 mixin 内', () {
      expect(src.contains('String formatMemories()'), isTrue);
      expect(src.contains('String formatDailySchedule()'), isTrue);
      final relations =
          File('lib/mixins/mixin_relations.dart').readAsStringSync();
      expect(relations.contains('String formatLoveHistory()'), isTrue);
    });
  });
}
