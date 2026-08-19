import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthLocationController = TextEditingController();
  
  String _bloodStatus = 'muggleborn';
  final List<String> _selectedTraits = [];
  
  static const List<String> _bloodOptions = [
    'muggleborn', 'halfblood', 'pureblood', 'special'
  ];
  static const Map<String, String> _bloodLabels = {
    'muggleborn': '麻瓜出身',
    'halfblood': '混血',
    'pureblood': '纯血',
    'special': '特殊家庭',
  };
  
  static const List<String> _traits = [
    '勇敢', '聪明', '善良', '野心', '谨慎',
    '幽默', '内向', '叛逆', '温柔', '倔强',
    '好奇', '忠诚', '独立', '乐观', '敏感',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _birthLocationController.dispose();
    super.dispose();
  }

  Future<void> _startGame() async {
    if (!_formKey.currentState!.validate()) return;

    final gameProvider = context.read<GameProvider>();
    await gameProvider.initializeGame(
      name: _nameController.text.trim(),
      bloodStatus: _bloodStatus,
      birthLocation: _birthLocationController.text.trim() ?? '英国',
      personalityTraits: _selectedTraits,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '你的名字',
                  hintText: '输入巫师名字...',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => (v?.isEmpty ?? true) ? '请输入名字' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _birthLocationController,
                decoration: const InputDecoration(
                  labelText: '出生地',
                  hintText: '例如：伦敦、爱丁堡、科茨沃尔德...',
                  prefixIcon: Icon(Icons.location_on),
                ),
                initialValue: '英国',
              ),
              const SizedBox(height: 24),
              
              const Text('血统背景',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _bloodOptions.map((val) {
                  final selected = val == _bloodStatus;
                  return FilterChip(
                    label: Text(_bloodLabels[val]!),
                    selected: selected,
                    onSelected: (v) => setState(() => _bloodStatus = val),
                    backgroundColor: const Color(0xFF21262d),
                    selectedColor: const Color(0xFF740001),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              
              const Text('性格特质（选3-5个）',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _traits.map((trait) {
                  final selected = _selectedTraits.contains(trait);
                  return FilterChip(
                    label: Text(trait),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          if (_selectedTraits.length < 5)
                            _selectedTraits.add(trait);
                        } else {
                          _selectedTraits.remove(trait);
                        }
                      });
                    },
                    backgroundColor: const Color(0xFF21262d),
                    selectedColor: const Color(0xFFD3A625),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                '已选: ${_selectedTraits.length}/5',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startGame,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('🪄 开始魔法人生', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
