import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/locations.dart';

/// 地点对账（第三次审查 N2/N3/N4/N6）的守门测试。
///
/// 背景：第二次审查后新增的地点对账（开学前时间门 / 霍格莫德年级门 / B 类漂移防护）
/// 零测试上线，时间门用无年份 MMDD 比较，把每年 1–8 月的校内地点同步全部拦截
/// （学年 1–6 月玩家在城堡里没法换房间）。本文件把这套逻辑抽成纯函数后钉死。
void main() {
  // ============================================================ 时间门（N2 回归）
  group('开学前时间门 blockedBySeasonGate', () {
    test('7/31 从校外切到霍格沃茨 → 拦（本次时间门的本意）', () {
      expect(
        blockedBySeasonGate(detected: '霍格沃茨大礼堂', current: '家中·卧室', dateInt: 731),
        isTrue,
        reason: '7 月底玩家还在家，被 AI 错切进城堡必须拦下',
      );
    });

    test('7/31 从校外切到国王十字车站 → 拦', () {
      expect(
        blockedBySeasonGate(detected: '国王十字车站', current: '家中·卧室', dateInt: 731),
        isTrue,
      );
    });

    test('7/31 从校外切到霍格沃茨特快列车 → 拦（特快 9/1 才发车）', () {
      expect(
        blockedBySeasonGate(detected: '霍格沃茨特快列车', current: '家中·卧室', dateInt: 731),
        isTrue,
      );
    });

    test('8/31 仍拦，9/1 放行', () {
      expect(
        blockedBySeasonGate(detected: '霍格沃茨大礼堂', current: '家中·卧室', dateInt: 831),
        isTrue,
      );
      expect(
        blockedBySeasonGate(detected: '霍格沃茨大礼堂', current: '家中·卧室', dateInt: 901),
        isFalse,
      );
    });

    test('N2 回归：学年内 1–6 月，已在校内换房间不被拦', () {
      for (final dateInt in [115, 308, 530, 630]) {
        expect(
          blockedBySeasonGate(
            detected: '霍格沃茨大礼堂',
            current: '霍格沃茨·公共休息室',
            dateInt: dateInt,
          ),
          isFalse,
          reason: '3月8日在城堡里从公共休息室去大礼堂不该被时间门拦（dateInt=$dateInt）',
        );
      }
    });

    test('学年内从校内去国王十字车站（放暑假离校）不被拦', () {
      expect(
        blockedBySeasonGate(
          detected: '国王十字车站',
          current: '霍格沃茨·公共休息室',
          dateInt: 615,
        ),
        isFalse,
      );
    });

    test('9/1 已在校内时照常放行', () {
      expect(
        blockedBySeasonGate(
          detected: '霍格沃茨大礼堂',
          current: '霍格沃茨·公共休息室',
          dateInt: 901,
        ),
        isFalse,
      );
    });

    test('未锁定的地点不受时间门约束（对角巷）', () {
      expect(
        blockedBySeasonGate(detected: '对角巷', current: '家中·卧室', dateInt: 731),
        isFalse,
      );
    });

    test('9/1 在国王十字车站登上特快 → 放行', () {
      expect(
        blockedBySeasonGate(
          detected: '霍格沃茨特快列车',
          current: '国王十字车站',
          dateInt: 901,
        ),
        isFalse,
      );
    });
  });

  // ============================================================ 年级门
  group('霍格莫德年级门 blockedByGradeGate', () {
    test('一/二年级去霍格莫德 → 拦', () {
      expect(blockedByGradeGate(detected: '霍格莫德村', grade: 1), isTrue);
      expect(blockedByGradeGate(detected: '霍格莫德村', grade: 2), isTrue);
    });

    test('三年级起放行', () {
      expect(blockedByGradeGate(detected: '霍格莫德村', grade: 3), isFalse);
      expect(blockedByGradeGate(detected: '霍格莫德村', grade: 7), isFalse);
    });

    test('非霍格莫德地点不受年级门约束', () {
      expect(blockedByGradeGate(detected: '对角巷', grade: 1), isFalse);
      expect(blockedByGradeGate(detected: '霍格沃茨大礼堂', grade: 1), isFalse);
    });
  });

  // ============================================================ 地图显示名归一化（N4）
  group('地图显示名 → 规范主名（travelTo 归一化）', () {
    test('城堡区域所有地图点位都能归一化成含「霍格沃茨」的主名', () {
      // 与 world_map_screen.dart 的 _mapData['霍格沃茨'] 逐一对齐。
      // 禁林不在城堡内（loc 不含霍格沃茨是正确行为），单独断言。
      const castlePoints = [
        '天文塔', '拉文克劳塔', '格兰芬多塔', '魁地奇球场', '魔咒教室',
        '变形课教室', '魔药课教室', '大礼堂', '赫奇帕奇地下室',
        '图书馆（含禁书区）', '魔法防御术教室', '决斗俱乐部', '训练场',
        '温室', '海格的小屋', '黑湖', '斯莱特林地牢',
      ];
      for (final p in castlePoints) {
        final r = resolveLocationName(p);
        expect(r, isNotNull, reason: '$p 应能解析出主名');
        expect(r!.contains('霍格沃茨'), isTrue,
            reason: '$p 归一化后（$r）必须含「霍格沃茨」，否则学院杯日常加分失效');
      }
      expect(resolveLocationName('禁林'), '禁林');
    });

    test('校外地图点位归一化到规范主名', () {
      expect(resolveLocationName('国王十字车站'), '国王十字车站');
      expect(resolveLocationName('三把扫帚酒吧'), '霍格莫德村');
      expect(resolveLocationName('蜂蜜公爵糖果店'), '霍格莫德村');
      expect(resolveLocationName('猪头酒吧'), '猪头酒吧');
      expect(resolveLocationName('陋居'), '陋居');
      expect(resolveLocationName('女贞路4号'), '女贞路4号');
      expect(resolveLocationName('格里莫广场12号'), '格里莫广场12号');
    });

    test('大礼堂/天文塔/图书馆归一化到含「霍格沃茨」的主名', () {
      expect(resolveLocationName('大礼堂'), '霍格沃茨大礼堂');
      expect(resolveLocationName('天文塔'), '霍格沃茨·天文塔');
      expect(resolveLocationName('图书馆（含禁书区）'), '霍格沃茨·图书馆');
    });
  });

  // ============================================================ B 类漂移防护
  group('B 类漂移防护 narrativeCorroboratesLocation', () {
    test('正文复现 detected 别名 → 放行', () {
      expect(
        narrativeCorroboratesLocation(
          '霍格沃茨大礼堂',
          '家中·卧室',
          '你推开大门，穿过走廊，走进大礼堂参加分院仪式。',
        ),
        isTrue,
      );
    });

    test('正文有移动动词 → 在途中，放行', () {
      expect(
        narrativeCorroboratesLocation(
          '霍格沃茨·天文塔',
          '霍格沃茨·公共休息室',
          '你沿着楼梯一路向上，准备去上今晚的天文学课。',
        ),
        isTrue,
      );
    });

    test('强冲突：正文明确说在家、标签却写大礼堂 → 拦', () {
      expect(
        narrativeCorroboratesLocation(
          '霍格沃茨大礼堂',
          '家中·卧室',
          '你躺在卧室的床上，养母在厨房喊你吃饭。',
        ),
        isFalse,
      );
    });

    test('正文无地点名词、无冲突 → 放行', () {
      expect(
        narrativeCorroboratesLocation(
          '霍格沃茨·宿舍',
          '霍格沃茨·公共休息室',
          '窗外开始下雨，火把在墙上投下摇晃的影子。',
        ),
        isTrue,
      );
    });
  });

  // ============================================================ N6：裸姓不再撞地点
  group('NPC 姓氏不再误判成地点（N6）', () {
    test('罗恩·韦斯莱不会解析成陋居', () {
      expect(resolveLocationName('罗恩·韦斯莱'), isNull);
    });

    test('韦斯莱家 → 陋居 仍成立', () {
      expect(resolveLocationName('韦斯莱家'), '陋居');
    });

    test('德思礼姨夫不会解析成女贞路4号', () {
      expect(resolveLocationName('德思礼姨夫'), isNull);
    });

    test('德思礼家 / 女贞路 → 女贞路4号 仍成立', () {
      expect(resolveLocationName('德思礼家'), '女贞路4号');
      expect(resolveLocationName('女贞路'), '女贞路4号');
    });
  });
}
