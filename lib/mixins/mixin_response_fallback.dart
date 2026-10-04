/// 降级叙事与选项生成子系统（r6-1 拆分自 mixin_response.dart）。
///
/// 【它解决什么问题】AI 不可用 / 降级 / 空响应时，游戏必须仍然「有话说、
/// 有事做、有选项点」：本地种子语料拼装降级叙事（[generateFallbackNarrative]）、
/// 结构化备选选项（`generateFallbackChoices` / `buildFallbackChoices`）、
/// 玩法快捷选项（`buildGameplayOptions`）与自动推进（`pickAutoAdvanceChoice` /
/// `processAutoAdvanceChoice`）。离线红线：本文件零 AI 调用，纯本地。
///
/// 【组合方式】`GameResponseMixin` 声明 `on GameResponseFallbackMixin`
/// （跨 mixin 走 on 链，遵守 ADR-001）。
library;

import '../models/game_systems.dart';
import '../narrative/offline_narrative_context.dart';
import '../providers/game_provider_base.dart';
import 'mixin_response_choices.dart';
import 'mixin_play.dart';

/// 引号台词后的说话人归属（「……」她说 / 「……」X 道）。
final RegExp reSpeakerAfterQuote = RegExp(
  r'[」"】][^，。！？\n]*?(养母|养父|海格|邓布利多|斯内普|麦格|哈利|罗恩|赫敏|马尔福|教授|同学|级长|妈妈|爸爸|NPC)[^，。！？\n]{0,10}(说|开口|问|道|回答|叹了口气|笑了笑|低声|沉声|看着你)',
  caseSensitive: false,
);

/// 抓取引号内的台词本体。
final RegExp reQuotedDialog = RegExp(
  r'[「"]([^「"」]{2,40})[」"]',
);


mixin GameResponseFallbackMixin on GameProviderBase, GameResponseChoiceMixin {
  @override
  String generateFallbackNarrative() {
    final p = player;
    if (p == null) return '你站在霍格沃茨的走廊上，等待着下一段旅程。';

    final location = worldState.currentLocation ?? '霍格沃茨';
    final time = worldState.timestamp;
    final weather = worldState.weather ?? '晴朗';
    final grade = p.grade ?? 1;

    // 事件种子：AI 失败时给离线叙事一点"正在发生的事"，而不是干巴巴的地点介绍。
    // 与天气/环境结合，让同一地点不同回合也有差异。
    //
    // 【为什么要按地点分池】早期版本只有一个全局池，直接在礼堂放出"走廊尽头
    // 传来脚步声"还算合理，但玩家在禁林里读到"礼堂飘来南瓜汁的香气"就出戏了。
    // 现在先按地点挑池、再按天气补一条，最后用 turnCount 错开，重复率显著下降。
    final eventSeeds = _fallbackSeedsFor(location, weather, p.grade ?? 1, p.name);

    // 【帧的多样性】4 个帧在长局里第五回合就循环了。补到 8 个，并让每一帧
    // 带上不同的**叙事职责**：陈述日常 / 抛出异常 / 回应玩家身份 / 只给氛围。
    // 玩家连点十次"自由行动"看到的开头不再是一句复读。
    final frames = <String>[
      '$time\n\n你站在$location。$weather的天气里，魔法世界的脉搏平稳地跳动着。\n\n${_pickFallbackEvent(eventSeeds)}\n\n接下来，你打算做些什么？',
      '$time\n\n$location的日常在继续：上课、聊天、追逐、争吵——这就是霍格沃茨的又一天。\n\n${_pickFallbackEvent(eventSeeds)}\n\n你的选择，会把它推向不同的方向。',
      '$time\n\n作为$grade年级的学生，你已经熟悉了这里的每一条走廊、每一幅会说话的画像。但今天似乎有些不同。\n\n${_pickFallbackEvent(eventSeeds)}\n\n你决定——',
      '$time\n\n${p.name}，你身处$location。魔法世界里没有真正静止的时刻，而你就是此刻故事的中心。\n\n${_pickFallbackEvent(eventSeeds)}',
      '$time\n\n$location。$weather。\n\n${_pickFallbackEvent(eventSeeds)}\n\n没有什么非做不可的事，这本身就很罕见。',
      '$time\n\n你在$location停下来，看了一眼天色。\n\n${_pickFallbackEvent(eventSeeds)}\n\n有些日子不会写进任何人的回忆录，但它确实发生过。',
      '$time\n\n$location今天比平时安静一点。\n\n${_pickFallbackEvent(eventSeeds)}\n\n安静通常不是坏事，除非你知道它在等什么。',
      '$time\n\n$grade年级的日程排得不算紧，你还有些自己的时间。\n\n${_pickFallbackEvent(eventSeeds)}\n\n这段时间怎么用，由你决定。',
    ];

    // 【为什么不用 turnCount】`turnCount` 在新书开局时会被归零（见
    // `_enterNextBook` 的注释），七部曲跑下来它会重置六次。用它取模，
    // 玩家每次换部都会看到兜底叙事从第 0 帧重新开始——在一个"长期玩"
    // 的设计里这很出戏。改用只增不减的 `_fallbackFrameSeq`。
    final idx = (_fallbackFrameSeq++) % frames.length;
    final base = frames[idx];

    // 个性化增强：在帧尾追加一句「这段存档自己的故事」。
    // 【为什么不插在帧首】离线兜底的多样性测试锁定了第二段正文必须
    // 8 回合不重复、且必须包含地点名。染色句只追加在末尾、不碰既有
    // 8 帧与地点种子池，因此这些不变量全部保持。
    final ctx = OfflineNarrativeContext.build(
      player: p,
      memory: memory,
      npcRegistry: npcRegistry,
    );
    final enhance = ctx.pick(_fallbackEnhanceSeq++);
    if (enhance.isEmpty) return base;
    return '$base\n\n${enhance.trim()}';
  }

  /// 个性化增强句的轮转序号。只增不减，与 `_fallbackFrameSeq` 同理，
  /// 跨书不重置，保证长局里染色句不会在某一本反复戳同一句。
  int _fallbackEnhanceSeq = 0;

  /// 兜底叙事的帧序号。只增不减，跨书不重置。
  ///
  /// 【为什么不用世界日/回合数】世界上限是七部 × 一学年，帧只有 8 个，
  /// 任何单调递增的计数都能均匀覆盖；用一个独立计数器最不容易被
  /// 别处的"重置进度"逻辑波及。
  int _fallbackFrameSeq = 0;

  /// 从事件种子池里取一条，尽量不与上一轮重复。
  String _pickFallbackEvent(List<String> seeds) {
    if (seeds.isEmpty) return '';
    // 简单轮换：turnCount 让种子自然错开，避免连续同一条
    return seeds[(turnCount + random.nextInt(seeds.length)) % seeds.length];
  }

  /// 按「地点 + 天气 + 年级」拼出本回合的候选事件池。
  ///
  /// 【池的叠放顺序】地点池（最具体，一定先出）→ 天气池（当日限定）
  /// → 年级池（只有低年级才有的经历）→ 通用池（任何地点都成立）。
  /// 叠放而不是替换，是为了让"禁林的雷雨夜"和"礼堂的晴天"都能取到
  /// 至少七八条候选——池太薄的话轮换会立刻被看穿。
  List<String> _fallbackSeedsFor(
    String location,
    String weather,
    int grade,
    String name,
  ) {
    final seeds = <String>[...?_locationSeeds[location]];

    // 天气池：只在几个有辨识度的天气下追加，避免"晴朗"这种占比最高的
    // 天气反而堆一堆同质描述。
    final weatherSeeds = _weatherSeeds[weather];
    if (weatherSeeds != null) seeds.addAll(weatherSeeds);

    // 年级池：低年级才有的"被规矩管着"的体感。
    if (grade <= 2) {
      seeds.addAll([
        '一个高年级生从你身边走过时顺手扶了一下你快要掉的书——他没停下脚步。',
        '你数了数，从这间教室走到下一间要经过四幅画像、两道楼梯，其中一道今天不听话。',
        '走廊上贴着新的告示，字比你认识的字还多，你只读懂了最后一行。',
      ]);
    } else if (grade >= 5) {
      seeds.addAll([
        '有人在你背后讨论考试，语气平静得不像是在讨论一件很急的事。',
        '图书馆靠窗的位置今天空着——你记下了这个时间点。',
        '你忽然发现自己已经能一眼看出哪条走廊在中午最挤。',
      ]);
    }

    // 通用池：兜住所有地点。
    seeds.addAll([
      '一只猫头鹰从你头顶掠过，丢下一封信，又振翅消失在窗外的暮色里。',
      '有几位同学聚在拐角低声讨论着什么，看见你走近，声音自然地小了下去。',
      '墙上的画像们正为某个话题争论不休，一位戴帽子的老绅士对你挤了挤眼。',
      '$name注意到$location的一角有些异样——某个平时不会注意到的细节，似乎和记忆里不太一样。',
    ]);

    return seeds;
  }


  static const Map<String, List<String>> _locationSeeds = {
    '霍格沃茨': [
      '走廊尽头传来一阵急促的脚步声——有同学正抱着厚厚一摞书跑向教室，其中两本摇摇欲坠。',
      '皮皮鬼从天花板上倒挂下来，冲你做了个鬼脸，又消失在墙里——他今天心情不错。',
      '远处的礼堂飘来南瓜汁和烤面包的香气，提醒你差不多该去吃饭了。',
      '窗外掠过一把飞天扫帚——是有人在练习，动作还不太熟练，几次差点撞上塔楼。',
      '楼梯今天换了三次方向，有位一年级生站在原地，看起来已经放弃了。',
      '公共休息室的火还在烧，椅子上搭着一条没人认领的围巾。',
    ],
    '大礼堂': [
      '长桌上空着的座位比平时多，浮在半空的蜡烛把每个人的脸照得很温和。',
      '教师席上有一位没来，他的椅子被人往桌下推了推。',
      '有人在餐桌底下传一张纸条，传到你这里时已经折了四折。',
      '天花板映着外面的天色，和盘子里冒的热气凑成很奇怪的一幅画。',
    ],
    '图书馆': [
      '平斯夫人在两排书架之间来回走，脚步比平时慢，说明她在找人。',
      '有人趴在摊开的书上睡着了，书页被压出一道折痕。',
      '靠窗那桌的四人小声争论着一道咒语的手势，谁也说服不了谁。',
      '书架深处传来很轻的翻页声——那里应该没有人才对。',
    ],
    '霍格莫德村': [
      '三把扫帚门口的雪被踩成了泥，进进出出的人把门推得吱呀响。',
      '蜂蜜公爵的橱窗换了新的陈设，最上面那盒糖会自己冒烟。',
      '有人蹲在路边回信，猫头鹰在他肩膀上等了很久，一点也没催他。',
      '风把告示栏上的纸吹起一角，露出底下贴的另一张。',
    ],
    '对角巷': [
      '奥利凡德的橱窗里换了新的魔杖盒，盒子上的灰积了一层。',
      '古灵阁的白台阶上有人上下，妖精们数钱的声音隔着门都能听见。',
      '破釜酒吧的窗玻璃上贴着通缉令，边角已经卷了。',
      '翻倒巷口有个穿斗篷的人站了很久，没有走进去也没有离开。',
    ],
    '禁林': [
      '某处的灌木动了动，然后停住——不是风。',
      '地上的痕迹很新，其中一串比你的手掌还大。',
      '树冠层里有翅膀拍打的声音，从头顶移到了身后。',
      '半空中的雾气没有随你移动，像被什么定住了。',
    ],
    '黑湖边': [
      '湖面平得像一面镜子，偶尔有个泡从深处冒上来。',
      '有人往水里丢了块石头，涟漪散开之后很快什么痕迹都没了。',
      '对岸的树林在雾里只剩一个轮廓，看不出有多深。',
    ],
    '球场': [
      '球门柱在风里发出很低的嗡嗡声，一根比一根响。',
      '看台上没人，但某排座椅上放着一副护目镜。',
      '草被踩出一条通往中间的窄路，不是正规的进场路线。',
    ],
  };

  /// 天气专属事件种子池。只有辨识度强的天气才列。
  static const Map<String, List<String>> _weatherSeeds = {
    '雨': [
      '雨敲在最近的窗上，节奏乱得像有人在上面走。',
      '屋檐下的水串成一道帘子，有人从底下冲过去，溅了一裤腿。',
    ],
    '雷雨': [
      '雷声从很远处滚过来，窗玻璃跟着轻轻震了一下。',
      '一道闪电过后，走廊里的画像集体沉默了两秒。',
    ],
    '雪': [
      '雪把窗台堆出了一道白边，有人在上面按了个手印。',
      '雪落进斗篷的领子里，冷得人一下清醒过来。',
    ],
    '雾': [
      '雾贴在地面上走，走到十步之外就看不清脚。',
      '雾里传来一声很短的咳嗽，你找不到是谁。',
    ],
    '阴': [
      '天色压得很低，蜡烛提前点上了。',
      '云把光滤成了灰白色，什么颜色都显得旧一点。',
    ],
  };

  @override
  List<GameChoice> generateFallbackChoices() {
    final location = worldState.currentLocation ?? '霍格沃茨';

    // 【为什么每个地点给 6~8 条而不是 4 条】选项靠 `turnCount % length` 轮换，
    // 池长 4 时每四回合就完整重现一次，玩家在长局里会立刻发现"不管选什么都
    // 是这几句"。加倍之后重复周期从 4 拉到 8，且每条都尽量带地点专属动作，
    // 让"在哪"这件事在选项层也成立。
    final locationChoices = {
      '霍格沃茨': [
        ('去教室上课', '前往教室学习'),
        ('在走廊散步', '在走廊里走动'),
        ('去大礼堂', '前往大礼堂'),
        ('找朋友聊天', '与朋友交谈'),
        ('去图书馆查点东西', '前往图书馆'),
        ('绕去公共休息室歇一会儿', '回公共休息室'),
        ('爬到天文塔顶上看一眼', '前往天文塔'),
        ('去厨房碰碰运气', '前往厨房'),
      ],
      '大礼堂': [
        ('坐下来好好吃一顿', '在大礼堂用餐'),
        ('看看新贴出来的通知', '查看通知'),
        ('和邻座的同学聊两句', '与邻座交谈'),
        ('等邮件来', '等待邮件'),
      ],
      '图书馆': [
        ('翻一本和下次魔咒课有关的书', '查阅魔咒书'),
        ('把作业写掉一部分', '在图书馆写作业'),
        ('找平斯夫人问资料放哪儿了', '询问图书管理员'),
        ('换个靠窗的位置坐', '换到窗边'),
      ],
      '霍格莫德村': [
        ('去三把扫帚酒吧', '前往三把扫帚'),
        ('逛蜂蜜公爵糖果店', '去糖果店'),
        ('拜访邮局', '去邮局寄信'),
        ('在街上慢慢走一圈', '在村里闲逛'),
        ('去看一眼尖叫棚屋', '前往尖叫棚屋'),
        ('返回霍格沃茨', '回到学校'),
      ],
      '对角巷': [
        ('去魔杖店', '前往奥利凡德'),
        ('逛魔法部', '去魔法部'),
        ('去古灵阁', '去古灵阁银行'),
        ('在破釜酒吧歇脚', '前往破釜酒吧'),
        ('去看看丽痕书店的新书', '前往书店'),
        ('返回霍格沃茨', '回到学校'),
      ],
      '禁林': [
        ('小心深入探索', '深入禁林'),
        ('观察神奇生物', '观察生物'),
        ('顺着地上的痕迹走', '追踪痕迹'),
        ('静下来听一会儿', '倾听周围'),
        ('原路返回', '返回安全区'),
        ('寻找光源', '寻找光源'),
      ],
      '黑湖边': [
        ('在岸边坐一会儿', '在湖边休息'),
        ('绕着湖走半圈', '沿湖散步'),
        ('看看水里有什么', '观察湖面'),
        ('回城堡去', '返回城堡'),
      ],
      '球场': [
        ('在场边看别人练习', '观看练习'),
        ('自己上去飞两圈', '练习飞行'),
        ('把空看台巡视一遍', '巡查看台'),
        ('回城堡去', '返回城堡'),
      ],
    };

    final options =
        locationChoices[location] ??
        [
          ('继续前进', '继续探索'),
          ('仔细观察', '观察周围'),
          ('与人交谈', '和周围的人交流'),
          ('找个地方歇脚', '休息片刻'),
          ('回忆一下刚才发生的事', '整理思路'),
          ('返回原地', '回到之前的位置'),
        ];

    // 【为什么是跨步取而不是取连续三条】原来是 `idx, idx+1, idx+2`。
    // 池长 8 时，连续取意味着第 0 回合出 {0,1,2}、第 1 回合出 {1,2,3}……
    // 相邻两回合有三条里两条重复，玩家看到的是"选项几乎没变"。
    // 改成按 `len/3` 跨步之后，八条池子三回合就能全部见过面。
    final n = options.length;
    // 【为什么也用 _fallbackFrameSeq 而不是 turnCount】理由与叙事帧一致：
    // turnCount 每次开新书都归零，玩家换部之后选项又从头开始轮——
    // 而选项的"新鲜感"恰恰是长局最需要的东西。
    final idx = _fallbackFrameSeq % n;
    final stepSize = (n / 3).floor().clamp(1, n);
    final picks = <int>[];
    for (var k = 0; k < 3; k++) {
      final i = (idx + k * stepSize) % n;
      if (!picks.contains(i)) picks.add(i);
    }
    // 兜底：池子太小时（长度 3 以下）上面的去重会不足 3 条，补满。
    for (var i = 0; picks.length < 3 && i < n; i++) {
      if (!picks.contains(i)) picks.add(i);
    }

    return picks
        .map((i) => GameChoice(text: options[i].$1, action: options[i].$2))
        .toList();
  }

  /// 从AI原始响应文本中智能提取选项（用于解析失败后的兜底提取）

  /// 清理选项文本中的 markdown 图片/链接/HTML 标签/Emoji/乱码
  /// 防止 AI 返回形如 `A. ![图](url) 仔细查看` 导致选项显示异常
  /// 采用两遍扫描确保彻底清除嵌套格式

  /// 验证选项文本质量：sanitize后不应包含残余markdown/图片/异常格式
  /// 返回 true 表示质量合格，false 表示需要重试
  /// BUG-L 修复：方括号检查过于严苛 → "前往[图书馆]"或"[低声]询问"被判废 →
  ///   4条里1条废就触发重试 → 极简prompt覆盖好结果。现在只拒绝markdown链接/图片语法。

  /// 最终兜底选项：当AI连续失败时，基于当前剧情生成4个合理选项
  /// 兜底选项（严格基于「剧情末尾800字」生成，不能输出"仔细观察/面对情况"这种会断链的空选项）
  ///
  /// 触发时机：选项 AI 生成超时(45s，与 ai_router.dart 配置一致) / 返回内容不合格 / 网络异常。
  /// 核心原则：从「剧情最末尾的最后一位说话者 / 最后一个未完成动作 / 最后一个氛围钩子」出发，
  ///          产出 A(勇敢/主动) B(谨慎/观察) C(人际/沟通) D(取巧/隐忍) 四个风格，
  ///          玩家点任何一个都会让剧情**自然衔接**，不会出现"选了仔细查看 → 下回合叙事完全跳场景"的断链。
  ///
  /// 【原著事件感知】若本回合刚注入过原著节点（见 [hasFreshCanonEvent] /
  /// [canonTopicFromTitle]，两者实现在 GameNarrativeMixin），A/B/C/D 四档
  /// 各自会多出一个「围绕该事件」的分支，让玩家能对时代背景做出反应，
  /// 而不是只读到一行旁白、选项仍是「四处看看」。
  @override
  List<GameChoice> buildFallbackChoices(String narrative) {
    final p = player;
    final energy = p?.energy ?? 100;
    final location = worldState.currentLocation ?? '';

    // ---- 原著事件感知：本回合刚发生的节点，优先级最低但有真实针对性 ----
    //
    // 为什么放在末尾用 else if 而不是插在前面：A/B/C/D 四档的既有分支是按
    // 「场景钩子精确度」排过序的（hookDoor/hookLetter 等），而节点分支的
    // 判据只是「刚触发过事件」。让它插队会覆盖掉更精确的钩子，属于退化。
    // 追加在末尾则恰好补上原先必然落进 `else` 通用兜底的那一档。
    // 注意：加 `!` 是因为 `hasFreshCanonEvent` 这个 getter 本身无法为
    // 类型分析器提供 promotion——getter 结果不被缓存，编译器不敢假设
    // 两次调用（getter + `!`）之间值不变。
    // 注意：`canonTopicFromTitle` 是基类上的 **static** 成员，mixin 内必须
    // 写全 `GameProviderBase.` 前缀——裸写名字会走实例作用域解析，
    // static 成员不参与，直接报 `undefined_method`（本轮踩过的坑）。
    // 而 `hasFreshCanonEvent` 是实例 getter，可以裸用，但它无法为
    // 类型分析器提供 promotion，故 `!` 不可省。
    final canonTopic = hasFreshCanonEvent
        ? GameProviderBase.canonTopicFromTitle(lastCanonEventTitle!)
        : null;
    final atHome =
        location.contains('家中') ||
        location.contains('卧室') ||
        location.contains('客厅') ||
        location.contains('餐厅');
    final isNight =
        worldState.timestamp.contains('深夜') ||
        worldState.timestamp.contains('晚间') ||
        worldState.timestamp.contains('黄昏');
    final rawTail = narrative.length > 800
        ? narrative.substring(narrative.length - 800)
        : narrative;

    // ---- 原著节点块必须先从「对话/说话人」提取范围里剔除 ----
    //
    // 踩过的坑：节点 directive 是**给叙事的指令文本**，里面带描述性引号
    // （如「你决定不再只听二手传言」）。`reQuotedDialog` 会把这种引号
    // 当成"最后一句台词"，于是 `lastDialogTopic` 被污染成毫无意义的片段，
    // 进而 A/B/C/D 四档**全部**命中 `hookAnswer` 分支——
    // 表现为四个选项都在"回应某人的提问"，而原著事件选项永远轮不到。
    //
    // 节点块以 `📖 ` 开头的整段为界，只对**块之前的正文**做提取。
    // 这里用 lastIndexOf 取最后一块，保证只切掉本回合新注入的那一块。
    var tail = rawTail;
    final canonBlockAt = tail.lastIndexOf('\n📖 ');
    if (canonBlockAt >= 0) {
      tail = tail.substring(0, canonBlockAt);
    }

    // ---------- Step 1: 从末尾 800 字抓最后一位说话者 + 最后一句对话关键词 ----------
    String? lastSpeaker;
    String? lastDialogTopic;
    final aqm = reSpeakerAfterQuote.allMatches(tail);
    if (aqm.isNotEmpty) lastSpeaker = aqm.last.group(1);
    final dm = reQuotedDialog.allMatches(tail);
    if (dm.isNotEmpty) lastDialogTopic = dm.last.group(1);

    // ---------- Step 2: 抓末尾的未完成动作钩子（关键：位置门控，防止场景错位） ----------
    // 在家中/卧室/客厅/餐厅 才激活的居家专属钩子
    final hookPacking =
        atHome &&
        (tail.contains('收拾') || tail.contains('行李') || tail.contains('整理'));
    final hookDoor =
        atHome &&
        (tail.contains('敲门') || tail.contains('敲门声') || tail.contains('门外'));
    // 录取信钩子：只有在家中 + 明确出现「录取通知书」关键词才激活
    // （霍格沃茨到处都是羊皮纸/信封/霍格沃茨的，去掉这些误判词）
    final hookLetter = atHome && tail.contains('录取通知书');
    // 通用钩子不受位置限制
    final hookLeaving =
        tail.contains('早点休息') ||
        tail.contains('明天') ||
        tail.contains('出发') ||
        tail.contains('车票') ||
        tail.contains('站台');
    final hookGoodbye =
        tail.contains('圣诞节') ||
        tail.contains('答应我') ||
        tail.contains('一定要回来') ||
        tail.contains('告别') ||
        tail.contains('舍不得');
    final hookAnswer =
        tail.contains('等你回答') ||
        tail.contains('你的选择') ||
        tail.contains('打算怎么做') ||
        tail.contains('那你打算') ||
        (lastSpeaker != null && (lastDialogTopic?.contains('吗') ?? false));
    // 霍格沃茨场景专属钩子
    final atHogwarts =
        location.contains('霍格沃茨') ||
        location.contains('大礼堂') ||
        location.contains('走廊') ||
        location.contains('教室') ||
        location.contains('公共休息室') ||
        location.contains('特快');
    final hookClass =
        atHogwarts &&
        (tail.contains('上课') ||
            tail.contains('教授') ||
            tail.contains('课本') ||
            tail.contains('笔记') ||
            tail.contains('作业'));
    final hookGreatHall = atHogwarts && location.contains('大礼堂');
    final hogwartsLastNPC =
        lastSpeaker ??
        (tail.contains('麦格')
            ? '麦格教授'
            : tail.contains('邓布利多')
            ? '邓布利多校长'
            : tail.contains('斯内普')
            ? '斯内普教授'
            : tail.contains('海格')
            ? '海格'
            : tail.contains('哈利')
            ? '哈利'
            : tail.contains('罗恩')
            ? '罗恩'
            : tail.contains('赫敏')
            ? '赫敏'
            : null);

    final fallback = <GameChoice>[];

    // ---- A 勇敢/主动出击型（推进按钮会优先选这档！）----
    if (hookGoodbye && atHome) {
      fallback.add(
        GameChoice(
          text: '和养父母认真告别后收拾行李，明天一早前往国王十字车站',
          action: '和养父母认真拥抱告别，随即开始收拾行李，确认车票、魔杖和加隆都已入箱，准备明天前往国王十字车站的九又四分之三站台',
        ),
      );
    } else if (canonTopic != null) {
      // 原著事件感知：**必须排在 hookAnswer 之前**。
      //
      // 为什么：`hookAnswer` 的判据里含 `tail.contains('你的选择')`，而离线
      // 兜底叙事的固定句正是「你的选择，会把它推向不同的方向。」——于是
      // 离线路径下 hookAnswer **恒为真**，会把所有更具体的分支全部压掉。
      // 这一条是测试实测出来的（选项四连全是"回应提问"），不是推测。
      // 但仍让它位于 hookGoodbye/hookDoor/hookLetter 之后：那三个是绑定
      // 具体位置与物件的精确钩子（门、录取信、告别），精确度高于
      // 「本月触发过事件」这种时间性判据。
      fallback.add(
        GameChoice(
          text: '主动找消息灵通的同学打听「$canonTopic」的来龙去脉',
          action:
              '这件事已经传遍了周围，你决定不再只听二手传言：主动去找消息最灵通的同学或高年级学长问清楚「$canonTopic」到底是怎么回事，把时间、地点、涉及的人一一问明白，再判断它会怎么波及到你',
        ),
      );
    } else if (hookAnswer) {
      fallback.add(
        GameChoice(
          text: '正面回应「${lastSpeaker ?? '对方'}」的问题，说出你的真实想法',
          action:
              '直面${lastSpeaker ?? '对方'}的提问，坦诚回答你对${lastDialogTopic ?? '这件事'}的真实想法和接下来的打算',
        ),
      );
    } else if ((hookPacking || hookLeaving) && atHome) {
      fallback.add(
        GameChoice(
          text: '立刻收拾行李，和家人道晚安后为明天出发做最后确认',
          action:
              '立刻动手收拾行李，把魔杖匣、课本和换洗衣物装好，去和养父母道晚安，最后确认一遍车票与加隆，准备明天一早前往九又四分之三站台',
        ),
      );
    } else if (hookDoor) {
      fallback.add(
        GameChoice(
          text: '立刻过去开门，看看门外究竟是谁',
          action: '深吸一口气，快步走向大门，握住门把手直接打开看看门外到底是谁',
        ),
      );
    } else if (hookLetter) {
      fallback.add(
        GameChoice(
          text: '当着养父母的面拆开录取通知书并仔细阅读全文',
          action: '当着养父母的面撕开火漆，把霍格沃茨录取通知书从头到尾读完，确认开学日期、采购清单和九又四分之三站台说明',
        ),
      );
    } else if (hookGreatHall) {
      // 霍格沃茨大礼堂专属A选项：分院刚结束/晚宴进行中
      fallback.add(
        GameChoice(
          text: '主动转向身边的${hogwartsLastNPC ?? '新同学'}打招呼并自我介绍，拉近距离融入新集体',
          action:
              '大方转向身边的${hogwartsLastNPC ?? '新同学'}，露出友好笑容做自我介绍，顺势聊起对分院结果和学院的初印象，主动融入新环境',
        ),
      );
    } else if (hookClass) {
      fallback.add(
        GameChoice(
          text: '鼓起勇气举手回答教授的提问，展现你对魔咒学/当前课堂内容的理解',
          action: '深吸一口气，鼓起勇气举手回答教授的提问，把自己平时从书本和天赋里积累的理解有条理地说出来，争取给教授留下正面印象',
        ),
      );
    } else if (atHogwarts && hookLeaving) {
      // 霍格沃茨场景下的推进/出发动作
      fallback.add(
        GameChoice(
          text: '起身准备前往下一地点：拿起书包确认课程表，大步朝目标方向走去',
          action: '动作利落地把课本和笔记收进书包，确认一遍下一节课的教室和时间，迈开步伐朝目的地走去，不在原地浪费时间',
        ),
      );
    } else if (energy < 25) {
      fallback.add(
        GameChoice(
          text: '先抓紧休息恢复精神体力',
          action: '不再逞强，找个安全的地方坐下或躺下休息，先把精力恢复到可行动水平再做下一步',
        ),
      );
    } else if (atHogwarts && isNight) {
      fallback.add(
        GameChoice(
          text: '起身点亮魔杖，沿着走廊主动探索午夜城堡的秘密',
          action:
              '不再犹豫，点亮魔杖起身沿着月光下的走廊前进，主动探索城堡在午夜的秘密——被费尔奇抓到风险大，但往往能发现白天看不到的东西',
        ),
      );
    } else if (energy < 30) {
      fallback.add(
        GameChoice(
          text: '先抓紧时间恢复体力，再考虑下一步行动',
          action: '感觉身体已经快到极限了，不再硬撑，找个安全的地方坐下或靠墙闭目养神，先把体力和精力恢复到能正常行动的水平再考虑下一步',
        ),
      );
    } else if (canonTopic != null) {
      // 原著事件感知（主动型）：事件发生在周围，玩家能做的是**追信息**，
      // 而不是冲进去当主角——后者会破坏「平行世界，玩家是原创角色」的前提。
      fallback.add(
        GameChoice(
          text: '主动找消息灵通的同学打听「$canonTopic」的来龙去脉',
          action:
              '这件事已经传遍了周围，你决定不再只听二手传言：主动去找消息最灵通的同学或高年级学长问清楚「$canonTopic」到底是怎么回事，把时间、地点、涉及的人一一问明白，再判断它会怎么波及到你',
        ),
      );
    } else {
      // 默认 A 选项：基于当前场景生成不同风格的主动型选项，避免多回合相同
      final defaultA = turnCount % 3 == 0
          ? GameChoice(
              text: '主动面对眼前状况并迈出第一步',
              action: '不再犹豫，鼓起勇气直接面对当前的局面，立刻着手处理最紧急的那件事',
            )
          : turnCount % 3 == 1
          ? GameChoice(
              text: '打起精神，大步向前迎接接下来的挑战',
              action: '深吸一口气振作精神，迈开大步向前走，用积极的态度迎接即将到来的每一件事',
            )
          : GameChoice(
              text: '果断行动，不让犹豫耽误当前良机',
              action: '直觉告诉自己不能再等了，果断采取行动抓住当下的时机，在悔意追上之前把事情推进下去',
            );
      fallback.add(defaultA);
    }

    // ---- B 谨慎/智取/观察型 ----
    if (canonTopic != null) {
      // 原著事件感知（谨慎型）：与 A 档形成风格对照——同样是关注事件，
      // A 是主动打听，B 是安静收集。玩家点哪个都不会跳场景，
      // 因为两者的动作都发生在「此刻所在的这个地方」。
      //
      // 【为什么四档都必须排在 hookAnswer 之前】
      // `hookAnswer` 的判据含 `tail.contains('你的选择')`，而离线兜底叙事
      // 里有一句固定文案「你的选择，会把它推向不同的方向。」——因此在
      // **整个离线路径下 hookAnswer 恒为真**。任何排在它后面的分支都是
      // 死代码。这不是风格取舍，是不这么排就永远不生效。
      fallback.add(
        GameChoice(
          text: '表面不介入，安静留意周围关于「$canonTopic」的所有消息',
          action:
              '你不打算主动卷进这件事，但也不想一无所知：维持平日的作息与课业节奏，一边留意公告栏、走廊议论和教授们的神情，把关于「$canonTopic」的零碎消息拼成完整脉络，等分清利害再决定要不要介入',
        ),
      );
    } else if (hookAnswer) {
      fallback.add(
        GameChoice(
          text: '不急于回答，先反问「${lastSpeaker ?? '对方'}」几个关键细节再决定',
          action:
              '先不动声色地反问${lastSpeaker ?? '对方'}两个关于${lastDialogTopic ?? '这件事'}的具体细节，确认信息完全后再做出稳妥的回应',
        ),
      );
    } else if (hookPacking && atHome) {
      fallback.add(
        GameChoice(
          text: '先列一张行李清单检查不落下必需品，再慢慢收拾',
          action: '拿羊皮纸列出开学必需品清单：魔杖、课本、袍子、加隆、私人物品，逐一核对后再动手收拾，确保不落下关键物件',
        ),
      );
    } else if (hookDoor) {
      fallback.add(
        GameChoice(
          text: '先从门缝/猫眼确认来人，再决定开门与否',
          action: '先不急着开门，从门缝或猫眼确认一下门外的人是谁、带什么东西，确认安全后再决定是否开门',
        ),
      );
    } else if (hookLetter) {
      fallback.add(
        GameChoice(
          text: '先收好信不声张，观察养父母的反应再决定下一步',
          action: '不动声色地把录取信先收进怀里，先观察养父母的表情和态度，揣摩他们知道多少内情再决定怎么谈',
        ),
      );
    } else if (hookGreatHall) {
      fallback.add(
        GameChoice(
          text: '先安静用餐，观察各个学院桌的氛围和同学的气质再决定社交节奏',
          action:
              '不急于社交，先拿起刀叉安静享用晚宴，同时暗中观察四个学院长桌的氛围、同学的气质和教授们的神态，把局势看清楚再决定怎么社交',
        ),
      );
    } else if (atHogwarts) {
      fallback.add(
        GameChoice(
          text: '先找个安静角落把课程表和学院地图理清楚，规划好今日行程',
          action: '先避开人流，找一个走廊的安静角落，把课程表、学院公共休息室位置和今天要做的事情逐一列清楚，避免走错教室或遗漏重要事项',
        ),
      );
    } else if (canonTopic != null) {
      // 原著事件感知（谨慎型）：与 A 档形成风格对照——同样是关注事件，
      // A 是主动打听，B 是安静收集。玩家点哪个都不会跳场景，
      // 因为两者的动作都发生在「此刻所在的这个地方」。
      fallback.add(
        GameChoice(
          text: '表面不介入，安静留意周围关于「$canonTopic」的所有消息',
          action:
              '你不打算主动卷进这件事，但也不想一无所知：维持平日的作息与课业节奏，一边留意公告栏、走廊议论和教授们的神情，把关于「$canonTopic」的零碎消息拼成完整脉络，等分清利害再决定要不要介入',
        ),
      );
    } else {
      // 默认 B 选项：基于回合数和场景变化
      final defaultB = turnCount % 3 == 0
          ? GameChoice(
              text: '先沉默观察几秒钟，理清所有信息再行动',
              action: '先不要急着做决定，安静观察周围的人和环境，把已知信息理一遍再选最稳妥的行动',
            )
          : turnCount % 3 == 1
          ? GameChoice(
              text: '停在原地静观其变，等局势明朗再做判断',
              action: '不急于踏出下一步，先停在原地感受周围氛围的变化，等关键信息浮现或局势明朗之后再做出冷静的判断',
            )
          : GameChoice(
              text: '先绕着周围走一圈，摸清地形和人员分布再决定',
              action: '不急于行动，先不动声色地绕着周围走一圈，把地形、出入口、周围人员分布都摸清楚，掌握全局信息再制定计划',
            );
      fallback.add(defaultB);
    }

    // ---- C 人际/沟通/结盟型 ----
    if (canonTopic != null) {
      // 原著事件感知（人际型）：原著大事往往也是人际场上的话题。
      // 让玩家借事件去攀谈，是把「时代背景」变成「社交资源」的最自然方式。
      //
      // 位置：提到 `lastSpeaker != null` 之前。那一分支在离线路径下同样
      // 恒为真（`reQuotedDialog` 会把 NPC 台词抓成 lastSpeaker），
      // 排它后面同样是死代码。
      fallback.add(
        GameChoice(
          text: '借着「$canonTopic」这个话题，和身边的同学交换各自听来的版本',
          action:
              '你意识到这件事正是个自然的搭话由头：主动和身边的同学、室友交换各自听来的关于「$canonTopic」的版本，比对谁的消息更接近实情，顺便看清哪些同学和你在同一立场，把关系建立起来',
        ),
      );
    } else if (lastSpeaker != null) {
      fallback.add(
        GameChoice(
          text: '和「$lastSpeaker」坐下来好好聊清楚${lastDialogTopic ?? '接下来的打算'}再决定',
          action:
              '拉着$lastSpeaker坐下来，把关于${lastDialogTopic ?? '接下来的安排'}的顾虑、担忧、期望都聊清楚，先把双方理解对齐再行动',
        ),
      );
    } else if ((hookGoodbye || hookLeaving) && atHome) {
      fallback.add(
        GameChoice(
          text: '坐下来和养父母吃最后一顿晚饭，聊聊对魔法界的担忧与期待',
          action: '先不急着收拾，坐到餐桌边陪养父母再吃一顿饭（哪怕是凉的），把彼此对魔法界的担忧和期待都说出来，给家人一个安心的告别',
        ),
      );
    } else if (atHome) {
      fallback.add(
        GameChoice(
          text: '去找养父母或家人聊聊，确认他们的看法和建议',
          action: '去找养父母或家里最信任的亲人聊一聊，问他们对这件事的真实想法和建议，再决定下一步怎么走',
        ),
      );
    } else if (hookGreatHall) {
      fallback.add(
        GameChoice(
          text: '向邻座伸出手自我介绍，主动结识同院的第一位朋友',
          action:
              '面带微笑转向身边最近的同院同学，礼貌地伸出手做自我介绍，顺势询问对方的名字、出身和对学院的看法，争取在学院里找到第一位朋友',
        ),
      );
    } else if (atHogwarts) {
      fallback.add(
        GameChoice(
          text: '找路过的${hogwartsLastNPC ?? '学长'}或同学确认下节课的教室方向和注意事项',
          action:
              '拦住一位看起来面善的路过的${hogwartsLastNPC ?? '高年级学长'}或同学，礼貌询问下一节课的教室位置、教授的上课风格和注意事项，确保自己不迟到踩雷',
        ),
      );
    } else {
      // 默认 C 选项：基于回合数和场景变化
      final defaultC = turnCount % 3 == 0
          ? GameChoice(
              text: '找附近熟悉的NPC了解情况再做判断',
              action: '先和周围看起来面善或认识的NPC聊两句，确认一下当前事态、别人都在做什么，避免自己信息不足做错决定',
            )
          : turnCount % 3 == 1
          ? GameChoice(
              text: '环顾四周寻找可信任的人，主动搭话建立联系',
              action: '目光扫过周围的人，找一个看起来靠谱或眼熟的面孔主动搭话，先建立初步联系再了解当前处境',
            )
          : GameChoice(
              text: '写好一封短信让猫头鹰送给信任的朋友，寻求建议',
              action: '拿出羊皮纸快速写一封短信，简单说明当前处境和困惑，让猫头鹰送给最信任的朋友，等对方回信获得建议后再行动',
            );
      fallback.add(defaultC);
    }

    // ---- D 取巧/隐忍/代价型 ----
    if (canonTopic != null) {
      // 原著事件感知（隐忍型）：原著里的大事往往伴随管控与清算。
      // 这一档给玩家「规避风险」的合理选择——不表态、不留痕迹、
      // 先保护自己不受波及，符合平行世界原创角色的生存逻辑。
      //
      // 位置：提到 hookAnswer 之前，理由同 A/B/C 三档（离线路径下
      // hookAnswer 恒真，排它后面即死代码）。
      fallback.add(
        GameChoice(
          text: '对「$canonTopic」不作任何公开表态，先把自己从风口浪尖上摘干净',
          action:
              '你敏锐地察觉到「$canonTopic」这桩事正在让周围的人变得敏感：于是刻意不作公开表态，避开议论扎堆的地方，也不在书面上留下立场痕迹，先确保自己不会被卷进任何一方的清算里',
        ),
      );
    } else if ((hookPacking || hookLeaving) && atHome) {
      fallback.add(
        GameChoice(
          text: '先把最重要的魔杖和车票揣进内袋，其余物品明天清早再收拾',
          action: '不做全面打包，只把魔杖匣子、车票和大面额加隆贴身收好，其余衣物课本留到明天清晨再装，先睡一觉保证明天出发时精神饱满',
        ),
      );
    } else if (hookAnswer) {
      fallback.add(
        GameChoice(
          text: '对「${lastSpeaker ?? '对方'}」的问题先模糊应付，保留信息差不亮底牌',
          action:
              '面对${lastSpeaker ?? '对方'}关于${lastDialogTopic ?? '这件事'}的提问，先模糊点头/打哈哈应付过去，不把自己真实想法和底牌亮出来，给自己留后路',
        ),
      );
    } else if (hookDoor) {
      fallback.add(
        GameChoice(
          text: '假装不在房间/没听见，先躲在一边观察外面动静再决定',
          action: '先假装屋里没人、不去开门，悄悄躲在门后或窗边听外面的脚步声/说话声，确认安全情况再做进一步打算',
        ),
      );
    } else if (atHome && isNight) {
      fallback.add(
        GameChoice(
          text: '借口很累先去睡，明早趁家人不注意偷偷出发',
          action: '借口精神不济先回房间休息，悄悄把最重要的行李整理好，第二天清早趁家人还没睡醒就拿着车票和加隆悄然出发',
        ),
      );
    } else if (hookGreatHall) {
      fallback.add(
        GameChoice(
          text: '低调坐在长桌角落默默吃饭，不主动社交但暗中观察所有人的互动',
          action:
              '端着餐盘悄悄挪到拉文克劳长桌最不起眼的角落坐下，安静吃饭不主动搭话，但暗中观察教授们、级长们和同学们之间的互动，默默收集情报',
        ),
      );
    } else if (atHogwarts) {
      fallback.add(
        GameChoice(
          text: '拿出提前准备好的笔记，把今天观察到的关键信息快速记下来建立情报优势',
          action:
              '掏出随身的羊皮纸小本和羽毛笔，把今天观察到的教授特点、同学性格、重要地点位置快速整理记录，建立属于自己的情报笔记方便日后利用',
        ),
      );
    } else if (canonTopic != null) {
      // 原著事件感知（隐忍型）：原著里的大事往往伴随管控与清算。
      // 这一档给玩家「规避风险」的合理选择——不表态、不留痕迹、
      // 先保护自己不受波及，符合平行世界原创角色的生存逻辑。
      fallback.add(
        GameChoice(
          text: '对「$canonTopic」不作任何公开表态，先把自己从风口浪尖上摘干净',
          action:
              '你敏锐地察觉到「$canonTopic」这桩事正在让周围的人变得敏感：于是刻意不作公开表态，避开议论扎堆的地方，也不在书面上留下立场痕迹，先确保自己不会被卷进任何一方的清算里',
        ),
      );
    } else {
      // 默认 D 选项：基于回合数和场景变化
      final defaultD = turnCount % 3 == 0
          ? GameChoice(
              text: '暂时隐忍不表态，等时机更成熟再出手',
              action: '把情绪压下去，不急于表明立场也不急于行动，先观察局势变化，等对自己最有利的时机出现再出手',
            )
          : turnCount % 3 == 1
          ? GameChoice(
              text: '退到边缘地带观察全局，不抢着出头但随时准备行动',
              action: '安静退到人群或场景的边缘，让主角光环落在别人身上，自己默默观察整个局面的走向，等需要你的时候再果断出手',
            )
          : GameChoice(
              text: '绕到对手侧后方，寻找可利用的机会出其不意',
              action: '不正面硬拼，悄悄绕到侧后方观察对手暴露的弱点，寻找对方意想不到的机会，出其不意掌握主动权',
            );
      fallback.add(defaultD);
    }

    // ---- P7 玩法入口注入（追加在承接式选项之后）----
    // 承接式四档保证剧情不断链；玩法入口是**可选的平行出口**，只在
    // 该玩法此刻确实可玩时出现（门控见 buildGameplayOptions），玩家
    // 主动选中才会触发完整玩法系统（自动推进按钮会跳过它们）。
    final gameplayEntries = buildGameplayOptions();
    if (gameplayEntries.isNotEmpty) {
      fallback.addAll(gameplayEntries);
    }

    // 保险：裁剪到 6 条（4 条承接式 + 至多 2 条玩法入口）、补齐至少 4 条
    if (fallback.length > 6) fallback.removeRange(6, fallback.length);
    if (fallback.length < 4) {
      fallback.add(
        GameChoice(
          text: '先在脑中过一遍所有后果，再选择最稳妥的做法',
          action: '把接下来可选动作的各种后果在脑子里快速过一遍，评估风险后再选最稳妥的那一步',
        ),
      );
    }
    while (fallback.length < 4) {
      fallback.add(
        GameChoice(
          text: '冷静下来整理思路后再决定下一步',
          action: '先深呼吸让情绪平稳下来，把已知的事实、未知的风险、自己的目标整理清楚，再继续下一步',
        ),
      );
    }
    return fallback;
  }

  /// P7 玩法入口选项：把当前**确实可玩**的完整玩法系统暴露为选项。
  ///
  /// 【为什么放在承接式四档之后】A/B/C/D 四档严格承接剧情末尾，保证剧情
  /// 不断链；玩法入口是玩家**主动选择的平行出口**——选它才会触发
  /// （魁地奇/决斗/禁林/宠物），自动推进按钮会跳过它们（见
  /// [pickAutoAdvanceChoice] 的 `@@gameplay:` 过滤）。
  ///
  /// 【上下文门控】只在玩法此刻真的能玩时才出现：有扫帚且本周未赛才给
  /// 魁地奇；精力/次数达标才给决斗与禁林；有宠物且今日未互动才给宠物。
  /// 门控与玩法函数内部的拒绝文案判据保持一致，避免把玩家指向一条
  /// 「点了之后只有拒绝提示」的死路。最多 2 条，保持选项面板清爽。
  List<GameChoice> buildGameplayOptions() {
    final p = player;
    if (p == null) return const [];
    final out = <GameChoice>[];
    final energy = p.energy;
    final atHogwarts = _locationIsHogwarts(worldState.currentLocation ?? '');

    // 1) 魁地奇训练赛：在城堡 + 有扫帚 + 精力足 + 本周未赛。
    if (atHogwarts &&
        (p.equipped['broom'] != null) &&
        energy >= 20 &&
        p.qLastWeek != gameWeek) {
      out.add(const GameChoice(
        text: '去魁地奇球场参加训练赛，为学院争取胜利',
        action: '${kGameplayActionPrefix}quidditch',
      ));
    }

    // 2) 决斗：在城堡 + 精力足 + 今日次数未满。
    if (atHogwarts && energy >= 15 && canDoDaily('duel')) {
      out.add(const GameChoice(
        text: '到决斗场地找一位同学切磋一场巫师决斗',
        action: '${kGameplayActionPrefix}duel',
      ));
    }

    // 3) 禁林探险：在城堡 + 精力足 + 饱食度足 + 今日次数未满。
    if (atHogwarts &&
        energy >= 25 &&
        p.satiety >= 20 &&
        canDoDaily('forest')) {
      out.add(const GameChoice(
        text: '去禁林边缘探险，采集魔法材料',
        action: '${kGameplayActionPrefix}forest',
      ));
    }

    // 4) 宠物互动：有宠物 + 今日还未玩耍/训练。
    final petName = (p.petName?.isNotEmpty ?? false) ? p.petName! : null;
    if (petName != null && p.petInteractDay != worldState.time.absoluteDayIndex) {
      out.add(GameChoice(
        text: '陪$petName玩耍互动，增进羁绊',
        action: '${kGameplayActionPrefix}pet_play',
      ));
    }

    // 最多两条：与上方上限 6（4 承接 + 2 玩法）对齐。
    if (out.length > 2) out.removeRange(2, out.length);
    return out;
  }

  /// 判断地点是否在霍格沃茨城堡内部（玩法入口门控用，口径与承接式
  /// 选项的 `atHogwarts` 保持一致）。
  bool _locationIsHogwarts(String location) =>
      location.contains('霍格沃茨') ||
      location.contains('大礼堂') ||
      location.contains('走廊') ||
      location.contains('教室') ||
      location.contains('公共休息室') ||
      location.contains('特快');

  /// 【推进按钮智能选策略】——替代原先的 choices.first，防止剧情回滚
  /// 选择优先级：
  ///  1) 先过滤掉与当前地点/时间完全错位的选项（如在霍格沃茨就去掉「拆录取通知书」「找养父母」）
  ///  2) 在剩余选项里，优先选含「推进型关键词」的选项（出发/动身/前往/告别/收拾/起程/离开/走下楼梯/走出房间）
  ///  3) 如果仍有多个候选，优先选 index 为 0 的 A 档（勇敢主动型）
  ///  4) 最后兜底：choices.first
  GameChoice pickAutoAdvanceChoice() {
    if (choices.isEmpty) {
      return GameChoice(
        text: '主动面对眼前状况',
        action: '不再犹豫，鼓起勇气直接面对当前局面，立刻处理最紧急的那件事',
      );
    }
    final loc = (worldState.currentLocation ?? '').toLowerCase();
    final atHome =
        loc.contains('家中') ||
        loc.contains('卧室') ||
        loc.contains('客厅') ||
        loc.contains('餐厅');
    final atHogwarts =
        loc.contains('霍格沃茨') ||
        loc.contains('大礼堂') ||
        loc.contains('走廊') ||
        loc.contains('教室') ||
        loc.contains('公共休息室') ||
        loc.contains('特快') ||
        loc.contains('对角巷') ||
        loc.contains('站台');

    // 居家错位关键词：在霍格沃茨/对角巷/特快 场景下，选项里出现这些词视为错位
    final homeMisplacedKeywords = const <String>[
      '养父母',
      '录取通知书',
      '撕开火漆',
      '九又四分之三站台',
      '德思礼',
      '弗农姨父',
      '佩妮姨妈',
      '麻瓜郊区',
      '家中的客厅',
      '家里的卧室',
      '回家睡',
      '回家休息',
    ];
    // 霍格沃茨错位关键词：在家中场景，选项出现这些词视为错位
    final hogwartsMisplacedKeywords = const <String>[
      '大礼堂',
      '分院',
      '教授',
      '学院长桌',
      '级长',
      '公共休息室',
      '走廊',
      '城堡',
      '禁林',
      '魁地奇',
      '教室',
      '同学自我介绍',
      '同院',
      '霍格沃茨特快',
    ];

    // Step 1: 过滤错位选项
    var candidates = List<GameChoice>.from(choices);
    candidates.retainWhere((c) {
      final text = c.text + c.action;
      if (atHogwarts) {
        // 非居家场景：去掉居家专属词
        for (final kw in homeMisplacedKeywords) {
          if (text.contains(kw)) return false;
        }
      }
      if (atHome) {
        // 居家场景：去掉霍格沃茨专属词
        for (final kw in hogwartsMisplacedKeywords) {
          if (text.contains(kw)) return false;
        }
      }
      return true;
    });
    if (candidates.isEmpty) candidates = List<GameChoice>.from(choices);

    // P7：玩法入口选项（action 带 `@@gameplay:` 标记）是玩家主动选择的
    // 玩法出口，不应被「推进」按钮顺手带走——自动推进只承接剧情。
    // 过滤后再兜底，兜底结果也绝不允许落回玩法入口（面板可能全是玩法选项）。
    candidates.retainWhere((c) => !c.action.startsWith(kGameplayActionPrefix));
    if (candidates.isEmpty) {
      candidates = List<GameChoice>.from(choices)
        ..retainWhere((c) => !c.action.startsWith(kGameplayActionPrefix));
    }
    if (candidates.isEmpty) {
      candidates = [
        GameChoice(
          text: '主动面对眼前状况',
          action: '不再犹豫，鼓起勇气直接面对当前局面，立刻处理最紧急的那件事',
        ),
      ];
    }

    // Step 2: 推进型关键词加分（优先排序）
    candidates.sort((a, b) => score(b).compareTo(score(a)));

    // Step 3: 同分/都为0分时，优先原列表更靠前的（A > B > C > D）
    final topScore = score(candidates.first);
    final topPool = candidates.where((c) => score(c) == topScore).toList();
    if (topPool.length <= 1) return topPool.first;
    // 在最高分池中找原 choices 里 index 最小的
    GameChoice? best;
    for (final c in choices) {
      if (topPool.any((x) => x.action == c.action && x.text == c.text)) {
        best = c;
        break;
      }
    }
    return best ?? candidates.first;
  }

  /// 「推进」按钮入口：调用 pickAutoAdvanceChoice() 后再 processChoice
  Future<void> processAutoAdvanceChoice() async {
    final choice = pickAutoAdvanceChoice();
    // 推进按钮选中日志已移除
    return processChoice(choice);
  }
}
