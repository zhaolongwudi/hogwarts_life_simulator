/// 魔法世界图鉴（百科收集系统）测试。
///
/// 【这一层测什么】
///   1. 数据完整性：id 唯一、分类合法、关键词非空——脏条目会在面板上
///      直接露馅（未知分类永远显示"尚未收录"之类的小 bug）；
///   2. `matchCollection` 纯函数：命中/多命中/不命中的基本语义；
///   3. **关键词-文本守卫**（本文件最重要的一组）：把《魔法石》《密室》
///      全部步骤文本拼起来跑 matchCollection，命中数必须达标——防止将来
///      改动让关键词与叙事文本脱节（图鉴变成永远空着的摆设）；
///   4. 运行时钩子 E2E：跑一步剧情 → 自动收录 + 叙事尾部提示行；
///      /图鉴 面板与 /图鉴 详情的真实输出；
///   5. 存档往返：collection 经 extra_data 通道一个来回后完整还原。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/collection_data.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/story_progress.dart'
    show findStoryBook;
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

Future<GameProvider> makeStoryGame() async {
  final gp = await makeGame(offlineQuickMode: true);
  gp.openingScene = 'letter';
  gp.enterStoryMode();
  return gp;
}

/// 拼接一本书全部步骤文本（情境 + 过场 + 选项 + 后果 + 氛围池），供关键词守卫用例扫描。
String bookFullText(String bookId) {
  final book = findStoryBook(bookId)!;
  final buf = StringBuffer();
  for (final ch in book.chapters) {
    buf.writeln(ch.title);
    for (final s in ch.steps) {
      buf.writeln(s.setup);
      buf.writeln(s.onEnterText ?? '');
      for (final a in s.ambient) {
        buf.writeln(a);
      }
      for (final c in s.choices) {
        buf.writeln(c.text);
        buf.writeln(c.consequence);
      }
    }
  }
  return buf.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllStoryBooks);

  group('A · 数据完整性', () {
    test('id 全局唯一且非空', () {
      final ids = kCollectionCatalog.map((e) => e.id).toSet();
      expect(ids.length, kCollectionCatalog.length, reason: 'id 有重复');
      expect(kCollectionCatalog.length, greaterThanOrEqualTo(50),
          reason: '收集玩法的内容底盘：条目太少撑不起"图鉴"的成就感');
    });

    test('分类必须是五大类之一，且每类都有条目', () {
      for (final e in kCollectionCatalog) {
        expect(
          kCollectionCategories,
          contains(e.category),
          reason: '${e.id} 的分类「${e.category}」不在五大类里',
        );
      }
      for (final cat in kCollectionCategories) {
        expect(
          kCollectionCatalog.any((e) => e.category == cat),
          isTrue,
          reason: '分类「$cat」一条条目都没有',
        );
      }
    });

    test('关键词非空、无空白项、条目内不重复', () {
      for (final e in kCollectionCatalog) {
        expect(e.keywords, isNotEmpty, reason: '${e.id} 没有关键词');
        final kws = e.keywords.toSet();
        expect(kws.length, e.keywords.length, reason: '${e.id} 关键词重复');
        for (final kw in e.keywords) {
          expect(kw.trim(), isNotEmpty, reason: '${e.id} 有空白关键词');
        }
      }
    });

    test('名字与说明非空，说明是纯中文叙述（无占位符）', () {
      for (final e in kCollectionCatalog) {
        expect(e.name.trim(), isNotEmpty, reason: '${e.id} 没有名字');
        expect(e.desc.trim(), isNotEmpty, reason: '${e.id} 没有说明');
        expect(e.desc.contains('TODO'), isFalse);
      }
    });
  });

  group('B · matchCollection 纯函数', () {
    test('空文本返回空集合', () {
      expect(matchCollection(''), isEmpty);
    });

    test('单关键词命中对应条目', () {
      expect(matchCollection('你念出了「除你武器」！'), contains('lore_expelliarmus'));
      expect(matchCollection('曼德拉草的哭声在温室里响起'), contains('lore_mandrake'));
    });

    test('一段文本命中多条（每条只算一次）', () {
      final hit = matchCollection('分院帽唱完歌，对角巷的传闻还在继续');
      expect(hit, containsAll(const ['lore_sorting_hat', 'lore_diagon_alley']));
    });

    test('无关文本零命中', () {
      expect(matchCollection('今天天气不错，大家都在上课。'), isEmpty);
    });
  });

  group('C · 关键词-文本守卫（防脱节，最重要）', () {
    test('《魔法石》全文自然命中 ≥ 15 条', () {
      final hits = matchCollection(bookFullText('ps'));
      expect(
        hits.length,
        greaterThanOrEqualTo(15),
        reason: '关键词与 PS 剧情文本脱节，实际命中：${hits.join(', ')}',
      );
    });

    test('《密室》全文自然命中 ≥ 10 条', () {
      final hits = matchCollection(bookFullText('cos'));
      expect(
        hits.length,
        greaterThanOrEqualTo(10),
        reason: '关键词与 CoS 剧情文本脱节，实际命中：${hits.join(', ')}',
      );
    });
  });

  group('D · 运行时钩子 E2E', () {
    test('跑一步剧情 → 自动收录 + 叙事尾部出现提示行', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(
        GameChoice(text: 'x', action: gp.choices.first.action),
      );
      expect(gp.collectionUnlocked, isNotEmpty, reason: '开局信件文本就该有命中');
      expect(gp.currentNarrative, contains('图鉴收录'));
    });

    test('/图鉴 输出五类进度面板；/图鉴 详情 输出条目说明', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(
        GameChoice(text: 'x', action: gp.choices.first.action),
      );

      expect(gp.handleLocalCommand('/图鉴'), isTrue);
      expect(gp.currentNarrative, contains('魔法世界图鉴'));
      expect(gp.currentNarrative, contains('已收录'));
      for (final cat in kCollectionCategories) {
        expect(gp.currentNarrative, contains('◆ $cat'));
      }

      expect(gp.handleLocalCommand('/图鉴 详情'), isTrue);
      expect(gp.currentNarrative, contains('『'), reason: '详情模式带条目名');
      expect(
        gp.currentNarrative.length,
        greaterThan(gp.collectionUnlocked.length * 10),
        reason: '详情模式应输出每条的说明文字',
      );
    });

    test('解锁只提示一次：同一内容第二次结算不重复收录', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(
        GameChoice(text: 'x', action: gp.choices.first.action),
      );
      final firstCount = gp.collectionUnlocked.length;

      // 手动重复扫描同一段文本：集合去重，不产生新收录
      final hits = matchCollection(gp.currentNarrative);
      final fresh = hits.difference(gp.collectionUnlocked);
      expect(fresh, isEmpty, reason: '已收录的内容不得重复出现在差集里');
      expect(gp.collectionUnlocked.length, firstCount);
    });
  });

  group('E · 存档往返', () {
    test('collection 经 extra_data 一个来回后完整还原', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(
        GameChoice(text: 'x', action: gp.choices.first.action),
      );
      final before = gp.collectionUnlocked.toSet();
      expect(before, isNotEmpty);

      // 与 story_save_test 同构的存档 JSON（走 writeSave 同款字段结构）
      final p = gp.player!;
      final saveJson = {
        'save_version': 2,
        'player': p.toJson(),
        'world_state': gp.worldState.toJson(),
        'npc_registry': gp.npcRegistry.map((k, v) => MapEntry(k, v.toJson())),
        'narrative': gp.currentNarrative,
        'choices': gp.choices
            .map((c) => {'text': c.text, 'action': c.action})
            .toList(),
        'turn_count': gp.turnCount,
        'extra_data': {
          'story_progress': gp.storyProgress.toJson(),
          'collection': before.toList(),
          'narrative_summary': '',
          'pending_summary': '',
        },
      };

      gp.applySaveData(saveJson);
      expect(
        gp.collectionUnlocked,
        before,
        reason: '图鉴收录必须能穿过存档往返',
      );
    });

    test('老存档没有 collection key → 空集合，读档不报错', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(
        GameChoice(text: 'x', action: gp.choices.first.action),
      );
      final p = gp.player!;
      final saveJson = {
        'save_version': 2,
        'player': p.toJson(),
        'world_state': gp.worldState.toJson(),
        'npc_registry': gp.npcRegistry.map((k, v) => MapEntry(k, v.toJson())),
        'narrative': gp.currentNarrative,
        'choices': gp.choices
            .map((c) => {'text': c.text, 'action': c.action})
            .toList(),
        'turn_count': gp.turnCount,
        'extra_data': {
          'story_progress': gp.storyProgress.toJson(),
          'narrative_summary': '',
          'pending_summary': '',
          // 故意不放 collection
        },
      };

      gp.applySaveData(saveJson);
      expect(gp.collectionUnlocked, isEmpty, reason: '老存档兼容：读入即空集');
    });
  });
}
