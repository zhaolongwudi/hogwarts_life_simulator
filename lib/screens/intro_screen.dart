import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/game_provider.dart';
import '../data/wand_data.dart';
import '../data/political_stance.dart';
import '../data/blood_status.dart';
import '../data/pet_data.dart';

/// 十三轮初始设定流程
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _step = 0;

  // ===== 十三轮设定数据 =====
  static const List<String> _stepTitles = [
    '第一轮 · 时代',
    '第二轮 · 姓名与身份',
    '第三轮 · 外貌与体格',
    '第四轮 · 家族与血统',
    '第五轮 · 童年经历',
    '第六轮 · 性格特质',
    '第七轮 · 信仰与价值观',
    '第八轮 · 魔杖',
    '第九轮 · 天赋与资质',
    '第十轮 · 宠物',
    '第十一轮 · 好友关系',
    '第十二轮 · 剧情起点',
    '第十三轮 · 最终确认',
  ];

  // 1. 时代（第75章启动界面 · 8个时代选项）
  int _eraIndex = 4;
  static const List<String> _eraOptions = [
    '霍格沃茨建校早期',
    '中世纪猎巫时期',
    '格林德沃崛起时代',
    '第一次巫师战争',
    '第二次巫师战争',
    '战后重建时代',
    '现代巫师社会',
    '自定义时代',
  ];
  static const List<String> _eraDescriptions = [
    '约990年 · 四位创始人建校时代',
    '1692年前后 · 《国际保密法》实施',
    '1920s-1945 · 格林德沃席卷欧洲',
    '1970s · 伏地魔崛起，社会紧张',
    '1995-1998 · 伏地魔复活，全面战争',
    '1998-2010s · 战后重建，新秩序建立',
    '2020+ · 阿不思·波特时代',
    '由玩家自定义时代背景',
  ];

  // 2. 姓名与身份
  final _nameController = TextEditingController();
  String _gender = '男';
  String _sexOrientation = '女';
  static const List<String> _genderOptions = ['男', '女'];

  // 3. 外貌与体格
  String _appearance = '相貌清秀，黑发，中等身高';
  static const List<String> _appearanceOptions = [
    '相貌清秀，黑发，中等身高',
    '红发，雀斑，瘦高',
    '金发，面容精致，略显高傲',
    '深色卷发，皮肤偏黑，健壮',
    '棕发，圆脸，朴实温和',
    '银白色头发，异色瞳，神秘气质',
  ];

  // 4. 家族与血统（第75章 · 11个血统选项）
  String _bloodStatus = 'muggleborn';
  String _familyBackground = '出生于普通麻瓜家庭';
  // 血统可选项 / 标签 / 说明统一放在 lib/data/blood_status.dart —— 游戏内
  // 文案（状态栏、档案、AI prompt）读的是同一张表，问卷里再手抄一份迟早
  // 对不上（原来这里「默然者」就比游戏内多带了个「（高风险）」）。
  // 注意标签要走 bloodStatusOptionLabel：只有它才给高风险血统加标注，
  // 而那个标注只属于问卷 UI，不能混进存档文案。
  // 出生身份（第75章）
  String _birthIdentity = '普通巫师家庭';
  static const List<String> _birthIdentityOptions = [
    '普通巫师家庭', '麻瓜家庭', '孤儿', '纯血没落家族',
    '纯血豪门', '魔法部官员家庭', '傲罗家庭', '教授家庭',
    '古灵阁妖精契约相关', '圣芒戈治疗师家庭', '自定义',
  ];

  // 5. 童年经历（选3项）
  static const List<String> _childhoodOptions = [
    '曾在花园里让玩具自己飘起来',
    '误把邻居家的窗户变蓝了',
    '发现能和动物说话',
    '曾坠入深井却安然无恙',
    '在阁楼发现一本古老的魔法书',
    '曾在雷雨中安然入睡，梦境能成真',
    '收养过一只受伤的猫头鹰',
    '曾让蜡烛自己熄灭后点燃',
    '在森林里迷路三天后自己走回来',
  ];
  final List<String> _selectedChildhood = [];

  // 6. 性格特质（选3-5个）
  static const List<String> _traits = [
    '勇敢', '聪明', '善良', '野心', '谨慎',
    '幽默', '内向', '叛逆', '温柔', '倔强',
    '好奇', '忠诚', '独立', '乐观', '敏感',
  ];
  final List<String> _selectedTraits = [];

  // 7. 信仰与价值观
  String _beliefs = '崇尚知识与正义，相信选择比血统更重要';
  static const List<String> _beliefsOptions = [
    '崇尚知识与正义，相信选择比血统更重要',
    '家族荣誉高于一切，血统决定命运',
    '自由与冒险，规则是束缚',
    '善恶有报，因果循环',
    '力量与掌控，弱者无生存空间',
    '没有绝对的对错，只看立场',
  ];

  // 8. 魔杖
  String? _selectedWandId;

  // 9. 天赋专精
  String _talent = '魔咒学天赋';
  static const List<String> _talentOptions = [
    '魔咒学天赋',
    '变形术天赋',
    '魔药学天赋',
    '草药学天赋',
    '黑魔法防御天赋',
    '魁地奇天赋',
    '心灵与直觉天赋',
    '领导力天赋',
  ];

  // 9b. 魔法资质（第75章）
  String _magicAptitude = '良好';
  static const List<String> _magicAptitudeOptions = [
    '哑炮·无魔法天赋',
    '普通',
    '良好',
    '优秀',
    '特殊（易容马格斯/蛇佬腔/预言天分/变形天赋/大脑封闭术天赋）',
    '随机',
  ];

  // 9c. 学院倾向（第75章）
  String _housePreference = '系统判定';
  static const List<String> _housePreferenceOptions = [
    '系统判定',
    '格兰芬多（勇气·胆识·骑士精神）',
    '斯莱特林（野心·血统·精明·意志）',
    '拉文克劳（智慧·知识·创造力·好奇）',
    '赫奇帕奇（忠诚·勤勉·公平·坚韧）',
    '未入学/成年/其他学校',
  ];

  // 9d. 初始政治倾向（第75章）
  String _politicalTendency = kPoliticalStanceNames.first;
  static const List<String> _politicalOptions = kPoliticalStanceNames;

  // 9e. 模拟风格（第75章）
  String _simulationStyle = '混合模式';
  static const List<String> _simulationStyleOptions = [
    '极度现实',
    '经典校园冒险',
    '史诗巫师战争',
    '黑暗奇幻',
    '日常人生',
    '混合模式',
  ];

  // 10. 宠物
  String? _petId;
  String? _petName;
  static const List<String> _petOptions = [
    '猫头鹰（送信、探索的好伙伴）',
    '猫（神秘而独立）',
    '蟾蜍（传统而忠诚）',
    '老鼠（小巧机灵）',
    '九尾灵狐·绯月（东方传说，可化人形，倾国倾城，听命于你）',
    '不养宠物',
  ];

  // 11. 好友关系（初始好感度最高的NPC）
  String _friendChoice = '随机';
  static const List<String> _friendOptions = ['随机', '同学院同学', '跨学院朋友', '高年级学长/学姐'];

  // 12. 剧情起点
  String _startPoint = '收到录取通知书的那一刻';
  static const List<String> _startPointOptions = [
    '收到录取通知书的那一刻',
    '在九又四分之三站台踏上列车',
    '第一次踏入霍格沃茨大礼堂',
    '分院仪式前夜',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _next() {
    if (!_validateCurrentStep()) {
      return;
    }
    if (_step < 12) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _startGame();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_step) {
      case 1:
        if (_nameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请输入你的名字')),
          );
          return false;
        }
        return true;
      case 5:
        if (_selectedChildhood.length < 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请选择3项童年经历')),
          );
          return false;
        }
        return true;
      case 6:
        if (_selectedTraits.length < 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请选择3-5个性格特质')),
          );
          return false;
        }
        return true;
      case 8:
        if (_selectedWandId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请选择一根魔杖')),
          );
          return false;
        }
        return true;
    }
    return true;
  }

  Future<void> _startGame() async {
    final gameProvider = context.read<GameProvider>();
    final appProvider = context.read<AppProvider>();

    // 时代映射（第75章8选项 → Era枚举）
    const eraMap = [
      Era.dumbledore,       // 霍格沃茨建校早期 → 映射到最早的可用时代
      Era.dumbledore,       // 中世纪猎巫时期
      Era.dumbledore,       // 格林德沃崛起时代
      Era.first_war,        // 第一次巫师战争
      Era.harry_same,       // 第二次巫师战争
      Era.post_war,         // 战后重建时代
      Era.post_war,         // 现代巫师社会
      Era.random,           // 自定义时代
    ];
    appProvider.setEra(eraMap[_eraIndex]);

    // 默认名字统一走 kPetDefaultNames——对角巷买宠物用的是同一张表，
    // 免得问卷里叫「猫」、买回来叫「巫师猫」。
    String? petName;
    if (_petId != null && _petName == null) {
      petName = kPetDefaultNames[_petId];
    }

    String _openingSceneKey = 'station';
    switch (_startPoint) {
      case '收到录取通知书的那一刻':
        _openingSceneKey = 'letter';
        break;
      case '在九又四分之三站台踏上列车':
        _openingSceneKey = 'station';
        break;
      case '第一次踏入霍格沃茨大礼堂':
        _openingSceneKey = 'hall';
        break;
      case '分院仪式前夜':
        _openingSceneKey = 'eve';
        break;
    }

    await gameProvider.initializeGame(
      name: _nameController.text.trim(),
      bloodStatus: _bloodStatus,
      birthLocation: _familyBackground.contains('伦敦') ? '伦敦' : '英国',
      personalityTraits: _selectedTraits,
      gender: _gender,
      sexOrientation: _sexOrientation,
      appearance: _appearance,
      familyBackground: _familyBackground,
      childhoodExperiences: _selectedChildhood,
      beliefs: _beliefs,
      wandId: _selectedWandId,
      petId: _petId,
      petName: petName,
      initialTalent: _talent,
      magicAptitude: _magicAptitude,
      housePreference: _housePreference,
      politicalTendency: _politicalTendency,
      simulationStyle: _simulationStyle,
      birthIdentity: _birthIdentity,
      openingScene: _openingSceneKey,
    );

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/game');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建你的魔法人生'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _step = i),
              children: [
                _buildEraStep(),
                _buildIdentityStep(),
                _buildAppearanceStep(),
                _buildFamilyStep(),
                _buildChildhoodStep(),
                _buildTraitsStep(),
                _buildBeliefsStep(),
                _buildWandStep(),
                _buildTalentStep(),
                _buildPetStep(),
                _buildFriendStep(),
                _buildStartStep(),
                _buildConfirmStep(),
              ],
            ),
          ),
          _buildNavButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Text(
            '${_step + 1}/13',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LinearProgressIndicator(
              value: (_step + 1) / 13,
              backgroundColor: const Color(0xFF21262d),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFD3A625)),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _stepTitles[_step],
            style: const TextStyle(fontSize: 12, color: Color(0xFFD3A625)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButtons() {
    final canProceed = _canProceed();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _back,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('上一步'),
                ),
              ),
            if (_step > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: canProceed ? _next : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canProceed ? const Color(0xFF740001) : const Color(0xFF484f58),
                  disabledBackgroundColor: const Color(0xFF484f58),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  _step == 12 ? '🪄 开启魔法人生' : '下一步',
                  style: TextStyle(color: canProceed ? Colors.white : Colors.white38),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canProceed() {
    switch (_step) {
      case 1:
        return _nameController.text.trim().isNotEmpty;
      case 5:
        return _selectedChildhood.length >= 3;
      case 6:
        return _selectedTraits.length >= 3;
      case 8:
        return _selectedWandId != null;
      default:
        return true;
    }
  }

  // ==================== 第一轮 · 时代 ====================
  Widget _buildEraStep() {
    return _buildStepShell(
      '选择你所在的时代',
      '时代的浪潮将塑造你的命运。',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (int i = 0; i < _eraOptions.length; i++)
            _buildRadioCard(
              title: _eraOptions[i],
              subtitle: _eraDescriptions[i],
              selected: _eraIndex == i,
              onTap: () => setState(() => _eraIndex = i),
            ),
        ],
      ),
    );
  }

  // ==================== 第二轮 · 姓名与身份 ====================
  Widget _buildIdentityStep() {
    return _buildStepShell(
      '你的名字与身份',
      '名字将伴随你的整个魔法人生。',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '你的名字',
              hintText: '输入巫师名字...',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          const Text('性别', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _genderOptions.map((g) {
              final selected = _gender == g;
              return FilterChip(
                label: Text(g, style: TextStyle(color: selected ? Colors.white : Colors.white70)),
                selected: selected,
                onSelected: (_) => setState(() {
                  _gender = g;
                  _sexOrientation = g == '男' ? '女' : '男';
                }),
                backgroundColor: const Color(0xFF21262d),
                selectedColor: const Color(0xFF740001),
                side: BorderSide(color: selected ? const Color(0xFFD3A625) : const Color(0xFF30363d)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('性取向（默认异性）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['女', '男', '双性'].map((s) {
              final selected = _sexOrientation == s;
              return FilterChip(
                label: Text(s, style: TextStyle(color: selected ? Colors.black : Colors.white70)),
                selected: selected,
                onSelected: (_) => setState(() => _sexOrientation = s),
                backgroundColor: const Color(0xFF21262d),
                selectedColor: const Color(0xFFD3A625),
                side: BorderSide(color: selected ? const Color(0xFFD3A625) : const Color(0xFF30363d)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ==================== 第三轮 · 外貌与体格 ====================
  Widget _buildAppearanceStep() {
    return _buildStepShell(
      '外貌与体格',
      '第一印象往往很重要。',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final a in _appearanceOptions)
            _buildRadioCard(
              title: a,
              selected: _appearance == a,
              onTap: () => setState(() => _appearance = a),
            ),
        ],
      ),
    );
  }

  // ==================== 第四轮 · 家族与血统 ====================
  Widget _buildFamilyStep() {
    return _buildStepShell(
      '家族与血统',
      '血统决定你的起点，但决定不了你的终点。',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('血统/出身', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kBloodStatusOptions.map((val) {
              final selected = _bloodStatus == val;
              return FilterChip(
                label: Text(bloodStatusOptionLabel(val), style: TextStyle(color: selected ? Colors.white : Colors.white70)),
                selected: selected,
                onSelected: (_) => setState(() => _bloodStatus = val),
                backgroundColor: const Color(0xFF21262d),
                selectedColor: const Color(0xFF740001),
                side: BorderSide(color: selected ? const Color(0xFFD3A625) : const Color(0xFF30363d)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
          if (kBloodStatusDescriptions[_bloodStatus] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFD3A625).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD3A625).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFD3A625)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kBloodStatusDescriptions[_bloodStatus]!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFD3A625)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text('出生身份', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _birthIdentityOptions.map((val) {
              final selected = _birthIdentity == val;
              return FilterChip(
                label: Text(val, style: TextStyle(color: selected ? Colors.black : Colors.white70)),
                selected: selected,
                onSelected: (_) => setState(() => _birthIdentity = val),
                backgroundColor: const Color(0xFF21262d),
                selectedColor: const Color(0xFFD3A625),
                side: BorderSide(color: selected ? const Color(0xFFD3A625) : const Color(0xFF30363d)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ==================== 第五轮 · 童年经历 ====================
  Widget _buildChildhoodStep() {
    return _buildStepShell(
      '童年经历（选3项）',
      '你童年中那些无法解释的瞬间，是魔法的第一次回响。',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _childhoodOptions.map((c) {
              final selected = _selectedChildhood.contains(c);
              return FilterChip(
                label: Text(
                  c,
                  style: TextStyle(color: selected ? Colors.black : Colors.white70),
                ),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      if (_selectedChildhood.length < 3) _selectedChildhood.add(c);
                    } else {
                      _selectedChildhood.remove(c);
                    }
                  });
                },
                backgroundColor: const Color(0xFF21262d),
                selectedColor: const Color(0xFFD3A625),
                side: BorderSide(color: selected ? const Color(0xFFD3A625) : const Color(0xFF30363d)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            '已选: ${_selectedChildhood.length}/3',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // ==================== 第六轮 · 性格特质 ====================
  Widget _buildTraitsStep() {
    return _buildStepShell(
      '性格特质（选3-5个）',
      '性格决定你如何面对命运。',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _traits.map((trait) {
              final selected = _selectedTraits.contains(trait);
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      const Icon(Icons.check, size: 16, color: Colors.black),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      trait,
                      style: TextStyle(color: selected ? Colors.black : Colors.white70),
                    ),
                  ],
                ),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      if (_selectedTraits.length < 5) _selectedTraits.add(trait);
                    } else {
                      _selectedTraits.remove(trait);
                    }
                  });
                },
                backgroundColor: const Color(0xFF21262d),
                selectedColor: const Color(0xFFD3A625),
                side: BorderSide(color: selected ? const Color(0xFFD3A625) : const Color(0xFF30363d)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            '已选: ${_selectedTraits.length}/5',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // ==================== 第七轮 · 信仰与价值观 ====================
  Widget _buildBeliefsStep() {
    return _buildStepShell(
      '信仰与价值观',
      '在最黑暗的时刻，是什么指引着你？',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final b in _beliefsOptions)
            _buildRadioCard(
              title: b,
              selected: _beliefs == b,
              onTap: () => setState(() => _beliefs = b),
            ),
        ],
      ),
    );
  }

  // ==================== 第八轮 · 魔杖 ====================
  Widget _buildWandStep() {
    return _buildStepShell(
      '选择你的魔杖',
      '魔杖选择巫师，巫师亦选择魔杖。',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final w in wands)
            _buildRadioCard(
              title: w.name,
              subtitle: '${w.length} · ${w.description}',
              selected: _selectedWandId == w.id,
              onTap: () => setState(() => _selectedWandId = w.id),
            ),
        ],
      ),
    );
  }

  // ==================== 第九轮 · 天赋专精 ====================
  Widget _buildTalentStep() {
    return _buildStepShell(
      '天赋与资质',
      '你的天赋、魔法资质、学院倾向与政治立场。',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('天赋专精', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _talentOptions.map((t) {
              final selected = _talent == t;
              return FilterChip(
                label: Text(t, style: TextStyle(color: selected ? Colors.white : Colors.white70)),
                selected: selected,
                onSelected: (_) => setState(() => _talent = t),
                backgroundColor: const Color(0xFF21262d),
                selectedColor: const Color(0xFF740001),
                side: BorderSide(color: selected ? const Color(0xFFD3A625) : const Color(0xFF30363d)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('魔法资质', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _magicAptitudeOptions.map((a) {
              final selected = _magicAptitude == a;
              return FilterChip(
                label: Text(a, style: TextStyle(color: selected ? Colors.black : Colors.white70, fontSize: 12)),
                selected: selected,
                onSelected: (_) => setState(() => _magicAptitude = a),
                backgroundColor: const Color(0xFF21262d),
                selectedColor: const Color(0xFFD3A625),
                side: BorderSide(color: selected ? const Color(0xFFD3A625) : const Color(0xFF30363d)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('学院倾向', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _housePreferenceOptions.map((h) {
              final selected = _housePreference == h;
              return FilterChip(
                label: Text(h, style: TextStyle(color: selected ? Colors.black : Colors.white70, fontSize: 12)),
                selected: selected,
                onSelected: (_) => setState(() => _housePreference = h),
                backgroundColor: const Color(0xFF21262d),
                selectedColor: const Color(0xFFD3A625),
                side: BorderSide(color: selected ? const Color(0xFFD3A625) : const Color(0xFF30363d)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('初始政治倾向', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _politicalOptions.map((p) {
              final selected = _politicalTendency == p;
              return FilterChip(
                label: Text(p, style: TextStyle(color: selected ? Colors.black : Colors.white70)),
                selected: selected,
                onSelected: (_) => setState(() => _politicalTendency = p),
                backgroundColor: const Color(0xFF21262d),
                selectedColor: const Color(0xFFD3A625),
                side: BorderSide(color: selected ? const Color(0xFFD3A625) : const Color(0xFF30363d)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('模拟风格', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _simulationStyleOptions.map((s) {
              final selected = _simulationStyle == s;
              return FilterChip(
                label: Text(s, style: TextStyle(color: selected ? Colors.black : Colors.white70)),
                selected: selected,
                onSelected: (_) => setState(() => _simulationStyle = s),
                backgroundColor: const Color(0xFF21262d),
                selectedColor: const Color(0xFFD3A625),
                side: BorderSide(color: selected ? const Color(0xFFD3A625) : const Color(0xFF30363d)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ==================== 第十轮 · 宠物 ====================
  Widget _buildPetStep() {
    return _buildStepShell(
      '选择宠物',
      '一位忠实的伙伴。',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (int i = 0; i < _petOptions.length; i++)
            _buildRadioCard(
              title: _petOptions[i],
              selected: _petId == _petOptionIds[i],
              onTap: () => setState(() {
                _petId = _petOptionIds[i];
                _petName = i == 5 ? null : _petOptions[i].split('（').first;
              }),
            ),
        ],
      ),
    );
  }

  static const List<String?> _petOptionIds = ['owl', 'cat', 'toad', 'rat', 'kyuubi', null];

  // ==================== 第十一轮 · 好友关系 ====================
  Widget _buildFriendStep() {
    return _buildStepShell(
      '初始好友',
      '在魔法世界，朋友是比魔杖更珍贵的财富。',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final f in _friendOptions)
            _buildRadioCard(
              title: f,
              selected: _friendChoice == f,
              onTap: () => setState(() => _friendChoice = f),
            ),
        ],
      ),
    );
  }

  // ==================== 第十二轮 · 剧情起点 ====================
  Widget _buildStartStep() {
    return _buildStepShell(
      '剧情起点',
      '你的故事从哪一刻开始？',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final s in _startPointOptions)
            _buildRadioCard(
              title: s,
              selected: _startPoint == s,
              onTap: () => setState(() => _startPoint = s),
            ),
        ],
      ),
    );
  }

  // ==================== 第十三轮 · 最终确认 ====================
  Widget _buildConfirmStep() {
    final wand = _selectedWandId != null ? wandById(_selectedWandId!) : null;
    return _buildStepShell(
      '最终确认',
      '你的命运即将书写。',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryRow('时代', _eraOptions[_eraIndex]),
          _buildSummaryRow('姓名', _nameController.text.trim()),
          _buildSummaryRow('性别', _gender),
          _buildSummaryRow('血统', bloodStatusOptionLabel(_bloodStatus)),
          _buildSummaryRow('出生身份', _birthIdentity),
          _buildSummaryRow('外貌', _appearance),
          _buildSummaryRow('童年', _selectedChildhood.join('；')),
          _buildSummaryRow('性格', _selectedTraits.join('、')),
          _buildSummaryRow('信仰', _beliefs),
          _buildSummaryRow('魔杖', wand?.name ?? '未选择'),
          _buildSummaryRow('天赋', _talent),
          _buildSummaryRow('魔法资质', _magicAptitude),
          _buildSummaryRow('学院倾向', _housePreference),
          _buildSummaryRow('政治倾向', _politicalTendency),
          _buildSummaryRow('模拟风格', _simulationStyle),
          _buildSummaryRow('宠物', _petName ?? '无'),
          _buildSummaryRow('好友', _friendChoice),
          _buildSummaryRow('起点', _startPoint),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStepShell(String title, String subtitle, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildRadioCard({
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? const Color(0xFF740001).withValues(alpha: 0.25)
            : const Color(0xFF21262d),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? const Color(0xFFD3A625) : const Color(0xFF30363d),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? const Color(0xFFD3A625) : const Color(0xFF8B949E),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          color: selected ? Colors.white : const Color(0xFFE6EDF3),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
