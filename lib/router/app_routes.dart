/// 命名路由单一事实源（F28/F29 收口）。
///
/// 历史问题：
///  1. 路由表散落在 main.dart 内联 `routes:`，页面文件里却用裸字符串
///     `pushNamed('/game')` —— 表与调用各写一份，改一边漏一边；
///  2. game_phone_tab 曾用 `/world_map`、`/save_load` 两个**幽灵路由**：
///     表里没有定义，真点进去会走 onUnknownRoute 抛错。
/// 收口后：
///  - 路由名是编译期常量（拼错直接编译失败）；
///  - 表只放真正需要命名的页面（低频页面直接 pushRoute 构造，见 ui_helpers）；
///  - main.dart 只引用这里，不再自建表。
library;

import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../screens/intro_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/game_screen.dart';

/// 命名路由常量：唯一写字符串的地方。
abstract final class AppRoutes {
  static const home = '/';
  static const intro = '/intro';
  static const settings = '/settings';
  static const game = '/game';
}

/// 命名路由表：main.dart 的 `routes:` 直接引用这里。
const Map<String, WidgetBuilder> appRoutes = <String, WidgetBuilder>{
  AppRoutes.home: (_) => const HomePage(),
  AppRoutes.intro: (_) => const IntroScreen(),
  AppRoutes.settings: (_) => const SettingsScreen(),
  AppRoutes.game: (_) => const GameScreen(),
};
