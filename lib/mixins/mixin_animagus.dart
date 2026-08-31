/// 阿尼马格斯系统（框架2 第67条）
///
/// 困难且长期的魔法道路：知识 → 曼德拉草药剂 → 训练 → 满月夜尝试 → 登记。
/// 玩家档案里的 animagus 字段（Map）是唯一状态源：
///   status: none / studying / potionReady / transformed / failed
///   form: 动物形态名（transformed 后生效）
///   progress: 训练进度 0~100
///   attempts: 尝试次数
///   registered: 是否已在魔法部登记
///   failedReason: 失败原因描述

import '../data/animagus_data.dart';
import '../models/game_systems.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';

mixin GameAnimagusMixin on GameProviderBase {
  Map<String, dynamic> _animagus() => player?.animagus ?? <String, dynamic>{};

  void _saveAnimagus(Map<String, dynamic> v) {
    player!.animagus = v;
    notifyListeners();
  }

  /// 状态面板文本
  String _statusText() {
    final v = _animagus();
    final stage = animagusStageOf(v['status'] as String? ?? 'none');
    final form = v['form'] as String?;
    final progress = (v['progress'] as int?) ?? 0;
    final attempts = (v['attempts'] as int?) ?? 0;
    final registered = (v['registered'] as bool?) ?? false;
    final p = player!;
    final potions = p.attributes['potions'] ?? 50;
    final transf = p.attributes['transfiguration'] ?? 50;
    final chance = animagusSuccessChance(
      progress: progress,
      potions: potions,
      transfiguration: transf,
    );

    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《阿尼马格斯修习录》')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln('【阶段】${stage.label}')
      ..writeln(stage.description)
      ..writeln();
    if (form != null && form.isNotEmpty) {
      final f = animagusFormByName(form);
      buf.writeln('【动物形态】$form');
      if (f != null) buf.writeln('  ${f.description}');
      buf.writeln();
    }
    if (stage.id == 'studying' || stage.id == 'potionReady' || stage.id == 'failed') {
      buf.writeln('【训练进度】$progress/100');
      buf.writeln('【尝试次数】$attempts 次');
      if (stage.id == 'potionReady') {
        buf.writeln('【满月夜成功概率】${(chance * 100).round()}%'
            '（受训练进度与魔药/变形熟练度影响）');
      }
      buf.writeln();
    }
    if (stage.id == 'transformed') {
      buf.writeln('【登记状态】${registered ? '✅ 已在魔法部登记' : '⚠️ 未登记！'}');
      if (!registered) {
        buf.writeln(' 未登记的阿尼马格斯是重罪——被魔法部发现将面临阿兹卡班之灾。');
      }
      buf.writeln();
    }
    if (v['failedReason'] != null) {
      buf.writeln('【上次失败】${v['failedReason']}');
      buf.writeln();
    }
    buf
      ..writeln('【指引】')
      ..writeln('  /阿尼马格斯 学习 — 开始研习（五年级起）')
      ..writeln('  /阿尼马格斯 训练 — 推进训练（需药剂就绪）')
      ..writeln('  /阿尼马格斯 尝试 — 满月之夜尝试变身')
      ..writeln('  /阿尼马格斯 登记 — 向魔法部登记');
    return buf.toString();
  }

  /// 处理 /阿尼马格斯 子命令（指令注册在 mixin_commands.dart）
  void handleAnimagusCommand(List<String> parts) {
    final p = player;
    if (p == null) return;
    final v = Map<String, dynamic>.from(_animagus());
    final sub = parts.isEmpty ? '状态' : parts[0];

    switch (sub) {
      case '状态':
        currentNarrative = _statusText();
        return;

      case '学习':
        _startAnimagusStudy(p, v);
        return;

      case '训练':
        _animagusTrain(p, v);
        return;

      case '尝试':
        _animagusAttempt(p, v);
        return;

      case '登记':
        _animagusRegister(p, v);
        return;

      default:
        currentNarrative = '【阿尼马格斯】未知子命令「$sub」。\n'
            '可用：状态 / 学习 / 训练 / 尝试 / 登记';
    }
  }

  void _startAnimagusStudy(Player p, Map<String, dynamic> v) {
    final status = v['status'] as String? ?? 'none';
    if (status == 'transformed') {
      currentNarrative = '你已经完成了这条漫长的路，无需再次学习。';
      return;
    }
    final grade = p.grade ?? 1;
    if (grade < 5) {
      currentNarrative = '你翻开了《阿尼马格斯：从入门到入狱》，但书里的内容远超你目前的变形术水平。'
          '阿尼马格斯是高年级才有资格触碰的领域——至少五年级，你的魔力与心智才足够稳定。\n\n'
          '（当前 ${grade}年级，需五年级起）';
      return;
    }
    final potions = p.attributes['potions'] ?? 50;
    final transf = p.attributes['transfiguration'] ?? 50;
    if (potions < 60 || transf < 60) {
      currentNarrative = '你决心研习阿尼马格斯，却在曼德拉草药剂的配方前停了下来——'
          '这份药剂的复杂程度远超你目前的魔药与变形功底。\n\n'
          '教授们说过：这门变形术比任何已知咒语都更危险，一步之差，就可能永远困在野兽的身体里。\n\n'
          '（需要：五年级 + 魔药学≥60 + 变形术≥60。当前 魔药$potions / 变形$transf）';
      return;
    }
    // 开始研习
    v['status'] = 'studying';
    v['progress'] = (v['progress'] as int?) ?? 0;
    v['attempts'] = (v['attempts'] as int?) ?? 0;
    v.remove('failedReason');
    _saveAnimagus(v);
    advanceTimeForAction('图书馆自习');
    notifications.add('📖 你开始研习阿尼马格斯的理论');
    worldState.addNarrativeEvent('📖 你开始研习阿尼马格斯的理论', turn: turnCount);
    currentNarrative = '接下来的日子里，你把《阿尼马格斯：从入门到入狱》的每一页都翻得起了毛边。'
        '曼德拉草药剂的关键材料已经记在清单上——你要在接下来几周内收集齐它们，'
        '并在每个满月之夜前，把变形术的基础动作练到刻进肌肉里。\n\n'
        '（进入「研习中」阶段。训练满 100 进度后，于满月之夜尝试变身。）';
  }

  void _animagusTrain(Player p, Map<String, dynamic> v) {
    final status = v['status'] as String? ?? 'none';
    if (status != 'studying' && status != 'potionReady') {
      currentNarrative = status == 'none'
          ? '你还没有开始研习阿尼马格斯。先 /阿尼马格斯 学习。'
          : '当前阶段无法训练（${animagusStageOf(status).label}）。';
      return;
    }
    if (p.energy < 20) {
      currentNarrative = '你太累了。变形的训练要求极高的专注力——先休息一晚再来吧。\n\n（精力不足20）';
      return;
    }
    final potions = p.attributes['potions'] ?? 50;
    final transf = p.attributes['transfiguration'] ?? 50;
    final gain = animagusTrainingGain(potions, transf);
    final progress = ((v['progress'] as int?) ?? 0) + gain;
    v['progress'] = progress.clamp(0, 100);
    if (v['progress'] >= 100) {
      v['status'] = 'potionReady';
    }
    _saveAnimagus(v);
    p.energy = (p.energy - 20).clamp(0, 100);
    advanceTimeForAction('图书馆自习');
    notifications.add('🔄 阿尼马格斯训练进度 +$gain');
    worldState.addNarrativeEvent('🔄 你进行了一次阿尼马格斯变形训练', turn: turnCount);
    currentNarrative = '你在空教室里一遍遍练习变形的起手式。'
        '月复一月，身体对"改变"的抗拒在减弱，某种属于本能的东西开始浮现。\n\n'
        '训练进度：${v['progress']}/100'
        '${v['status'] == 'potionReady' ? '\n\n曼德拉草药剂已经备好。等待满月之夜——每月十五。' : ''}';
  }

  void _animagusAttempt(Player p, Map<String, dynamic> v) {
    final status = v['status'] as String? ?? 'none';
    if (status != 'potionReady') {
      if (status == 'transformed') {
        currentNarrative = '你已经掌握了变形的奥秘，无需再次尝试。';
      } else if (status == 'failed') {
        currentNarrative = '上次的失败让你心有余悸。静养一段时间，或重新研习后再试吧。';
      } else {
        currentNarrative = '时机未到。你需要先研习理论（/阿尼马格斯 学习）并把训练练满（/阿尼马格斯 训练），'
            '药剂就绪后才能尝试。';
      }
      return;
    }
    // 满月判定：每月十五
    if (worldState.time.day != 15) {
      currentNarrative = '变形仪式必须在满月之夜进行——魔力最盛的时刻，也是这门变形术唯一安全的窗口。\n\n'
          '今天是${worldState.time.month}月${worldState.time.day}日，离满月还有${_daysUntilFullMoon()}天。';
      return;
    }
    final potions = p.attributes['potions'] ?? 50;
    final transf = p.attributes['transfiguration'] ?? 50;
    final progress = (v['progress'] as int?) ?? 0;
    final chance = animagusSuccessChance(
      progress: progress,
      potions: potions,
      transfiguration: transf,
    );
    final attempts = ((v['attempts'] as int?) ?? 0) + 1;
    v['attempts'] = attempts;
    final dice = random.nextDouble();
    if (dice <= chance) {
      // 成功
      final form = resolveAnimagusForm(
        personality: p.personalityTraits,
        house: p.house ?? '',
        dice: random.nextDouble(),
      );
      v['status'] = 'transformed';
      v['form'] = form;
      v['registered'] = (v['registered'] as bool?) ?? false;
      _saveAnimagus(v);
      bumpImpactScore(0.08, debugReason: '成为阿尼马格斯(世界线扰动)');
      worldState.addNarrativeEvent('🌕 你在满月之夜成功变身为$form（阿尼马格斯）', turn: turnCount);
      currentNarrative = '满月升到中天。你饮下曼德拉草药剂，闭上眼，感受每一块骨骼、每一寸皮肤的记忆。\n\n'
          '疼痛如潮水般漫过全身——然后，潮水退去。\n\n'
          '你睁开眼，世界变得不一样了：气味有了形状，声音有了颜色。你低头，看见自己${animagusFormByName(form)?.description ?? '全新的'}\n\n'
          '你成功了。你是一名真正的阿尼马格斯。\n\n'
          '⚠️ 记得向魔法部登记（/阿尼马格斯 登记）——未登记的阿尼马格斯，是阿兹卡班的重罪。';
    } else {
      // 失败
      v['status'] = 'failed';
      v['failedReason'] = '变形在中途溃散，剧痛中你几乎被困在半兽形态，最后勉强恢复了人形。';
      _saveAnimagus(v);
      p.health = (p.health - 15).clamp(0, 100);
      notifications.add('💔 阿尼马格斯尝试失败：变形中途溃散');
      worldState.addNarrativeEvent('💔 你的阿尼马格斯尝试失败了', turn: turnCount);
      currentNarrative = '满月的魔力在身体里翻涌，你咬紧牙关推进变形——\n\n'
          '下一瞬，剧痛炸开。毛皮与皮肤在争夺你的身体，爪子从指尖探出又缩回。'
          '你几乎要被那野兽的一半吞没，最后拼尽全力才把自己拖回人形。\n\n'
          '你瘫倒在地，浑身发抖。变形的尝试失败了。\n\n'
          '（健康 -15。一段时间内无法再尝试，但并非没有挽回的余地——'
          '调养身体后重新研习，下一次满月或许会不同。）';
    }
  }

  void _animagusRegister(Player p, Map<String, dynamic> v) {
    final status = v['status'] as String? ?? 'none';
    if (status != 'transformed') {
      currentNarrative = '只有真正掌握变形的阿尼马格斯才需要登记。';
      return;
    }
    if (v['registered'] == true) {
      currentNarrative = '你已经在魔法部登记过了。手续齐全，安心使用你的形态吧。';
      return;
    }
    v['registered'] = true;
    _saveAnimagus(v);
    p.playerReputation.add('moral', 3);
    notifications.add('📜 你已在魔法部完成阿尼马格斯登记');
    worldState.addNarrativeEvent('📜 你向魔法部登记了阿尼马格斯身份', turn: turnCount);
    currentNarrative = '你写了一封信给魔法部神奇动物管理控制司，正式登记了自己的阿尼马格斯形态。'
        '两周后回信抵达：登记完成，档案编号归档。\n\n'
        '从现在起，你的变形是合法的。魔法部知道你的形态，也知道你的名字——'
        '这既是保护，也是约束。\n\n'
        '（道德声望 +3）';
  }

  int _daysUntilFullMoon() {
    final day = worldState.time.day;
    if (day <= 15) return 15 - day;
    // 下月十五
    final daysInMonth = _daysInCurrentMonth();
    return (daysInMonth - day) + 15;
  }

  int _daysInCurrentMonth() {
    final m = worldState.time.month;
    final y = worldState.time.year;
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (m == 2 && ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0)) return 29;
    return days[m - 1];
  }
}
