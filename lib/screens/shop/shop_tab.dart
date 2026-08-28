import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../data/item_data.dart';
import 'inventory_screen.dart';

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
  /// 交易防抖：purchaseItem / sellItem 都会立刻扣钱加物并落盘，
  /// 连点两下会重复成交（钱扣双份、物品加双份）。
  bool _trading = false;

  Future<T?> _guarded<T>(Future<T> Function() action) async {
    if (_trading) return null;
    if (mounted) setState(() => _trading = true);
    try {
      return await action();
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) setState(() => _trading = false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
  int _subTab = 0; // 0=淘货, 1=卖闲置

  IconData _iconFor(ItemDef def) {
    switch (def.type) {
      case '食品':
        return def.name == '黄油啤酒' || def.name == '比比多味豆'
            ? Icons.local_cafe
            : Icons.cookie;
      case '药水':
        return Icons.science;
      case '装备':
        switch (def.equipSlot) {
          case 'broom':
            return Icons.airline_seat_recline_normal;
          case 'hat':
            return Icons.workspace_premium;
          case 'amulet':
            return Icons.diamond;
          default:
            return Icons.checkroom;
        }
      case '材料':
        return Icons.grass;
      case '书籍':
        return Icons.menu_book;
      case '文具':
        return Icons.edit;
      case '礼物':
        return Icons.card_giftcard;
      default:
        return Icons.inventory_2;
    }
  }

  List<Map<String, dynamic>> _catalog() {
    return kItemCatalog.map((def) {
      return {
        'name': def.name,
        'icon': _iconFor(def),
        'type': def.type,
        'desc': def.desc,
        'price': def.price,
        'usable': def.usable,
        'equippable': def.isEquippable,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _sellItems() {
    final gp = context.read<GameProvider>();
    final inventory = gp.player?.inventory ?? [];
    final sellCatalog = {for (final d in kItemCatalog) d.name: d.price ~/ 2};
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
          child: _subTab == 0 ? _buildShopGrid(_catalog(), true) : _buildShopGrid(_sellItems(), false),
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
              if (isBuy) ...[
                if (item['usable'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('可用', style: TextStyle(fontSize: 10, color: Colors.orange)),
                  ),
                if (item['equippable'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('可装备', style: TextStyle(fontSize: 10, color: Colors.teal)),
                  ),
                const SizedBox(width: 4),
                _OwnedBadge(itemName: item['name'] as String? ?? ''),
              ],
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
              onPressed: _trading
                  ? null
                  : () async {
                final gp = context.read<GameProvider>();
                if (isBuy) {
                  final price = item['price'] as int? ?? 10;
                  final ok = await _guarded(
                        () async => gp.purchaseItem(
                          item['name'] as String? ?? '未知物品',
                          price,
                          type: item['type'] as String? ?? 'item',
                          description: item['desc'] as String? ?? '',
                        ),
                      ) ??
                      false;
                  if (!context.mounted) return;
                  final isUsable = item['usable'] == true || item['equippable'] == true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? '已购买 ${item['name']} (花费 $price 加隆)' : '加隆不足！需要 $price 加隆'),
                      duration: const Duration(seconds: 3),
                      action: ok && isUsable
                          ? SnackBarAction(
                              label: '去使用',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const InventoryScreen()),
                                );
                              },
                            )
                          : null,
                    ),
                  );
                } else {
                  final price = item['price'] as int? ?? 5;
                  final invIndex = gp.player?.inventory.indexWhere((e) => e.name == item['name']) ?? -1;
                  if (invIndex >= 0) {
                    await _guarded(() async => gp.sellItem(invIndex, price));
                    if (!context.mounted) return;
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
