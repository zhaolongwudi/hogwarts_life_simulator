/// R1：指令系统去 switch-case 化（统一注册表 + 自动生成 /帮助）
///
/// 原设计：
///   - handleLocalCommand()：50+ 条 case 散在 1 个巨型 switch
///   - _formatHelp()：另一份硬编码，路由和文档**两个独立维护点**
///
/// 新设计：
///   - 每条指令 = 1 条 CommandDef { id, primary, aliases, helpText, handler, argSchema, permission }
///   - 注册一次同时解决「路由匹配」+「/帮助 文档生成」，天然不可能不同步
///   - 支持：命令别名、子命令、自动参数校验、权限分类
///
/// 因为 handler 需要调用 mixin 里的方法（比如 formatRelationships()、petInteract()），
/// 所以注册表设计成：CommandRegistry 是一个单例，mixin 在自己初始化时
/// 通过 registerAll(this) 传入 handler 闭包，闭包再调用 mixin 方法。
///   这样避免了大量 circular import，也不需要改 GameProviderBase 的继承链。

import '../providers/game_provider_base.dart';

/// 指令处理上下文：解析好的参数 + 调用方 mixin 的引用（暴露 GameProviderBase 字段）
class CommandContext {
  final List<String> parts; // 去掉 primary 命令后的子参数
  final GameProviderBase provider;

  const CommandContext(this.parts, this.provider);

  /// 获取第 idx 个子参数（0 = 第一个子参数，即 parts[0]）。
  ///
  /// handler 里请统一用 arg()/tailFrom() 取参，**不要**直接写 `parts[1]`：
  /// 本列表已去掉命令本身，parts[0] 就是第一个真实参数。
  String? arg(int idx) => (idx >= 0 && idx < parts.length) ? parts[idx] : null;

  /// parts[idx:] 拼接成的字符串（用于 /目标 xxx xxx 这种带空格的内容）
  String tailFrom(int idx) => parts.sublist(idx).join(' ');
}

/// 指令定义
class CommandDef {
  /// 主命令：/状态 → primary = '状态'
  final String primary;

  /// 别名：/舆论 /传闻 都映射到同一个 handler
  final List<String> aliases;

  /// /帮助 里显示的说明（带参数示例）
  final String helpText;

  /// 处理函数：返回 true = 已处理
  final bool Function(CommandContext ctx) handler;

  /// 分组（/帮助 里按分组展示）
  final String group;

  /// 权限标签：'player' / 'cheat' / 'admin'
  final String permission;

  /// 是否「面板型指令」（查看/列表类，如 /状态 /关系 /收藏）：
  /// 面板型指令的输出进独立面板、不覆盖当前回合剧情；事件型指令
  /// （如 /计划 /快进 /决斗）的输出就是新剧情、必须覆盖。
  ///
  /// BUG-FIX: processChoice 原先用「choices 是否为单个『返回/继续』」的
  /// 启发式判断面板型，导致 /计划、/新NPC 生成 这类事件指令设置了
  /// 「返回」选项后被误判为面板型、剧情被还原成上一段——玩家执行完
  /// 指令看不到任何结果。改为注册时显式声明，判定不再猜。
  final bool panel;

  const CommandDef({
    required this.primary,
    this.aliases = const [],
    required this.helpText,
    required this.handler,
    this.group = '基础',
    this.permission = 'player',
    this.panel = false,
  });

  bool matches(String cmd) {
    if (cmd == primary) return true;
    return aliases.contains(cmd);
  }
}

/// 全局注册表（单例）
class CommandRegistry {
  CommandRegistry._();
  static final CommandRegistry instance = CommandRegistry._();

  final List<CommandDef> _all = [];
  bool _sealed = false;

  /// 所有注册的命令（/帮助 用）
  List<CommandDef> get all => List.unmodifiable(_all);

  /// 注册一批命令（mixin 在 attach 时调用）
  void registerAll(Iterable<CommandDef> commands) {
    if (_sealed) {
      throw StateError('CommandRegistry 已 sealed，不能再注册。');
    }
    _all.addAll(commands);
  }

  /// 注册完成后调用，防止后续修改
  void seal() => _sealed = true;

  /// 清空（用于 resetAllState / 测试隔离）
  void resetForTesting() {
    _all.clear();
    _sealed = false;
  }

  /// 按 cmd 名查找
  CommandDef? find(String cmd) {
    for (final c in _all) {
      if (c.matches(cmd)) return c;
    }
    return null;
  }

  /// 生成 /帮助 文本（按 group 分组）
  String buildHelpText({String? filterPermission}) {
    final buf = StringBuffer('【指令系统】\n');
    final groups = <String, List<CommandDef>>{};
    for (final c in _all) {
      if (filterPermission != null && c.permission != filterPermission) continue;
      groups.putIfAbsent(c.group, () => []).add(c);
    }
    for (final entry in groups.entries) {
      buf.writeln('—— ${entry.key} ——');
      for (final c in entry.value) {
        final aliasStr = c.aliases.isNotEmpty ? '（/${c.aliases.join('、/')}）' : '';
        buf.writeln('  /${c.primary}$aliasStr — ${c.helpText}');
      }
    }
    return buf.toString();
  }
}
