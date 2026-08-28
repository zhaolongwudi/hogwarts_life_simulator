import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/item_data.dart';
import 'package:hogwarts_life_simulator/data/locations.dart';
import 'package:hogwarts_life_simulator/data/npc_data.dart';
import 'package:hogwarts_life_simulator/utils/story_text_renderer.dart';

/// 剧情文字着色渲染规则测试：
/// 冒号对话 / 叙述动词剥离 / 时间日期误判排除 / 未知说话人 / 选项行剥离
void main() {
  const narrationColor = Color(0xFFC9D1D9);
  const dialogueColor = Color(0xFF58A6FF);
  const speakerColor = Color(0xFFFFA657);
  const locationColor = Color(0xFF56D364);
  const characterColor = Color(0xFFE3B341);
  const itemColor = Color(0xFFBC8CFF);

  Color? colorOf(List<TextSpan> spans, String text) {
    for (final s in spans) {
      if (s.text == text) return s.style?.color;
    }
    return null;
  }

  bool hasColor(List<TextSpan> spans, Color color) {
    return spans.any((s) => s.style?.color == color);
  }

  String allText(List<TextSpan> spans) =>
      spans.map((s) => s.text ?? '').join();

  group('冒号对话', () {
    test('已知角色：名字橙色、冒号与台词蓝色', () {
      final spans = StoryTextRenderer.parse('赫敏：我们去图书馆吧。');
      expect(colorOf(spans, '赫敏'), speakerColor);
      expect(colorOf(spans, '：'), dialogueColor);
      expect(colorOf(spans, '我们去图书馆吧。'), dialogueColor);
    });

    test('带情绪修饰：整个「名字（情绪）」按说话人着色', () {
      final spans = StoryTextRenderer.parse('德拉科（冷笑）：何必自讨苦吃。');
      expect(colorOf(spans, '德拉科（冷笑）'), speakerColor);
      expect(colorOf(spans, '何必自讨苦吃。'), dialogueColor);
    });

    test('未知角色名（AI 生成的随机 NPC）也按说话人着色', () {
      final spans = StoryTextRenderer.parse('莉娜：你终于来了。');
      expect(colorOf(spans, '莉娜'), speakerColor);
      expect(colorOf(spans, '你终于来了。'), dialogueColor);
    });
  });

  group('叙述动词剥离', () {
    test('「罗恩说：」——「罗恩」橙色、「说：」叙述灰、台词蓝色', () {
      final spans = StoryTextRenderer.parse('罗恩说："等等我！"');
      expect(colorOf(spans, '罗恩'), speakerColor);
      expect(colorOf(spans, '说：'), narrationColor);
      expect(colorOf(spans, '"等等我！"'), dialogueColor);
    });

    test('未知名字+动词：动词同样归叙述', () {
      final spans = StoryTextRenderer.parse('莉娜问道：今晚要一起自习吗？');
      expect(colorOf(spans, '莉娜'), speakerColor);
      expect(colorOf(spans, '问道：'), narrationColor);
      expect(colorOf(spans, '今晚要一起自习吗？'), dialogueColor);
    });
  });

  group('误判排除', () {
    test('时钟时间不是对话（09:30）', () {
      final spans = StoryTextRenderer.parse('09:30，列车缓缓驶入霍格莫德车站。');
      expect(hasColor(spans, speakerColor), isFalse);
      expect(hasColor(spans, dialogueColor), isFalse);
      expect(colorOf(spans, '霍格莫德车站'), locationColor);
    });

    test('日期行与场景描写不是对话', () {
      final spans = StoryTextRenderer.parse(
          '📅 1991年9月1日 星期日\n清晨的霍格沃茨：雾气弥漫在塔楼之间。');
      expect(hasColor(spans, speakerColor), isFalse);
      expect(hasColor(spans, dialogueColor), isFalse);
      expect(colorOf(spans, '霍格沃茨'), locationColor);
    });

    test('状态标签不是说话人', () {
      final spans = StoryTextRenderer.parse('当前位置：图书馆');
      expect(hasColor(spans, speakerColor), isFalse);
      expect(hasColor(spans, dialogueColor), isFalse);
    });
  });

  group('选项行剥离', () {
    test('内嵌 A/B 选项行被剥离，正文保留', () {
      final spans = StoryTextRenderer.parse(
          '夜色渐深，你回到休息室。\n\nA. 去图书馆自习\nB. 找罗恩下巫师棋');
      final text = allText(spans);
      expect(text, contains('夜色渐深'));
      expect(text, isNot(contains('去图书馆自习')));
      expect(text, isNot(contains('找罗恩下巫师棋')));
    });

    test('以句号结尾的「A.」叙述句不误删', () {
      final spans = StoryTextRenderer.parse('A. 清晨的霍格莫德一片宁静。');
      expect(allText(spans), contains('清晨的霍格莫德一片宁静'));
    });

    test('紧跟正文行且不成块的选项样式行保留', () {
      final spans =
          StoryTextRenderer.parse('你走进礼堂。\nA. 环顾四周，寻找空位');
      expect(allText(spans), contains('环顾四周'));
    });
  });

  // ====== 实体词表跟随数据层 ======
  //
  // 这三张表原先是在渲染器里手抄的字面量，抄的是哈利时代那批熟面孔。
  // 后果不只是少个颜色：好感行的识别正则、台词的说话人判定都拿这张表拼，
  // 于是第一次巫师战争时代的 12 个原创 NPC 在剧情里既不上色、好感变化也
  // 显示不出来。下面这几条把「加 NPC / 加物品自动跟上」钉死。
  group('实体高亮跟随数据层', () {
    /// 渲染器里被排除的通用称谓（与源码里的 _aliasesTooGeneric 对应）。
    /// 测试只做行为验证，这份清单用于跳过那些"故意不高亮"的 NPC。
    const tooGeneric = {
      '双胞胎', '叛徒', '妹妹', '护士长',
      '校医', '教父', '看门人', '管理员',
      '级长', '追球手', '解说员', '蝎子',
    };

    test('每个 NPC 的全名都能被高亮（含全部四个时代）', () {
      final missed = <String>[];
      for (final npc in kAllNpcSeeds) {
        final spans = StoryTextRenderer.parse('${npc.name}站在走廊尽头。');
        if (colorOf(spans, npc.name) != characterColor) {
          missed.add('${npc.id}:${npc.name}');
        }
      }
      expect(missed, isEmpty,
          reason: '这些 NPC 的名字在剧情里不会上色（共 ${kAllNpcSeeds.length} 个）：'
              '${missed.take(8).join('、')}');
    });

    test('第一次巫师战争时代的原创 NPC 也认得（此前一个都不认）', () {
      final missed = <String>[];
      for (final npc in firstWarOriginals) {
        final spans = StoryTextRenderer.parse('${npc.name}朝你点了点头。');
        if (colorOf(spans, npc.name) != characterColor) missed.add(npc.name);
      }
      expect(missed, isEmpty,
          reason: 'first_war 时代原创 NPC 没被高亮：${missed.join('、')}');
    });

    test('NPC 别名同样认得，但通用称谓不染成角色色', () {
      final aliases = <String>{
        for (final npc in kAllNpcSeeds) ...npc.aliases,
      }..removeAll(tooGeneric);
      final missed = <String>[];
      for (final a in aliases) {
        final spans = StoryTextRenderer.parse('$a朝你点了点头。');
        if (colorOf(spans, a) != characterColor) missed.add(a);
      }
      expect(missed, isEmpty,
          reason: '这些别名在剧情里不会上色：${missed.take(8).join('、')}');

      // 反过来：通用称谓不能因为进了别名表就把普通叙述染黄
      for (final w in tooGeneric) {
        final spans = StoryTextRenderer.parse('走廊尽头站着$w，看不清脸。');
        expect(colorOf(spans, w), isNot(characterColor),
            reason: '「$w」是普通名词，不该被当成角色名高亮');
      }
    });

    test('未知时代 NPC 的好感行会被收进【好感度变化】', () {
      // 好感正则就是从角色名表拼出来的：名字不在表里，这一行就不会被
      // 识别成好感变化，玩家看不到数值。
      for (final name in ['马琳·麦金农', '阿拉斯托·穆迪', '秋·张']) {
        final spans =
            StoryTextRenderer.parseWithAffectionStyle('$name：+3（并肩作战）');
        expect(allText(spans), contains('【好感度变化】'),
            reason: '「$name：+3」没被识别成好感变化行');
        expect(allText(spans), contains(name));
      }
    });

    test('物品目录里的东西按物品色高亮（此前 53 个只认得 3 个）', () {
      final missed = <String>[];
      for (final item in kItemCatalog) {
        final spans = StoryTextRenderer.parse('你把${item.name}放进口袋。');
        if (colorOf(spans, item.name) != itemColor) missed.add(item.name);
      }
      expect(missed, isEmpty,
          reason: '这些物品名不上色（共 ${kItemCatalog.length} 个）：'
              '${missed.take(8).join('、')}');
    });

    test('采集材料也按物品色高亮', () {
      for (final m in [...kCommonLootMaterials, ...kRareLootMaterials]) {
        final spans = StoryTextRenderer.parse('你在树根下找到$m。');
        expect(colorOf(spans, m), itemColor, reason: '材料「$m」不上色');
      }
    });

    test('地点表里的主名与别名按地点色高亮', () {
      for (final name in kLocationNames) {
        final spans = StoryTextRenderer.parse('你走向$name，推开门。');
        expect(colorOf(spans, name), locationColor,
            reason: '地点「$name」不上色');
      }
    });

    test('仍是物品的东西不会因为有地点别名就被染成地点色', () {
      // 「分院帽」既是霍格沃茨大礼堂的别名，也是物品表里的道具。
      // 角色→地点→物品按顺序占位，不先去重的话物品那份永远轮不到。
      final spans = StoryTextRenderer.parse('分院帽戴在你头上。');
      expect(colorOf(spans, '分院帽'), itemColor);
    });

    test('渲染器不再手抄词表：实体名一律从数据层派生', () {
      final src = File('lib/utils/story_text_renderer.dart').readAsStringSync();
      expect(src, contains('kAllNpcSeeds'));
      expect(src, contains('allLocationAliases'));
      expect(src, contains('kItemCatalog'));
      // 补充词只允许是"数据层没有的"，不能把 NPC 全名再抄回去
      for (final name in ['马琳·麦金农', '阿拉斯托·穆迪', '斯科皮·马尔福']) {
        expect(src, isNot(contains(name)),
            reason: 'NPC 全名「$name」不该再手抄进渲染器');
      }
    });

    test('通用称谓黑名单没有变成没人认领的字符串', () {
      final src = File('lib/utils/story_text_renderer.dart').readAsStringSync();
      final block = src.split('_aliasesTooGeneric = {')[1].split('}')[0];
      final listed = RegExp(r"'([^']+)'").allMatches(block).map((m) => m.group(1)!);
      final allAliases = <String>{
        for (final npc in kAllNpcSeeds) ...npc.aliases,
      };
      expect(listed, isNotEmpty);
      for (final w in listed) {
        expect(allAliases, contains(w),
            reason: '黑名单里的「$w」已经不是任何 NPC 的别名了，删掉它');
      }
    });
  });
}
