import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../data/item_data.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _filter = '全部';
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getItemIcon(String type) {
    switch (type.toLowerCase()) {
      case 'food':
      case '食品':
        return Icons.restaurant;
      case 'potion':
      case '药水':
        return Icons.science;
      case 'wand':
      case '魔杖':
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
      case 'equipment':
      case '装备':
        return Icons.workspace_premium;
      case '道具':
        return Icons.toys;
      case '文具':
        return Icons.edit;
      case '礼物':
        return Icons.card_giftcard;
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
      case '魔杖':
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
      case 'equipment':
      case '装备':
        return Colors.amber;
      case '道具':
        return Colors.deepOrange;
      case '文具':
        return Colors.indigo;
      case '礼物':
        return Colors.pinkAccent;
      default:
        return Colors.grey;
    }
  }

  /// 物品真实类型集合（取自 lib/data/*.dart 里 InventoryItem 的 type 字段）。
  /// 旧分类写的是「武器 / 服装」，但项目里根本没有这两类
  /// （装备统一是「装备」，另有「道具」「文具」），
  /// 结果这两个筛选项点进去永远是空的。
  static const List<String> kItemCategories = [
    '全部',
    '装备',
    '道具',
    '食品',
    '药水',
    '材料',
    '书籍',
    '文具',
    '礼物',
  ];

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
    final items = _getDynamicItems();
    // 只保留背包里真实存在的分类，避免又出现点了没结果的空筛选项
    final present = items.map((i) => i['category'] as String).toSet();
    final categories =
        kItemCategories.where((c) => c == '全部' || present.contains(c)).toList();
    if (!categories.contains(_filter)) _filter = '全部';
    final filtered = items.where((i) {
      if (_filter != '全部' && i['category'] != _filter) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return (i['name'] as String).toLowerCase().contains(q) ||
          (i['desc'] as String).toLowerCase().contains(q);
    }).toList();

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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).dividerTheme.color!),
                    ),
                    // 之前这里是一个写着"搜索物品..."的 Text，纯装饰、点了没反应。
                    // 现在换成真的输入框，按名称/描述/分类过滤。
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '搜索物品...',
                        hintStyle: const TextStyle(fontSize: 13),
                        border: InputBorder.none,
                        icon: const Icon(Icons.search, size: 16),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerTheme.color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('x${item['count']}', style: const TextStyle(fontSize: 10)),
              ),
              const Spacer(),
              if (_actionFor(item['name'] as String) case final String action?)
                GestureDetector(
                  onTap: () {
                    final gp = context.read<GameProvider>();
                    final name = item['name'] as String? ?? '';
                    if (action == '使用') {
                      gp.useItem(name);
                    } else if (action == '装备') {
                      gp.equipItem(name);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已$action「$name」，详情见游戏对话')), 
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      action,
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 返回该物品在背包中可执行的快捷操作：使用/装备；无则 null
  String? _actionFor(String name) {
    final gp = context.read<GameProvider>();
    final def = itemDefByName(name);
    if (def == null) return null;
    if (def.isEquippable) {
      final worn = gp.player?.equipped[def.equipSlot] == name;
      return worn ? null : '装备';
    }
    if (def.usable) return '使用';
    return null;
  }
}
