import '../utils/npc_lookup.dart';
import '../providers/game_provider_base.dart';
import '../data/command_registry.dart';
import '../models/game_systems.dart';
import 'mixin_commands.dart';

/// 指令注册表数据段·活动组（r10-3 拆分自 mixin_commands_registry.dart）。
///
/// 覆盖：活动 & 玩法 CommandDef 注册函数（魁地奇/决斗/社团等玩法指令）。
/// handler 里引用 GameCommandsMixin 成员——运行时 GameProvider with 链同时具备，
/// 静态 cast 保持既有写法。
mixin GameCommandsRegistryActivityMixin on GameProviderBase {
// —— 活动 & 玩法 ——
  void registerActivityCommands(CommandRegistry registry) {
    registry.registerAll([
      CommandDef(
        primary: '魁地奇',
        group: '玩法&活动',
        helpText: '魁地奇：/魁地奇 比赛·/魁地奇 训练·/魁地奇 位置 <位置>',
        subs: [
          CommandSub('比赛', '参加魁地奇比赛'),
          CommandSub('训练', '位置专项训练（每周2次，为比赛+实力）'),
          CommandSub('位置', '查看/更换场上位置', argHint: '位置'),
        ],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isNotEmpty && ctx.arg(0) == '比赛') {
            m.playQuidditch();
          } else if (ctx.parts.isNotEmpty && ctx.arg(0) == '训练') {
            m.trainQuidditch();
          } else if (ctx.parts.length >= 2 && ctx.arg(0) == '位置') {
            m.setQuidditchPosition(ctx.arg(1)!);
          } else {
            m.currentNarrative = m.formatQuidditch();
            m.choices = [GameChoice(text: '返回', action: '继续')];
          }
          return true;
        },
      ),
      CommandDef(
        primary: '魔药',
        group: '玩法&活动',
        helpText: '魔药部限时配方：/魔药 配方·/魔药 酿造 <配方id>',
        subs: [
          CommandSub('配方', '查看当前窗口配方'),
          CommandSub('酿造', '酿造配方药水', argHint: '配方id'),
        ],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isNotEmpty && ctx.arg(0) == '配方') {
            m.showPotionRecipes();
          } else if (ctx.parts.length >= 2 && ctx.arg(0) == '酿造') {
            m.brewPotion(ctx.arg(1)!);
          } else {
            m.showPotionRecipes();
          }
          return true;
        },
      ),
      CommandDef(
        primary: '快讯',
        group: '玩法&活动',
        helpText: '快讯社头版：/快讯 头版·/快讯 报道 <序号> <角度>',
        subs: [
          CommandSub('头版', '查看本学期可报道素材'),
          CommandSub('报道', '选定素材报道', argHint: '序号 角度'),
        ],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isNotEmpty && ctx.arg(0) == '头版') {
            m.showHeadlineBoard();
          } else if (ctx.parts.length >= 3 && ctx.arg(0) == '报道') {
            final idx = int.tryParse(ctx.arg(1) ?? '') ?? -1;
            m.reportHeadline(idx - 1, ctx.arg(2)!);
          } else {
            m.showHeadlineBoard();
          }
          return true;
        },
      ),
      CommandDef(
        primary: '决斗',
        group: '玩法&活动',
        helpText: '与NPC巫师决斗：/决斗 [NPC名]（空参随机）·/决斗 赛季（赛季面板与领奖）',
        subs: [CommandSub('赛季', '查看决斗赛季积分与档位奖励')],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isNotEmpty && ctx.arg(0) == '赛季') {
            if (ctx.parts.length >= 2 && ctx.arg(1) == '领奖') {
              m.claimDuelSeasonReward();
            } else {
              m.showDuelSeasonPanel();
            }
          } else {
            final arg = ctx.parts.isNotEmpty ? ctx.tailFrom(0) : null;
            m.duelNpc(arg);
          }
          return true;
        },
      ),
      CommandDef(
        primary: '禁林',
        group: '玩法&活动',
        helpText: '禁林探险：/禁林 探险',
        subs: [CommandSub('探险', '进入禁林探险')],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isNotEmpty && ctx.arg(0) == '探险') {
            m.exploreForbiddenForest();
          } else {
            m.currentNarrative =
                '【禁林】\n'
                '黑暗而神秘的森林，栖息着许多神奇生物，也藏着危险。\n'
                '输入 /禁林 探险 进入禁林探索（消耗 3 小时，可能遭遇生物、采集材料或受伤）。\n\n'
                '低年级学生请量力而行——一年级的魔杖在这里还很脆弱。';
            m.choices = [GameChoice(text: '返回', action: '继续')];
          }
          return true;
        },
      ),
      CommandDef(
        primary: '图鉴',
        group: '玩法&活动',
        helpText: '魔法世界图鉴：收录你的见闻（/图鉴 详情 查看条目说明）',
        panel: true,
        subs: [CommandSub('详情', '查看已收录条目的完整说明')],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatCollectionPanel(
            detailed: ctx.parts.isNotEmpty && ctx.arg(0) == '详情',
          );
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '委托',
        group: '玩法&活动',
        helpText: '支线委托板：/委托 刷新·接受 [编号]·交付 [编号]',
        subs: [
          CommandSub('刷新', '刷新委托板'),
          CommandSub('接受', '接受委托', argHint: '编号'),
          CommandSub('交付', '交付委托', argHint: '编号'),
        ],
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isNotEmpty && ctx.arg(0) == '刷新') {
            m.refreshQuestBoard();
          } else if (ctx.parts.length >= 2 && ctx.arg(0) == '接受') {
            m.acceptQuest((int.tryParse(ctx.arg(1)!) ?? 0) - 1);
          } else if (ctx.parts.length >= 2 && ctx.arg(0) == '交付') {
            m.deliverQuest((int.tryParse(ctx.arg(1)!) ?? 0) - 1);
          } else {
            m.currentNarrative = m.formatQuests();
            m.choices = [GameChoice(text: '返回', action: '继续')];
          }
          return true;
        },
      ),
      CommandDef(
        primary: '学院杯',
        group: '玩法&活动',
        helpText: '查看学院杯积分与排名',
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatHouseCup();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '新NPC',
        group: '玩法&活动',
        helpText: '生成/查看新NPC：/新NPC（列表）｜/新NPC [全名]（档案）｜/新NPC 生成 [数量]',
        subs: [
          CommandSub('生成', '批量生成新 NPC', argHint: '数量'),
          CommandSub('好感', '调整新 NPC 好感', argHint: 'NPC名'),
        ],
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          // 框架 7.7：/新NPC 查看所有已生成新NPC列表；/新NPC [全名] 查看指定档案；
          // /新NPC 生成 [数量] 生成。历史版本把「查档案」误触发生成（副作用+BUG-FIX），
          // 这里对齐框架：无参=列表，名字=档案，只有显式 生成/数字 才生成。
          final generated = m.npcRegistry.values
              .where((n) => n.isGenerated)
              .toList();

          // 1) 作弊路径
          if (ctx.parts.isNotEmpty && ctx.arg(0) == '好感') {
            m.cheatNewNpc(['新NPC', '好感', ctx.arg(1) ?? '', ctx.arg(2) ?? '']);
            m.choices = [GameChoice(text: '返回', action: '继续')];
            return true;
          }

          // 2) 生成路径：/新NPC 生成 [N] 或 /新NPC <数字>
          if (ctx.parts.isNotEmpty) {
            if (ctx.arg(0) == '生成') {
              final count = (int.tryParse(ctx.arg(1) ?? '') ?? 1).clamp(1, 5);
              final names = <String>[];
              for (var i = 0; i < count; i++) {
                m.generateNewNPC();
                final gen = m.npcRegistry.values
                    .where((n) => n.isGenerated)
                    .toList();
                if (gen.isNotEmpty) names.add(gen.last.name);
              }
              m.currentNarrative =
                  '📬 一次性生成 $count 位新NPC：\n${names.join('\n')}\n\n'
                  '他们或许会成为你故事里的一部分。';
              // 事件类指令：清空选项，输出即剧情（面板标记只适用于列表/档案查看）
              m.choices = [];
              return true;
            }
            final asNumber = int.tryParse(ctx.arg(0) ?? '');
            if (asNumber != null) {
              final count = asNumber.clamp(1, 5);
              final names = <String>[];
              for (var i = 0; i < count; i++) {
                m.generateNewNPC();
                final gen = m.npcRegistry.values
                    .where((n) => n.isGenerated)
                    .toList();
                if (gen.isNotEmpty) names.add(gen.last.name);
              }
              m.currentNarrative =
                  '📬 一次性生成 $count 位新NPC：\n${names.join('\n')}\n\n'
                  '他们或许会成为你故事里的一部分。';
              m.choices = [];
              return true;
            }
          }

          // 3) 档案路径：/新NPC [全名]（仅已生成 NPC）
          final kw = ctx.tailFrom(0).trim();
          if (kw.isNotEmpty) {
            final target = generated.isEmpty
                ? null
                : findNpcByKeyword(generated, kw);
            if (target != null) {
              m.currentNarrative = m.formatCharacterDossier(target.name);
              m.choices = [GameChoice(text: '返回', action: '继续')];
              return true;
            }
            m.currentNarrative =
                '【新NPC】\n没有叫「$kw」的生成NPC。\n\n'
                '已生成 ${generated.length} 位：${generated.map((n) => n.name).join('、')}。\n'
                '用 /新NPC 生成 一位新同学。';
            m.choices = [GameChoice(text: '返回', action: '继续')];
            return true;
          }

          // 4) 列表路径：/新NPC（无参数）
          if (generated.isEmpty) {
            m.currentNarrative =
                '【新NPC】\n还没有生成过新NPC。\n'
                '用 /新NPC 生成 一位属于你故事的新同学。';
          } else {
            final lines = generated
                .map(
                  (n) =>
                      '· ${n.name}｜${n.house.isEmpty ? '未知学院' : n.house}'
                      '${n.grade}年级｜好感 ${n.affection}'
                      '（${n.affectionStage}）\n'
                      '   ${n.appearance.isNotEmpty ? n.appearance : ''}'
                      '${n.personalGoal != null && n.personalGoal!.isNotEmpty ? '｜${n.personalGoal}' : ''}',
                )
                .join('\n');
            m.currentNarrative =
                '【新NPC · 已生成 ${generated.length} 位】\n$lines\n\n'
                '想看某位详情：/新NPC [全名]';
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '室友',
        group: '关系&情感',
        helpText: '室友互动：/室友（列表）·/室友 聊天·/室友 早起',
        panel: true,
        subs: [
          CommandSub('聊天', '和室友聊聊（好感 +1，冷却 3 回合）'),
          CommandSub('早起', '让室友叫你起床（概率性，精力 +1）'),
        ],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isNotEmpty && ctx.arg(0) == '聊天') {
            m.currentNarrative = m.roommateChat();
          } else if (ctx.parts.isNotEmpty && ctx.arg(0) == '早起') {
            m.currentNarrative = m.roommateWakeUp();
          } else {
            m.currentNarrative = m.formatRoommatePanel();
            m.choices = [GameChoice(text: '返回', action: '继续')];
          }
          return true;
        },
      ),
    ]);
  }
}
