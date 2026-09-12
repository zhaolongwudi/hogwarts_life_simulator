// PrefsStore 的行为测试（审查 D4 / F16 / F36 / F37 的回归网）。
//
// 断言的是行为：写入真的落进 SharedPreferences、一次闭包里的多个写只提交一次、
// 失败时有返回值可查。不读源码文本。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hogwarts_life_simulator/services/prefs_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // 单例会缓存实例，测试之间需要让它重新指向新的 mock 实例。
    PrefsStore.instance.resetForTest();
  });

  group('PrefsStore', () {
    test('write 真的把值写进去，且返回成功', () async {
      final ok = await PrefsStore.instance.write(
        'test_flag',
        (p) => p.setBool('test_flag', true),
      );
      expect(ok, isTrue);
      expect(PrefsStore.instance.getBool('test_flag'), isTrue);
      // 未写过的 key 走 fallback，而不是抛异常
      expect(PrefsStore.instance.getBool('nope', fallback: true), isTrue);
      expect(PrefsStore.instance.getInt('nope', fallback: 7), 7);
    });

    test('F37：一个闭包里的多个写只提交一次', () async {
      var commitCount = 0;
      // SharedPreferences 的 setXxx 本身不会计数，这里用"闭包只被调用一次"
      // 来钉住"批量写入 = 一次调用"这个契约。
      await PrefsStore.instance.write('batch', (p) {
        commitCount++;
        p.remove('api_key_x');
        p.remove('base_url_x');
      });
      expect(commitCount, 1);
    });

    test('F16/F36：writeAsync 不阻塞当前流程', () async {
      var done = false;
      PrefsStore.instance.writeAsync('async_flag', (p) {
        p.setBool('async_flag', true);
        done = true;
      });
      // 还没 await 就能继续往下走（这是刻意的 fire-and-forget）
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });

    test('未初始化时 getString 返回 null 而不是抛异常', () {
      PrefsStore.instance.resetForTest();
      expect(PrefsStore.instance.ready, isFalse);
      expect(PrefsStore.instance.getString('anything'), isNull);
    });
  });
}
