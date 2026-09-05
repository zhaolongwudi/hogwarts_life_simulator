import 'package:flutter/material.dart';
import '../../utils/ui_helpers.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../data/provider_defaults.dart';
import '../../providers/game_provider.dart';
import '../../providers/game_provider_base.dart';
import '../../services/deepseek_service.dart';
import '../../utils/ai_debug_logger.dart';
import '../story_history_screen.dart';
import 'settings_provider_card.dart';
import 'settings_scene_routing.dart';
import 'settings_preset_pickers.dart';
import 'settings_stance.dart';
import 'settings_token_usage.dart';
import 'settings_crash_section.dart';
import '../../data/political_stance.dart';
import '../../theme/miuix_tokens.dart';
import '../../widgets/miuix_overlays.dart';

/// 设置页正文。
///
/// 此前 SettingsScreen（独立页面）与 GameSettingsInlineTab（游戏内 Tab）
/// 各自维护一份约 460 行的正文，86% 逐行相同，只有 4 处差异：AppBar、
/// 剧情回放入口、开始新游戏后的退出行为、底部留白。现在两边共用本组件，
/// 差异通过构造参数表达。
class SettingsBody extends StatefulWidget {
  const SettingsBody({
    super.key,
    this.showStoryReplay = true,
    this.onAfterNewGame,
    this.bottomPadding = 36,
  });

  /// 游戏内 Tab 与独立设置页都提供剧情回放——入口此前只存在于 Tab 里，
  /// 从手机主页进设置的用户看不到。
  final bool showStoryReplay;

  /// 确认「开始新游戏」并关闭确认弹窗后触发。独立设置页传一个退栈回调，
  /// 游戏内 Tab 不传（留在 Tab 里即可）。
  final VoidCallback? onAfterNewGame;

  final double bottomPadding;

  @override
  State<SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<SettingsBody> {
  final _keyControllers = <AiProvider, TextEditingController>{};
  final _modelControllers = <AiProvider, TextEditingController>{};
  bool _testing = false;
  final _testResults = <AiProvider, String>{};
  final _testSuccess = <AiProvider, bool>{};

  @override
  void initState() {
    super.initState();
    final appProvider = context.read<AppProvider>();
    for (final p in AiProvider.values) {
      final keys = appProvider.keysForProvider(p);
      final firstKey = keys.isNotEmpty ? keys.first : '';
      _keyControllers[p] = TextEditingController(text: firstKey);
      _modelControllers[p] = TextEditingController(text: appProvider.providerModel(p));
    }
  }

  @override
  void dispose() {
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    for (final c in _modelControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveKeyAndModel(AiProvider p) async {
    // 注意：key 的保存由 SettingsProviderCard 内部的 _saveAllKeys 负责
    // 这里只保存模型设置
    final model = _modelControllers[p]!.text.trim();

    if (model.isNotEmpty) {
      await context.read<AppProvider>().setModelForProvider(p, model);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _testConnection(AiProvider p) async {
    setState(() {
      _testing = true;
      _testResults[p] = '测试中...';
      _testSuccess[p] = false;
    });

    try {
      final defaults = defaultsForProvider(p.name);
      final typed = _modelControllers[p]!.text.trim();
      final service = DeepSeekService(
        config: AiConfig(
          provider: p,
          apiKey: _keyControllers[p]!.text.trim(),
          baseUrl: defaults.baseUrl,
          chatPath: defaults.chatPath,
          model: typed.isEmpty ? defaults.model : typed,
        ),
      );
      final connected = await service.checkConnection();
      if (!mounted) return;
      setState(() {
        _testResults[p] = connected ? '✅ 连接成功' : '❌ 连接失败';
        _testSuccess[p] = connected;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testResults[p] = '❌ $e';
        _testSuccess[p] = false;
      });
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  /// HyperOS 设置分组标题：icon 徽块 + 大标题 + 副题（Miuix 生态页风格）。
  Widget _buildGroupHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    Color color = MiuiColors.primary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: MiuiSpace.dividerThickness,
                ),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: MiuiColors.onSurface,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 48),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: MiuiColors.onSurfaceVariantSummary,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final gp = context.watch<GameProvider>();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, widget.bottomPadding),
      children: [
        _buildGroupHeader(
          icon: Icons.smart_toy_outlined,
          title: '🤖 AI 服务配置',
          subtitle: '选择并配置您的 AI 提供商',
        ),
        const SizedBox(height: 12),
        ...AiProvider.values.map((p) => SettingsProviderCard(
              provider: p,
              appProvider: appProvider,
              keyController: _keyControllers[p]!,
              modelController: _modelControllers[p]!,
              testing: _testing,
              testResult: _testResults[p],
              testSuccess: _testSuccess[p],
              onSave: () => _saveKeyAndModel(p),
              onTest: () => _testConnection(p),
              onModelPresetSelected: (m) {
                context.read<AppProvider>().setModelForProvider(p, m);
                setState(() {});
              },
            )),
        const SizedBox(height: 16),
        SettingsSceneRouting(
          appProvider: appProvider,
          onSceneRouteChanged: (scene, provider) {
            appProvider.setSceneRoute(scene, provider);
            context.read<GameProvider>().refreshClient();
          },
        ),
        const SizedBox(height: 16),
        _buildOfflineModeCard(context, appProvider),
        SettingsTokenUsage(
          gameProvider: gp,
          onReset: () {
            gp.resetTokenUsage();
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        const SettingsCrashSection(),
        const SizedBox(height: 20),
        _buildGroupHeader(
          icon: Icons.desktop_windows_outlined,
          title: '📺 显示模式',
          subtitle: '选择游戏界面的显示风格',
          color: const Color(0xFF60A5FA),
        ),
        const SizedBox(height: 12),
        SettingsPresetPickers.buildModePicker(
          appProvider.displayMode.name,
          disabled: appProvider.identityMode == IdentityMode.transmigration
              ? const {'magazine'}
              : null,
          onSelect: (v) {
            context.read<AppProvider>().setDisplayMode(DisplayMode.values.byName(v));
          },
        ),
        const SizedBox(height: 24),
        _buildGroupHeader(
          icon: Icons.badge_outlined,
          title: '🎭 身份模式',
          subtitle: '穿越者/骨科/原住民：影响整个App的AI叙事口吻。注：政治立场(纯血/维护传统/光明/黑暗/中立)已移到下方「当前角色政治立场」快捷开关',
          color: const Color(0xFFA78BFA),
        ),
        const SizedBox(height: 12),
        Consumer<GameProvider>(builder: (ctx, _, __) => SettingsPresetPickers.buildModePicker(
              appProvider.identityMode.name,
              modes: const [
                ModeOption('pure', label: '原住民（默认）', desc: '对命运走向一无所知，只凭判断与本能行事'),
                ModeOption('transmigration', label: '穿越者', desc: '对原作剧情留有隐约记忆，引用未来信息需克制'),
                ModeOption('bone_mode', label: '骨科模式(隐藏)', desc: '解锁血缘亲属的恋爱与CG线路'),
              ],
              disabled: appProvider.displayMode == DisplayMode.magazine
                  ? const {'transmigration'}
                  : null,
              onSelect: (v) {
                ctx.read<AppProvider>().setIdentityMode(IdentityMode.values.byName(v));
              },
            )),
        if (appProvider.displayMode == DisplayMode.magazine)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '使用「魔法手账」显示模式时，无法选用「穿越者」身份',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
        const SizedBox(height: 24),
        const Text('🔱 当前角色政治立场（快捷改）',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: MiuiColors.onSurface)),
        const SizedBox(height: 4),
        const Text('修改当前存档的主角政治立场（与开局第11轮的选项一致）；未开新游戏时不生效。',
            style: TextStyle(fontSize: 13, color: MiuiColors.onSurfaceVariantSummary, height: 1.5)),
        const SizedBox(height: 12),
        Consumer<GameProvider>(builder: (ctx, gp, _) {
          final p = gp.player;
          final current = p?.politicalTendency ?? kDefaultPoliticalStance;
          final disabled =
              p == null ? Set<String>.from(kPoliticalStanceNames) : null;
          return SettingsPresetPickers.buildModePicker(
            current,
            modes: stanceModeOptions,
            disabled: disabled,
            onSelect: (v) async {
              gp.player?.politicalTendency = v;
              setState(() {});
              await gp.quickSave();
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text('🔱 政治立场已切换为：$v（下回合 AI 起生效）'),
                  duration: const Duration(seconds: 2),
                ));
              }
            },
          );
        }),
        const SizedBox(height: 24),
        const Text('⏳ 时代背景',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: MiuiColors.onSurface)),
        const SizedBox(height: 4),
        const Text('选择游戏开始的时代',
            style: TextStyle(fontSize: 13, color: MiuiColors.onSurfaceVariantSummary, height: 1.5)),
        const SizedBox(height: 12),
        SettingsPresetPickers.buildEraPicker(context, appProvider.era.name),
        const SizedBox(height: 24),
        if (widget.showStoryReplay) ...[
          _buildStoryReplayCard(context),
          const SizedBox(height: 24),
        ],
        _buildDebugLogCard(context, appProvider),
        _buildDangerCard(context, appProvider),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildStoryReplayCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MiuiColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MiuiColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.history, color: MiuiColors.primary),
              SizedBox(width: 8),
              Text('📜 剧情回放',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MiuiColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '查看最近 ${GameProviderBase.maxRecentTurns} 回合的完整剧情记录，包含场景插图、对话气泡和详细叙事',
            style: const TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StoryHistoryScreen()),
                );
              },
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const Text('打开剧情回放'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MiuiColors.primary,
                foregroundColor: MiuiColors.surfaceContainerHigh,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineModeCard(BuildContext context, AppProvider appProvider) {
    final enabled = appProvider.offlineQuickMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MiuiColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? MiuiColors.success : MiuiColors.disabledOnSurface,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.offline_bolt, color: MiuiColors.success),
              SizedBox(width: 8),
              Text('⚡ 无 AI 快速模式',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('完全离线游玩（不消耗 AI 额度）'),
            subtitle: Text(
              enabled
                  ? '已开启：所有剧情与选项由本地模板生成，不调用 AI，'
                      '适合免费额度耗尽或未配置 Key 时保底游玩。'
                  : '未开启：正常使用 AI 生成剧情。AI 服务不可用或额度耗尽时，'
                      '仍会自动切换到本地兜底剧情保证不断链。',
              style: const TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary),
            ),
            value: enabled,
            onChanged: (v) => context.read<AppProvider>().setOfflineQuickMode(v),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugLogCard(BuildContext context, AppProvider appProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MiuiColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MiuiColors.disabledOnSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bug_report, color: Colors.amber),
              SizedBox(width: 8),
              Text('🔧 调试日志',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('启用 AI 调用日志'),
            subtitle: const Text('记录每回合 AI 的输入输出到本地文件，用于排查 bug'),
            value: appProvider.aiDebugLogEnabled,
            onChanged: (v) async {
              AiDebugLogger.instance.setEnabled(v);
              if (v) {
                await AiDebugLogger.instance.initialize(enabled: true);
              }
              await context.read<AppProvider>().setAiDebugLogEnabled(v);
            },
          ),
          if (appProvider.aiDebugLogEnabled) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final files = await AiDebugLogger.instance.getLogFiles();
                    if (!mounted) return;
                    if (files.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('暂无日志文件')),
                      );
                      return;
                    }
                    showMiuixDialog(
                      context: context,
                      builder: (_) => LogViewerDialog(logFiles: files),
                    );
                  },
                  icon: const Icon(Icons.folder),
                  label: const Text('查看日志'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showMiuixDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('清空日志？'),
                        content: const Text('将删除所有已保存的 AI 调用日志'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                          ElevatedButton(
                            onPressed: () {
                              AiDebugLogger.instance.clearAllLogs();
                              Navigator.pop(context);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('日志已清空')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('清空'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('清空'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MiuiColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '日志文件保存在应用文档目录下的 ai_debug_logs 文件夹\n可用于分析上下文污染、路由错误等问题',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDangerCard(BuildContext context, AppProvider appProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MiuiColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MiuiColors.disabledOnSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️ 危险操作',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('清除所有 API Key'),
            subtitle: const Text('删除本地保存的所有 AI 提供商 Key'),
            trailing: const Icon(Icons.delete, color: Colors.red),
            onTap: () async {
              final ok = await confirmDangerDialog(
                context,
                title: '清除所有 API Key',
                message: '确定要删除本地保存的所有 AI 提供商 Key 吗？\n'
                    '清除后 AI 对话将无法使用，需要重新粘贴 Key。',
                confirmText: '全部清除',
              );
              if (!ok) return;
              for (final p in AiProvider.values) {
                context.read<AppProvider>().clearApiKeyFor(p);
                _keyControllers[p]!.clear();
              }
              setState(() {});
            },
          ),
          ListTile(
            title: const Text('开始新游戏'),
            subtitle: const Text('重置当前游戏进度'),
            trailing: const Icon(Icons.refresh, color: Colors.orange),
            onTap: () {
              showMiuixDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('确认？'),
                  content: const Text('所有进度将被清除，确定继续？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                    ElevatedButton(
                      onPressed: () {
                        // 先清空 GameProvider 内所有旧叙事/玩家/世界状态（摘要、近期剧情、回合计数等）
                        // 否则新游戏第一回合 Prompt 里会注入旧游戏的前情摘要，导致 AI 接着旧剧情写
                        context.read<GameProvider>().resetAllState();
                        appProvider.setGameStarted(false);
                        Navigator.pop(context);
                        widget.onAfterNewGame?.call();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('确认'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
