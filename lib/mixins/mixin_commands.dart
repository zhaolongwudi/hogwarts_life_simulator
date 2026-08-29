import 'dart:async';
import '../data/pet_data.dart';
import '../data/pet_narrative_config.dart';
import '../data/game_config_rules.dart';
import '../data/command_registry.dart';
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../data/cg_data.dart';
import '../data/goal_data.dart';
import '../data/wand_data.dart';
import '../providers/game_provider_base.dart';
import 'mixin_systems.dart';

mixin GameCommandsMixin on GameProviderBase {
  // ================ R1：注册命令到注册表（初始化时调用一次即可） ================
  bool _commandsRegistered = false;

  void _ensureCommandsRegistered() {
    if (_commandsRegistered) return;
    _commandsRegistered = true;
    final registry = CommandRegistry.instance;
    registry.resetForTesting();

    // —— 基础信息类 ——
    registry.registerAll([
      CommandDef(
        primary: '状态',
        group: '基础信息',
        helpText: '查看角色完整状态',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m._formatStatus();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '时间',
        group: '基础信息',
        helpText: '查看当前时间与特殊标记',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m._formatTime();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '快进',
        aliases: ['跳过', '时间跳跃', 'skip'],
        group: '基础信息',
        helpText: '快进时间：/快进 [天数|明天|下周|下月|假期|暑假|开学]',
        handler: (ctx) {
          final m = ctx.provider as GameSystemsMixin;
          final days = m.resolveFastForwardDays(ctx.tailFrom(0));
          // days == 0 表示「你要的时间点已经到了」——7 月里输入
          // 「/快进 暑假」就是这种。老实现会借 _daysUntilMonth 的循环
          // 绕满一整年，直接跳掉 351 天。
          if (days <= 0) {
            m.currentNarrative = '【时间快进】\n'
                '${m.worldState.time.formatDate()} —— 你要的时间点已经到了，无需快进。';
            m.choices = [const GameChoice(text: '继续', action: '继续')];
            m.notifyListeners();
            return true;
          }
          final before = m.worldState.time.formatDate();
          // 快进若跨过毕业，_graduationSettlement 会把「七年统计 + 人生目标
          // 达成判定」整段报告追加到 currentNarrative 尾部，而下面这行
          // 又会无条件覆盖它——玩家最后只看到一条「🎓 你从霍格沃茨毕业了！」
          // 通知，七年的账本和 goal_achieved 的判定结果全都没了。
          // 这里先把快进期间追加进来的那一段截出来，最后再接回去。
          final narrativeBefore = m.currentNarrative;
          final produced = m.fastForwardDays(days);
          final after = m.worldState.time.formatDate();
          final appended = m.currentNarrative.startsWith(narrativeBefore)
              ? m.currentNarrative.substring(narrativeBefore.length).trim()
              : '';

          final buf = StringBuffer()
            ..writeln('【时间快进】')
            ..writeln('$before → $after（共 $days 天）');
          if (produced.isNotEmpty) {
            buf.writeln('\n期间发生：');
            for (final n in produced.take(12)) {
              buf.writeln('· $n');
            }
            if (produced.length > 12) {
              buf.writeln('……等共 ${produced.length} 条（/通知 查看全部）');
            }
          } else {
            buf.writeln('\n这段日子里没有发生什么值得一提的事。');
          }
          if (appended.isNotEmpty) {
            buf.writeln('\n$appended');
          }
          buf.writeln('\n接下来你想做些什么？');
          m.currentNarrative = buf.toString();
          m.choices = [
            GameChoice(text: '继续', action: '继续'),
            GameChoice(text: '再快进一个月', action: '/快进 下月'),
          ];
          m.notifyListeners();
          return true;
        },
      ),
      CommandDef(
        primary: '地图',
        group: '基础信息',
        helpText: '查看霍格沃茨地图与NPC位置',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m._formatMap();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '通知',
        group: '基础信息',
        helpText: '查看未读通知',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m._formatNotifications();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '帮助',
        group: '基础信息',
        helpText: '查看指令说明',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = CommandRegistry.instance.buildHelpText();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
    ]);

    // —— 关系 / 恋爱 / 声望类 ——
    registry.registerAll([
      CommandDef(
        primary: '关系',
        group: '关系&情感',
        helpText: '查看所有NPC好感度与关系',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatRelationships();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '查看',
        aliases: ['看', '打量', '观察', '打听'],
        group: '关系&情感',
        helpText: '查看某位NPC的档案：/查看 [名字]（不带名字则列出可查看的人）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatCharacterDossier(ctx.tailFrom(0));
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '送礼',
        aliases: ['送', '赠', '赠送', '给'],
        group: '关系&情感',
        helpText: '把背包里的东西送给NPC：/送礼 [名字] [物品]，例如 /送礼 赫敏 旧书'
            '（只写名字则提示对方喜好）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          // 「/送礼 赫敏 旧书」：首词是人名，其余是物品名
          // （物品名本身可能含空格，所以取剩下整段而不是 arg(1)）
          final who = ctx.arg(0) ?? '';
          final what = ctx.tailFrom(1);
          m.currentNarrative = m.giveGift(who, what);
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '恋爱',
        group: '关系&情感',
        helpText: '查看恋爱状态',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatLove();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '声望',
        group: '关系&情感',
        helpText: '查看声望档案',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatReputation();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '舆论',
        // 「谣言」以前只出现在 helpText 里，玩家照着输会得到一个「未知指令」
        aliases: ['传闻', '谣言'],
        group: '关系&情感',
        helpText: '查看校园里的传闻/谣言',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatRumors();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '血缘',
        group: '关系&情感',
        helpText: '查看血缘亲属',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatBloodRelatives();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '恋爱等待',
        group: '关系&情感',
        helpText: '查看等待中的恋爱事件',
        // 别加带空格的别名：调度只拿 parts[0] 去 find，永远匹配不上
        aliases: const [],
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatLoveWaiting();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '恋爱阶段',
        group: '关系&情感',
        helpText: '查看恋爱阶段说明',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatLoveStages();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '关系网络',
        // 同上：带空格的别名匹配不上。真正能用的是 /关系网络
        aliases: const [],
        group: '关系&情感',
        helpText: '查询两位NPC间的关系（/关系网络 [NPC1] [NPC2]）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.length >= 2) {
            m.currentNarrative = m.formatNpcRelationship(ctx.arg(0)!, ctx.arg(1)!);
          } else {
            m.currentNarrative = '请输入两位NPC的名字：/关系网络 [NPC1] [NPC2]';
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '骨科',
        aliases: ['骨科状态'],
        group: '关系&情感',
        helpText: '查看骨科模式状态',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatBoneMode();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '家庭',
        aliases: ['婚姻', '配偶', '孩子', '子女'],
        group: '关系&情感',
        helpText: '查看婚姻/怀孕/子女状态',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatFamily();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '求婚',
        aliases: ['求婚戒指'],
        group: '关系&情感',
        helpText: '向恋人求婚（需恋爱中、好感≥95、五年级以上）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final err = m.proposeMarriage();
          m.currentNarrative = err != null
              ? '【求婚】\n$err\n\n${m.formatFamily()}'
              : '你单膝跪地，把戒指举到对方面前。\n\n${m.formatFamily()}';
          m.choices = [
            if (err == null) GameChoice(text: '筹备婚礼', action: '/结婚'),
            GameChoice(text: '返回', action: '继续'),
          ];
          return true;
        },
      ),
      CommandDef(
        primary: '结婚',
        aliases: ['婚礼', '举行婚礼'],
        group: '关系&情感',
        helpText: '举行婚礼（需已订婚）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final err = m.holdWedding();
          m.currentNarrative = err != null
              ? '【婚礼】\n$err\n\n${m.formatFamily()}'
              : '礼堂里洒满了花瓣，你们在众人的注视下交换了誓言。\n\n${m.formatFamily()}';
          m.choices = [
            if (err == null) GameChoice(text: '要个孩子', action: '/生育'),
            GameChoice(text: '返回', action: '继续'),
          ];
          return true;
        },
      ),
      CommandDef(
        primary: '生育',
        aliases: ['备孕', '要孩子', '怀孕'],
        group: '关系&情感',
        helpText: '婚后备孕（孕期 120 天，可用 /快进 推进）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final err = m.tryConceive();
          m.currentNarrative = err != null
              ? '【生育】\n$err\n\n${m.formatFamily()}'
              : '你们决定迎接一个新生命。\n\n${m.formatFamily()}';
          m.choices = [
            if (err == null) GameChoice(text: '快进一个月', action: '/快进 下月'),
            GameChoice(text: '返回', action: '继续'),
          ];
          return true;
        },
      ),
      CommandDef(
        primary: '拉郎配',
        aliases: ['撮合', '拉郎', '配对', '磕cp', '磕CP'],
        group: '关系&情感',
        helpText: '撮合两位NPC：/拉郎配 [甲] [乙]（/拉郎配 放弃 [编号] 放手）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final a = ctx.arg(0);
          final b = ctx.arg(1);
          if (a != null && a == '放弃') {
            final idx = int.tryParse(b ?? '');
            if (idx == null) {
              m.currentNarrative = '请输入要放手的编号：/拉郎配 放弃 [编号]';
            } else {
              m.stopShipping(idx - 1);
              m.currentNarrative = m.formatShippings();
            }
          } else if (a != null && b != null) {
            final err = m.startShipping(a, b);
            m.currentNarrative = err != null ? '【拉郎配】\n$err' : m.formatShippings();
          } else {
            m.currentNarrative = m.formatShippings();
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
    ]);

    // —— 学业 & 成就 & 收藏类 ——
    registry.registerAll([
      CommandDef(
        primary: '课程',
        group: '学业&成长',
        helpText: '查看课程表与进度',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatCourses();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '课堂',
        group: '学业&成长',
        helpText: '触发课堂互动（/课堂 互动）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.length >= 1 && ctx.arg(0) == '互动') {
            m.classroomInteraction();
          } else {
            m.currentNarrative = '【课堂互动】\n输入 /课堂 互动 触发当前课堂的互动环节（教授提问、实践练习、同桌互动、随机意外）。\n\n当前课表见 /课程。';
            m.choices = [GameChoice(text: '返回', action: '继续')];
          }
          return true;
        },
      ),
      CommandDef(
        primary: '咒语',
        group: '学业&成长',
        helpText: '魔咒一览（/咒语 学习 漂浮咒 ｜ /咒语 练习 漂浮咒 ｜ /咒语 详情 漂浮咒）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final verb = ctx.arg(0) ?? '';
          final rest = ctx.tailFrom(1);
          switch (verb) {
            case '学习':
            case '学':
              if (rest.isEmpty) {
                m.currentNarrative = '要学哪个咒语？用法：/咒语 学习 漂浮咒\n\n'
                    '不知道能学什么就先输入 /咒语';
                m.choices = [GameChoice(text: '返回', action: '继续')];
              } else {
                m.learnSpell(rest);
              }
            case '练习':
            case '练':
              if (rest.isEmpty) {
                m.currentNarrative = '要练哪个咒语？用法：/咒语 练习 漂浮咒';
                m.choices = [GameChoice(text: '返回', action: '继续')];
              } else {
                m.practiseSpell(rest);
              }
            case '详情':
              if (rest.isEmpty) {
                m.currentNarrative = '要查哪个咒语？用法：/咒语 详情 漂浮咒';
                m.choices = [GameChoice(text: '返回', action: '继续')];
              } else {
                m.currentNarrative = m.formatSpellDetail(rest);
                m.choices = [GameChoice(text: '返回', action: '继续')];
              }
            case '':
              m.currentNarrative = m.formatSpells();
              m.choices = [GameChoice(text: '返回', action: '继续')];
            default:
              // 没带动词时把它当成咒语名，等价于 /咒语 详情 xxx
              m.currentNarrative = m.formatSpellDetail(ctx.tailFrom(0));
              m.choices = [GameChoice(text: '返回', action: '继续')];
          }
          return true;
        },
      ),
      CommandDef(
        primary: '收藏',
        group: '学业&成长',
        helpText: '查看收藏品',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatCollection();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '日记',
        group: '学业&成长',
        helpText: 'CG图鉴：统计/详情/重播（/日记 统计·/日记 [编号]·/日记 重播 [编号]）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.length >= 1 && ctx.arg(0) == '统计') {
            m.currentNarrative = m._formatDiaryStats();
          } else if (ctx.parts.length >= 2 && ctx.arg(0) == '重播') {
            m.currentNarrative = m._replayCg(ctx.arg(1)!);
          } else if (ctx.parts.length >= 1) {
            m.currentNarrative = m._formatCgDetail(ctx.arg(0)!);
          } else {
            m.currentNarrative = m._formatDiary();
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '档案',
        group: '学业&成长',
        helpText: '查看角色完整档案',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m._formatArchive();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '成就',
        group: '学业&成长',
        helpText: '查看成就列表',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m._formatAchievements();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
    ]);

    // —— 物品 & 宠物 ——
    registry.registerAll([
      CommandDef(
        primary: '宠物',
        group: '物品&宠物',
        helpText: '宠物：查看 / 喂食 / 玩耍 / 训练 / 购买',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final sub = ctx.arg(0);
          if (sub != null &&
              ['喂食', '喂', '食物', '玩耍', '玩', '训练', '练'].contains(sub)) {
            m.petInteract(sub);
          } else if (sub != null &&
              ['购买', '买', '选购', '挑选'].contains(sub)) {
            // 以前没宠物时 /宠物 会让人「去对角巷挑选」，但商店里没宠物卖。
            // 现在这里真能买。
            m.currentNarrative = m.buyPet(ctx.tailFrom(1));
          } else {
            m.currentNarrative = m._formatPet();
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '使用',
        group: '物品&宠物',
        helpText: '使用背包物品：/使用 <物品名>',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isEmpty) {
            m.currentNarrative = m.formatItemUseHelp();
          } else {
            m.useItem(ctx.tailFrom(0));
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '装备',
        group: '物品&宠物',
        helpText: '穿戴装备：/装备 <物品名>',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isEmpty) {
            m.currentNarrative = m.formatEquip();
          } else {
            m.equipItem(ctx.tailFrom(0));
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '卸下',
        group: '物品&宠物',
        helpText: '脱下装备：/卸下 <袍子|帽子|扫帚|饰品>',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.isEmpty) {
            m.currentNarrative = m.formatEquip();
          } else {
            m.unequipItem(ctx.arg(0)!);
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
    ]);

    // —— 活动 & 玩法 ——
    registry.registerAll([
      CommandDef(
        primary: '魁地奇',
        group: '玩法&活动',
        helpText: '魁地奇：/魁地奇 比赛·/魁地奇 位置 <位置>',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.length >= 1 && ctx.arg(0) == '比赛') {
            m.playQuidditch();
          } else if (ctx.parts.length >= 2 && ctx.arg(0) == '位置') {
            m.setQuidditchPosition(ctx.arg(1)!);
          } else {
            m.currentNarrative = m.formatQuidditch();
            m.choices = [GameChoice(text: '返回', action: '继续')];
          }
          return true;
        },
      ),
      CommandDef(
        primary: '决斗',
        group: '玩法&活动',
        helpText: '与NPC巫师决斗：/决斗 [NPC名]（空参随机）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          final arg = ctx.parts.isNotEmpty ? ctx.tailFrom(0) : null;
          m.duelNpc(arg);
          return true;
        },
      ),
      CommandDef(
        primary: '禁林',
        group: '玩法&活动',
        helpText: '禁林探险：/禁林 探险',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.length >= 1 && ctx.arg(0) == '探险') {
            m.exploreForbiddenForest();
          } else {
            m.currentNarrative = '【禁林】\n'
                '黑暗而神秘的森林，栖息着许多神奇生物，也藏着危险。\n'
                '输入 /禁林 探险 进入禁林探索（消耗 3 小时，可能遭遇生物、采集材料或受伤）。\n\n'
                '低年级学生请量力而行——一年级的魔杖在这里还很脆弱。';
            m.choices = [GameChoice(text: '返回', action: '继续')];
          }
          return true;
        },
      ),
      CommandDef(
        primary: '图鉴',
        group: '玩法&活动',
        helpText: '查看已发现的魔法生物图鉴',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatBestiary();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '委托',
        group: '玩法&活动',
        helpText: '支线委托板：/委托 刷新·接受 [编号]·交付 [编号]',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.length >= 1 && ctx.arg(0) == '刷新') {
            m.refreshQuestBoard();
          } else if (ctx.parts.length >= 2 && ctx.arg(0) == '接受') {
            m.acceptQuest((int.tryParse(ctx.arg(1)!) ?? 0) - 1);
          } else if (ctx.parts.length >= 2 && ctx.arg(0) == '交付') {
            m.deliverQuest((int.tryParse(ctx.arg(1)!) ?? 0) - 1);
          } else {
            m.currentNarrative = m.formatQuests();
            m.choices = [GameChoice(text: '返回', action: '继续')];
          }
          return true;
        },
      ),
      CommandDef(
        primary: '学院杯',
        group: '玩法&活动',
        helpText: '查看学院杯积分与排名',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatHouseCup();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '新NPC',
        group: '玩法&活动',
        helpText: '生成一位新NPC（每学年限4次）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.generateNewNPC();
          return true;
        },
      ),
    ]);

    // —— 信件 & 目标 & 世界 & 结局 ——
    registry.registerAll([
      CommandDef(
        primary: '信',
        group: '信件&目标',
        helpText: '查看信件：读/回/寄（/信 读 [编号]·/信 回 [编号] [内容]·/信 寄 [NPC] [内容]）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.handleLetterCommand(ctx.parts);
          // handler 里已经写了 choices
          return true;
        },
      ),
      CommandDef(
        primary: '联动',
        group: '世界&结局',
        helpText: '查看时代联动痕迹',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          // 文案以前许诺的是"与其他时代剧情产生关联（遇到亲世代留下的物品或
          // 信件）"，但那套内容并不存在，而列表又从来没被写入过——玩家看到的
          // 永远是一句「暂无。」加一段兑现不了的说明。改成如实描述：这里记的
          // 是你亲手造成的不可逆分叉。
          final branches = m.worldState.timelineBranches;
          m.currentNarrative = '【世界线】\n当前时代：${m.eraLabel(m.appProvider.era)}\n'
              '每跨过一个回不了头的节点，世界线就分出一条只有这一周目存在的支流。\n'
              '世界线变动次数：${m.worldState.timelineChanges}\n'
              '已记录的分叉：\n${branches.isEmpty ? '暂无——毕业、成婚这类不可逆的节点会出现在这里。' : branches.reversed.map((b) => '· $b').join('\n')}';
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '世界演化',
        group: '世界&结局',
        helpText: '查看世界演化情况',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m.currentNarrative = m.formatWorldEvolution();
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '目标',
        group: '信件&目标',
        helpText: '查看/设定人生目标（/目标 [编号]·/目标 进度）',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          if (ctx.parts.length >= 1 &&
              (ctx.arg(0) == '进度' || ctx.arg(0) == 'progress')) {
            m.currentNarrative = m.formatGoalProgress();
            m.choices = [GameChoice(text: '返回', action: '继续')];
            return true;
          }
          if (ctx.parts.length >= 1) {
            final arg = ctx.tailFrom(0);
            LifeGoal? goal;
            final idx = int.tryParse(arg);
            if (idx != null && idx >= 1 && idx <= lifeGoalCatalog.length) {
              goal = lifeGoalCatalog[idx - 1];
            } else {
              goal = goalById(arg) ?? goalByName(arg);
            }
            if (goal != null) {
              ctx.provider.player?.currentGoal = goal.name;
              m.currentNarrative = '✅ 已设定人生目标：${goal.name}\n'
                  '『${goal.description}』\n\n'
                  '这条目标将牵引后续剧情方向，但你仍可自由行动。\n'
                  '输入 /目标 可重新查看或更换。';
            } else {
              m.currentNarrative = '未找到目标"$arg"。输入 /目标 查看全部目标。';
            }
          } else {
            m.currentNarrative = m._formatGoals();
          }
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
      CommandDef(
        primary: '结局',
        aliases: ['终章'],
        group: '世界&结局',
        helpText: '生成终章报告，书写你的七年人生结局',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m._startEndingSequence();
          return true;
        },
      ),
    ]);

    // —— 作弊指令 ——
    registry.registerAll([
      CommandDef(
        primary: 'cheat',
        group: '作弊',
        permission: 'cheat',
        helpText: '作弊指令总入口（好感/资源/声望/时间/骨科/舆论/解锁CG），详情见 /cheat',
        handler: (ctx) {
          final m = ctx.provider as GameCommandsMixin;
          m._handleCheat(ctx.parts);
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
    ]);

    registry.seal();
  }

  void closeCommandPanel() {
    if (commandResult == null) return;
    commandResult = null;
    notifyListeners();
  }

  /// 本地指令解析（设定文档第X部分指令系统）
  ///
  /// R1：优先走 CommandRegistry（数据驱动路由，自动生成帮助），
  /// 找不到匹配时 fallback 到旧 switch-case（双活方案确保平滑迁移）。

  bool handleLocalCommand(String command) {
    final p = player;
    if (p == null) return false;
    _ensureCommandsRegistered();

    final parts = command.split(RegExp(r'\s+'));
    final cmd = parts[0];

    // 去掉前导 "/"，匹配注册表
    final slashless = cmd.startsWith('/') ? cmd.substring(1) : cmd;
    final registry = CommandRegistry.instance;
    final def = registry.find(slashless);
    if (def != null) {
      final ctx = CommandContext(parts.sublist(1), this as GameProviderBase);
      return def.handler(ctx);
    }

    // 未注册指令：给出可点选的近似指令，而不是把 "/状态统计" 当成自由行动发给 AI。
    if (cmd.startsWith('/')) {
      currentNarrative = _formatUnknownCommand(slashless);
      choices = [
        ..._suggestCommands(slashless).take(3).map(
            (c) => GameChoice(text: '/${c.primary}', action: '/${c.primary}')),
        GameChoice(text: '查看全部指令', action: '/帮助'),
      ];
      return true;
    }
    return false;
  }

  /// 未知指令提示：按「前缀/包含/编辑距离」给出最接近的几条候选，
  /// 比直接返回 false（把 /状态统计 当成自由行动文本发给 AI）友好得多。
  List<CommandDef> _suggestCommands(String input) {
    final scored = <(CommandDef, int)>[];
    for (final c in CommandRegistry.instance.all) {
      var best = 1 << 30;
      for (final name in [c.primary, ...c.aliases]) {
        final n = name.replaceAll(' ', '');
        final s = input.replaceAll(' ', '');
        final d = n.startsWith(s) || s.startsWith(n)
            ? 0
            : (n.contains(s) || s.contains(n) ? 1 : _levenshtein(s, n));
        if (d < best) best = d;
      }
      if (best <= 3) scored.add((c, best));
    }
    scored.sort((a, b) => a.$2.compareTo(b.$2));
    return scored.map((e) => e.$1).toList();
  }

  String _formatUnknownCommand(String input) {
    final suggestions = _suggestCommands(input);
    final buf = StringBuffer()..writeln('❓ 没有「/$input」这条指令。');
    if (suggestions.isNotEmpty) {
      buf.writeln('\n你是不是想输入：');
      for (final c in suggestions.take(4)) {
        buf.writeln('  /${c.primary} — ${c.helpText}');
      }
    } else {
      buf.writeln('\n输入 /帮助 查看全部可用指令。'
          '\n如果你想把这段话当成自由行动交给 AI，请把开头的「/」去掉。');
    }
    return buf.toString();
  }

  /// 标准编辑距离（候选词都很短，O(n·m) 完全够用）
  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var cur = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        cur[j] = [
          prev[j] + 1,
          cur[j - 1] + 1,
          prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        ].reduce((x, y) => x < y ? x : y);
      }
      final t = prev;
      prev = cur;
      cur = t;
    }
    return prev[b.length];
  }

  // ==================== 作弊指令（设定 8.1-8.5） ====================

  /// [parts] 为「去掉 /cheat 命令本身」后的子参数列表，parts[0] 即子命令。
  void _handleCheat(List<String> parts) {
    final p = player;
    if (p == null) return;
    if (parts.isEmpty) {
      currentNarrative = _formatCheatHelp();
      choices = [GameChoice(text: '返回', action: '继续')];
      return;
    }
    final sub = parts[0];

    switch (sub) {
      case '好感':
      case 'affection':
        if (parts.length >= 3) {
          final nameKey = parts[1];
          NPC? npc;
          for (final n in npcRegistry.values) {
            if (n.name.contains(nameKey)) { npc = n; break; }
          }
          npc ??= npcRegistry[nameKey];
          if (npc == null) {
            final allNames = npcRegistry.values.map((n) => n.name).join('、');
            currentNarrative = '未找到NPC "$nameKey"。可用：$allNames';
            break;
          }
          final delta = int.tryParse(parts[2]);
          if (delta != null) {
            // 作弊指令刻意绕过好感上限，这里只补上状态同步：
            // 恋爱阶段与关系等级原本会停在旧值，导致面板与实际数值对不上。
            npc.affection = (npc.affection + delta).clamp(-100, 100);
            if (npc.affection > npc.maxAffectionReached) {
              npc.maxAffectionReached = npc.affection;
            }
            syncRelationshipLevel(npc);
            checkAffectionAchievements(npc);
            notifyListeners();
            currentNarrative = '已调整「${npc.name}」的好感度：${npc.affection}（${npc.affectionStage}）';
          }
        }
        break;

      case '资源':
      case 'resources':
        if (parts.length >= 3) {
          final amount = int.tryParse(parts[1]) ?? 0;
          switch (parts[2]) {
            case '魔力':
            case 'mp':
              p.magic = (p.magic + amount).clamp(0, 100);
              break;
            case '精神力':
            case 'sp':
              p.spirit = (p.spirit + amount).clamp(0, 100);
              break;
            case '饱食':
            case 'sat':
              p.satiety = (p.satiety + amount).clamp(0, 100);
              break;
            case '精力':
            case 'energy':
              p.energy = (p.energy + amount).clamp(0, 100);
              break;
            case '生命':
            case 'hp':
              p.health = (p.health + amount).clamp(0, 100);
              break;
          }
          currentNarrative = '资源已调整。';
        }
        break;

      case '声望':
      case 'reputation':
        if (parts.length >= 3) {
          final amount = int.tryParse(parts[1]) ?? 0;
          p.playerReputation.add(parts[2], amount);
          currentNarrative =
              '${p.playerReputation.labelOf(parts[2])} ${p.playerReputation.get(parts[2])}';
        }
        break;

      case '时间':
      case 'time':
        if (parts.length >= 2) {
          final days = int.tryParse(parts[1]);
          if (days != null) fastForwardTime(days);
          currentNarrative = '时间已推进 $days 天。\n${worldState.timestamp}';
        }
        break;

      case '骨科':
        if (parts.length >= 2 && parts[1] == '无视') {
          p.boneMode = true;
          unlockAchievement('bone_mode');
          notifications.add('⚠️ 骨科模式已开启：禁忌的大门已为你敞开');
          worldState.addNarrativeEvent('⚠️ 骨科模式已开启：禁忌限制解除', turn: turnCount);
          bumpImpactScore(0.1, debugReason: '开启骨科模式(世界线剧烈扰动)');
          currentNarrative =
              '【骨科模式已开启】三代内血亲的禁忌限制已解除，但这意味着你的选择将付出更沉重的代价。';
        } else {
          currentNarrative = '使用方式：/cheat 骨科 无视（开启骨科模式）';
        }
        break;

      case '舆论':
      case 'rumor':
        if (parts.length >= 2 && parts[1] == '重置') {
          p.rumors.clear();
          currentNarrative = '已清除所有舆论传闻。';
        } else if (parts.length >= 3 && parts[1] == '清除') {
          final key = parts.sublist(2).join(' ');
          final before = p.rumors.length;
          p.rumors.removeWhere((r) => r.contains(key));
          currentNarrative = '已清除 ${before - p.rumors.length} 条相关传闻。';
        } else {
          currentNarrative = '使用方式：/cheat 舆论 清除 <关键词> 或 /cheat 舆论 重置';
        }
        break;

      case '解锁CG':
      case 'cg':
        if (parts.length >= 2) {
          final cg = cgById(parts[1]);
          if (cg != null) {
            unlockCG(cg);
            currentNarrative = '已解锁 CG：${cg.name}';
          } else {
            currentNarrative = '未找到该 CG，可用：${allCgs().map((c) => c.id).take(10).join(', ')}...';
          }
        }
        break;

      default:
        currentNarrative = _formatCheatHelp();
    }
    choices = [GameChoice(text: '返回', action: '继续')];
  }

  String _formatCheatHelp() {
    return '''【作弊指令】
  /cheat 好感 <NPC名> <数值>  — 调整好感度
  /cheat 资源 <数值> <魔力|精神力|饱食|精力|生命>
  /cheat 声望 <数值> <academic|social|combat|moral|leadership|dark>
  /cheat 时间 <天数>
  /cheat 骨科 无视 — 开启骨科模式
  /cheat 舆论 清除 <关键词> — 清除相关传闻
  /cheat 舆论 重置 — 清空所有传闻
  /cheat 解锁CG <CG编号> — 解锁指定CG''';
  }

  // ==================== 生成新NPC（增强版：多人格+多样化） ====================

  String _formatStatus() {
    final p = player!;
    final w = worldState;
    // resolveMagicAptitude 要扫长期记忆里的关键事实，原来在插值里连调两次
    final aptitude = resolveMagicAptitude(p);
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《哈利·波特·魔法纪元·人生状态》')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln('【时间】${w.timestamp}')
      ..writeln('【年龄】${calculateAge()}岁')
      ..writeln('【血统】${bloodStatusLabel(p.bloodType)}')
      ..writeln('【身份】${p.birthIdentity ?? '未设定'}')
      ..writeln('【所在地】${w.currentLocation ?? '未知'}')
      ..writeln('【学院】${p.house ?? '未分院'} · ${p.grade ?? 1}年级')
      // 以前这里打的是 initialTalent，和下面的「主修天赋」是同一个字段。
      // 在校就是学生，毕业后用最近一次打工的岗位。
      ..writeln('【职业】${worldState.graduated ? (p.currentJobTitle ?? '待业') : '霍格沃茨${p.grade ?? 1}年级学生'}')
      ..writeln('【财富】💰 ${p.galleons}金加隆 · 🏦 ${p.bankGalleons}古灵阁')
      ..writeln('【家庭】${p.familyBackground ?? '未设定'}')
      ..writeln('【社会地位】学院声望${p.houseReputation} · 魔法界声望${p.wizardingReputation} · 阵营声望${p.factionReputation}')
      ..writeln()
      ..writeln('【生存状态】')
      ..writeln('❤️ 生命：${p.health}/100')
      ..writeln('🔮 魔力：${p.magic}/100')
      ..writeln('🧠 精神力：${p.spirit}/100')
      ..writeln('🍗 饱食度：${p.satiety}/100')
      ..writeln('⚡ 精力：${p.energy}/100')
      ..writeln()
      ..writeln('【魔法能力】')
      ..writeln('魔法资质：${aptitude.isEmpty ? '普通' : aptitude}')
      ..writeln('主修天赋：${p.initialTalent ?? '未设定'}')
      // 这一行以前永远是「尚未学会任何魔咒」或「1个咒语」——咒语没有学习
      // 入口。现在 /咒语 能学能练，这里顺手指一下，玩家才知道有这条路。
      ..writeln('已学魔咒：${p.learnedSpells.isEmpty ? '尚未学会任何魔咒（/咒语 查看可学的）' : '${p.learnedSpells.length}个咒语（/咒语 查看详情）'}')
      ..writeln()
      ..writeln('【学院四维】')
      ..writeln('勇气：${p.houseDimensions['courage']}  智慧：${p.houseDimensions['wisdom']}')
      ..writeln('忠诚：${p.houseDimensions['loyalty']}  野心：${p.houseDimensions['ambition']}')
      ..writeln()
      ..writeln('【政治倾向】${p.politicalTendency ?? '未设定'}')
      ..writeln('【模拟风格】${p.simulationStyle ?? '混合模式'}')
      ..writeln('【恋爱状态】${p.loveState.status}${p.loveState.partnerName != null ? '（${p.loveState.partnerName}）' : ''}')
      ..writeln('【世界线变动率】${(p.worldLineDeviation * 100).toStringAsFixed(1)}%')
      ..writeln()
      ..writeln('【装备栏】')
      ..writeln('袍子：${p.equipped['robe'] ?? '（空）'}  帽子：${p.equipped['hat'] ?? '（空）'}')
      ..writeln('扫帚：${p.equipped['broom'] ?? '（空）'}  饰品：${p.equipped['amulet'] ?? '（空）'}')
      ..writeln('【学院杯】${p.house != null ? '本学年贡献 ${p.houseCupPoints} 分（/学院杯 查看）' : '未分院，暂未参与'}')
      ..writeln('【当前目标】${p.currentGoal ?? '尚未设定目标'}');
    return buf.toString();
  }

  String _formatTime() {
    final w = worldState;
    return '【当前时间】\n${w.timestamp}\n'
        '学年：${w.academicYear}\n'
        '学期：${termLabel(w.term)}\n'
        '流速模式：${flowModeLabel(w.timeFlowMode)}\n'
        '${w.specialMarkers.isEmpty ? '' : '特殊标记：${w.specialMarkers.join(' ')}'}';
  }

  String _formatMap() {
    // R11：使用 mapRegions 数据（替代 8 行硬编码）
    final knownRegions = mapRegions.map((r) {
      final cond = r.unlockCondition != null ? '（${r.unlockCondition}）' : '';
      return '  ${r.icon} ${r.name}$cond';
    }).join('\n');
    return '''【霍格沃茨地图】
  当前地点：${worldState.currentLocation ?? '九又四分之三站台 / 霍格沃茨特快'}

  已知区域：
$knownRegions

  各NPC当前位置：
  ${npcRegistry.values.where((n) => n.isAlive).take(6).map((n) => '· ${n.name}：${n.currentLocation}').join('\n')}''';
  }

  String _formatNotifications() {
    if (notifications.isEmpty) {
      return '【通知】\n暂无新通知。';
    }
    return '【通知】\n${notifications.reversed.take(10).map((n) => '· $n').join('\n')}';
  }

  // ==================== 人生目标系统 ====================

  String _formatGoals() {
    final p = player;
    final current = p?.currentGoal;
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《人生目标》')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln('【当前目标】${(current == null || current.isEmpty) ? '尚未设定' : current}');
    if (current != null && current.isNotEmpty) {
      final g = goalByName(current);
      if (g != null) {
        buf.writeln('  『${g.description}』');
      }
    }
    buf
      ..writeln()
      ..writeln('【可选目标】（输入 /目标 [编号] 设定）');
    for (int i = 0; i < lifeGoalCatalog.length; i++) {
      final g = lifeGoalCatalog[i];
      buf.writeln('${i + 1}. ${g.name}（${g.category}）— ${g.description}');
    }
    if (current != null && current.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('💡 输入 /目标 进度 查看当前目标的毕业条件达成情况。');
    }
    return buf.toString();
  }

  // ==================== 终章 / 结局 ====================

  void _startEndingSequence() {
    if (player == null) return;
    isLoading = true;
    loadingStage = '正在书写你的终章…';
    currentNarrative = '';
    choices = [];
    notifyListeners();
    unawaited(generateEnding());
  }

  String _formatDiary() {
    if (player!.cgRecords.isEmpty) {
      return '【日记 / CG图鉴】\n暂无解锁CG。在关键剧情节点将解锁专属CG。\n\n（输入 /日记 统计 查看进度；/日记 [编号] 查看详情）';
    }
    final buf = StringBuffer('【日记 / CG图鉴】（已解锁 ${player!.cgRecords.length}/${allCgs().length}）\n');
    for (final cg in allCgs()) {
      final rec = player!.cgRecords[cg.id];
      if (rec == null) continue;
      buf.writeln('· ${cg.id} ${cg.name}（${rec.unlockedDate}）');
    }
    return buf.toString();
  }

  /// CG 数量与等级分布（设定 7.5 /日记 统计）

  String _formatDiaryStats() {
    final unlocked = player!.cgRecords;
    final all = allCgs();
    final byStars = <int, int>{2: 0, 3: 0, 4: 0, 5: 0};
    final byChapter = <String, int>{};
    for (final cg in all) {
      if (unlocked.containsKey(cg.id)) {
        byStars[cg.stars] = (byStars[cg.stars] ?? 0) + 1;
        byChapter[cg.chapter] = (byChapter[cg.chapter] ?? 0) + 1;
      }
    }
    final buf = StringBuffer()
      ..writeln('【日记统计】')
      ..writeln('已解锁：${unlocked.length}/${all.length}')
      ..writeln()
      ..writeln('【等级分布】')
      ..writeln('★★ 二星：${byStars[2] ?? 0}')
      ..writeln('★★★ 三星：${byStars[3] ?? 0}')
      ..writeln('★★★★ 四星：${byStars[4] ?? 0}')
      ..writeln('★★★★★ 五星：${byStars[5] ?? 0}')
      ..writeln()
      ..writeln('【章节分布】');
    if (byChapter.isEmpty) {
      buf.writeln('（暂无）');
    } else {
      for (final e in byChapter.entries) {
        buf.writeln('· ${e.key}：${e.value}');
      }
    }
    return buf.toString();
  }

  /// 查看指定 CG 详情（设定 7.5 /日记 [编号]）

  String _formatCgDetail(String id) {
    final cg = cgById(id);
    if (cg == null) {
      return '未找到 CG「$id」。可用编号见 /日记。';
    }
    final rec = player!.cgRecords[cg.id];
    if (rec == null) {
      return '【${cg.id} ${cg.name}】🔒 尚未解锁\n'
          '章节：${cg.chapter}｜等级：${cg.starText}\n'
          '解锁条件：${cg.conditionText}';
    }
    return '【${cg.id} ${cg.name}】${cg.starText}\n'
        '章节：${cg.chapter}\n'
        '解锁条件：${cg.conditionText}\n'
        '解锁于：${rec.unlockedDate}';
  }

  /// 重播指定 CG（精简版，设定 7.5 /日记 重播）

  String _replayCg(String id) {
    final cg = cgById(id);
    if (cg == null) {
      return '未找到 CG「$id」。可用编号见 /日记。';
    }
    final rec = player!.cgRecords[cg.id];
    if (rec == null) {
      return '【${cg.id} ${cg.name}】尚未解锁，无法重播。\n解锁条件：${cg.conditionText}';
    }
    return '【重播 · ${cg.name}】${cg.starText}\n\n'
        '—— 记忆被重新点亮。\n\n'
        '你仿佛又回到了那一刻：旧羊皮纸与蜡烛的气味在空气里浮动，远处的钟声在石墙之间低低回荡，而「${cg.name}」的画面，如月光一般温柔地重新铺展在你眼前。\n\n'
        '（${cg.chapter}）解锁于 ${rec.unlockedDate}';
  }

  String _formatArchive() {
    final p = player!;
    return '''【角色完整档案】
  姓名：${p.name}｜性别：${p.gender.isEmpty ? '未设定' : p.gender}
  生日：${p.birthDay ?? '未设定'}｜出生年份：${p.birthYear}
  血统：${bloodStatusLabel(p.bloodType)}｜出生地：${p.birthLocation}
  学院：${p.house ?? '未分院'}｜年级：${p.grade ?? 1}
  性取向：${p.sexOrientation ?? '未设定'}
  魔杖：${p.wandId != null ? wandById(p.wandId!)?.name ?? p.wandId : '未选择'}
  宠物：${p.petName ?? '无'}
  外貌：${p.appearance ?? '未设定'}
  家族背景：${p.familyBackground ?? '未设定'}
  童年经历：${p.childhoodExperiences.isEmpty ? '未设定' : p.childhoodExperiences.join('；')}
  信仰与价值观：${p.beliefs ?? '未设定'}
  初始天赋：${p.initialTalent ?? '未设定'}
  性格特质：${p.personalityTraits.isEmpty ? '未设定' : p.personalityTraits.join('、')}
  当前目标：${p.currentGoal ?? '无'}''';
  }

  String _formatAchievements() {
    final unlocked = player!.achievements;
    final catalog = achievementCatalog;
    final buf = StringBuffer('【成就】（${unlocked.length}/${catalog.length}）\n');
    for (final a in catalog) {
      final has = unlocked.contains(a.id);
      buf.writeln('${has ? '✅' : '🔒'} ${a.name}${has ? ' — ${a.description}' : ''}');
    }
    return buf.toString();
  }

  String _formatPet() {
    final p = player!;
    if (p.petId == null && p.petName == null) {
      // 以前这里让人「去对角巷挑选」，但商店里没宠物卖，是条死路。
      // 现在 /宠物 购买 真能买，把清单直接列出来。
      return '【宠物】\n你还没有宠物。\n\n${formatPetShop()}';
    }
    final def = p.petId != null ? petById(p.petId!) : null;
    // R8：使用 petNarrativeConfig 去除「九尾灵狐羁绊≥60 化形」硬编码
    final cfg = p.petId != null ? petNarrativeConfig(p.petId!) : null;
    final buf = StringBuffer('【宠物】\n');
    buf.writeln('名字：${p.petName ?? def?.name ?? '未命名'}');
    if (def != null) {
      buf.writeln('种类：${def.species}');
      buf.writeln('能力：${def.abilities.join('、')}');
      if (cfg != null && cfg.bondGatedTransform) {
        buf.writeln('特性：可化人形（羁绊≥${cfg.specialInteractionBondThreshold}后会触发人形互动）');
      } else if (def.canTransform) {
        buf.writeln('特性：可化人形');
      }
      buf.writeln('简介：${def.description.split('\n').first}');
    }
    buf.write('羁绊：${p.petBond}/100\n');
    buf.writeln('互动：/宠物 喂食 ｜ /宠物 玩耍 ｜ /宠物 训练（喂食每日一次，玩耍/训练每日共一次）');
    final canTransformHint = (cfg?.bondGatedTransform ?? false)
        ? '${def?.species ?? '特殊宠物'}在羁绊≥${cfg?.specialInteractionBondThreshold ?? 60} 时会化为人形。'
        : '特殊宠物会在羁绊达到阈值后触发专属互动。';
    buf.writeln('羁绊≥40 时宠物可在决斗/探险中助战；$canTransformHint');
    return buf.toString();
  }

  // ==================== 信件互动系统 ====================

  /// 处理 /信 系列子指令：读 / 回 / 寄
}
