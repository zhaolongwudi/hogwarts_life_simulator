import 'package:flutter/material.dart';
import 'miuix_tokens.dart';

/// Miuix 字体排印阶梯 —— 14 个语义样式，1:1 移植字号/字重/行高。
///
/// Miuix 原版无自定义字体族，使用平台默认字体（Android 小米系统字体 / iOS SF）。
/// Flutter 侧同样沿用平台默认，不做字体捆绑。
///
/// 关键特征：标题体系是 iOS 式的（32sp 大标题 → 折叠为 20sp 小标题），
/// 而非 Material 的 22sp AppBar 标题。
abstract final class MiuiType {
  /// 正文主样式 17 / Normal
  static const main = TextStyle(fontSize: 17, color: MiuiColors.onBackground);

  /// 长段落 17 / 行高 1.2 —— 剧情正文用这个
  static const paragraph = TextStyle(
    fontSize: 17,
    height: 1.2,
    color: MiuiColors.onBackground,
  );

  static const body1 = TextStyle(fontSize: 16, color: MiuiColors.onBackground);
  static const body2 = TextStyle(fontSize: 14, color: MiuiColors.onSurfaceSecondary);

  static const button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: MiuiColors.onSecondaryVariant,
  );

  static const footnote1 = TextStyle(fontSize: 13, color: MiuiColors.onSurfaceVariantSummary);
  static const footnote2 = TextStyle(fontSize: 11, color: MiuiColors.onSurfaceVariantSummary);

  /// 列表行标题 17 / Medium
  static const headline1 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: MiuiColors.onSurface,
  );
  static const headline2 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: MiuiColors.onSurface,
  );

  /// 分组小标题 14 / Bold
  static const subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: MiuiColors.onBackgroundVariant,
  );

  /// 大标题 32（可折叠）
  static const title1 = TextStyle(fontSize: 32, color: MiuiColors.onBackground);
  static const title2 = TextStyle(fontSize: 24, color: MiuiColors.onBackground);
  /// 折叠后的小标题 20 / Medium
  static const title3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: MiuiColors.onBackground,
  );
  static const title4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: MiuiColors.onBackground,
  );

  // ==========================================================================
  // 项目专用派生样式
  // ==========================================================================

  /// 剧情叙事正文：比标准 paragraph 行高更松，长文阅读更舒服
  static const narrative = TextStyle(
    fontSize: 17,
    height: 1.75,
    color: Color(0xFFE8E8EC),
  );

  /// 叙事中的对话（引述）
  static const narrativeDialogue = TextStyle(
    fontSize: 17,
    height: 1.75,
    color: Color(0xFFFFE9B0),
  );

  /// 叙事中的内心独白
  static const narrativeThought = TextStyle(
    fontSize: 16,
    height: 1.75,
    fontStyle: FontStyle.italic,
    color: Color(0xFFA8B4D0),
  );

  /// 数值 / 统计（等宽数字，避免跳动）
  static const numeric = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    color: MiuiColors.onSurface,
  );

  /// 导航栏标签
  static const navLabel = TextStyle(
    fontSize: MiuiSpace.navBarFontSize,
    fontWeight: FontWeight.normal,
    color: MiuiColors.onSurfaceVariantActions,
  );
  static const navLabelSelected = TextStyle(
    fontSize: MiuiSpace.navBarFontSize,
    fontWeight: FontWeight.bold,
    color: MiuiColors.primaryVariant,
  );
}
