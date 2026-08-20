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
  String? _selectedLocation;

  final Map<String, List<Map<String, dynamic>>> _mapData = {
    '霍格沃茨': [
      {'name': '天文塔', 'x': 0.62, 'y': 0.12, 'desc': '霍格沃茨最高的塔楼，仰望星空学习天文学。', 'icon': Icons.auto_awesome},
      {'name': '拉文克劳塔', 'x': 0.28, 'y': 0.14, 'desc': '拉文克劳学院的公共休息室所在。', 'icon': Icons.castle},
      {'name': '格兰芬多塔', 'x': 0.40, 'y': 0.22, 'desc': '格兰芬多学院的塔楼，公共休息室在七楼。', 'icon': Icons.castle},
      {'name': '魁地奇球场', 'x': 0.82, 'y': 0.18, 'desc': '举办魁地奇比赛的大型运动场。', 'icon': Icons.sports_baseball},
      {'name': '魔咒教室', 'x': 0.52, 'y': 0.20, 'desc': '菲涅尔教授教授魔咒课的教室。', 'icon': Icons.auto_awesome},
      {'name': '变形课教室', 'x': 0.72, 'y': 0.30, 'desc': '麦格教授的变形课教室。', 'icon': Icons.transform},
      {'name': '魔药课教室', 'x': 0.68, 'y': 0.36, 'desc': '斯内普教授的魔药课教室。', 'icon': Icons.science},
      {'name': '大礼堂', 'x': 0.48, 'y': 0.30, 'desc': '霍格沃茨的心脏，分院帽在此分配新生。', 'icon': Icons.castle},
      {'name': '赫奇帕奇地下室', 'x': 0.22, 'y': 0.32, 'desc': '赫奇帕奇学院的公共休息室。', 'icon': Icons.business},
      {'name': '图书馆（含禁书区）', 'x': 0.62, 'y': 0.48, 'desc': '霍格沃茨最大的知识宝库，禁书区需特别许可。', 'icon': Icons.menu_book},
      {'name': '魔法防御术教室', 'x': 0.48, 'y': 0.48, 'desc': '黑魔法防御术课程的教室。', 'icon': Icons.shield},
      {'name': '决斗俱乐部', 'x': 0.35, 'y': 0.56, 'desc': '洛哈特教授创办的决斗俱乐部。', 'icon': Icons.sports_martial_arts},
      {'name': '训练场', 'x': 0.85, 'y': 0.36, 'desc': '学生们进行课外活动的场地。', 'icon': Icons.flag},
      {'name': '温室', 'x': 0.68, 'y': 0.62, 'desc': '斯普劳特教授的草药课温室。', 'icon': Icons.local_florist},
      {'name': '海格的小屋', 'x': 0.78, 'y': 0.64, 'desc': '钥匙保管员海格居住的小屋。', 'icon': Icons.home},
      {'name': '黑湖', 'x': 0.12, 'y': 0.64, 'desc': '湖中住着人鱼和其他神秘生物。', 'icon': Icons.waves},
      {'name': '斯莱特林地牢', 'x': 0.22, 'y': 0.54, 'desc': '斯莱特林学院的公共休息室所在地。', 'icon': Icons.business},
      {'name': '禁林', 'x': 0.90, 'y': 0.55, 'desc': '禁区深处有许多未知的生物和秘密。', 'icon': Icons.park},
    ],
    '伦敦': [
      {'name': '魔法部', 'x': 0.75, 'y': 0.68, 'desc': '伦敦地下，英国巫师政府中枢。', 'icon': Icons.account_balance},
      {'name': '对角巷', 'x': 0.50, 'y': 0.38, 'desc': '巫师世界的主要商业街。', 'icon': Icons.shopping_bag},
      {'name': '国王十字车站', 'x': 0.48, 'y': 0.68, 'desc': '乘坐霍格沃茨特快列车的地方。', 'icon': Icons.train},
      {'name': '格里莫广场12号', 'x': 0.82, 'y': 0.45, 'desc': '凤凰社总部，布莱克家族的故居。', 'icon': Icons.star},
      {'name': '圣芒戈魔法伤病医院', 'x': 0.28, 'y': 0.42, 'desc': '魔法世界的中心医院。', 'icon': Icons.local_hospital},
      {'name': '翻倒巷', 'x': 0.15, 'y': 0.40, 'desc': '与对角巷相连的邪恶小巷。', 'icon': Icons.no_adult_content},
      {'name': '破釜酒吧', 'x': 0.42, 'y': 0.36, 'desc': '通往对角巷的入口。', 'icon': Icons.restaurant},
      {'name': '古灵阁巫师银行', 'x': 0.62, 'y': 0.40, 'desc': '妖精经营的魔法银行。', 'icon': Icons.account_balance_wallet},
      {'name': '魔法交通运输部', 'x': 0.88, 'y': 0.60, 'desc': '管理骑士公共汽车等交通方式。', 'icon': Icons.directions_bus},
    ],
    '住宅区': [
      {'name': '迪戈里住宅', 'x': 0.18, 'y': 0.18, 'desc': '塞德里克·迪戈里的家。', 'icon': Icons.home},
      {'name': '洛夫古德住宅', 'x': 0.38, 'y': 0.16, 'desc': '卢娜·洛夫古德和她父亲的家。', 'icon': Icons.home},
      {'name': '汉普斯特德花园街', 'x': 0.82, 'y': 0.22, 'desc': '伦敦的一个魔法家庭聚居区。', 'icon': Icons.streetview},
      {'name': '马尔福庄园', 'x': 0.18, 'y': 0.42, 'desc': '马尔福家族的豪华庄园。', 'icon': Icons.villa},
      {'name': '扎比尼庄园', 'x': 0.38, 'y': 0.42, 'desc': '布拉德利·扎比尼的家族庄园。', 'icon': Icons.villa},
      {'name': '陋居', 'x': 0.50, 'y': 0.54, 'desc': '罗恩·韦斯莱的家，虽然破旧但充满温暖。', 'icon': Icons.home},
      {'name': '女贞路4号', 'x': 0.78, 'y': 0.58, 'desc': '德思礼一家的家，哈利的寄养处。', 'icon': Icons.home},
      {'name': '诺特庄园', 'x': 0.15, 'y': 0.62, 'desc': '文森特·诺特的家族庄园。', 'icon': Icons.villa},
    ],
    '霍格莫德村': [
      {'name': '帕笛芙夫人茶馆', 'x': 0.30, 'y': 0.18, 'desc': '温馨的小茶馆，适合约会和闲聊。', 'icon': Icons.coffee},
      {'name': '佐科笑话店', 'x': 0.16, 'y': 0.30, 'desc': '出售各种恶作剧道具和魔法笑话。', 'icon': Icons.sentiment_satisfied},
      {'name': '德维斯和班斯商店', 'x': 0.50, 'y': 0.22, 'desc': '日常魔法用品商店。', 'icon': Icons.shopping_bag},
      {'name': '蜂蜜公爵糖果店', 'x': 0.62, 'y': 0.36, 'desc': '霍格沃茨学生最爱！比比多味豆、巧克力蛙。', 'icon': Icons.cake},
      {'name': '文人居羽毛笔店', 'x': 0.28, 'y': 0.44, 'desc': '最好的羽毛笔和墨水。', 'icon': Icons.edit},
      {'name': '三把扫帚酒吧', 'x': 0.64, 'y': 0.54, 'desc': '霍格莫德村最受欢迎的酒吧。', 'icon': Icons.local_cafe},
      {'name': '猪头酒吧', 'x': 0.40, 'y': 0.54, 'desc': '环境简陋但有故事的酒吧。', 'icon': Icons.restaurant},
      {'name': '霍格莫德车站', 'x': 0.78, 'y': 0.62, 'desc': '乘坐霍格沃茨特快的地方。', 'icon': Icons.train},
      {'name': '霍格莫德邮局', 'x': 0.56, 'y': 0.68, 'desc': '发送和接收猫头鹰邮递。', 'icon': Icons.mail},
      {'name': '尖叫棚屋', 'x': 0.78, 'y': 0.32, 'desc': '传说中闹鬼的小屋。', 'icon': Icons.hotel},
      {'name': '风雅牌巫师服装店', 'x': 0.12, 'y': 0.56, 'desc': '购买巫师袍和节日服装。', 'icon': Icons.checkroom},
      {'name': '酒吧', 'x': 0.48, 'y': 0.44, 'desc': '村中的小酒吧，当地巫师常来。', 'icon': Icons.bar_chart},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final player = gp.player;

    return Scaffold(
      body: Stack(
        children: [
          _buildFullMap(),
          _buildTopHeader(player, gp),
          _buildLocationMarkers(),
          _buildRegionNav(),
          if (_selectedLocation != null) _buildLocationCard(gp),
          _buildBackButton(),
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildFullMap() {
    return Container(
      decoration: BoxDecoration(
        gradient: _mapGradient(),
      ),
      child: CustomPaint(
        painter: MapAreaPainter(_currentArea),
        size: Size.infinite,
      ),
    );
  }

  Gradient _mapGradient() {
    switch (_currentArea) {
      case '伦敦':
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC4A882), Color(0xFFA0825A), Color(0xFF6B5B3A)],
        );
      case '住宅区':
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD4C5A9), Color(0xFFB8A88A), Color(0xFF8A9A7B)],
        );
      case '霍格莫德村':
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB8C5A0), Color(0xFF8FA07A), Color(0xFF5A6B50)],
        );
      default:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9EB5C9), Color(0xFF6B8E7A), Color(0xFF3E5B4A)],
        );
    }
  }

  Widget _buildTopHeader(player, gp) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(60, 56, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0.0)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentArea,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getAreaSubtitle(),
                          style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium!.color),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAreaSubtitle() {
    switch (_currentArea) {
      case '伦敦':
        return '英国巫师政府中枢，魔法界的政治中心。';
      case '住宅区':
        return '巫师家族聚居的庄园与住宅。';
      case '霍格莫德村':
        return '英国唯一全由巫师居住的村庄。';
      default:
        return '霍格沃茨城堡，世界上最古老的魔法学校。';
    }
  }

  Widget _buildLocationMarkers() {
    final locations = _mapData[_currentArea] ?? [];
    return Stack(
      children: locations.map((loc) {
        final x = loc['x'] as double;
        final y = loc['y'] as double;
        final isSelected = _selectedLocation == loc['name'];
        return Positioned(
          left: MediaQuery.of(context).size.width * x - 40,
          top: MediaQuery.of(context).size.height * y - 25,
          child: GestureDetector(
            onTap: () => setState(() => _selectedLocation = loc['name']),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade400,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    loc['name'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.location_on,
                    size: 18,
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

  Widget _buildRegionNav() {
    final areas = _mapData.keys.toList();
    final idx = areas.indexOf(_currentArea);
    return Positioned(
      bottom: 110,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (idx > 0) setState(() => _currentArea = areas[idx - 1]);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerTheme.color!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chevron_left, size: 18),
                  const SizedBox(width: 4),
                  Text(areas.isEmpty ? '' : areas[(idx - 1 + areas.length) % areas.length],
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).colorScheme.primary),
            ),
            child: Text(_currentArea, style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
          ),
          GestureDetector(
            onTap: () {
              if (idx < areas.length - 1) setState(() => _currentArea = areas[idx + 1]);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerTheme.color!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(areas.isNotEmpty ? areas[(idx + 1) % areas.length] : '', style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(GameProvider gp) {
    final loc = (_mapData[_currentArea] ?? []).firstWhere(
      (l) => l['name'] == _selectedLocation,
      orElse: () => {},
    );
    if (loc.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      right: 12,
      top: 120,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerTheme.color!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(loc['icon'] as IconData, color: Theme.of(context).colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc['name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(loc['desc'] as String,
                          style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium!.color),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      gp.travelTo(loc['name'] as String);
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

  Widget _buildBackButton() {
    return Positioned(
      top: 48,
      left: 12,
      child: SafeArea(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
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

class MapAreaPainter extends CustomPainter {
  final String area;
  MapAreaPainter(this.area);

  @override
  void paint(Canvas canvas, Size size) {
    final groundPaint = Paint()
      ..color = Color(0xFF5A6B4A).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(size.width * 0.15, size.height * 0.25)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.15, size.width * 0.55, size.height * 0.20)
      ..lineTo(size.width * 0.85, size.height * 0.22)
      ..quadraticBezierTo(size.width * 0.90, size.height * 0.40, size.width * 0.80, size.height * 0.45)
      ..lineTo(size.width * 0.50, size.height * 0.42)
      ..quadraticBezierTo(size.width * 0.30, size.height * 0.38, size.width * 0.15, size.height * 0.35)
      ..close();
    canvas.drawPath(path1, groundPaint);

    final hillPaint = Paint()
      ..color = Color(0xFF3E5B4A).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final hillPath = Path()
      ..moveTo(size.width * 0.05, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.48, size.width * 0.45, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.65, size.height * 0.60, size.width * 0.85, size.height * 0.52)
      ..lineTo(size.width * 0.95, size.height * 0.65)
      ..lineTo(size.width * 0.95, size.height * 0.85)
      ..lineTo(size.width * 0.05, size.height * 0.85)
      ..close();
    canvas.drawPath(hillPath, hillPaint);

    final waterPaint = Paint()
      ..color = Color(0xFF4A6B8A).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final waterPath = Path()
      ..moveTo(size.width * 0.50, size.height * 0.62)
      ..quadraticBezierTo(size.width * 0.65, size.height * 0.60, size.width * 0.75, size.height * 0.68)
      ..lineTo(size.width * 0.70, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.55, size.height * 0.82, size.width * 0.45, size.height * 0.75)
      ..close();
    canvas.drawPath(waterPath, waterPaint);

    final pathPaint = Paint()
      ..color = Color(0xFFC4A574).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.20, size.height * 0.30)
        ..quadraticBezierTo(size.width * 0.40, size.height * 0.50, size.width * 0.55, size.height * 0.55)
        ..quadraticBezierTo(size.width * 0.70, size.height * 0.58, size.width * 0.82, size.height * 0.40),
      pathPaint,
    );

    final treePaint = Paint()
      ..color = Color(0xFF2D3E2A).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 12; i++) {
      final tx = (i * 0.083 + 0.05) * size.width;
      final ty = (0.75 + (i % 3) * 0.04) * size.height;
      canvas.drawCircle(Offset(tx, ty), 8 + (i % 3).toDouble() * 3, treePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}