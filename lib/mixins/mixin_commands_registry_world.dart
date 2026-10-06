import 'dart:async';
import '../data/goal_data.dart';
import '../data/worldline_data.dart';
import '../data/legacy_data.dart';
import '../mixins/mixin_club.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';
import '../data/command_registry.dart';
import '../models/game_systems.dart';
import 'mixin_commands.dart';
import 'mixin_commands_extras.dart';

/// 指令注册表数据段·世界组（r10-2 拆分自 mixin_commands_registry.dart）。
///
/// 覆盖：信件 & 目标 & 世界 & 结局 CommandDef 注册函数（world 组指令）。
/// handler 里引用 GameCommandsMixin / GameCommandsExtrasMixin / GameClubMixin
/// 的成员——运行时 GameProvider with 链同时具备，静态 cast 保持既有写法。
mixin GameCommandsRegistryWorldMixin on GameProviderBase {
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
