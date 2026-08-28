import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../data/pet_data.dart';

/// 「咿啦猫头鹰商店」的在售宠物。
///
/// 购买逻辑在 GamePlayMixin.buyPet（数据见 pet_data.dart 的 kPetPrices）。
/// 之前只有 /宠物 购买 这一条命令行入口，商店界面里翻遍了也找不到宠物，
/// 等于这个功能对用 UI 的玩家不存在。
class PetShopTab extends StatelessWidget {
  const PetShopTab({super.key});

  IconData _iconFor(String id) {
    switch (id) {
      case 'owl':
        return Icons.mail_outline;
      case 'cat':
        return Icons.pets;
      case 'toad':
        return Icons.water_drop;
      case 'rat':
        return Icons.hive;
      default:
        return Icons.pets;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final p = gp.player;
    final galleons = p?.galleons ?? 0;
    final owned = p?.petId;
    final pets = purchasablePets.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            owned != null
                ? '你已经有伙伴了（${p?.petName ?? ''}）。再买一只的话，它会带着所有羁绊离开。'
                : '挑一只陪你过完这七年。买下之后可以用 /宠物 喂食 · 玩耍 · 训练。',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium!.color,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: pets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _buildCard(context, gp, pets[i], galleons, owned),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    GameProvider gp,
    PetDef pet,
    int galleons,
    String? owned,
  ) {
    final price = kPetPrices[pet.id] ?? 0;
    final affordable = galleons >= price;
    final canBuy = owned == null && affordable;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconFor(pet.id), color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(pet.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Text(
                      '${pet.species}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodyMedium!.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  pet.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodyMedium!.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '能力：${pet.abilities.join('、')}',
                  style: const TextStyle(fontSize: 11, color: Colors.teal),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Text('$price', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Text('加隆', style: TextStyle(fontSize: 10)),
              const SizedBox(height: 8),
              SizedBox(
                width: 72,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    backgroundColor: canBuy ? Theme.of(context).colorScheme.primary : null,
                    foregroundColor: canBuy ? Colors.white : null,
                  ),
                  onPressed: canBuy
                      ? () {
                          final msg = gp.buyPet(pet.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
                          );
                        }
                      : null,
                  child: Text(
                    owned != null ? '已有宠物' : (affordable ? '买下' : '钱不够'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
