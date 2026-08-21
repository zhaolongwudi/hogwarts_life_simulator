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
  String? _currentSubArea;
  String? _parentArea;
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
      {'name': '对角巷', 'x': 0.50, 'y': 0.38, 'desc': '巫师世界的主要商业街，店铺林立。', 'icon': Icons.shopping_bag, 'branch': true},
      {'name': '国王十字车站', 'x': 0.48, 'y': 0.68, 'desc': '乘坐霍格沃茨特快列车的地方。', 'icon': Icons.train},
      {'name': '格里莫广场12号', 'x': 0.82, 'y': 0.45, 'desc': '凤凰社总部，布莱克家族的故居。', 'icon': Icons.star},
      {'name': '圣芒戈魔法伤病医院', 'x': 0.28, 'y': 0.42, 'desc': '魔法世界的中心医院。', 'icon': Icons.local_hospital},
      {'name': '翻倒巷', 'x': 0.15, 'y': 0.40, 'desc': '与对角巷相连的邪恶小巷，黑魔法交易地。', 'icon': Icons.no_adult_content, 'branch': true},
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

  final Map<String, Map<String, dynamic>> _subAreas = {
    '对角巷': {
      'subtitle': '巫师世界最繁华的商业街，各类魔法店铺齐聚于此。',
      'locations': [
        {'name': '古灵阁巫师银行', 'x': 0.12, 'y': 0.18, 'desc': '妖精经营的魔法银行，货币兑换和贵重物品存放。', 'icon': Icons.account_balance},
        {'name': '《预言家日报》总部', 'x': 0.30, 'y': 0.14, 'desc': '魔法界最大报纸的编辑部。', 'icon': Icons.newspaper},
        {'name': '飞路粉公司', 'x': 0.46, 'y': 0.16, 'desc': '唯一合法的飞路粉生产商。', 'icon': Icons.local_fire_department},
        {'name': '奥利凡德魔杖店', 'x': 0.60, 'y': 0.14, 'desc': '传承三代的魔杖制作店，"杖芯决定一切"。', 'icon': Icons.auto_awesome},
        {'name': '摩金夫人长袍专卖店', 'x': 0.76, 'y': 0.16, 'desc': '定制巫师袍和礼服。', 'icon': Icons.checkroom},
        {'name': '丽痕书店', 'x': 0.88, 'y': 0.14, 'desc': '魔法书籍的最大零售商。', 'icon': Icons.menu_book},
        {'name': '呼啦猫头鹰商店', 'x': 0.10, 'y': 0.40, 'desc': '购买和邮寄猫头鹰的商店。', 'icon': Icons.pets},
        {'name': '神奇动物商店', 'x': 0.30, 'y': 0.38, 'desc': '售卖各种魔法生物。', 'icon': Icons.park},
        {'name': '帕特奇坩埚店', 'x': 0.46, 'y': 0.38, 'desc': '出售各种坩埚和炼金器具。', 'icon': Icons.science},
        {'name': '药店', 'x': 0.62, 'y': 0.40, 'desc': '魔法药品和药材。', 'icon': Icons.local_pharmacy},
        {'name': '翻倒巷入口', 'x': 0.82, 'y': 0.42, 'desc': '通往翻倒巷的隐秘入口。', 'icon': Icons.no_adult_content, 'branch': true},
        {'name': '魁地奇精品专卖店', 'x': 0.12, 'y': 0.66, 'desc': '魁地奇装备和纪念品。', 'icon': Icons.sports_baseball},
        {'name': '维泽埃克魔法用品店', 'x': 0.30, 'y': 0.66, 'desc': '各类魔法杂货。', 'icon': Icons.shopping_bag},
        {'name': '普瑞姆派尼尔夫人美容店', 'x': 0.46, 'y': 0.68, 'desc': '巫师美容和魔法化妆品。', 'icon': Icons.face},
        {'name': '弗洛林·福斯冰品店', 'x': 0.62, 'y': 0.66, 'desc': '各种口味的魔法冰淇淋。', 'icon': Icons.icecream},
        {'name': '韦斯莱魔法把戏坊', 'x': 0.80, 'y': 0.68, 'desc': '弗雷德和乔治的恶作剧道具店。', 'icon': Icons.sentiment_satisfied},
      ],
    },
    '翻倒巷': {
      'subtitle': '与对角巷相连的黑暗小巷，黑魔法交易的地下市场。',
      'locations': [
        {'name': '博金·博克古董店', 'x': 0.20, 'y': 0.20, 'desc': '出售各种黑魔法物品和古董。', 'icon': Icons.shop},
        {'name': '卡赞的铺子', 'x': 0.40, 'y': 0.24, 'desc': '黑魔法材料交易。', 'icon': Icons.science},
        {'name': '黑魔法市集', 'x': 0.60, 'y': 0.20, 'desc': '非法魔法物品的地下交易。', 'icon': Icons.visibility_off},
        {'name': '幽灵酒馆', 'x': 0.30, 'y': 0.50, 'desc': '黑暗生物聚集的酒馆。', 'icon': Icons.restaurant},
        {'name': '毒药铺', 'x': 0.50, 'y': 0.52, 'desc': '出售各类毒药的隐秘店铺。', 'icon': Icons.bloodtype},
        {'name': '黑市入口', 'x': 0.72, 'y': 0.50, 'desc': '通往地下黑市的入口。', 'icon': Icons.lock},
      ],
    },
  };

  List<Map<String, dynamic>> get _currentLocations {
    if (_currentSubArea != null) {
      return _subAreas[_currentSubArea]!['locations'] as List<Map<String, dynamic>>;
    }
    return _mapData[_currentArea] ?? [];
  }

  String get _displayAreaName {
    if (_currentSubArea != null) return _currentSubArea!;
    return _currentArea;
  }

  String get _displaySubtitle {
    if (_currentSubArea != null) {
      return _subAreas[_currentSubArea]!['subtitle'] as String? ?? '';
    }
    return _getAreaSubtitle();
  }

  bool get _isInSubArea => _currentSubArea != null;

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
          _buildBranchIndicators(),
          _buildRegionNav(),
          if (_selectedLocation != null) _buildLocationCard(gp),
          _buildBackButton(),
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildBranchIndicators() {
    if (!_isInSubArea) {
      final areas = _mapData.keys.toList();
      return Positioned(
        right: 16,
        bottom: 110,
        child: GestureDetector(
          onTap: () {
            final idx = areas.indexOf(_currentArea);
            if (idx < areas.length - 1) {
              setState(() {
                _currentArea = areas[idx + 1];
                _currentSubArea = null;
                _parentArea = null;
                _selectedLocation = null;
              });
            }
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
                const Icon(Icons.chevron_right, size: 16),
                const SizedBox(width: 4),
                Text('大世界', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildFullMap() {
    return Container(
      decoration: BoxDecoration(
        gradient: _mapGradient(),
      ),
      child: CustomPaint(
        painter: MapAreaPainter(_currentArea, _currentSubArea),
        size: Size.infinite,
      ),
    );
  }

  Gradient _mapGradient() {
    if (_currentSubArea == '对角巷') {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFC4A574), Color(0xFFA08C5A), Color(0xFF6B5B3A)],
      );
    }
    if (_currentSubArea == '翻倒巷') {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3A3040), Color(0xFF2A2530), Color(0xFF1A1520)],
      );
    }
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
                        Row(
                          children: [
                            if (_isInSubArea) ...[
                              GestureDetector(
                                onTap: () => _backToParent(),
                                child: Text(_parentArea ?? '',
                                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary)),
                              ),
                              const Icon(Icons.chevron_right, size: 16),
                            ],
                            Flexible(
                              child: Text(
                                _displayAreaName,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _displaySubtitle,
                          style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium!.color),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

  void _backToParent() {
    setState(() {
      _currentSubArea = null;
      if (_parentArea != null) {
        _currentArea = _parentArea!;
      }
      _parentArea = null;
      _selectedLocation = null;
    });
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
    final locations = _currentLocations;
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapWidth = constraints.maxWidth;
        final mapHeight = constraints.maxHeight;

        final headerOffset = 90.0;
        final bottomOffset = 120.0;
        final usableHeight = mapHeight - headerOffset - bottomOffset;

        return Stack(
          clipBehavior: Clip.none,
          children: locations.asMap().entries.map((entry) {
            final loc = entry.value;
            final x = loc['x'] as double;
            final y = loc['y'] as double;
            final isSelected = _selectedLocation == loc['name'];
            final isBranch = loc['branch'] == true;

            final adjustedY = headerOffset + (y * usableHeight);
            final left = mapWidth * x - 30;
            final top = adjustedY - 24;

            return Positioned(
              left: left,
              top: top,
              child: GestureDetector(
                onTap: () {
                  if (isBranch) {
                    _enterSubArea(loc['name'] as String);
                  } else {
                    setState(() => _selectedLocation = loc['name']);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: isBranch ? 6 : 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFD3A625)
                              : isBranch
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF8B949E),
                          width: isSelected || isBranch ? 1.5 : 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isBranch) ...[
                            Icon(Icons.subdirectory_arrow_right, size: 11, color: const Color(0xFFD97706)),
                            const SizedBox(width: 2),
                          ],
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 70),
                            child: Text(
                              loc['name'] as String,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected || isBranch ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFFB8860B)
                                    : isBranch
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF1F2937),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFD3A625)
                            : isBranch
                                ? const Color(0xFFD97706)
                                : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFB8860B)
                              : isBranch
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFFD3A625),
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
                        isBranch ? Icons.subdirectory_arrow_right : Icons.location_on,
                        size: 14,
                        color: isSelected || isBranch ? Colors.white : const Color(0xFFD3A625),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _enterSubArea(String subAreaName) {
    if (_subAreas.containsKey(subAreaName)) {
      setState(() {
        _parentArea = _currentArea;
        _currentSubArea = subAreaName;
        _selectedLocation = null;
      });
    } else if (_subAreas.containsKey('翻倒巷') && subAreaName == '翻倒巷入口') {
      setState(() {
        _parentArea = _currentSubArea ?? _currentArea;
        _currentSubArea = '翻倒巷';
        _selectedLocation = null;
      });
    }
  }

  Widget _buildRegionNav() {
    if (_isInSubArea) return const SizedBox.shrink();

    final areas = _mapData.keys.toList();
    final idx = areas.indexOf(_currentArea);
    return Positioned(
      bottom: 110,
      left: 16,
      right: 80,
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
            child: Text(_currentArea,
                style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
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
    final loc = _currentLocations.firstWhere(
      (l) => l['name'] == _selectedLocation,
      orElse: () => {},
    );
    if (loc.isEmpty) return const SizedBox.shrink();

    final isBranch = loc['branch'] == true;

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
                    color: (isBranch ? const Color(0xFFD97706) : Theme.of(context).colorScheme.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isBranch ? Icons.subdirectory_arrow_right : loc['icon'] as IconData,
                    color: isBranch ? const Color(0xFFD97706) : Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(loc['name'] as String,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          if (isBranch)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('子地图',
                                  style: TextStyle(fontSize: 10, color: Color(0xFFD97706))),
                            ),
                        ],
                      ),
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
                    child: Text(
                      isBranch ? '点击进入子地图探索更多' : '直接前往或输入想去此地做的事',
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBranch ? const Color(0xFFD97706) : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (isBranch) {
                        _enterSubArea(loc['name'] as String);
                      } else {
                        gp.travelTo(loc['name'] as String);
                        Navigator.pop(context);
                      }
                    },
                    child: Text(isBranch ? '进入' : '直接前往',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
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
          onTap: () {
            if (_isInSubArea) {
              _backToParent();
            } else {
              Navigator.pop(context);
            }
          },
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
            child: Icon(_isInSubArea ? Icons.subdirectory_arrow_left : Icons.arrow_back, size: 22),
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
  final String? subArea;
  MapAreaPainter(this.area, this.subArea);

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

    if (subArea == '翻倒巷') {
      final darkPaint = Paint()
        ..color = Color(0xFF1A1520).withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;

      final darkPath = Path()
        ..moveTo(size.width * 0.20, size.height * 0.35)
        ..quadraticBezierTo(size.width * 0.40, size.height * 0.30, size.width * 0.60, size.height * 0.40)
        ..lineTo(size.width * 0.70, size.height * 0.65)
        ..quadraticBezierTo(size.width * 0.50, size.height * 0.75, size.width * 0.30, size.height * 0.70)
        ..close();
      canvas.drawPath(darkPath, darkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MapAreaPainter oldDelegate) {
    return oldDelegate.area != area || oldDelegate.subArea != subArea;
  }
}