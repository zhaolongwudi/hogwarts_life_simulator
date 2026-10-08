import '../models/story_progress.dart';
import '../providers/game_provider_base.dart';

/// 剧情叙事三层拼装族（第十一轮 r11-4 拆分自 mixin_story_engine.dart）。
///
/// 覆盖：composeStoryNarrative（情境+因果+世界氛围三层拼接）、
/// composeCausalText（由选择结果与知识库生成过渡句）、formatStoryDelta（数值变动提示）。
mixin GameStoryComposeMixin on GameProviderBase {
  /// 深夜专属事件池（熄灯后的霍格沃茨氛围）。
  static const List<String> _nightEventLines = [
    '窗外月光洒在走廊的地板上，墙上的画像正闭眼休息，只有你的脚步声在回荡。',
    '远处传来城堡大钟低沉又悠远的报时，惊起了一只在窗棂上打盹的猫头鹰。',
    '守夜的老门卫提着马灯从走廊尽头走过，灯光在地板上拉出一条长长的影子。',
    '几盏蜡烛在半空无声地漂浮着，像一个没人注意的幽灵缓缓飘过走廊。',
    '图书馆的方向还亮着一盏微弱的灯，不知是谁还在一排排书架间流连。',
    '窗外的禁林里隐约传来某种低沉的嗡鸣，转瞬又归于寂静蹊跷。',
    '走廊尽头的盔甲忽然像活了一样，发出一声很轻的金属摩擦声。',
    '公共休息室的壁炉火苗已经压得很低，沙发旁还摊着一本没合上的《预言家日报》。',
    '头顶传来一阵窸窣，大概是淘气的皮皮鬼，你决定假装没听见。',
    '潮湿的晚风从某扇没关严的窗缝溜进来，烛火跟着晃了晃。',
  ];
  /// 常见地点各自的专属事件池——按地点名精确或子串匹配。
  static const Map<String, List<String>> _locationEventLines = {
    '礼堂': [
      '四张长桌旁的家养小精灵正在无声地收拾残羹，动作熟练得像影子。',
      '天花板外的夜空露出几颗星，食物被施了保暖咒仍冒着热气。',
      '一位教授正对着空无一人的餐桌低声念着什么咒语，像是在加固防尘屏障。',
      '格兰芬多的长桌上有人围成一圈低声讨论着什么，忽而又散开了。',
      '邓布利多的座椅背后，一只家养小精灵已经在打瞌睡，头一点一点。',
    ],
    '图书馆': [
      '平斯夫人推着满载的书车经过，对你投来一个「安静看书」的提醒眼神。',
      '几本书在书架上轻微颤动，像是有人刚刚触碰过它们又移开了手。',
      '角落的禁书区被链子拴着的书发出低低的翻页声，却不见有手翻动。',
      '一本《魔法史》被翻开又合上，页边空白处写满细密的铅笔批注。',
      '靠窗的座位还留着上一节课主动留下来的几根羽毛笔和一小叠羊皮纸。',
    ],
    '禁林': [
      '树影间一双发亮的眼睛一闪而过，你定神再看时已经没了踪影。',
      '地面传来一阵细碎的沙沙声，像是有什么小东西正沿着灌木丛边缘快速挪动。',
      '某棵树干上刻着新鲜的爪痕，摩擦的毛边还没有被时间磨圆。',
      '一株会张合叶片的植物在脚边动了动，像在试探要不要咬你一口。',
      '远处传来马蹄声与一声低沉的嘶鸣，随即又被更深处的黑暗吞没。',
    ],
    '温室': [
      '一株曼德拉草幼苗在盆里轻轻扭动了一阵，随后又安静下来。',
      '暖房里的空气又湿又暖，某种从未见过的花朵正在悄然绽放。',
      '霍格沃茨的家养小精灵正小心地往一株食人藤的根部浇水，看见你后他迅速移开了视线。',
      '一排番茄也属的魔法植物结出会发光的果实，在暖光下轻轻晃动。',
      '石板缝隙里钻出几根会攀爬的藤蔓，正朝旁边一盆跳跳球茎悄悄伸去。',
    ],
    '塔楼': [
      '风从塔楼的窗缝里灌进来，吹得羽毛笔和羊皮纸在桌上轻轻挪动。',
      '楼下传来争论课表的声音，被塔楼的风吹得断断续续。',
      '一架望远镜正对着夜空，等待着一颗迟迟没有出现的流星。',
      '盘旋的楼梯尽头，某幅肖像画在你经过时偷偷睁开了半只眼睛。',
      '天文台上的星图被风吹动一角，上面的墨水还没完全干透。',
    ],
    '魔药教室': [
      '坩埚里残留的液体冒出几缕向上的烟，空气中还留着薄荷与苦草的气息。',
      '柜子里一排瓶瓶罐罐轻轻碰了一下，像是有人刚取走过一瓶又放回一瓶。',
      '黑板上的魔药配方还没擦去，末尾的几行字被打了个记号。',
      '一只烧杯里的液体一小会儿变一个颜色，隔着毛玻璃也看得很清楚。',
      '讲台上的教具蛇在地下静静蜷着，通体透着一股虎视眈眈的凉意。',
    ],
    '厨房': [
      '一排家养小精灵正排着队把刚出炉的馅饼往碗柜里码，热腾腾的香气扑鼻。',
      '某只家养小精灵朝你鞠了一躬，又忙不迭地回到灶台边翻炒着什么。',
      '橱柜顶放着的一罐蜂蜜突然抖了抖，大概是什么零食咒在下午茶时间发作。',
      '角落堆着一摞洗好的餐具，正自己一蹦一蹦地跳回各自的架子上。',
    ],
    '场地': [
      '远处的魁地奇球场空无一人，只有几面旗帜在风中猎猎作响。',
      '黑湖的水面泛着幽光，一阵波纹从岸边扩散开去，像有什么刚从水下经过。',
      '海格的南瓜地里，最大的那几颗南瓜正忙着抢占地盘，越挤越紧。',
      '草坪上散落着几把练习用的扫帚，一只咿呀飞行的雏鹰正绕着看台盘旋。',
    ],
    '宿舍': [
      '公共休息室的壁炉噼啪作响，几个同学窝在扶手椅里下巫师棋。',
      '床上叠着一件还没干的校袍，估计是谁刚施过烘干咒的成果。',
      '窗台上蹲着室友的猫头鹰，歪头用一只圆眼打量你翻找东西。',
      '桌上的棋局还停在原处，一枚棋子趁没人注意偷偷换了个位置。',
      // 室友系统人物句（设计文档 3.2：带 $roommate 占位，localEventLinesFor
      // 触发时若玩家在宿舍且存在室友 → 优先取人物句）
      '『再不起来要赶不上早餐了！』室友 \$roommate 一把掀开你的被子。',
      '熄灯后 \$roommate 翻了个身，压低声音问你最近是不是有心事。',
      '\$roommate 把课本摊在桌上，说『这段我猜必考』，拉着你一起背。',
      '\$roommate 摸出一袋滋滋蜜蜂糖，分了半袋给你。',
    ],
    '球场': [
      '扫帚架上的飞天扫帚排得整整齐齐，有几把还缠着练习用的毛线球。',
      '看台上有人落下一副护目镜，在阳光下闪闪发亮。',
      '更衣室的门半掩着，里面飘出几句关于战术的争论。',
    ],
    '黑湖': [
      '湖面平静得像一面深色的镜子，偶尔被某条跃出的鳍划开一道涟漪。',
      '岸边水草丛里，一只螃蟹用钳子夹着一片浮萍，慢吞吞地横着爬。',
      '水下的阴影比别处浓重，像有一双眼睛在湖水的光斑间注视着你。',
    ],
  };
  /// 通用事件池——覆盖没有专属池的地点，seed 驱动轮转避免长会话撞句。
  static const List<List<String>> _genericEventLines = [
    [
      '走廊里几个低年级学生抱着书本匆匆跑过，其中一本差点掉在地上。',
      '墙上的画像们正在争论魁地奇比赛的历史最佳找球手，声音越来越大。',
      '窗外传来猫头鹰扑打翅膀的声音，一封新信被扔进了窗台。',
    ],
    [
      '远处的教室传来一阵整齐的咒语吟唱声，听起来像是弗立维教授的魔咒课。',
      '拐角处皮皮鬼唱着怪调的歌飘过，又突然折返往另一个方向去了。',
      '一个胖乎乎的家养小精灵用布巾抹了一下额头，又消失在拐角。',
    ],
    [
      '走廊尽头挂着一幅正在打瞌睡的画像，鼾声里混着几句含糊的梦话。',
      '头顶的吊灯轻轻晃动了一下，像是有什么大东西刚从天花板上走过。',
      '一阵轻微的低语从墙后传来，仔细听又只剩下风声。',
    ],
    [
      '一只猫头鹰落在窗台上，歪着头观察了你片刻后才展翅离去。',
      '空地上散落的几根羽毛被风卷起，打了个旋又落回原处。',
      '远处传来几声被压抑的惊呼，很快又归于一片安静。',
    ],
    [
      '走廊的盔甲突然做好像动了动最外面的那只手，随后又纹丝不动。',
      '某个房间的门半掩着，里面透出昏黄的烛光，却听不见任何声音。',
      '你在墙角发现一枚被遗落的加隆，边缘在灯光下微微发亮。',
    ],
    [
      '墙上的藏书地图某处皱起一角，像被反复翻看过。',
      '有人的脚步声在你身后停了一下，你回头时走廊却空无一人。',
      '一阵冷风不知从哪个方向吹来，蜡烛的火苗齐齐偏向了同一个方向。',
    ],
    [
      '班上的幽灵正漂浮在天花板附近，对你说完「别太晚」后穿墙而去。',
      '远处的炊烟混着洋葱和烤面包的香气飘过来，勾起了你的食欲。',
      '窗边的挂毯上绣着的魔法生物，似乎在某个瞬间眨了眨眼睛。',
    ],
  ];
  static List<String> localEventLinesFor({
    required String location,
    required int hour,
    required int seed,
  }) {
    final isNight = hour < 6 || hour >= 21;
    if (isNight) return _nightEventLines;
    // 地点池精确匹配失败时退化为「子串双向匹配」：
    // currentLocation 存的是规范名（如「霍格沃茨·礼堂」），而池 key 是短名
    // （如「礼堂」）——只做 `_locationEventLines[location]` 精确查找的话，
    // 专属池几乎永远落空、全走通用池（P5 实地发现：离线玩法读到的几乎
    // 全是通用句，礼堂/图书馆/禁林全在 "某角落" 的句子里打转）。
    // 向后兼容：短名直查 / 长名包含短名 / 短名包含长名都能命中。
    final exact = _locationEventLines[location];
    if (exact != null) return exact;
    for (final entry in _locationEventLines.entries) {
      if (location.contains(entry.key) || entry.key.contains(location)) {
        return entry.value;
      }
    }
    return _genericEventLines[(seed ~/ 3) % _genericEventLines.length];
  }
  /// 带 $roommate 占位，由 localEventLinesFor 替换为实际室友名。
  static const List<String> _roommateSceneLines = [
    '室友 \$roommate 打了一整晚呼噜，你翻来覆去怎么也睡不着。',
    '\$roommate 偷藏的零食被舍监抓了包，你帮忙打圆场才蒙混过去。',
    '你赖床不起，\$roommate 顺手帮你带了份早餐回来。',
    '\$roommate 在课上给你传了张纸条，上面写着隔壁班的新八卦。',
    '\$roommate 怂恿你翘课去霍格莫德，被你严词拒绝后他嘟囔了半天。',
    '你的校袍袖口开了线，\$roommate 翻出针线包帮你补好了。',
    '\$roommate 一脸疲惫地回来，抱怨魁地奇训练实在太累了。',
    '\$roommate 问你周末要不要一起去对角巷逛逛。',
    '考试周凌晨你还在背书，\$roommate 默默递来一杯热牛奶，什么也没问。',
    '你的青蛙糖果滚到了床底下，\$roommate 趴在地上帮你够了出来，还搭进去一张蜘蛛网。',
    '放假前夜你和 \$roommate 躺在床上盘点这一学年各自最丢脸的瞬间，笑到宿管来敲门。',
    '你半夜说梦话被 \$roommate 听了个正着，第二天TA只神秘兮兮地说了句「秘密保住了」。',
    '你的猫头鹰把 \$roommate 的枕头当成了新窝，两人郑重其事地签了一份「枕头共用协议」。',
    '壁炉熄了，你和 \$roommate 挤在一条毯子里轮流讲鬼故事，结果谁都不敢先去睡觉。',
  ];
  /// 以免破坏既有静态调用测试（batch33_offline_ux_test）。
  List<String> localEventLinesWithRoommates({
    required String location,
    required int hour,
    required int seed,
  }) {
    final lines = localEventLinesFor(
      location: location,
      hour: hour,
      seed: seed,
    );
    if (!location.contains('宿舍')) return lines;
    final rms = roommates();
    if (rms.isEmpty) return lines;
    final roommateName = rms[seed % rms.length].name;
    if (_roommateSceneLines.isNotEmpty) {
      final scene = _roommateSceneLines[seed % _roommateSceneLines.length];
      return [scene.replaceAll('\$roommate', roommateName)];
    }
    return lines.map((l) => l.replaceAll('\$roommate', roommateName)).toList();
  }
/// 叙事三层拼装：
  ///   [层1 情境] 本步 setup（+ 过场文本）
  ///   [层2 因果] 由选择结果与知识库生成的过渡句
  ///   [层3 世界] 地点氛围池（复用沙盒的 `localEventLinesFor`）
  ///   末尾附上"你做了什么"（consequence）与数值变动的可读提示。
  String composeStoryNarrative(StoryBeat beat) {
    final parts = <String>[];

    // 结局回合：只呈现结局，不再有情境与选项。
    if (beat.endingTitle != null) {
      parts.add('🏁 结局 · ${beat.endingTitle}');
      if (beat.endingBody != null && beat.endingBody!.trim().isNotEmpty) {
        parts.add(beat.endingBody!.trim());
      }
      parts.add(
        '（这一部的剧情到此结束。你可以继续在城堡里自由活动，'
        '或在设置中开始新的存档。）',
      );
      return parts.join('\n\n');
    }

    final step = beat.step;
    if (step == null) {
      return '剧情数据暂时不可用，请尝试重新开始一局。';
    }

    // [层1] 情境层，带章节抬头——让玩家时刻知道"我在第几章"。
    final book = findStoryBook(storyProgress.bookId);
    final chapter = findStoryChapter(storyProgress.bookId, step.chapterId);
    final header = book != null && chapter != null
        ? '《${book.title}》第 ${chapter.ordinal} 章 · ${chapter.title}'
        : '主线剧情';
    parts.add('📖 $header');

    // 【自由插话回合】不走"情境三明治"，而是"你做了什么 → 世界如何回应"：
    // 玩家上一句还在读这一步的情境，再贴一遍 setup 会显得像重开了一屏。
    // 这里只呈现插话本身 + 现场回应，末尾提示剧情仍在原地等他继续。
    if (beat.isFreeformInterjection) {
      parts.add('你选择按自己的方式行动：${beat.freeActionText ?? ''}。');
      final ai = beat.freeformAiText;
      if (ai != null && ai.trim().isNotEmpty) {
        parts.add(ai.trim());
      } else if (step.ambient.isNotEmpty) {
        // 本地兜底：AI 不可用时用当前步的氛围池回应一句，
        // 让玩家感到"这句话被听见了"，而不是打了一行字毫无反应。
        parts.add(step.ambient[storyProgress.stepTurnSeed % step.ambient.length]);
      }
      parts.add('（主线仍在原处等你——上面的选项依然有效。）');
      return parts.join('\n\n');
    }

    if (beat.onEnterText != null && beat.onEnterText!.trim().isNotEmpty) {
      parts.add(beat.onEnterText!.trim());
    }
    parts.add(step.setup.trim());

    // [层2] 因果层：把上一步的选择与本步串起来。
    final causal = composeCausalText(beat);
    if (causal.isNotEmpty) parts.add(causal);

    // [层3] 世界层：地点氛围（复用沙盒的地点池，保证两套玩法读到的
    // "城堡的样子"是一致的）。
    if (step.ambient.isNotEmpty) {
      parts.add(step.ambient[storyProgress.stepTurnSeed % step.ambient.length]);
    } else {
      final p = player;
      if (p != null) {
        final location = worldState.currentLocation ?? '霍格沃茨';
        final hour = worldState.time.hour;
        final lines = localEventLinesWithRoommates(
          location: location,
          hour: hour,
          seed: storyProgress.stepTurnSeed,
        );
        if (lines.isNotEmpty) {
          parts.add(lines[storyProgress.stepTurnSeed % lines.length]);
        }
      }
    }

    // 收束层：玩家做了什么 + 数值变动的可读回馈。
    if (beat.consequence.trim().isNotEmpty) {
      if (beat.freeActionText != null) {
        parts.add('你选择按自己的方式行动：${beat.freeActionText}。');
      }
      parts.add(beat.consequence.trim());
    }
    final delta = formatStoryDelta(beat.effect);
    if (delta.isNotEmpty) parts.add(delta);

    return parts.join('\n\n');
  }

  /// [层2 因果层] 把上一步的选择与获得的情报，织成一句过渡。
  ///
  /// 【为什么需要这一层】没有它，每一步都是独立的情境描写，读起来像
  /// "在同一个地方反复醒来"。有了它，玩家能看见自己的选择正在生效——
  /// 这是"有因果"在文本上唯一的证据。
  String composeCausalText(StoryBeat beat) {
    final prev = beat.prevStep;
    if (prev == null) return '';
    final lines = <String>[];

    // 情报引用：优先引用与本步 setup 相关的那条（简单的子串重叠判定），
    // 引不到就引用最近一条——总比不说强。
    final knowledge = storyProgress.knowledge;
    if (knowledge.isNotEmpty) {
      final corpus = '${beat.step?.setup ?? ''}${prev.setup}';
      String? picked;
      for (final k in knowledge.reversed) {
        // 正则已提为文件级预编译（_reNonWordChars）：
        // 这个方法每回合都会跑，而本仓库有源码形状守卫
        // （test/regex_hotpath_test.dart）专门抓循环内现编译 RegExp。
        final token = k.replaceAll(_reNonWordChars, '');
        if (token.isNotEmpty && corpus.contains(token)) {
          picked = k;
          break;
        }
      }
      picked ??= knowledge.last;
      lines.add('你还记得之前留意到的那件事（$picked），于是脚步没有停。');
    }

    // 选择引用：上一步做了什么。
    final chosenId = storyProgress.chosen[prev.id];
    if (chosenId != null) {
      for (final c in prev.choices) {
        if (c.id == chosenId) {
          lines.add('你此前的做法还留有余波：${c.text}。');
          break;
        }
      }
    }

    return lines.join('\n');
  }

  /// 把数值变动转成玩家能读懂的一行。全部为 0 时返回空串（不显示噪声）。
  String formatStoryDelta(StoryEffect e) {
    final bits = <String>[];
    if (e.housePoints != 0) {
      bits.add('学院分 ${e.housePoints > 0 ? '+' : ''}${e.housePoints}');
    }
    if (e.reputation != 0) {
      bits.add('声望 ${e.reputation > 0 ? '+' : ''}${e.reputation}');
    }
    if (e.spirit != 0) {
      bits.add('精神 ${e.spirit > 0 ? '+' : ''}${e.spirit}');
    }
    if (e.affection != 0) {
      bits.add('好感 ${e.affection > 0 ? '+' : ''}${e.affection}');
    }
    if (e.galleons != 0) {
      bits.add('加隆 ${e.galleons > 0 ? '+' : ''}${e.galleons}');
    }
    if (e.addItems.isNotEmpty) {
      bits.add('获得物品×${e.addItems.length}');
    }
    if (e.addKnowledge.isNotEmpty) {
      bits.add('获得情报×${e.addKnowledge.length}');
    }
    return bits.isEmpty ? '' : '（${bits.join('，')}）';
  }
}

/// 情报 token 归一化：剥掉下划线与所有非文字字符（`composeCausalText` 用）。
///
/// 【为什么提为文件级】它在 `composeCausalText` 的循环里逐条情报调用，
/// 而本仓库有源码形状守卫（`test/regex_hotpath_test.dart`）专门禁止
/// "循环内现编译 RegExp"。这条守卫曾抓出过真实的性能回归，不是风格洁癖。
final RegExp _reNonWordChars = RegExp(r'[_\W]+');
