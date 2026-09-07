// 批次4「外来数据的健壮性」回归网：F3 / F5 / SI2。
//
// 这三条的核心主题一样：**读进来的是旧存档或外部导入的数据，类型可能漂移，
// 不能因为一个字段不干净就让整份档读不出来。** 断言全部走行为（输入什么、
// 该得到什么），不读源码文本。
import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/models/world_state.dart';
import 'package:hogwarts_life_simulator/services/save_service.dart';
import 'package:hogwarts_life_simulator/utils/json_read.dart';

void main() {
  group('json_read 工具', () {
    test('readString：String 原样，数字/布尔转字符串，非法走 fallback', () {
      expect(readString('哈利'), '哈利');
      expect(readString(123), '123');
      expect(readString(1.5), '1.5');
      expect(readString(true), 'true');
      expect(readString(null, fallback: '缺'), '缺');
      expect(readString({'a': 1}, fallback: '缺'), '缺');
    });

    test('readStringOrNull：只有 String 才取值，其余为 null', () {
      expect(readStringOrNull('hi'), 'hi');
      expect(readStringOrNull(123), isNull);
      expect(readStringOrNull(null), isNull);
      expect(readStringOrNull(false), isNull);
    });

    test('readInt：int/double/数字字符串/布尔都算数', () {
      expect(readInt(7), 7);
      expect(readInt(7.9), 7);
      expect(readInt('42'), 42);
      expect(readInt(' 42 ', fallback: -1), 42);
      expect(readInt(true), 1);
      expect(readInt(false), 0);
      expect(readInt('abc', fallback: -1), -1);
      expect(readInt(null, fallback: -1), -1);
    });

    test('readIntOrNull：非法返回 null 而非硬转', () {
      expect(readIntOrNull(4), 4);
      expect(readIntOrNull('4'), 4);
      expect(readIntOrNull('abc'), isNull);
      expect(readIntOrNull(null), isNull);
    });

    test('readDouble：int/double/数字字符串都算数', () {
      expect(readDouble(3), 3.0);
      expect(readDouble(3.5), 3.5);
      expect(readDouble('2.25'), 2.25);
      expect(readDouble('x', fallback: -1.0), -1.0);
      expect(readDouble(null, fallback: -1.0), -1.0);
    });

    test('readBool：true/1/数字/字符串都识别', () {
      expect(readBool(true), isTrue);
      expect(readBool(1), isTrue);
      expect(readBool(0), isFalse);
      expect(readBool('TRUE'), isTrue);
      expect(readBool('false'), isFalse);
      expect(readBool('1'), isTrue);
      expect(readBool('0'), isFalse);
      expect(readBool('maybe', fallback: true), isTrue);
    });

    test('readStringList：标量转 String，嵌套结构丢弃', () {
      expect(readStringList(['a', 'b']), ['a', 'b']);
      expect(readStringList(['a', 1, true]), ['a', '1', 'true']);
      expect(readStringList({'k': 1}), isEmpty);
      expect(readStringList(['a', {'k': 1}]), ['a']); // 嵌套 Map 被过滤
      expect(readStringList('not a list', fallback: ['fb']), ['fb']);
    });
  });

  group('F3 / F5：宽容反序列化', () {
    test('Player.fromJson：旧存档类型漂移不再崩溃', () {
      final p = Player.fromJson({
        'id': 123, // num -> '123'
        'name': '哈利',
        'birth_year': '1980',
        'blood_status': 'muggleborn',
        'health': '85', // 数字字符串 -> 85
        'current_goal': 99, // 非字符串可选字段 -> null（不崩）
        'injuries': ['左臂', 3], // 混合列表 -> 全部转 String
        'generation': 2.0, // double 整数 -> 2
        'world_line_deviation': '0.5', // 数字字符串 double -> 0.5
        'grade': '3', // 可选 int，数字字符串
      });
      expect(p.id, '123');
      expect(p.health, 85);
      expect(p.currentGoal, isNull);
      expect(p.injuries, ['左臂', '3']);
      expect(p.generation, 2);
      expect(p.worldLineDeviation, 0.5);
      expect(p.grade, 3);
    });

    test('Player.fromJson：字段缺失时走 fallback 而非抛错', () {
      final p = Player.fromJson({'id': 'x', 'name': 'n', 'birth_year': '1980'});
      expect(p.health, 100);
      expect(p.galleons, 500);
      expect(p.endingType, 'normal');
      expect(p.boneMode, isFalse);
      expect(p.currentGoal, isNull);
    });

    test('NarrativeEvent.fromJson：t 是数值时不崩且尽量保住内容', () {
      final e = NarrativeEvent.fromJson(<String, dynamic>{'t': 123});
      expect(e.text, '123');
      expect(e.turn, isNull);
    });

    test('NarrativeEvent.fromJson：r 数字字符串与缺失 a 都安全', () {
      final e = NarrativeEvent.fromJson(<String, dynamic>{'t': 'x', 'r': '4'});
      expect(e.text, 'x');
      expect(e.turn, 4);
      expect(e.at, isNull);
    });

    test('NarrativeEvent.fromJson：a 非法日期 → 空 at（不崩）', () {
      final e = NarrativeEvent.fromJson(<String, dynamic>{
        't': 'x',
        'a': 'not-a-date',
      });
      expect(e.at, isNull);
    });

    test('NarrativeEvent.fromJson：纯 String 与纯空入参原样兼容', () {
      expect(NarrativeEvent.fromJson('hello').text, 'hello');
      expect(NarrativeEvent.fromJson(42).text, ''); // 非 String/Map → 空
    });
  });

  group('SI2：存档结构校验', () {
    test('合法存档放行', () {
      expect(
        SaveService.isStructurallyValid({
          'save_version': 2,
          'player': <String, dynamic>{},
          'world_state': <String, dynamic>{},
          'turn_count': 5,
        }),
        isTrue,
      );
    });

    test('player / world_state 必须是对象', () {
      expect(
        SaveService.isStructurallyValid({
          'player': 'oops',
          'world_state': <String, dynamic>{},
        }),
        isFalse,
      );
      expect(
        SaveService.isStructurallyValid({
          'player': <String, dynamic>{},
          'world_state': 3,
        }),
        isFalse,
      );
    });

    test('turn_count 须非负数值（容忍数字字符串）', () {
      final base = {
        'player': <String, dynamic>{},
        'world_state': <String, dynamic>{},
      };
      expect(SaveService.isStructurallyValid({...base, 'turn_count': 7}), isTrue);
      expect(
        SaveService.isStructurallyValid({...base, 'turn_count': '7'}),
        isTrue,
      );
      expect(
        SaveService.isStructurallyValid({...base, 'turn_count': -1}),
        isFalse,
      );
      expect(
        SaveService.isStructurallyValid({...base, 'turn_count': 'abc'}),
        isFalse,
      );
      // 缺省 turn_count 视为老档，放行
      expect(SaveService.isStructurallyValid(base), isTrue);
    });

    test('save_version 缺失视为 v1 老档，存在须可识别', () {
      final base = {
        'player': <String, dynamic>{},
        'world_state': <String, dynamic>{},
      };
      expect(SaveService.isStructurallyValid(base), isTrue);
      expect(
        SaveService.isStructurallyValid({...base, 'save_version': '2'}),
        isTrue,
      );
      expect(
        SaveService.isStructurallyValid({...base, 'save_version': 'v2'}),
        isFalse,
      );
    });
  });
}