import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../theme/miuix_tokens.dart';
import '../theme/miuix_typography.dart';
import '../utils/ui_helpers.dart';
import '../widgets/miui_magic_backdrop.dart';
import '../widgets/miuix_components.dart';

class SaveLoadScreen extends StatefulWidget {
  const SaveLoadScreen({super.key});

  @override
  State<SaveLoadScreen> createState() => _SaveLoadScreenState();
}

class _SaveLoadScreenState extends State<SaveLoadScreen> {
  int _tab = 0;
  List<Map<String, dynamic>> _saves = [];
  bool _isLoading = false;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSaves();
  }

  Future<void> _loadSaves() async {
    setState(() => _isLoading = true);
    try {
      _saves = await context.read<GameProvider>().listSaves();
    } catch (e) {
      if (mounted) _showSnack('加载存档失败: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveCurrentGame() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('请输入存档名称');
      return;
    }
    final gp = context.read<GameProvider>();
    setState(() => _isLoading = true);
    try {
      await gp.saveGameNamed(_nameController.text);
      await _loadSaves();
      if (!mounted) return;
      _showSnack('✅ 已保存为「${_nameController.text.trim()}」');
      _nameController.clear();
    } catch (e) {
      if (!mounted) return;
      _showSnack('保存失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSave(String slotId) async {
    try {
      await context.read<GameProvider>().loadFromSave(slotId);
      if (!mounted) return;
      // BUG-FIX: 原来先 pop 再用同一 context pushReplacementNamed，
      // pop 后 element 已 deactivate，debug 下会触发
      // "Looking up a deactivated widget's ancestor is unsafe"。
      // 直接 pushReplacementNamed 即可替换当前页。
      Navigator.pushReplacementNamed(context, '/game');
    } catch (e) {
      if (!mounted) return;
      _showSnack('加载存档失败: $e');
    }
  }

  Future<void> _deleteSave(String slotId) async {
    try {
      await context.read<GameProvider>().deleteSave(slotId);
      await _loadSaves();
    } catch (e) {
      if (!mounted) return;
      _showSnack('删除存档失败: $e');
    }
  }

  /// 导出存档到剪贴板（用于备份/跨设备迁移）
  Future<void> _exportSave(Map<String, dynamic> save) async {
    try {
      final json = await context.read<GameProvider>().exportSave(save['id']);
      if (json == null) {
        _showSnack('❌ 导出失败：存档不存在或已损坏');
        return;
      }
      await Clipboard.setData(ClipboardData(text: json));
      _showSnack('✅ 存档已复制到剪贴板，请粘贴到备忘录/文件保存');
    } catch (e) {
      _showSnack('❌ 导出失败: $e');
    }
  }

  /// 从剪贴板导入存档
  Future<void> _importSave() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      // 读剪贴板是一次平台通道调用，期间玩家可能已经退出这一页
      if (!mounted) return;
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        _showSnack('❌ 剪贴板为空，请先复制存档数据');
        return;
      }
      final gp = context.read<GameProvider>();
      setState(() => _isLoading = true);
      final slotId = await gp.importSave(text);
      await _loadSaves();
      if (!mounted) return;
      _showSnack(slotId != null ? '✅ 存档导入成功' : '❌ 导入失败：剪贴板内容不是有效存档');
    } catch (e) {
      _showSnack('❌ 导入失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('存档 / 读档')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: MiuiMagicBackdrop(density: 0.55)),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 12),
                child: MiuiSegmented<int>(
                  segments: const {0: '📥 存档', 1: '📤 读档'},
                  selected: _tab,
                  onChanged: (v) => setState(() => _tab = v),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _tab == 0 ? _buildSavePanel() : _buildLoadPanel(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavePanel() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
      child: MiuiCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '创建新存档',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: MiuiColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '给你的魔法人生加一个书签',
              style: TextStyle(
                fontSize: 13,
                color: MiuiColors.onSurfaceVariantSummary,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: '输入存档名称...',
                prefixIcon: Icon(Icons.bookmark_outline),
              ),
            ),
            const SizedBox(height: 20),
            MiuiButton(
              label: '💾 保存游戏',
              onPressed: _isLoading ? null : _saveCurrentGame,
              primary: true,
              expand: true,
            ),
            if (_isLoading) ...[
              const SizedBox(height: 12),
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadPanel() {
    if (_isLoading && _saves.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_saves.isEmpty) {
      return MiuiEmptyState(
        message: '暂无存档\n粘贴一份 JSON 即可恢复你的魔法人生',
        icon: Icons.cloud_off_outlined,
        action: MiuiButton(
          label: '从剪贴板导入存档',
          icon: Icons.paste,
          primary: false,
          onPressed: _importSave,
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '共 ${_saves.length} 个存档',
                  style: MiuiType.body2.copyWith(
                    color: MiuiColors.onSurfaceVariantSummary,
                  ),
                ),
              ),
              MiuiButton(
                label: '导入',
                icon: Icons.paste,
                primary: false,
                onPressed: _importSave,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
            itemCount: _saves.length,
            itemBuilder: (context, index) => _buildSaveCard(_saves[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveCard(Map<String, dynamic> save) {
    final timestamp = save['saved_at']?.toString().substring(0, 16) ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MiuiCard(
        onTap: () => _loadSave(save['id']),
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MiuiColors.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.bookmark,
                color: MiuiColors.primaryVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    save['name'] ?? '未命名',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: MiuiColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timestamp,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MiuiColors.onSurfaceVariantSummary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: '导出到剪贴板',
              color: MiuiColors.info,
              onPressed: () => _exportSave(save),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除',
              color: MiuiColors.error,
              onPressed: () async {
                final ok = await confirmDangerDialog(
                  context,
                  title: '删除存档',
                  message: '确定要删除存档「${save['slotName'] ?? save['id']}」吗？\n'
                      '删除后无法恢复。',
                  confirmText: '删除',
                );
                if (ok) _deleteSave(save['id']);
              },
            ),
          ],
        ),
      ),
    );
  }
}