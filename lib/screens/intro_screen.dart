// ignore_for_file: curly_braces_in_flow_control_structures, avoid_unnecessary_containers

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/game_provider.dart';
import '../data/wand_data.dart';

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
    '第九轮 · 天赋专精',
    '第十轮 · 宠物',
    '第十一轮 · 好友关系',
    '第十二轮 · 剧情起点',
    '第十三轮 · 最终确认',
  ];

  // 1. 时代
  int _eraIndex = 2;
  static const List<String> _eraOptions = ['邓布利多时代', '亲世代', '子世代', '现代', '随机'];
  static const List<String> _eraDescriptions = [
    '1892-1899 · 少年邓布利多与格林德沃',
    '1971-1978 · 掠夺者四人组时代',
    '1991-1998 · 哈利·波特求学时代',
    '2020+ · 战后重建的魔法世界',
    '随机时代，充满惊喜',
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

  // 4. 家族与血统
  String _bloodStatus = 'muggleborn';
  String _familyBackground = '出生于普通麻瓜家庭';
  static const List<String> _bloodOptions = ['muggleborn', 'halfblood', 'pureblood', 'special'];
  static const Map<String, String> _bloodLabels = {
    'muggleborn': '麻瓜出身',
    'halfblood': '混血',
    'pureblood': '纯血',
    'special': '特殊家庭',
  };
  static const List<String> _familyOptions = [
    '出生于普通麻瓜家庭，父母都是医生',
    '母亲是巫师，父亲是麻瓜',
    '传承已久的纯血家族，家规森严',
    '父母都是强大巫师，家族在魔法部有影响力',
    '孤儿，在孤儿院长大',
    '出生于魔法家庭，但家境普通',
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

  // 10. 宠物
  String? _petId;
  String? _petName;
  static const List<String> _petOptions = [
    '猫头鹰（送信、探索的好伙伴）',
    '猫（神秘而独立）',
    '蟾蜍（传统而忠诚）',
    '老鼠（小巧机灵）',
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
    if (!_validateCurrentStep()) return;
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

    const eraMap = [
      Era.dumbledore,
      Era.marauders,
      Era.harry_same,
      Era.post_war,
      Era.random,
    ];
    appProvider.setEra(eraMap[_eraIndex]);

    String? petName;
    if (_petId != null && _petName == null) {
      switch (_petId) {
        case 'owl':
          petName = '雪鸮';
          break;
        case 'cat':
          petName = '猫';
          break;
        case 'toad':
          petName = '蟾蜍';
          break;
        case 'rat':
          petName = '老鼠';
          break;
      }
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
    );

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/game');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建你的魔法人生'),
        backgroundColor: Colors.transparent,
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
          const Text('血统', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _bloodOptions.map((val) {
              final selected = _bloodStatus == val;
              return FilterChip(
                label: Text(_bloodLabels[val]!, style: TextStyle(color: selected ? Colors.white : Colors.white70)),
                selected: selected,
                onSelected: (_) => setState(() => _bloodStatus = val),
                backgroundColor: const Color(0xFF21262d),
                selectedColor: const Color(0xFF740001),
                side: BorderSide(color: selected ? const Color(0xFFD3A625) : const Color(0xFF30363d)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('家族背景', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final f in _familyOptions)
            _buildRadioCard(
              title: f,
              selected: _familyBackground == f,
              onTap: () => setState(() => _familyBackground = f),
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
      '天赋专精',
      '你与生俱来的闪光点。',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final t in _talentOptions)
            _buildRadioCard(
              title: t,
              selected: _talent == t,
              onTap: () => setState(() => _talent = t),
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
                _petName = i == 4 ? null : _petOptions[i].split('（').first;
              }),
            ),
        ],
      ),
    );
  }

  static const List<String?> _petOptionIds = ['owl', 'cat', 'toad', 'rat', null];

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
          _buildSummaryRow('血统', _bloodLabels[_bloodStatus]!),
          _buildSummaryRow('家族', _familyBackground),
          _buildSummaryRow('外貌', _appearance),
          _buildSummaryRow('童年', _selectedChildhood.join('；')),
          _buildSummaryRow('性格', _selectedTraits.join('、')),
          _buildSummaryRow('信仰', _beliefs),
          _buildSummaryRow('魔杖', wand?.name ?? '未选择'),
          _buildSummaryRow('天赋', _talent),
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
        color: selected ? const Color(0xFF740001).withValues(alpha: 0.3) : const Color(0xFF21262d),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? const Color(0xFFD3A625) : const Color(0xFF30363d),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? const Color(0xFFD3A625) : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
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
