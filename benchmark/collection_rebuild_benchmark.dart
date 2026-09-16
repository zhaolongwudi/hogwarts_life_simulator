// P1：集合重建开销基准（纯 Dart，可 `dart run benchmark/collection_rebuild_benchmark.dart`）。
//
// 覆盖目标：审查条目 P3「频繁的集合重建」提到的 `.toList()..sort()` 热路径。
// 这里不做「优化」，只把两种写法的成本差异量化成基准线：
//   A. 每次调用 `.toList()..sort()`（每次创建新列表 + 全量排序）
//   B. 原地 `..sort()`（仅排序，不新建列表）
// P2/P3 后续优化时以本文件跑出的基线为「优化前」参照，避免空口说快。
//
// 用法：
//   dart run benchmark/collection_rebuild_benchmark.dart

import 'package:benchmark_harness/benchmark_harness.dart';

const _kItemCount = 400;

List<int> _makeList() {
  // 用固定种子的伪随机序列，保证每轮数据形状一致、可复现。
  var seed = 0x5EED1234;
  return List<int>.generate(_kItemCount, (_) {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return seed % 10000;
  });
}

/// 写法 A：每次 `.toList()..sort()`（新列表 + 排序）。
class CopyThenSortBenchmark extends BenchmarkBase {
  CopyThenSortBenchmark() : super('A. toList()..sort()（新列表+排序）');

  late List<int> _source;

  @override
  void setup() {
    _source = _makeList();
  }

  @override
  void run() {
    final sorted = _source.toList()..sort();
    if (sorted.length != _kItemCount) {
      throw StateError('unreachable');
    }
  }
}

/// 写法 B：原地排序（不新建列表）。
class InPlaceSortBenchmark extends BenchmarkBase {
  InPlaceSortBenchmark() : super('B. 原地 sort()（不新建列表）');

  late List<int> _source;

  @override
  void setup() {
    _source = _makeList();
  }

  @override
  void run() {
    _source.sort();
  }
}

void main() {
  CopyThenSortBenchmark().report();
  InPlaceSortBenchmark().report();
}
