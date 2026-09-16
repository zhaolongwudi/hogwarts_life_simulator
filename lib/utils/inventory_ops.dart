import '../models/player.dart';

/// 背包增删的共享实现。
///
/// 此前 mixin_play 里有一份 _hasItem / _removeItem，mixin_relations 里的
/// 送礼逻辑要消耗物品时只能再写一遍 indexWhere。跨 mixin 文件访问受限，
/// 所以下沉成顶层函数，两个 mixin 共用同一份。
InventoryItem? findInInventory(List<InventoryItem> inventory, String name) {
  for (final item in inventory) {
    if (item.name == name) return item;
  }
  return null;
}

bool hasItem(List<InventoryItem> inventory, String name) =>
    findInInventory(inventory, name) != null;
/// 消耗一件，成功返回 true。
bool removeOneItem(List<InventoryItem> inventory, String name) {
  final idx = inventory.indexWhere((e) => e.name == name);
  if (idx < 0) return false;
  inventory.removeAt(idx);
  return true;
}
