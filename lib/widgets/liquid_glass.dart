import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/miuix_tokens.dart';

/// 液态玻璃着色器的全局加载器。
///
/// `ImageFilter.shader` 只在 Impeller 后端可用（Flutter 3.44 移动端默认开启）。
/// 在 Skia 或未启用 Impeller 的环境里，加载/使用会抛异常，
/// 此时 [_supported] 置 false，所有 [LiquidGlass] 自动走降级渲染。
class LiquidGlassShaderLoader {
  LiquidGlassShaderLoader._();

  static FragmentProgram? _program;
  static Future<FragmentProgram?>? _pending;
  static bool _unsupported = false;

  /// 着色器是否已就绪。
  static bool get isReady => _program != null;

  /// 当前环境是否支持液态玻璃（Impeller）。
  static bool get isSupported => !_unsupported;

  static Future<FragmentProgram?> load() {
    final program = _program;
    if (program != null) return Future<FragmentProgram?>.value(program);
    if (_unsupported) return Future<FragmentProgram?>.value(null);
    return _pending ??= _load();
  }

  static Future<FragmentProgram?> _load() async {
    try {
      final program =
          await FragmentProgram.fromAsset('shaders/liquid_glass.frag');
      _program = program;
      return program;
    } catch (_) {
      // Skia 后端 / 着色器编译失败 / 资源缺失 —— 一律降级
      _unsupported = true;
      return null;
    }
  }
}

/// 一块液态玻璃。
///
/// 视觉来源：AndroidLiquidGlass（Kyant0）的 Backdrop v2 折射管线。
/// 渲染顺序（自下而上）：背景模糊 → 斜面折射（+可选色散）→ 可读性底色 → 边缘高光 → 内容。
///
/// 关键参数与原作同名同义：
/// * [refractionHeight] 斜面宽度，从边缘向内的多宽区域内发生折射；
/// * [refractionAmount] 最大位移量，正值 = 边缘内容被放大（Apple 内折射方向）；
/// * [blurRadius] 背景高斯模糊半径；
/// * [chromaticAberration] 7-tap 色散，成本高 ~7 倍，只建议用在按压态等短暂场景。
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    this.width,
    this.height,
    this.child,
    this.padding,
    this.margin,
    this.radius = MiuiRadius.pill,
    this.blurRadius = 8,
    this.refractionHeight = 24,
    this.refractionAmount = 24,
    this.depthEffect = false,
    this.chromaticAberration = false,
    this.highlightAngle = -45,
    this.highlightFalloff = 1.0,
    this.highlightIntensity = 0.5,
    this.surfaceColor = MiuiColors.glassSurface,
    this.surfaceAlpha = 0.4,
    this.saturation = 1.5,
    this.opacity = 1.0,
    this.border,
    this.onTap,
  });

  /// 显式宽度。为空时跟随 child。
  final double? width;

  /// 显式高度。为空时跟随 child。
  final double? height;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// 圆角半径。默认 [MiuiRadius.pill]（全圆药丸）。
  final double radius;

  /// 背景模糊半径（px）。
  final double blurRadius;

  /// 斜面宽度（px），建议不超过 [radius]。
  final double refractionHeight;

  /// 折射位移量（px）。正值产生放大效果。
  final double refractionAmount;

  /// 是否混入径向渐变，产生中心隆起的透镜感。
  final bool depthEffect;

  /// 是否启用色散（性能开销大）。
  final bool chromaticAberration;

  /// 高光入射角（度）。-45 为左上打光。
  final double highlightAngle;

  /// 高光衰减指数，越大越集中在正对光的一侧。
  final double highlightFalloff;

  /// 高光强度。
  final double highlightIntensity;

  /// 可读性底色（保证玻璃上文字可辨认）。
  final Color surfaceColor;

  /// 底色混合比例。
  final double surfaceAlpha;

  /// 背景饱和度。1.5 对应原作的 vibrancy。
  final double saturation;

  /// 整体不透明度。
  final double opacity;

  /// 额外的描边（降级模式下也会绘制）。
  final BoxBorder? border;

  final VoidCallback? onTap;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  FragmentShader? _shader;

  /// 本组件是否已确认 Impeller 可用（ImageFilter.shader 在此后端不抛错）。
  ///
  /// 构造本身不抛，真正的异常发生在绘制路径上；因此这里在 build 时做一次
  /// "试构造"并缓存结果——Skia 后端第一次会抛，之后永久走 blur 降级。
  bool _shaderUsable = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final program = await LiquidGlassShaderLoader.load();
    if (!mounted || program == null) return;
    setState(() => _shader = program.fragmentShader());
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  /// 写入自定义 uniform。
  ///
  /// 索引 0、1（uSize）与 sampler 0（uTexture）由引擎在 ImageFilter 场景自动填充，
  /// 这里绝对不能碰；自定义 uniform 从索引 2 开始。
  void _syncUniforms(FragmentShader shader) {
    shader
      ..setFloat(2, widget.refractionHeight)
      ..setFloat(3, -widget.refractionAmount) // 负号 = 采样点内移 = 放大
      ..setFloat(4, widget.depthEffect ? 1.0 : 0.0)
      ..setFloat(5, widget.chromaticAberration ? 1.0 : 0.0)
      ..setFloat(6, widget.radius)
      ..setFloat(7, widget.blurRadius)
      ..setFloat(8, widget.highlightAngle * 3.141592653589793 / 180.0)
      ..setFloat(9, widget.highlightFalloff)
      ..setFloat(10, widget.highlightIntensity)
      ..setFloat(11, widget.surfaceAlpha)
      ..setFloat(12, widget.surfaceColor.r)
      ..setFloat(13, widget.surfaceColor.g)
      ..setFloat(14, widget.surfaceColor.b)
      ..setFloat(15, widget.surfaceColor.a)
      ..setFloat(16, widget.saturation)
      ..setFloat(17, widget.opacity);
  }

  /// 尝试构建着色器滤镜。Skia 等不支持的后端会抛错，返回 null 表示降级。
  ImageFilter? _tryBuildShaderFilter(FragmentShader shader) {
    if (!_shaderUsable) return null;
    try {
      _syncUniforms(shader);
      return ImageFilter.shader(shader);
    } catch (_) {
      _shaderUsable = false;
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(widget.radius),
      border: widget.border,
    );

    Widget content = Container(
      width: widget.width,
      height: widget.height,
      padding: widget.padding,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: widget.child,
    );

    final shader = _shader;
    ImageFilter filter;
    var useFallback = false;
    if (shader != null && _shaderUsable) {
      final f = _tryBuildShaderFilter(shader);
      if (f != null) {
        filter = f;
      } else {
        useFallback = true;
        filter = _blurFilter();
      }
    } else {
      useFallback = true;
      filter = _blurFilter();
    }

    Widget glass;
    if (useFallback) {
      // 降级：引擎级高斯模糊 + 半透明底色，保留"毛玻璃 + 描边高光"的观感
      glass = BackdropFilter(
        filter: filter,
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: widget.padding,
          decoration: decoration.copyWith(
            color: widget.surfaceColor.withValues(
              alpha: widget.surfaceAlpha * 0.9,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: widget.child,
        ),
      );
    } else {
      glass = BackdropFilter(filter: filter, child: content);
    }

    // BackdropFilter 必须用 ClipRect 限制作用域，否则会作用到整屏
    glass = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: glass,
    );

    if (widget.onTap != null) {
      glass = GestureDetector(onTap: widget.onTap, child: glass);
    }

    if (widget.margin != null) {
      glass = Padding(padding: widget.margin!, child: glass);
    }
    return glass;
  }

  ImageFilter _blurFilter() {
    return ImageFilter.blur(
      sigmaX: widget.blurRadius * 0.8,
      sigmaY: widget.blurRadius * 0.8,
      tileMode: TileMode.clamp,
    );
  }
}
