/// 批次 S4 / S7 专项测试：时间/精力关键词对齐。
///
/// S4：恢复表（mixin_systems.updateNPCsFromAction）原 9 词里「放松」「回房」
/// 不是睡眠动作，却在时间表（time_cost_rules）不认它们时落 30 分钟档给满额
/// +50 精力——「回宿舍躺下」「小憩片刻」30 分钟换满血，精力系统被绕过。
/// 修复：时间表把睡眠系统一到 120 分钟（昼寝级），恢复表只保留真睡眠语义，
/// 「放松」降为小恢复。
///
/// S7：魁地奇训练文档承诺 30 分钟，实际被通用 ['魁地奇','训练'] 规则命中 120
/// 分钟。修复：新增高优先级 ['魁地奇训练','训练赛','训练'] → 30，且不误伤
/// 「魁地奇比赛」（仍 120）。
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/time_cost_rules.dart';

void main() {
  group('S4 睡眠语义统一', () {
    test('睡眠系统一 120 分钟（昼寝/午休级）', () {
      expect(resolveActionCost('回宿舍躺下'), 120);
      expect(resolveActionCost('小憩片刻'), 120);
      expect(resolveActionCost('睡一觉'), 120);
      expect(resolveActionCost('躺下小憩一会'), 120);
      expect(resolveActionCost('回房睡觉'), 120);
    });

    test('整夜保留 480 分钟', () {
      expect(resolveActionCost('就寝'), 480);
      expect(resolveActionCost('睡大觉'), 480);
    });

    test('放松不再是满额睡眠档（落默认 30）', () {
      // 放松既不含睡眠系关键词，也不在时间表其他规则 → 默认 30 分钟
      expect(resolveActionCost('放松一下'), 30);
      expect(resolveActionCost('在草坪上晒太阳放松'), 30);
    });

    test('回房不再被误判为睡眠', () {
      // 「回房拿东西」不恢复满额
      expect(resolveActionCost('回房拿东西'), 30);
    });

    test('疗养/休养/养神命中睡眠档，养猫头鹰不命中', () {
      expect(resolveActionCost('闭目养神'), 120);
      expect(resolveActionCost('去疗养'), 120);
      expect(resolveActionCost('休养几天'), 120);
      // 裸「养」不命中睡眠档（避免「养猫头鹰」被算成睡觉）
      expect(resolveActionCost('养猫头鹰'), 30);
    });
  });

  group('S7 魁地奇训练耗时', () {
    test('魁地奇训练 30 分钟（与设计文档一致）', () {
      expect(resolveActionCost('魁地奇训练'), 30);
      expect(resolveActionCost('去参加魁地奇训练'), 30);
    });

    test('魁地奇比赛仍 120 分钟，不误伤', () {
      expect(resolveActionCost('魁地奇比赛'), 120);
      expect(resolveActionCost('打一场魁地奇比赛'), 120);
    });

    test('普通训练不受 S7 影响（练习魔咒 60）', () {
      expect(resolveActionCost('练习魔咒'), 60);
    });
  });
}
