/// 穿越者原著记忆等级（框架2 §11：原著记忆程度随机，
/// 且蝴蝶效应发生后记忆会越来越不可靠）。
///
/// 原住民没有这个字段；穿越者在开局时随机掷档写入存档。
/// 每一档给出不同的系统提示词注入文案——同为穿越者，
/// "把原著当攻略书背得滚瓜烂熟"和"只记得伏地魔最后会失败"是两种人设。
library;

/// 记忆等级枚举（name 写入 Player.transmemoryLevel 存档）
enum TransmemoryLevel {
  /// 非常熟悉：把原著当攻略书，细节张口就来
  vivid,

  /// 看过电影但忘掉很多细节
  partial,

  /// 很久以前看过，只剩模糊印象
  faded,

  /// 只知道伏地魔最后会失败
  endingOnly,

  /// 部分记忆存在错误（人名/顺序/因果对不上）
  errors,
}

/// 开局掷档权重（总和 100）
const Map<TransmemoryLevel, int> kTransmemoryWeights = {
  TransmemoryLevel.vivid: 8,
  TransmemoryLevel.partial: 25,
  TransmemoryLevel.faded: 25,
  TransmemoryLevel.endingOnly: 22,
  TransmemoryLevel.errors: 20,
};

/// 按名称解析（存档兼容：未知值回退 partial）
TransmemoryLevel transmemoryLevelFromName(String? name) {
  if (name == null) return TransmemoryLevel.partial;
  for (final l in TransmemoryLevel.values) {
    if (l.name == name) return l;
  }
  return TransmemoryLevel.partial;
}

/// 系统提示词注入文案（[deviation] 为世界线变动率，越高记忆越不可靠）
String transmemoryPromptLine(TransmemoryLevel level, double deviation) {
  final base = switch (level) {
    TransmemoryLevel.vivid =>
      '你是穿越者，对原作的剧情走向、人物结局、关键时间点都非常熟悉'
          '（近乎逐字记忆）。你可以把原著当行动依据，但他人不会轻信"预言"，'
          '引用未来信息需克制并举证自洽；你越是精确地"预知"，越会引来怀疑。',
    TransmemoryLevel.partial =>
      '你是穿越者，看过《哈利·波特》但忘掉了大量细节：只记得主要人物和'
          '几件大事的大致轮廓，具体年份、过程、顺序都模糊。把记忆当模糊参考，'
          '别把细节当事实写死。',
    TransmemoryLevel.faded =>
      '你是穿越者，很多年前看过这个故事，如今只剩模糊印象：'
          '隐约知道"有个戴眼镜的男孩"，知道霍格沃茨有四个学院，'
          '其他的都记不清了。',
    TransmemoryLevel.endingOnly =>
      '你是穿越者，对原作几乎一无所知，只隐约记得一句话：'
          '"伏地魔最后会失败"。你甚至不知道他是谁、在哪一年失败。',
    TransmemoryLevel.errors =>
      '你是穿越者，但你的记忆存在错误：人名、时间线、因果顺序都有对不上的'
          '地方（例如记错了某个人是死是活、记错了关键事件的年份）。'
          '不要强行引用记忆中的细节，想不起来就说不记得。',
  };
  // 蝴蝶效应后记忆越来越不可靠（框架2 §11 末句）
  final reliability = deviation >= 0.5
      ? '⚠️ 世界线已经被你改动得面目全非（变动率 ${(deviation * 100).toStringAsFixed(1)}%），'
            '你的原著记忆正在变得不可靠——以当前世界的事实为准，别再依赖记忆里的"剧透"。'
      : '';
  return '【身份模式】穿越者：$base$reliability';
}
