/// 指令注册表数据段（r7-2 拆分自 mixin_commands.dart）。
///
/// 覆盖：关系/学业/物品/活动/世界五大组 CommandDef 注册函数（60+ 条指令）。
/// handler 里引用 GameCommandsMixin / GameCommandsExtrasMixin 的成员——
/// 运行时 GameProvider with 链同时具备两者（Extras on Commands），静态 cast
/// 保持既有写法。通过 on 链复用 [GameCommandsMixin] 的注册入口。
library;

import 'dart:async';
import '../utils/npc_lookup.dart';
import '../data/goal_data.dart';
import '../data/worldline_data.dart';
import '../data/legacy_data.dart';
import '../data/collectible_data.dart';
import '../data/course_data.dart';
import '../mixins/mixin_club.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';
import '../data/command_registry.dart';
import '../models/game_systems.dart';
import 'mixin_commands.dart';
import 'mixin_commands_extras.dart';

mixin GameCommandsRegistryMixin on GameProviderBase {
  void registerRelationCommands(CommandRegistry registry) {
    registry.registerAll([
      CommandDef(
        primary: '关系',
        group: '关系&情感',
        helpText: '查看所有NPC好感度与关系',
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatRelationships();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '查看',
        aliases: ['看', '打量', '观察', '打听'],
        group: '关系&情感',
        panel: true,
        helpText: '查看某位NPC的档案：/查看 [名字]（不带名字则列出可查看的人）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatCharacterDossier(ctx.tailFrom(0));
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '送礼',
        aliases: ['送', '赠', '赠送', '给'],
        group: '关系&情感',
        helpText:
            '把背包里的东西送给NPC：/送礼 [名字] [物品]，例如 /送礼 赫敏 旧书'
            '（只写名字则提示对方喜好）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          // 「/送礼 赫敏 旧书」：首词是人名，其余是物品名
          // （物品名本身可能含空格，所以取剩下整段而不是 arg(1)）
          final who = ctx.arg(0) ?? '';
          final what = ctx.tailFrom(1);
          m.currentNarrative = m.giveGift(who, what);
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '恋爱',
        group: '关系&情感',
        helpText: '查看恋爱状态（/恋爱 历史 回看一路走来的心动事件）',
        panel: true,
        subs: [CommandSub('历史', '回看恋爱相关的事件记录')],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsExtrasMixin;
          if (ctx.parts.isNotEmpty &&
              (ctx.arg(0) == '历史' ||
                  ctx.arg(0) == '回顾' ||
                  ctx.arg(0) == '过往')) {
            m.currentNarrative = m.formatLoveHistory();
            m.choices = [GameChoice(text: '返回', action: '继续')];
            return true;
          }
          m.currentNarrative = m.formatLove();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '声望',
        group: '关系&情感',
        helpText: '查看声望（/声望 恋爱·/声望 NPC [名字]·/声望 NPC 列表·/声望 NPC 排名 [维度]）',
        subs: [
          CommandSub('恋爱', '查看恋爱声望'),
          CommandSub('NPC 列表', '列出可查声望的 NPC'),
          CommandSub('NPC 排名', '按维度排名', argHint: '维度'),
        ],
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsExtrasMixin;
          if (ctx.parts.isNotEmpty && ctx.arg(0) == '恋爱') {
            m.currentNarrative = m.formatLoveReputation();
          } else if (ctx.parts.isNotEmpty && ctx.arg(0) == 'NPC') {
            final p2 = ctx.parts.skip(1).toList();
            if (p2.isNotEmpty && p2[0] == '列表') {
              m.currentNarrative = m.formatNpcReputationList();
            } else if (p2.isNotEmpty && p2[0] == '排名') {
              m.currentNarrative = m.formatNpcReputationRanking(
                p2.length > 1 ? p2[1] : 'academic',
              );
            } else if (p2.isNotEmpty) {
              m.currentNarrative = m.formatNpcReputation(p2.join(' '));
            } else {
              m.currentNarrative =
                  '用法：/声望 NPC [名字] ｜ /声望 NPC 列表 ｜ /声望 NPC 排名 [维度]';
            }
          } else {
            m.currentNarrative = m.formatReputation();
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '舆论',
        // 「谣言」以前只出现在 helpText 里，玩家照着输会得到一个「未知指令」
        aliases: ['传闻', '谣言'],
        group: '关系&情感',
        panel: true,
        helpText: '查看校园里的传闻/谣言',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatRumors();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '血缘',
        group: '关系&情感',
        helpText: '查看血缘亲属',
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatBloodRelatives();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '恋爱等待',
        group: '关系&情感',
        helpText: '查看等待中的恋爱事件',
        panel: true,
        // 别加带空格的别名：调度只拿 parts[0] 去 find，永远匹配不上
        aliases: const [],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatLoveWaiting();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '恋爱阶段',
        group: '关系&情感',
        helpText: '查看恋爱阶段说明',
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatLoveStages();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '关系网络',
        // 同上：带空格的别名匹配不上。真正能用的是 /关系网络
        aliases: const [],
        group: '关系&情感',
        panel: true,
        helpText: '查询两位NPC间的关系（/关系网络 [NPC1] [NPC2]）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.length >= 2) {
            m.currentNarrative = m.formatNpcRelationship(
              ctx.arg(0)!,
              ctx.arg(1)!,
            );
          } else {
            m.currentNarrative = '请输入两位NPC的名字：/关系网络 [NPC1] [NPC2]';
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '骨科',
        aliases: ['骨科状态'],
        group: '关系&情感',
        panel: true,
        helpText: '查看骨科模式状态',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatBoneMode();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '家庭',
        aliases: ['婚姻', '配偶', '孩子', '子女'],
        group: '关系&情感',
        panel: true,
        helpText: '查看婚姻/怀孕/子女状态',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatFamily();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '求婚',
        aliases: ['求婚戒指'],
        group: '关系&情感',
        helpText: '向恋人求婚（需恋爱中、好感≥95、五年级以上）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final err = m.proposeMarriage();
          m.currentNarrative = err != null
              ? '【求婚】\n$err\n\n${m.formatFamily()}'
              : '你单膝跪地，把戒指举到对方面前。\n\n${m.formatFamily()}';
          m.choices = [
            if (err == null) GameChoice(text: '筹备婚礼', action: '/结婚'),
            GameChoice(text: '返回', action: '继续'),
          ];
          return true;
        },
      ),
      CommandDef(
        primary: '结婚',
        aliases: ['婚礼', '举行婚礼'],
        group: '关系&情感',
        helpText: '举行婚礼（需已订婚）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final err = m.holdWedding();
          m.currentNarrative = err != null
              ? '【婚礼】\n$err\n\n${m.formatFamily()}'
              : '礼堂里洒满了花瓣，你们在众人的注视下交换了誓言。\n\n${m.formatFamily()}';
          m.choices = [
            if (err == null) GameChoice(text: '要个孩子', action: '/生育'),
            GameChoice(text: '返回', action: '继续'),
          ];
          return true;
        },
      ),
      CommandDef(
        primary: '生育',
        aliases: ['备孕', '要孩子', '怀孕'],
        group: '关系&情感',
        helpText: '婚后备孕（孕期 120 天，可用 /快进 推进）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final err = m.tryConceive();
          m.currentNarrative = err != null
              ? '【生育】\n$err\n\n${m.formatFamily()}'
              : '你们决定迎接一个新生命。\n\n${m.formatFamily()}';
          m.choices = [
            if (err == null) GameChoice(text: '快进一个月', action: '/快进 下月'),
            GameChoice(text: '返回', action: '继续'),
          ];
          return true;
        },
      ),
      CommandDef(
        primary: '拉郎配',
        aliases: ['撮合', '拉郎', '配对', '磕cp', '磕CP'],
        group: '关系&情感',
        helpText: '撮合两位NPC：/拉郎配 [甲] [乙]（/拉郎配 放弃 [编号] 放手）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final a = ctx.arg(0);
          final b = ctx.arg(1);
          if (a != null && a == '放弃') {
            final idx = int.tryParse(b ?? '');
            if (idx == null) {
              m.currentNarrative = '请输入要放手的编号：/拉郎配 放弃 [编号]';
            } else {
              m.stopShipping(idx - 1);
              m.currentNarrative = m.formatShippings();
            }
          } else if (a != null && b != null) {
            final err = m.startShipping(a, b);
            m.currentNarrative = err != null
                ? '【拉郎配】\n$err'
                : m.formatShippings();
          } else {
            m.currentNarrative = m.formatShippings();
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
    ]);
  }

  // —— 学业 & 成就 & 收藏类 ——
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

  // —— 物品 & 宠物 ——
  void registerItemCommands(CommandRegistry registry) {
    registry.registerAll([
      CommandDef(
        primary: '宠物',
        group: '物品&宠物',
        helpText: '宠物：查看 / 喂食 / 玩耍 / 训练 / 购买',
        subs: [
          CommandSub('喂食', '喂宠物'),
          CommandSub('玩耍', '陪宠物玩'),
          CommandSub('训练', '训练宠物'),
          CommandSub('购买', '去商店买宠物'),
        ],
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsExtrasMixin;
          final sub = ctx.arg(0);
          if (sub != null &&
              ['喂食', '喂', '食物', '玩耍', '玩', '训练', '练'].contains(sub)) {
            m.petInteract(sub);
          } else if (sub != null && ['购买', '买', '选购', '挑选'].contains(sub)) {
            // 以前没宠物时 /宠物 会让人「去对角巷挑选」，但商店里没宠物卖。
            // 现在这里真能买。
            m.currentNarrative = m.buyPet(ctx.tailFrom(1));
          } else {
            m.currentNarrative = m.formatPet();
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '使用',
        group: '物品&宠物',
        helpText: '使用背包物品：/使用 <物品名>',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isEmpty) {
            m.currentNarrative = m.formatItemUseHelp();
          } else {
            m.useItem(ctx.tailFrom(0));
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '装备',
        group: '物品&宠物',
        helpText: '穿戴装备：/装备 <物品名>',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isEmpty) {
            m.currentNarrative = m.formatEquip();
          } else {
            m.equipItem(ctx.tailFrom(0));
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '卸下',
        group: '物品&宠物',
        helpText: '脱下装备：/卸下 <袍子|帽子|扫帚|饰品>',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isEmpty) {
            m.currentNarrative = m.formatEquip();
          } else {
            m.unequipItem(ctx.arg(0)!);
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
    ]);
  }

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
  // —— 信件 & 目标 & 世界 & 结局 ——
  void registerWorldCommands(CommandRegistry registry) {
    registry.registerAll([
      CommandDef(
        primary: '信',
        group: '信件&目标',
        helpText: '查看信件：读/回/寄（/信 读 [编号]·/信 回 [编号] [内容]·/信 寄 [NPC] [内容]）',
        subs: [
          CommandSub('读', '读一封信', argHint: '编号'),
          CommandSub('回', '回信', argHint: '编号'),
          CommandSub('寄', '寄信给 NPC', argHint: 'NPC'),
        ],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.handleLetterCommand(ctx.parts);
          // handler 里已经写了 choices
          return true;
        },
      ),
      CommandDef(
        primary: '联动',
        group: '世界&结局',
        helpText: '查看时代联动痕迹（/联动 状态 查看当前时代详情）',
        panel: true,
        subs: [CommandSub('状态', '查看当前时代与世界线详情')],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          // 文案以前许诺过跨时代联动（遇到亲世代留下的物品或
          // 信件）"，但那套内容并不存在，而列表又从来没被写入过——玩家看到的
          // 永远是一句「暂无。」加一段兑现不了的说明。改成如实描述：这里记的
          // 是你亲手造成的不可逆分叉。
          final branches = m.worldState.timelineBranches;
          m.currentNarrative =
              '【世界线】\n当前时代：${m.eraLabel(m.appProvider.era)}\n'
              '每跨过一个回不了头的节点，世界线就分出一条只有这一周目存在的支流。\n'
              '世界线变动次数：${m.worldState.timelineChanges}\n'
              '已记录的分叉：\n${branches.isEmpty ? '暂无——毕业、成婚这类不可逆的节点会出现在这里。' : branches.reversed.map((b) => '· $b').join('\n')}';
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '世界线',
        aliases: ['变动率', '分歧点'],
        group: '世界&结局',
        panel: true,
        helpText: '查看世界线变动率、已被你改写的事、还差多少能动下一段原著',
        handler: (ctx) {
          final m = ctx.provider;
          m.currentNarrative = m.formatWorldLine();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      // 带参数的形式（/抉择 <anchorId> <optionId>）根本走不到这儿——
      // processChoice 在 handleLocalCommand 之前就把它拦下来结算了。
      // 注册它只是为了两件事：让玩家能回头看一眼当前悬着的分歧点，
      // 以及不让「文案里出现 /抉择 却没这个命令」这类检查报警。
      CommandDef(
        primary: '抉择',
        group: '世界&结局',
        helpText: '查看当前是否有一个悬而未决的分歧点',
        panel: true,
        handler: (ctx) {
          final m = ctx.provider;
          final id = m.pendingCausalAnchorId;
          final anchor = id == null ? null : causalAnchorFor(id);
          m.currentNarrative = anchor == null
              ? '【抉择】\n眼下没有悬而未决的分歧点。\n'
                    '它们只在原著里那些写死的节点上出现，而且得等你的世界线'
                    '偏得够远——输入 /世界线 看看还差多少。'
              : '【${anchor.title}】\n${anchor.setup}\n\n'
                    '${anchor.options.map((o) => '· ${o.text}').join('\n')}\n\n'
                    '在下面的选项里挑一个就行。';
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '伤痕',
        group: '个人',
        helpText: '查看身上永远不会好的那些伤，以及它们留下了什么',
        panel: true,
        handler: (ctx) {
          final m = ctx.provider;
          m.currentNarrative = m.formatScars();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '成长',
        aliases: ['成长总账'],
        group: '个人',
        helpText: '查看属性成长总账：开局定型值 vs 现在（P1-9）',
        panel: true,
        handler: (ctx) {
          final m = ctx.provider;
          m.currentNarrative = m.formatGrowth();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      // /传承 名字 会开一局新的，所以在 handler 里异步地跑，
      // 先把"正在交棒"这句话回给玩家，别让界面卡在空白上。
      CommandDef(
        primary: '传承',
        group: '世界&结局',
        helpText: '把这一生交棒给下一代；/传承 名字 正式开始新的一局',
        subs: [CommandSub('名字', '指定继承人名字开始新一局', argHint: '名字')],
        panel: true,
        handler: (ctx) {
          final m = ctx.provider;
          final name = ctx.tailFrom(0).trim();
          if (name.isEmpty) {
            m.currentNarrative = m.formatLegacy();
            m.choices = [GameChoice(text: '返回', action: '继续')];
            return true;
          }
          final heir = m.heirsOfAge().cast<ChildRecord?>().firstWhere(
            (c) => c!.name == name,
            orElse: () => null,
          );
          if (heir == null) {
            m.currentNarrative =
                '没有找到叫「$name」的孩子，'
                '或者他还没到 $kHeirEntranceAge 岁。\n'
                '输入 /传承 看看谁能接棒。';
            m.choices = [GameChoice(text: '返回', action: '继续')];
            return true;
          }
          m.currentNarrative = '【传承】\n正在把这一生交给$name……';
          m.choices = const [];
          unawaited(m.startLegacy(name));
          return true;
        },
      ),
      // 带「接受/婉拒」的形式走不到这儿——processChoice 会先拦下来结算，
      // 再把「我留下来了」当成玩家行动发给 AI 续写毕业后的第一天。
      CommandDef(
        primary: '教职',
        group: '世界&结局',
        helpText: '查看留校任教的资格与晋升进度；/教职 接受 或 /教职 婉拒 答复邀请',
        subs: [CommandSub('接受', '接受留校任教邀请'), CommandSub('婉拒', '婉拒留校任教邀请')],
        panel: true,
        handler: (ctx) {
          final m = ctx.provider;
          m.currentNarrative = m.formatFaculty();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '世界演化',
        group: '世界&结局',
        helpText: '查看世界演化情况',
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatWorldEvolution();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '守护神',
        aliases: ['呼神护卫'],
        group: '学业&成长',
        panel: true,
        helpText: '守护神之路：/守护神 状态 ｜ /守护神 尝试（框架2 第66条）',
        subs: [CommandSub('状态', '查看守护神状态'), CommandSub('尝试', '尝试召唤守护神')],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsExtrasMixin;
          m.handlePatronus(ctx.parts);
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '阿尼马格斯',
        aliases: ['阿尼玛格斯', '变身'],
        group: '学业&成长',
        panel: true,
        helpText: '阿尼马格斯之路：/阿尼马格斯 状态｜学习｜训练｜尝试｜登记（框架2 第67条）',
        subs: [
          CommandSub('状态', '查看变身进度'),
          CommandSub('学习', '学习阿尼马格斯'),
          CommandSub('训练', '训练变身'),
          CommandSub('尝试', '尝试变身'),
          CommandSub('登记', '登记变身'),
        ],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.handleAnimagusCommand(ctx.parts);
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '职业',
        aliases: ['工作', '就职'],
        group: '世界&结局',
        panel: true,
        helpText: '毕业后正式职业（/职业 列表｜选择 <职业名>｜状态｜辞职）',
        subs: [
          CommandSub('列表', '查看可选职业'),
          CommandSub('选择', '选择职业', argHint: '职业名'),
          CommandSub('状态', '查看职业状态'),
          CommandSub('辞职', '辞去当前职业'),
        ],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.handleCareerCommand(ctx.parts);
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '计划',
        aliases: ['周计划', '这周'],
        group: '学业&成长',
        helpText: '批量推进一周：/计划 学习｜社交｜魁地奇｜调查｜放松（框架2 周计划）',
        subs: [
          CommandSub('学习', '本周计划：学习'),
          CommandSub('社交', '本周计划：社交'),
          CommandSub('魁地奇', '本周计划：魁地奇'),
          CommandSub('调查', '本周计划：调查'),
          CommandSub('放松', '本周计划：放松'),
        ],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsExtrasMixin;
          m.handlePlan(ctx.parts);
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '回忆册',
        aliases: ['回忆'],
        group: '学业&成长',
        helpText: 'NPC 回忆收集进度：好感达标后聊天解锁（/回忆册）',
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsExtrasMixin;
          m.currentNarrative = m.formatCollectedMemories();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '节庆',
        aliases: ['节日', '庆典'],
        group: '学业&成长',
        helpText: '霍格沃茨年度节庆日历：本学年已庆祝/待庆祝的节日（/节庆）',
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsExtrasMixin;
          m.currentNarrative = m.formatFestivalCalendar();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '社团',
        aliases: ['俱乐部'],
        group: '学业&成长',
        helpText: '校园社团：加入/查看/退出社团，长期出力可逐级晋升；社团任务跨回合推进（/社团 [id]·/社团 退出·/社团 任务）',
        subs: [
          CommandSub('退出', '退出当前社团'),
          CommandSub('任务', '查看社团任务（接取/完成领奖）'),
          CommandSub('duel', '加入决斗俱乐部'),
          CommandSub('potion', '加入魔药部'),
          CommandSub('broom', '加入魁地奇队'),
          CommandSub('quip', '加入快讯社'),
        ],
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameClubMixin;
          if (ctx.parts.isEmpty) {
            m.currentNarrative = m.formatClubPanel();
          } else if (ctx.parts.first == '退出') {
            m.currentNarrative = m.leaveClub();
          } else if (ctx.parts.first == '任务') {
            final sub = ctx.arg(0) ?? '';
            if (sub == '接取' && ctx.arg(1) != null) {
              m.currentNarrative = m.acceptClubTask(ctx.arg(1)!);
            } else if (sub == '完成') {
              m.currentNarrative = m.claimClubTask();
            } else if (sub == '放弃') {
              m.currentNarrative = m.abandonClubTask();
            } else {
              m.currentNarrative = m.clubTaskPanel();
            }
          } else {
            m.currentNarrative = m.joinClub(ctx.parts.first);
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '目标',
        group: '信件&目标',
        helpText: '查看/设定人生目标（/目标 [编号]·/目标 进度）',
        subs: [CommandSub('进度', '查看目标进度')],
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsExtrasMixin;
          if (ctx.parts.isNotEmpty &&
              (ctx.arg(0) == '进度' || ctx.arg(0) == 'progress')) {
            m.currentNarrative = m.formatGoalProgress();
            m.choices = [GameChoice(text: '返回', action: '继续')];
            return true;
          }
          if (ctx.parts.isNotEmpty) {
            final arg = ctx.tailFrom(0);
            LifeGoal? goal;
            final idx = int.tryParse(arg);
            if (idx != null && idx >= 1 && idx <= lifeGoalCatalog.length) {
              goal = lifeGoalCatalog[idx - 1];
            } else {
              goal = goalById(arg) ?? goalByName(arg);
            }
            if (goal != null) {
              ctx.provider.player?.currentGoal = goal.name;
              m.currentNarrative =
                  '✅ 已设定人生目标：${goal.name}\n'
                  '『${goal.description}』\n\n'
                  '这条目标将牵引后续剧情方向，但你仍可自由行动。\n'
                  '输入 /目标 可重新查看或更换。';
            } else {
              m.currentNarrative = '未找到目标"$arg"。输入 /目标 查看全部目标。';
            }
          } else {
            m.currentNarrative = m.formatGoals();
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '结局',
        aliases: ['终章'],
        group: '世界&结局',
        helpText: '生成终章报告，书写你的七年人生结局',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsExtrasMixin;
          m.startEndingSequence();
          return true;
        },
      ),
    ]);
  }

}
