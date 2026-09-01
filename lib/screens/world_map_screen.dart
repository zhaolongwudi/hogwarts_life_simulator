import 'package:flutter/material.dart';
import '../utils/ui_helpers.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';

class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

/// 单个地图标记解算后的位置。
class MarkerBox {
  final double left;
  final double top;
  const MarkerBox(this.left, this.top);
}

/// 地图标记防重叠布局。
///
/// 背景：标记位置直接由数据里的归一化 x/y 算出，没有任何碰撞处理。
/// 大屏上勉强能看，但小屏（可用高度只有两三百像素）上，
/// y 相差 0.02 的两个地点只差几像素，而标记本身有 ~120px 高 ——
/// 结果是整片标记叠在一起，既读不出名字也点不中。霍格沃茨一张图
/// 有 18 个地点，问题尤其严重。
///
/// 做法：按 top 排序后做单向扫描（经典标签排布算法）——
/// 每个标记只需躲开排在它前面、且水平方向确实挨着的那些，
/// 一旦冲突就整体下推到刚好不重叠的位置。纯确定性，
/// 所以同一张地图每次打开位置一致。
///
/// 早期版本用的是"成对对称互推 + 多轮迭代"，实测会来回抖动、
/// 甚至在 16 轮内收敛不了（18 个标记最终挤在 130px 内）。
/// 单向扫描一轮就到位，也更可预测。
///
/// 前提：调用方需要保证画布高度足够（world_map_screen 里画布会
/// 按需撑开并允许滚动）。空间物理上不够时本函数只能做到尽量分开。
List<MarkerBox> resolveMarkerOverlaps(
  List<MarkerBox> input, {
  required double boxWidth,
  required double boxHeight,
  required double minTop,
  required double maxLeft,
  required double maxTop,
  double gap = 6.0,
}) {
  if (input.isEmpty) return input;

  final safeLeft = maxLeft < 0 ? 0.0 : maxLeft;
  final safeTop = maxTop < minTop ? minTop : maxTop;

  // 1) 先把水平位置夹进边界：后续判定冲突要用夹紧后的坐标，
  //    否则"看起来错开了、夹完其实重叠"的标记会被漏掉。
  final clamped = <MarkerBox>[
    for (final b in input)
      MarkerBox(
        b.left.clamp(0.0, safeLeft),
        b.top < minTop ? minTop : b.top,
      ),
  ];

  // 2) 按 top 排序（top 相同则按 left），保证扫描方向稳定
  final order = List<int>.generate(clamped.length, (i) => i)
    ..sort((a, b) {
      final c = clamped[a].top.compareTo(clamped[b].top);
      return c != 0 ? c : clamped[a].left.compareTo(clamped[b].left);
    });

  final lefts = <double>[for (final i in order) clamped[i].left];
  final tops = <double>[for (final i in order) clamped[i].top];
  final n = tops.length;

  bool conflicts(int i, int j) =>
      (lefts[i] - lefts[j]).abs() < boxWidth + gap &&
      (tops[i] - tops[j]).abs() < boxHeight + gap;

  // 3) 正向扫描：每个标记躲开排在它前面的所有冲突者
  for (var i = 1; i < n; i++) {
    for (var j = 0; j < i; j++) {
      if (!conflicts(i, j)) continue;
      final target = tops[j] + boxHeight + gap;
      if (target > tops[i]) tops[i] = target;
    }
  }

  // 4) 超出下边界则从底部往回推（画布被外部限制时才会发生）
  if (tops[n - 1] > safeTop) {
    tops[n - 1] = safeTop;
    for (var i = n - 2; i >= 0; i--) {
      for (var j = i + 1; j < n; j++) {
        if (!conflicts(i, j)) continue;
        final target = tops[j] - boxHeight - gap;
        if (target < tops[i]) tops[i] = target;
      }
      if (tops[i] < minTop) tops[i] = minTop;
    }
  }

  // 5) 还原原始顺序并做最后一次边界夹取
  final out = List<MarkerBox>.filled(n, const MarkerBox(0, 0));
  for (var k = 0; k < n; k++) {
    out[order[k]] = MarkerBox(
      lefts[k],
      tops[k].clamp(minTop, safeTop),
    );
  }
  return out;
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
                color: const Color(0xFF161B22).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFD3A625), width: 1.5),
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
        color: isSub ? AppColors.warning : const Color(0xFFD3A625),
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
            colors: [const Color(0xFF0D1117).withValues(alpha: 0.95), const Color(0xFF0D1117).withValues(alpha: 0.0)],
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
                                    style: const TextStyle(fontSize: 16, color: Color(0xFF3E5B4A), fontWeight: FontWeight.w500)),
                              ),
                              const Icon(Icons.chevron_right, size: 18, color: Color(0xFF8B949E)),
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
                                  color: Color(0xFF1F2937),
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
                      child: const Icon(Icons.edit, size: 20, color: Color(0xFFD3A625)),
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
    showDialog<void>(
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
    final locations = _currentLocations;
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapWidth = constraints.maxWidth;
        final mapHeight = constraints.maxHeight;

        final headerOffset = 110.0;
        final bottomOffset = 420.0;
        final usableHeight = mapHeight - headerOffset - bottomOffset;

        // 空间不够时切成紧凑标记（只留圆点，去掉文字气泡）：
        // 完整标记盒 ~96x120，紧凑只有 ~44x50，同样高度能多排一倍以上。
        final perMarker = locations.isEmpty
            ? usableHeight
            : usableHeight / locations.length;
        final compact = perMarker < 78;

        final boxW = compact ? 44.0 : 96.0;
        final boxH = compact ? 50.0 : 118.0;

        // 画布按需撑开：霍格沃茨一张图有 18 个地点，
        // 而小屏上可用高度只有两三百像素——再怎么压缩也放不下。
        // 与其让标记叠成一团，不如把画布拉高并允许上下滚动。
        const markerGap = 6.0;
        final needed = locations.length * (boxH + markerGap);
        final canvasHeight =
            needed > usableHeight ? needed : usableHeight;

        final raw = <MarkerBox>[
          for (final loc in locations)
            MarkerBox(
              mapWidth * (loc['x'] as double) - boxW / 2,
              headerOffset + ((loc['y'] as double) * canvasHeight) -
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!compact) Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      constraints: const BoxConstraints(minWidth: 70),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.97),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFD3A625)
                              : isBranch
                                  ? AppColors.warning
                                  : const Color(0xFF3E5B4A),
                          width: isSelected || isBranch ? 2 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isBranch) ...[
                            const Icon(Icons.subdirectory_arrow_right, size: 15, color: AppColors.gold),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              loc['name'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppColors.gold
                                    : isBranch
                                        ? AppColors.gold
                                        : const Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact) const SizedBox(height: 4),
                    Container(
                      width: compact ? 30 : 36,
                      height: compact ? 30 : 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFD3A625)
                            : isBranch
                                ? AppColors.warning
                                : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.goldBright
                              : isBranch
                                  ? AppColors.gold
                                  : const Color(0xFFD3A625),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        isBranch ? Icons.subdirectory_arrow_right : Icons.location_on,
                        size: compact ? 17 : 20,
                        color: isSelected || isBranch ? Colors.white : const Color(0xFFD3A625),
                      ),
                    ),
                    if (compact) ...[
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
                            color: Color(0xFF1F2937),
                            shadows: [
                              Shadow(color: Colors.white, blurRadius: 3),
                              Shadow(color: Colors.white, blurRadius: 6),
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
    if (_isInSubArea) return const SizedBox.shrink();

    final areas = _mapData.keys.toList();
    final idx = areas.indexOf(_currentArea);
    return Positioned(
      bottom: 104,
      left: 12,
      right: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (idx > 0) setState(() => _currentArea = areas[idx - 1]);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF3E5B4A).withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chevron_left, size: 20, color: Color(0xFF3E5B4A)),
                  const SizedBox(width: 6),
                  Text(areas.isEmpty ? '' : areas[(idx - 1 + areas.length) % areas.length],
                      style: const TextStyle(fontSize: 14, color: Color(0xFF3E5B4A), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFD3A625), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(_currentArea,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.goldBright)),
          ),
          GestureDetector(
            onTap: () {
              if (idx < areas.length - 1) setState(() => _currentArea = areas[idx + 1]);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF3E5B4A).withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(areas.isNotEmpty ? areas[(idx + 1) % areas.length] : '',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF3E5B4A), fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, size: 20, color: Color(0xFF3E5B4A)),
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
              border: Border.all(color: const Color(0xFFD3A625).withValues(alpha: 0.3), width: 1.5),
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
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
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
                          color: const Color(0xFF21262D),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18, color: Color(0xFF8B949E)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF30363D)),
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
                          backgroundColor: isBranch ? AppColors.warning : const Color(0xFFD3A625),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        onPressed: () {
                          if (isBranch) {
                            _enterSubArea(loc['name'] as String);
                          } else {
                            gp.travelTo(loc['name'] as String);
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
              ? const Color(0xFF1F2937)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFF1F2937)
                : const Color(0xFFD3A625).withValues(alpha: 0.55),
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
            color: isCurrent ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
      ),
    );
  }

  Widget _buildMapLegend() {
    return Positioned(
      left: 12,
      bottom: 280,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD3A625).withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFD3A625), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            const Text('当前', style: TextStyle(fontSize: 11, color: Color(0xFF5A6B4A), fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            const Text('子地图', style: TextStyle(fontSize: 11, color: Color(0xFF5A6B4A), fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Color(0xFFD3A625), width: 1.5))),
            const SizedBox(width: 5),
            const Text('地点', style: TextStyle(fontSize: 11, color: Color(0xFF5A6B4A), fontWeight: FontWeight.w500)),
          ],
        ),
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
    switch (subArea ?? area) {
      case '对角巷':
        _paintDiagonAlley(canvas, size);
        break;
      case '翻倒巷':
        _paintKnockturnAlley(canvas, size);
        break;
      default:
        _paintArea(canvas, size);
    }
  }

  void _paintArea(Canvas canvas, Size size) {
    final groundColor = area == '伦敦'
        ? const Color(0xFFA0825A).withValues(alpha: 0.25)
        : area == '住宅区'
            ? const Color(0xFFB8A88A).withValues(alpha: 0.3)
            : area == '霍格莫德村'
                ? const Color(0xFF8FA07A).withValues(alpha: 0.3)
                : const Color(0xFF5A6B4A).withValues(alpha: 0.3);

    final groundPaint = Paint()..color = groundColor..style = PaintingStyle.fill;
    final path1 = Path()
      ..moveTo(size.width * 0.15, size.height * 0.25)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.15, size.width * 0.55, size.height * 0.20)
      ..lineTo(size.width * 0.85, size.height * 0.22)
      ..quadraticBezierTo(size.width * 0.90, size.height * 0.40, size.width * 0.80, size.height * 0.45)
      ..lineTo(size.width * 0.50, size.height * 0.42)
      ..quadraticBezierTo(size.width * 0.30, size.height * 0.38, size.width * 0.15, size.height * 0.35)
      ..close();
    canvas.drawPath(path1, groundPaint);

    final hillColor = area == '霍格莫德村'
        ? const Color(0xFF5A6B50).withValues(alpha: 0.25)
        : area == '住宅区'
            ? const Color(0xFF8A9A7B).withValues(alpha: 0.2)
            : const Color(0xFF3E5B4A).withValues(alpha: 0.25);
    final hillPaint = Paint()..color = hillColor..style = PaintingStyle.fill;
    final hillPath = Path()
      ..moveTo(size.width * 0.05, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.48, size.width * 0.45, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.65, size.height * 0.60, size.width * 0.85, size.height * 0.52)
      ..lineTo(size.width * 0.95, size.height * 0.65)
      ..lineTo(size.width * 0.95, size.height * 0.85)
      ..lineTo(size.width * 0.05, size.height * 0.85)
      ..close();
    canvas.drawPath(hillPath, hillPaint);

    if (area != '伦敦') {
      final waterPaint = Paint()..color = const Color(0xFF4A6B8A).withValues(alpha: 0.35)..style = PaintingStyle.fill;
      final waterPath = Path()
        ..moveTo(size.width * 0.50, size.height * 0.62)
        ..quadraticBezierTo(size.width * 0.65, size.height * 0.60, size.width * 0.75, size.height * 0.68)
        ..lineTo(size.width * 0.70, size.height * 0.78)
        ..quadraticBezierTo(size.width * 0.55, size.height * 0.82, size.width * 0.45, size.height * 0.75)
        ..close();
      canvas.drawPath(waterPath, waterPaint);
    }

    final pathPaint = Paint()
      ..color = area == '伦敦' ? const Color(0xFF8A7B5A).withValues(alpha: 0.5) : const Color(0xFFC4A574).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.20, size.height * 0.30)
        ..quadraticBezierTo(size.width * 0.40, size.height * 0.50, size.width * 0.55, size.height * 0.55)
        ..quadraticBezierTo(size.width * 0.70, size.height * 0.58, size.width * 0.82, size.height * 0.40),
      pathPaint,
    );

    if (area != '伦敦') {
      final treePaint = Paint()..color = const Color(0xFF2D3E2A).withValues(alpha: 0.4)..style = PaintingStyle.fill;
      for (int i = 0; i < 12; i++) {
        final tx = (i * 0.083 + 0.05) * size.width;
        final ty = (0.75 + (i % 3) * 0.04) * size.height;
        canvas.drawCircle(Offset(tx, ty), 8 + (i % 3).toDouble() * 3, treePaint);
      }
    } else {
      final buildingPaint = Paint()..color = const Color(0xFF8A7B5A).withValues(alpha: 0.35)..style = PaintingStyle.fill;
      for (int i = 0; i < 8; i++) {
        final bx = (i * 0.12 + 0.08) * size.width;
        final bw = size.width * 0.06;
        final bh = size.height * (0.15 + (i % 3) * 0.08);
        canvas.drawRect(Rect.fromLTWH(bx, size.height * 0.55 - bh, bw, bh), buildingPaint);
      }
    }

    if (area == '住宅区') {
      final housePaint = Paint()..color = const Color(0xFFB88A6A).withValues(alpha: 0.3)..style = PaintingStyle.fill;
      for (int i = 0; i < 6; i++) {
        final hx = (i * 0.16 + 0.1) * size.width;
        final hy = size.height * (0.78 + (i % 2) * 0.05);
        canvas.drawRect(Rect.fromLTWH(hx, hy, size.width * 0.08, size.height * 0.06), housePaint);
        final roofPaint = Paint()..color = const Color(0xFF8A5A3A).withValues(alpha: 0.3)..style = PaintingStyle.fill;
        canvas.drawPath(
          Path()
            ..moveTo(hx - size.width * 0.01, hy)
            ..lineTo(hx + size.width * 0.04, hy - size.height * 0.03)
            ..lineTo(hx + size.width * 0.09, hy)
            ..close(),
          roofPaint,
        );
      }
    }

    if (area == '霍格莫德村') {
      final snowPaint = Paint()..color = const Color(0xFFFFFF).withValues(alpha: 0.2)..style = PaintingStyle.fill;
      for (int i = 0; i < 20; i++) {
        final sx = (i * 0.05 + 0.02) * size.width;
        final sy = (i * 0.047 + 0.03) * size.height;
        canvas.drawCircle(Offset(sx, sy), 2 + (i % 3).toDouble(), snowPaint);
      }
    }
  }

  void _paintDiagonAlley(Canvas canvas, Size size) {
    final groundPaint = Paint()..color = const Color(0xFF8A7B5A).withValues(alpha: 0.4)..style = PaintingStyle.fill;
    final groundPath = Path()
      ..moveTo(size.width * 0.05, size.height * 0.3)
      ..lineTo(size.width * 0.95, size.height * 0.3)
      ..lineTo(size.width * 0.95, size.height * 0.85)
      ..lineTo(size.width * 0.05, size.height * 0.85)
      ..close();
    canvas.drawPath(groundPath, groundPaint);

    final roadPaint = Paint()..color = const Color(0xFF6B5B3A).withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 8;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.05, size.height * 0.55)
        ..lineTo(size.width * 0.95, size.height * 0.55),
      roadPaint,
    );

    final shopPaint = Paint()..color = const Color(0xFFC4A574).withValues(alpha: 0.35)..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final sx = (i * 0.12 + 0.06) * size.width;
      final sy = size.height * 0.35;
      final sw = size.width * 0.08;
      final sh = size.height * 0.18;
      canvas.drawRect(Rect.fromLTWH(sx, sy, sw, sh), shopPaint);
    }
  }

  void _paintKnockturnAlley(Canvas canvas, Size size) {
    final groundPaint = Paint()..color = const Color(0xFF2A2530).withValues(alpha: 0.5)..style = PaintingStyle.fill;
    final groundPath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.30, size.width * 0.5, size.height * 0.40)
      ..lineTo(size.width * 0.70, size.height * 0.70)
      ..quadraticBezierTo(size.width * 0.50, size.height * 0.80, size.width * 0.30, size.height * 0.75)
      ..close();
    canvas.drawPath(groundPath, groundPaint);

    final wallPaint = Paint()..color = const Color(0xFF1A1520).withValues(alpha: 0.6)..style = PaintingStyle.fill;
    final wallPath = Path()
      ..moveTo(size.width * 0.05, size.height * 0.85)
      ..lineTo(size.width * 0.05, size.height * 0.25)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.20, size.width * 0.45, size.height * 0.30)
      ..lineTo(size.width * 0.50, size.height * 0.85)
      ..close();
    canvas.drawPath(wallPath, wallPaint);

    final wallPath2 = Path()
      ..moveTo(size.width * 0.95, size.height * 0.85)
      ..lineTo(size.width * 0.95, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.30, size.width * 0.55, size.height * 0.45)
      ..lineTo(size.width * 0.50, size.height * 0.85)
      ..close();
    canvas.drawPath(wallPath2, wallPaint);

    final glowPaint = Paint()..color = const Color(0xFF8B4A2A).withValues(alpha: 0.2)..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      final gx = (i * 0.2 + 0.15) * size.width;
      final gy = (0.55 + (i % 2) * 0.15) * size.height;
      canvas.drawCircle(Offset(gx, gy), 15 + (i % 3).toDouble() * 5, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MapAreaPainter oldDelegate) {
    return oldDelegate.area != area || oldDelegate.subArea != subArea;
  }
}