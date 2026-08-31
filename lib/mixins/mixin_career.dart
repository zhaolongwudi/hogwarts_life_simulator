/// 毕业后正式职业系统（框架2 §95 毕业不是结局 / §96 职业有门槛）
///
/// /职业 指令：
///   列表 — 全部职业线 + 达标状态（未达标显示缺口）
///   选择 <职业名> — 入职（需已毕业 + 达标）
///   状态 — 当前职级/年薪/晋升进度
///   辞职 — 离职（回到打工自由身）
///
/// 年结：每年九月（与教职同一节点）发年薪 + 按服务年限晋升。
/// 玩家七年攒下的 O.W.L/N.E.W.T 成绩、核心属性与声望在此兑现为职业起点。

import '../data/career_data.dart';
import '../providers/game_provider_base.dart';

mixin GameCareerMixin on GameProviderBase {
  /// 处理 /职业 子命令
  void handleCareerCommand(List<String> parts) {
    final p = player;
    if (p == null) return;
    final sub = parts.isEmpty ? '状态' : parts[0];

    switch (sub) {
      case '列表':
        currentNarrative = _careerList();
        break;
      case '选择':
        if (parts.length >= 2) {
          _careerJoin(parts.sublist(1).join(' '));
        } else {
          currentNarrative = '用法：/职业 选择 <职业名>，例如 /职业 选择 傲罗';
        }
        break;
      case '状态':
        currentNarrative = _careerStatus();
        break;
      case '辞职':
        _careerQuit();
        break;
      default:
        // 直接传职业名也视为选择
        _careerJoin(parts.join(' '));
    }
  }

  String _careerList() {
    final p = player!;
    final owl = p.examRecords['OWL'] ?? const <String, String>{};
    final newt = p.examRecords['NEWT'] ?? const <String, String>{};
    final buf = StringBuffer('【职业选择】（毕业后可入职）\n');
    for (final c in kCareers) {
      final rep = p.playerReputation.get(c.repDim);
      final ok = c.eligible(
        attributes: p.attributes,
        owlGrades: owl,
        newtGrades: newt,
        repValue: rep,
      );
      final gap = ok ? '' : '　— ${careerGapText(c, attributes: p.attributes, owlGrades: owl, newtGrades: newt, repValue: rep)}';
      buf.writeln('${ok ? '✅' : '🔒'} ${c.name}${gap}');
      if (ok || c.id == 'ordinary') {
        buf.writeln('   ${c.description}');
        buf.writeln('   职级：${c.ranks.join(' → ')} ｜ 年薪 ${c.startPay}~${c.topPay} 加隆');
      }
    }
    buf.writeln('\n用法：/职业 选择 <职业名>');
    return buf.toString();
  }

  void _careerJoin(String name) {
    final p = player!;
    if (!worldState.graduated) {
      currentNarrative = '你还在霍格沃茨念书——职业是毕业以后的事。'
          '（也可以先打点零工，见手机里的「找工作」。）';
      return;
    }
    if (p.careerId != null) {
      currentNarrative = '你已经入职「${careerById(p.careerId!)?.name}」了。'
          '想换工作先 /职业 辞职。';
      return;
    }
    final career = careerByName(name);
    if (career == null) {
      currentNarrative = '没有「$name」这个职业。可选的：'
          '${kCareers.map((c) => c.name).join('、')}。';
      return;
    }
    final owl = p.examRecords['OWL'] ?? const <String, String>{};
    final newt = p.examRecords['NEWT'] ?? const <String, String>{};
    final rep = p.playerReputation.get(career.repDim);
    if (!career.eligible(
      attributes: p.attributes,
      owlGrades: owl,
      newtGrades: newt,
      repValue: rep,
    )) {
      currentNarrative = '「${career.name}」对你不合格。\n'
          '${careerGapText(career, attributes: p.attributes, owlGrades: owl, newtGrades: newt, repValue: rep)}\n\n'
          '职业不是毕业当天想当就能当的——成绩、能力与名声，缺一样都进不了门。';
      return;
    }
    p.careerId = career.id;
    p.careerRankIndex = 0;
    p.careerYears = 0;
    p.currentJobTitle = career.ranks.first;
    notifications.add('💼 你入职了「${career.name}」——${career.ranks.first}');
    worldState.addNarrativeEvent('💼 你入职了「${career.name}」', turn: turnCount);
    currentNarrative = '毕业后的第一份正式工作：${career.name}。\n\n'
        '${career.duty}\n\n'
        '【职级】${career.ranks.first}\n'
        '【年薪】${career.startPay} 加隆（每年九月结算）\n\n'
        '这条路是你七年攒下的成绩与名声铺出来的。接下来的日子，用 /职业 状态 查看你的职场进展。';
  }

  String _careerStatus() {
    final p = player!;
    if (p.careerId == null) {
      if (worldState.graduated) {
        return '你还没有正式职业。\n\n/职业 列表 看看有哪些路可走，'
            '或用手机里的「找工作」打零工先过渡。';
      }
      return '你还在上学——毕业后（/职业 列表）可以挑选正式职业。';
    }
    final c = careerById(p.careerId!)!;
    final rank = p.careerRankIndex.clamp(0, c.ranks.length - 1);
    final yearsInRank = p.careerYears % c.yearsPerRank;
    final pay = c.payAt(rank);
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《职业档案》· ${c.name}')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln('【职级】${c.ranks[rank]}')
      ..writeln('【年薪】$pay 加隆（每年九月结算）')
      ..writeln('【从业】${p.careerYears} 年');
    if (rank < c.ranks.length - 1) {
      final yearsNeeded = c.yearsPerRank - yearsInRank;
      buf.writeln('【晋升】升任「${c.ranks[rank + 1]}」还需约 $yearsNeeded 年');
      buf.writeln('  （服务满 ${c.yearsPerRank} 年 + 职级对应声望达标即可晋升）');
    } else {
      buf.writeln('【晋升】已是「${c.ranks[rank]}」，这条路你走到了顶。');
    }
    buf
      ..writeln()
      ..writeln('${c.duty}');
    return buf.toString();
  }

  void _careerQuit() {
    final p = player!;
    if (p.careerId == null) {
      currentNarrative = '你还没有入职任何职业。';
      return;
    }
    final name = careerById(p.careerId!)?.name ?? '未知职业';
    p.careerId = null;
    p.careerRankIndex = 0;
    p.careerYears = 0;
    p.currentJobTitle = null;
    currentNarrative = '你辞去了${name}的职位。\n\n'
        '办公室的回忆和年薪一起留在了身后——但你带走的东西（经验、人脉、名字）不会消失。'
        '想重新出发时，/职业 列表 还有别的路。';
  }

  /// 每年九月年结：发年薪 + 晋升判定。挂在学年推进的 graduated 分支。
  void settleCareerYear(int yearsPassed) {
    final p = player;
    if (p == null || p.careerId == null) return;
    final c = careerById(p.careerId!)!;
    final totalPay = c.payAt(p.careerRankIndex) * yearsPassed;
    p.galleons += totalPay;
    p.careerYears += yearsPassed;
    // 晋升判定：每满 yearsPerRank 年且声望达标升一级
    var promoted = false;
    while (p.careerRankIndex < c.ranks.length - 1) {
      final yearsInRank = p.careerYears - p.careerRankIndex * c.yearsPerRank;
      if (yearsInRank < c.yearsPerRank) break;
      final rep = p.playerReputation.get(c.repDim);
      final need = 40 + p.careerRankIndex * 15;
      if (rep < need) break;
      p.careerRankIndex++;
      promoted = true;
      p.currentJobTitle = c.ranks[p.careerRankIndex];
    }
    notifications.add('💰 职业年结：${c.name}年薪 +$totalPay 加隆'
        '${promoted ? '，晋升为「${c.ranks[p.careerRankIndex]}」' : ''}');
    worldState.addNarrativeEvent('💰 ${c.name}的年薪结算：+$totalPay 加隆'
        '${promoted ? '，晋升为「${c.ranks[p.careerRankIndex]}」' : ''}', turn: turnCount);
  }
}
