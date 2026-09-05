import 'package:flutter/material.dart';

/// HyperOS / Miuix 风格设计令牌 —— 霍格沃兹魔法金配色变体。
///
/// 移植自 Miuix（github.com/YuKongA/Miuix）的设计规范，保留其版式骨架
/// （圆角阶梯 / 间距 / 表面层级 / 语义槽位结构），主色替换为项目品牌金。
///
/// 与 Miuix 原版的刻意偏离：
/// 1. 主色 #D3A625 是亮金色，其上的 onPrimary 用深色而非白色（可读性）；
/// 2. dark 的 surface 从纯黑微调为 #0A0A0C，避免 OLED 上的涂抹感，
///    同时给游戏内容留出"魔法辉光"叠加空间；
/// 3. 保留项目既有的 danger/success/warning/info 语义色（Miuix 无 success）。
///
/// 用法：全部走 `MiuiTokens.of(context)`，不要在 UI 里写裸色值。
class MiuiColors {
  const MiuiColors._();

  // ==========================================================================
  // 主强调色 —— 魔法金
  // ==========================================================================
  /// 主金：开关/Slider/进度条/主按钮/聚焦边框
  static const primary = Color(0xFFD3A625);
  /// 主金之上的内容色（金底是亮色，必须用深色字，这点与 Miuix 的白字不同）
  static const onPrimary = Color(0xFF1A1206);
  /// 次级金：深底上的文字与图标（提亮，保证暗色模式可读）
  static const primaryVariant = Color(0xFFE0B84A);
  static const onPrimaryVariant = Color(0xFFF3DFA0);

  /// 禁用态主色
  static const disabledPrimary = Color(0xFF4A3C18);
  static const disabledOnPrimary = Color(0xFF7A6A48);
  static const disabledPrimaryButton = Color(0xFF3A3020);
  static const disabledOnPrimaryButton = Color(0xFF6B6153);
  static const disabledPrimarySlider = Color(0xFF4A4030);

  /// 主色容器（选中态底、淡强调块）
  static const primaryContainer = Color(0xFFB8860B);
  static const onPrimaryContainer = Color(0xFFFFFFFF);

  // ==========================================================================
  // 中性色 —— 按钮底 / 次级容器
  // ==========================================================================
  static const secondary = Color(0xFF2E2E34);
  static const onSecondary = Color(0xFFF2F2F2);
  static const secondaryVariant = Color(0xFF3D3D48);
  static const onSecondaryVariant = Color(0xFFF2F2F2);
  static const disabledSecondary = Color(0xFF24242A);
  static const disabledOnSecondary = Color(0xFF55555E);
  static const disabledSecondaryVariant = Color(0xFF2A2A31);
  static const disabledOnSecondaryVariant = Color(0xFF5A5A63);
  static const secondaryContainer = Color(0xFF30303A);
  static const onSecondaryContainer = Color(0xFFC2C2CC);
  static const secondaryContainerVariant = Color(0xFF2D2D34);
  static const onSecondaryContainerVariant = Color(0xFFA8A8B0);

  /// 第三级容器：淡强调背景（金调，用于标签/提示块）
  static const tertiaryContainer = Color(0xFF2A2410);
  static const onTertiaryContainer = Color(0xFFE0B84A);
  static const tertiaryContainerVariant = Color(0xFF33302A);
  static const onTertiaryContainerVariant = Color(0xFFC7BEA6);

  // ==========================================================================
  // 表面层级 —— HyperOS 的核心骨架
  // 暗色下：画布近黑 → 卡片抬升。与 Miuix 一样是自定义层级，非 MD3 色阶。
  // ==========================================================================
  /// 页面画布底色
  static const background = Color(0xFF0A0A0C);
  static const onBackground = Color(0xE6FFFFFF); // 90%
  static const onBackgroundVariant = Color(0xFF8A8A94);

  /// AppBar / NavigationBar 底色
  static const surface = Color(0xFF0A0A0C);
  static const onSurface = Color(0xFFF2F2F2);
  static const surfaceVariant = Color(0xFF191920);
  static const onSurfaceSecondary = Color(0xCCFFFFFF); // 80%
  static const onSurfaceVariantSummary = Color(0x8FFFFFFF); // 56%
  static const onSurfaceVariantActions = Color(0x66FFFFFF); // 40%
  static const disabledOnSurface = Color(0xFF5A5A63);

  /// 卡片 / 列表容器
  static const surfaceContainer = Color(0xFF26252C);
  static const onSurfaceContainer = Color(0xEFFFFFFF);
  static const onSurfaceContainerVariant = Color(0xFFA8A8B2);

  /// 抬升一级（输入框底、分段控件底、悬浮层）
  static const surfaceContainerHigh = Color(0xFF30303A);
  static const onSurfaceContainerHigh = Color(0xFF9C9CA8);

  /// 抬升两级（选中的 chip、按压态）
  static const surfaceContainerHighest = Color(0xFF3B3B47);
  static const onSurfaceContainerHighest = Color(0xFFF2F2F2);

  // ==========================================================================
  // 描边与分隔
  // ==========================================================================
  static const outline = Color(0xFF43434F);
  /// 分隔线：Miuix 是 0.75dp 的极细线，暗色 #393939
  static const dividerLine = Color(0xFF373741);

  // ==========================================================================
  // 浮层
  // ==========================================================================
  /// 弹窗遮罩（Miuix dark 是 60% 黑）
  static const windowDimming = Color(0x99000000);
  /// 液态玻璃容器的可读性底（对应 AndroidLiquidGlass 的 onDrawSurface）
  static const glassSurface = Color(0x66_121212);
  static const glassSurfaceLight = Color(0x66_FAFAFA);

  // ==========================================================================
  // Slider
  // ==========================================================================
  static const sliderKeyPoint = Color(0x4D8A8AA6);
  static const sliderKeyPointForeground = Color(0xFFFFD873);
  static const sliderBackground = Color(0x26FFFFFF);

  // ==========================================================================
  // 状态色（项目既有语义，非 Miuix 规范）
  // ==========================================================================
  /// 危险 / 负面 / 伤害
  static const error = Color(0xFFF12522);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFF2E0603);
  static const onErrorContainer = Color(0xFFFFDAD6);

  /// 成功 / 正面 / 好感升温
  static const success = Color(0xFF10B981);
  static const successContainer = Color(0xFF0C2E22);
  /// 警告 / 中性偏负
  static const warning = Color(0xFFF59E0B);
  static const warningContainer = Color(0xFF33240A);
  /// 信息 / 对话
  static const info = Color(0xFF79C0FF);
  static const infoContainer = Color(0xFF0E1E30);

  // ==========================================================================
  // 学院色（亮色版，暗底可读）—— 从 utils/ui_helpers.dart 收敛而来
  // ==========================================================================
  static const gryffindor = Color(0xFFC7362D);
  static const slytherin = Color(0xFF2D8B5A);
  static const ravenclaw = Color(0xFF4A7BC8);
  static const hufflepuff = Color(0xFFECB939);
  static const houseNeutral = Color(0xFF8B949E);
}

// ============================================================================
// 尺寸与形状
// ============================================================================

/// 圆角阶梯。Miuix 的核心识别特征之一：比 MD3 大得多。
abstract final class MiuiRadius {
  /// 卡片 / 按钮 / 输入框 —— Miuix 主力圆角
  static const double card = 16;
  static const double button = 16;
  static const double field = 16;
  /// 列表内嵌块、小容器
  static const double small = 12;
  /// 分段控件
  static const double tab = 12;
  /// 对话框
  static const double dialog = 32;
  /// 悬浮药丸（FloatingToolbar / 悬浮导航栏 / SnackbarAction）
  static const double pill = 50;
  /// 图标按钮（40 尺寸下等效圆形）
  static const double iconButton = 40;
  /// 工具提示
  static const double tooltip = 12;
  static const double tooltipRich = 16;

  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get buttonRadius => BorderRadius.circular(button);
  static BorderRadius get dialogRadius => BorderRadius.circular(dialog);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
  static BorderRadius get smallRadius => BorderRadius.circular(small);
}

/// 间距与尺寸规范。
abstract final class MiuiSpace {
  /// 页面水平边距 / 列表项内边距（Miuix BasicComponent InsideMargin）
  static const double page = 16;
  static const double itemPadding = 16;
  /// 列表项之间的间隔
  static const double itemGap = 8;
  /// 卡片之间的间隔
  static const double cardGap = 12;
  /// 段落之间
  static const double sectionGap = 24;
  /// 小标题（SmallTitle）内边距
  static const double smallTitleH = 28;
  static const double smallTitleV = 8;

  /// AppBar 标题水平边距（比内容更宽，Miuix 特征）
  static const double titlePadding = 26;
  static const double navIconPadding = 16;
  static const double actionIconPadding = 16;
  /// AppBar 折叠高度
  static const double appBarCollapsed = 52;
  static const double appBarHeight = 56;

  /// 列表项最小高度（Miuix BasicComponent）
  static const double itemMinHeight = 56;
  /// 按钮最小尺寸
  static const double buttonMinWidth = 58;
  static const double buttonMinHeight = 40;
  /// 图标按钮
  static const double iconButtonSize = 40;
  /// FAB
  static const double fabSize = 60;

  /// 导航栏
  static const double navBarHeight = 64;
  static const double navBarIcon = 26;
  static const double navBarFontSize = 12;
  static const double navBarIconTop = 8;
  static const double navBarBottom = 8;

  /// 悬浮导航栏（紧凑）
  static const double floatingNavMinHeight = 48;
  static const double floatingNavOutside = 22;
  static const double floatingNavIcon = 24;

  /// 分隔线厚度（Miuix 的 0.75 极细线）
  static const double dividerThickness = 0.75;

  /// 对话框
  static const double dialogOutside = 12;
  static const double dialogInside = 24;
  static const double dialogMaxWidth = 420;

  /// Snackbar
  static const double snackbarMargin = 12;
  static const double snackbarMinHeight = 48;

  /// Switch
  static const double switchWidth = 49;
  static const double switchHeight = 28;
  static const double switchThumb = 20;

  /// Slider
  static const double sliderHeight = 28;
  /// Checkbox / Radio
  static const double checkBoxSize = 26;

  /// 进度条
  static const double linearProgressHeight = 6;
  static const double circularProgressSize = 30;
}
