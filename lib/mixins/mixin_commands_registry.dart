/// 指令注册表数据段（r7-2 拆分自 mixin_commands.dart）。
///
/// 覆盖：关系/学业/物品/活动/世界五大组 CommandDef 注册函数（60+ 条指令）。
/// handler 里引用 GameCommandsMixin / GameCommandsExtrasMixin 的成员——
/// 运行时 GameProvider with 链同时具备两者（Extras on Commands），静态 cast
/// 保持既有写法。通过 on 链复用 [GameCommandsMixin] 的注册入口。
library;

import '../data/collectible_data.dart';
import '../data/course_data.dart';
import '../providers/game_provider_base.dart';
import '../data/command_registry.dart';
import '../models/game_systems.dart';
import 'mixin_commands.dart';
import 'mixin_commands_extras.dart';
import 'mixin_commands_registry_world.dart';
import 'mixin_commands_registry_activity.dart';

mixin GameCommandsRegistryMixin
    on GameProviderBase,
        GameCommandsRegistryWorldMixin,
        GameCommandsRegistryActivityMixin {
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

}
