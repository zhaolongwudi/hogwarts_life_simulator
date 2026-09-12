/// 人格原型 → 偏好映射（数据层）。
///
/// 为什么放在 data 层而不是 mixin 里：
/// `mixin A on GameProviderBase` 中，`this` 的静态类型是该 mixin 自身，
/// 跨文件调用**另一个** mixin（`GameRelationsMixin`）里的成员时，
/// 即便在 `GameProviderBase` 上补了抽象声明，analyzer 仍按 mixin 自身作用域解析，
/// 会报 undefined_method。纯数据映射本来也不该挂在 mixin 上——
/// 下沉成顶层函数后，`mixin_init`（装载预设NPC）和
/// `mixin_relations`（生成原创NPC）都能直接调，没有循环依赖。

/// 原型 → 人格关键词
const Map<String, List<String>> kArchetypeTraits = {
  '勇敢型': ['勇敢', '直率', '热情', '正义', '无畏'],
  '智慧型': ['理性', '聪明', '好奇', '独立', '博学', '机智'],
  '温柔型': ['善良', '温柔', '体贴', '细腻', '柔和'],
  '野心型': ['野心', '精明', '果断', '领导', '傲慢'],
  '忠诚型': ['忠诚', '正直', '勤勉', '耐心', '可靠'],
  '神秘型': ['神秘', '内敛', '深沉', '敏感', '阴郁'],
  '幽默型': ['幽默', '乐观', '善于交际', '活泼', '开朗'],
  '叛逆型': ['叛逆', '挑战权威', '不羁', '古怪'],
};

/// 原型 → 挚爱礼物（名称 → 分值）
///
/// 这张表里的每个名字都必须能在 kItemCatalog 里找到，否则玩家送不出、
/// 送礼判定永远是 unknown 档。此前「羽毛笔」就是个对不上的名字
/// （目录里叫「新羽毛笔」）。一致性由 test 里的断言守住。
///
/// 末尾的材料项不只是凑数：禁林采集是材料唯一的产出途径，而材料此前
/// 没有任何消耗途径，采回来只能堆在背包里。让部分原型偏好材料，等于
/// 给「去禁林翻树根」这件事一个真实的理由。
const Map<String, Map<String, int>> kArchetypeGiftPrefs = {
  '勇敢型': {'魁地奇徽章': 8, '勇气勋章': 6, '龙血': 5, '巧克力蛙': 2},
  '智慧型': {'旧书': 8, '新羽毛笔': 5, '独角兽毛': 4, '巧克力蛙': 2},
  '温柔型': {'花束': 8, '手写贺卡': 5, '独角兽毛': 3, '巧克力蛙': 3},
  '野心型': {'计划书': 8, '银色钢笔': 6, '蛇的毒牙': 5, '巧克力蛙': 2},
  '忠诚型': {'编织围巾': 8, '自制点心': 5, '巧克力蛙': 3},
  '神秘型': {'神秘符号': 8, '魔法道具': 6, '凤羽': 7, '巧克力蛙': 2},
  '幽默型': {'恶作剧玩具': 8, '笑话集': 5, '巧克力蛙': 3},
  '叛逆型': {'朋克饰品': 8, '摇滚专辑': 6, '龙血': 3, '巧克力蛙': 2},
};

/// 由人格特质反推原型（无命中时退回「神秘型」）。
///
/// 56 位预设/原著 NPC 的 giftPrefs 在 npc_data.dart 里全是空的，
/// 而送礼玩法完全靠 giftPrefs 判定「送对了没有」——空的后果是所有人的
/// 反应一模一样，送礼退化成随机数。这里按人格给他们补一套原型。
String archetypeOfPersonality(List<String> personality) {
  final joined = personality.join('');
  var best = '神秘型';
  var bestScore = 0;
  for (final entry in kArchetypeTraits.entries) {
    var score = 0;
    for (final t in entry.value) {
      if (joined.contains(t)) score++;
    }
    if (score > bestScore) {
      bestScore = score;
      best = entry.key;
    }
  }
  return best;
}

/// 原型 → 礼物偏好表（未知原型退回只喜欢巧克力蛙）
Map<String, int> giftPrefsForArchetype(String archetype) =>
    Map<String, int>.from(
        kArchetypeGiftPrefs[archetype] ?? const {'巧克力蛙': 2});
