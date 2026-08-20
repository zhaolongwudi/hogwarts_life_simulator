import 'package:flutter/material.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _tab = 0;

  final List<Map<String, dynamic>> _items = [
    {'name': '比比多味豆', 'icon': Icons.cake, 'desc': '什么味道都有，包括你最不喜欢的', 'price': 5, 'owned': 0},
    {'name': '巧克力蛙', 'icon': Icons.person, 'desc': '每张都附一张著名巫师卡片', 'price': 2, 'owned': 3},
    {'name': '黄油啤酒', 'icon': Icons.emoji_food_beverage, 'desc': '霍格莫德村的热门饮品，温热的黄油泡沫', 'price': 3, 'owned': 0},
    {'name': '羽毛笔', 'icon': Icons.edit, 'desc': '提高写作时的魔力控制', 'price': 15, 'owned': 1},
    {'name': '魔药材料包', 'icon': Icons.science, 'desc': '基础魔药课所需的全套材料', 'price': 50, 'owned': 0},
    {'name': '水晶瓶', 'icon': Icons.local_drink, 'desc': '用于存放自制药水', 'price': 8, 'owned': 5},
    {'name': '魔法符咒', 'icon': Icons.emoji_symbols, 'desc': '一次性使用的小型符咒', 'price': 10, 'owned': 2},
    {'name': '活力药剂', 'icon': Icons.local_drink, 'desc': '饮用后恢复5点精力', 'price': 20, 'owned': 0},
  ];

  final List<Map<String, dynamic>> _sellItems = [
    {'name': '旧魔杖', 'icon': Icons.corporate_fare, 'desc': '入门级魔杖，想换新的了', 'price': 30},
    {'name': '二手坩埚', 'icon': Icons.restaurant, 'desc': '有些磨损但还能用', 'price': 15},
    {'name': '多余的羽毛笔', 'icon': Icons.edit, 'desc': '三支中的一支', 'price': 5},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('魔法商店')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton('淘货', 0, Icons.shopping_cart),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTabButton('卖闲置', 1, Icons.sell),
                ),
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
            child: Row(
              children: [
                Icon(Icons.bolt, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('加隆余额', style: TextStyle(fontSize: 13)),
                const Spacer(),
                const Text('50', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: _tab == 0 ? _buildShopGrid(_items, true) : _buildShopGrid(_sellItems, false),
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
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item['icon'] as IconData, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(item['desc'] as String, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium!.color), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerTheme.color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('¥${item['price']}', style: const TextStyle(fontSize: 12)),
              ),
              const Spacer(),
              if (isBuy && item['owned'] != null)
                Text('已拥有 ${item['owned']}', style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium!.color)),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isBuy ? '已购买 ${item['name']}' : '已上架 ${item['name']}')),
                );
              },
              child: Text(isBuy ? '+ 买入' : '出售', style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _filter = '全部';

  final List<Map<String, dynamic>> _items = [
    {'name': '旧魔杖', 'icon': Icons.corporate_fare, 'category': '武器', 'desc': '入门级魔杖', 'count': 1, 'color': Colors.amber},
    {'name': '巧克力蛙', 'icon': Icons.person, 'category': '食品', 'desc': '霍格沃茨最受欢迎的零食', 'count': 3, 'color': Colors.brown},
    {'name': '羽毛笔', 'icon': Icons.edit, 'category': '文具', 'desc': '提升写作体验', 'count': 2, 'color': Colors.blue},
    {'name': '活力药剂', 'icon': Icons.local_drink, 'category': '药水', 'desc': '恢复精力', 'count': 1, 'color': Colors.green},
    {'name': '比比多味豆', 'icon': Icons.cake, 'category': '食品', 'desc': '各种奇怪的味道', 'count': 10, 'color': Colors.pink},
    {'name': '水晶瓶', 'icon': Icons.local_drink, 'category': '材料', 'desc': '存放药水用', 'count': 5, 'color': Colors.purple},
  ];

  @override
  Widget build(BuildContext context) {
    final categories = ['全部', '武器', '食品', '文具', '药水', '材料'];
    final filtered = _filter == '全部' ? _items : _items.where((i) => i['category'] == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('你的背包')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).dividerTheme.color!),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search, size: 16),
                        SizedBox(width: 8),
                        Expanded(child: Text('搜索物品...', style: TextStyle(fontSize: 13))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Badge(
                    label: Text('${_items.length}'),
                    child: Icon(Icons.inventory_2, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((c) {
                  final isSelected = _filter == c;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerTheme.color!,
                        ),
                      ),
                      child: Text(
                        c,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium!.color,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2, size: 64, color: Theme.of(context).textTheme.bodyMedium!.color),
                        const SizedBox(height: 12),
                        Text('暂无物品', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildItemCard(filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (item['color'] as Color).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(item['name'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(item['desc'] as String, style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodyMedium!.color), maxLines: 1, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerTheme.color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('x${item['count']}', style: const TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }
}
