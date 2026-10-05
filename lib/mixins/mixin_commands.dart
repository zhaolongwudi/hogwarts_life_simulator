

import 'mixin_command_cheats.dart';
import 'mixin_commands_registry.dart';
import 'mixin_commands_extras.dart';
import '../data/game_config_rules.dart';
import '../data/command_registry.dart';
import '../models/game_systems.dart';
import '../data/castle_data.dart';
import '../models/story_progress.dart';
import '../providers/game_provider_base.dart';
import 'mixin_systems.dart';

mixin GameCommandsMixin on GameProviderBase, GameCommandCheatMixin, GameCommandsRegistryMixin {
  void ensureCommandsRegistered() {
    if (commandsRegistered) return;
    commandsRegistered = true;
    final registry = CommandRegistry.instance;
    registry.resetForTesting();

    registerBasicInfoCommands(registry);
    registerRelationCommands(registry);
    registerStudyCommands(registry);
    registerItemCommands(registry);
    registerActivityCommands(registry);
    registerWorldCommands(registry);
    registerCheatCommands(registry);

    registry.seal();
  }
  // ================ R1：注册命令到注册表（初始化时调用一次即可） ================
  bool commandsRegistered = false;


  // —— 基础信息类 ——
  void registerBasicInfoCommands(CommandRegistry registry) {
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
