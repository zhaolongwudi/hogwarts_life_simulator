import 'package:flutter/material.dart';
import '../../data/provider_defaults.dart';
import '../../providers/app_provider.dart';

/// AI 提供商配置卡片（可折叠）。
/// 收起态：提供商名称 + 一句话定位 + 当前模型 + 配置状态，一眼总览。
/// 展开态：完整说明 + API Key（可切换明文）+ 模型预设 + 自定义模型 + 连接测试。
/// 未配置 Key 的提供商默认展开，引导用户先完成配置。
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
  late bool _expanded;
  bool _obscureKey = true;
  bool _obscureAdditionalKeys = true;

  /// 额外 API Key 的控制器（第一个 key 使用 widget.keyController）
  final List<TextEditingController> _additionalKeyControllers = [];

  @override
  void initState() {
    super.initState();
    // 未配置的提供商默认展开，引导填写；已配置的收起保持页面整洁
    _expanded = !widget.appProvider.hasKey(widget.provider);
    // 模型输入变化时同步刷新收起态头部显示的"当前模型"
    widget.modelController.addListener(_onModelTextChanged);
    // 同步已有额外 key
    _syncAdditionalKeyControllers();
  }

  @override
  void didUpdateWidget(covariant SettingsProviderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当 AppProvider 的数据变化时，同步额外 key 控制器
    if (oldWidget.appProvider != widget.appProvider) {
      _syncAdditionalKeyControllers();
    }
  }

  @override
  void dispose() {
    widget.modelController.removeListener(_onModelTextChanged);
    for (final c in _additionalKeyControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onModelTextChanged() {
    if (mounted) setState(() {});
  }

  /// 将 AppProvider 中的额外 key 同步到本地控制器
  void _syncAdditionalKeyControllers() {
    final allKeys = widget.appProvider.keysForProvider(widget.provider);
    // 第一个 key 已经由 widget.keyController 管理，从第二个开始
    final expectedExtraCount = allKeys.length > 1 ? allKeys.length - 1 : 0;

    // 如果当前控制器比需要的多，移除多余的
    while (_additionalKeyControllers.length > expectedExtraCount) {
      _additionalKeyControllers.last.dispose();
      _additionalKeyControllers.removeLast();
    }

    // 如果当前控制器比需要的少，添加缺少的
    if (allKeys.length > 1) {
      for (int i = 1; i < allKeys.length; i++) {
        final existingIdx = i - 1;
        if (existingIdx < _additionalKeyControllers.length) {
          // 如果控制器已存在，同步文本（避免覆盖用户正在编辑的文字）
          if (_additionalKeyControllers[existingIdx].text.isEmpty) {
            _additionalKeyControllers[existingIdx].text = allKeys[i];
          }
        } else {
          // 新建控制器
          final ctrl = TextEditingController(text: allKeys[i]);
          _additionalKeyControllers.add(ctrl);
        }
      }
    }

    // 如果状态变化了，重绘
    if (mounted) {
      setState(() {});
    }
  }

  // 以下四项原先各写一份 switch，与 AiConfig 工厂、AppProvider._defaultModel
  // 以及两个设置页的副本取值不一致。统一读 lib/data/provider_defaults.dart。
  String defaultBaseUrl(AiProvider p) => defaultsForProvider(p.name).baseUrl;

  String defaultModel(AiProvider p) => defaultsForProvider(p.name).model;

  String providerNameLabel(AiProvider p) => providerDisplayName(p.name);

  /// 一句话定位（收起态显示，帮助用户快速区分三家）
  String _tagline(AiProvider p) => defaultsForProvider(p.name).tagline;

  Color _providerColor(AiProvider p) {
    switch (p) {
      case AiProvider.deepseek:
        return const Color(0xFF4D6BFE);
      case AiProvider.agnes:
        return const Color(0xFF10B981);
      case AiProvider.sensenova:
        return const Color(0xFFFF8A3D);
    }
  }

  IconData _providerIcon(AiProvider p) {
    switch (p) {
      case AiProvider.deepseek:
        return Icons.water_outlined;
      case AiProvider.agnes:
        return Icons.bolt_outlined;
      case AiProvider.sensenova:
        return Icons.auto_awesome_outlined;
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
            return InkWell(
              onTap: () {
                widget.modelController.text = model;
                // 选完预设后，光标移到末尾方便编辑
                widget.modelController.selection = TextSelection.fromPosition(
                  TextPosition(offset: widget.modelController.text.length),
                );
                widget.onModelPresetSelected?.call(model);
                setState(() {});
              },
              borderRadius: BorderRadius.circular(8),
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

  /// 收起/展开共用的头部行
  Widget _buildHeader(bool hasKey, {int keyCount = 0}) {
    final p = widget.provider;
    final accent = _providerColor(p);
    final customModel = widget.modelController.text.trim();
    final displayModel = customModel.isEmpty ? defaultModel(p) : customModel;
    final isDefaultModel = displayModel == defaultModel(p);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 提供商标识
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Icon(_providerIcon(p), size: 18, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        providerNameLabel(p),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _tagline(p),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // 当前使用的模型
                  Row(
                    children: [
                      const Icon(Icons.memory_outlined, size: 12, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          displayModel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDefaultModel ? const Color(0xFF6B7280) : accent,
                          ),
                        ),
                      ),
                      if (isDefaultModel)
                        const Text('默认', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 配置状态徽章
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: hasKey
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasKey
                      ? const Color(0xFF10B981).withValues(alpha: 0.5)
                      : Colors.orange.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                hasKey ? (keyCount > 1 ? '$keyCount Keys' : '已配置') : '未配置',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: hasKey ? const Color(0xFF10B981) : Colors.orange,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: const Color(0xFF8B949E),
            ),
          ],
        ),
      ),
    );
  }

  /// 展开态：完整配置区
  Widget _buildExpandedBody(bool hasKey) {
    final p = widget.provider;
    final desc = kProviderDescriptions[p] ?? '';
    final testResult = widget.testResult;
    final testSuccess = widget.testSuccess;
    final keyCount = widget.appProvider.keyCount(p);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 详细说明
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1C232D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(desc,
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11.5, height: 1.45)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('API Key', style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
              if (keyCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$keyCount 个 Key',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),

          // 第一个 Key
          _buildKeyInputRow(
            controller: widget.keyController,
            obscureText: _obscureKey,
            helperText: 'Key 1',
            showDelete: false,
            onToggleVisibility: () => setState(() => _obscureKey = !_obscureKey),
          ),

          // 额外 Key
          for (int i = 0; i < _additionalKeyControllers.length; i++) ...[
            const SizedBox(height: 6),
            _buildKeyInputRow(
              controller: _additionalKeyControllers[i],
              obscureText: _obscureAdditionalKeys,
              helperText: 'Key ${i + 2}',
              showDelete: true,
              onDelete: () => _confirmDeleteKey(i + 1),
              onToggleVisibility: () => setState(() => _obscureAdditionalKeys = !_obscureAdditionalKeys),
            ),
          ],

          // 添加新 Key 按钮
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addNewKey,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加 API Key', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                foregroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
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
          if (!hasKey) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.tips_and_updates_outlined, size: 13, color: Color(0xFFD3A625)),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '填入 API Key 并点击「保存」后，该提供商才会出现在场景路由的可选列表中。多个 Key 可提升并发上限（每个 Key 独立 20 RPM）',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFFD3A625)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKeyInputRow({
    required TextEditingController controller,
    required bool obscureText,
    required String helperText,
    required bool showDelete,
    required VoidCallback onToggleVisibility,
    VoidCallback? onDelete,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'sk-...',
              helperText: helperText,
              helperStyle: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                  color: const Color(0xFF8B949E),
                ),
                onPressed: onToggleVisibility,
              ),
              suffixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 0),
            ),
          ),
        ),
        const SizedBox(width: 6),
        if (showDelete && onDelete != null)
          SizedBox(
            height: 40,
            child: IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
              tooltip: '删除此 Key',
            ),
          ),
        const SizedBox(width: 6),
        SizedBox(
          height: 40,
          child: ElevatedButton(
            onPressed: () async {
              await _saveAllKeys();
              widget.onSave?.call();
            },
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
    );
  }

  Future<void> _saveAllKeys() async {
    final p = widget.provider;
    final allKeys = <String>[];
    // 第一个 key
    final firstKey = widget.keyController.text.trim();
    if (firstKey.isNotEmpty) allKeys.add(firstKey);
    // 额外 key
    for (final ctrl in _additionalKeyControllers) {
      final key = ctrl.text.trim();
      if (key.isNotEmpty) allKeys.add(key);
    }
    // 一次性写入 provider（避免多次 notifyListeners）
    await widget.appProvider.setAllKeysForProvider(p, allKeys);
  }

  void _addNewKey() {
    setState(() {
      _additionalKeyControllers.add(TextEditingController());
    });
  }

  void _confirmDeleteKey(int index) {
    final p = widget.provider;
    // 先保存控制器文本，再删除
    final ctrl = _additionalKeyControllers[index - 1];
    if (ctrl.text.trim().isNotEmpty) {
      widget.appProvider.removeApiKeyAt(p, index);
    }
    setState(() {
      ctrl.dispose();
      _additionalKeyControllers.removeAt(index - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = widget.appProvider.hasKey(widget.provider);
    final keyCount = widget.appProvider.keyCount(widget.provider);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF252C36),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasKey
              ? const Color(0xFF10B981).withValues(alpha: 0.55)
              : const Color(0xFF374151),
          width: hasKey ? 1.3 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(hasKey, keyCount: keyCount),
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFF30363D)),
            _buildExpandedBody(hasKey),
          ],
        ],
      ),
    );
  }
}
