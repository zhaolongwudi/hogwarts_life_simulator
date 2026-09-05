import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/game_systems.dart';
import '../services/ai_router.dart';
import '../data/job_data.dart';
import '../data/locations.dart';
import '../theme/miuix_tokens.dart';
import '../widgets/miuix_overlays.dart';

class JobScreen extends StatefulWidget {
  const JobScreen({super.key});

  @override
  State<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends State<JobScreen> {
  List<JobDef> _jobs = [];
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _generateJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 排序规则对应副标题那句「根据你的位置和属性推荐」：
  /// 同城优先 → 体力吃得消的优先 → 时薪高的优先。
  /// 以前这里是 `List.from(jobCatalog)`，刷新按钮点了十次列表一帧不变。
  void _generateJobs() {
    final location = context.read<GameProvider>().worldState.currentLocation ?? '';
    final energy = context.read<GameProvider>().player?.energy ?? 0;

    int score(JobDef j) {
      var s = 0;
      // 两边都先归一化到规范主名，再按包含关系加分：
      // 玩家在 '霍格沃茨·场地' 时，岗位 '海格的小屋'（该主名的别名）也能命中，
      // 而不是靠裸子串「海格小屋」碰运气（以前解析不出、永远吃不到加成）。
      final loc = resolveLocationName(location) ?? location;
      final jLoc = resolveLocationName(j.location) ?? j.location;
      if (loc.isNotEmpty && jLoc.contains(loc)) s += 100;
      if (loc.isNotEmpty && loc.contains(jLoc)) s += 60;
      if (j.energyCost <= energy) s += 30;
      // 时薪（加隆/小时）放大 10 倍取整，避免浮点
      s += (j.pay * 600 / (j.minutes <= 0 ? 60 : j.minutes)).round();
      return s;
    }

    final list = List<JobDef>.from(jobCatalog)
      ..sort((a, b) => score(b).compareTo(score(a)));
    _jobs = list;
  }

  bool _aiLoading = false;

  /// 让 AI 按玩家当下的处境（位置/体力/钱/剧情近况）想一个活儿。
  ///
  /// 这个箭头以前是 `onPressed: () {}`，全项目唯一一处空回调——
  /// 卡片上明明白白写着「让 AI 根据剧情生成专属工作机会」，点了毫无反应。
  Future<void> _askAiForWork() async {
    final gp = context.read<GameProvider>();
    final p = gp.player;
    if (p == null) return;
    if (gp.router == null || !(gp.router?.hasNarrativeService ?? false)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先在设置里配置一个 AI 提供商')),
      );
      return;
    }

    setState(() => _aiLoading = true);
    try {
      final location = gp.worldState.currentLocation ?? '霍格沃茨';
      final prompt = '【魔法世界 · 打工推荐】\n'
          '玩家：${p.name}（${(p.house?.isEmpty ?? true) ? '未分院' : p.house}，第${p.grade}年）\n'
          '当前时间地点：${gp.worldState.timestamp}｜$location\n'
          '体力 ${p.energy}／100，钱包 ${p.galleons} 加隆\n'
          '最近经历：${gp.recentTurns.isEmpty ? '（暂无）' : gp.recentTurns.last.substring(0, gp.recentTurns.last.length > 120 ? 120 : gp.recentTurns.last.length)}\n\n'
          '请为这个角色想 1 个此刻确实做得成、且贴合处境的临时活计：'
          '写出活计名称、在哪儿干、大概耗时、报酬（加隆）和一句风险或趣事。'
          '120 字以内，直接给内容，不要客套话，不要列点。';
      final result = await gp.callDeepSeek(prompt, scene: AiScene.npcChat);
      if (!mounted) return;
      _showAiWorkDialog(result.content.trim());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 暂时没想出来：$e')),
      );
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  void _showAiWorkDialog(String content) {
    showMiuixDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 给你想的活儿'),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我再想想'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('想接这个活？在剧情框里直接写下你的行动')),
              );
            },
            child: const Text('知道啦'),
          ),
        ],
      ),
    );
  }

  /// 搜索命中标题 / 地点 / 描述 / 要求。
  List<JobDef> get _visibleJobs {
    if (_keyword.isEmpty) return _jobs;
    final kw = _keyword.toLowerCase();
    return _jobs
        .where((j) =>
            j.title.toLowerCase().contains(kw) ||
            j.location.toLowerCase().contains(kw) ||
            j.description.toLowerCase().contains(kw) ||
            j.requirements.toLowerCase().contains(kw))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final player = gp.player;

    return Scaffold(
      appBar: AppBar(
        title: const Text('找点活干'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '按当前位置和体力重新排序',
            onPressed: () {
              setState(() => _generateJobs());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已按你的位置和体力重新排序')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildStatusCards(player),
          Expanded(child: _buildJobList()),
          _buildAiSuggestion(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerTheme.color!),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Theme.of(context).textTheme.bodyMedium!.color),
            const SizedBox(width: 8),
            Expanded(
              // 以前这里是个 Text，看着像搜索框其实点不动、也绑了没有任何过滤逻辑。
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _keyword = v.trim()),
                decoration: const InputDecoration(
                  hintText: '搜岗位 / 地点 / 要求',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium!.color,
                  fontSize: 14,
                ),
              ),
            ),
            if (_keyword.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _keyword = '');
                },
                child: const Icon(Icons.close, size: 18, color: MiuiColors.onSurfaceVariantSummary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCards(player) {
    final gp = context.read<GameProvider>();
    final ws = gp.worldState;
    final grade = player?.grade ?? 1;
    final monthLabel = GameTime.months[ws.time.month - 1];
    final location = ws.currentLocation ?? '霍格沃茨';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$location · 第${grade}年·$monthLabel',
            style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium!.color),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  '可投入体力',
                  '${player?.energy ?? 5}',
                  Icons.bolt,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusCard(
                  '钱包余额',
                  '${player?.galleons ?? 0}',
                  Icons.account_balance_wallet,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerTheme.color!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('今天有什么活适合你?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('根据你的位置和属性推荐', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.work, color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobList() {
    final visible = _visibleJobs;
    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_keyword.isEmpty ? Icons.work_off : Icons.search_off,
                size: 64, color: Theme.of(context).textTheme.bodyMedium!.color),
            const SizedBox(height: 12),
            Text(_keyword.isEmpty ? '暂无岗位' : '没有匹配「$_keyword」的岗位',
                style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium!.color)),
            const SizedBox(height: 8),
            Text(_keyword.isEmpty
                ? '让 AI 根据你现在的位置、属性和剧情生成工作机会'
                : '换个关键词，或点右上角的 ✕ 清空',
                style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium!.color),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: visible.length,
      itemBuilder: (context, index) => _buildJobCard(visible[index]),
    );
  }

  Widget _buildJobCard(JobDef job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: Theme.of(context).textTheme.bodyMedium!.color),
                        const SizedBox(width: 2),
                        Text(job.location, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('+${job.pay}加隆', style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(job.description, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium!.color), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTag(Icons.bolt, '体力 ${job.energyCost}', Colors.amber),
              const SizedBox(width: 8),
              _buildTag(Icons.timer, '${job.minutes ~/ 60}小时', Colors.blue),
              const SizedBox(width: 8),
              _buildTag(Icons.verified_user, job.requirements, Colors.purple),
              const Spacer(),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final gp = context.read<GameProvider>();
                    final pay = gp.acceptJob(job.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: pay > 0 ? Text('完成岗位 ${job.title}，获得 $pay 加隆') : const Text('打工失败')),
                    );
                  },
                  child: const Text('接受', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _buildAiSuggestion() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI 智能推荐', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('让 AI 根据剧情生成专属工作机会', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                ],
              ),
            ),
            _aiLoading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: '让 AI 按你目前的处境想想能干点什么',
                    onPressed: _askAiForWork,
                  ),
          ],
        ),
      ),
    );
  }
}
