/// 世界线因果锚点子系统（r6-8 拆分自 mixin_systems.dart）。
///
/// 覆盖：世界线变动率的兑现——因果锚点（跨时代决策的长周期后果落地）。
/// 全部本地结算（零 AI 调用），通过 on 链复用 [GameSystemsMixin] 的时间
/// 推进与通知工具。
library;

import '../data/attribute_data.dart';
import '../data/worldline_data.dart';
import 'mixin_systems.dart';

mixin GameWorldlineAnchorMixin on GameSystemsMixin {
  // ==================== 世界线变动率的兑现：因果锚点 ====================

  /// 结算一次因果锚点抉择，返回展示给玩家的后果文本。
  ///
  /// 这是 `player.worldLineDeviation` 唯一的兑现点：
  /// 之前那个数字只在成就、目标门槛、影响力增速三处被读，玩家看不见它到底干嘛用。
  @override
  String resolveCausalChoice(String anchorId, String optionId) {
    final p = player;
    final anchor = causalAnchorFor(anchorId);
    if (p == null || anchor == null) return '这个抉择已经不在了。';
    // 幂等：同一夜只能选一次。UI 上的按钮在快速连点时可能进来两趟。
    if (worldState.causalChoices.containsKey(anchorId)) {
      return '你已经在这一夜做过选择了。';
    }
    CausalOption? opt;
    for (final o in anchor.options) {
      if (o.id == optionId) opt = o;
    }
    if (opt == null) return '没有这个选项。';

    // 先记档再结算：下面 deviation 会被 clamp 到 [0,1]，
    // 而"这一夜做过了没有"只看记档，不能依赖 clamp 之后的数值。
    worldState.causalChoices[anchorId] = opt.id;
    if (pendingCausalAnchorId == anchorId) pendingCausalAnchorId = null;

    final before = p.worldLineDeviation;
    incrementWorldLineDeviation(opt.deviationDelta);
    final after = p.worldLineDeviation;

    for (final e in opt.reputation.entries) {
      p.playerReputation.add(e.key, e.value);
    }
    for (final e in opt.attributes.entries) {
      p.attributes[e.key] = ((p.attributes[e.key] ?? 50) + e.value).clamp(
        0,
        100,
      );
    }
    if (opt.healthDelta != 0) {
      p.health = (p.health + opt.healthDelta).clamp(0, 100);
    }
    if (opt.impactDelta != 0.0) {
      worldState.playerImpactScore =
          (worldState.playerImpactScore + opt.impactDelta).clamp(0.0, 1.0);
    }

    final buf = StringBuffer()
      ..writeln('【${anchor.title}】')
      ..writeln()
      ..writeln(opt.consequence);

    // 改写留下的痕迹要落到两个地方：
    // 1) /联动 的「已记录的分叉」——玩家随时能翻自己改过什么
    // 2) 之后每一回合的 AI 上下文——不然 AI 下一回合就照着原著写回去了
    if (opt.echo.isNotEmpty) {
      worldState.addTimelineBranch(opt.echo, snapshot: worldSnapshot());
      worldState.addNarrativeEvent(
        '⏳ ${anchor.title}·你选择了「${opt.text}」',
        turn: turnCount,
      );
      notifications.add('⏳ 你改写了一段已经写好的历史');
      if (p.health <= 0) {
        buf.writeln();
        buf.writeln('（你的健康状况已经跌到极限——先去医疗翼。）');
      }
    }

    // NPC 本地状态联动（框架2 §93）：改写历史后同步 NPC 生死/位置，
    // 与上面的 echo（AI 注入凭证）形成双保险——AI 不守规矩时本地状态兜底。
    for (final entry in opt.npcEffects.entries) {
      final npc = npcRegistry[entry.key];
      if (npc == null) continue; // 该时代没有这个 NPC 实体，静默跳过
      final fx = entry.value;
      if (fx.containsKey('alive')) {
        npc.isAlive = fx['alive'] == true;
      }
      if (fx.containsKey('grade') && fx['grade'] is int) {
        npc.grade = fx['grade'] as int;
      }
      if (fx['recent_event'] is String &&
          (fx['recent_event'] as String).isNotEmpty) {
        npc.recentEvents.insert(0, fx['recent_event'] as String);
        if (npc.recentEvents.length > 10) npc.recentEvents.removeLast();
      }
    }

    buf.writeln();
    final pctBefore = (before * 100).toStringAsFixed(1);
    final pctAfter = (after * 100).toStringAsFixed(1);
    final arrow = opt.deviationDelta > 0 ? '↑' : '↓';
    buf.writeln(
      '世界线变动率：$pctBefore% $arrow $pctAfter%'
      '（${stageDefFor(worldLineStageFor(after)).badge} '
      '${stageDefFor(worldLineStageFor(after)).label}）',
    );

    notifyListeners();
    return buf.toString();
  }

  /// /世界线 的输出。
  ///
  /// 关键是**把"还差多少"摆出来**。变动率是个只有小数点后三位的数字，
  /// 不给出通往下一个分歧点的距离，玩家永远不知道自己该做什么、
  /// 也不知道这套系统到底在不在跑。
  /// 世界线变动率的文本进度条（20 格），让「0.3 黑箱」一眼可见（P1-9）。
  String _worldLineBar(double dev) {
    final filled = (dev.clamp(0.0, 1.0) * 20).round();
    return '[${'█' * filled}${'░' * (20 - filled)}]';
  }

  /// 属性成长总账：开局定型值 vs 现在（P1-9）。
  @override
  String formatGrowth() {
    final p = player;
    if (p == null) return '尚未创建角色。';
    final keys = {...p.attributes.keys, ...p.initialAttributes.keys};
    if (keys.isEmpty) return '【成长总账】\n暂无属性数据。';
    final buf = StringBuffer('【成长总账】\n');
    var totalGain = 0;
    var totalAttrs = 0;
    for (final k in keys) {
      final cur = p.attributes[k] ?? 0;
      final init = p.initialAttributes[k] ?? cur;
      final diff = cur - init;
      totalGain += diff;
      totalAttrs += cur;
      buf.writeln(
        '· ${attributeLabel(k)}：$init → $cur'
        '${diff == 0 ? '' : (diff > 0 ? '  ▲+$diff' : '  ▼$diff')}',
      );
    }
    buf.writeln();
    buf.writeln(
      '属性总值 $totalAttrs｜累计成长 '
      '${totalGain >= 0 ? '+' : ''}$totalGain',
    );
    buf.writeln('（初始值记录于开局定型时，老存档显示差值 0）');
    return buf.toString();
  }

  @override
  String formatWorldLine() {
    final p = player;
    if (p == null) return '尚未创建角色。';
    final dev = p.worldLineDeviation;
    final stage = worldLineStageFor(dev);
    final def = stageDefFor(stage);

    final buf = StringBuffer()
      ..writeln('【世界线】${def.badge} ${def.label}')
      ..writeln(
        '变动率 ${(dev * 100).toStringAsFixed(1)}%　'
        '（世界影响力 ${(worldState.playerImpactScore * 100).toStringAsFixed(0)}%）',
      )
      ..writeln(_worldLineBar(dev))
      ..writeln()
      ..writeln(def.aiDirective)
      ..writeln();

    // 已被你改写的事
    final echoes = rewrittenEchoesOf(worldState.causalChoices);
    buf.writeln('【已被你改写的事】');
    if (echoes.isEmpty) {
      buf.writeln('暂无——史书上写的，至今都还是真的。');
    } else {
      for (final e in echoes) {
        buf.writeln('· $e');
      }
      buf.writeln();
      buf.writeln(
        '以上每一条都会一直生效。这个世界是照着它们往下走的，'
        '不是照着原著。',
      );
    }
    buf.writeln();

    // 还没走到的分歧点：给出门槛与差距
    final pending = <CausalAnchor>[];
    for (final a in kCausalAnchors) {
      if (a.era != null && a.era != worldState.era) continue;
      if (worldState.causalChoices.containsKey(a.anchorId)) continue;
      pending.add(a);
    }
    buf.writeln('【尚未解锁的分歧点】');
    if (pending.isEmpty) {
      buf.writeln('这个时代能改的，你都改完了。');
    } else {
      for (final a in pending) {
        final need = stageDefFor(a.minStage);
        final gap = deviationGapToUnlock(a, dev);
        final ok = gap <= 0;
        buf.writeln(
          ok
              ? '✅ ${a.title}　（需 ${need.label} —— 已达成，等它发生时会出现抉择）'
              : '🔒 ${a.title}　（需 ${need.label} ${(need.minDeviation * 100).toStringAsFixed(0)}%'
                    ' —— 还差 ${(gap * 100).toStringAsFixed(1)}%）',
        );
      }
      buf.writeln();
      buf.writeln(
        '变动率随你在这个世界里留下的痕迹缓慢上升，'
        '而每一次「干预」都会让它跳一大截，每一次「旁观」都会把它压回去。',
      );
    }

    // 世界线重演（记录侧）：每个分叉点发生时的世界快照时间轴。
    // 交互式重演（改选择看世界怎么变）需要完整状态快照与分支树，
    // 是后续产品决策项；当前先让玩家能回看"我当时站在哪、世界什么样"。
    if (worldState.timelineBranches.isNotEmpty) {
      buf.writeln();
      buf.writeln('【分叉时间轴】（世界线重演记录）');
      for (var i = 0; i < worldState.timelineBranches.length; i++) {
        final snap = i < worldState.timelineSnapshots.length
            ? worldState.timelineSnapshots[i]
            : const <String, dynamic>{};
        final date = snap['date'];
        final loc = snap['location'];
        final dev = snap['deviation'];
        final dateStr = date is String && date.isNotEmpty ? '[$date]' : '';
        final locStr = loc is String && loc.isNotEmpty ? '· $loc' : '';
        final devStr = dev is num
            ? '· 当时变动率 ${(dev * 100).toStringAsFixed(1)}%'
            : '';
        buf.writeln(
          '· $dateStr ${worldState.timelineBranches[i]}'
          '${locStr.isEmpty ? '' : ' $locStr'}$devStr',
        );
      }
    }

    return buf.toString();
  }

  /// 世界线分叉时的世界快照（供 addTimelineBranch 记录）。
  @override
  Map<String, dynamic> worldSnapshot() {
    final p = player;
    return {
      'date': worldState.time.formatDate(),
      'year': worldState.time.year,
      'academic_year': worldState.academicYear,
      'location': worldState.currentLocation ?? '',
      'deviation': p?.worldLineDeviation ?? 0.0,
      'impact': worldState.playerImpactScore,
    };
  }
}
