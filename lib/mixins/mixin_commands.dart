import 'dart:async';


import 'mixin_command_cheats.dart';
import 'mixin_commands_extras.dart';
import '../data/game_config_rules.dart';
import '../data/command_registry.dart';
import '../utils/npc_lookup.dart';
import '../models/game_systems.dart';
import '../data/goal_data.dart';
import '../data/castle_data.dart';
import '../data/worldline_data.dart';
import '../data/legacy_data.dart';
import '../data/collectible_data.dart';
import '../data/course_data.dart';
import '../mixins/mixin_club.dart';
import '../models/player.dart';
import '../models/story_progress.dart';
import '../providers/game_provider_base.dart';
import 'mixin_systems.dart';

mixin GameCommandsMixin on GameProviderBase, GameCommandCheatMixin {
  // ================ R1：注册命令到注册表（初始化时调用一次即可） ================
  bool _commandsRegistered = false;

  void ensureCommandsRegistered() {
    if (_commandsRegistered) return;
    _commandsRegistered = true;
    final registry = CommandRegistry.instance;
    registry.resetForTesting();

    _registerBasicInfoCommands(registry);
    _registerRelationCommands(registry);
    _registerStudyCommands(registry);
    _registerItemCommands(registry);
    _registerActivityCommands(registry);
    _registerWorldCommands(registry);
    registerCheatCommands(registry);

    registry.seal();
  }

  // —— 基础信息类 ——
  void _registerBasicInfoCommands(CommandRegistry registry) {
    registry.registerAll([
      CommandDef(
        primary: '状态',
        group: '基础信息',
        helpText: '查看角色完整状态',
        panel: true,
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
        helpText: '查看当前时间与特殊标记（/时间 快进 [天数|明天|下周…]·/时间 日程）',
        panel: true,
        subs: [
          CommandSub('快进', '快进时间，可接天数/明天/下周/下月/假期/暑假/开学', argHint: '天数|明天|下周…'),
          CommandSub('日程', '查看本周安排与最近事件'),
        ],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsExtrasMixin;
          final sub = ctx.arg(0);
          // P2#11 指令缺口：/时间 快进 —— 与 /快进 同一套结算逻辑
          if (sub == '快进') {
            final gm = ctx.provider as GameSystemsMixin;
            final days = gm.resolveFastForwardDays(ctx.tailFrom(1));
            if (days <= 0) {
              m.currentNarrative =
                  '【时间快进】\n'
                  '${m.worldState.time.formatDate()} —— 你要的时间点已经到了，无需快进。';
              m.choices = [const GameChoice(text: '继续', action: '继续')];
              m.notifyListeners();
              return true;
            }
            final before = m.worldState.time.formatDate();
            final produced = gm.fastForwardDays(days);
            final after = m.worldState.time.formatDate();
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
            buf.writeln('\n接下来你想做些什么？');
            m.currentNarrative = buf.toString();
            m.choices = [
              GameChoice(text: '继续', action: '继续'),
              GameChoice(text: '再快进一个月', action: '/快进 下月'),
            ];
            m.notifyListeners();
            return true;
          }
          // P2#11 指令缺口：/时间 日程
          if (sub == '日程' || sub == '安排' || sub == '本周') {
            m.currentNarrative = m.formatDailySchedule();
            m.choices = [GameChoice(text: '返回', action: '继续')];
            return true;
          }
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
        subs: [
          CommandSub('明天', '快进 1 天'),
          CommandSub('下周', '快进 7 天'),
          CommandSub('下月', '快进到下月'),
          CommandSub('假期', '快进到假期'),
          CommandSub('暑假', '快进到暑假'),
          CommandSub('开学', '快进到开学'),
        ],
        handler: (ctx) {
          final m = ctx.provider as GameSystemsMixin;
          final days = m.resolveFastForwardDays(ctx.tailFrom(0));
          // days == 0 表示「你要的时间点已经到了」——7 月里输入
          // 「/快进 暑假」就是这种。老实现会借 _daysUntilMonth 的循环
          // 绕满一整年，直接跳掉 351 天。
          if (days <= 0) {
            m.currentNarrative =
                '【时间快进】\n'
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
        panel: true,
        helpText: '城堡设定：/城堡 通道 [名字]｜/城堡 幽灵 [名字]｜/城堡 学院 [院名]',
        subs: [
          CommandSub('通道', '全部通道 / 查指定通道', argHint: '名字'),
          CommandSub('幽灵', '全部幽灵 / 查指定幽灵', argHint: '名字'),
          CommandSub('学院', '四院档案 / 查指定学院', argHint: '院名'),
        ],
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
                m.currentNarrative =
                    '【秘密通道】\n城堡里没有「$q」这条路。\n\n'
                    '输入 /城堡 通道 看看已知的七条。';
              } else {
                final known = p.knownToStudents ? '这条路在学生间口耳相传。' : '这条路几乎无人知晓。';
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
            final profile = q.isEmpty
                ? houseProfileOf(m.player?.house)
                : houseProfileOf(q);
            if (profile == null) {
              final why = q.isEmpty ? '你还没有分院，暂时没有自己的学院档案。' : '查不到「$q」的学院档案。';
              m.currentNarrative =
                  '【学院】\n$why\n\n'
                  '四所学院是：格兰芬多、赫奇帕奇、拉文克劳、斯莱特林。';
            } else {
              m.currentNarrative = houseProfileBlock(profile);
            }
          } else {
            m.currentNarrative =
                '${formatCastleOverview(houseKey: m.player?.house)}\n\n输入 /城堡 通道 或 /城堡 幽灵 看更多。';
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '地图',
        group: '基础信息',
        helpText: '查看霍格沃茨地图与NPC位置',
        panel: true,
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
        panel: true,
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
        panel: true,
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = CommandRegistry.instance.buildHelpText();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
    ]);
  }

  // —— 关系 / 恋爱 / 声望类 ——
  void _registerRelationCommands(CommandRegistry registry) {
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
  void _registerStudyCommands(CommandRegistry registry) {
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
  void _registerItemCommands(CommandRegistry registry) {
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
  void _registerActivityCommands(CommandRegistry registry) {
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
  void _registerWorldCommands(CommandRegistry registry) {
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
          // 文案以前许诺的是"与其他时代剧情产生关联（遇到亲世代留下的物品或
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
      ..writeln(
        '【职业】${worldState.graduated ? (p.currentJobTitle ?? '待业') : '霍格沃茨${p.grade ?? 1}年级学生'}',
      )
      ..writeln('【财富】💰 ${p.galleons}金加隆 · 🏦 ${p.bankGalleons}古灵阁')
      ..writeln('【家庭】${p.familyBackground ?? '未设定'}')
      ..writeln(
        '【社会地位】学院声望${p.houseReputation} · 魔法界声望${p.wizardingReputation} · 阵营声望${p.factionReputation}',
      )
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
      ..writeln(
        '已学魔咒：${p.learnedSpells.isEmpty ? '尚未学会任何魔咒（/咒语 查看可学的）' : '${p.learnedSpells.length}个咒语（/咒语 查看详情）'}',
      )
      ..writeln()
      ..writeln('【学院四维】')
      ..writeln(
        '勇气：${p.houseDimensions['courage']}  智慧：${p.houseDimensions['wisdom']}',
      )
      ..writeln(
        '忠诚：${p.houseDimensions['loyalty']}  野心：${p.houseDimensions['ambition']}',
      )
      ..writeln()
      ..writeln('【政治倾向】${p.politicalTendency ?? '未设定'}')
      ..writeln('【模拟风格】${p.simulationStyle ?? '混合模式'}')
      ..writeln(
        '【恋爱状态】${p.loveState.status}${p.loveState.partnerName != null ? '（${p.loveState.partnerName}）' : ''}',
      )
      ..writeln('【世界线变动率】${(p.worldLineDeviation * 100).toStringAsFixed(1)}%')
      ..writeln()
      ..writeln('【装备栏】')
      ..writeln(
        '袍子：${p.equipped['robe'] ?? '（空）'}  帽子：${p.equipped['hat'] ?? '（空）'}',
      )
      ..writeln(
        '扫帚：${p.equipped['broom'] ?? '（空）'}  饰品：${p.equipped['amulet'] ?? '（空）'}',
      )
      ..writeln(
        '【学院杯】${houseKeyOrNull != null ? '本学年贡献 ${p.houseCupPoints} 分（/学院杯 查看）' : '未分院，暂未参与'}',
      )
      ..writeln('【当前目标】${p.currentGoal ?? '尚未设定目标'}');
    // 阿尼马格斯状态（若有）
    if (p.animagus != null) {
      final av = p.animagus!;
      final aStatus = av['status'] as String? ?? 'none';
      if (aStatus == 'transformed') {
        buf.writeln(
          '【阿尼马格斯】形态：${av['form']}'
          '${av['registered'] == true ? '（已登记）' : '（⚠️ 未登记）'}',
        );
      } else if (aStatus == 'studying' || aStatus == 'potionReady') {
        buf.writeln('【阿尼马格斯】研习中（训练进度 ${av['progress'] ?? 0}/100）');
      }
    }
    if (p.patronus != null && p.patronus!.isNotEmpty) {
      buf.writeln('【守护神】${p.patronus}');
    }
    // 【主线剧情】剧情模式下把进度面板并进状态页（批次 5）。
    // 非剧情模式 storyProgress 是 inactive（chapterId 为空），天然跳过。
    // 【为什么放 /状态 而不是新开一块 UI】玩家问"我玩到哪了"的频率
    // 远低于看状态本身；而 /状态 是剧情模式也照常可用的命令（零 AI），
    // 复用它就不用为一块静态文本加屏幕、路由和入口按钮。
    final sp = storyProgress;
    if (sp.active && sp.chapterId.isNotEmpty) {
      final book = findStoryBook(sp.bookId);
      final ch = findStoryChapter(sp.bookId, sp.chapterId);
      final totalSteps = book?.chapters.fold<int>(
            0,
            (n, c) => n + c.steps.length,
          ) ??
          0;
      buf
        ..writeln()
        ..writeln(
          '【主线剧情】📖 ${book?.title ?? sp.bookId}'
          '${ch != null ? ' · 第 ${ch.ordinal} 章 · ${ch.title}' : ''}',
        );
      if (sp.isFinished) {
        buf.writeln('本部剧情已完成（结局：${sp.endingId}）。');
        // 跨部衔接预告：结局态下告知下一部的状态，让"七部一场长局"
        // 的进度在状态页一目了然。
        final nextId = nextStoryBookId(sp.bookId);
        if (nextId != null) {
          final nextBook = findStoryBook(nextId);
          if (nextBook != null && nextBook.chapters.isNotEmpty) {
            final anchor = worldState.time.absoluteDayIndex >=
                    nextBook.startAbsoluteDayIndex
                ? '现在就可以从结局选项进入'
                : '${nextBook.startYear} 年 ${nextBook.startMonth} 月开启';
            buf.writeln('下一部：《${nextBook.title}》——$anchor。');
          } else {
            buf.writeln(
              '下一部：《${bookDisplayName(nextId)}》'
              '的主线还没装载进当前版本。',
            );
          }
        } else {
          buf.writeln('七部曲至此全部走完——这一场魔法人生，是你自己的。');
        }
      } else {
        buf.writeln('进度：已走 ${sp.doneSteps.length}/$totalSteps 步');
      }
      buf.writeln(
        '剧情累计：好感${_signed(sp.totalAffection)} · '
        '声望${_signed(sp.totalReputation)} · '
        '学院分${_signed(sp.totalHousePoints)}',
      );
      if (sp.knowledge.isNotEmpty) {
        buf.writeln('已获情报：${sp.knowledge.length} 条');
      }
    }
    return buf.toString();
  }

  /// 带符号的数值显示（+5 / -3），剧情累计面板用。
  String _signed(int v) => v >= 0 ? '+$v' : '$v';

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
    final isWeekend = isWeekendWeekday(worldState.time.weekday);
    final knownRegions = mapRegions
        .map((r) {
          final unlocked = r.isUnlocked(grade: p?.grade, isWeekend: isWeekend);
          final cond = r.unlockCondition != null
              ? '（${r.unlockCondition}）'
              : '';
          return '  ${unlocked ? r.icon : '🔒'} ${r.name}$cond';
        })
        .join('\n');
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
  // ==================== 作弊指令（设定 8.1-8.5） ====================


}
