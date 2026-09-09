// Q12：设置页 SenseNova 模型配额标注（1500/500 次每 5 小时）。
//
// 修复前：配额数字只存在于代码注释里，玩家从 UI 上无法得知
// sensenova 系列（1500 次/5h）与 deepseek-v4-flash / glm-5.2（500 次/5h）
// 的天花板差异，误选托管模型后约 1.67 次/分钟即触发限流。
// 修复后：模型预设 chip 直接标注配额，且数字取自限流闸门
// SenseNovaQuotaManager.quotaForModel（单一数据源，杜绝第二份抄写）。
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/screens/settings/settings_provider_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SettingsProviderCard _card(AiProvider p) {
    return SettingsProviderCard(
      provider: p,
      appProvider: AppProvider(),
      keyController: TextEditingController(),
      modelController: TextEditingController(),
      testing: false,
    );
  }

  Future<void> _pump(WidgetTester tester, AiProvider p) async {
    // 卡片展开态较高，放进滚动容器避免测试面（800x600）内溢出
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: _card(p)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('SenseNova 免费模型 chip 标注 1500次/5h 与 500次/5h', (tester) async {
    await _pump(tester, AiProvider.sensenova);

    // 自研模型 1500 次/5h
    expect(
      find.textContaining('sensenova-6.8-flash-lite  1500次/5h'),
      findsOneWidget,
    );
    expect(
      find.textContaining('sensenova-6.7-flash-lite  1500次/5h'),
      findsOneWidget,
    );
    // 托管模型 500 次/5h
    expect(find.textContaining('deepseek-v4-flash  500次/5h'), findsOneWidget);
    expect(find.textContaining('glm-5.2  500次/5h'), findsOneWidget);
  });

  testWidgets('DeepSeek 提供商不出现配额标注（按量计费无限流）', (tester) async {
    await _pump(tester, AiProvider.deepseek);
    expect(find.textContaining('次/5h'), findsNothing);
  });

  testWidgets('Agnes 提供商不出现 5h 配额标注（20 RPM 维度）', (tester) async {
    await _pump(tester, AiProvider.agnes);
    expect(find.textContaining('次/5h'), findsNothing);
  });
}
