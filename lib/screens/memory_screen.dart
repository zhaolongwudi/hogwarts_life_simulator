import 'package:flutter/material.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  int _tab = 0;
  int _sortMode = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('你的回忆'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('导出功能即将上线')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabs(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerTheme.color!.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildTabItem('回忆', 0),
          _buildTabItem('收藏', 1),
          _buildTabItem('CG画廊', 2),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, int index) {
    final isActive = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : Theme.of(context).textTheme.bodyMedium!.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_tab == 0) return _buildChaptersView();
    if (_tab == 1) return _buildFavoritesView();
    return _buildCgGallery();
  }

  Widget _buildChaptersView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('章节目录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              _buildSortChip('按时间', 0),
              const SizedBox(width: 8),
              _buildSortChip('最新更新', 1),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Text('导出', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13)),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildChapterCard(1, '第1年·9月', '主线', true),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '—— 全文完 ——',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium!.color,
                fontSize: 13,
                letterSpacing: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, int mode) {
    final isActive = _sortMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _sortMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerTheme.color!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Theme.of(context).textTheme.bodyMedium!.color,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildChapterCard(int number, String title, String subtitle, bool isLatest) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    if (isLatest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('最新', style: TextStyle(fontSize: 10, color: Colors.red)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium!.color)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Theme.of(context).textTheme.bodyMedium!.color),
        ],
      ),
    );
  }

  Widget _buildFavoritesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_outline, size: 64, color: Theme.of(context).textTheme.bodyMedium!.color),
          const SizedBox(height: 12),
          Text('暂无收藏', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color)),
        ],
      ),
    );
  }

  Widget _buildCgGallery() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_search, size: 64, color: Theme.of(context).textTheme.bodyMedium!.color),
          const SizedBox(height: 12),
          Text('暂无CG', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color)),
          const SizedBox(height: 4),
          Text('在游戏中解锁更多CG插画', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
        ],
      ),
    );
  }
}
