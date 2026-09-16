// 地图标记防重叠布局的纯算法层（无 Flutter 依赖，可单测）。

/// 单个地图标记解算后的位置。
class MarkerBox {
  final double left;
  final double top;
  const MarkerBox(this.left, this.top);
}

/// 地图标记防重叠布局。
///
/// 背景：标记位置直接由数据里的归一化 x/y 算出，没有任何碰撞处理。
/// 大屏上勉强能看，但小屏（可用高度只有两三百像素）上，
/// y 相差 0.02 的两个地点只差几像素，而标记本身有 ~120px 高 ——
/// 结果是整片标记叠在一起，既读不出名字也点不中。霍格沃茨一张图
/// 有 18 个地点，问题尤其严重。
///
/// 做法：按 top 排序后做单向扫描（经典标签排布算法）——
/// 每个标记只需躲开排在它前面、且水平方向确实挨着的那些，
/// 一旦冲突就整体下推到刚好不重叠的位置。纯确定性，
/// 所以同一张地图每次打开位置一致。
///
/// 早期版本用的是"成对对称互推 + 多轮迭代"，实测会来回抖动、
/// 甚至在 16 轮内收敛不了（18 个标记最终挤在 130px 内）。
/// 单向扫描一轮就到位，也更可预测。
///
/// 前提：调用方需要保证画布高度足够（world_map_screen 里画布会
/// 按需撑开并允许滚动）。空间物理上不够时本函数只能做到尽量分开。
List<MarkerBox> resolveMarkerOverlaps(
  List<MarkerBox> input, {
  required double boxWidth,
  required double boxHeight,
  required double minTop,
  required double maxLeft,
  required double maxTop,
  double gap = 6.0,
}) {
  if (input.isEmpty) return input;

  final safeLeft = maxLeft < 0 ? 0.0 : maxLeft;
  final safeTop = maxTop < minTop ? minTop : maxTop;

  // 1) 先把水平位置夹进边界：后续判定冲突要用夹紧后的坐标，
  //    否则"看起来错开了、夹完其实重叠"的标记会被漏掉。
  final clamped = <MarkerBox>[
    for (final b in input)
      MarkerBox(
        b.left.clamp(0.0, safeLeft),
        b.top < minTop ? minTop : b.top,
      ),
  ];

  // 2) 按 top 排序（top 相同则按 left），保证扫描方向稳定
  final order = List<int>.generate(clamped.length, (i) => i)
    ..sort((a, b) {
      final c = clamped[a].top.compareTo(clamped[b].top);
      return c != 0 ? c : clamped[a].left.compareTo(clamped[b].left);
    });

  final lefts = <double>[for (final i in order) clamped[i].left];
  final tops = <double>[for (final i in order) clamped[i].top];
  final n = tops.length;

  bool conflicts(int i, int j) =>
      (lefts[i] - lefts[j]).abs() < boxWidth + gap &&
      (tops[i] - tops[j]).abs() < boxHeight + gap;

  // 3) 正向扫描：每个标记躲开排在它前面的所有冲突者
  for (var i = 1; i < n; i++) {
    for (var j = 0; j < i; j++) {
      if (!conflicts(i, j)) continue;
      final target = tops[j] + boxHeight + gap;
      if (target > tops[i]) tops[i] = target;
    }
  }

  // 4) 超出下边界则从底部往回推（画布被外部限制时才会发生）
  if (tops[n - 1] > safeTop) {
    tops[n - 1] = safeTop;
    for (var i = n - 2; i >= 0; i--) {
      for (var j = i + 1; j < n; j++) {
        if (!conflicts(i, j)) continue;
        final target = tops[j] - boxHeight - gap;
        if (target < tops[i]) tops[i] = target;
      }
      if (tops[i] < minTop) tops[i] = minTop;
    }
  }

  // 5) 还原原始顺序并做最后一次边界夹取
  final out = List<MarkerBox>.filled(n, const MarkerBox(0, 0));
  for (var k = 0; k < n; k++) {
    out[order[k]] = MarkerBox(
      lefts[k],
      tops[k].clamp(minTop, safeTop),
    );
  }
  return out;
}
