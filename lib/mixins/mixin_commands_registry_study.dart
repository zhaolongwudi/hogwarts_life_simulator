import '../data/course_data.dart';
import '../data/collectible_data.dart';
import '../providers/game_provider_base.dart';
import '../data/command_registry.dart';
import '../models/game_systems.dart';
import 'mixin_commands.dart';
import 'mixin_commands_extras.dart';

/// 指令注册表数据段·学业组（r10-4 拆分自 mixin_commands_registry.dart）。
///
/// 覆盖：学业 & 课程 & 收藏品 CommandDef 注册函数。
/// handler 里引用 GameCommandsMixin / GameCommandsExtrasMixin 成员——
/// 运行时 GameProvider with 链同时具备，静态 cast 保持既有写法。
mixin GameCommandsRegistryStudyMixin on GameProviderBase {
void registerStudyCommands(CommandRegistry registry) {
    registry.registerAll([
      CommandDef(
        primary: '课程',
        group: '学业&成长',
        helpText: '查看课程表与进度（/课程 成绩 查看考试成绩单）',
        subs: [CommandSub('成绩', '查看考试成绩单'), CommandSub('选课', '管理选修课')],
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsExtrasMixin;
          if (ctx.parts.isNotEmpty &&
              (ctx.arg(0) == '成绩' || ctx.arg(0) == '考试')) {
            m.currentNarrative = m.formatExamRecords();
          } else if (ctx.parts.isNotEmpty &&
              (ctx.arg(0) == '选课' || ctx.arg(0) == '选修')) {
            m.currentNarrative =
                '【选修课】（三年级起，至少选2门）\n'
                '${electiveCourses.map((c) => '· ${c.name}（${c.professor}，${c.minGrade}年级起）').join('\n')}\n\n'
                '选课通过课堂系统自动生效——随着年级提升，选修课会自然进入你的课表。';
          } else {
            m.currentNarrative = m.formatCourses();
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '课堂',
        group: '学业&成长',
        helpText: '触发课堂互动（/课堂 互动）',
        subs: [CommandSub('互动', '触发课堂互动')],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isNotEmpty && ctx.arg(0) == '互动') {
            m.classroomInteraction();
          } else {
            m.currentNarrative =
                '【课堂互动】\n输入 /课堂 互动 触发当前课堂的互动环节（教授提问、实践练习、同桌互动、随机意外）。\n\n当前课表见 /课程。';
            m.choices = [GameChoice(text: '返回', action: '继续')];
          }
          return true;
        },
      ),
      CommandDef(
        primary: '咒语',
        group: '学业&成长',
        helpText: '魔咒一览（/咒语 学习 漂浮咒 ｜ /咒语 练习 漂浮咒 ｜ /咒语 详情 漂浮咒）',
        subs: [
          CommandSub('学习', '学习新咒语', argHint: '咒语名'),
          CommandSub('练习', '练习咒语', argHint: '咒语名'),
          CommandSub('详情', '查看咒语详情', argHint: '咒语名'),
        ],
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final verb = ctx.arg(0) ?? '';
          final rest = ctx.tailFrom(1);
          switch (verb) {
            case '学习':
            case '学':
              if (rest.isEmpty) {
                m.currentNarrative =
                    '要学哪个咒语？用法：/咒语 学习 漂浮咒\n\n'
                    '不知道能学什么就先输入 /咒语';
                m.choices = [GameChoice(text: '返回', action: '继续')];
              } else {
                m.learnSpell(rest);
              }
            case '练习':
            case '练':
              if (rest.isEmpty) {
                m.currentNarrative = '要练哪个咒语？用法：/咒语 练习 漂浮咒';
                m.choices = [GameChoice(text: '返回', action: '继续')];
              } else {
                m.practiseSpell(rest);
              }
            case '详情':
              if (rest.isEmpty) {
                m.currentNarrative = '要查哪个咒语？用法：/咒语 详情 漂浮咒';
                m.choices = [GameChoice(text: '返回', action: '继续')];
              } else {
                m.currentNarrative = m.formatSpellDetail(rest);
                m.choices = [GameChoice(text: '返回', action: '继续')];
              }
            case '':
              m.currentNarrative = m.formatSpells();
              m.choices = [GameChoice(text: '返回', action: '继续')];
            default:
              // 没带动词时把它当成咒语名，等价于 /咒语 详情 xxx
              m.currentNarrative = m.formatSpellDetail(ctx.tailFrom(0));
              m.choices = [GameChoice(text: '返回', action: '继续')];
          }
          return true;
        },
      ),
      CommandDef(
        primary: '收藏',
        group: '学业&成长',
        helpText: '查看收藏品（/收藏 [名称] 查看单件详情）',
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          // P2#11 指令缺口：/收藏 [物品] —— 查单件收藏的详情
          if (ctx.parts.isNotEmpty) {
            final q = ctx.tailFrom(0);
            CollectibleDef? found;
            for (final c in kCollectibleCatalog) {
              if (c.id == q || c.name == q) {
                found = c;
                break;
              }
            }
            if (found == null) {
              m.currentNarrative =
                  '【收藏】\n没有找到叫「$q」的收藏品。'
                  '\n\n输入 /收藏 看看收集册里都有哪些系列。';
              m.choices = [GameChoice(text: '返回', action: '继续')];
              return true;
            }
            final owned = m.player?.collection.contains(found.id) ?? false;
            final buf = StringBuffer('【收藏·${found.name}】');
            if (owned) {
              buf.writeln('\n✅ 已收入册子（${found.starText}）');
            } else {
              buf.writeln('\n🔒 尚未收集（${found.starText}）');
            }
            if (found.desc.isNotEmpty) {
              buf.writeln('\n${found.desc}');
            }
            m.currentNarrative = buf.toString();
            m.choices = [GameChoice(text: '返回', action: '继续')];
            return true;
          }
          m.currentNarrative = m.formatCollection();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '日记',
        group: '学业&成长',
        helpText: 'CG图鉴：统计/详情/重播（/日记 统计·/日记 [编号]·/日记 重播 [编号]）',
        subs: [
          CommandSub('统计', 'CG 收集统计'),
          CommandSub('重播', '重播某张 CG', argHint: '编号'),
        ],
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsExtrasMixin;
          if (ctx.parts.isNotEmpty && ctx.arg(0) == '统计') {
            m.currentNarrative = m.formatDiaryStats();
          } else if (ctx.parts.length >= 2 && ctx.arg(0) == '重播') {
            m.currentNarrative = m.replayCg(ctx.arg(1)!);
          } else if (ctx.parts.isNotEmpty) {
            m.currentNarrative = m.formatCgDetail(ctx.arg(0)!);
          } else {
            m.currentNarrative = m.formatDiary();
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '档案',
        group: '学业&成长',
        helpText: '查看角色完整档案（/档案 回忆 回看人生大事记）',
        panel: true,
        subs: [CommandSub('回忆', '回看人生大事记与成长痕迹')],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsExtrasMixin;
          if (ctx.parts.isNotEmpty &&
              (ctx.arg(0) == '回忆' || ctx.arg(0) == '大事记')) {
            m.currentNarrative = m.formatMemories();
            m.choices = [GameChoice(text: '返回', action: '继续')];
            return true;
          }
          m.currentNarrative = m.formatArchive();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '成就',
        group: '学业&成长',
        helpText: '查看成就列表',
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsExtrasMixin;
          m.currentNarrative = m.formatAchievements();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
    ]);
  }
}
