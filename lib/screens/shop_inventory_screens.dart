import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _tab = 0;
  final _depositCtrl = TextEditingController();
  final _withdrawCtrl = TextEditingController();

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
  void dispose() {
    _depositCtrl.dispose();
    _withdrawCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(_tab == 2 ? '古灵阁·魔法银行' : '魔法商店')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _buildTabButton('淘货', 0, Icons.shopping_cart)),
                const SizedBox(width: 10),
                Expanded(child: _buildTabButton('卖闲置', 1, Icons.sell)),
                const SizedBox(width: 10),
                Expanded(child: _buildTabButton('古灵阁', 2, Icons.account_balance)),
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
            child: _tab == 2
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
                          Icon(Icons.vault, color: Colors.amber.shade700),
                          const SizedBox(width: 8),
                          const Text('金库存款', style: TextStyle(fontSize: 13)),
                          const Spacer(),
                          Text('${gp.player?.bankGalleons ?? 0}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
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
          Expanded(
            child: _tab == 2 ? _buildBankPanel(context, gp) : (_tab == 0 ? _buildShopGrid(_items, true) : _buildShopGrid(_sellItems, false)),
          ),
        ],
      ),
    );
  }

  Widget _buildBankPanel(BuildContext context, GameProvider gp) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('🏛 古灵阁巫师银行', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 6),
                Text('由妖精运营的千年银行。存款无利息，但绝对安全——没有人敢抢古灵阁。',
                    style: TextStyle(fontSize: 12, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildBankAction(
            context: context,
            title: '存入加隆',
            subtitle: '从随身钱包转入金库',
            icon: Icons.arrow_upward,
            color: Colors.green,
            controller: _depositCtrl,
            hint: '存入数量',
            onConfirm: (amount) {
              final ok = gp.depositToBank(amount);
              return ok ? '✅ 已存入 $amount 加隆。当前金库：${gp.player?.bankGalleons ?? 0}' : '❌ 存入失败：随身加隆不足。';
            },
          ),
          const SizedBox(height: 16),
          _buildBankAction(
            context: context,
            title: '取出加隆',
            subtitle: '从金库转回随身钱包',
            icon: Icons.arrow_downward,
            color: Colors.orange,
            controller: _withdrawCtrl,
            hint: '取出数量',
            onConfirm: (amount) {
              final ok = gp.withdrawFromBank(amount);
              return ok ? '✅ 已取出 $amount 加隆。当前钱包：${gp.player?.galleons ?? 0}' : '❌ 取出失败：金库余额不足。';
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBankAction({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    required String hint,
    required String Function(int amount) onConfirm,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium!.color)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hint,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => controller.text = '',
                      icon: const Icon(Icons.clear, size: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                  onPressed: () {
                    final amount = int.tryParse(controller.text.trim()) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入大于 0 的数量')));
                      return;
                    }
                    final msg = onConfirm(amount);
                    controller.clear();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  },
                  child: const Text('确认'),
                ),
              ),
            ],
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                final gp = context.read<GameProvider>();
                if (isBuy) {
                  final price = item['price'] as int? ?? 10;
                  final ok = gp.purchaseItem(item['name'] as String? ?? '未知物品', price);
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

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _filter = '全部';

  IconData _getItemIcon(String type) {
    switch (type.toLowerCase()) {
      case 'food':
      case '食品':
        return Icons.restaurant;
      case 'potion':
      case '药水':
        return Icons.science;
      case 'wand':
      case '武器':
        return Icons.auto_awesome;
      case 'spell':
      case '魔咒':
        return Icons.emoji_symbols;
      case 'material':
      case '材料':
        return Icons.category;
      case 'tool':
      case '工具':
        return Icons.build;
      case 'book':
      case '书籍':
        return Icons.menu_book;
      case 'clothing':
      case '服装':
        return Icons.checkroom;
      default:
        return Icons.inventory_2;
    }
  }

  Color _getItemColor(String type) {
    switch (type.toLowerCase()) {
      case 'food':
      case '食品':
        return Colors.brown;
      case 'potion':
      case '药水':
        return Colors.green;
      case 'wand':
      case '武器':
        return Colors.amber;
      case 'spell':
      case '魔咒':
        return Colors.purple;
      case 'material':
      case '材料':
        return Colors.blue;
      case 'tool':
      case '工具':
        return Colors.orange;
      case 'book':
      case '书籍':
        return Colors.teal;
      case 'clothing':
      case '服装':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _getDynamicItems() {
    final gp = context.read<GameProvider>();
    final inventory = gp.player?.inventory ?? [];
    return inventory.asMap().entries.map((entry) {
      final item = entry.value;
      return {
        'name': item.name,
        'icon': _getItemIcon(item.type),
        'category': item.type,
        'desc': item.description.isNotEmpty ? item.description : item.type,
        'count': 1,
        'color': _getItemColor(item.type),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['全部', '武器', '食品', '文具', '药水', '材料'];
    final items = _getDynamicItems();
    final filtered = _filter == '全部' ? items : items.where((i) => i['category'] == _filter).toList();

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
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Badge(
                    label: Text('${items.length}'),
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
              color: (item['color'] as Color).withValues(alpha: 0.15),
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
