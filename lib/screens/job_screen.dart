import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/game_systems.dart';
import '../data/job_data.dart';

class JobScreen extends StatefulWidget {
  const JobScreen({super.key});

  @override
  State<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends State<JobScreen> {
  List<JobDef> _jobs = [];

  @override
  void initState() {
    super.initState();
    _generateJobs();
  }

  void _generateJobs() {
    _jobs = List<JobDef>.from(jobCatalog);
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
            onPressed: () {
              setState(() => _generateJobs());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('岗位已刷新')),
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
              child: Text(
                '搜岗位 / 公司 / 附近机会',
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color),
              ),
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
    if (_jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_off, size: 64, color: Theme.of(context).textTheme.bodyMedium!.color),
            const SizedBox(height: 12),
            Text('暂无岗位', style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium!.color)),
            const SizedBox(height: 8),
            Text('让 AI 根据你现在的位置、属性和剧情生成工作机会',
                style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium!.color), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _jobs.length,
      itemBuilder: (context, index) => _buildJobCard(_jobs[index]),
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
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
