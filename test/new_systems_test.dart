/// 新增系统测试：考试成绩 / 阿尼马格斯 / 守护神 / 存档字段
///
/// 覆盖本次完善新增的四块：
///  1. 考试成绩结算（框架2 第60条）：成绩由熟练度主导、有上下限、等级映射稳定；
///  2. 阿尼马格斯（框架2 第67条）：形态与人格关联、成功率随投入增长；
///  3. 守护神（框架2 第66条）：形态与人格/学院/信念关联；
///  4. 新存档字段（cheat/animagus/patronus/examRecords/affectionLocked）可往返。
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/animagus_data.dart';
import 'package:hogwarts_life_simulator/data/exam_data.dart';
import 'package:hogwarts_life_simulator/data/patronus_data.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/models/player.dart';

void main() {
  // ------------------------------------------------------------ 考试成绩
  group('考试成绩结算（框架2 第60条）', () {
    test('成绩等级映射稳定：高分O、低分T', () {
      expect(examGradeFor(90), 'O');
      expect(examGradeFor(85), 'O');
      expect(examGradeFor(70), 'E');
      expect(examGradeFor(55), 'A');
      expect(examGradeFor(40), 'P');
      expect(examGradeFor(25), 'D');
      expect(examGradeFor(10), 'T');
    });

    test('熟练度决定下限：属性90+最差也是A，属性35以下到不了E', () {
      final goodAttrs = {
        'transfiguration': 90,
        'magic_control': 90,
        'spell_understanding': 90,
        'dda': 90,
        'reaction_time': 90,
        'potions': 90,
        'observation': 90,
        'herbology': 90,
        'theory': 90,
        'memory': 90,
        'flying': 90,
      };
      final poorAttrs = {
        'transfiguration': 30,
        'magic_control': 30,
        'spell_understanding': 30,
        'dda': 30,
        'reaction_time': 30,
        'potions': 30,
        'observation': 30,
        'herbology': 30,
        'theory': 30,
        'memory': 30,
        'flying': 30,
      };
      var rng = Random(42);
      for (var i = 0; i < 50; i++) {
        final good = settleExams(
          playerAttrs: goodAttrs,
          nextDouble: rng.nextDouble,
        );
        for (final g in good.values) {
          expect(['O', 'E', 'A'].contains(g), isTrue,
              reason: '属性90+不应考出$g');
        }
        final poor = settleExams(
          playerAttrs: poorAttrs,
          nextDouble: rng.nextDouble,
        );
        for (final g in poor.values) {
          expect(['O', 'E'].contains(g), isFalse,
              reason: '属性30不应考出$g');
        }
      }
    });

    test('同属性全科优秀不可能：随机波动存在，成绩有分布', () {
      final attrs = {
        'transfiguration': 80,
        'magic_control': 80,
        'spell_understanding': 80,
        'dda': 80,
        'reaction_time': 80,
        'potions': 80,
        'observation': 80,
        'herbology': 80,
        'theory': 80,
        'memory': 80,
        'flying': 80,
      };
      final grades = <String>{};
      for (var i = 0; i < 30; i++) {
        final r = settleExams(playerAttrs: attrs, nextDouble: Random(i).nextDouble);
        grades.addAll(r.values);
      }
      expect(grades.length, greaterThanOrEqualTo(2),
          reason: '30次考试的成绩应该有分化，而不是恒为同一档');
    });

    test('成绩单格式化包含所有8门必修', () {
      final records = {
        'transfiguration': 'O',
        'charms': 'E',
        'dda': 'A',
        'potions': 'P',
        'herbology': 'O',
        'astronomy': 'E',
        'history': 'A',
        'flying': 'O',
      };
      final sheet = formatExamSheet(records);
      expect(sheet.contains('变形术'), isTrue);
      expect(sheet.contains('魔咒学'), isTrue);
      expect(sheet.contains('飞行课'), isTrue);
      final s = examSummary(records);
      expect(s.oCount, 3);
      // potions 是 P（差），其余 7 门及格以上
      expect(s.aPlusCount, 7);
    });
  });

  // ------------------------------------------------------------ 阿尼马格斯
  group('阿尼马格斯（框架2 第67条）', () {
    test('形态与人格关联：勇敢特质倾向狮，忠诚倾向獾', () {
      final brave = resolveAnimagusForm(
        personality: ['勇敢', '直率', '正义'],
        house: 'Gryffindor',
        dice: 0.5,
      );
      final loyal = resolveAnimagusForm(
        personality: ['忠诚', '正直', '勤勉'],
        house: 'Hufflepuff',
        dice: 0.5,
      );
      expect(brave, anyOf('雄狮', '灰狼'));
      expect(loyal, anyOf('银獾', '白鹿'));
    });

    test('成功率随训练投入单调上升', () {
      final low = animagusSuccessChance(progress: 10, potions: 50, transfiguration: 50);
      final high = animagusSuccessChance(progress: 90, potions: 80, transfiguration: 80);
      expect(high, greaterThan(low));
      expect(high, lessThanOrEqualTo(0.9));
      expect(low, greaterThanOrEqualTo(0.25));
    });

    test('训练增益有上下界', () {
      for (var i = 0; i < 20; i++) {
        final g = animagusTrainingGain(60 + i, 60 + i);
        expect(g, inInclusiveRange(5, 15));
      }
    });

    test('形态查表往返', () {
      for (final f in kAnimagusForms) {
        expect(animagusFormByName(f.animal)?.animal, f.animal);
      }
      expect(animagusFormByName('不存在的动物'), isNull);
    });
  });

  // ------------------------------------------------------------ 守护神
  group('守护神（框架2 第66条）', () {
    test('形态与人格/学院关联', () {
      final gryff = resolvePatronusForm(
        personality: ['勇敢', '正义'],
        house: 'Gryffindor',
        beliefs: '守护重要的人',
        dice: 0.5,
      );
      final sly = resolvePatronusForm(
        personality: ['野心', '果断'],
        house: 'Slytherin',
        beliefs: '力量至上',
        dice: 0.5,
      );
      expect(gryff, anyOf('银狮', '雄鹿', '牡鹿'));
      expect(sly, anyOf('蛇', '灰狼'));
    });

    test('查表往返', () {
      for (final f in kPatronusForms) {
        expect(patronusFormByName(f.animal)?.animal, f.animal);
      }
    });
  });

  // ------------------------------------------------------------ 存档字段
  group('新字段存档往返', () {
    test('Player 新字段 toJson/fromJson 无损', () {
      final p = Player(
        name: '测试',
        birthYear: '1980',
        bloodType: 'pureblood',
        birthLocation: '伦敦',
        cheatInvincible: true,
        cheatOmniscient: false,
        animagus: {'status': 'transformed', 'form': '雄狮', 'progress': 100, 'registered': true},
        patronus: '银狮',
        examRecords: {
          'OWL': {'potions': 'O', 'dda': 'E'},
          'Y1': {'charms': 'A'},
        },
        cheatOrientationBackup: {'德拉科': '女'},
        cheatModifiedPairs: ['A|B'],
      );
      final restored = Player.fromJson(p.toJson());
      expect(restored.cheatInvincible, isTrue);
      expect(restored.animagus?['form'], '雄狮');
      expect(restored.animagus?['registered'], true);
      expect(restored.patronus, '银狮');
      expect(restored.examRecords['OWL']?['potions'], 'O');
      expect(restored.cheatOrientationBackup['德拉科'], '女');
      expect(restored.cheatModifiedPairs, contains('A|B'));
    });

    test('老存档缺省值兼容：无新字段时按默认', () {
      final oldJson = {
        'id': 'x',
        'name': '旧档',
        'birth_year': '1980',
        'blood_status': 'muggleborn',
        'birth_location': '伦敦',
      };
      final p = Player.fromJson(oldJson);
      expect(p.cheatInvincible, isFalse);
      expect(p.cheatOmniscient, isFalse);
      expect(p.animagus, isNull);
      expect(p.patronus, isNull);
      expect(p.examRecords, isEmpty);
      expect(p.cheatOrientationBackup, isEmpty);
      expect(p.cheatModifiedPairs, isEmpty);
    });

    test('NPC affectionLocked 存档往返', () {
      final n = NPC(id: 'n1', name: '测试NPC', affectionLocked: true, affection: 80);
      final restored = NPC.fromJson(n.toJson());
      expect(restored.affectionLocked, isTrue);
      expect(restored.affection, 80);

      final oldJson = {'id': 'n2', 'name': '旧NPC'};
      expect(NPC.fromJson(oldJson).affectionLocked, isFalse);
    });
  });
}
