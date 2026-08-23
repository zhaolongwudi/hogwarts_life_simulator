import 'package:flutter/material.dart';
import '../../providers/app_provider.dart';

class SettingsProviderCard extends StatefulWidget {
  final AiProvider provider;
  final AppProvider appProvider;
  final TextEditingController keyController;
  final TextEditingController modelController;
  final bool testing;
  final String? testResult;
  final bool? testSuccess;
  final VoidCallback? onSave;
  final VoidCallback? onTest;
  final void Function(String model)? onModelPresetSelected;

  const SettingsProviderCard({
    super.key,
    required this.provider,
    required this.appProvider,
    required this.keyController,
    required this.modelController,
    required this.testing,
    this.testResult,
    this.testSuccess,
    this.onSave,
    this.onTest,
    this.onModelPresetSelected,
  });

  @override
  State<SettingsProviderCard> createState() => _SettingsProviderCardState();
}

class _SettingsProviderCardState extends State<SettingsProviderCard> {
  String defaultBaseUrl(AiProvider p) {
    switch (p) {
      case AiProvider.deepseek:
        return 'https://api.deepseek.com';
      case AiProvider.agnes:
        return 'https://api.agnes-ai.cn';
      case AiProvider.sensenova:
        return 'https://token.sensenova.cn';
    }
  }

  String defaultModel(AiProvider p) {
    switch (p) {
      case AiProvider.deepseek:
        return 'deepseek-v4-flash';
      case AiProvider.agnes:
        return 'agnes-2.5-flash';
      case AiProvider.sensenova:
        return 'sensenova-6.7-flash-lite';
    }
  }

  String providerNameLabel(AiProvider p) {
    switch (p) {
      case AiProvider.deepseek:
        return 'DeepSeek';
      case AiProvider.agnes:
        return 'Agnes';
      case AiProvider.sensenova:
        return 'SenseNova';
    }
  }

  Widget _buildModelPresets(AiProvider p, AppProvider appProvider) {
    final freeModels = appProvider.freeModelsFor(p);
    final paidModels = appProvider.popularPaidModelsFor(p);
    final current = widget.modelController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (freeModels.isNotEmpty)
          _buildModelChipRow(p, '🎁 免费额度', freeModels, current, const Color(0xFF10B981)),
        if (freeModels.isNotEmpty && paidModels.isNotEmpty) const SizedBox(height: 6),
        if (paidModels.isNotEmpty)
          _buildModelChipRow(p, '⭐ 推荐付费', paidModels, current, const Color(0xFFD3A625)),
      ],
    );
  }

  Widget _buildModelChipRow(AiProvider p, String label, List<String> models, String current, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: models.map((model) {
            final selected = current == model;
            return GestureDetector(
              onTap: () {
                widget.modelController.text = model;
                widget.onModelPresetSelected?.call(model);
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.18)
                      : const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? accent : const Color(0xFF30363D),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  model,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: selected ? accent : const Color(0xFFC9D1D9),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final hasKey = widget.appProvider.hasKey(p);
    final desc = kProviderDescriptions[p] ?? '';
    final testResult = widget.testResult;
    final testSuccess = widget.testSuccess;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252C36),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasKey ? const Color(0xFF10B981) : const Color(0xFF374151),
          width: hasKey ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  providerNameLabel(p),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              if (hasKey)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text('已配置', style: TextStyle(fontSize: 11, color: Color(0xFF10B981))),
                  ],
                )
              else
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 14, color: Colors.orange),
                    SizedBox(width: 4),
                    Text('未配置', style: TextStyle(fontSize: 11, color: Colors.orange)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc,
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11.5, height: 1.4)),
          const SizedBox(height: 8),
          const Text('API Key',
              style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.keyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'sk-...',
                    helperText: '获取地址: ${defaultBaseUrl(p)}',
                    helperStyle: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: widget.onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD3A625),
                    foregroundColor: const Color(0xFF1C232D),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text('保存', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('模型（可选覆盖默认）',
              style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.modelController,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: defaultModel(p),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: OutlinedButton(
                  onPressed: widget.testing ? null : widget.onTest,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD3A625)),
                    foregroundColor: const Color(0xFFD3A625),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 40),
                  ),
                  child: widget.testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD3A625)),
                        )
                      : const Text('测试', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildModelPresets(p, widget.appProvider),
          if (testResult != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (testSuccess ?? false)
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    (testSuccess ?? false) ? Icons.check_circle : Icons.error,
                    size: 14,
                    color: (testSuccess ?? false) ? const Color(0xFF10B981) : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      testResult,
                      style: TextStyle(
                        fontSize: 11,
                        color: (testSuccess ?? false) ? const Color(0xFF10B981) : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
