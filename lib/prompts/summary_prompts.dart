/// 剧情摘要压缩 Prompt。

/// 前情摘要分层压缩的**尾部**配额（Q4，v5 修正为头尾双保）。
///
/// `previousSummary` 是**累积拼接**的历史摘要：按周期追加一次、limit 随
/// 进度放宽到 2400 字，长线玩到一两百回合后，单是前情就 1 万字起步，
/// 每次都原样塞进摘要 prompt，输入 token 随局龄线性膨胀。
/// 这里做分层压缩，超出配额时**头尾各保一段**：
///
///   · **尾部**（本常量）：紧邻新 chunk 的那段旧摘要。新剧情承接的是它，
///     保留才能不脱缝——这是原实现的唯一考虑。
///   · **头部**（[kMaxPreviousHeadChars]）：最早那段历史摘要。它承载着
///     开局身份、初始关系、早期承诺这些"地基"型事实。
///
/// 【为什么要补头部】旧实现只保尾部，头部只剩一行 `已有 N 字历史摘要`。
/// 后果是摘要 AI **看不到历史全貌**，会把"最近发生的事"当成"整段历史"来压缩，
/// 产出偏重近期的摘要；而这份摘要又会被 `_extractMemoryFromSummary`
/// 固化成 9 分 T0 事实再注入 prompt——偏差因此一轮轮自我强化。
/// 作者自己在 `mixin_narrative.dart` 里批判过同类问题（"从中期开始
/// narrativeSummary 永久不再进入 prompt"），这里是把同一批评用在自己身上。
const int kMaxPreviousChars = 1400;

/// 前情摘要分层压缩的**头部**配额。
///
/// 取值小于尾部配额：头部的作用是锚住"地基事实"（开局身份/初始关系），
/// 信息密度高、篇幅需求低；尾部需要保留足够上下文供新 chunk 缝合。
const int kMaxPreviousHeadChars = 600;

/// 分层压缩后的前情摘要 + 压缩元信息（便于测试断言与调试）。
class LayeredPreviousSummary {
  /// 实际拼进 prompt 的文本。
  final String text;

  /// 原始长度。
  final int originalLength;

  /// 是否触发了压缩。
  final bool compressed;

  const LayeredPreviousSummary({
    required this.text,
    required this.originalLength,
    required this.compressed,
  });

  /// 压缩掉的字数（未压缩时为 0）。
  int get elidedChars => compressed
      ? originalLength - kMaxPreviousHeadChars - kMaxPreviousChars
      : 0;
}

/// 对累积前情做分层压缩（纯函数，便于单测）。
///
/// 未超限时原样返回；超限时保留头部 [kMaxPreviousHeadChars] 字
/// + 中间省略提示 + 尾部 [kMaxPreviousChars] 字。
LayeredPreviousSummary layerPreviousSummary(String previousSummary) {
  final total = previousSummary.length;
  if (total <= kMaxPreviousHeadChars + kMaxPreviousChars) {
    return LayeredPreviousSummary(
      text: previousSummary,
      originalLength: total,
      compressed: false,
    );
  }
  final head = previousSummary.substring(0, kMaxPreviousHeadChars);
  final tail = previousSummary.substring(total - kMaxPreviousChars);
  final elided = total - kMaxPreviousHeadChars - kMaxPreviousChars;
  return LayeredPreviousSummary(
    text: '【最早一段】$head\n'
        '（中间 $elided 字历史摘要省略——如需回溯请参考 T0/T1/T3 结构化记忆）\n'
        '【最近一段】$tail',
    originalLength: total,
    compressed: true,
  );
}

/// 构造摘要压缩 Prompt。
/// [limit] 字数上限 (AI 侧目标)，[previousSummary] 老摘要，[newChunk] 新剧情正文块，
/// [relSnapshot] 当前NPC关系快照（以此校准，不要让 AI 凭印象写）。
/// [coreFacts] 主角既定事实（来自 Player 权威字段，非记忆层——防止摘要 AI
/// 凭叙事猜测把哈利特征张冠李戴到原创主角身上，如"闪电疤/猫头鹰宠物"）。
String buildSummaryPrompt({
  required int limit,
  required String previousSummary,
  required String newChunk,
  required String relSnapshot,
  required String coreFacts,
}) {
  // Q4：对累积的前情做头尾双保的分层压缩。短局不触发，行为与旧版一致。
  final layeredPrevious = layerPreviousSummary(previousSummary).text;

  return '''请将以下剧情内容压缩成摘要。重要规则：
  1. 只保留【人物关系变化】和【重要剧情转折】
  2. 淘汰具体场景描述（如"在车站"、"在教室"、"列车走廊"等地点信息），这些会严重干扰后续剧情生成
  3. 淘汰具体行动描述（如"检票上车"、"拿出魔杖"等），除非是关键转折点
  4. 保留 NPC 好感度变化（如"赫敏:友好+10"）、学院分配、重要事件等。⚠️ 注意：好感度数值格式（如"友好+10"）是系统内部数据表示，仅供本摘要层使用，不写入叙事正文
  5. 保留关键伏笔、NPC承诺、秘密、未完成任务、冲突起源、长期目标（这些是长线剧情的锚，必须单独归纳）
  6. 用简洁的第三人称
  7. 绝对禁止保留一次性冲突/怪物事件（如"巨怪事件""某个小决斗"）的具体场景和过程，仅保留对人物关系造成的长期影响（例如："与罗恩因共同抗敌建立信任"而非"在厕所击败巨怪"）
  8. 严格遵守【精简剧情摘要】不超过 $limit 字，超过部分会被直接截断，超出规则会导致后续剧情冲突

  【主角既定事实】（权威设定，摘要【核心事实】必须与以下内容完全一致，严禁冲突或张冠李戴）
  ${coreFacts.isNotEmpty ? coreFacts : '（暂无）'}

  【前情摘要】
  ${layeredPrevious.isNotEmpty ? layeredPrevious : '（开局）'}

  【新剧情】
  $newChunk

  【当前关系状态】（以此为准校准）
  ${relSnapshot.isNotEmpty ? relSnapshot : '暂无'}

  请输出：
  1. 精简剧情摘要（不超过$limit字，聚焦关系和转折，不要保留具体场景）
  2. 末尾单独一行【关系】列出当前重要NPC的关系状态（如：赫敏:友好/72；马尔福:敌对/-30）
  3. 如果有伏笔/承诺/秘密/未完成任务，再单独一行【伏笔】列出（例如：斯内普答应给主角保密身份；主角欠邓布利多一次夜探；小天狼星留了一把钥匙）
  4. 单独一行【核心事实】列出本段剧情确立的、后续绝不能遗忘的纯事实（身份/血统/魔杖/宠物/特殊能力/重大秘密等，每条一行，第三人称陈述，无则写"无"）。⚠️ 必须与上方【主角既定事实】一致：魔杖材料/杖芯、宠物物种与名字、主角身份等一律以既定事实为准，禁止编造或与哈利·波特混淆
  5. 单独一行【世界事件】列出本段剧情发生的、影响后续走向的重大事件（每条格式：事件标题|事件描述，无则写"无"）
  6. 单独一行【了结】列出本段剧情里**真正了结了的**伏笔、承诺、约定或疑问。写法要求：尽量照抄当初【伏笔】里的说法，不要改写、不要概括、不要加自己的评价——后面要靠这段话去认出是哪件事。每条一行；本段没有东西了结就整行不写，绝对不要为了凑格式而写"无"''';
}
