/// 日志文件/目录名的统一收口（审查 SI3）。
///
/// 此前 CrashLogger（`crash_logs.json` / `heartbeat.json`）与 AiDebugLogger
/// （`ai_debug_logs/`）各自在源码里硬编码路径字符串，散落多处、改一处忘一处。
/// 这里把"这些日志文件叫什么、放哪儿"集中成常量，三个 logger 全部引用，
/// 以后改名/搬目录只需改这一处，测试也能拿常量断言。
///
/// 注意：只统一**相对文档目录的文件名**，不迁移已有文件的位置——
/// 传统玩家设备上可能已存在旧路径的日志，动位置会产生孤儿文件。
library;

/// 崩溃日志文件名（CrashLogger，位于应用文档目录根）。
const String kCrashLogFileName = 'crash_logs.json';

/// 心跳标记文件名（CrashLogger，位于应用文档目录根）。
const String kHeartbeatFileName = 'heartbeat.json';

/// AI 调试日志目录名（AiDebugLogger，位于应用文档目录根）。
const String kAiDebugLogDirName = 'ai_debug_logs';