import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/crash_logger.dart';
import '../../utils/ai_debug_logger.dart';
import '../../utils/ui_helpers.dart';

class SettingsCrashSection extends StatefulWidget {
  final VoidCallback? onCleared;
  final void Function(CrashEntry entry)? onCrashEntryTap;
  final VoidCallback? onShowAll;

  const SettingsCrashSection({
    super.key,
    this.onCleared,
    this.onCrashEntryTap,
    this.onShowAll,
  });

  @override
  State<SettingsCrashSection> createState() => _SettingsCrashSectionState();
}

class _SettingsCrashSectionState extends State<SettingsCrashSection> {
  String _formatTime(DateTime t) {
    return '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text('$label:', style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCrashDetail(CrashEntry e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.bug_report, color: AppColors.danger, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('崩溃详情', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Color(0xFFD3A625)),
              onPressed: () {
                final text = '时间: ${e.time.toIso8601String()}\n'
                    '场景: ${e.screen}\n'
                    '错误: ${e.error}\n'
                    '补充: ${e.extra}\n'
                    '堆栈:\n${e.stackTrace}';
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              },
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('时间', e.time.toIso8601String()),
              if (e.screen.isNotEmpty) _buildDetailRow('场景', e.screen),
              if (e.extra.isNotEmpty) _buildDetailRow('补充', e.extra),
              const SizedBox(height: 8),
              const Text('错误信息', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Text(e.error, style: const TextStyle(fontSize: 12, color: Color(0xFFFFE4E4))),
              ),
              if (e.stackTrace.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('堆栈跟踪', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B949E))),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      e.stackTrace,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF8B949E), fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildCrashItem(CrashEntry e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF252C36),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: InkWell(
        onTap: () {
          if (widget.onCrashEntryTap != null) {
            widget.onCrashEntryTap!(e);
          } else {
            _showCrashDetail(e);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error, size: 14, color: AppColors.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    e.error.length > 60 ? '${e.error.substring(0, 60)}...' : e.error,
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatTime(e.time)}${e.screen.isNotEmpty ? ' · ${e.screen}' : ''}',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF8B949E)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllCrashLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          appBar: AppBar(
            title: Text('全部崩溃日志 (${CrashLogger.instance.entries.length})'),
            backgroundColor: const Color(0xFF161B22),
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // 心跳诊断：上次崩溃/卡死前最后在做的事（ANR 不会触发异常记录，
              // 靠这个定位"转圈卡死"发生在哪一步）
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💓 上次心跳（卡死前最后一步）',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDDB54A))),
                    const SizedBox(height: 6),
                    Text(
                      CrashLogger.instance.heartbeatSnapshot.isEmpty
                          ? '暂无心跳记录（重新启动后自动写入）'
                          : '${CrashLogger.instance.heartbeatSnapshot['time']}\n'
                              '最后在做：${CrashLogger.instance.heartbeatSnapshot['marker']}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF8B949E), height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...CrashLogger.instance.entries.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text('暂无崩溃记录',
                              style: TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 13)),
                        ),
                      ),
                    ]
                  : CrashLogger.instance.entries
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildCrashItem(e),
                          ))
                      .toList(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report, color: AppColors.danger, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('🐞 崩溃日志',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.danger)),
              ),
              TextButton(
                onPressed: CrashLogger.instance.entries.isEmpty
                    ? null
                    : () async {
                        await CrashLogger.instance.clear();
                        widget.onCleared?.call();
                        // 清日志要写文件，中途页面可能已经被关掉。下面那句
                        // ScaffoldMessenger 记得判 mounted，setState 却没判——
                        // 同一个回调里两种口径，漏的那个会在页面已卸载时抛异常。
                        if (!mounted) return;
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('崩溃日志已清除')),
                        );
                      },
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('清除', style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (CrashLogger.instance.entries.isEmpty)
            const Text('暂无崩溃记录，游戏运行稳定 ✅',
                style: TextStyle(fontSize: 12, color: Color(0xFF10B981)))
          else ...[
            Text('共记录 ${CrashLogger.instance.entries.length} 次崩溃',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
            const SizedBox(height: 10),
            ...CrashLogger.instance.entries.take(3).map((e) => _buildCrashItem(e)),
            if (CrashLogger.instance.entries.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (widget.onShowAll != null) {
                      widget.onShowAll!();
                    } else {
                      _showAllCrashLogs();
                    }
                  },
                  icon: const Icon(Icons.list, size: 16),
                  label: Text('查看全部 (${CrashLogger.instance.entries.length})'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size.fromHeight(40),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class LogViewerDialog extends StatefulWidget {
  final List<String> logFiles;
  const LogViewerDialog({super.key, required this.logFiles});

  @override
  State<LogViewerDialog> createState() => _LogViewerDialogState();
}

class _LogViewerDialogState extends State<LogViewerDialog> {
  String? _selectedFile;
  String? _fileContent;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.logFiles.isNotEmpty) {
      _loadFile(widget.logFiles.first);
    }
  }

  Future<void> _loadFile(String path) async {
    setState(() {
      _isLoading = true;
      _selectedFile = path;
    });
    final content = await AiDebugLogger.instance.readLogFile(path);
    if (mounted) {
      setState(() {
        _fileContent = content ?? '无法读取文件';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI 调用日志'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.logFiles.length,
                itemBuilder: (context, index) {
                  final file = widget.logFiles[index];
                  final isSelected = file == _selectedFile;
                  return Padding(
                    padding: const EdgeInsets.all(4),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
                        foregroundColor: isSelected ? Colors.white : Colors.black,
                      ),
                      onPressed: () => _loadFile(file),
                      child: Text(
                        file.split('/').last,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _fileContent ?? '选择一个日志文件查看',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
