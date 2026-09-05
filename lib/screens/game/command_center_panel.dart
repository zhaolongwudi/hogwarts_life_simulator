/// 指令中心面板（模块化、数据驱动）
///
/// 取代旧的 `_showCommandMenu` 手写硬编码列表。面板从
/// [CommandRegistry] 自动读取全部指令（含分组、说明、作弊标记）——
/// 注册表里加一条新指令，面板自动出现，永不与 /帮助 脱节。
///
/// 特性：
///  · 按注册表 group 自动分组，每组可折叠（作弊组默认收起）
///  · 顶部搜索：按命令名 / 别名 / 说明实时过滤
///  · 无参指令点 ▶ 直接执行；带参指令点 ▶ 填入输入框等待补参
///  · 高频指令快捷区（状态/时间/地图/通知/帮助）
library;

import 'package:flutter/material.dart';
import '../../data/command_registry.dart';
import '../../theme/miuix_tokens.dart';

/// 分组图标与折叠默认状态
class _GroupMeta {
  final IconData icon;
  final bool expandedByDefault;
  const _GroupMeta(this.icon, {this.expandedByDefault = false});
}

const Map<String, _GroupMeta> _groupMeta = {
  '基础信息': _GroupMeta(Icons.info_outline, expandedByDefault: true),
  '关系&情感': _GroupMeta(Icons.favorite_outline, expandedByDefault: true),
  '学业&成长': _GroupMeta(Icons.school_outlined, expandedByDefault: true),
  '玩法&活动': _GroupMeta(Icons.sports_esports_outlined),
  '物品&宠物': _GroupMeta(Icons.inventory_2_outlined),
  '信件&目标': _GroupMeta(Icons.mail_outline),
  '世界&结局': _GroupMeta(Icons.public, expandedByDefault: true),
  '个人': _GroupMeta(Icons.person_outline),
  '作弊': _GroupMeta(Icons.bug_report_outlined),
};

const IconData _defaultGroupIcon = Icons.extension_outlined;

/// 打开指令中心面板。
///
/// [onExecute]：执行一条指令（无参指令点击后调用，文本已填好）。
/// [onFillInput]：把文本填入输入框（带参指令点击后调用，等待玩家补参）。
void showCommandCenter(
  BuildContext context, {
  required ValueChanged<String> onExecute,
  required ValueChanged<String> onFillInput,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: MiuiColors.surface,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.88,
      child: CommandCenterPanel(
        onExecute: onExecute,
        onFillInput: onFillInput,
      ),
    ),
  );
}

class CommandCenterPanel extends StatefulWidget {
  final ValueChanged<String> onExecute;
  final ValueChanged<String> onFillInput;

  const CommandCenterPanel({
    super.key,
    required this.onExecute,
    required this.onFillInput,
  });

  @override
  State<CommandCenterPanel> createState() => _CommandCenterPanelState();
}

class _CommandCenterPanelState extends State<CommandCenterPanel> {
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  // 作弊组默认折叠：避免满屏指令里混入灰色地带入口
  final Set<String> _collapsedGroups = {'作弊'};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = CommandRegistry.instance.all;
    final query = _query.trim().toLowerCase();

    // 按 group 分组 + 过滤
    final groups = <String, List<CommandDef>>{};
    for (final c in all) {
      if (query.isNotEmpty && !_matches(c, query)) continue;
      groups.putIfAbsent(c.group, () => []).add(c);
    }
    // 分组排序：作弊永远最后
    final orderedGroups = groups.entries.toList()
      ..sort((a, b) {
        if (a.key == '作弊') return 1;
        if (b.key == '作弊') return -1;
        return a.key.compareTo(b.key);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部：拖拽条 + 标题 + 搜索
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Text('⚡ 指令中心',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: MiuiColors.primary)),
              const Spacer(),
              Text('共 ${all.length} 条指令',
                  style: const TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: MiuiColors.onSurface, fontSize: 14),
            decoration: InputDecoration(
              hintText: '搜索指令（名称 / 别名 / 功能）',
              hintStyle: const TextStyle(color: MiuiColors.onSurfaceVariantActions, fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20, color: MiuiColors.onSurfaceVariantSummary),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18, color: MiuiColors.onSurfaceVariantSummary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: MiuiColors.surfaceContainer,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: MiuiColors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: MiuiColors.outline),
              ),
            ),
          ),
        ),
        // 快捷区（无搜索时显示）
        if (_query.isEmpty) _buildQuickRow(context),
        const Divider(height: 1, color: MiuiColors.outline),
        // 分组列表
        Expanded(
          child: orderedGroups.isEmpty
              ? const Center(
                  child: Text('没有匹配的指令',
                      style: TextStyle(color: MiuiColors.onSurfaceVariantSummary, fontSize: 13)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: orderedGroups.length,
                  itemBuilder: (context, i) {
                    final entry = orderedGroups[i];
                    return _buildGroupSection(context, entry.key, entry.value);
                  },
                ),
        ),
      ],
    );
  }

  // ---------- 高频快捷区 ----------

  Widget _buildQuickRow(BuildContext context) {
    const quick = [
      ('/状态', '状态', Icons.person),
      ('/时间', '时间', Icons.schedule),
      ('/地图', '地图', Icons.map_outlined),
      ('/通知', '通知', Icons.notifications_outlined),
      ('/关系', '关系', Icons.people_outline),
      ('/职业', '职业', Icons.work_outline),
      ('/帮助', '帮助', Icons.help_outline),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: quick.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (cmd, label, icon) = quick[i];
          return GestureDetector(
            onTap: () => _run(cmd),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: MiuiColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: MiuiColors.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: MiuiColors.primary),
                  const SizedBox(width: 5),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MiuiColors.onSurface)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- 分组区 ----------

  Widget _buildGroupSection(
      BuildContext context, String group, List<CommandDef> commands) {
    final meta = _groupMeta[group] ?? const _GroupMeta(_defaultGroupIcon);
    final isCheat = group == '作弊';
    final collapsed = _collapsedGroups.contains(group);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 组头：点击折叠/展开
        GestureDetector(
          onTap: () => setState(() {
            if (collapsed) {
              _collapsedGroups.remove(group);
            } else {
              _collapsedGroups.add(group);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Icon(meta.icon, size: 16,
                    color: isCheat ? MiuiColors.error : MiuiColors.primary),
                const SizedBox(width: 8),
                Text(
                  isCheat ? '$group（${commands.length}）' : group,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: MiuiColors.onSurfaceVariantSummary,
                      letterSpacing: 0.4),
                ),
                if (commands.length > 0 && !isCheat)
                  Text(' ${commands.length}',
                      style: const TextStyle(fontSize: 11, color: MiuiColors.onSurfaceVariantActions)),
                const Spacer(),
                Icon(
                  collapsed ? Icons.expand_more : Icons.expand_less,
                  size: 18,
                  color: MiuiColors.onSurfaceVariantActions,
                ),
              ],
            ),
          ),
        ),
        if (!collapsed)
          ...commands.map((c) => _buildCommandTile(c, isCheat)),
      ],
    );
  }

  Widget _buildCommandTile(CommandDef c, bool isCheat) {
    final needsArgs = _needsArgs(c);
    final aliases = c.aliases.isNotEmpty ? '（/${c.aliases.join('、/')}）' : '';
    final accent = isCheat ? MiuiColors.error : MiuiColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCheat ? Icons.bug_report : Icons.bolt,
                  size: 16,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('/${c.primary}$aliases',
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: MiuiColors.onSurface)),
                    const SizedBox(height: 2),
                    Text(c.helpText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: MiuiColors.onSurfaceVariantSummary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _run('/${c.primary}'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        needsArgs ? Icons.edit_outlined : Icons.play_arrow,
                        size: 15,
                        color: accent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        needsArgs ? '填参' : '运行',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 结构化二级指令：渲染成可点击按钮，不用再手动打字
          if (c.subs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 46, top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final sub in c.subs) _buildSubChip(c, sub, accent),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 二级指令按钮：无附加参数 → 直接执行；有附加参数 → 填入输入框补参。
  Widget _buildSubChip(CommandDef c, CommandSub sub, Color accent) {
    final hasArg = sub.argHint != null;
    return GestureDetector(
      onTap: () {
        final text = '/${c.primary} ${sub.keyword}';
        if (hasArg) {
          Navigator.of(context).pop();
          widget.onFillInput('$text ');
        } else {
          Navigator.of(context).pop();
          widget.onExecute(text);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasArg ? Icons.edit_outlined : Icons.play_arrow,
              size: 12,
              color: accent,
            ),
            const SizedBox(width: 3),
            Text(
              hasArg ? '${sub.keyword} <${sub.argHint}>' : sub.keyword,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: MiuiColors.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 执行 ----------

  void _run(String command) {
    Navigator.of(context).pop();
    final def = CommandRegistry.instance.find(command.substring(1));
    final needsArgs = def != null && _needsArgs(def);
    if (needsArgs) {
      // 带参指令：填入输入框，等待玩家补充参数
      widget.onFillInput('$command ');
    } else {
      widget.onExecute(command);
    }
  }

  static bool _needsArgs(CommandDef c) {
    // 参数占位可能是 <名字>（尖括号）或 [名字]（方括号），
    // 也可能是子命令列表（｜）——任一出现都算需要补参
    return c.helpText.contains('<') ||
        c.helpText.contains('[') ||
        c.helpText.contains('｜') ||
        c.helpText.contains('|');
  }

  static bool _matches(CommandDef c, String query) {
    final haystack = '/${c.primary} ${c.aliases.join(' ')} ${c.helpText}'.toLowerCase();
    return haystack.contains(query);
  }
}

/// 便捷包装：从 GameBottomInput 调用，自动处理执行与填参。
void showCommandCenterFromGame(
  BuildContext context,
  TextEditingController inputController,
  VoidCallback onHandleFreeAction,
) {
  showCommandCenter(
    context,
    onExecute: (command) {
      inputController.text = command;
      onHandleFreeAction();
    },
    onFillInput: (text) {
      // 带参指令：填入输入框，末尾留空格提示补参，玩家补完点发送
      inputController.text = text;
      inputController.selection =
          TextSelection.collapsed(offset: inputController.text.length);
    },
  );
}
