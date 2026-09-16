/// 剧情页阅读空间优化（UI 审查专项）行为测试
///
/// 纪律沿用第八/九轮：断言守性质（接线真的存在、旧实现真的移除），
/// 不锁像素级布局细节——Flutter 布局在 widget 测试里锁像素只会
/// 换来一批下次改 padding 就假红的用例。
///
/// 覆盖本轮四处改动：
///  1. 阅读模式一键入口（沉浸显示模式原先只藏在设置页深处）
///  2. 场景横幅滚动自动折叠（96px 插图 → 36px 紧凑条，滞回阈值）
///  3. 文本颜色图例学习期后默认收起（前 3 回合强制展开）
///  4. 选项区限高 0.42 → 0.32（长选项内部滚动，不预支正文高度）
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/screens/game/game_narrative_tab.dart').readAsStringSync();

  group('阅读模式入口', () {
    test('剧情页能一键进入沉浸显示模式', () {
      expect(src.contains('DisplayMode.immersive'), isTrue);
      expect(src.contains('setDisplayMode'), isTrue);
      expect(src.contains("import '../../providers/app_provider.dart'"), isTrue);
    });

    test('入口带无障碍语义标签', () {
      expect(src.contains('进入阅读模式'), isTrue);
    });
  });

  group('场景横幅滚动折叠', () {
    test('滚动监听真的注册且成对移除（防泄漏）', () {
      expect(src.contains("widget.scrollController.addListener("), isTrue);
      expect(src.contains("widget.scrollController.removeListener("), isTrue);
      expect(src.contains('hasClients'), isTrue,
          reason: 'subTab 切走时 controller 未挂载，必须先判 hasClients');
    });

    test('滞回阈值：下去 60 才收、回到 20 才放，不在临界点抖动', () {
      expect(src.contains('offset > 60'), isTrue);
      expect(src.contains('offset > 20'), isTrue);
    });

    test('紧凑条保留时间与地点信息（折叠不是丢失）', () {
      expect(src.contains('header_compact'), isTrue);
      expect(src.contains('header_full'), isTrue);
      // 紧凑条里时间戳和地点都还在
      expect(src.contains("timestamp ?? ''"), isTrue);
    });

    test('留位用 AnimatedContainer 平滑跟随，正文区不跳变', () {
      expect(src.contains('AnimatedContainer('), isTrue);
    });
  });

  group('文本颜色图例', () {
    test('前 3 回合强制展开（学习期），之后跟随偏好默认收起', () {
      expect(src.contains('legendCollapsed'), isTrue);
      expect(src.contains('gp.turnCount > 3'), isTrue);
    });

    test('学习期内收起不记偏好（玩家还没看懂不能收）', () {
      expect(src.contains('legendCollapsed && gp.turnCount > 3'), isTrue);
    });
  });

  group('选项区位置', () {
    test('选项跟随正文出现在剧情最下方（不固定占屏、不做内滚）', () {
      expect(src.contains('只出现在正文剧情最下方'), isTrue,
          reason: '选项应处于正文滚动流末尾（滑到底即行动）');
      expect(src.contains('_buildChoiceDock'), isFalse,
          reason: '固定屏底 Dock 方案已移除（会挤压正文阅读区）');
      expect(src.contains('screenH * 0.34'), isFalse,
          reason: '不再按屏高比例给选项预留固定空间');
      expect(src.contains('maxHeight: 1e6'), isTrue,
          reason: '选项自然全展开，不需要「可选行动」面板内二次滚动');
    });
  });
}
