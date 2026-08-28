import 'package:flutter/material.dart';

/// 跟随系统字体缩放的 RichText。
///
/// 背景：Flutter 的 `RichText` 构造参数 `textScaler` **默认值是
/// `TextScaler.noScaling`**（`Text` 组件才会主动传 `MediaQuery.textScalerOf`），
/// 所以所有直接用 RichText 渲染的正文都会无视用户在系统设置里调的大字体，
/// 对弱视玩家等于锁死最小字号。
///
/// 这里统一补上系统缩放，并夹一个上限：叙事原文是 600~800 字长文，
/// 无限放大会把选项区整个挤出屏幕。
class ScaledRichText extends StatelessWidget {
  final InlineSpan text;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  /// 缩放上限，1.0 表示完全不跟随系统设置
  static const double maxScale = 1.6;

  const ScaledRichText({
    super.key,
    required this.text,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  /// 当前上下文实际生效的缩放系数（供其它组件复用同一套夹取策略）
  static TextScaler scalerOf(BuildContext context) {
    final system = MediaQuery.textScalerOf(context);
    final scale = system.scale(1.0).clamp(1.0, maxScale);
    return TextScaler.linear(scale);
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: text,
      textAlign: textAlign,
      textScaler: scalerOf(context),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
