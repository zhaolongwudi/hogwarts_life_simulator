import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../utils/ui_helpers.dart';
import 'world_map/marker_layout.dart';
import 'world_map/map_area_painter.dart';
import '../data/locations.dart';
import '../data/game_config_rules.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../theme/miuix_tokens.dart';
import '../widgets/miuix_overlays.dart';

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

  static const Map<String, List<Map<String, dynamic>>> _mapData = {
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

  static const Map<String, Map<String, dynamic>> _subAreas = {
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

  /// 区域标题：优先显示玩家自定义名称，未设置时回退到地图默认名
  String _displayHeaderName(BuildContext context) {
    final label = context.watch<GameProvider>().worldState.currentLocationLabel;
    if (label != null && label.isNotEmpty) return label;
    return _displayAreaName;
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
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF3E5B4A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildFullMap(),
          SafeArea(
            child: Stack(
              children: [
                _buildTopHeader(player, gp),
                _buildLocationMarkers(),
                _buildBranchIndicators(),
                _buildRegionNav(),
                if (_selectedLocation != null) _buildLocationCard(gp),
                _buildBackButton(),
                _buildMapLegend(),
                _buildQuickAreaSwitch(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchIndicators() {
    if (_isInSubArea) return const SizedBox.shrink();

    return Positioned(
      right: 12,
      bottom: 160,
      child: GestureDetector(
        onTap: _showWorldOverview,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: MiuiColors.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: MiuiColors.primary, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.public, size: 18, color: AppColors.goldBright),
                  const SizedBox(width: 6),
                  const Text('大世界', style: TextStyle(fontSize: 16, color: AppColors.goldBright, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text('世界总览', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  /// 打开「大世界」总览：列出全部区域与子地图，点按快速跳转。
  void _showWorldOverview() {
    final areas = _mapData.keys.toList();
    final subAreas = _subAreas.keys.toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF20402F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '大世界 · 区域总览',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...areas.map((a) => _buildOverviewTile(ctx, a, _mapData[a]!.length, false)),
                  ...subAreas.map((s) => _buildOverviewTile(ctx, s, (_subAreas[s]!['locations'] as List).length, true)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 子地图所属的父区域：由 _mapData 中的 branch 标记推导（避免硬编码）。
  String? _parentAreaOf(String subAreaName) {
    for (final entry in _mapData.entries) {
      for (final loc in entry.value) {
        if (loc['branch'] == true && loc['name'] == subAreaName) {
          return entry.key;
        }
      }
    }
    return null;
  }

  Widget _buildOverviewTile(
      BuildContext ctx, String name, int count, bool isSub) {
    return ListTile(
      leading: Icon(
        isSub ? Icons.subdirectory_arrow_right : Icons.map,
        color: isSub ? AppColors.warning : MiuiColors.primary,
      ),
      title: Text(name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text('$count 个地点', style: const TextStyle(color: Colors.white70)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      onTap: () {
        Navigator.pop(ctx);
        setState(() {
          if (isSub) {
            final parent = _parentAreaOf(name) ?? _currentArea;
            _currentArea = parent;
            _parentArea = parent;
            _currentSubArea = name;
          } else {
            _currentArea = name;
            _currentSubArea = null;
            _parentArea = null;
          }
          _selectedLocation = null;
        });
      },
    );
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
        colors: [Color(0xFF2E2615), Color(0xFF221D11), Color(0xFF18150D)],
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
          colors: [Color(0xFF2C2935), Color(0xFF1F1C28), Color(0xFF16141C)],
        );
      case '住宅区':
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2D33), Color(0xFF1E2025), Color(0xFF15171B)],
        );
      case '霍格莫德村':
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1F2E33), Color(0xFF162126), Color(0xFF0E171C)],
        );
      default:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A3540), Color(0xFF1F2A35), Color(0xFF151D26)],
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
            colors: [MiuiColors.background.withValues(alpha: 0.95), MiuiColors.background.withValues(alpha: 0.0)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MiuiColors.surfaceContainerHigh.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: MiuiColors.outline.withValues(alpha: 0.6),
                  width: MiuiSpace.dividerThickness,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 14,
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
                                    style: const TextStyle(fontSize: 16, color: Color(0xFF3E5B4A), fontWeight: FontWeight.w500)),
                              ),
                              const Icon(Icons.chevron_right, size: 18, color: MiuiColors.onSurfaceVariantSummary),
                            ],
                            Flexible(
                              child: Text(
                                _displayHeaderName(context),

                                // 第16轮E：用户反馈地图上方标题看不清——
                                // 原样式无 color，跟随 Theme 在白底卡片上对比度低。
                                // 改为深色高对比（与 subtitle 区分层级）
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: MiuiColors.surfaceContainer,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _displaySubtitle,
                          // subtitle 用更深的中绿，提高白底可读性
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF3E5B4A).withValues(alpha: 0.95),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _editAreaLabel(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, size: 20, color: MiuiColors.primary),
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

  void _editAreaLabel(BuildContext context) {
    final gp = context.read<GameProvider>();
    final controller = TextEditingController(
      text: gp.worldState.currentLocationLabel ?? _displayAreaName,
    );
    showMiuixDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义区域名称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(
            hintText: '给这片区域起个名字...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              gp.setCurrentLocationLabel(controller.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('区域名称已更新')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
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

        final headerOffset = 110.0;
        final bottomOffset = 420.0;
        final usableHeight = mapHeight - headerOffset - bottomOffset;

        // 空间不够时切成紧凑标记（只留圆点，去掉文字气泡）
        final perMarker = locations.isEmpty
            ? usableHeight
            : usableHeight / locations.length;
        final compact = perMarker < 78;

        final boxW = compact ? 44.0 : 100.0;
        final boxH = compact ? 50.0 : 120.0;

        // 画布按需撑开
        const markerGap = 6.0;
        final needed = locations.length * (boxH + markerGap);
        final canvasHeight =
            needed > usableHeight ? needed : usableHeight;

        final raw = <MarkerBox>[
          for (final loc in locations)
            MarkerBox(
              mapWidth * ((loc['x'] as num?)?.toDouble() ?? 0.15) - boxW / 2,
              headerOffset +
                      ((loc['y'] as num?)?.toDouble() ?? 0.5) * canvasHeight -
                  (compact ? 0 : 36),
            ),
        ];
        final placed = resolveMarkerOverlaps(
          raw,
          boxWidth: boxW,
          boxHeight: boxH,
          minTop: headerOffset,
          maxLeft: mapWidth - boxW,
          maxTop: headerOffset + (canvasHeight - boxH).clamp(0.0, canvasHeight),
        );

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            height: headerOffset + canvasHeight + boxH,
            child: Stack(
              clipBehavior: Clip.none,
              children: locations.asMap().entries.map((entry) {
                final loc = entry.value;
                final isSelected = _selectedLocation == loc['name'];
                final isBranch = loc['branch'] == true;

                final pos = placed[entry.key];

                return Positioned(
                  left: pos.left,
                  top: pos.top,
                  child: GestureDetector(
                    onTap: () {
                      if (isBranch) {
                        _enterSubArea(loc['name'] as String);
                      } else {
                        setState(() => _selectedLocation = loc['name']);
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!compact) ...[
                          // 暗色玻璃标签 — 匹配参考图的深色半透明风格
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                constraints: const BoxConstraints(
                                  minWidth: 80,
                                  maxWidth: 140,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A2E).withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.goldBright
                                        : isBranch
                                            ? AppColors.gold
                                            : const Color(0xFF3A3A5C),
                                    width: isSelected || isBranch ? 1.8 : 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                    if (isSelected)
                                      BoxShadow(
                                        color: AppColors.gold.withValues(alpha: 0.3),
                                        blurRadius: 18,
                                        offset: const Offset(0, 0),
                                      ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isBranch) ...[
                                      Icon(Icons.subdirectory_arrow_right,
                                          size: 14, color: AppColors.gold),
                                      const SizedBox(width: 4),
                                    ],
                                    Flexible(
                                      child: Text(
                                        loc['name'] as String,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected || isBranch
                                              ? AppColors.goldBright
                                              : Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // 金色定位针
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.topLeft,
                                radius: 1.2,
                                colors: isSelected
                                    ? [AppColors.goldBright, AppColors.goldDeep]
                                    : isBranch
                                        ? [AppColors.gold, AppColors.goldDeep]
                                        : [const Color(0xFF4A4A6A), const Color(0xFF2A2A4A)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.goldBright
                                    : isBranch
                                        ? AppColors.gold
                                        : const Color(0xFF5A5A7A),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? AppColors.gold.withValues(alpha: 0.45)
                                      : isBranch
                                          ? AppColors.gold.withValues(alpha: 0.25)
                                          : Colors.black.withValues(alpha: 0.3),
                                  blurRadius: isSelected ? 12 : 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isBranch ? Icons.alt_route : Icons.location_on,
                              size: 17,
                              color: isSelected || isBranch
                                  ? Colors.white
                                  : const Color(0xFF8A8AAA),
                            ),
                          ),
                        ],
                        if (compact) ...[
                          // 紧凑模式：金色小圆点 + 简短名称
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.goldBright
                                  : isBranch
                                      ? AppColors.gold
                                      : const Color(0xFF2A2A4A).withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.goldBright
                                    : isBranch
                                        ? AppColors.gold
                                        : const Color(0xFF5A5A7A),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.location_on,
                              size: 14,
                              color: isSelected || isBranch
                                  ? Colors.white
                                  : const Color(0xFF8A8AAA),
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            width: 44,
                            child: Text(
                              loc['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 9,
                                height: 1.1,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 4),
                                  Shadow(color: Colors.black, blurRadius: 8),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _enterSubArea(String subAreaName) {
    if (_subAreas.containsKey(subAreaName)) {
      setState(() {
        _parentArea = _currentSubArea ?? _currentArea;
        _currentSubArea = subAreaName;
        _selectedLocation = null;
      });
    } else if (_subAreas.containsKey('翻倒巷') &&
        (subAreaName == '翻倒巷入口' || subAreaName == '翻倒巷')) {
      setState(() {
        _parentArea = _currentSubArea ?? _currentArea;
        _currentSubArea = '翻倒巷';
        _selectedLocation = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$subAreaName" 区域地图暂未开放')),
      );
    }
  }

  Widget _buildRegionNav() {
    // 消重（v3.8.7）：区域左右切换已由底部 _buildQuickAreaSwitch 承担
    // （‹ 上一区域 | 当前区域 | 下一区域 ›），这里不再重复绘制第二组导航胶囊。
    return const SizedBox.shrink();
  }
  Widget _buildLocationCard(GameProvider gp) {
    // 崩溃修复（用户日志：v3.5.x `firstWhere orElse` 类型不匹配）：
    // `orElse: () => {}` 推断为 Map<String, dynamic>，而列表元素在旧版
    // const 字面量下推断为 Map<String, Object> → 运行时类型断言崩溃。
    // 改用循环查找：无泛型推导歧义，任何列表元素类型都不崩。
    Map<String, dynamic>? selected;
    for (final l in _currentLocations) {
      if (l['name'] == _selectedLocation) {
        selected = l;
        break;
      }
    }
    final loc = selected;
    if (loc == null || loc.isEmpty) return const SizedBox.shrink();

    final isBranch = loc['branch'] == true;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: () => setState(() => _selectedLocation = null),
            child: Container(
              color: Colors.black.withValues(alpha: 0.25),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 120,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MiuiColors.primary.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isBranch ? AppColors.warning : const Color(0xFF3E5B4A))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isBranch ? Icons.subdirectory_arrow_right : loc['icon'] as IconData,
                        color: isBranch ? AppColors.warning : const Color(0xFF3E5B4A),
                        size: 24,
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
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: MiuiColors.surfaceContainer)),
                              ),
                              if (isBranch)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('子地图',
                                      style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(loc['desc'] as String,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF5A6B4A)),
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
                          color: MiuiColors.surfaceContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18, color: MiuiColors.onSurfaceVariantSummary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MiuiColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MiuiColors.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(isBranch ? Icons.map : Icons.flag, size: 18, color: isBranch ? AppColors.warning : const Color(0xFF4CAF7D)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isBranch ? '点击进入子地图探索更多地点' : '前往此地并开始你的冒险',
                          style: TextStyle(fontSize: 13, color: isBranch ? AppColors.warning : const Color(0xFF3E5B4A)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3E5B4A),
                            side: const BorderSide(color: Color(0xFF3E5B4A), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => setState(() => _selectedLocation = null),
                          child: const Text('关闭', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBranch ? AppColors.warning : MiuiColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        onPressed: () {
                          if (isBranch) {
                            _enterSubArea(loc['name'] as String);
                          } else {
                            // 第16轮E：预检时间门/年级门——原 travelTo 拦截是
                            // 静默的（只记系统事件），玩家点「前往」毫无反馈，
                            // 像地图"灰屏没反应"。拦截时给可见 SnackBar 提示。
                            final targetName = loc['name'] as String;
                            final normalized =
                                resolveLocationName(targetName) ?? targetName;
                            final curLoc = gp.worldState.currentLocation ?? '';
                            final dateInt = gp.worldState.time.month * 100 +
                                gp.worldState.time.day;
                            if (blockedBySeasonGate(
                              detected: normalized,
                              current: curLoc,
                              dateInt: dateInt,
                            )) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('该地点开学后才能前往（9月1日起）'),
                                  duration: MiuiDuration.snackbarMedium,
                                ),
                              );
                              return;
                            }
                            // 区域门禁：与 travelTo / 叙事同步共用同一判定。
                            // 文案由判定结果动态生成，不再写死"需三年级"——
                            // 旧文案在拦禁林时也这么说，因为旧函数只认霍格莫德。
                            final gate = evaluateRegionGate(
                              detected: normalized,
                              grade: gp.player?.grade,
                              isWeekend: isWeekendWeekday(
                                  gp.worldState.time.weekday),
                            );
                            if (gate.isBlocked) {
                              final msg = switch (gate.reason!) {
                                RegionGateReason.grade =>
                                  '该地点需${gate.blocked!.minGrade}年级以上才能前往',
                                RegionGateReason.weekend =>
                                  '${gate.blocked!.name}仅周末开放',
                              };
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(msg),
                                  duration: MiuiDuration.snackbarMedium,
                                ),
                              );
                              return;
                            }
                            gp.travelTo(targetName);
                            Navigator.pop(context);
                          }
                        },
                        child: Text(isBranch ? '进入子地图' : '前往此地',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF3E5B4A).withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              _isInSubArea ? Icons.subdirectory_arrow_left : Icons.arrow_back,
              size: 24,
              color: const Color(0xFF2C4A3A),
            ),
          ),
        ),
      ),
    );
  }

  /// 底部快速切换大区域按钮（第16轮E：用户期望「< 霍格莫德村 | 霍格沃茨 | 伦敦 >」
  /// 三按钮左右切区域，代码里之前缺失——切区域只能走「大世界」总览）。
  /// 三按钮：左 = 上一区域（<），中 = 当前（点击打开总览），右 = 下一区域（>）。
  Widget _buildQuickAreaSwitch() {
    const order = ['霍格莫德村', '霍格沃茨', '伦敦'];
    final idx = order.indexOf(_currentArea);
    if (idx < 0 || _isInSubArea) return const SizedBox.shrink();
    final prev = order[(idx - 1 + order.length) % order.length];
    final next = order[(idx + 1) % order.length];
    return Positioned(
      left: 0,
      right: 0,
      bottom: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _areaChip('‹ $prev', () => _switchArea(prev)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _areaChip(_currentArea, _showWorldOverview,
                      isCurrent: true),
                ),
              ),
              _areaChip('$next ›', () => _switchArea(next)),
            ],
          ),
        ),
      ),
    );
  }

  /// 切换大区域：清掉子区域/选中态，重置归位指示，避免上一区域的状态污染。
  void _switchArea(String area) {
    if (area == _currentArea) return;
    setState(() {
      _currentArea = area;
      _currentSubArea = null;
      _parentArea = null;
      _selectedLocation = null;
    });
  }

  Widget _areaChip(String label, VoidCallback onTap, {bool isCurrent = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent
              ? MiuiColors.surfaceContainer
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isCurrent
                ? MiuiColors.surfaceContainer
                : MiuiColors.primary.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isCurrent ? Colors.white : MiuiColors.surfaceContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildMapLegend() {
    return Positioned(
      left: 12,
      bottom: 280,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3A3A5C).withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.goldBright, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('当前', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(width: 10),
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('子地图', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(width: 10),
                Container(width: 10, height: 10, decoration: BoxDecoration(
                  color: const Color(0xFF2A2A4A),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF5A5A7A), width: 1.5),
                )),
                const SizedBox(width: 5),
                const Text('地点', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

