/// 作弊指令子系统（阶段 r3-2 拆分自 mixin_commands.dart）。
///
/// 【拆分说明】/cheat 家族（注册、分发、20+ 子命令实现、帮助文本）约 1080 行，
/// 从 3600 行的 mixin_commands 迁入本文件。GameCommandsMixin 声明
/// on GameCommandCheatMixin（跨 mixin 走 on 链，遵守 ADR-001），GameProvider
/// 的 with 列表中 cheat 在 commands 之前。行为零变化：所有成员仍是
/// GameProvider 上的实例成员，测试契约不变。
library;

import 'dart:math';


import '../data/attribute_data.dart';
import '../data/collectible_data.dart';
import '../data/collection_data.dart';
import '../data/command_registry.dart';
import '../data/event_anchors.dart';
import '../data/bestiary_data.dart';
import '../data/memory_importance_config.dart';
import '../data/cg_data.dart';
import '../models/game_systems.dart';
import '../models/long_term_memory.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';
import '../utils/prompt_sanitizer.dart';

/// 作弊指令（debug/测试与「上帝模式」玩法共用）。挂在 GameProviderBase 上。
mixin GameCommandCheatMixin on GameProviderBase {
  // —— 作弊指令 ——
  void registerCheatCommands(CommandRegistry registry) {
    registry.registerAll([
      CommandDef(
        primary: 'cheat',
        group: '作弊',
        permission: 'cheat',
        helpText: '作弊指令总入口（好感/资源/声望/时间/骨科/舆论/解锁CG），详情见 /cheat',
        subs: [
          CommandSub('好感', '好感作弊'),
          CommandSub('资源', '资源作弊'),
          CommandSub('声望', '声望作弊'),
          CommandSub('时间', '时间作弊'),
          CommandSub('骨科', '骨科模式'),
          CommandSub('舆论', '舆论作弊'),
          CommandSub('解锁CG', '解锁全部 CG'),
        ],
        handler: (ctx) {
          final m = ctx.provider as GameCommandCheatMixin;
          m.handleCheat(ctx.parts);
          m.choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        },
      ),
    ]);
  }

  // —— 魔法世界图鉴（百科收集，见 data/collection_data.dart）——

  /// 图鉴面板：紧凑模式按 5 类列出已收录名与进度；详情模式逐条附说明。
  /// 禁林遭遇生物是独立系统（player.bestiary），面板底部只给进度指路。
  String formatCollectionPanel({bool detailed = false}) {
    final buf = StringBuffer(
      '【魔法世界图鉴】（已收录 ${collectionUnlocked.length}/${kCollectionCatalog.length}）\n',
    );
    if (collectionUnlocked.isEmpty) {
      buf.writeln(
        '\n图鉴还空着。你的每一段经历都会被它记下来——去上课、去冒险、'
        '去听见这个魔法世界，再回来翻看。',
      );
    } else if (!detailed) {
      for (final cat in kCollectionCategories) {
        final all =
            kCollectionCatalog.where((e) => e.category == cat).toList();
        final got =
            all.where((e) => collectionUnlocked.contains(e.id)).toList();
        buf.writeln(
          '\n◆ $cat（${got.length}/${all.length}）'
          '${got.isEmpty ? '：尚未收录' : '：${got.map((e) => e.name).join(' · ')}'}',
        );
      }
      buf.writeln('\n输入 /图鉴 详情 查看条目说明。');
    } else {
      for (final cat in kCollectionCategories) {
        final got = kCollectionCatalog
            .where(
              (e) => e.category == cat && collectionUnlocked.contains(e.id),
            )
            .toList();
        if (got.isEmpty) continue;
        buf.writeln('\n◆ $cat');
        for (final e in got) {
          buf.writeln('『${e.name}』${e.desc}');
        }
      }
      final missing = kCollectionCatalog.length - collectionUnlocked.length;
      if (missing > 0) {
        buf.writeln('\n还有 $missing 条未知条目等着你。继续生活，继续遇见。');
      }
    }
    buf.writeln(
      '\n—— 禁林遭遇：${player?.bestiary.length ?? 0}/${kCreatureCatalog.length} 种'
      '（/禁林 探险收录）',
    );
    return buf.toString();
  }

  void handleCheat(List<String> parts) {
    final p = player;
    if (p == null) return;
    if (parts.isEmpty) {
      currentNarrative = _formatCheatHelp();
      choices = [GameChoice(text: '返回', action: '继续')];
      return;
    }
    final sub = parts[0];

    switch (sub) {
      // ============ 8.1 基础作弊 ============
      case '属性':
      case '熟练度':
      case 'attr':
      case 'skill':
        _cheatAttribute(parts);
        break;
      case '加隆':
      case 'galleons':
        _cheatGalleons(parts);
        break;
      case '世界线':
      case 'worldline':
        _cheatWorldline(parts);
        break;
      case '知晓':
      case 'know':
        _cheatKnow(parts);
        break;
      case '剧情':
      case 'event':
        _cheatEvent(parts);
        break;
      case '无敌':
      case 'invincible':
        p.cheatInvincible = !p.cheatInvincible;
        currentNarrative = p.cheatInvincible
            ? '⚔️ 无敌模式开启：伤害与死亡结算对你失效。'
            : '⚔️ 无敌模式关闭。';
        break;
      case '全知':
      case 'omniscient':
        p.cheatOmniscient = !p.cheatOmniscient;
        currentNarrative = p.cheatOmniscient
            ? '👁️ 全知模式开启：查看档案将显示隐藏信息。'
            : '👁️ 全知模式关闭。';
        break;
      case '重置':
      case 'reset':
        _cheatReset();
        break;
      case '列表':
      case 'list':
        currentNarrative = _formatCheatHelp();
        break;

      // ============ 8.2 好感度与关系作弊 ============
      case '好感':
      case 'affection':
        _cheatAffection(parts);
        break;
      case '固定好感':
        _cheatLockAffection(parts);
        break;
      case '解锁CG':
      case 'cg':
        _cheatUnlockCg(parts);
        break;
      case '骨科':
        _cheatBone(parts);
        break;

      // ============ 8.3 拉郎配作弊 ============
      case '配对':
        _cheatPair(parts);
        break;

      // ============ 8.4 声望与收藏作弊 ============
      case '声望':
      case 'reputation':
        _cheatReputation(parts);
        break;
      case '舆论':
      case 'rumor':
        _cheatRumor(parts);
        break;
      case '收藏':
        _cheatCollectible(parts);
        break;
      case '成就':
        _cheatAchievement(parts);
        break;
      case '宠物':
        _cheatPet(parts);
        break;

      // ============ 8.5 新NPC作弊 ============
      case '新NPC':
        cheatNewNpc(parts);
        break;

      // ============ 兼容旧子命令 ============
      case '资源':
      case 'resources':
        _cheatResource(parts);
        break;
      case '时间':
      case 'time':
        _cheatTime(parts);
        break;

      default:
        currentNarrative = _formatCheatHelp();
    }
    choices = [GameChoice(text: '返回', action: '继续')];
  }

  /// 按关键词查找 NPC（先精确 id，再名字包含）。找不到返回 null。
  NPC? cheatFindNpc(String key) {
    if (key.isEmpty) return null;
    final direct = npcRegistry[key];
    if (direct != null) return direct;
    for (final n in npcRegistry.values) {
      if (n.name.contains(key) || n.aliases.any((a) => a.contains(key))) {
        return n;
      }
    }
    return null;
  }

  String cheatAllNpcNames() => npcRegistry.values.map((n) => n.name).join('、');

  // ---------- 8.1 基础作弊 ----------

  /// /cheat 熟练度 <技能名> <数值> —— 直接设定指定技能熟练度（0~100）
  void _cheatAttribute(List<String> parts) {
    final p = player!;
    if (parts.length < 3) {
      currentNarrative = '使用方式：/cheat 熟练度 <技能名> <0-100>，例如 /cheat 熟练度 魔药学 80';
      return;
    }
    final skillKey = parts[1];
    final value = int.tryParse(parts[2]);
    if (value == null) {
      currentNarrative = '数值必须是整数。';
      return;
    }
    // 属性键归一化：中文名/课程名 → 属性 key（权威表在 attribute_data）
    final resolved = _resolveAttrKey(skillKey);
    if (resolved == null) {
      currentNarrative =
          '未知技能「$skillKey」。可用：${kAttributeLabels.values.join('/')}。';
      return;
    }
    p.attributes[resolved] = value.clamp(0, 100);
    currentNarrative =
        '已将「${attributeLabel(resolved)}」熟练度设为 ${p.attributes[resolved]}。';
  }

  /// 属性 key 归一化：key / 中文名 / 课程名 → 属性 key。查不到返回 null。
  String? _resolveAttrKey(String input) {
    if (input.isEmpty) return null;
    if (Player.isAttributeKey(input)) return input;
    for (final e in kAttributeLabels.entries) {
      if (e.value == input ||
          e.value.contains(input) ||
          input.contains(e.value)) {
        return e.key;
      }
    }
    // 课程名别名（course_data 里的课程名 → 属性）
    const courseAliases = {
      '魔咒学': 'spell_understanding',
      '黑魔法防御术': 'dda',
      '魔法史': 'memory',
      '天文学': 'theory',
      '天文': 'theory',
      '魔药': 'potions',
      '飞行术': 'flying',
      '草药': 'herbology',
      '如尼文': 'memory',
      '算术占卜': 'logic',
      '占卜学': 'intuition',
    };
    return courseAliases[input];
  }

  /// /cheat 加隆 <数值> —— 增加/减少加隆数量
  void _cheatGalleons(List<String> parts) {
    final p = player!;
    if (parts.length < 2) {
      currentNarrative = '使用方式：/cheat 加隆 <数值>（负数扣钱）';
      return;
    }
    final amount = int.tryParse(parts[1]);
    if (amount == null) {
      currentNarrative = '数值必须是整数。';
      return;
    }
    p.galleons = (p.galleons + amount).clamp(0, 999999);
    currentNarrative = '💰 加隆余额：${p.galleons}（+$amount）';
  }

  /// /cheat 世界线 <数值> —— 直接调整世界线变动率（0~100）
  void _cheatWorldline(List<String> parts) {
    final p = player!;
    if (parts.length < 2) {
      currentNarrative = '使用方式：/cheat 世界线 <0-100>，例如 /cheat 世界线 35';
      return;
    }
    final value = int.tryParse(parts[1]);
    if (value == null) {
      currentNarrative = '数值必须是整数（0~100）。';
      return;
    }
    p.worldLineDeviation = (value.clamp(0, 100) / 100).toDouble();
    currentNarrative =
        '🌍 世界线变动率已设为 ${(p.worldLineDeviation * 100).toStringAsFixed(0)}%。';
  }

  /// /cheat 知晓 <秘密内容> —— 强制知晓一个隐藏秘密（写入永不遗忘层）
  void _cheatKnow(List<String> parts) {
    if (parts.length < 2) {
      currentNarrative = '使用方式：/cheat 知晓 <秘密内容>，例如 /cheat 知晓 斯内普是凤凰社的人';
      return;
    }
    final secret = PromptSanitizer.sanitize(parts.sublist(1).join(' '));
    if (secret.isEmpty) {
      currentNarrative = '输入内容为空或全为无效字符，未写入。';
      return;
    }
    final ts = worldState.time.format();
    memory = memory.addKeyFact(
      KeyFactRecord(
        id: 'cheat_secret_${DateTime.now().millisecondsSinceEpoch}',
        fact: '主角已得知一个秘密：$secret。',
        importance: kImportanceCheatSecret,
        timestamp: ts,
        category: 'secret',
      ),
    );
    worldState.addNarrativeEvent('🔍 你知晓了一个隐藏秘密（作弊）', turn: turnCount);
    currentNarrative = '🔍 你已强制知晓：$secret\n（已写入永不遗忘层，AI 不会再把你当不知情者。）';
  }

  /// /cheat 剧情 <事件关键词> —— 直接触发指定剧情事件（事件锚点）
  void _cheatEvent(List<String> parts) {
    if (parts.length < 2) {
      currentNarrative = '使用方式：/cheat 剧情 <事件关键词>，例如 /cheat 剧情 魁地奇';
      return;
    }
    final keyword = parts.sublist(1).join(' ');
    final matches = eventAnchors
        .where(
          (a) => a.title.contains(keyword) || a.directive.contains(keyword),
        )
        .toList();
    if (matches.isEmpty) {
      final titles = eventAnchors
          .map((a) => a.title)
          .toSet()
          .take(12)
          .join('、');
      currentNarrative = '未找到匹配「$keyword」的剧情事件。可尝试关键词：$titles……';
      return;
    }
    final anchor = matches.first;
    pendingAnchorDirective = anchor.directive;
    worldState.addNarrativeEvent(
      '⚡ 已强制触发剧情：${anchor.title}（作弊）',
      turn: turnCount,
    );
    currentNarrative =
        '⚡ 已强制触发剧情事件：「${anchor.title}」\n'
        '接下来的剧情将围绕它展开。\n\n（若同时匹配多个事件，已取第一条；'
        '共匹配 ${matches.length} 条）';
  }

  /// /cheat 重置 —— 重置所有作弊修改（开关类 + 锁定类 + 配对修改）
  void _cheatReset() {
    final p = player!;
    var restored = <String>[];
    // 解除所有好感锁定
    for (final n in npcRegistry.values) {
      if (n.affectionLocked) {
        n.affectionLocked = false;
        restored.add('解除锁定：${n.name}');
      }
    }
    // 恢复被修改过的性取向
    if (p.cheatOrientationBackup.isNotEmpty) {
      p.cheatOrientationBackup.forEach((name, original) {
        final npc = cheatFindNpc(name);
        if (npc != null) {
          npc.sexOrientation = original;
          restored.add('恢复取向：$name');
        }
      });
      p.cheatOrientationBackup.clear();
    }
    // 重置被修改过的配对好感（清掉作弊写入的 NPC 间好感）
    for (final pairKey in p.cheatModifiedPairs) {
      final parts2 = pairKey.split('|');
      if (parts2.length == 2) {
        final a = npcRegistry.values
            .where((n) => n.name == parts2[0])
            .firstOrNull;
        final b = npcRegistry.values
            .where((n) => n.name == parts2[1])
            .firstOrNull;
        if (a != null && b != null) {
          a.relationships.remove(b.id);
          b.relationships.remove(a.id);
          restored.add('重置配对：${a.name} × ${b.name}');
        }
      }
    }
    p.cheatModifiedPairs.clear();
    // 关闭开关
    if (p.cheatInvincible) {
      p.cheatInvincible = false;
      restored.add('关闭无敌模式');
    }
    if (p.cheatOmniscient) {
      p.cheatOmniscient = false;
      restored.add('关闭全知模式');
    }
    currentNarrative = restored.isEmpty
        ? '当前没有任何作弊修改需要重置。'
        : '【作弊重置完成】\n${restored.join('\n')}\n\n'
              '（注：属性/加隆/声望/世界线等数值型调整不可逆，不属于重置范围；'
              '如需恢复请手动调整回来。）';
  }

  // ---------- 8.2 好感度与关系作弊 ----------

  /// `/cheat 好感 <NPC名> <数值>` —— 调整好感度
  void _cheatAffection(List<String> parts) {
    if (parts.length >= 3) {
      final npc = cheatFindNpc(parts[1]);
      if (npc == null) {
        currentNarrative = '未找到NPC "${parts[1]}"。可用：${cheatAllNpcNames()}';
        return;
      }
      final delta = int.tryParse(parts[2]);
      if (delta != null) {
        npc.affection = (npc.affection + delta).clamp(-100, 100);
        if (npc.affection > npc.maxAffectionReached) {
          npc.maxAffectionReached = npc.affection;
        }
        syncRelationshipLevel(npc);
        checkAffectionAchievements(npc);
        notifyListeners();
        currentNarrative =
            '已调整「${npc.name}」的好感度：${npc.affection}（${npc.affectionStage}）';
      } else {
        currentNarrative = '数值必须是整数。';
      }
    } else {
      currentNarrative = '使用方式：/cheat 好感 <NPC名> <数值>';
    }
  }

  /// `/cheat 固定好感 <NPC名>` —— 锁定该 NPC 好感（再输一次解锁）
  void _cheatLockAffection(List<String> parts) {
    if (parts.length < 2) {
      currentNarrative = '使用方式：/cheat 固定好感 <NPC名>';
      return;
    }
    final npc = cheatFindNpc(parts[1]);
    if (npc == null) {
      currentNarrative = '未找到NPC "${parts[1]}"。可用：${cheatAllNpcNames()}';
      return;
    }
    npc.affectionLocked = !npc.affectionLocked;
    currentNarrative = npc.affectionLocked
        ? '🔒 「${npc.name}」的好感已固定为 ${npc.affection}：'
              '衰减/背叛/送礼/事件都不会再改变它。'
        : '🔓 「${npc.name}」的好感锁定已解除。';
  }

  /// `/cheat 解锁CG <CG编号>` —— 直接解锁指定CG
  void _cheatUnlockCg(List<String> parts) {
    if (parts.length >= 2) {
      final cg = cgById(parts[1]);
      if (cg != null) {
        unlockCG(cg);
        currentNarrative = '已解锁 CG：${cg.name}';
      } else {
        currentNarrative =
            '未找到该 CG，可用：${allCgs().map((c) => c.id).take(10).join(', ')}...';
      }
    } else {
      currentNarrative = '使用方式：/cheat 解锁CG <CG编号>';
    }
  }

  /// /cheat 骨科 无视 / /cheat 骨科 恢复
  void _cheatBone(List<String> parts) {
    final p = player!;
    if (parts.length >= 2 && (parts[1] == '无视' || parts[1] == '开启')) {
      p.boneMode = true;
      unlockAchievement('bone_mode');
      notifications.add('⚠️ 骨科模式已开启：禁忌的大门已为你敞开');
      worldState.addNarrativeEvent('⚠️ 骨科模式已开启：禁忌限制解除', turn: turnCount);
      bumpImpactScore(0.1, debugReason: '开启骨科模式(世界线剧烈扰动)');
      currentNarrative = '【骨科模式已开启】三代内血亲的禁忌限制已解除，但这意味着你的选择将付出更沉重的代价。';
    } else if (parts.length >= 2 && (parts[1] == '恢复' || parts[1] == '关闭')) {
      p.boneMode = false;
      currentNarrative = '【骨科模式已关闭】血缘限制已恢复。';
    } else {
      currentNarrative = '使用方式：/cheat 骨科 无视（开启）｜/cheat 骨科 恢复（关闭）';
    }
  }

  // ---------- 8.3 拉郎配作弊 ----------

  /// /cheat 配对 <子命令>：好感 / 关系 / 重置 / 查看 / 性取向 / 列表
  void _cheatPair(List<String> parts) {
    if (parts.length < 2) {
      currentNarrative =
          '【配对作弊】\n'
          '  /cheat 配对 好感 <NPC1> <NPC2> <数值>\n'
          '  /cheat 配对 关系 <NPC1> <NPC2> <阶段>（陌生/认识/朋友/暧昧/恋爱/深爱）\n'
          '  /cheat 配对 重置 <NPC1> <NPC2>\n'
          '  /cheat 配对 查看 <NPC1> <NPC2>\n'
          '  /cheat 配对 性取向 <NPC名> <男|女|双性>\n'
          '  /cheat 配对 性取向 重置 <NPC名>\n'
          '  /cheat 配对 列表';
      return;
    }
    final cmd = parts[1];
    final p = player!;
    switch (cmd) {
      case '好感':
        if (parts.length >= 5) {
          final a = cheatFindNpc(parts[2]);
          final b = cheatFindNpc(parts[3]);
          final value = int.tryParse(parts[4]);
          if (a == null || b == null) {
            currentNarrative = '未找到NPC，请检查名字。';
            return;
          }
          if (value == null) {
            currentNarrative = '数值必须是整数（-100~100）。';
            return;
          }
          final v = value.clamp(-100, 100);
          a.relationships[b.id] = v;
          b.relationships[a.id] = v;
          p.cheatModifiedPairs.add(ShipRecord.keyOf(a.name, b.name));
          currentNarrative = '已设置 ${a.name} × ${b.name} 的互有好感：$v';
        } else {
          currentNarrative = '使用方式：/cheat 配对 好感 <NPC1> <NPC2> <数值>';
        }
        break;
      case '关系':
        if (parts.length >= 5) {
          final a = cheatFindNpc(parts[2]);
          final b = cheatFindNpc(parts[3]);
          final stageName = parts[4];
          const stageMap = {
            '陌生': 0,
            '认识': 20,
            '朋友': 45,
            '暧昧': 65,
            '恋爱': 80,
            '深爱': 95,
          };
          final v = stageMap[stageName];
          if (a == null || b == null) {
            currentNarrative = '未找到NPC，请检查名字。';
            return;
          }
          if (v == null) {
            currentNarrative = '阶段必须是：陌生/认识/朋友/暧昧/恋爱/深爱。';
            return;
          }
          a.relationships[b.id] = v;
          b.relationships[a.id] = v;
          p.cheatModifiedPairs.add(ShipRecord.keyOf(a.name, b.name));
          currentNarrative =
              '已设置 ${a.name} × ${b.name} 的关系阶段：「$stageName」（好感 $v）';
        } else {
          currentNarrative = '使用方式：/cheat 配对 关系 <NPC1> <NPC2> <阶段>';
        }
        break;
      case '重置':
        if (parts.length >= 4) {
          final a = cheatFindNpc(parts[2]);
          final b = cheatFindNpc(parts[3]);
          if (a == null || b == null) {
            currentNarrative = '未找到NPC，请检查名字。';
            return;
          }
          a.relationships.remove(b.id);
          b.relationships.remove(a.id);
          currentNarrative = '已重置 ${a.name} × ${b.name} 的互有好感。';
        } else {
          currentNarrative = '使用方式：/cheat 配对 重置 <NPC1> <NPC2>';
        }
        break;
      case '查看':
        if (parts.length >= 4) {
          final a = cheatFindNpc(parts[2]);
          final b = cheatFindNpc(parts[3]);
          if (a == null || b == null) {
            currentNarrative = '未找到NPC，请检查名字。';
            return;
          }
          final ab = a.relationships[b.id];
          final ba = b.relationships[a.id];
          currentNarrative =
              '【配对状态】${a.name} × ${b.name}\n'
              '· ${a.name} 对 ${b.name}：${ab ?? 0}\n'
              '· ${b.name} 对 ${a.name}：${ba ?? 0}';
        } else {
          currentNarrative = '使用方式：/cheat 配对 查看 <NPC1> <NPC2>';
        }
        break;
      case '性取向':
        if (parts.length >= 4 && parts[2] == '重置') {
          final npc = cheatFindNpc(parts[3]);
          if (npc == null) {
            currentNarrative = '未找到NPC "${parts[3]}"。';
            return;
          }
          final original = p.cheatOrientationBackup.remove(npc.name);
          if (original != null) {
            npc.sexOrientation = original;
            currentNarrative = '已恢复「${npc.name}」的默认性取向：$original';
          } else {
            currentNarrative = '「${npc.name}」没有被修改过性取向，无需重置。';
          }
          return;
        }
        if (parts.length >= 4) {
          final npc = cheatFindNpc(parts[2]);
          final type = parts[3];
          if (npc == null) {
            currentNarrative = '未找到NPC "${parts[2]}"。';
            return;
          }
          if (!['男', '女', '双性'].contains(type)) {
            currentNarrative = '性取向必须是：男 / 女 / 双性。';
            return;
          }
          p.cheatOrientationBackup.putIfAbsent(
            npc.name,
            () => npc.sexOrientation ?? '',
          );
          npc.sexOrientation = type;
          currentNarrative = '已修改「${npc.name}」的性取向：$type';
        } else {
          currentNarrative = '使用方式：/cheat 配对 性取向 <NPC名> <男|女|双性>';
        }
        break;
      case '列表':
        final pairs = p.cheatModifiedPairs.map((k) {
          final parts2 = k.split('|');
          if (parts2.length == 2) {
            final a = npcRegistry.values
                .where((n) => n.name == parts2[0])
                .firstOrNull;
            final b = npcRegistry.values
                .where((n) => n.name == parts2[1])
                .firstOrNull;
            if (a != null && b != null) {
              return '· ${a.name} × ${b.name}：${a.relationships[b.id] ?? 0}';
            }
          }
          return '· $k';
        }).toList();
        currentNarrative = pairs.isEmpty
            ? '【被修改过的配对】\n暂无——还没有用配对作弊改过任何关系。'
            : '【被修改过的配对】\n${pairs.join('\n')}';
        break;
      default:
        currentNarrative = '未知配对子命令「$cmd」，输入 /cheat 配对 查看全部用法。';
    }
  }

  // ---------- 8.4 声望与收藏作弊 ----------

  /// `/cheat 声望 <数值> <维度>` ｜ `/cheat 声望 NPC <NPC名> <维度> <数值>` ｜ `/cheat 声望 NPC 重置 <NPC名>`
  void _cheatReputation(List<String> parts) {
    final p = player!;
    if (parts.length >= 2 && parts[1] == 'NPC') {
      // NPC 声望作弊
      if (parts.length >= 3 && parts[2] == '重置') {
        if (parts.length >= 4) {
          final npc = cheatFindNpc(parts[3]);
          if (npc == null) {
            currentNarrative = '未找到NPC "${parts[3]}"。';
            return;
          }
          npc.reputation = Reputation(
            academic: 25,
            social: 25,
            combat: 20,
            moral: 30,
            leadership: 20,
            dark: 10,
          );
          currentNarrative = '已重置「${npc.name}」的声望至默认值。';
        } else {
          currentNarrative = '使用方式：/cheat 声望 NPC 重置 <NPC名>';
        }
        return;
      }
      if (parts.length >= 5) {
        final npc = cheatFindNpc(parts[2]);
        final value = int.tryParse(parts[4]);
        if (npc == null) {
          currentNarrative = '未找到NPC "${parts[2]}"。';
          return;
        }
        if (value == null) {
          currentNarrative = '数值必须是整数。';
          return;
        }
        npc.reputation.add(parts[3], value);
        currentNarrative =
            '「${npc.name}」的${npc.reputation.labelOf(parts[3])}：'
            '${npc.reputation.get(parts[3])}';
      } else {
        currentNarrative =
            '使用方式：/cheat 声望 NPC <NPC名> <维度> <数值>（维度：academic、social、combat、moral、leadership、dark）';
      }
      return;
    }
    if (parts.length >= 3) {
      final amount = int.tryParse(parts[1]) ?? 0;
      p.playerReputation.add(parts[2], amount);
      currentNarrative =
          '${p.playerReputation.labelOf(parts[2])} ${p.playerReputation.get(parts[2])}';
    } else {
      currentNarrative =
          '使用方式：/cheat 声望 <数值> <academic|social|combat|moral|leadership|dark>';
    }
  }

  /// /cheat 舆论 清除 <关键词> ｜ /cheat 舆论 重置
  void _cheatRumor(List<String> parts) {
    final p = player!;
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
  }

  /// /cheat 收藏 <物品名或id> —— 添加指定物品到收藏
  void _cheatCollectible(List<String> parts) {
    final p = player!;
    if (parts.length < 2) {
      currentNarrative = '使用方式：/cheat 收藏 <物品名或id>，例如 /cheat 收藏 巧克力蛙';
      return;
    }
    final key = parts.sublist(1).join(' ');
    CollectibleDef? def;
    for (final c in kCollectibleCatalog) {
      if (c.id == key || c.name == key || c.name.contains(key)) {
        def = c;
        break;
      }
    }
    if (def == null) {
      currentNarrative = '未找到收藏品「$key」。可输入 /cheat 收藏 列表 查看全部。';
      return;
    }
    if (p.collection.contains(def.id)) {
      currentNarrative = '该收藏品已在收藏册中：${def.name}';
      return;
    }
    p.collection.add(def.id);
    currentNarrative =
        '📖 已将「${def.name}」加入收藏册（${def.series}·${def.starText}）。';
  }

  /// /cheat 成就 <成就名> —— 解锁指定成就
  void _cheatAchievement(List<String> parts) {
    if (parts.length < 2) {
      currentNarrative = '使用方式：/cheat 成就 <成就名>，例如 /cheat 成就 分院仪式';
      return;
    }
    final key = parts.sublist(1).join(' ');
    Achievement? def;
    for (final a in achievementCatalog) {
      if (a.id == key || a.name == key || a.name.contains(key)) {
        def = a;
        break;
      }
    }
    if (def == null) {
      currentNarrative = '未找到成就「$key」。';
      return;
    }
    unlockAchievement(def.id);
    currentNarrative = '🏆 已解锁成就：${def.name}';
  }

  /// /cheat 宠物 羁绊 <数值>
  void _cheatPet(List<String> parts) {
    final p = player!;
    if (parts.length >= 3 && parts[1] == '羁绊') {
      final value = int.tryParse(parts[2]);
      if (value == null) {
        currentNarrative = '数值必须是整数。';
        return;
      }
      p.petBond = value.clamp(0, 100);
      currentNarrative = '🐾 宠物羁绊已设为 ${p.petBond}/100';
    } else {
      currentNarrative = '使用方式：/cheat 宠物 羁绊 <0-100>';
    }
  }

  // ---------- 8.5 新NPC作弊 ----------

  /// /cheat 新NPC 生成 ｜ /cheat 新NPC 好感 <全名> <数值> ｜ /cheat 新NPC 删除 <全名>
  void cheatNewNpc(List<String> parts) {
    final p = player!;
    if (parts.length < 2) {
      currentNarrative =
          '【新NPC作弊】\n'
          '  /cheat 新NPC 生成 — 强制生成一位新NPC\n'
          '  /cheat 新NPC 好感 <全名> <数值>\n'
          '  /cheat 新NPC 删除 <全名>（不可逆）';
      return;
    }
    switch (parts[1]) {
      case '生成':
        // 作弊强制生成：先清空本学年计数绕过上限
        npcGeneratedThisSchoolYear = 0;
        generateNewNPC();
        currentNarrative = '（作弊强制生成）$currentNarrative';
        break;
      case '好感':
        if (parts.length >= 4) {
          final npc = cheatFindNpc(parts[2]);
          final value = int.tryParse(parts[3]);
          if (npc == null) {
            currentNarrative = '未找到NPC "${parts[2]}"。';
            return;
          }
          if (value == null) {
            currentNarrative = '数值必须是整数。';
            return;
          }
          npc.affection = value.clamp(-100, 100);
          if (npc.affection > npc.maxAffectionReached) {
            npc.maxAffectionReached = npc.affection;
          }
          syncRelationshipLevel(npc);
          currentNarrative =
              '已将「${npc.name}」的好感设为 ${npc.affection}（${npc.affectionStage}）';
        } else {
          currentNarrative = '使用方式：/cheat 新NPC 好感 <全名> <数值>';
        }
        break;
      case '删除':
        if (parts.length >= 3) {
          final npc = cheatFindNpc(parts[2]);
          if (npc == null) {
            currentNarrative = '未找到NPC "${parts[2]}"。';
            return;
          }
          npcRegistry.remove(npc.id);
          p.relationships.remove(npc.id);
          currentNarrative = '🗑️ 已删除NPC：${npc.name}（不可逆）。';
        } else {
          currentNarrative = '使用方式：/cheat 新NPC 删除 <全名>';
        }
        break;
      default:
        currentNarrative = '未知新NPC子命令「${parts[1]}」。';
    }
  }

  // ---------- 兼容旧子命令 ----------

  /// /cheat 资源 <数值> <魔力|精神力|饱食|精力|生命>
  void _cheatResource(List<String> parts) {
    final p = player!;
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
    } else {
      currentNarrative = '使用方式：/cheat 资源 <数值> <魔力|精神力|饱食|精力|生命>';
    }
  }

  /// /cheat 时间 <天数>
  void _cheatTime(List<String> parts) {
    if (parts.length >= 2) {
      final raw = int.tryParse(parts[1]);
      // BUG-FIX: 天数无上限时 fastForwardTime 按天循环，超大值会冻结主线程，
      // 与 resolveFastForwardDays 的上限对齐（最多 365 天）。
      final days = raw == null ? null : min(raw.abs(), 365);
      if (days != null) fastForwardTime(days);
      currentNarrative = '时间已推进 $days 天。\n${worldState.timestamp}';
    } else {
      currentNarrative = '使用方式：/cheat 时间 <天数>';
    }
  }

  String _formatCheatHelp() {
    return '''【作弊指令】（框架1 · 第八部分完整版）

━━━ 8.1 基础作弊 ━━━
  /cheat 熟练度 <技能名> <0-100>  调整技能熟练度（魔药学/变形术/飞行…）
  /cheat 属性 <技能名> <0-100>    同上（别名）
  /cheat 加隆 <数值>             增加/减少加隆
  /cheat 资源 <数值> <魔力|精神力|饱食|精力|生命>
  /cheat 时间 <天数>             跳转时间
  /cheat 世界线 <0-100>          直接调整世界线变动率
  /cheat 知晓 <秘密内容>         强制知晓一个隐藏秘密
  /cheat 剧情 <事件关键词>       直接触发剧情事件（如：魁地奇、O.W.L）
  /cheat 无敌                    无敌模式开关
  /cheat 全知                    全知模式开关（查看档案显示隐藏信息）
  /cheat 重置                    重置所有开关类/锁定类作弊修改
  /cheat 列表                    显示本列表

━━━ 8.2 好感度与关系作弊 ━━━
  /cheat 好感 <NPC名> <数值>     调整好感度
  /cheat 固定好感 <NPC名>        锁定好感（再输一次解锁，多人惩罚免疫）
  /cheat 解锁CG <CG编号>         直接解锁CG
  /cheat 骨科 无视               开启骨科模式（无视血缘限制）
  /cheat 骨科 恢复               关闭骨科模式

━━━ 8.3 拉郎配作弊 ━━━
  /cheat 配对 好感 <NPC1> <NPC2> <数值>
  /cheat 配对 关系 <NPC1> <NPC2> <阶段>  （陌生/认识/朋友/暧昧/恋爱/深爱）
  /cheat 配对 重置 <NPC1> <NPC2>
  /cheat 配对 查看 <NPC1> <NPC2>
  /cheat 配对 性取向 <NPC名> <男|女|双性>
  /cheat 配对 性取向 重置 <NPC名>
  /cheat 配对 列表

━━━ 8.4 声望与收藏作弊 ━━━
  /cheat 声望 <数值> <维度>      维度：academic、social、combat、moral、leadership、dark
  /cheat 声望 NPC <NPC名> <维度> <数值>
  /cheat 声望 NPC 重置 <NPC名>
  /cheat 舆论 清除 <关键词>      清除指定传闻
  /cheat 舆论 重置               重置所有舆论
  /cheat 收藏 <物品名>           添加收藏品
  /cheat 成就 <成就名>           解锁成就
  /cheat 宠物 羁绊 <0-100>       调整宠物羁绊

━━━ 8.5 新NPC作弊 ━━━
  /cheat 新NPC 生成              强制生成一位新NPC
  /cheat 新NPC 好感 <全名> <数值>
  /cheat 新NPC 删除 <全名>       删除新NPC（不可逆）''';
  }

  // ==================== 生成新NPC（增强版：多人格+多样化） ====================
}
