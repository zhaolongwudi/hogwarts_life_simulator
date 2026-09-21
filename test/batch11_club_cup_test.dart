/// Batch 11 · 社团 × 学院杯反向半环测试。
///
/// 背景：P18 已实现「社团 → 学院杯」单向（为社团出力 / 晋升王牌·传奇 /
/// 社团任务完成都会写进 houseCupSources，key 带「社团·」/「社团任务·」前缀）。
/// 本批补反向半环：学年结算 settleHouseCup 时，把本学年为社团挣的学院分
/// 单独拎出来，按档位追加「社团荣光」叙事与学院声望/加隆奖励——让
/// 「你属于什么」反过来成为学院杯里看得见的分量（规划文档第一梯队）。
///
/// 覆盖：
///  - 归因统计 clubContributedCupPoints：只认社团前缀正分，负分与无关来源不计；
///  - 档位选择 clubCupTierFor：4 分命中一档、12 分命中二档、不足返回 null；
///  - 结算集成：达标 → 追加「社团荣光」文本 + 奖励到账（加隆/学院声望）；
///  - 结算集成：未达标 → 不追加、无奖励；
///  - 接线静态断言：mixin_play 已 import club_data、结算体存在接入点。
library;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/house_cup_data.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';
import 'helpers/test_fixtures.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 【为什么 mock path_provider】settleHouseCup → _finishLocal → autoSave
  // 走真实文件系统（path_provider 的 getApplicationDocumentsDirectory），
  // 测试环境无原生插件实现，不 mock 会在存档写入时抛 MissingPluginException
  // （batch10 曾实测翻车）。这里把文档目录指到系统临时目录，让保存走真实
  // File 读写，比纯内存 mock 更接近线上行为。
  setUpAll(() async {
    final tmpDir = await Directory.systemTemp.createTemp('batch11_saves_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tmpDir.path;
      }
      return null;
    });
  });
  String _code(String path) => File('lib/$path').readAsStringSync();

  group('Batch 11 · 归因统计', () {
    test('只统计社团前缀的正分来源', () {
      final sources = {
        '社团·决斗俱乐部': 5, // 日常出力
        '社团·决斗俱乐部·王牌': 5, // 晋升
        '社团任务·守护练习': 3, // 任务完成
        '魁地奇取胜': 30, // 非社团，不计
        '日常表现': 8, // 非社团，不计
      };
      expect(clubContributedCupPoints(sources), 13);
    });

    test('社团来源的负分不抵消贡献', () {
      // 扣分不会因为加入社团而少扣，也不该抵消社团贡献
      final real = {
        '社团·决斗俱乐部': 6,
        '日常扣分': -10, // 负分不计
      };
      expect(clubContributedCupPoints(real), 6);
    });

    test('空来源返回 0', () {
      expect(clubContributedCupPoints({}), 0);
      expect(clubContributedCupPoints({'魁地奇取胜': 30}), 0);
    });

    test('前缀必须精确匹配，避免误吞相似 key', () {
      final sources = {
        '社团长会议': 5, // 不以「社团·」开头，不算
        '社团任务清单': 3, // 不以「社团任务·」开头，不算
      };
      expect(clubContributedCupPoints(sources), 0);
    });
  });

  group('Batch 11 · 档位选择', () {
    test('不足最低档返回 null', () {
      expect(clubCupTierFor(0), isNull);
      expect(clubCupTierFor(3), isNull);
    });

    test('4 分命中一档（学院声望 +2，无加隆）', () {
      final tier = clubCupTierFor(4)!;
      expect(tier.houseReputation, 2);
      expect(tier.galleons, 0);
    });

    test('12 分命中二档（学院声望 +4，加隆 10）', () {
      final tier = clubCupTierFor(12)!;
      expect(tier.houseReputation, 4);
      expect(tier.galleons, 10);
    });

    test('档位单调递增且从低到高排列', () {
      for (var i = 1; i < kClubCupBonusTiers.length; i++) {
        expect(kClubCupBonusTiers[i].points,
            greaterThan(kClubCupBonusTiers[i - 1].points),
            reason: '奖励档应按贡献分从低到高排列');
      }
      // 最低档必须 > 0，避免「什么都没做也领奖」
      expect(kClubCupBonusTiers.first.points, greaterThan(0));
    });

    test('占位符保留字面量（\$club / \$points 未插值）', () {
      // const 字符串里的 \$club 应保持字面量，等待结算时 replaceAll
      for (final tier in kClubCupBonusTiers) {
        expect(tier.note, contains(r'$club'), reason: '旁白应保留 \$club 占位符');
        expect(tier.note, contains(r'$points'), reason: '旁白应保留 \$points 占位符');
      }
    });
  });

  group('Batch 11 · 结算集成', () {
    Future<GameProvider> makeSettled({
      required Map<String, int> sources,
      String? clubId,
      int houseReputation = 50,
      int galleons = 100,
    }) async {
      final gp = await makeGame(offlineQuickMode: true);
      gp.player!.house = 'Gryffindor';
      gp.player!.clubId = clubId;
      gp.player!.houseCupPoints =
          sources.values.where((v) => v > 0).fold(0, (a, b) => a + b);
      gp.player!.houseCupSources = Map<String, int>.from(sources);
      gp.player!.houseReputation = houseReputation;
      gp.player!.galleons = galleons;
      // 触发学年结算（settleHouseCup 由学年切换调用；这里直接调以隔离测试）
      gp.settleHouseCup();
      return gp;
    }

    test('贡献达标（12 分）：追加社团荣光叙事 + 奖励到账', () async {
      final gp = await makeSettled(
        sources: {
          '社团·决斗俱乐部': 6,
          '社团·决斗俱乐部·王牌': 5,
          '社团任务·守护练习': 3,
        },
        clubId: 'duel',
        houseReputation: 50,
        galleons: 100,
      );
      final text = gp.currentNarrative;
      expect(text, contains('社团荣光'), reason: '学年结算应追加社团荣光叙事');
      expect(text, contains('决斗俱乐部'), reason: '旁白应点名当前社团');
      expect(text, contains('14'), reason: '旁白应写明本学年贡献分');
      // 二档奖励：加隆 +10、学院声望 +4
      expect(gp.player!.galleons, 110);
      expect(gp.player!.houseReputation, 54);
    });

    test('贡献刚过一档（4 分）：只加学院声望，不加隆', () async {
      final gp = await makeSettled(
        sources: {'社团·快讯社': 4},
        clubId: 'quip',
        houseReputation: 50,
        galleons: 100,
      );
      final text = gp.currentNarrative;
      expect(text, contains('社团荣光'), reason: '一档也应追加叙事');
      expect(text, contains('快讯社'));
      expect(gp.player!.houseReputation, 52);
      expect(gp.player!.galleons, 100, reason: '一档无加隆奖励');
    });

    test('贡献不足（3 分）：不追加叙事、无奖励', () async {
      final gp = await makeSettled(
        sources: {'社团·决斗俱乐部': 3},
        clubId: 'duel',
        houseReputation: 50,
        galleons: 100,
      );
      final text = gp.currentNarrative;
      expect(text, isNot(contains('社团荣光')), reason: '不足最低档不追加叙事');
      expect(gp.player!.houseReputation, 50);
      expect(gp.player!.galleons, 100);
    });

    test('未加入社团但来源含社团 key（异常档）：仍按贡献统计（降级为泛称）', () async {
      // 理论上 clubId 与来源可能不一致（老档/异常），不应崩溃，泛称兜底
      final gp = await makeSettled(
        sources: {'社团·决斗俱乐部': 5},
        clubId: null,
        houseReputation: 50,
        galleons: 100,
      );
      final text = gp.currentNarrative;
      expect(text, contains('社团荣光'));
      expect(text, contains('你的社团'), reason: '无 clubId 时用泛称兜底');
      expect(gp.player!.houseReputation, 52);
    });

    test('来源清零不误伤：结算后社团来源被清空（下学年不重复发奖）', () async {
      final gp = await makeSettled(
        sources: {'社团·决斗俱乐部': 5},
        clubId: 'duel',
      );
      expect(gp.player!.houseCupSources, isEmpty,
          reason: '学年结算后来源明细应清零，避免下学年重复统计');
    });
  });

  group('Batch 11 · 接线静态断言', () {
    test('mixin_play 已 import club_data（clubById 可用）', () {
      final src = _code('mixins/mixin_play.dart');
      expect(src, contains("import '../data/club_data.dart';"),
          reason: 'settleHouseCup 需要 clubById 查询社团名');
    });

    test('settleHouseCup 内含社团荣光接入点', () {
      final src = _code('mixins/mixin_play.dart');
      final fn = src.indexOf('void settleHouseCup()');
      final body = src.substring(fn, src.indexOf('\n  }', fn));
      expect(body, contains('clubContributedCupPoints'),
          reason: '结算体应调用社团贡献统计');
      expect(body, contains('clubCupTierFor'), reason: '结算体应按档位发奖');
      expect(body, contains('houseReputation += tier.houseReputation'),
          reason: '社团荣光应给学院声望奖励');
    });

    test('house_cup_data 导出 Batch 11 新符号', () {
      final src = _code('data/house_cup_data.dart');
      expect(src, contains('int clubContributedCupPoints('));
      expect(src, contains('ClubCupBonusTier? clubCupTierFor('));
      expect(src, contains('kClubCupBonusTiers'));
    });
  });
}
