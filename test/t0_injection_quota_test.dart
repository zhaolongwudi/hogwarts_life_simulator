import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/models/long_term_memory.dart';

/// T0 注入配额分层规则的守门测试。
///
/// 【背景·被修复的静默缺陷】
/// 存储层的「永不遗忘层」容量是 [kMaxPersistentKeyFacts]（60），
/// 但注入侧写死了 `for (int i = 0; i < t0.length && i < 40; i++)`。
/// 于是第 41 条起的 9 分事实（结婚 / 死亡 / 誓言 / 继承）**存着但永远不喂给 AI**——
/// 「永不遗忘」在存储层成立、在注入层不成立。
///
/// 本文件钉死两条不变量：
///   1. 永不遗忘层（importance ≥ 9）在配额内**全量**入选，不被普通层挤掉；
///   2. 普通层最多 [kT0InjectionRegularQuota] 条。
void main() {
  group('T0 注入配额：永不遗忘层全量入选（原缺陷回归）', () {
    test('60 条 9 分事实全部入选（旧实现只给 40）', () {
      final importance = List.filled(60, kPersistentFactImportance);
      final q = computeT0InjectionQuota(importance);
      expect(q.persistentCount, 60,
          reason: '永不遗忘层存储上限是 kMaxPersistentKeyFacts=60，'
              '注入必须能读到全部 60 条，否则又出现"存着读不到"');
      expect(q.total, greaterThanOrEqualTo(60),
          reason: '旧实现 i<40 会让第 41-60 条永久不可见');
    });

    test('永不遗忘层配额 ≥ 存储容量（两个数不允许漂移）', () {
      expect(kT0InjectionPersistentQuota, greaterThanOrEqualTo(kMaxPersistentKeyFacts),
          reason: '注入上限小于存储容量时，必然有一部分事实存了读不到');
    });

    test('永不遗忘层优先于普通层：普通层再多也挤不掉 9 分事实', () {
      // 40 条 9 分 + 200 条 5 分。旧实现按总序取前 40 →
      // 若排序把 5 分放前面，9 分就全被挤掉。新实现分层独立计数。
      final importance = [
        ...List.filled(40, kPersistentFactImportance),
        ...List.filled(200, 5),
      ]..sort((a, b) => b.compareTo(a)); // 降序，模拟调用方排序
      final q = computeT0InjectionQuota(importance);
      expect(q.persistentCount, 40);
      expect(q.regularCount, kT0InjectionRegularQuota);
    });

    test('普通层超配额时被截断', () {
      final importance = List.filled(100, 7);
      final q = computeT0InjectionQuota(importance);
      expect(q.persistentCount, 0);
      expect(q.regularCount, kT0InjectionRegularQuota);
    });

    test('普通层未超配额时全量入选', () {
      final q = computeT0InjectionQuota(List.filled(10, 6));
      expect(q.regularCount, 10);
      expect(q.persistentCount, 0);
    });

    test('永不遗忘层自身超容量时按容量截断（不越界）', () {
      // 存储层本该在 60 条处淘汰，但若存档被外部改坏塞进 100 条 9 分事实，
      // 注入侧也不能越界读取。
      final q = computeT0InjectionQuota(List.filled(100, 10));
      expect(q.persistentCount, kT0InjectionPersistentQuota);
    });

    test('身份级（10 分）与永不遗忘级（9 分）同属一层', () {
      final importance = [10, 10, 9, 9];
      final q = computeT0InjectionQuota(importance);
      expect(q.persistentCount, 4);
      expect(q.regularCount, 0);
    });

    test('空输入不崩', () {
      final q = computeT0InjectionQuota(const []);
      expect(q.total, 0);
    });

    test('混合输入：数量正确且互不侵占', () {
      final importance = [
        ...List.filled(3, 10), // 身份级
        ...List.filled(5, 9), // 永不遗忘级
        ...List.filled(50, 7), // 普通
        ...List.filled(20, 5), // 普通
      ]..sort((a, b) => b.compareTo(a));
      final q = computeT0InjectionQuota(importance);
      expect(q.persistentCount, 8, reason: '3 + 5 = 8 条全部入选');
      expect(q.regularCount, kT0InjectionRegularQuota,
          reason: '70 条普通事实 → 截断到配额');
      expect(q.total, 8 + kT0InjectionRegularQuota);
    });
  });

  group('重要性阈值常量自洽', () {
    test('身份级 ≥ 永不遗忘级', () {
      expect(kIdentityFactImportance, greaterThanOrEqualTo(kPersistentFactImportance));
    });

    test('永不遗忘级高于普通事实的典型分值（7）', () {
      expect(kPersistentFactImportance, greaterThan(7),
          reason: '若阈值降到 7，大量日常事实会被当成永不遗忘，信噪比崩坏');
    });
  });
}
