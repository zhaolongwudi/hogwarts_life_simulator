import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';

/// Miuix / HyperOS 动效规范 —— Folme 弹簧体系。
///
/// Compose 的 `spring(dampingRatio, stiffness)` 与 Flutter 的
/// [SpringDescription] 参数化方式不同，换算关系如下（mass 恒为 1）：
///
///   ω = √(stiffness / mass)                （自然角频率）
///   c = 2 · ζ · √(stiffness · mass)        （阻尼系数）
///
/// Miuix 的 `folmeSpring(damping, response)` 用响应时间而非刚度表达：
///   stiffness = (2π / response)²
///
/// 例：folmeSpring(1.0, 0.3) → stiffness ≈ 438.6，与 Miuix 源码一致。
abstract final class MiuiMotion {
  // ==========================================================================
  // 弹簧构造器
  // ==========================================================================

  /// 直接映射 Compose 的 `spring(dampingRatio, stiffness)`。
  ///
  /// [dampingRatio] ζ：1.0 = 临界阻尼（无过冲），< 1 有回弹。
  /// [stiffness] 刚度，越大越快。
  static SpringDescription spring(double dampingRatio, double stiffness) {
    final w = math.sqrt(stiffness);
    return SpringDescription(
      mass: 1,
      stiffness: stiffness,
      damping: 2 * dampingRatio * w,
    );
  }

  /// Miuix 的 `folmeSpring(damping, response)`。
  ///
  /// [damping] 阻尼比；[response] 响应时间（秒），越小越快。
  static SpringDescription folme({
    double damping = 1.0,
    double response = 0.3,
  }) {
    final w = 2 * math.pi / response;
    return spring(damping, w * w);
  }

  // ==========================================================================
  // 常用弹簧（与 Miuix 源码逐项对应）
  // ==========================================================================

  /// 按压缩放（SinkFeedback）：缩到 0.94
  static SpringDescription get sink => spring(0.8, 600);

  /// 按压倾斜（TiltFeedback）：倾斜 8°
  static SpringDescription get tilt => spring(0.6, 400);

  /// TopAppBar 小标题淡入
  static SpringDescription get appBarTitleIn =>
      folme(damping: 1.0, response: 0.3);

  /// TopAppBar 小标题淡出
  static SpringDescription get appBarTitleOut =>
      folme(damping: 1.0, response: 0.15);

  /// TopAppBar 吸附
  static SpringDescription get appBarSnap => spring(1.0, 2500);

  /// Switch 滑块位移（4 ↔ 25dp）
  static SpringDescription get switchThumb => spring(0.7, 987);

  /// Switch 滑块缩放（1 ↔ 1.127）
  static SpringDescription get switchThumbScale => spring(0.6, 987);

  /// Switch 轨道颜色
  static SpringDescription get switchTrack => spring(0.99, 438.6);

  /// Slider 拖拽中的进度
  static SpringDescription get sliderDrag => spring(0.9, 1755);

  /// Slider 松手 / 程序化改变进度
  static SpringDescription get sliderSettle => spring(0.96, 322);

  /// Slider 滑块缩放
  static SpringDescription get sliderThumbScale => spring(0.6, 987);

  /// Checkbox / Radio 按下（缩到 0.85）
  static SpringDescription get checkPress => spring(0.99, 986.96);

  /// 对话框进场（大屏：缩放 0.8 → 1）
  static SpringDescription get dialogIn => spring(0.9, 438.6);

  /// 对话框进场（小屏：底部滑入）
  static SpringDescription get dialogInSheet => spring(0.88, 450);

  /// 滚轮选择器吸附
  static SpringDescription get pickerSnap => spring(1.0, 400);

  /// 通用导航转场
  static SpringDescription get pageTransition =>
      folme(damping: 1.0, response: 0.35);

  // ==========================================================================
  // 时长与曲线
  // ==========================================================================

  /// 导航栏图标/文字切换
  static const navDuration = Duration(milliseconds: 300);

  /// 分段控件指示器位移
  static const tabDuration = Duration(milliseconds: 200);

  /// 列表项状态层淡入淡出
  static const stateLayerDuration = Duration(milliseconds: 200);

  /// 对话框遮罩
  static const scrimInDuration = Duration(milliseconds: 300);
  static const scrimOutDuration = Duration(milliseconds: 250);

  /// 弹层内容
  static const popupInDuration = Duration(milliseconds: 200);
  static const popupOutDuration = Duration(milliseconds: 150);

  /// 线性进度条不确定态
  static const linearProgressDuration = Duration(milliseconds: 1250);

  /// 圆形进度条旋转
  static const circularProgressDuration = Duration(milliseconds: 1000);

  /// 下拉刷新旋转
  static const refreshSpinDuration = Duration(milliseconds: 800);

  /// Miuix 的 DecelerateEasing(1.5f)
  static const decelerate = Cubic(0.0, 0.0, 0.0, 1.5);

  /// Miuix 的 SinOutEasing
  static const sinOut = Cubic(0.0, 0.0, 0.58, 1.0);

  /// 下拉刷新完成（CubicBezierEasing(0, 0, 0, 0.37)）
  static const refreshDone = Cubic(0.0, 0.0, 0.0, 0.37);

  /// 按压反馈延迟（Miuix TAP_INDICATION_DELAY）
  static const tapIndicationDelay = Duration(milliseconds: 150);

  // ==========================================================================
  // 交互常量
  // ==========================================================================

  /// 按压缩放目标值（SinkFeedback）
  static const double sinkAmount = 0.94;

  /// Checkbox / Radio 按压缩放目标值
  static const double checkPressAmount = 0.85;

  /// Switch / Slider 滑块按压放大倍数
  static const double thumbPressScale = 1.127;

  /// 按压倾斜角度（度）
  static const double tiltDegrees = 8.0;

  /// 状态层叠加透明度（替代 Material 水波纹）
  static const double hoverAlphaDelta = 0.06;
  static const double focusAlphaDelta = 0.08;
  static const double pressAlphaDelta = 0.10;
  static const double holdDownAlphaDelta = 0.10;

  // ==========================================================================
  // 触感（与 Miuix 规范一致）
  // ==========================================================================
  static void toggleOn() => HapticFeedback.mediumImpact();
  static void toggleOff() => HapticFeedback.lightImpact();
  static void segmentTick() => HapticFeedback.selectionClick();
  static void thresholdActivate() => HapticFeedback.mediumImpact();
  static void textHandleMove() => HapticFeedback.selectionClick();
}

/// 把任意 [SpringDescription] 变成可直接用在
/// [TweenAnimationBuilder] / [AnimatedPositioned] / [ImplicitlyAnimatedWidget]
/// 上的 [Curve]。
///
/// 用弹簧的**解析阶跃响应**求值（而非数值积分），因此零误差、零状态：
/// * 欠阻尼 ζ<1：  `1 - e^(-ζωt)·[cos(ω_d t) + (ζω/ω_d)·sin(ω_d t)]`
/// * 临界阻尼 ζ=1：`1 - e^(-ωt)·(1 + ωt)`
/// * 过阻尼 ζ>1：  `1 - (r₂e^(r₁t) - r₁e^(r₂t)) / (r₂ - r₁)`
///
/// 这是 Miuix "Q 弹但不发散"手感能在 Flutter 上还原的关键——
/// 标准的 easeOutCubic 之类的缓动曲线做不出回弹。
class SpringCurve extends Curve {
  const SpringCurve(this.description, {Duration? duration})
      : _explicitDuration = duration;

  /// 直接给定阻尼比与刚度（Compose 风格）。
  SpringCurve.by({required double dampingRatio, required double stiffness})
      : description = MiuiMotion.spring(dampingRatio, stiffness),
        _explicitDuration = null;

  /// Miuix 风格：阻尼比 + 响应时间（秒）。
  SpringCurve.folme({double damping = 1.0, double response = 0.3})
      : description = MiuiMotion.folme(damping: damping, response: response),
        _explicitDuration = null;

  final SpringDescription description;
  final Duration? _explicitDuration;

  /// 弹簧稳定所需时长（秒）。
  ///
  /// 未显式指定时按指数包络衰减到 0.1% 估算：
  /// 欠阻尼 ≈ 7/(ζω)，临界/过阻尼 ≈ 7/ω。
  double get seconds {
    final d = _explicitDuration;
    if (d != null) return d.inMicroseconds / Duration.microsecondsPerSecond;
    final w = math.sqrt(description.stiffness / description.mass);
    final zeta = description.damping /
        (2 * math.sqrt(description.stiffness * description.mass));
    final effective = zeta < 1.0 ? zeta * w : w;
    return (7.0 / effective).clamp(0.05, 3.0);
  }

  Duration get duration => Duration(
        microseconds: (seconds * Duration.microsecondsPerSecond).round(),
      );

  @override
  double transform(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    return _evaluate(t * seconds);
  }

  double _evaluate(double t) {
    final m = description.mass;
    final k = description.stiffness;
    final c = description.damping;
    final w = math.sqrt(k / m);
    final zeta = c / (2 * math.sqrt(k * m));

    if ((zeta - 1.0).abs() < 1e-4) {
      // 临界阻尼
      return 1.0 - math.exp(-w * t) * (1.0 + w * t);
    } else if (zeta < 1.0) {
      // 欠阻尼（有回弹）
      final wd = w * math.sqrt(1.0 - zeta * zeta);
      final decay = math.exp(-zeta * w * t);
      return 1.0 -
          decay * (math.cos(wd * t) + (zeta * w / wd) * math.sin(wd * t));
    } else {
      // 过阻尼
      final wd = w * math.sqrt(zeta * zeta - 1.0);
      final r1 = -zeta * w + wd;
      final r2 = -zeta * w - wd;
      return 1.0 -
          (r2 * math.exp(r1 * t) - r1 * math.exp(r2 * t)) / (r2 - r1);
    }
  }
}

/// Miuix 的过滚动阻尼物理。
///
/// 位移映射：`x - x² + x³/3`（x 为归一化输入），
/// 在 x=1 处导数为 0（与平坦区 C¹ 连续），x=0 处导数最大。
/// 这是"越拉越沉、渐进饱和"手感的核心。
abstract final class MiuiOverscroll {
  /// 归一化输入 → 阻尼后的位移量。
  static double dampingDistance(double normalizedInput, double range) {
    final x = normalizedInput.clamp(0.0, 1.0).toDouble();
    final damped = x - math.pow(x, 2.0) + (math.pow(x, 3.0) / 3.0);
    return damped * range;
  }

  /// 反函数：视觉位移 → 手指位移（用于手势反解）。
  static double touchDistance(double pixelOffset, double range) {
    final absMax = dampingDistance(1.0, range).abs();
    final absPixel = pixelOffset.abs();
    if (absPixel >= absMax) return range * (pixelOffset < 0 ? -1 : 1);

    // 解 x - x² + x³/3 = t 关于 x 的实根
    final t = absPixel / range;
    // 卡尔丹公式：x³ - 3x² + 3x = 3t  →  令 u = x - 1，u³ + 1 = 3t - ... 化简为
    // (1-x)³ = 1 - 3t
    final c = 1.0 - 3.0 * t;
    final root = c >= 0 ? math.pow(c, 1.0 / 3.0) : -math.pow(-c, 1.0 / 3.0);
    final x = 1.0 - root;
    return x * range * (pixelOffset < 0 ? -1 : 1);
  }

  /// pre-fling 抑制系数
  static const double preFlingFactor = 2.13333;

  /// post-fling 抑制系数
  static const double postFlingFactor = 1.53333;
}
