import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/castle_data.dart';
import 'package:hogwarts_life_simulator/data/house_data.dart';

void main() {
  group('城堡档案', () {
    test('城堡基本信息与设定文档一致', () {
      expect(kCastleProfile.founded, '约公元990年');
      expect(kCastleProfile.motto, '眠龙勿扰');
      expect(kCastleProfile.mottoLatin, 'Draco Dormiens Nunquam Titillandus');
      expect(kCastleProfile.founders, hasLength(4));
    });

    test('城堡特征包含不可幻影显形与台阶数', () {
      expect(
        kCastleProfile.traits.any((t) => t.contains('142')),
        isTrue,
      );
      expect(
        kCastleProfile.traits.any((t) => t.contains('不可幻影显形')),
        isTrue,
      );
    });
  });

  group('秘密通道', () {
    test('共七条，id 唯一', () {
      expect(secretPassages, hasLength(7));
      final ids = secretPassages.map((p) => p.id).toSet();
      expect(ids, hasLength(7));
    });

    test('回归：打人柳通向尖叫棚屋，不是蜂蜜公爵地窖', () {
      // 这两条通道最容易被写串——都是「钻进一个洞，出来在别处」。
      // 数据落表之前，这类错误只能靠 AI 自觉。
      final willow = passageById('whomping_willow');
      expect(willow, isNotNull);
      expect(willow!.to, '尖叫棚屋');
      expect(willow.to, isNot(contains('蜂蜜公爵')));

      final witch = passageById('one_eyed_witch');
      expect(witch, isNotNull);
      expect(witch!.to, contains('蜂蜜公爵'));
      expect(witch.to, isNot(contains('尖叫棚屋')));
    });

    test('每条通道都有起点、终点与备注', () {
      for (final p in secretPassages) {
        expect(p.id, isNotEmpty);
        expect(p.name, isNotEmpty);
        expect(p.from, isNotEmpty);
        expect(p.to, isNotEmpty);
        expect(p.note, isNotEmpty);
      }
    });

    test('至少有通道通往霍格莫德', () {
      expect(passagesTo('霍格莫德').length, greaterThanOrEqualTo(3));
    });

    test('模糊匹配：写简称也能命中', () {
      expect(passageByName('打人柳')?.id, 'whomping_willow');
      expect(passageByName('独眼女巫')?.id, 'one_eyed_witch');
      expect(passageByName('有求必应屋')?.id, 'room_of_requirement');
      expect(passageByName('天文塔密道')?.id, 'astronomy_tower');
    });

    test('模糊匹配：认不出就返回 null，不硬猜', () {
      expect(passageByName(''), isNull);
      expect(passageByName('   '), isNull);
      expect(passageByName('不存在的密道'), isNull);
    });

    test('学生间口耳相传的路与无人知晓的路都有', () {
      expect(secretPassages.where((p) => p.knownToStudents), isNotEmpty);
      expect(secretPassages.where((p) => !p.knownToStudents), isNotEmpty);
    });
  });

  group('常驻幽灵与特殊居民', () {
    test('id 唯一', () {
      final ids = castleResidents.map((r) => r.id).toSet();
      expect(ids, hasLength(castleResidents.length));
    });

    test('四类学院幽灵都在册', () {
      expect(residentById('nick')?.name, '差点没头的尼克');
      expect(residentById('fat_friar')?.name, '胖修士');
      expect(residentById('grey_lady')?.name, '格雷女士');
      expect(residentById('bloody_baron')?.name, '血人巴罗');
    });

    test('皮皮鬼、桃金娘、宾斯、家养小精灵都在册', () {
      expect(residentById('peeves')?.kind, '恶作剧精灵');
      expect(residentById('moaning_myrtle')?.haunt, contains('盥洗室'));
      expect(residentById('binns')?.kind, '幽灵教授');
      expect(residentById('house_elves')?.haunt, '城堡厨房');
    });

    test('每个居民都有常驻地点与性格描述', () {
      for (final r in castleResidents) {
        expect(r.name, isNotEmpty);
        expect(r.kind, isNotEmpty);
        expect(r.haunt, isNotEmpty);
        expect(r.persona, isNotEmpty);
      }
    });

    test('按地点能查到人', () {
      expect(residentsAt('厨房'), isNotEmpty);
      expect(residentsAt('盥洗室'), isNotEmpty);
      expect(residentsAt('不存在的房间'), isEmpty);
    });

    test('名字模糊匹配', () {
      expect(residentByName('皮皮鬼')?.id, 'peeves');
      expect(residentByName('桃金娘')?.id, 'moaning_myrtle');
      expect(residentByName(''), isNull);
    });
  });

  group('四大学院档案', () {
    test('四院齐全，key 与 house_data 的权威表一致', () {
      expect(houseProfiles, hasLength(4));
      for (final p in houseProfiles) {
        expect(kHouseKeys, contains(p.key));
        expect(kHouseDisplayNames[p.key], p.name);
      }
    });

    test('中文名与 key 都能查到档案', () {
      expect(houseProfileOf('Gryffindor')?.name, '格兰芬多');
      expect(houseProfileOf('gryffindor')?.name, '格兰芬多'); // 老存档大小写
      expect(houseProfileOf('格兰芬多')?.key, 'Gryffindor');
    });

    test('认不出来返回 null（未分院时不要硬塞一个学院）', () {
      expect(houseProfileOf(null), isNull);
      expect(houseProfileOf(''), isNull);
      expect(houseProfileOf('   '), isNull);
      expect(houseProfileOf('阿兹卡班'), isNull);
    });

    test('每院都有特质、休息室、入口、陈设、幽灵、象征、配色与校友', () {
      for (final p in houseProfiles) {
        expect(p.virtues, isNotEmpty);
        expect(p.commonRoom, isNotEmpty);
        expect(p.entrance, isNotEmpty);
        expect(p.interior, isNotEmpty);
        expect(p.ghost, isNotEmpty);
        expect(p.ghostDesc, isNotEmpty);
        expect(p.symbol, isNotEmpty);
        expect(p.colors, isNotEmpty);
        expect(p.alumni, isNotEmpty);
      }
    });

    test('交叉一致性：学院档案里的幽灵名能在居民名册里找到', () {
      // 学院幽灵在两份数据里都出现了（houseProfiles.ghost 与
      // castleResidents.name）。这两份一旦漂了，叙事里就会出现
      // 「本学院的幽灵」和「走廊上飘过的那位」对不上号的情况。
      for (final p in houseProfiles) {
        expect(
          castleResidents.any((r) => r.name == p.ghost),
          isTrue,
          reason: '${p.name} 的学院幽灵「${p.ghost}」不在常驻居民名册里',
        );
      }
    });

    test('交叉一致性：象征与配色对得上', () {
      final expected = <String, String>{
        '格兰芬多': '狮子',
        '赫奇帕奇': '獾',
        '拉文克劳': '鹰',
        '斯莱特林': '蛇',
      };
      for (final p in houseProfiles) {
        expect(p.symbol, expected[p.name]);
      }
    });
  });

  group('展示与提示词', () {
    test('提示词精简版含七条通道的走向', () {
      final brief = castleBriefForPrompt();
      for (final p in secretPassages) {
        expect(brief, contains(p.name));
        expect(brief, contains(p.to));
      }
    });

    test('提示词精简版含全部常驻居民', () {
      final brief = castleBriefForPrompt();
      for (final r in castleResidents) {
        expect(brief, contains(r.name));
      }
    });

    test('提示词精简版不含冗长的性格描述（省 token）', () {
      // persona 是给玩家看的，不该进每回合都发一遍的系统提示词。
      final brief = castleBriefForPrompt();
      expect(brief.length, lessThan(1200));
      expect(brief, isNot(contains('彬彬有礼')));
    });

    test('通道面板七条全列，且标注是否众所周知', () {
      final text = formatCastlePassages();
      for (final p in secretPassages) {
        expect(text, contains(p.name));
        expect(text, contains(p.note));
      }
      expect(text, contains('学生间口耳相传'));
      expect(text, contains('几乎无人知晓'));
    });

    test('居民面板列出性格描述', () {
      final text = formatCastleResidents();
      for (final r in castleResidents) {
        expect(text, contains(r.name));
        expect(text, contains(r.persona));
      }
    });

    test('学院档案块内容完整', () {
      final p = houseProfileOf('Slytherin')!;
      final text = houseProfileBlock(p);
      expect(text, contains('斯莱特林'));
      expect(text, contains('野心'));
      expect(text, contains('血人巴罗'));
      expect(text, contains('绿与银'));
    });

    test('城堡概览带学院时附上该院档案', () {
      final withHouse = formatCastleOverview(houseKey: 'Ravenclaw');
      expect(withHouse, contains('拉文克劳'));
      expect(withHouse, contains('青铜鹰状门环'));

      final without = formatCastleOverview();
      expect(without, contains('霍格沃茨魔法学校'));
      expect(without, isNot(contains('拉文克劳塔楼的最高层')));
    });
  });
}
