import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';

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
