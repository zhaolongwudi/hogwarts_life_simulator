import '../models/long_term_memory.dart';

/// Issue #18：长期记忆 importance 按事件类型集中配置。
///
/// 修复前：importance 值散落在 6 个文件 15 处硬编码（5/6/7/8/9），
/// 调整某个事件类型的重要性需要全局搜索替换，容易漏改。
///
/// 修复后：所有 importance 值集中在此文件，按事件类型命名，
/// 调整只需改一处常量。
///
/// 分级标准：
/// - 9 = 永不遗忘层（kPersistentFactImportance）：定义"你是谁"的核心事实
/// - 8 = 里程碑：改变故事走向的重大事件
/// - 7 = 重要：对角色关系或剧情有实质影响
/// - 6 = 一般：值得记录但不影响主线
/// - 5 = 次要：日常事件，容量不足时优先淘汰

// ===== 9 级：永不遗忘层 =====

/// 剧情结局——整局最该被记住的事。
const int kImportanceStoryEnding = kPersistentFactImportance;

/// 作弊命令写入的秘密——玩家主动获取的隐藏信息。
const int kImportanceCheatSecret = kPersistentFactImportance;

// ===== 8 级：里程碑 =====

/// 新篇章开启——《哈利·波特》系列剧情推进到下一部。
const int kImportanceStoryBegin = 8;

// ===== 7 级：重要 =====

/// 主线剧情开始——进入原著时间线。
const int kImportanceStoryStart = 7;

/// AI 提取的悬念/问题——AI 叙事中识别出的未解之谜。
const int kImportanceAiExtractedLoop = 7;

/// 宿敌终结——与宿敌的对抗关系结束。
const int kImportanceRivalEnded = 7;

// ===== 6 级：一般 =====

/// 离线世界事件——离线期间发生的世界变化（兜底值）。
const int kImportanceOfflineWorldEvent = 6;

/// 剧情效果开启的悬念——story effect 中声明的 open loop。
const int kImportanceStoryEffectLoop = 6;

/// AI 提取的悬念（foreshadow）——AI 叙事中提取的伏笔。
const int kImportanceAiForeshadowLoop = 6;

/// AI 提取的世界事件——AI 叙事中自动提取的世界事件。
const int kImportanceAiWorldEvent = 6;

/// What-if 采纳——玩家采纳的假设分支。
const int kImportanceWhatIf = 6;

// ===== 5 级：次要 =====

/// 离线 NPC 关系——离线期间与 NPC 的往来记录。
const int kImportanceOfflineNpcRelation = 5;

/// 初次结识 NPC——主角第一次遇到某个 NPC。
const int kImportanceMeetNpc = 5;

/// 接取委托——玩家接受了一个委托任务。
const int kImportanceQuestOpen = 5;

/// 完成委托——玩家完成了一个委托任务。
const int kImportanceQuestDone = 5;

// ===== 10 级：超越永不遗忘层 =====

/// 主角死亡——整局最不可磨灭的事实。
const int kImportancePlayerDeath = 10;

/// 主角被捕——人生改道的不可逆事件。
const int kImportancePlayerImprisoned = 10;

// ===== 4 级：极低 =====

/// 离线剧情 flag 未解决事项——剧情中起了头但没推进的线索。
const int kImportanceOfflineFlagLoop = 4;

/// 完成委托的世界事件——委托完成后的事件记录。
const int kImportanceQuestDoneEvent = 4;
