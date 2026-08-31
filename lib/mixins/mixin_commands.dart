import 'dart:async';
import 'package:flutter/widgets.dart';
import '../data/pet_data.dart';
import '../data/pet_narrative_config.dart';
import '../data/game_config_rules.dart';
import '../data/command_registry.dart';
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../data/cg_data.dart';
import '../data/goal_data.dart';
import '../data/wand_data.dart';
import '../data/castle_data.dart';
import '../data/worldline_data.dart';
import '../data/legacy_data.dart';
import '../data/event_anchors.dart';
import '../data/collectible_data.dart';
import '../data/exam_data.dart';
import '../data/course_data.dart';
import '../data/patronus_data.dart';
import '../data/attribute_data.dart';
import '../models/long_term_memory.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';
import 'mixin_systems.dart';

mixin GameCommandsMixin on GameProviderBase {
  // ================ R1：注册命令到注册表（初始化时调用一次即可） ================
  bool _commandsRegistered = false;

  void _ensureCommandsRegistered() {
    if (_commandsRegistered) return;
    _commandsRegistered = true;
    final registry = CommandRegistry.instance;
    registry.resetForTesting();

    // —— 基础信息类 ——
    registry.registerAll([
      CommandDef(
        primary: '状态',
        group: '基础信息',
        helpText: '查看角色完整状态',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m._formatStatus();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '时间',
        group: '基础信息',
        helpText: '查看当前时间与特殊标记',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m._formatTime();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '快进',
        aliases: ['跳过', '时间跳跃', 'skip'],
        group: '基础信息',
        helpText: '快进时间：/快进 [天数|明天|下周|下月|假期|暑假|开学]',
        handler: (ctx) {
          final m = ctx.provider as GameSystemsMixin;
          final days = m.resolveFastForwardDays(ctx.tailFrom(0));
          // days == 0 表示「你要的时间点已经到了」——7 月里输入
          // 「/快进 暑假」就是这种。老实现会借 _daysUntilMonth 的循环
          // 绕满一整年，直接跳掉 351 天。
          if (days <= 0) {
            m.currentNarrative = '【时间快进】\n'
                '${m.worldState.time.formatDate()} —— 你要的时间点已经到了，无需快进。';
            m.choices = [const GameChoice(text: '继续', action: '继续')];
            m.notifyListeners();
            return true;
          }
          final before = m.worldState.time.formatDate();
          // 快进若跨过毕业，_graduationSettlement 会把「七年统计 + 人生目标
          // 达成判定」整段报告追加到 currentNarrative 尾部，而下面这行
          // 又会无条件覆盖它——玩家最后只看到一条「🎓 你从霍格沃茨毕业了！」
          // 通知，七年的账本和 goal_achieved 的判定结果全都没了。
          // 这里先把快进期间追加进来的那一段截出来，最后再接回去。
          final narrativeBefore = m.currentNarrative;
          final produced = m.fastForwardDays(days);
          final after = m.worldState.time.formatDate();
          final appended = m.currentNarrative.startsWith(narrativeBefore)
              ? m.currentNarrative.substring(narrativeBefore.length).trim()
              : '';

          final buf = StringBuffer()
            ..writeln('【时间快进】')
            ..writeln('$before → $after（共 $days 天）');
          if (produced.isNotEmpty) {
            buf.writeln('\n期间发生：');
            for (final n in produced.take(12)) {
              buf.writeln('· $n');
            }
            if (produced.length > 12) {
              buf.writeln('……等共 ${produced.length} 条（/通知 查看全部）');
            }
          } else {
            buf.writeln('\n这段日子里没有发生什么值得一提的事。');
          }
          if (appended.isNotEmpty) {
            buf.writeln('\n$appended');
          }
          buf.writeln('\n接下来你想做些什么？');
          m.currentNarrative = buf.toString();
          m.choices = [
            GameChoice(text: '继续', action: '继续'),
            GameChoice(text: '再快进一个月', action: '/快进 下月'),
          ];
          m.notifyListeners();
          return true;
        },
      ),
      CommandDef(
        primary: '城堡',
        aliases: ['秘密通道', '幽灵', '休息室'],
        group: '基础信息',
        helpText: '城堡设定：/城堡 通道 [名字]｜/城堡 幽灵 [名字]｜/城堡 学院 [院名]',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final sub = ctx.arg(0);
          if (sub == '通道') {
            final q = ctx.tailFrom(1).trim();
            if (q.isEmpty) {
              m.currentNarrative = formatCastlePassages();
            } else {
              final p = passageByName(q);
              if (p == null) {
                m.currentNarrative = '【秘密通道】\n城堡里没有「$q」这条路。\n\n'
                    '输入 /城堡 通道 看看已知的七条。';
              } else {
                final known = p.knownToStudents
                    ? '这条路在学生间口耳相传。'
                    : '这条路几乎无人知晓。';
                m.currentNarrative =
                    '【${p.name}】\n${p.from} → ${p.to}\n\n${p.note}\n\n$known';
              }
            }
          } else if (sub == '幽灵') {
            final q = ctx.tailFrom(1).trim();
            if (q.isEmpty) {
              m.currentNarrative = formatCastleResidents();
            } else {
              final r = residentByName(q);
              if (r == null) {
                m.currentNarrative =
                    '【常驻居民】\n城堡里没有叫「$q」的幽灵或居民。\n\n'
                        '输入 /城堡 幽灵 看看都有谁。';
              } else {
                m.currentNarrative =
                    '【${r.name}】（${r.kind}）\n常驻：${r.haunt}\n\n${r.persona}';
              }
            }
          } else if (sub == '学院') {
            // 不带名字时给玩家自己所在学院的档案；还没分院就如实说。
            final q = ctx.tailFrom(1).trim();
            final profile =
                q.isEmpty ? houseProfileOf(m.player?.house) : houseProfileOf(q);
            if (profile == null) {
              final why = q.isEmpty
                  ? '你还没有分院，暂时没有自己的学院档案。'
                  : '查不到「$q」的学院档案。';
              m.currentNarrative = '【学院】\n$why\n\n'
                  '四所学院是：格兰芬多、赫奇帕奇、拉文克劳、斯莱特林。';
            } else {
              m.currentNarrative = houseProfileBlock(profile);
            }
          } else {
            m.currentNarrative =
                formatCastleOverview(houseKey: m.player?.house) +
                    '\n\n输入 /城堡 通道 或 /城堡 幽灵 看更多。';
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '地图',
        group: '基础信息',
        helpText: '查看霍格沃茨地图与NPC位置',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m._formatMap();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '通知',
        group: '基础信息',
        helpText: '查看未读通知',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m._formatNotifications();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '帮助',
        group: '基础信息',
        helpText: '查看指令说明',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = CommandRegistry.instance.buildHelpText();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
    ]);

    // —— 关系 / 恋爱 / 声望类 ——
    registry.registerAll([
      CommandDef(
        primary: '关系',
        group: '关系&情感',
        helpText: '查看所有NPC好感度与关系',
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
        helpText: '把背包里的东西送给NPC：/送礼 [名字] [物品]，例如 /送礼 赫敏 旧书'
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
        helpText: '查看恋爱状态',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatLove();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '声望',
        group: '关系&情感',
        helpText: '查看声望（/声望 恋爱·/声望 NPC [名字]·/声望 NPC 列表·/声望 NPC 排名 [维度]）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isNotEmpty && ctx.arg(0) == '恋爱') {
            m.currentNarrative = m._formatLoveReputation();
          } else if (ctx.parts.isNotEmpty && ctx.arg(0) == 'NPC') {
            final p2 = ctx.parts.skip(1).toList();
            if (p2.isNotEmpty && p2[0] == '列表') {
              m.currentNarrative = m._formatNpcReputationList();
            } else if (p2.isNotEmpty && p2[0] == '排名') {
              m.currentNarrative = m._formatNpcReputationRanking(
                  p2.length > 1 ? p2[1] : 'academic');
            } else if (p2.isNotEmpty) {
              m.currentNarrative = m._formatNpcReputation(p2.join(' '));
            } else {
              m.currentNarrative = '用法：/声望 NPC [名字] ｜ /声望 NPC 列表 ｜ /声望 NPC 排名 [维度]';
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
        helpText: '查询两位NPC间的关系（/关系网络 [NPC1] [NPC2]）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.length >= 2) {
            m.currentNarrative = m.formatNpcRelationship(ctx.arg(0)!, ctx.arg(1)!);
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
            m.currentNarrative = err != null ? '【拉郎配】\n$err' : m.formatShippings();
          } else {
            m.currentNarrative = m.formatShippings();
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
    ]);

    // —— 学业 & 成就 & 收藏类 ——
    registry.registerAll([
      CommandDef(
        primary: '课程',
        group: '学业&成长',
        helpText: '查看课程表与进度（/课程 成绩 查看考试成绩单）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isNotEmpty && (ctx.arg(0) == '成绩' || ctx.arg(0) == '考试')) {
            m.currentNarrative = m._formatExamRecords();
          } else if (ctx.parts.isNotEmpty &&
              (ctx.arg(0) == '选课' || ctx.arg(0) == '选修')) {
            m.currentNarrative = '【选修课】（三年级起，至少选2门）\n'
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
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.length >= 1 && ctx.arg(0) == '互动') {
            m.classroomInteraction();
          } else {
            m.currentNarrative = '【课堂互动】\n输入 /课堂 互动 触发当前课堂的互动环节（教授提问、实践练习、同桌互动、随机意外）。\n\n当前课表见 /课程。';
            m.choices = [GameChoice(text: '返回', action: '继续')];
          }
          return true;
        },
      ),
      CommandDef(
        primary: '咒语',
        group: '学业&成长',
        helpText: '魔咒一览（/咒语 学习 漂浮咒 ｜ /咒语 练习 漂浮咒 ｜ /咒语 详情 漂浮咒）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final verb = ctx.arg(0) ?? '';
          final rest = ctx.tailFrom(1);
          switch (verb) {
            case '学习':
            case '学':
              if (rest.isEmpty) {
                m.currentNarrative = '要学哪个咒语？用法：/咒语 学习 漂浮咒\n\n'
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
        helpText: '查看收藏品',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatCollection();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '日记',
        group: '学业&成长',
        helpText: 'CG图鉴：统计/详情/重播（/日记 统计·/日记 [编号]·/日记 重播 [编号]）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.length >= 1 && ctx.arg(0) == '统计') {
            m.currentNarrative = m._formatDiaryStats();
          } else if (ctx.parts.length >= 2 && ctx.arg(0) == '重播') {
            m.currentNarrative = m._replayCg(ctx.arg(1)!);
          } else if (ctx.parts.length >= 1) {
            m.currentNarrative = m._formatCgDetail(ctx.arg(0)!);
          } else {
            m.currentNarrative = m._formatDiary();
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '档案',
        group: '学业&成长',
        helpText: '查看角色完整档案',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m._formatArchive();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '成就',
        group: '学业&成长',
        helpText: '查看成就列表',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m._formatAchievements();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
    ]);

    // —— 物品 & 宠物 ——
    registry.registerAll([
      CommandDef(
        primary: '宠物',
        group: '物品&宠物',
        helpText: '宠物：查看 / 喂食 / 玩耍 / 训练 / 购买',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final sub = ctx.arg(0);
          if (sub != null &&
              ['喂食', '喂', '食物', '玩耍', '玩', '训练', '练'].contains(sub)) {
            m.petInteract(sub);
          } else if (sub != null &&
              ['购买', '买', '选购', '挑选'].contains(sub)) {
            // 以前没宠物时 /宠物 会让人「去对角巷挑选」，但商店里没宠物卖。
            // 现在这里真能买。
            m.currentNarrative = m.buyPet(ctx.tailFrom(1));
          } else {
            m.currentNarrative = m._formatPet();
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

    // —— 活动 & 玩法 ——
    registry.registerAll([
      CommandDef(
        primary: '魁地奇',
        group: '玩法&活动',
        helpText: '魁地奇：/魁地奇 比赛·/魁地奇 位置 <位置>',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.length >= 1 && ctx.arg(0) == '比赛') {
            m.playQuidditch();
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
        primary: '决斗',
        group: '玩法&活动',
        helpText: '与NPC巫师决斗：/决斗 [NPC名]（空参随机）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final arg = ctx.parts.isNotEmpty ? ctx.tailFrom(0) : null;
          m.duelNpc(arg);
          return true;
        },
      ),
      CommandDef(
        primary: '禁林',
        group: '玩法&活动',
        helpText: '禁林探险：/禁林 探险',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.length >= 1 && ctx.arg(0) == '探险') {
            m.exploreForbiddenForest();
          } else {
            m.currentNarrative = '【禁林】\n'
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
        helpText: '查看已发现的魔法生物图鉴',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatBestiary();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '委托',
        group: '玩法&活动',
        helpText: '支线委托板：/委托 刷新·接受 [编号]·交付 [编号]',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.length >= 1 && ctx.arg(0) == '刷新') {
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
        helpText: '生成一位新NPC（每学年限4次）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          // 支持：/新NPC（生成1位）｜/新NPC 生成 [数量]｜/新NPC 好感 [全名] [数值]
          if (ctx.parts.isNotEmpty && ctx.arg(0) == '好感') {
            m._cheatNewNpc(['新NPC', '好感', ctx.arg(1) ?? '', ctx.arg(2) ?? '']);
            m.choices = [GameChoice(text: '返回', action: '继续')];
            return true;
          }
          var count = 1;
          if (ctx.parts.isNotEmpty) {
            if (ctx.arg(0) == '生成') {
              count = int.tryParse(ctx.arg(1) ?? '') ?? 1;
            } else {
              count = int.tryParse(ctx.arg(0) ?? '') ?? 1;
            }
          }
          count = count.clamp(1, 5);
          if (count > 1) {
            final names = <String>[];
            for (var i = 0; i < count; i++) {
              m.generateNewNPC();
              final gen = m.npcRegistry.values
                  .where((n) => n.isGenerated)
                  .toList();
              if (gen.isNotEmpty) names.add(gen.last.name);
            }
            m.currentNarrative = '📬 一次性生成 $count 位新NPC：\n${names.join('\n')}\n\n'
                '他们或许会成为你故事里的一部分。';
          } else {
            m.generateNewNPC();
          }
          return true;
        },
      ),
    ]);

    // —— 信件 & 目标 & 世界 & 结局 ——
    registry.registerAll([
      CommandDef(
        primary: '信',
        group: '信件&目标',
        helpText: '查看信件：读/回/寄（/信 读 [编号]·/信 回 [编号] [内容]·/信 寄 [NPC] [内容]）',
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
        helpText: '查看时代联动痕迹',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          // 文案以前许诺的是"与其他时代剧情产生关联（遇到亲世代留下的物品或
          // 信件）"，但那套内容并不存在，而列表又从来没被写入过——玩家看到的
          // 永远是一句「暂无。」加一段兑现不了的说明。改成如实描述：这里记的
          // 是你亲手造成的不可逆分叉。
          final branches = m.worldState.timelineBranches;
          m.currentNarrative = '【世界线】\n当前时代：${m.eraLabel(m.appProvider.era)}\n'
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
        handler: (ctx) {
          final m = ctx.provider;
          m.currentNarrative = m.formatScars();
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
            m.currentNarrative = '没有找到叫「$name」的孩子，'
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
        helpText: '守护神之路：/守护神 状态 ｜ /守护神 尝试（框架2 第66条）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m._handlePatronus(ctx.parts);
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '阿尼马格斯',
        aliases: ['阿尼玛格斯', '变身'],
        group: '学业&成长',
        helpText: '阿尼马格斯之路：/阿尼马格斯 状态｜学习｜训练｜尝试｜登记（框架2 第67条）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.handleAnimagusCommand(ctx.parts);
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '计划',
        aliases: ['周计划', '这周'],
        group: '学业&成长',
        helpText: '批量推进一周：/计划 学习｜社交｜魁地奇｜调查｜放松（框架2 周计划）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m._handlePlan(ctx.parts);
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '目标',
        group: '信件&目标',
        helpText: '查看/设定人生目标（/目标 [编号]·/目标 进度）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.length >= 1 &&
              (ctx.arg(0) == '进度' || ctx.arg(0) == 'progress')) {
            m.currentNarrative = m.formatGoalProgress();
            m.choices = [GameChoice(text: '返回', action: '继续')];
            return true;
          }
          if (ctx.parts.length >= 1) {
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
              m.currentNarrative = '✅ 已设定人生目标：${goal.name}\n'
                  '『${goal.description}』\n\n'
                  '这条目标将牵引后续剧情方向，但你仍可自由行动。\n'
                  '输入 /目标 可重新查看或更换。';
            } else {
              m.currentNarrative = '未找到目标"$arg"。输入 /目标 查看全部目标。';
            }
          } else {
            m.currentNarrative = m._formatGoals();
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
          final m = ctx.provider as GameCommandsMixin;
          m._startEndingSequence();
          return true;
        },
      ),
    ]);

    // —— 作弊指令 ——
    registry.registerAll([
      CommandDef(
        primary: 'cheat',
        group: '作弊',
        permission: 'cheat',
        helpText: '作弊指令总入口（好感/资源/声望/时间/骨科/舆论/解锁CG），详情见 /cheat',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m._handleCheat(ctx.parts);
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
    ]);

    registry.seal();
  }

  void closeCommandPanel() {
    if (commandResult == null) return;
    commandResult = null;
    notifyListeners();
  }

  /// 本地指令解析（设定文档第X部分指令系统）
  ///
  /// R1：优先走 CommandRegistry（数据驱动路由，自动生成帮助），
  /// 找不到匹配时 fallback 到旧 switch-case（双活方案确保平滑迁移）。

  bool handleLocalCommand(String command) {
    final p = player;
    if (p == null) return false;
    _ensureCommandsRegistered();

    final parts = command.split(RegExp(r'\s+'));
    final cmd = parts[0];

    // 去掉前导 "/"，匹配注册表
    final slashless = cmd.startsWith('/') ? cmd.substring(1) : cmd;
    final registry = CommandRegistry.instance;
    final def = registry.find(slashless);
    if (def != null) {
      final ctx = CommandContext(parts.sublist(1), this as GameProviderBase);
      return def.handler(ctx);
    }

    // 未注册指令：给出候选提示，但**不覆盖当前剧情**。
    //
    // choices 只留一条「返回」是为了命中 processChoice 的 isPanelOutput 判定：
    // 命中后错误提示会进 commandResult 面板，而 currentNarrative / choices 被还原成
    // 输入前的样子，玩家关掉面板即可接着玩。
    // 早先这里把候选指令直接塞进 choices（3 条候选 + 1 条「查看全部指令」），
    // 于是 isPanelOutput 判定失败，错误提示被当成事件类指令永久覆写剧情，
    // 而玩家点任何一条候选都会继续触发新指令 —— 输错指令就等于丢掉当前一整段剧情。
    // 候选指令仍写在提示正文里（_formatUnknownCommand 已逐条列出），信息没丢。
    if (cmd.startsWith('/')) {
      currentNarrative = _formatUnknownCommand(slashless);
      choices = [GameChoice(text: '返回', action: '继续')];
      return true;
    }
    return false;
  }

  /// 未知指令提示：按「前缀/包含/编辑距离」给出最接近的几条候选，
  /// 比直接返回 false（把 /状态统计 当成自由行动文本发给 AI）友好得多。
  List<CommandDef> _suggestCommands(String input) {
    final scored = <(CommandDef, int)>[];
    for (final c in CommandRegistry.instance.all) {
      var best = 1 << 30;
      for (final name in [c.primary, ...c.aliases]) {
        final n = name.replaceAll(' ', '');
        final s = input.replaceAll(' ', '');
        final d = n.startsWith(s) || s.startsWith(n)
            ? 0
            : (n.contains(s) || s.contains(n) ? 1 : _levenshtein(s, n));
        if (d < best) best = d;
      }
      if (best <= 3) scored.add((c, best));
    }
    scored.sort((a, b) => a.$2.compareTo(b.$2));
    return scored.map((e) => e.$1).toList();
  }

  String _formatUnknownCommand(String input) {
    final suggestions = _suggestCommands(input);
    final buf = StringBuffer()..writeln('❓ 没有「/$input」这条指令。');
    if (suggestions.isNotEmpty) {
      buf.writeln('\n你是不是想输入：');
      for (final c in suggestions.take(4)) {
        buf.writeln('  /${c.primary} — ${c.helpText}');
      }
    } else {
      buf.writeln('\n输入 /帮助 查看全部可用指令。'
          '\n如果你想把这段话当成自由行动交给 AI，请把开头的「/」去掉。');
    }
    return buf.toString();
  }

  /// 标准编辑距离（候选词都很短，O(n·m) 完全够用）
  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var cur = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        cur[j] = [
          prev[j] + 1,
          cur[j - 1] + 1,
          prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        ].reduce((x, y) => x < y ? x : y);
      }
      final t = prev;
      prev = cur;
      cur = t;
    }
    return prev[b.length];
  }

  // ==================== 作弊指令（设定 8.1-8.5） ====================

  /// [parts] 为「去掉 /cheat 命令本身」后的子参数列表，parts[0] 即子命令。
  void _handleCheat(List<String> parts) {
    final p = player;
    if (p == null) return;
    if (parts.isEmpty) {
      currentNarrative = _formatCheatHelp();
      choices = [GameChoice(text: '返回', action: '继续')];
      return;
    }
    final sub = parts[0];

    switch (sub) {
      // ============ 8.1 基础作弊 ============
      case '属性':
      case '熟练度':
      case 'attr':
      case 'skill':
        _cheatAttribute(parts);
        break;
      case '加隆':
      case 'galleons':
        _cheatGalleons(parts);
        break;
      case '世界线':
      case 'worldline':
        _cheatWorldline(parts);
        break;
      case '知晓':
      case 'know':
        _cheatKnow(parts);
        break;
      case '剧情':
      case 'event':
        _cheatEvent(parts);
        break;
      case '无敌':
      case 'invincible':
        p.cheatInvincible = !p.cheatInvincible;
        currentNarrative = p.cheatInvincible
            ? '⚔️ 无敌模式开启：伤害与死亡结算对你失效。'
            : '⚔️ 无敌模式关闭。';
        break;
      case '全知':
      case 'omniscient':
        p.cheatOmniscient = !p.cheatOmniscient;
        currentNarrative = p.cheatOmniscient
            ? '👁️ 全知模式开启：查看档案将显示隐藏信息。'
            : '👁️ 全知模式关闭。';
        break;
      case '重置':
      case 'reset':
        _cheatReset();
        break;
      case '列表':
      case 'list':
        currentNarrative = _formatCheatHelp();
        break;

      // ============ 8.2 好感度与关系作弊 ============
      case '好感':
      case 'affection':
        _cheatAffection(parts);
        break;
      case '固定好感':
        _cheatLockAffection(parts);
        break;
      case '解锁CG':
      case 'cg':
        _cheatUnlockCg(parts);
        break;
      case '骨科':
        _cheatBone(parts);
        break;

      // ============ 8.3 拉郎配作弊 ============
      case '配对':
        _cheatPair(parts);
        break;

      // ============ 8.4 声望与收藏作弊 ============
      case '声望':
      case 'reputation':
        _cheatReputation(parts);
        break;
      case '舆论':
      case 'rumor':
        _cheatRumor(parts);
        break;
      case '收藏':
        _cheatCollectible(parts);
        break;
      case '成就':
        _cheatAchievement(parts);
        break;
      case '宠物':
        _cheatPet(parts);
        break;

      // ============ 8.5 新NPC作弊 ============
      case '新NPC':
        _cheatNewNpc(parts);
        break;

      // ============ 兼容旧子命令 ============
      case '资源':
      case 'resources':
        _cheatResource(parts);
        break;
      case '时间':
      case 'time':
        _cheatTime(parts);
        break;

      default:
        currentNarrative = _formatCheatHelp();
    }
    choices = [GameChoice(text: '返回', action: '继续')];
  }

  /// 按关键词查找 NPC（先精确 id，再名字包含）。找不到返回 null。
  NPC? _cheatFindNpc(String key) {
    if (key.isEmpty) return null;
    final direct = npcRegistry[key];
    if (direct != null) return direct;
    for (final n in npcRegistry.values) {
      if (n.name.contains(key) || n.aliases.any((a) => a.contains(key))) {
        return n;
      }
    }
    return null;
  }

  String _cheatAllNpcNames() =>
      npcRegistry.values.map((n) => n.name).join('、');

  // ---------- 8.1 基础作弊 ----------

  /// /cheat 熟练度 <技能名> <数值> —— 直接设定指定技能熟练度（0~100）
  void _cheatAttribute(List<String> parts) {
    final p = player!;
    if (parts.length < 3) {
      currentNarrative = '使用方式：/cheat 熟练度 <技能名> <0-100>，例如 /cheat 熟练度 魔药学 80';
      return;
    }
    final skillKey = parts[1];
    final value = int.tryParse(parts[2]);
    if (value == null) {
      currentNarrative = '数值必须是整数。';
      return;
    }
    // 属性键归一化：中文名/课程名 → 属性 key（权威表在 attribute_data）
    final resolved = _resolveAttrKey(skillKey);
    if (resolved == null) {
      currentNarrative =
          '未知技能「$skillKey」。可用：${kAttributeLabels.values.join('/')}。';
      return;
    }
    p.attributes[resolved] = value.clamp(0, 100);
    currentNarrative =
        '已将「${attributeLabel(resolved)}」熟练度设为 ${p.attributes[resolved]}。';
  }

  /// 属性 key 归一化：key / 中文名 / 课程名 → 属性 key。查不到返回 null。
  String? _resolveAttrKey(String input) {
    if (input.isEmpty) return null;
    if (Player.isAttributeKey(input)) return input;
    for (final e in kAttributeLabels.entries) {
      if (e.value == input || e.value.contains(input) || input.contains(e.value)) {
        return e.key;
      }
    }
    // 课程名别名（course_data 里的课程名 → 属性）
    const courseAliases = {
      '魔咒学': 'spell_understanding',
      '黑魔法防御术': 'dda',
      '魔法史': 'memory',
      '天文学': 'theory',
      '天文': 'theory',
      '魔药': 'potions',
      '飞行术': 'flying',
      '草药': 'herbology',
      '如尼文': 'memory',
      '算术占卜': 'logic',
      '占卜学': 'intuition',
    };
    return courseAliases[input];
  }

  /// /cheat 加隆 <数值> —— 增加/减少加隆数量
  void _cheatGalleons(List<String> parts) {
    final p = player!;
    if (parts.length < 2) {
      currentNarrative = '使用方式：/cheat 加隆 <数值>（负数扣钱）';
      return;
    }
    final amount = int.tryParse(parts[1]);
    if (amount == null) {
      currentNarrative = '数值必须是整数。';
      return;
    }
    p.galleons = (p.galleons + amount).clamp(0, 999999);
    currentNarrative = '💰 加隆余额：${p.galleons}（+$amount）';
  }

  /// /cheat 世界线 <数值> —— 直接调整世界线变动率（0~100）
  void _cheatWorldline(List<String> parts) {
    final p = player!;
    if (parts.length < 2) {
      currentNarrative = '使用方式：/cheat 世界线 <0-100>，例如 /cheat 世界线 35';
      return;
    }
    final value = int.tryParse(parts[1]);
    if (value == null) {
      currentNarrative = '数值必须是整数（0~100）。';
      return;
    }
    p.worldLineDeviation = (value.clamp(0, 100) / 100).toDouble();
    currentNarrative =
        '🌍 世界线变动率已设为 ${(p.worldLineDeviation * 100).toStringAsFixed(0)}%。';
  }

  /// /cheat 知晓 <秘密内容> —— 强制知晓一个隐藏秘密（写入永不遗忘层）
  void _cheatKnow(List<String> parts) {
    if (parts.length < 2) {
      currentNarrative = '使用方式：/cheat 知晓 <秘密内容>，例如 /cheat 知晓 斯内普是凤凰社的人';
      return;
    }
    final secret = parts.sublist(1).join(' ');
    final ts = worldState.time.format();
    memory = memory.addKeyFact(KeyFactRecord(
      id: 'cheat_secret_${DateTime.now().millisecondsSinceEpoch}',
      fact: '主角已得知一个秘密：$secret。',
      importance: 9,
      timestamp: ts,
      category: 'secret',
    ));
    worldState.addNarrativeEvent('🔍 你知晓了一个隐藏秘密（作弊）', turn: turnCount);
    currentNarrative = '🔍 你已强制知晓：$secret\n（已写入永不遗忘层，AI 不会再把你当不知情者。）';
  }

  /// /cheat 剧情 <事件关键词> —— 直接触发指定剧情事件（事件锚点）
  void _cheatEvent(List<String> parts) {
    if (parts.length < 2) {
      currentNarrative = '使用方式：/cheat 剧情 <事件关键词>，例如 /cheat 剧情 魁地奇';
      return;
    }
    final keyword = parts.sublist(1).join(' ');
    final matches = eventAnchors
        .where((a) => a.title.contains(keyword) || a.directive.contains(keyword))
        .toList();
    if (matches.isEmpty) {
      final titles = eventAnchors.map((a) => a.title).toSet().take(12).join('、');
      currentNarrative = '未找到匹配「$keyword」的剧情事件。可尝试关键词：$titles……';
      return;
    }
    final anchor = matches.first;
    pendingAnchorDirective = anchor.directive;
    worldState.addNarrativeEvent('⚡ 已强制触发剧情：${anchor.title}（作弊）', turn: turnCount);
    currentNarrative = '⚡ 已强制触发剧情事件：「${anchor.title}」\n'
        '接下来的剧情将围绕它展开。\n\n（若同时匹配多个事件，已取第一条；'
        '共匹配 ${matches.length} 条）';
  }

  /// /cheat 重置 —— 重置所有作弊修改（开关类 + 锁定类 + 配对修改）
  void _cheatReset() {
    final p = player!;
    var restored = <String>[];
    // 解除所有好感锁定
    for (final n in npcRegistry.values) {
      if (n.affectionLocked) {
        n.affectionLocked = false;
        restored.add('解除锁定：${n.name}');
      }
    }
    // 恢复被修改过的性取向
    if (p.cheatOrientationBackup.isNotEmpty) {
      p.cheatOrientationBackup.forEach((name, original) {
        final npc = _cheatFindNpc(name);
        if (npc != null) {
          npc.sexOrientation = original;
          restored.add('恢复取向：$name');
        }
      });
      p.cheatOrientationBackup.clear();
    }
    // 重置被修改过的配对好感（清掉作弊写入的 NPC 间好感）
    for (final pairKey in p.cheatModifiedPairs) {
      final parts2 = pairKey.split('|');
      if (parts2.length == 2) {
        final a = npcRegistry.values.where((n) => n.name == parts2[0]).firstOrNull;
        final b = npcRegistry.values.where((n) => n.name == parts2[1]).firstOrNull;
        if (a != null && b != null) {
          a.relationships.remove(b.id);
          b.relationships.remove(a.id);
          restored.add('重置配对：${a.name} × ${b.name}');
        }
      }
    }
    p.cheatModifiedPairs.clear();
    // 关闭开关
    if (p.cheatInvincible) {
      p.cheatInvincible = false;
      restored.add('关闭无敌模式');
    }
    if (p.cheatOmniscient) {
      p.cheatOmniscient = false;
      restored.add('关闭全知模式');
    }
    currentNarrative = restored.isEmpty
        ? '当前没有任何作弊修改需要重置。'
        : '【作弊重置完成】\n${restored.join('\n')}\n\n'
            '（注：属性/加隆/声望/世界线等数值型调整不可逆，不属于重置范围；'
            '如需恢复请手动调整回来。）';
  }

  // ---------- 8.2 好感度与关系作弊 ----------

  /// /cheat 好感 <NPC名> <数值> —— 调整好感度
  void _cheatAffection(List<String> parts) {
    if (parts.length >= 3) {
      final npc = _cheatFindNpc(parts[1]);
      if (npc == null) {
        currentNarrative = '未找到NPC "${parts[1]}"。可用：${_cheatAllNpcNames()}';
        return;
      }
      final delta = int.tryParse(parts[2]);
      if (delta != null) {
        npc.affection = (npc.affection + delta).clamp(-100, 100);
        if (npc.affection > npc.maxAffectionReached) {
          npc.maxAffectionReached = npc.affection;
        }
        syncRelationshipLevel(npc);
        checkAffectionAchievements(npc);
        notifyListeners();
        currentNarrative =
            '已调整「${npc.name}」的好感度：${npc.affection}（${npc.affectionStage}）';
      } else {
        currentNarrative = '数值必须是整数。';
      }
    } else {
      currentNarrative = '使用方式：/cheat 好感 <NPC名> <数值>';
    }
  }

  /// /cheat 固定好感 <NPC名> —— 锁定该 NPC 好感（再输一次解锁）
  void _cheatLockAffection(List<String> parts) {
    if (parts.length < 2) {
      currentNarrative = '使用方式：/cheat 固定好感 <NPC名>';
      return;
    }
    final npc = _cheatFindNpc(parts[1]);
    if (npc == null) {
      currentNarrative = '未找到NPC "${parts[1]}"。可用：${_cheatAllNpcNames()}';
      return;
    }
    npc.affectionLocked = !npc.affectionLocked;
    currentNarrative = npc.affectionLocked
        ? '🔒 「${npc.name}」的好感已固定为 ${npc.affection}：'
            '衰减/背叛/送礼/事件都不会再改变它。'
        : '🔓 「${npc.name}」的好感锁定已解除。';
  }

  /// /cheat 解锁CG <CG编号> —— 直接解锁指定CG
  void _cheatUnlockCg(List<String> parts) {
    if (parts.length >= 2) {
      final cg = cgById(parts[1]);
      if (cg != null) {
        unlockCG(cg);
        currentNarrative = '已解锁 CG：${cg.name}';
      } else {
        currentNarrative =
            '未找到该 CG，可用：${allCgs().map((c) => c.id).take(10).join(', ')}...';
      }
    } else {
      currentNarrative = '使用方式：/cheat 解锁CG <CG编号>';
    }
  }

  /// /cheat 骨科 无视 / /cheat 骨科 恢复
  void _cheatBone(List<String> parts) {
    final p = player!;
    if (parts.length >= 2 && (parts[1] == '无视' || parts[1] == '开启')) {
      p.boneMode = true;
      unlockAchievement('bone_mode');
      notifications.add('⚠️ 骨科模式已开启：禁忌的大门已为你敞开');
      worldState.addNarrativeEvent('⚠️ 骨科模式已开启：禁忌限制解除', turn: turnCount);
      bumpImpactScore(0.1, debugReason: '开启骨科模式(世界线剧烈扰动)');
      currentNarrative =
          '【骨科模式已开启】三代内血亲的禁忌限制已解除，但这意味着你的选择将付出更沉重的代价。';
    } else if (parts.length >= 2 && (parts[1] == '恢复' || parts[1] == '关闭')) {
      p.boneMode = false;
      currentNarrative = '【骨科模式已关闭】血缘限制已恢复。';
    } else {
      currentNarrative = '使用方式：/cheat 骨科 无视（开启）｜/cheat 骨科 恢复（关闭）';
    }
  }

  // ---------- 8.3 拉郎配作弊 ----------

  /// /cheat 配对 <子命令>：好感 / 关系 / 重置 / 查看 / 性取向 / 列表
  void _cheatPair(List<String> parts) {
    if (parts.length < 2) {
      currentNarrative = '【配对作弊】\n'
          '  /cheat 配对 好感 <NPC1> <NPC2> <数值>\n'
          '  /cheat 配对 关系 <NPC1> <NPC2> <阶段>（陌生/认识/朋友/暧昧/恋爱/深爱）\n'
          '  /cheat 配对 重置 <NPC1> <NPC2>\n'
          '  /cheat 配对 查看 <NPC1> <NPC2>\n'
          '  /cheat 配对 性取向 <NPC名> <男|女|双性>\n'
          '  /cheat 配对 性取向 重置 <NPC名>\n'
          '  /cheat 配对 列表';
      return;
    }
    final cmd = parts[1];
    final p = player!;
    switch (cmd) {
      case '好感':
        if (parts.length >= 5) {
          final a = _cheatFindNpc(parts[2]);
          final b = _cheatFindNpc(parts[3]);
          final value = int.tryParse(parts[4]);
          if (a == null || b == null) {
            currentNarrative = '未找到NPC，请检查名字。';
            return;
          }
          if (value == null) {
            currentNarrative = '数值必须是整数（-100~100）。';
            return;
          }
          final v = value.clamp(-100, 100);
          a.relationships[b.id] = v;
          b.relationships[a.id] = v;
          p.cheatModifiedPairs.add(ShipRecord.keyOf(a.name, b.name));
          currentNarrative =
              '已设置 ${a.name} × ${b.name} 的互有好感：$v';
        } else {
          currentNarrative = '使用方式：/cheat 配对 好感 <NPC1> <NPC2> <数值>';
        }
        break;
      case '关系':
        if (parts.length >= 5) {
          final a = _cheatFindNpc(parts[2]);
          final b = _cheatFindNpc(parts[3]);
          final stageName = parts[4];
          const stageMap = {
            '陌生': 0, '认识': 20, '朋友': 45, '暧昧': 65, '恋爱': 80, '深爱': 95,
          };
          final v = stageMap[stageName];
          if (a == null || b == null) {
            currentNarrative = '未找到NPC，请检查名字。';
            return;
          }
          if (v == null) {
            currentNarrative = '阶段必须是：陌生/认识/朋友/暧昧/恋爱/深爱。';
            return;
          }
          a.relationships[b.id] = v;
          b.relationships[a.id] = v;
          p.cheatModifiedPairs.add(ShipRecord.keyOf(a.name, b.name));
          currentNarrative =
              '已设置 ${a.name} × ${b.name} 的关系阶段：「$stageName」（好感 $v）';
        } else {
          currentNarrative = '使用方式：/cheat 配对 关系 <NPC1> <NPC2> <阶段>';
        }
        break;
      case '重置':
        if (parts.length >= 4) {
          final a = _cheatFindNpc(parts[2]);
          final b = _cheatFindNpc(parts[3]);
          if (a == null || b == null) {
            currentNarrative = '未找到NPC，请检查名字。';
            return;
          }
          a.relationships.remove(b.id);
          b.relationships.remove(a.id);
          currentNarrative = '已重置 ${a.name} × ${b.name} 的互有好感。';
        } else {
          currentNarrative = '使用方式：/cheat 配对 重置 <NPC1> <NPC2>';
        }
        break;
      case '查看':
        if (parts.length >= 4) {
          final a = _cheatFindNpc(parts[2]);
          final b = _cheatFindNpc(parts[3]);
          if (a == null || b == null) {
            currentNarrative = '未找到NPC，请检查名字。';
            return;
          }
          final ab = a.relationships[b.id];
          final ba = b.relationships[a.id];
          currentNarrative = '【配对状态】${a.name} × ${b.name}\n'
              '· ${a.name} 对 ${b.name}：${ab ?? 0}\n'
              '· ${b.name} 对 ${a.name}：${ba ?? 0}';
        } else {
          currentNarrative = '使用方式：/cheat 配对 查看 <NPC1> <NPC2>';
        }
        break;
      case '性取向':
        if (parts.length >= 4 && parts[2] == '重置') {
          final npc = _cheatFindNpc(parts[3]);
          if (npc == null) {
            currentNarrative = '未找到NPC "${parts[3]}"。';
            return;
          }
          final original = p.cheatOrientationBackup.remove(npc.name);
          if (original != null) {
            npc.sexOrientation = original;
            currentNarrative = '已恢复「${npc.name}」的默认性取向：${original}';
          } else {
            currentNarrative = '「${npc.name}」没有被修改过性取向，无需重置。';
          }
          return;
        }
        if (parts.length >= 4) {
          final npc = _cheatFindNpc(parts[2]);
          final type = parts[3];
          if (npc == null) {
            currentNarrative = '未找到NPC "${parts[2]}"。';
            return;
          }
          if (!['男', '女', '双性'].contains(type)) {
            currentNarrative = '性取向必须是：男 / 女 / 双性。';
            return;
          }
          p.cheatOrientationBackup.putIfAbsent(npc.name, () => npc.sexOrientation ?? '');
          npc.sexOrientation = type;
          currentNarrative = '已修改「${npc.name}」的性取向：$type';
        } else {
          currentNarrative = '使用方式：/cheat 配对 性取向 <NPC名> <男|女|双性>';
        }
        break;
      case '列表':
        final pairs = p.cheatModifiedPairs.map((k) {
          final parts2 = k.split('|');
          if (parts2.length == 2) {
            final a = npcRegistry.values.where((n) => n.name == parts2[0]).firstOrNull;
            final b = npcRegistry.values.where((n) => n.name == parts2[1]).firstOrNull;
            if (a != null && b != null) {
              return '· ${a.name} × ${b.name}：${a.relationships[b.id] ?? 0}';
            }
          }
          return '· $k';
        }).toList();
        currentNarrative = pairs.isEmpty
            ? '【被修改过的配对】\n暂无——还没有用配对作弊改过任何关系。'
            : '【被修改过的配对】\n${pairs.join('\n')}';
        break;
      default:
        currentNarrative = '未知配对子命令「$cmd」，输入 /cheat 配对 查看全部用法。';
    }
  }

  // ---------- 8.4 声望与收藏作弊 ----------

  /// /cheat 声望 <数值> <维度> ｜ /cheat 声望 NPC <NPC名> <维度> <数值> ｜ /cheat 声望 NPC 重置 <NPC名>
  void _cheatReputation(List<String> parts) {
    final p = player!;
    if (parts.length >= 2 && parts[1] == 'NPC') {
      // NPC 声望作弊
      if (parts.length >= 3 && parts[2] == '重置') {
        if (parts.length >= 4) {
          final npc = _cheatFindNpc(parts[3]);
          if (npc == null) {
            currentNarrative = '未找到NPC "${parts[3]}"。';
            return;
          }
          npc.reputation = Reputation(
            academic: 25, social: 25, combat: 20,
            moral: 30, leadership: 20, dark: 10,
          );
          currentNarrative = '已重置「${npc.name}」的声望至默认值。';
        } else {
          currentNarrative = '使用方式：/cheat 声望 NPC 重置 <NPC名>';
        }
        return;
      }
      if (parts.length >= 5) {
        final npc = _cheatFindNpc(parts[2]);
        final value = int.tryParse(parts[4]);
        if (npc == null) {
          currentNarrative = '未找到NPC "${parts[2]}"。';
          return;
        }
        if (value == null) {
          currentNarrative = '数值必须是整数。';
          return;
        }
        npc.reputation.add(parts[3], value);
        currentNarrative = '「${npc.name}」的${npc.reputation.labelOf(parts[3])}：'
            '${npc.reputation.get(parts[3])}';
      } else {
        currentNarrative =
            '使用方式：/cheat 声望 NPC <NPC名> <维度> <数值>（维度：academic、social、combat、moral、leadership、dark）';
      }
      return;
    }
    if (parts.length >= 3) {
      final amount = int.tryParse(parts[1]) ?? 0;
      p.playerReputation.add(parts[2], amount);
      currentNarrative =
          '${p.playerReputation.labelOf(parts[2])} ${p.playerReputation.get(parts[2])}';
    } else {
      currentNarrative =
          '使用方式：/cheat 声望 <数值> <academic|social|combat|moral|leadership|dark>';
    }
  }

  /// /cheat 舆论 清除 <关键词> ｜ /cheat 舆论 重置
  void _cheatRumor(List<String> parts) {
    final p = player!;
    if (parts.length >= 2 && parts[1] == '重置') {
      p.rumors.clear();
      currentNarrative = '已清除所有舆论传闻。';
    } else if (parts.length >= 3 && parts[1] == '清除') {
      final key = parts.sublist(2).join(' ');
      final before = p.rumors.length;
      p.rumors.removeWhere((r) => r.contains(key));
      currentNarrative = '已清除 ${before - p.rumors.length} 条相关传闻。';
    } else {
      currentNarrative = '使用方式：/cheat 舆论 清除 <关键词> 或 /cheat 舆论 重置';
    }
  }

  /// /cheat 收藏 <物品名或id> —— 添加指定物品到收藏
  void _cheatCollectible(List<String> parts) {
    final p = player!;
    if (parts.length < 2) {
      currentNarrative = '使用方式：/cheat 收藏 <物品名或id>，例如 /cheat 收藏 巧克力蛙';
      return;
    }
    final key = parts.sublist(1).join(' ');
    CollectibleDef? def;
    for (final c in kCollectibleCatalog) {
      if (c.id == key || c.name == key || c.name.contains(key)) {
        def = c;
        break;
      }
    }
    if (def == null) {
      currentNarrative = '未找到收藏品「$key」。可输入 /cheat 收藏 列表 查看全部。';
      return;
    }
    if (p.collection.contains(def.id)) {
      currentNarrative = '该收藏品已在收藏册中：${def.name}';
      return;
    }
    p.collection.add(def.id);
    currentNarrative = '📖 已将「${def.name}」加入收藏册（${def.series}·${def.starText}）。';
  }

  /// /cheat 成就 <成就名> —— 解锁指定成就
  void _cheatAchievement(List<String> parts) {
    if (parts.length < 2) {
      currentNarrative = '使用方式：/cheat 成就 <成就名>，例如 /cheat 成就 分院仪式';
      return;
    }
    final key = parts.sublist(1).join(' ');
    Achievement? def;
    for (final a in achievementCatalog) {
      if (a.id == key || a.name == key || a.name.contains(key)) {
        def = a;
        break;
      }
    }
    if (def == null) {
      currentNarrative = '未找到成就「$key」。';
      return;
    }
    unlockAchievement(def.id);
    currentNarrative = '🏆 已解锁成就：${def.name}';
  }

  /// /cheat 宠物 羁绊 <数值>
  void _cheatPet(List<String> parts) {
    final p = player!;
    if (parts.length >= 3 && parts[1] == '羁绊') {
      final value = int.tryParse(parts[2]);
      if (value == null) {
        currentNarrative = '数值必须是整数。';
        return;
      }
      p.petBond = value.clamp(0, 100);
      currentNarrative = '🐾 宠物羁绊已设为 ${p.petBond}/100';
    } else {
      currentNarrative = '使用方式：/cheat 宠物 羁绊 <0-100>';
    }
  }

  // ---------- 8.5 新NPC作弊 ----------

  /// /cheat 新NPC 生成 ｜ /cheat 新NPC 好感 <全名> <数值> ｜ /cheat 新NPC 删除 <全名>
  void _cheatNewNpc(List<String> parts) {
    final p = player!;
    if (parts.length < 2) {
      currentNarrative = '【新NPC作弊】\n'
          '  /cheat 新NPC 生成 — 强制生成一位新NPC\n'
          '  /cheat 新NPC 好感 <全名> <数值>\n'
          '  /cheat 新NPC 删除 <全名>（不可逆）';
      return;
    }
    switch (parts[1]) {
      case '生成':
        // 作弊强制生成：先清空本学年计数绕过上限
        npcGeneratedThisSchoolYear = 0;
        generateNewNPC();
        currentNarrative = '（作弊强制生成）${currentNarrative}';
        break;
      case '好感':
        if (parts.length >= 4) {
          final npc = _cheatFindNpc(parts[2]);
          final value = int.tryParse(parts[3]);
          if (npc == null) {
            currentNarrative = '未找到NPC "${parts[2]}"。';
            return;
          }
          if (value == null) {
            currentNarrative = '数值必须是整数。';
            return;
          }
          npc.affection = value.clamp(-100, 100);
          if (npc.affection > npc.maxAffectionReached) {
            npc.maxAffectionReached = npc.affection;
          }
          syncRelationshipLevel(npc);
          currentNarrative =
              '已将「${npc.name}」的好感设为 ${npc.affection}（${npc.affectionStage}）';
        } else {
          currentNarrative = '使用方式：/cheat 新NPC 好感 <全名> <数值>';
        }
        break;
      case '删除':
        if (parts.length >= 3) {
          final npc = _cheatFindNpc(parts[2]);
          if (npc == null) {
            currentNarrative = '未找到NPC "${parts[2]}"。';
            return;
          }
          npcRegistry.remove(npc.id);
          p.relationships.remove(npc.id);
          currentNarrative = '🗑️ 已删除NPC：${npc.name}（不可逆）。';
        } else {
          currentNarrative = '使用方式：/cheat 新NPC 删除 <全名>';
        }
        break;
      default:
        currentNarrative = '未知新NPC子命令「${parts[1]}」。';
    }
  }

  // ---------- 兼容旧子命令 ----------

  /// /cheat 资源 <数值> <魔力|精神力|饱食|精力|生命>
  void _cheatResource(List<String> parts) {
    final p = player!;
    if (parts.length >= 3) {
      final amount = int.tryParse(parts[1]) ?? 0;
      switch (parts[2]) {
        case '魔力':
        case 'mp':
          p.magic = (p.magic + amount).clamp(0, 100);
          break;
        case '精神力':
        case 'sp':
          p.spirit = (p.spirit + amount).clamp(0, 100);
          break;
        case '饱食':
        case 'sat':
          p.satiety = (p.satiety + amount).clamp(0, 100);
          break;
        case '精力':
        case 'energy':
          p.energy = (p.energy + amount).clamp(0, 100);
          break;
        case '生命':
        case 'hp':
          p.health = (p.health + amount).clamp(0, 100);
          break;
      }
      currentNarrative = '资源已调整。';
    } else {
      currentNarrative = '使用方式：/cheat 资源 <数值> <魔力|精神力|饱食|精力|生命>';
    }
  }

  /// /cheat 时间 <天数>
  void _cheatTime(List<String> parts) {
    if (parts.length >= 2) {
      final days = int.tryParse(parts[1]);
      if (days != null) fastForwardTime(days);
      currentNarrative = '时间已推进 $days 天。\n${worldState.timestamp}';
    } else {
      currentNarrative = '使用方式：/cheat 时间 <天数>';
    }
  }

  String _formatCheatHelp() {
    return '''【作弊指令】（框架1 · 第八部分完整版）

━━━ 8.1 基础作弊 ━━━
  /cheat 熟练度 <技能名> <0-100>  调整技能熟练度（魔药学/变形术/飞行…）
  /cheat 属性 <技能名> <0-100>    同上（别名）
  /cheat 加隆 <数值>             增加/减少加隆
  /cheat 资源 <数值> <魔力|精神力|饱食|精力|生命>
  /cheat 时间 <天数>             跳转时间
  /cheat 世界线 <0-100>          直接调整世界线变动率
  /cheat 知晓 <秘密内容>         强制知晓一个隐藏秘密
  /cheat 剧情 <事件关键词>       直接触发剧情事件（如：魁地奇、O.W.L）
  /cheat 无敌                    无敌模式开关
  /cheat 全知                    全知模式开关（查看档案显示隐藏信息）
  /cheat 重置                    重置所有开关类/锁定类作弊修改
  /cheat 列表                    显示本列表

━━━ 8.2 好感度与关系作弊 ━━━
  /cheat 好感 <NPC名> <数值>     调整好感度
  /cheat 固定好感 <NPC名>        锁定好感（再输一次解锁，多人惩罚免疫）
  /cheat 解锁CG <CG编号>         直接解锁CG
  /cheat 骨科 无视               开启骨科模式（无视血缘限制）
  /cheat 骨科 恢复               关闭骨科模式

━━━ 8.3 拉郎配作弊 ━━━
  /cheat 配对 好感 <NPC1> <NPC2> <数值>
  /cheat 配对 关系 <NPC1> <NPC2> <阶段>  （陌生/认识/朋友/暧昧/恋爱/深爱）
  /cheat 配对 重置 <NPC1> <NPC2>
  /cheat 配对 查看 <NPC1> <NPC2>
  /cheat 配对 性取向 <NPC名> <男|女|双性>
  /cheat 配对 性取向 重置 <NPC名>
  /cheat 配对 列表

━━━ 8.4 声望与收藏作弊 ━━━
  /cheat 声望 <数值> <维度>      维度：academic、social、combat、moral、leadership、dark
  /cheat 声望 NPC <NPC名> <维度> <数值>
  /cheat 声望 NPC 重置 <NPC名>
  /cheat 舆论 清除 <关键词>      清除指定传闻
  /cheat 舆论 重置               重置所有舆论
  /cheat 收藏 <物品名>           添加收藏品
  /cheat 成就 <成就名>           解锁成就
  /cheat 宠物 羁绊 <0-100>       调整宠物羁绊

━━━ 8.5 新NPC作弊 ━━━
  /cheat 新NPC 生成              强制生成一位新NPC
  /cheat 新NPC 好感 <全名> <数值>
  /cheat 新NPC 删除 <全名>       删除新NPC（不可逆）''';
  }

  // ==================== 生成新NPC（增强版：多人格+多样化） ====================

  String _formatStatus() {
    final p = player!;
    final w = worldState;
    // resolveMagicAptitude 要扫长期记忆里的关键事实，原来在插值里连调两次
    final aptitude = resolveMagicAptitude(p);
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《哈利·波特·魔法纪元·人生状态》')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln('【时间】${w.timestamp}')
      ..writeln('【年龄】${calculateAge()}岁')
      ..writeln('【血统】${bloodStatusLabel(p.bloodType)}')
      ..writeln('【身份】${p.birthIdentity ?? '未设定'}')
      ..writeln('【所在地】${w.currentLocation ?? '未知'}')
      ..writeln('【学院】${p.house ?? '未分院'} · ${p.grade ?? 1}年级')
      // 以前这里打的是 initialTalent，和下面的「主修天赋」是同一个字段。
      // 在校就是学生，毕业后用最近一次打工的岗位。
      ..writeln('【职业】${worldState.graduated ? (p.currentJobTitle ?? '待业') : '霍格沃茨${p.grade ?? 1}年级学生'}')
      ..writeln('【财富】💰 ${p.galleons}金加隆 · 🏦 ${p.bankGalleons}古灵阁')
      ..writeln('【家庭】${p.familyBackground ?? '未设定'}')
      ..writeln('【社会地位】学院声望${p.houseReputation} · 魔法界声望${p.wizardingReputation} · 阵营声望${p.factionReputation}')
      ..writeln()
      ..writeln('【生存状态】')
      ..writeln('❤️ 生命：${p.health}/100')
      ..writeln('🔮 魔力：${p.magic}/100')
      ..writeln('🧠 精神力：${p.spirit}/100')
      ..writeln('🍗 饱食度：${p.satiety}/100')
      ..writeln('⚡ 精力：${p.energy}/100')
      ..writeln()
      ..writeln('【魔法能力】')
      ..writeln('魔法资质：${aptitude.isEmpty ? '普通' : aptitude}')
      ..writeln('主修天赋：${p.initialTalent ?? '未设定'}')
      // 这一行以前永远是「尚未学会任何魔咒」或「1个咒语」——咒语没有学习
      // 入口。现在 /咒语 能学能练，这里顺手指一下，玩家才知道有这条路。
      ..writeln('已学魔咒：${p.learnedSpells.isEmpty ? '尚未学会任何魔咒（/咒语 查看可学的）' : '${p.learnedSpells.length}个咒语（/咒语 查看详情）'}')
      ..writeln()
      ..writeln('【学院四维】')
      ..writeln('勇气：${p.houseDimensions['courage']}  智慧：${p.houseDimensions['wisdom']}')
      ..writeln('忠诚：${p.houseDimensions['loyalty']}  野心：${p.houseDimensions['ambition']}')
      ..writeln()
      ..writeln('【政治倾向】${p.politicalTendency ?? '未设定'}')
      ..writeln('【模拟风格】${p.simulationStyle ?? '混合模式'}')
      ..writeln('【恋爱状态】${p.loveState.status}${p.loveState.partnerName != null ? '（${p.loveState.partnerName}）' : ''}')
      ..writeln('【世界线变动率】${(p.worldLineDeviation * 100).toStringAsFixed(1)}%')
      ..writeln()
      ..writeln('【装备栏】')
      ..writeln('袍子：${p.equipped['robe'] ?? '（空）'}  帽子：${p.equipped['hat'] ?? '（空）'}')
      ..writeln('扫帚：${p.equipped['broom'] ?? '（空）'}  饰品：${p.equipped['amulet'] ?? '（空）'}')
      ..writeln('【学院杯】${houseKeyOrNull != null ? '本学年贡献 ${p.houseCupPoints} 分（/学院杯 查看）' : '未分院，暂未参与'}')
      ..writeln('【当前目标】${p.currentGoal ?? '尚未设定目标'}');
    // 阿尼马格斯状态（若有）
    if (p.animagus != null) {
      final av = p.animagus!;
      final aStatus = av['status'] as String? ?? 'none';
      if (aStatus == 'transformed') {
        buf.writeln('【阿尼马格斯】形态：${av['form']}'
            '${av['registered'] == true ? '（已登记）' : '（⚠️ 未登记）'}');
      } else if (aStatus == 'studying' || aStatus == 'potionReady') {
        buf.writeln('【阿尼马格斯】研习中（训练进度 ${av['progress'] ?? 0}/100）');
      }
    }
    if (p.patronus != null && p.patronus!.isNotEmpty) {
      buf.writeln('【守护神】${p.patronus}');
    }
    return buf.toString();
  }

  String _formatTime() {
    final w = worldState;
    return '【当前时间】\n${w.timestamp}\n'
        '学年：${w.academicYear}\n'
        '学期：${termLabel(w.term)}\n'
        '流速模式：${flowModeLabel(w.timeFlowMode)}\n'
        '${w.specialMarkers.isEmpty ? '' : '特殊标记：${w.specialMarkers.join(' ')}'}';
  }

  String _formatMap() {
    // R11：使用 mapRegions 数据（替代 8 行硬编码）
    // unlockCondition 以前只是打印出来的文案——有没有人真的去不了，
    // 全看 AI 那天心情好不好。现在按年级/周末实判，未开放的标 🔒。
    final p = player;
    final isWeekend = worldState.time.weekday == 0 || worldState.time.weekday == 6;
    final knownRegions = mapRegions.map((r) {
      final unlocked = r.isUnlocked(grade: p?.grade, isWeekend: isWeekend);
      final cond = r.unlockCondition != null ? '（${r.unlockCondition}）' : '';
      return '  ${unlocked ? r.icon : '🔒'} ${r.name}$cond';
    }).join('\n');
    return '''【霍格沃茨地图】
  当前地点：${worldState.currentLocation ?? '九又四分之三站台 / 霍格沃茨特快'}

  已知区域：
$knownRegions

  各NPC当前位置：
  ${npcRegistry.values.where((n) => n.isAlive).take(6).map((n) => '· ${n.name}：${n.currentLocation}').join('\n')}''';
  }

  String _formatNotifications() {
    if (notifications.isEmpty) {
      return '【通知】\n暂无新通知。';
    }
    return '【通知】\n${notifications.reversed.take(10).map((n) => '· $n').join('\n')}';
  }

  // ==================== 周计划（框架2 第62条 · 时间是一种资源） ====================

  /// /计划 指令：玩家声明「这一周以什么为主」，系统批量结算一周时间。
  /// 时间推进走 fastForwardTime（自动处理学年推进/月度演化/事件锚点/好感衰减），
  /// 再叠加对应的成长结算——玩家把时间花在哪，哪条线就会前进。
  void _handlePlan(List<String> parts) {
    final p = player;
    if (p == null) return;
    final sub = parts.isEmpty ? '' : parts[0];

    switch (sub) {
      case '学习':
        _planStudy(p);
        break;
      case '社交':
        _planSocial(p);
        break;
      case '魁地奇':
        _planQuidditch(p);
        break;
      case '调查':
        _planInvestigate(p);
        break;
      case '放松':
        _planRest(p);
        break;
      case '打工':
        _planWork(p);
        break;
      default:
        currentNarrative = '【周计划】把一整周的时间投给一件事，系统批量结算。\n\n'
            '  /计划 学习 — 泡图书馆，学业属性成长\n'
            '  /计划 社交 — 经营关系，好感提升\n'
            '  /计划 魁地奇 — 训练技巧与体能\n'
            '  /计划 调查 — 探索禁林与城堡的秘密\n'
            '  /计划 放松 — 恢复精力与精神\n'
            '  /计划 打工 — 赚一周的零花钱\n\n'
            '（每周推进 7 天，中间的关键事件会自动进入通知）';
    }
  }

  void _planStudy(Player p) {
    const pool = ['spell_understanding', 'transfiguration', 'potions', 'herbology', 'theory', 'memory'];
    final gains = <String, int>{};
    for (final key in pool) {
      if (random.nextDouble() < 0.6) {
        gains[key] = 1 + random.nextInt(3); // 1~3
      }
    }
    gains.forEach((k, v) {
      p.attributes[k] = (p.attributes[k] ?? 50 + v).clamp(0, 100);
    });
    p.energy = (p.energy - 10).clamp(0, 100);
    _advanceWeek('学习');
    final line = gains.entries
        .map((e) => '${attributeLabel(e.key)} +${e.value}')
        .join('，');
    worldState.addNarrativeEvent('📚 这一周你几乎把时间都泡在了图书馆', turn: turnCount);
    currentNarrative = '这一周，你的生活节奏简单而充实：上午上课，下午图书馆，晚上在公共休息室的角落里'
        '翻书写作业。蜡烛的火焰在羊皮纸上投下晃动的影子，你偶尔抬头，看见窗外禁林的轮廓在夜色里沉默。\n\n'
        '一周下来，你明显感到自己在${gains.length == 0 ? '原地踏步——状态不太好，也许该换换节奏' : '进步'}'
        '${gains.isEmpty ? '' : '：$line'}。\n\n'
        '（时间推进一周）';
  }

  void _planSocial(Player p) {
    final candidates = npcRegistry.values
        .where((n) => n.isAlive && n.introduced)
        .toList();
    var affected = 0;
    final names = <String>[];
    if (candidates.isNotEmpty) {
      candidates.shuffle(random);
      final count = random.nextInt(3) + 1; // 1~3 位
      for (var i = 0; i < count && i < candidates.length; i++) {
        final npc = candidates[i];
        final delta = 1 + random.nextInt(2); // 1~2
        updateNpcAffection(npc.id, delta, reason: '周计划·社交', quiet: true);
        affected++;
        names.add('${npc.name}（+$delta）');
      }
    }
    p.attributes['social'] = (p.attributes['social'] ?? 50) + 2;
    p.energy = (p.energy - 10).clamp(0, 100);
    _advanceWeek('社交');
    worldState.addNarrativeEvent('☕ 这一周你忙于经营人际关系', turn: turnCount);
    currentNarrative = '你主动调整了这一周的重心：和同学一起吃饭、帮朋友跑腿、参加公共休息室的闲聊、'
        '给远方的人写信。魔法世界的人情冷暖，说到底也是靠一次次小小的来往织成的。\n\n'
        '${affected > 0 ? '一周下来，你们的关系更近了一些：${names.join('，')}。' : '这一周没什么特别的交集，但至少你让自己出现在了人群里。'}\n\n'
        '（时间推进一周）';
  }

  void _planQuidditch(Player p) {
    final qGain = 3 + random.nextInt(3); // 3~5
    p.qSkill = (p.qSkill + qGain).clamp(0, 100);
    p.attributes['flying'] = (p.attributes['flying'] ?? 50) + 2;
    p.attributes['reaction_time'] = (p.attributes['reaction_time'] ?? 50) + 1;
    p.energy = (p.energy - 25).clamp(0, 100);
    p.satiety = (p.satiety + 5).clamp(0, 100);
    _advanceWeek('魁地奇');
    worldState.addNarrativeEvent('🏏 这一周你在魁地奇球场挥汗如雨', turn: turnCount);
    currentNarrative = '这一周，魁地奇球场几乎成了你的第二个家。清晨的风里，你绕着球门做俯冲练习；'
        '傍晚的余晖中，你和队友磨合配合。扫帚的抛光油味混着青草的气息，是这一周最熟悉的味道。\n\n'
        '一周下来，你的魁地奇技巧 +$qGain，飞行能力也见长。\n\n'
        '（时间推进一周）';
  }

  void _planInvestigate(Player p) {
    p.attributes['observation'] = (p.attributes['observation'] ?? 50) + 2;
    p.attributes['theory'] = (p.attributes['theory'] ?? 50) + 1;
    p.attributes['magic_control'] = (p.attributes['magic_control'] ?? 50) + 1;
    p.energy = (p.energy - 15).clamp(0, 100);
    _advanceWeek('调查');
    // 小概率发现彩蛋：写一条随机传闻/事件
    final found = random.nextDouble() < 0.3;
    if (found) {
      final bits = [
        '图书馆禁书区的一本书里夹着一张泛黄的羊皮纸，上面的字迹已经模糊',
        '城堡某条密道的入口附近有一串新鲜的脚印，通向你们不该去的地方',
        '有同学在夜里听见走廊深处传来低低的歌声，没人说得清它来自哪里',
        '禁林边缘的树丛里，有什么东西在月光下闪了一下',
      ];
      final bit = bits[random.nextInt(bits.length)];
      worldState.addNarrativeEvent('🔍 调查发现：$bit', turn: turnCount);
      notifications.add('🔍 这周的调查有了点发现：$bit');
      currentNarrative = '这一周你像一只安静的猫，在霍格沃茨的角落里搜寻线索。图书馆、废弃教室、'
          '画像背后的走廊——你几乎把城堡的纹理摸了一遍。\n\n'
          '周三深夜，你发现：$bit\n\n'
          '（时间推进一周）';
    } else {
      worldState.addNarrativeEvent('🔍 这一周你在城堡里调查走访，没有特别的发现', turn: turnCount);
      currentNarrative = '这一周你像一只安静的猫，在霍格沃茨的角落里搜寻线索。图书馆、废弃教室、'
          '画像背后的走廊——你几乎把城堡的纹理摸了一遍。\n\n'
          '遗憾的是，这一周并没有惊天动地的发现。城堡的古老秘密，从来不会轻易向人敞开。\n\n'
          '（时间推进一周）';
    }
  }

  void _planRest(Player p) {
    p.energy = (p.energy + 45).clamp(0, 100);
    p.spirit = (p.spirit + 35).clamp(0, 100);
    p.satiety = (p.satiety + 25).clamp(0, 100);
    _advanceWeek('放松');
    worldState.addNarrativeEvent('🛋️ 这一周你好好休息了一番', turn: turnCount);
    currentNarrative = '你决定这一周不为任何事奔忙：睡到自然醒，和同学去霍格莫德喝黄油啤酒，'
        '在城堡外的草地上晒晒太阳，晚上窝在休息室的扶手椅里发呆。\n\n'
        '一周下来，身心都得到了喘息。\n\n'
        '（时间推进一周）';
  }

  void _planWork(Player p) {
    final income = 150 + random.nextInt(100); // 150~249 加隆
    p.galleons += income;
    p.energy = (p.energy - 20).clamp(0, 100);
    p.attributes['social'] = (p.attributes['social'] ?? 50) + 1;
    _advanceWeek('打工');
    worldState.addNarrativeEvent('🪙 这一周你接了一份短工', turn: turnCount);
    currentNarrative = '这一周你把自己卖给了一份短工——跑腿、整理货架、帮忙照看摊位，'
        '偶尔还要应付难缠的顾客。腰酸背痛是免不了的，但每天晚上数着西可和纳特入睡的感觉，'
        '也不算太糟。\n\n'
        '一周下来，你赚了 💰 $income 加隆。\n\n'
        '（时间推进一周）';
  }

  void _advanceWeek(String focus) {
    final before = worldState.time.format();
    fastForwardTime(7);
    final after = worldState.time.format();
    debugPrint('📅 周计划[$focus]：$before → $after');
  }


  // ==================== 守护神（框架2 第66条） ====================

  /// /守护神 状态 ｜ /守护神 尝试
  void _handlePatronus(List<String> parts) {
    final p = player;
    if (p == null) return;
    final sub = parts.isEmpty ? '状态' : parts[0];

    switch (sub) {
      case '状态':
        currentNarrative = _formatPatronusStatus();
        break;
      case '尝试':
        _patronusAttempt(p);
        break;
      default:
        currentNarrative = '【守护神】未知子命令「$sub」。\n'
            '可用：/守护神 状态 ｜ /守护神 尝试';
    }
  }

  String _formatPatronusStatus() {
    final p = player!;
    final buf = StringBuffer('【守护神】\n');
    if (p.patronus != null && p.patronus!.isNotEmpty) {
      final f = patronusFormByName(p.patronus!);
      buf.writeln('形态：${p.patronus}');
      if (f != null) buf.writeln(f.description);
      buf.writeln('\n守护神是灵魂的映照。它可能随着你人生的巨变而改变——'
          '但此刻，它就是你的模样。');
      return buf.toString();
    }
    final grade = p.grade ?? 1;
    final emotion = p.attributes['emotional_stability'] ?? 50;
    final knowsSpell = p.learnedSpells.containsKey('守护神咒');
    buf.writeln('你还没有属于自己的守护神。');
    if (grade < 5 && !knowsSpell) {
      buf.writeln('\n守护神咒是高年级（五年级起）的黑魔法防御术咒语——'
          '你的魔法还不够成熟，强行尝试只会让杖尖凝出一缕毫无形状的银雾。');
    } else {
      buf.writeln('\n你已经掌握了守护神咒的基础，但召唤成形守护神'
          '需要内心深处的幸福记忆与稳定的情绪。');
      if (emotion < 60) {
        buf.writeln('\n（情绪稳定度 ${emotion}/100——你的内心还不够平静，'
            '建议先学会在混乱中稳住自己。）');
      } else {
        buf.writeln('\n（情绪稳定度 ${emotion}/100，可以尝试：/守护神 尝试）');
      }
    }
    return buf.toString();
  }

  void _patronusAttempt(Player p) {
    final grade = p.grade ?? 1;
    final knowsSpell = p.learnedSpells.containsKey('守护神咒');
    if (grade < 5 && !knowsSpell) {
      currentNarrative = '你举起魔杖，拼尽全力回想快乐的记忆，念出「Expecto Patronum！」——\n\n'
          '杖尖只飘出一缕不成形的银雾，转瞬即逝。\n\n'
          '守护神咒是高年级的领域。你的魔法还不够成熟，强行尝试只会让自己头晕目眩。\n\n'
          '（五年级后可学习守护神咒，再作尝试。）';
      p.spirit = (p.spirit - 10).clamp(0, 100);
      return;
    }
    final emotion = p.attributes['emotional_stability'] ?? 50;
    if (emotion < 60) {
      currentNarrative = '你努力回想快乐的记忆，但思绪总是被焦虑和杂念打断。'
          '银雾在杖尖聚了又散，始终无法成形。\n\n'
          '守护神是心灵的映照——内心不平静，它就无处可依。'
          '（情绪稳定度 ${emotion}/100，需 ≥60）';
      p.spirit = (p.spirit - 10).clamp(0, 100);
      return;
    }
    // 尝试召唤：成功概率由情绪稳定 + 魔法控制 + DDA 决定
    final emotionScore = emotion;
    final control = p.attributes['magic_control'] ?? 50;
    final dda = p.attributes['dda'] ?? 50;
    final chance =
        (0.5 + (emotionScore - 60) / 200 + (control - 50) / 200 + (dda - 50) / 200)
            .clamp(0.3, 0.9);
    p.spirit = (p.spirit - 15).clamp(0, 100);
    if (random.nextDouble() <= chance) {
      final form = resolvePatronusForm(
        personality: p.personalityTraits,
        house: p.house ?? '',
        beliefs: p.beliefs ?? '',
        dice: random.nextDouble(),
      );
      p.patronus = form;
      worldState.addNarrativeEvent('✨ 你的守护神成形了：$form', turn: turnCount);
      notifications.add('✨ 你的守护神成形了：$form');
      final f = patronusFormByName(form);
      currentNarrative = '这一次，你没有费力去想快乐的记忆。\n\n'
          '你只是闭上眼，让某个早已刻进心底的画面浮现——'
          '然后，杖尖喷涌出耀眼的白光。\n\n'
          '光芒凝聚成形：$form。${f?.description ?? ''}\n\n'
          '它绕着你奔跑了一圈，然后停在你面前，静静地看着你。'
          '你知道，从今往后，无论黑暗多深，你都不再是独自一人。';
    } else {
      worldState.addNarrativeEvent('🌫️ 守护神尝试失败：银雾聚了又散', turn: turnCount);
      currentNarrative = '白光从杖尖涌出，但始终凝不成形。银雾在空气中徘徊片刻，'
          '像一个欲言又止的词，然后散去了。\n\n'
          '你放下魔杖，喘了口气。还差一点——也许是记忆还不够清晰，'
          '也许是情绪还不够纯粹。\n\n'
          '（提升情绪稳定度与魔法控制后，再来尝试。）';
    }
  }

  // ==================== 声望子命令（框架1 7.3） ====================

  /// /声望 恋爱 —— 恋爱关系的声望影响明细
  String _formatLoveReputation() {
    final p = player;
    if (p == null) return '尚未开始游戏。';
    final love = p.loveState;
    final buf = StringBuffer('【恋爱声望影响】（设定 13.3）\n');
    for (final e in loveReputationEffects) {
      buf.writeln('· ${e.type}：${e.min >= 0 ? '+' : ''}${e.min} ~ ${e.max >= 0 ? '+' : ''}${e.max}');
    }
    // 当前关系的命中情况
    if (love.partnerName != null || love.currentCrushName != null) {
      final npcName = love.partnerName ?? love.currentCrushName!;
      final npc = _cheatFindNpc(npcName);
      if (npc != null) {
        final ctx = LovePairContext(
          playerHouse: p.house ?? '',
          npcHouse: npc.house,
          playerBlood: p.bloodType,
          npcBlood: npc.bloodStatus,
          npcIsStaff: npc.grade <= 0,
          playerStance: p.politicalTendency ?? '',
          npcBloodSupremacist: npc.bloodSupremacist,
        );
        buf.writeln();
        buf.writeln('【当前关系 · $npcName】');
        var hit = false;
        for (final e in loveReputationEffects) {
          if (loveEffectApplies(e, ctx)) {
            buf.writeln('  ⚡ 命中「${e.type}」：${e.min >= 0 ? '+' : ''}${e.min} ~ ${e.max >= 0 ? '+' : ''}${e.max}');
            hit = true;
          }
        }
        if (!hit) buf.writeln('  当前关系不触发任何声望惩罚。');
      }
    } else {
      buf.writeln('\n（当前单身，暂无关系判定。）');
    }
    return buf.toString();
  }

  /// /声望 NPC [名字] —— 指定 NPC 的声望档案
  String _formatNpcReputation(String nameKey) {
    final npc = _cheatFindNpc(nameKey);
    if (npc == null) {
      return '未找到NPC "$nameKey"。可用：${_cheatAllNpcNames()}';
    }
    final r = npc.reputation;
    final buf = StringBuffer('【${npc.name} · 声望档案】\n');
    for (final dim in Reputation.dimensions) {
      final v = r.get(dim);
      buf.writeln('· ${r.labelOf(dim)}：$v（${reputationGrade(v)}）');
    }
    return buf.toString();
  }

  /// /声望 NPC 列表 —— 所有已认识 NPC 的声望摘要
  String _formatNpcReputationList() {
    final buf = StringBuffer('【NPC声望摘要】（已登场）\n');
    final list = npcRegistry.values
        .where((n) => n.introduced)
        .toList()
      ..sort((a, b) => b.reputation.social.compareTo(a.reputation.social));
    if (list.isEmpty) {
      buf.writeln('（还没有结识任何人。）');
      return buf.toString();
    }
    for (final n in list) {
      final r = n.reputation;
      buf.writeln('· ${n.name}：学术${r.academic} 社交${r.social} 战斗${r.combat}'
          ' 道德${r.moral} 领导${r.leadership} 黑魔法${r.dark}');
    }
    return buf.toString();
  }

  /// /声望 NPC 排名 [维度] —— 按指定维度排名
  String _formatNpcReputationRanking(String dim) {
    final norm = dim.startsWith('黑') ? 'dark' : dim;
    final valid = Reputation.dimensions.contains(norm);
    if (!valid) {
      return '未知维度「$dim」。维度：academic(学术)、social(社交)、combat(战斗)、moral(道德)、leadership(领导)、dark(黑魔法)';
    }
    final list = npcRegistry.values.where((n) => n.introduced).toList()
      ..sort((a, b) => b.reputation.get(norm).compareTo(a.reputation.get(norm)));
    final label = list.isEmpty ? '' : list.first.reputation.labelOf(norm);
    final buf = StringBuffer('【$label · 排名】（已登场 ${list.length} 人）\n');
    for (var i = 0; i < list.length && i < 10; i++) {
      final n = list[i];
      buf.writeln('${i + 1}. ${n.name}：${n.reputation.get(norm)}');
    }
    return buf.toString();
  }

  // ==================== 人生目标系统 ====================

  /// 考试成绩单展示（/课程 成绩）
  String _formatExamRecords() {
    final p = player;
    if (p == null) return '尚未开始游戏。';
    final records = p.examRecords;
    if (records.isEmpty) {
      return '【考试成绩】\n还没有任何考试成绩——学年结束时（9月升学年结算）会揭晓期末成绩，'
          '五年级末还有 O.W.L.，七年级末有 N.E.W.T.。\n\n'
          '平时上课（/课堂 互动）、学习魔咒、认真对待学业，都会让成绩变得更好看。';
    }
    final buf = StringBuffer('╔══════════════════════════════════════╗\n')
      ..writeln('  《学业成绩册》')
      ..writeln('╚══════════════════════════════════════╝');
    // 学年成绩
    for (var i = 1; i <= 7; i++) {
      final key = 'Y$i';
      final r = records[key];
      if (r == null) continue;
      final s = examSummary(r);
      buf.writeln();
      buf.writeln('【第$i 学年期末】${s.oCount}O / ${s.eCount}E / ${s.aPlusCount} 及格以上');
      buf.writeln(formatExamSheet(r));
    }
    // 大考
    for (final key in ['OWL', 'NEWT']) {
      final r = records[key];
      if (r == null) continue;
      final s = examSummary(r);
      buf.writeln();
      buf.writeln('【${key == 'OWL' ? 'O.W.L. 普通巫师等级考试（五年级末）' : 'N.E.W.T. 终极巫师等级考试（七年级末）'}】'
          ' ${s.oCount}O / ${s.eCount}E / ${s.aPlusCount} 及格以上');
      buf.writeln(formatExamSheet(r));
      if (s.oCount >= 3) {
        buf.writeln('🏅 这份成绩单足以叩开绝大多数高阶职业的大门。');
      } else if (s.aPlusCount >= 6) {
        buf.writeln('📖 稳健的成绩，多数常规职业都会接纳你。');
      } else {
        buf.writeln('⚠️ 成绩平平——部分要求苛刻的职业会对你关上大门。');
      }
    }
    return buf.toString();
  }

  String _formatGoals() {
    final p = player;
    final current = p?.currentGoal;
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《人生目标》')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln('【当前目标】${(current == null || current.isEmpty) ? '尚未设定' : current}');
    if (current != null && current.isNotEmpty) {
      final g = goalByName(current);
      if (g != null) {
        buf.writeln('  『${g.description}』');
      }
    }
    buf
      ..writeln()
      ..writeln('【可选目标】（输入 /目标 [编号] 设定）');
    for (int i = 0; i < lifeGoalCatalog.length; i++) {
      final g = lifeGoalCatalog[i];
      buf.writeln('${i + 1}. ${g.name}（${g.category}）— ${g.description}');
    }
    if (current != null && current.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('💡 输入 /目标 进度 查看当前目标的毕业条件达成情况。');
    }
    return buf.toString();
  }

  // ==================== 终章 / 结局 ====================

  void _startEndingSequence() {
    if (player == null) return;
    isLoading = true;
    loadingStage = '正在书写你的终章…';
    currentNarrative = '';
    choices = [];
    notifyListeners();
    unawaited(generateEnding());
  }

  String _formatDiary() {
    if (player!.cgRecords.isEmpty) {
      return '【日记 / CG图鉴】\n暂无解锁CG。在关键剧情节点将解锁专属CG。\n\n（输入 /日记 统计 查看进度；/日记 [编号] 查看详情）';
    }
    final buf = StringBuffer('【日记 / CG图鉴】（已解锁 ${player!.cgRecords.length}/${allCgs().length}）\n');
    for (final cg in allCgs()) {
      final rec = player!.cgRecords[cg.id];
      if (rec == null) continue;
      buf.writeln('· ${cg.id} ${cg.name}（${rec.unlockedDate}）');
    }
    return buf.toString();
  }

  /// CG 数量与等级分布（设定 7.5 /日记 统计）

  String _formatDiaryStats() {
    final unlocked = player!.cgRecords;
    final all = allCgs();
    final byStars = <int, int>{2: 0, 3: 0, 4: 0, 5: 0};
    final byChapter = <String, int>{};
    for (final cg in all) {
      if (unlocked.containsKey(cg.id)) {
        byStars[cg.stars] = (byStars[cg.stars] ?? 0) + 1;
        byChapter[cg.chapter] = (byChapter[cg.chapter] ?? 0) + 1;
      }
    }
    final buf = StringBuffer()
      ..writeln('【日记统计】')
      ..writeln('已解锁：${unlocked.length}/${all.length}')
      ..writeln()
      ..writeln('【等级分布】')
      ..writeln('★★ 二星：${byStars[2] ?? 0}')
      ..writeln('★★★ 三星：${byStars[3] ?? 0}')
      ..writeln('★★★★ 四星：${byStars[4] ?? 0}')
      ..writeln('★★★★★ 五星：${byStars[5] ?? 0}')
      ..writeln()
      ..writeln('【章节分布】');
    if (byChapter.isEmpty) {
      buf.writeln('（暂无）');
    } else {
      for (final e in byChapter.entries) {
        buf.writeln('· ${e.key}：${e.value}');
      }
    }
    return buf.toString();
  }

  /// 查看指定 CG 详情（设定 7.5 /日记 [编号]）

  String _formatCgDetail(String id) {
    final cg = cgById(id);
    if (cg == null) {
      return '未找到 CG「$id」。可用编号见 /日记。';
    }
    final rec = player!.cgRecords[cg.id];
    if (rec == null) {
      return '【${cg.id} ${cg.name}】🔒 尚未解锁\n'
          '章节：${cg.chapter}｜等级：${cg.starText}\n'
          '解锁条件：${cg.conditionText}';
    }
    return '【${cg.id} ${cg.name}】${cg.starText}\n'
        '章节：${cg.chapter}\n'
        '解锁条件：${cg.conditionText}\n'
        '解锁于：${rec.unlockedDate}';
  }

  /// 重播指定 CG（精简版，设定 7.5 /日记 重播）

  String _replayCg(String id) {
    final cg = cgById(id);
    if (cg == null) {
      return '未找到 CG「$id」。可用编号见 /日记。';
    }
    final rec = player!.cgRecords[cg.id];
    if (rec == null) {
      return '【${cg.id} ${cg.name}】尚未解锁，无法重播。\n解锁条件：${cg.conditionText}';
    }
    return '【重播 · ${cg.name}】${cg.starText}\n\n'
        '—— 记忆被重新点亮。\n\n'
        '你仿佛又回到了那一刻：旧羊皮纸与蜡烛的气味在空气里浮动，远处的钟声在石墙之间低低回荡，而「${cg.name}」的画面，如月光一般温柔地重新铺展在你眼前。\n\n'
        '（${cg.chapter}）解锁于 ${rec.unlockedDate}';
  }

  String _formatArchive() {
    final p = player!;
    return '''【角色完整档案】
  姓名：${p.name}｜性别：${p.gender.isEmpty ? '未设定' : p.gender}
  生日：${p.birthDay ?? '未设定'}｜出生年份：${p.birthYear}
  血统：${bloodStatusLabel(p.bloodType)}｜出生地：${p.birthLocation}
  学院：${p.house ?? '未分院'}｜年级：${p.grade ?? 1}
  性取向：${p.sexOrientation ?? '未设定'}
  魔杖：${p.wandId != null ? wandById(p.wandId!)?.name ?? p.wandId : '未选择'}
  宠物：${p.petName ?? '无'}
  外貌：${p.appearance ?? '未设定'}
  家族背景：${p.familyBackground ?? '未设定'}
  童年经历：${p.childhoodExperiences.isEmpty ? '未设定' : p.childhoodExperiences.join('；')}
  信仰与价值观：${p.beliefs ?? '未设定'}
  初始天赋：${p.initialTalent ?? '未设定'}
  性格特质：${p.personalityTraits.isEmpty ? '未设定' : p.personalityTraits.join('、')}
  当前目标：${p.currentGoal ?? '无'}''';
  }

  String _formatAchievements() {
    final unlocked = player!.achievements;
    final catalog = achievementCatalog;
    final buf = StringBuffer('【成就】（${unlocked.length}/${catalog.length}）\n');
    for (final a in catalog) {
      final has = unlocked.contains(a.id);
      buf.writeln('${has ? '✅' : '🔒'} ${a.name}${has ? ' — ${a.description}' : ''}');
    }
    return buf.toString();
  }

  String _formatPet() {
    final p = player!;
    if (p.petId == null && p.petName == null) {
      // 以前这里让人「去对角巷挑选」，但商店里没宠物卖，是条死路。
      // 现在 /宠物 购买 真能买，把清单直接列出来。
      return '【宠物】\n你还没有宠物。\n\n${formatPetShop()}';
    }
    final def = p.petId != null ? petById(p.petId!) : null;
    // R8：使用 petNarrativeConfig 去除「九尾灵狐羁绊≥60 化形」硬编码
    final cfg = p.petId != null ? petNarrativeConfig(p.petId!) : null;
    final buf = StringBuffer('【宠物】\n');
    buf.writeln('名字：${p.petName ?? def?.name ?? '未命名'}');
    if (def != null) {
      buf.writeln('种类：${def.species}');
      buf.writeln('能力：${def.abilities.join('、')}');
      if (cfg != null && cfg.bondGatedTransform) {
        buf.writeln('特性：可化人形（羁绊≥${cfg.specialInteractionBondThreshold}后会触发人形互动）');
      } else if (def.canTransform) {
        buf.writeln('特性：可化人形');
      }
      buf.writeln('简介：${def.description.split('\n').first}');
    }
    buf.write('羁绊：${p.petBond}/100\n');
    buf.writeln('互动：/宠物 喂食 ｜ /宠物 玩耍 ｜ /宠物 训练（喂食每日一次，玩耍/训练每日共一次）');
    final canTransformHint = (cfg?.bondGatedTransform ?? false)
        ? '${def?.species ?? '特殊宠物'}在羁绊≥${cfg?.specialInteractionBondThreshold ?? 60} 时会化为人形。'
        : '特殊宠物会在羁绊达到阈值后触发专属互动。';
    buf.writeln('羁绊≥40 时宠物可在决斗/探险中助战；$canTransformHint');
    return buf.toString();
  }

  // ==================== 信件互动系统 ====================

  /// 处理 /信 系列子指令：读 / 回 / 寄
}
