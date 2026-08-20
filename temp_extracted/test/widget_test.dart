import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hogwarts_life_simulator/main.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    final app = AppProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: app),
          ChangeNotifierProvider<GameProvider>(
            create: (_) => GameProvider(app),
          ),
        ],
        child: const HogwartsLifeSimulator(),
      ),
    );

    expect(find.text('魔法人生模拟器'), findsOneWidget);
    expect(find.text('开始新人生'), findsOneWidget);
  });
}
