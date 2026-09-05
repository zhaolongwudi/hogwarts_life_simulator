import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'miuix_tokens.dart';
import 'miuix_typography.dart';
import 'miuix_motion.dart';

/// HyperOS / Miuix 风格主题。
///
/// 设计要点：Material 组件在这里被"重新皮肤化"成 Miuix 的样子——
/// 大圆角、无 elevation、无 ripple、金色强调、极细分隔线、iOS 式字号阶梯。
///
/// 这样做的好处是：存量页面即使还留着旧的硬编码色值，
/// 只要用的是 Material 组件，视觉也会被统一到新语言；
/// 真正需要逐页重写的只有"自定义盒子容器"那部分。
abstract final class MiuiTheme {
  /// 主题扩展的唯一 key。
  static const extensionKey = 'miuix';

  /// 构造完整主题。
  static ThemeData build({Brightness brightness = Brightness.dark}) {
    final isDark = brightness == Brightness.dark;

    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: MiuiColors.background,
      canvasColor: MiuiColors.background,
      // Miuix 不用阴影表达层级，全靠表面色阶
      shadowColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      // Miuix 的水波纹是极淡黑色叠加，Material 的 splash 直接关掉
      hoverColor: MiuiColors.onSurface.withValues(alpha: MiuiMotion.hoverAlphaDelta),
      focusColor: MiuiColors.onSurface.withValues(alpha: MiuiMotion.focusAlphaDelta),
      highlightColor: MiuiColors.onSurface.withValues(alpha: MiuiMotion.pressAlphaDelta),

      colorScheme: _colorScheme(),
      textTheme: _miuiTextTheme,
      primaryTextTheme: _miuiTextTheme,

      appBarTheme: _appBarTheme(),
      cardTheme: _cardTheme(),
      dialogTheme: _dialogTheme(),
      bottomSheetTheme: _bottomSheetTheme(),
      snackBarTheme: _snackBarTheme(),
      dividerTheme: const DividerThemeData(
        color: MiuiColors.dividerLine,
        thickness: MiuiSpace.dividerThickness,
        space: MiuiSpace.dividerThickness,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),
      textButtonTheme: _textButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      iconButtonTheme: _iconButtonTheme(),
      inputDecorationTheme: _inputDecorationTheme(),
      bottomNavigationBarTheme: _bottomNavTheme(),
      navigationBarTheme: _navigationBarTheme(),
      switchTheme: _switchTheme(),
      sliderTheme: _sliderTheme(),
      checkboxTheme: _checkboxTheme(),
      radioTheme: _radioTheme(),
      progressIndicatorTheme: _progressTheme(),
      chipTheme: _chipTheme(),
      listTileTheme: _listTileTheme(),
      popupMenuTheme: _popupMenuTheme(),
      tooltipTheme: _tooltipTheme(),
      scrollbarTheme: _scrollbarTheme(),
      tabBarTheme: _tabBarTheme(),
      floatingActionButtonTheme: _fabTheme(),
      segmentedButtonTheme: _segmentedTheme(),

      extensions: const <ThemeExtension<dynamic>>[MiuiThemeExtension()],
    );
  }

  /// 让整个子树获得 Miuix 的弹性滚动手感。
  static ScrollBehavior scrollBehavior(Widget? child) =>
      const MiuiScrollBehavior();

  // ==========================================================================
  // 颜色方案
  // ==========================================================================
  static ColorScheme _colorScheme() => const ColorScheme.dark(
        primary: MiuiColors.primary,
        onPrimary: MiuiColors.onPrimary,
        primaryContainer: MiuiColors.primaryContainer,
        onPrimaryContainer: MiuiColors.onPrimaryContainer,
        secondary: MiuiColors.secondary,
        onSecondary: MiuiColors.onSecondary,
        secondaryContainer: MiuiColors.secondaryContainer,
        onSecondaryContainer: MiuiColors.onSecondaryContainer,
        tertiary: MiuiColors.primaryVariant,
        onTertiary: MiuiColors.onPrimary,
        tertiaryContainer: MiuiColors.tertiaryContainer,
        onTertiaryContainer: MiuiColors.onTertiaryContainer,
        error: MiuiColors.error,
        onError: MiuiColors.onError,
        errorContainer: MiuiColors.errorContainer,
        onErrorContainer: MiuiColors.onErrorContainer,
        surface: MiuiColors.surface,
        onSurface: MiuiColors.onSurface,
        surfaceContainerHighest: MiuiColors.surfaceContainerHighest,
        onSurfaceVariant: MiuiColors.onSurfaceVariantSummary,
        outline: MiuiColors.outline,
        outlineVariant: MiuiColors.dividerLine,
        surfaceTint: Colors.transparent,
      );

  // ==========================================================================
  // 排版
  // ==========================================================================
  static const TextTheme _miuiTextTheme = TextTheme(
    displayLarge: MiuiType.title1,
    displayMedium: MiuiType.title2,
    displaySmall: MiuiType.title3,
    headlineLarge: MiuiType.title3,
    headlineMedium: MiuiType.title4,
    headlineSmall: MiuiType.headline1,
    titleLarge: MiuiType.headline1,
    titleMedium: MiuiType.headline2,
    titleSmall: MiuiType.body1,
    bodyLarge: MiuiType.body1,
    bodyMedium: MiuiType.body2,
    bodySmall: MiuiType.footnote1,
    labelLarge: MiuiType.button,
    labelMedium: MiuiType.footnote1,
    labelSmall: MiuiType.footnote2,
  );

  // ==========================================================================
  // 组件主题
  // ==========================================================================

  static AppBarTheme _appBarTheme() => const AppBarTheme(
        backgroundColor: MiuiColors.surface,
        foregroundColor: MiuiColors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: MiuiSpace.appBarHeight,
        titleSpacing: MiuiSpace.navIconPadding,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: MiuiColors.onSurface,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: MiuiColors.onSurface, size: 24),
        actionsIconTheme: IconThemeData(color: MiuiColors.onSurface, size: 24),
      );

  /// Miuix Card：16dp 圆角、无阴影、surfaceContainer 底、默认零内边距。
  static CardThemeData _cardTheme() => const CardThemeData(
        color: MiuiColors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.card)),
        ),
      );

  /// Miuix Dialog：32dp 圆角，大屏居中缩放淡入，小屏底部滑入。
  static DialogThemeData _dialogTheme() => const DialogThemeData(
        backgroundColor: MiuiColors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.dialog)),
        ),
        // 大屏居中时四边留白
        insetPadding: EdgeInsets.symmetric(
          horizontal: 40,
          vertical: 24,
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: MiuiColors.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: 16,
          color: MiuiColors.onSurfaceSecondary,
        ),
      );

  static BottomSheetThemeData _bottomSheetTheme() => const BottomSheetThemeData(
        backgroundColor: MiuiColors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: MiuiColors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MiuiRadius.dialog),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: MiuiColors.outline,
      );

  /// Miuix Snackbar：16dp 圆角、反色容器。
  static SnackBarThemeData _snackBarTheme() => const SnackBarThemeData(
        backgroundColor: MiuiColors.onSecondaryVariant,
        contentTextStyle: TextStyle(
          fontSize: 15,
          color: MiuiColors.background,
        ),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.card)),
        ),
        insetPadding: EdgeInsets.all(MiuiSpace.snackbarMargin),
      );

  /// Miuix Button：16dp 圆角、58×40 最小尺寸、默认中性底（非主色）。
  static ElevatedButtonThemeData _elevatedButtonTheme() =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MiuiColors.primary,
          foregroundColor: MiuiColors.onPrimary,
          disabledBackgroundColor: MiuiColors.disabledPrimaryButton,
          disabledForegroundColor: MiuiColors.disabledOnPrimaryButton,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          minimumSize: const Size(
            MiuiSpace.buttonMinWidth,
            MiuiSpace.buttonMinHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          textStyle: MiuiType.button,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.button)),
          ),
        ),
      );

  static FilledButtonThemeData _filledButtonTheme() => FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MiuiColors.secondaryVariant,
          foregroundColor: MiuiColors.onSecondaryVariant,
          disabledBackgroundColor: MiuiColors.disabledSecondary,
          disabledForegroundColor: MiuiColors.disabledOnSecondary,
          elevation: 0,
          minimumSize: const Size(
            MiuiSpace.buttonMinWidth,
            MiuiSpace.buttonMinHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          textStyle: MiuiType.button,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.button)),
          ),
        ),
      );

  static TextButtonThemeData _textButtonTheme() => TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MiuiColors.primaryVariant,
          disabledForegroundColor: MiuiColors.disabledOnPrimary,
          minimumSize: const Size(
            MiuiSpace.buttonMinWidth,
            MiuiSpace.buttonMinHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          textStyle: MiuiType.button,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.button)),
          ),
        ),
      );

  static OutlinedButtonThemeData _outlinedButtonTheme() =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MiuiColors.onSurface,
          disabledForegroundColor: MiuiColors.disabledOnSurface,
          side: const BorderSide(color: MiuiColors.outline),
          elevation: 0,
          minimumSize: const Size(
            MiuiSpace.buttonMinWidth,
            MiuiSpace.buttonMinHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          textStyle: MiuiType.button,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.button)),
          ),
        ),
      );

  static IconButtonThemeData _iconButtonTheme() => IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: MiuiColors.onSurface,
          disabledForegroundColor: MiuiColors.disabledOnSurface,
          minimumSize: const Size(
            MiuiSpace.iconButtonSize,
            MiuiSpace.iconButtonSize,
          ),
          iconSize: 22,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(MiuiRadius.iconButton),
            ),
          ),
        ),
      );

  /// Miuix TextField：实心填充、16dp 圆角、聚焦时 2dp 主色描边、无下划线。
  static InputDecorationTheme _inputDecorationTheme() =>
      const InputDecorationTheme(
        filled: true,
        fillColor: MiuiColors.surfaceContainerHigh,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: MiuiColors.onSurfaceVariantSummary),
        labelStyle: TextStyle(color: MiuiColors.onSurfaceVariantSummary),
        floatingLabelStyle: TextStyle(color: MiuiColors.primaryVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.field)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.field)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.field)),
          borderSide: BorderSide(color: MiuiColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.field)),
          borderSide: BorderSide(color: MiuiColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.field)),
          borderSide: BorderSide(color: MiuiColors.error, width: 2),
        ),
      );

  /// 选中态靠 alpha 差异 + 字重，无指示器胶囊。
  static BottomNavigationBarThemeData _bottomNavTheme() =>
      const BottomNavigationBarThemeData(
        backgroundColor: MiuiColors.surface,
        selectedItemColor: MiuiColors.primaryVariant,
        unselectedItemColor: MiuiColors.onSurfaceVariantActions,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontSize: MiuiSpace.navBarFontSize,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: MiuiSpace.navBarFontSize,
          fontWeight: FontWeight.normal,
        ),
      );

  static NavigationBarThemeData _navigationBarTheme() =>
      const NavigationBarThemeData(
        backgroundColor: MiuiColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: MiuiSpace.navBarHeight,
        indicatorColor: Colors.transparent,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.card)),
        ),
        labelTextStyle: WidgetStatePropertyAll(MiuiType.navLabel),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: MiuiColors.onSurfaceVariantActions, size: 26),
        ),
      );

  /// Miuix Switch：49×28 胶囊，金色轨道，20dp 圆形滑块。
  static SwitchThemeData _switchTheme() => SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return MiuiColors.disabledOnPrimaryButton;
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return MiuiColors.disabledPrimaryButton;
          }
          if (states.contains(WidgetState.selected)) {
            return MiuiColors.primary;
          }
          return MiuiColors.secondary;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      );

  /// Miuix Slider：28dp 高全圆轨道，金色前景。
  static SliderThemeData _sliderTheme() => const SliderThemeData(
        activeTrackColor: MiuiColors.primary,
        inactiveTrackColor: MiuiColors.sliderBackground,
        thumbColor: Colors.white,
        overlayColor: Colors.transparent,
        trackHeight: MiuiSpace.linearProgressHeight,
        valueIndicatorColor: MiuiColors.surfaceContainerHighest,
        valueIndicatorTextStyle: TextStyle(
          fontSize: 13,
          color: MiuiColors.onSurfaceContainerHighest,
        ),
      );

  static CheckboxThemeData _checkboxTheme() => CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return MiuiColors.disabledPrimaryButton;
          }
          if (states.contains(WidgetState.selected)) return MiuiColors.primary;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(MiuiColors.onPrimary),
        side: const BorderSide(color: MiuiColors.outline, width: 2),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MiuiRadius.small),
        ),
      );

  static RadioThemeData _radioTheme() => RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return MiuiColors.disabledOnPrimary;
          }
          if (states.contains(WidgetState.selected)) return MiuiColors.primary;
          return MiuiColors.onSurfaceVariantSummary;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      );

  static ProgressIndicatorThemeData _progressTheme() =>
      const ProgressIndicatorThemeData(
        color: MiuiColors.primary,
        linearTrackColor: MiuiColors.sliderBackground,
        circularTrackColor: Colors.transparent,
        linearMinHeight: MiuiSpace.linearProgressHeight,
      );

  static ChipThemeData _chipTheme() => const ChipThemeData(
        backgroundColor: MiuiColors.surfaceContainerHigh,
        selectedColor: MiuiColors.tertiaryContainer,
        disabledColor: MiuiColors.disabledSecondary,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.pill)),
        ),
        labelStyle: TextStyle(fontSize: 14, color: MiuiColors.onSurface),
        secondaryLabelStyle: TextStyle(
          fontSize: 14,
          color: MiuiColors.onTertiaryContainer,
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      );

  /// Miuix 列表行：56dp 最小高度，16dp 水平内边距。
  static ListTileThemeData _listTileTheme() => const ListTileThemeData(
        minVerticalPadding: 12,
        horizontalTitleGap: 12,
        contentPadding: EdgeInsets.symmetric(horizontal: MiuiSpace.itemPadding),
        iconColor: MiuiColors.primaryVariant,
        textColor: MiuiColors.onSurface,
        titleTextStyle: MiuiType.headline1,
        subtitleTextStyle: MiuiType.body2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.card)),
        ),
      );

  static PopupMenuThemeData _popupMenuTheme() => const PopupMenuThemeData(
        color: MiuiColors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.card)),
        ),
        textStyle: MiuiType.body1,
      );

  static TooltipThemeData _tooltipTheme() => const TooltipThemeData(
        decoration: BoxDecoration(
          color: MiuiColors.surfaceContainerHighest,
          borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.tooltip)),
        ),
        textStyle: TextStyle(fontSize: 13, color: MiuiColors.onSurface),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );

  static ScrollbarThemeData _scrollbarTheme() => const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(MiuiColors.outline),
        trackColor: WidgetStatePropertyAll(Colors.transparent),
        thickness: WidgetStatePropertyAll(4),
        radius: Radius.circular(2),
      );

  static TabBarThemeData _tabBarTheme() => const TabBarThemeData(
        labelColor: MiuiColors.primaryVariant,
        unselectedLabelColor: MiuiColors.onSurfaceVariantSummary,
        indicatorColor: MiuiColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 16),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
      );

  static FloatingActionButtonThemeData _fabTheme() =>
      const FloatingActionButtonThemeData(
        backgroundColor: MiuiColors.primary,
        foregroundColor: MiuiColors.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        shape: CircleBorder(),
      );

  static SegmentedButtonThemeData _segmentedTheme() =>
      SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: MiuiColors.surfaceContainerHigh,
          foregroundColor: MiuiColors.onSurfaceSecondary,
          selectedBackgroundColor: MiuiColors.tertiaryContainer,
          selectedForegroundColor: MiuiColors.onTertiaryContainer,
          elevation: 0,
          side: BorderSide.none,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(MiuiRadius.tab)),
          ),
          textStyle: MiuiType.body1,
        ),
      );
}

/// 主题扩展：让业务代码可以 `MiuiThemeExtension.of(context)` 取到 token。
///
/// 目前 token 都是编译期常量（MiuiColors / MiuiSpace / MiuiRadius 均为 static const），
/// 直接引用即可；这个扩展存在的意义是让未来要做亮/暗双主题或动态取色时，
/// 组件层无需改动就能切换。
class MiuiThemeExtension extends ThemeExtension<MiuiThemeExtension> {
  const MiuiThemeExtension();

  static const MiuiThemeExtension instance = MiuiThemeExtension();

  static MiuiThemeExtension of(BuildContext context) {
    return Theme.of(context).extension<MiuiThemeExtension>() ?? instance;
  }

  @override
  MiuiThemeExtension copyWith() => this;

  @override
  MiuiThemeExtension lerp(ThemeExtension<MiuiThemeExtension>? other, double t) =>
      this;
}

/// Miuix 的滚动手感：全局弹性回弹 + 隐藏默认滚动条发光。
class MiuiScrollBehavior extends ScrollBehavior {
  const MiuiScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // HyperOS 用弹性回弹而非 Material 的发光指示器
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

/// 便捷入口：给整个 App 套上 Miuix 滚动行为。
class MiuiScrollConfiguration extends StatelessWidget {
  const MiuiScrollConfiguration({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const MiuiScrollBehavior(),
      child: child,
    );
  }
}
