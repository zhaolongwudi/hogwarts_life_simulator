/// 共享测试 fixture：`makeGame` 构造真实 GameProvider 实例（不跑 AI、不走网络）。
///
/// 此前 provider_logic / round15 / round16 / round16c 四个测试文件各复制了一份
/// 完全相同的 makeGame，任何参数调整都要同步改 4 处（D1 收口）。
///  - 默认 = 全属性 50 的「测试巫师」；
///  - `offlineQuickMode: true` 额外走本地快速模式（模拟真实回合推进，无 AI key）。
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

/// 构造一份标准测试存档的 GameProvider。
Future<GameProvider> makeGame({bool offlineQuickMode = false}) async {
  // AppProvider.loadSettings 读 SharedPreferences，测试环境需要 mock
  SharedPreferences.setMockInitialValues({});
  final app = AppProvider();
  await app.loadSettings();
  // P10 隔离：奇遇默认开、会随机改写 choices，既有的 1900+ 确定性用例全都不
  // 开它（否则一次随机触发就可能撞坏别处对 choices/叙事的断言）。奇遇专项
  // 用例在各自 fixture 里再 `setHappenstanceEnabled(true)` 打开。
  app.happenstanceEnabled = false;
  // P11 隔离：羁绊小剧场同理由默认开改为测试关，不给既有确定性用例添加
  // 噪音；羁绊专项用例（batch40）在各自 fixture 里再打开。
  app.companionArcEnabled = false;
  final gp = GameProvider(app);
  if (offlineQuickMode) {
    app.setOfflineQuickMode(true); // 无 AI key 也走本地快速模式（模拟真实回合推进）
  }
  await gp.initializeGame(
    name: '测试巫师',
    bloodStatus: '混血',
    birthLocation: '伦敦',
    personalityTraits: const ['勇敢', '善良'],
    gender: '男',
    attributes: const {
      'spell_understanding': 50,
      'transfiguration': 50,
      'potions': 50,
      'herbology': 50,
      'theory': 50,
      'memory': 50,
      'courage': 50,
      'wisdom': 50,
      'loyalty': 50,
      'ambition': 50,
      'social': 50,
      'flying': 50,
      'reaction_time': 50,
    },
    houseDimensions: const {
      'courage': 50,
      'wisdom': 50,
      'loyalty': 50,
      'ambition': 50,
    },
    openingScene: 'letter',
  );
  return gp;
}
