import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';

class _OwnedBadge extends StatelessWidget {
  final String itemName;
  const _OwnedBadge({required this.itemName});

  @override
  Widget build(BuildContext context) {
    final count = context
            .watch<GameProvider>()
            .player
            ?.inventory
            .where((e) => e.name == itemName)
            .length ??
        0;
    if (count <= 0) return const SizedBox.shrink();
    return Text(
      '已拥有 $count',
      style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium!.color),
    );
  }
}

class ShopTab extends StatefulWidget {
  const ShopTab({super.key});

  @override
  State<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<ShopTab> {
  int _subTab = 0; // 0=淘货, 1=卖闲置

  final List<Map<String, dynamic>> _items = [
    {'name': '巧克力蛙', 'icon': Icons.cookie, 'type': '食品', 'desc': '会跳的巧克力，附赠著名巫师卡片', 'price': 10},
    {'name': '酸味爆弹', 'icon': Icons.local_drink, 'type': '食品', 'desc': '真的很酸，慎入', 'price': 8},
    {'name': '坩埚蛋糕', 'icon': Icons.cake, 'type': '食品', 'desc': '迷你坩埚造型，味道不错', 'price': 12},
    {'name': '新羽毛笔', 'icon': Icons.edit, 'type': '文具', 'desc': '猫头鹰羽毛，书写流畅', 'price': 20},
    {'name': '羊皮纸一包', 'icon': Icons.description, 'type': '文具', 'desc': '优质防泼溅羊皮纸 20 张', 'price': 25},
    {'name': '标准咒语书', 'icon': Icons.menu_book, 'type': '书籍', 'desc': '一年级课程教材', 'price': 60},
  ];

  List<Map<String, dynamic>> _sellItems() {
    final gp = context.read<GameProvider>();
    final inventory = gp.player?.inventory ?? [];
    final sellCatalog = {for (final i in _items) i['name'] as String: (i['price'] as int) ~/ 2};
    return inventory.map((item) {
      final basePrice = sellCatalog[item.name] ?? 5;
      return {
        'name': item.name,
        'icon': Icons.sell,
        'desc': item.description.isNotEmpty ? item.description : '可出售换取加隆',
        'price': basePrice,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<GameProvider>(); // 监听GameProvider变化以触发UI重建
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _buildTabButton(
                  '淘货',
                  0,
                  Icons.shopping_cart,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTabButton(
                  '卖闲置',
                  1,
                  Icons.sell,
                  Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _subTab == 0 ? _buildShopGrid(_items, true) : _buildShopGrid(_sellItems(), false),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon, Color activeColor) {
    final isActive = _subTab == index;
    return GestureDetector(
      onTap: () => setState(() => _subTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Theme.of(context).scaffoldBackgroundColor,
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

  Widget _buildShopGrid(List<Map<String, dynamic>> items, bool isBuy) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildItemCard(items[index], isBuy),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, bool isBuy) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item['icon'] as IconData, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            item['desc'] as String,
            style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium!.color),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerTheme.color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${item['price']}加隆', style: const TextStyle(fontSize: 12)),
              ),
              const Spacer(),
              if (isBuy)
                _OwnedBadge(itemName: item['name'] as String? ?? ''),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                backgroundColor: isBuy ? Theme.of(context).colorScheme.primary : Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final gp = context.read<GameProvider>();
                if (isBuy) {
                  final price = item['price'] as int? ?? 10;
                  final ok = gp.purchaseItem(
                    item['name'] as String? ?? '未知物品',
                    price,
                    type: item['type'] as String? ?? 'item',
                    description: item['desc'] as String? ?? '',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? '已购买 ${item['name']} (花费 $price 加隆)' : '加隆不足！需要 $price 加隆')),
                  );
                } else {
                  final price = item['price'] as int? ?? 5;
                  final invIndex = gp.player?.inventory.indexWhere((e) => e.name == item['name']) ?? -1;
                  if (invIndex >= 0) {
                    gp.sellItem(invIndex, price);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已出售 ${item['name']} (获得 $price 加隆)')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('背包中没有此物品')),
                    );
                  }
                }
              },
              child: Text(isBuy ? '+ 买入' : '出售', style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
