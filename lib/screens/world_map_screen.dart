import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';

class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  String _currentArea = '霍格沃茨';
  final Map<String, List<Map<String, dynamic>>> _mapData = {
    '霍格沃茨': [
      {'name': '大礼堂', 'x': 0.42, 'y': 0.32, 'desc': '霍格沃茨的心脏，分院帽在此分配新生。', 'icon': Icons.castle},
      {'name': '天文台', 'x': 0.65, 'y': 0.18, 'desc': '仰望星空，学习天文学的最佳地点。', 'icon': Icons.auto_awesome},
      {'name': '黑湖', 'x': 0.15, 'y': 0.72, 'desc': '湖中住着神秘的生物，夜间请勿靠近。', 'icon': Icons.waves},
      {'name': '禁林', 'x': 0.82, 'y': 0.65, 'desc': '禁区深处有许多未知的生物和秘密。', 'icon': Icons.park},
      {'name': '地下室', 'x': 0.35, 'y': 0.75, 'desc': '斯莱特林学院的公共休息室所在地。', 'icon': Icons.business},
      {'name': '图书馆', 'x': 0.28, 'y': 0.45, 'desc': '霍格沃茨最大的知识宝库。', 'icon': Icons.menu_book},
    ],
    '霍格莫德村': [
      {'name': '蜂蜜公爵糖果店', 'x': 0.38, 'y': 0.48, 'desc': '霍格沃茨学生最爱！出售比比多味豆、巧克力蛙等魔法糖果。', 'icon': Icons.cake},
      {'name': '帕笛芙夫人茶馆', 'x': 0.28, 'y': 0.35, 'desc': '温馨的小茶馆，适合约会和闲聊。', 'icon': Icons.coffee},
      {'name': '佐科笑话店', 'x': 0.18, 'y': 0.45, 'desc': '出售各种恶作剧道具和魔法笑话。', 'icon': Icons.sentiment_satisfied},
      {'name': '德维斯和班斯商店', 'x': 0.55, 'y': 0.32, 'desc': '日常魔法用品商店。', 'icon': Icons.shopping_bag},
      {'name': '文人居羽毛笔店', 'x': 0.28, 'y': 0.6, 'desc': '最好的羽毛笔和墨水。', 'icon': Icons.edit},
      {'name': '三把扫帚酒吧', 'x': 0.65, 'y': 0.5, 'desc': '霍格莫德村最受欢迎的酒吧。', 'icon': Icons.local_cafe},
      {'name': '猪头酒吧', 'x': 0.42, 'y': 0.68, 'desc': '环境简陋但有故事的酒吧。', 'icon': Icons.restaurant},
      {'name': '霍格莫德车站', 'x': 0.82, 'y': 0.65, 'desc': '乘坐霍格沃茨特快的地方。', 'icon': Icons.train},
      {'name': '霍格莫德邮局', 'x': 0.58, 'y': 0.72, 'desc': '发送和接收猫头鹰邮递。', 'icon': Icons.mail},
      {'name': '尖叫棚屋', 'x': 0.78, 'y': 0.4, 'desc': '传说中闹鬼的小屋。', 'icon': Icons.hotel},
      {'name': '风雅牌巫师服装店', 'x': 0.1, 'y': 0.65, 'desc': '购买巫师袍和节日服装。', 'icon': Icons.checkroom},
    ],
  };

  String? _selectedLocation;

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final player = gp.player;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(player, gp),
          Expanded(
            child: Stack(
              children: [
                _buildMapBackground(),
                _buildLocationMarkers(),
                _buildNavigationBar(),
                if (_selectedLocation != null) _buildLocationCard(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader(player, gp) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerTheme.color!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          player?.name ?? '旅人',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${player?.house ?? '未知'} · ${player?.bloodType == 'pureblood' ? '纯血' : player?.bloodType == 'halfblood' ? '混血' : '麻瓜'}',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.bolt, size: 12, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 2),
                        Text('体力 ${player?.energy ?? 5}/5', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 12),
                        Icon(Icons.schedule, size: 12, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 2),
                        Text('第${_currentYear()}年·${_currentMonth()}', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 12),
                        Icon(Icons.location_on, size: 12, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 2),
                        Text(gp.worldState.currentLocation ?? '未知', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerTheme.color!.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.keyboard_arrow_up, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAttributeBars(player),
        ],
      ),
    );
  }

  int _currentYear() {
    final gp = context.read<GameProvider>();
    final yearStr = gp.worldState.academicYear;
    try {
      return int.parse(yearStr.split('-')[0]) - 1991 + 1;
    } catch (_) {
      return 1;
    }
  }

  String _currentMonth() {
    final gp = context.read<GameProvider>();
    final months = ['9月', '10月', '11月', '12月', '1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月'];
    final m = gp.worldState.time.month;
    if (m >= 1 && m <= 12) return months[m - 1];
    return '9月';
  }

  Widget _buildAttributeBars(player) {
    final attrs = [
      {'label': '容貌', 'value': 80, 'icon': Icons.face, 'color': Color(0xFFD97706)},
      {'label': '体质', 'value': player?.attributes['constitution'] ?? 50, 'icon': Icons.favorite, 'color': Color(0xFFDC2626)},
      {'label': '智力', 'value': player?.attributes['intelligence'] ?? 50, 'icon': Icons.psychology, 'color': Color(0xFF2563EB)},
      {'label': '魅力', 'value': player?.attributes['charisma'] ?? 50, 'icon': Icons.favorite_border, 'color': Color(0xFFDB2777)},
      {'label': '体能', 'value': player?.attributes['strength'] ?? 50, 'icon': Icons.fitness_center, 'color': Color(0xFF059669)},
      {'label': '道德值', 'value': 50, 'icon': Icons.verified, 'color': Color(0xFF7C3AED)},
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildAttrBar(attrs[0])),
            const SizedBox(width: 8),
            Expanded(child: _buildAttrBar(attrs[1])),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: attrs.sublist(2).map((a) => _buildAttrChip(a)).toList(),
        ),
      ],
    );
  }

  Widget _buildAttrBar(Map<String, dynamic> attr) {
    final value = attr['value'] as int;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerTheme.color!.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(attr['icon'] as IconData, size: 14, color: attr['color'] as Color),
              const SizedBox(width: 4),
              Text(attr['label'] as String, style: const TextStyle(fontSize: 12)),
              const Spacer(),
              Text('$value', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: (attr['color'] as Color).withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(attr['color'] as Color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttrChip(Map<String, dynamic> attr) {
    final value = attr['value'] as int;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerTheme.color!.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(attr['icon'] as IconData, size: 14, color: attr['color'] as Color),
          const SizedBox(width: 4),
          Text('${attr['label']} $value', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMapBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF87CEEB).withOpacity(0.6),
            Color(0xFF90EE90).withOpacity(0.3),
            Color(0xFF228B22).withOpacity(0.4),
          ],
        ),
      ),
      child: CustomPaint(
        painter: MapPainter(),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildLocationMarkers() {
    final locations = _mapData[_currentArea] ?? [];
    return Stack(
      children: locations.map((loc) {
        final x = loc['x'] as double;
        final y = loc['y'] as double;
        final isSelected = _selectedLocation == loc['name'];
        return Positioned(
          left: MediaQuery.of(context).size.width * x - 20,
          top: MediaQuery.of(context).size.height * y - 30,
          child: GestureDetector(
            onTap: () => setState(() => _selectedLocation = loc['name']),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_right, size: 12, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
                      const SizedBox(width: 2),
                      Text(
                        loc['name'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    loc['icon'] as IconData,
                    size: 14,
                    color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNavigationBar() {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerTheme.color!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                final keys = _mapData.keys.toList();
                final idx = keys.indexOf(_currentArea);
                if (idx > 0) setState(() => _currentArea = keys[idx - 1]);
              },
              child: const Icon(Icons.chevron_left, size: 20),
            ),
            const SizedBox(width: 8),
            Text(_currentArea, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final keys = _mapData.keys.toList();
                final idx = keys.indexOf(_currentArea);
                if (idx < keys.length - 1) setState(() => _currentArea = keys[idx + 1]);
              },
              child: const Icon(Icons.chevron_right, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final loc = (_mapData[_currentArea] ?? []).firstWhere(
      (l) => l['name'] == _selectedLocation,
      orElse: () => {},
    );
    if (loc.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 16,
      right: 16,
      bottom: 140,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.97),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerTheme.color!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(loc['icon'] as IconData, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc['name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(loc['desc'] as String, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium!.color)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedLocation = null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerTheme.color!),
                    ),
                    child: const Text('直接前往或输入想去此地做的事',
                        style: TextStyle(fontSize: 13), textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onPressed: () {
                      context.read<GameProvider>().travelTo(loc['name'] as String);
                      Navigator.pop(context);
                    },
                    child: const Text('直接前往', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerTheme.color!)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(Icons.menu_book, '剧情', false),
            _buildBottomNavItem(Icons.phone_android, '手机', false),
            _buildBottomNavItem(Icons.public, '世界', true),
            _buildBottomNavItem(Icons.settings, '设置', false),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, bool isActive) {
    final color = isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodyMedium!.color;
    return GestureDetector(
      onTap: () {
        if (label != '世界') Navigator.pop(context);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFF228B22).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(size.width * 0.3, size.height * 0.2)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.1, size.width * 0.7, size.height * 0.15)
      ..lineTo(size.width * 0.75, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.6, size.height * 0.5, size.width * 0.5, size.height * 0.45)
      ..lineTo(size.width * 0.35, size.height * 0.4)
      ..close();
    canvas.drawPath(path1, paint);

    final path2 = Path()
      ..moveTo(size.width * 0.1, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.2, size.height * 0.4, size.width * 0.35, size.height * 0.5)
      ..lineTo(size.width * 0.3, size.height * 0.75)
      ..quadraticBezierTo(size.width * 0.15, size.height * 0.8, size.width * 0.05, size.height * 0.7)
      ..close();
    canvas.drawPath(path2, paint);

    final waterPaint = Paint()
      ..color = Color(0xFF4169E1).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final waterPath = Path()
      ..moveTo(size.width * 0.6, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.55, size.width * 0.85, size.height * 0.65)
      ..lineTo(size.width, size.height * 0.8)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.5, size.height)
      ..close();
    canvas.drawPath(waterPath, waterPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
