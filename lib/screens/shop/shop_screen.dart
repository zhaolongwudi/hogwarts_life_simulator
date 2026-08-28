import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import 'shop_tab.dart';
import 'pet_shop_tab.dart';
import 'gringotts_tab.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  // 0=淘货 1=卖闲置 2=宠物 3=古灵阁
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(_tab == 3 ? '古灵阁·魔法银行' : '魔法商店')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _buildTabButton('淘货', 0, Icons.shopping_cart)),
                const SizedBox(width: 8),
                Expanded(child: _buildTabButton('卖闲置', 1, Icons.sell)),
                const SizedBox(width: 8),
                Expanded(child: _buildTabButton('宠物', 2, Icons.pets)),
                const SizedBox(width: 8),
                Expanded(child: _buildTabButton('古灵阁', 3, Icons.account_balance)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerTheme.color!),
            ),
            child: _tab == 3
                ? Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.wallet, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          const Text('随身加隆', style: TextStyle(fontSize: 13)),
                          const Spacer(),
                          Text('${gp.player?.galleons ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.savings, color: Colors.amber.shade700),
                          const SizedBox(width: 8),
                          const Text('金库存款', style: TextStyle(fontSize: 13)),
                          const Spacer(),
                          Text(
                            '${gp.player?.bankGalleons ?? 0}',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(Icons.bolt, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text('加隆余额', style: TextStyle(fontSize: 13)),
                      const Spacer(),
                      Text('${gp.player?.galleons ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: switch (_tab) {
              1 => const ShopTab(sellMode: true),
              2 => const PetShopTab(),
              3 => const GringottsTab(),
              _ => const ShopTab(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
    final isActive = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerTheme.color!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : null),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: isActive ? Colors.white : null)),
          ],
        ),
      ),
    );
  }
}
