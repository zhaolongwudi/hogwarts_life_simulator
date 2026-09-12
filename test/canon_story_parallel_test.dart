/// 剧情模式 × 原著时间线的平行世界守卫。
///
/// 【这个文件守什么】剧情模式的目标是「让玩家以原创角色身份亲历原著年份」，
/// 它有三类一旦写崩就很难在运行时发现的问题，全部在内容层钉死：
///
///   1. **玩家即主角**（最致命）：剧情文本一旦写成「你杀死了蛇怪」「你下了
///      活板门」，平行世界的根基就塌了——玩家是原创角色，原著大事必须由
///      原著人物完成。用禁用措辞扫描守住。
///   2. **原著节点漏讲**：canon_events 里属于某本书的节点必须全部被那本书
///      的剧情步声明讲述（canonRefId）。漏一个，玩家就"跳过了一段原著"。
///   3. **幽灵引用/幽灵 flag/幽灵物品**：canonRefId、requireFlag、addItems、
///      targetNpcId 指向不存在的东西时，症状都在很远的地方
///      （选项永远不出现 / 背包出现乱名物品 / 好感加给了空气）。
///
/// 【为什么不用运行时检查】内容是 const 表，构建期扫描一次的成本是零；
/// 而运行时检查每个选项的存在性会让每个回合都多出几百次字典查找。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/canon_events.dart';
import 'package:hogwarts_life_simulator/data/item_data.dart';
import 'package:hogwarts_life_simulator/data/npc_data.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/models/story_progress.dart';

/// 剧情模式挂 harry_same 时代——targetNpcId 必须是该时代真正登场的 NPC。
final Set<String> _harrySameNpcIds = {
  for (final s in eraNpcSeeds['harry_same'] ?? const <NpcSeed>[]) s.id,
};

/// 剧情物品白名单：不在物品目录里、但故意作为剧情纪念品发放的物品。
///
/// 【为什么要白名单】`_applyStoryEffect` 对查不到的物品名会兜底落包
/// （type=「剧情」），所以英文 id、错别字都不会崩——但玩家会看到一个
/// 乱名物品。白名单把「故意不走目录」的剧情物品显式登记，
/// 其余一律要求在 `item_data.dart` 的目录里有真名。
const Set<String> _storyItemWhitelist = {'霍格沃茨的来信'};

/// 一步剧情的全部可见文本（禁用措辞 / 主体检查的语料）。
List<String> _corpusOf(StoryStepDef s) => [
  s.setup,
  if (s.onEnterText != null) s.onEnterText!,
  ...s.ambient,
  for (final c in s.choices) c.text,
  for (final c in s.choices) c.consequence,
];

void main() {
  setUpAll(registerAllStoryBooks);

  group('A · 禁用措辞扫描（玩家必须是原创角色）', () {
    /// 「玩家即哈利」的禁用措辞——出现任何一条，平行世界原则即被破坏。
    ///
    /// 【词表怎么长】按"玩家替代了原著里某人的戏剧位"逐条积累：
    /// 身份类（波特/德思礼/救世主）、身体特征类（伤疤）、
    /// 原著高光动作类（下活板门/与奇洛对峙/喝独角兽的血）、
    /// 原著特权类（一年级进魁地奇队）。新内容写崩一次，就在这里加一条。
    const forbidden = <String>[
      // —— 身份类：玩家不是哈利·波特 ——
      '你是哈利',
      '你，哈利',
      '你姓波特',
      '你的父母是波特',
      '德思礼',
      '救世主的你',
      '你是救世主',
      '作为救世主',
      // —— 身体特征类 ——
      '你的伤疤',
      '你额上的闪电',
      '闪电形伤疤',
      // —— 家庭背景类：玩家的家庭是自己选的 ——
      '你住在女贞路4号',
      '你住在储物间',
      '你的姨妈是佩妮',
      // —— 原著高光动作类：这些事是原著人物做的 ——
      '你杀死了蛇怪',
      '你举起了魔杖对着蛇怪',
      '你下了活板门',
      '你钻进了活板门',
      '你与奇洛对峙',
      '你摘下了头巾',
      '你喝下了独角兽的血',
      '你饮下了独角兽的血',
      '你与伏地魔',
      '你面对了伏地魔',
      // —— 原著特权类 ——
      '你进了魁地奇队',
      '你成为了找球手',
      '你骑着扫帚追金色飞贼',
      '你拿到了分院帽的',
    ];

    test('全部步的可见文本不含禁用措辞', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            final corpus = _corpusOf(s).join('\n');
            for (final bad in forbidden) {
              expect(
                corpus.contains(bad),
                isFalse,
                reason: '步 ${s.id} 出现「玩家即主角」措辞：$bad',
              );
            }
          }
        }
      }
    });

    test('结局文本同样不含禁用措辞', () {
      const forbiddenInEnding = <String>[
        '你是哈利',
        '救世主的你',
        '你杀死了伏地魔',
        '德思礼',
        '你的伤疤',
      ];
      for (final book in kStoryBooks.values) {
        for (final e in book.endings) {
          final corpus = '${e.title}\n${e.body}';
          for (final bad in forbiddenInEnding) {
            expect(
              corpus.contains(bad),
              isFalse,
              reason: '结局 ${e.id} 出现禁用措辞：$bad',
            );
          }
        }
      }
    });

    test('章名不含禁用措辞（章名会出现在章节抬头里）', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          expect(ch.title.contains('德思礼'), isFalse, reason: '章 ${ch.id}');
        }
      }
    });
  });

  group('B · 原著关键场景的第三方主体检查', () {
    /// 提到这些场景时，文本里必须同时出现一个第三方行为主体——
    /// 否则极容易写成「你饮下了独角兽的血」这类玩家替代原著人物的句子。
    ///
    /// 【为什么只检查"出现即要求主体"而不逐句判断】
    /// const 文本没法真正理解语义；但"这一步里提到了 X 场景却没有
    /// 任何原著人物在场"几乎必然意味着场景被错误地安在了玩家头上。
    const keyScenes = <String>{
      '独角兽的血', // 饮血者是奇洛/伏地魔
      '活板门', // 下去的是三人组
      '三头狗', // 看门与收服的是教工/三人组
      '找球手', // 哈利的戏剧位
      '魔法石', // 争夺战是哈利/邓布利多
      '厄里斯', // 镜前的执念叙事属于哈利
    };

    /// 第三方主体信号——出现任何一个即视为"原著人物在场"。
    const subjSignals = <String>[
      '有人', '某人', '别人', '他人', '谁',
      '他', '她', '他们', '她们',
      '那身影', '那道身影', '影子', '黑袍',
      '奇洛', '斯内普', '海格', '邓布利多', '麦格', '费尔奇', '马尔福',
      '级长', '教授', '校长', '妖精', '傲罗', '帽子', '猎犬', '警卫',
      '男孩', '女孩', '同学', '学生', '家长', '奶奶', '母亲', '养母', '养父',
      '一年级生', '高年级', '三人', '几个人',
    ];

    test('提到关键场景的步必须同时有第三方主体', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            final corpus = _corpusOf(s).join('\n');
            for (final scene in keyScenes) {
              if (!corpus.contains(scene)) continue;
              final hasSubject = subjSignals.any(corpus.contains);
              expect(
                hasSubject,
                isTrue,
                reason:
                    '步 ${s.id} 提到原著关键场景「$scene」却没有第三方行为主体'
                    '（原著人物没在场）——这段场景极可能被错误地安在了玩家头上',
              );
            }
          }
        }
      }
    });
  });

  group('C · 章节骨架（内容规模下限）', () {
    test('每章至少 2 步（一步撑不起一章的选择弧）', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          expect(
            ch.steps.length >= 2,
            isTrue,
            reason: '章 ${ch.id} 只有 ${ch.steps.length} 步',
          );
        }
      }
    });

    test('每章至少 4 个选择点（2 步 × 2 分支）', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          final choiceCount =
              ch.steps.fold<int>(0, (n, s) => n + s.choices.length);
          expect(
            choiceCount >= 4,
            isTrue,
            reason: '章 ${ch.id} 只有 $choiceCount 个选择点',
          );
        }
      }
    });

    test('《魔法石》全书规模达标（防止内容被误删后测试静默通过）', () {
      final book = findStoryBook('ps')!;
      expect(book.chapters.length, 9, reason: '九个章节');
      final steps = book.chapters.fold<int>(0, (n, c) => n + c.steps.length);
      expect(steps, 26, reason: '全书 26 步');
      final choices = book.chapters.fold<int>(
        0,
        (n, c) => n + c.steps.fold<int>(0, (m, s) => m + s.choices.length),
      );
      expect(choices, greaterThanOrEqualTo(45), reason: '至少 45 个选择点');
    });
  });

  group('D · canon 节点全覆盖（不许跳过任何一段原著）', () {
    test('canonRefId 必须真实存在于 canon_events 表（幽灵引用直接失败）', () {
      final ids = canonEvents.map((e) => e.id).toSet();
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            final ref = s.canonRefId;
            if (ref == null) continue;
            expect(
              ids.contains(ref),
              isTrue,
              reason:
                  '步 ${s.id} 的 canonRefId「$ref」在 canon_events 里不存在'
                  '——批次 5 的白名单抑制按 id 精确匹配，幽灵引用等于没声明',
            );
          }
        }
      }
    });

    test('每本书对应前缀的原著节点全部被该书剧情声明讲述', () {
      for (final book in kStoryBooks.values) {
        final prefix = 'canon_${book.id}_';
        final covered = <String>{
          for (final ch in book.chapters)
            for (final s in ch.steps)
              if (s.canonRefId != null) s.canonRefId!,
        };
        final expected = canonEvents
            .where((e) => e.id.startsWith(prefix))
            .map((e) => e.id)
            .toSet();
        expect(
          covered,
          containsAll(expected),
          reason:
              '书 ${book.id} 有原著节点没被剧情讲述：'
              '${expected.difference(covered)}——玩家会"跳过"这段原著',
        );
      }
    });

    test('《魔法石》的 7 个原著节点各被声明且不重复声明', () {
      final book = findStoryBook('ps')!;
      final refs = <String>[
        for (final ch in book.chapters)
          for (final s in ch.steps)
            if (s.canonRefId != null) s.canonRefId!,
      ];
      expect(refs, hasLength(7), reason: '7 个节点 = 7 次声明');
      expect(refs.toSet(), hasLength(refs.length), reason: '不允许重复声明');
      expect(
        refs,
        containsAll(const [
          'canon_ps_gringotts',
          'canon_ps_sorting',
          'canon_ps_troll',
          'canon_ps_quidditch_first',
          'canon_ps_christmas_mirror',
          'canon_ps_forbidden_forest',
          'canon_ps_year_end',
        ]),
      );
    });

    test('声明讲述某节点的步，其文本必须真的在讲那件事（关键词抽查）', () {
      // 每个节点抽 2 个必现关键词——canonRefId 抑制旁白块之后，
      // 剧情文本是玩家了解这段原著的唯一渠道，讲错事等于没讲。
      const mustMention = <String, List<String>>{
        'canon_ps_gringotts': ['古灵阁', '闯'],
        'canon_ps_sorting': ['分院'],
        'canon_ps_troll': ['巨怪'],
        'canon_ps_quidditch_first': ['魁地奇'],
        'canon_ps_christmas_mirror': ['镜子'],
        'canon_ps_forbidden_forest': ['禁林', '独角兽'],
        'canon_ps_year_end': ['学院杯'],
      };
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            final ref = s.canonRefId;
            if (ref == null) continue;
            final keywords = mustMention[ref];
            if (keywords == null) continue; // 未来书籍逐部补表
            final corpus = _corpusOf(s).join('\n');
            for (final k in keywords) {
              expect(
                corpus.contains(k),
                isTrue,
                reason: '步 ${s.id} 声明讲述「$ref」但文本里找不到「$k」',
              );
            }
          }
        }
      }
    });
  });

  group('E · 幽灵引用防线（flag / 物品 / NPC）', () {
    /// 全部会被置位的 flag（结局条件与选项解锁都必须指向这里）。
    Set<String> settableFlags() {
      final set = <String>{};
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            for (final c in s.choices) {
              set.addAll(c.effect.setFlags);
            }
          }
        }
      }
      return set;
    }

    test('结局规则引用的 flag 必须真的会被置位', () {
      final settable = settableFlags();
      for (final book in kStoryBooks.values) {
        for (final r in book.endings) {
          for (final f in r.requireFlags) {
            expect(
              settable.contains(f),
              isTrue,
              reason: '结局 ${r.id} 需要 flag「$f」，但没有任何选择会置位它'
                  '——这个结局永远不可达',
            );
          }
          for (final f in r.requireAnyFlags) {
            expect(
              settable.contains(f),
              isTrue,
              reason: '结局 ${r.id} 的候选 flag「$f」永远不会被置位',
            );
          }
        }
      }
    });

    test('选项的 requireFlag 必须真的会被置位（否则选项永远不可见）', () {
      final settable = settableFlags();
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            for (final c in s.choices) {
              if (c.requireFlag == null) continue;
              expect(
                settable.contains(c.requireFlag),
                isTrue,
                reason:
                    '分支 ${s.id}/${c.id} 需要 flag「${c.requireFlag}」，'
                    '但没有任何选择会置位它',
              );
            }
          }
        }
      }
    });

    test('结局的数值门槛必须在全书累计上限之内（否则特殊结局永远不可达）', () {
      // 理论上限 = 每一步都选"该数值最大"的分支（不同玩家不同路线，
      // 但内容作者必须保证至少存在一条路线能越过每道门槛）。
      var maxAffection = 0;
      var maxReputation = 0;
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            maxAffection += s.choices
                .map((c) => c.effect.affection)
                .fold(0, (a, b) => a > b ? a : b);
            maxReputation += s.choices
                .map((c) => c.effect.reputation)
                .fold(0, (a, b) => a > b ? a : b);
          }
        }
      }
      for (final book in kStoryBooks.values) {
        for (final r in book.endings) {
          if (r.minAffectionTotal != null) {
            expect(
              r.minAffectionTotal!,
              lessThanOrEqualTo(maxAffection),
              reason: '结局 ${r.id} 的好感门槛 ${r.minAffectionTotal} 超过'
                  '全书累计上限 $maxAffection，永远不可达',
            );
          }
          if (r.minReputation != null) {
            expect(
              r.minReputation!,
              lessThanOrEqualTo(maxReputation),
              reason: '结局 ${r.id} 的声望门槛 ${r.minReputation} 超过'
                  '全书累计上限 $maxReputation，永远不可达',
            );
          }
        }
      }
    });

    test('addItems 要么是物品目录里的真名，要么是登记过的剧情物品', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            for (final c in s.choices) {
              for (final item in c.effect.addItems) {
                expect(
                  itemDefByName(item) != null ||
                      _storyItemWhitelist.contains(item),
                  isTrue,
                  reason: '${s.id}/${c.id} 的物品「$item」既不在物品目录'
                      '也不在剧情白名单，会以乱名落进背包',
                );
              }
            }
          }
        }
      }
    });

    test('targetNpcId 必须是 harry_same 时代真正登场的 NPC id', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            for (final c in s.choices) {
              final npc = c.effect.targetNpcId;
              if (npc == null) continue;
              expect(
                _harrySameNpcIds.contains(npc),
                isTrue,
                reason: '${s.id}/${c.id} 的好感对象「$npc」不在'
                    'harry_same 时代的 NPC 种子表里——好感会加给空气',
              );
            }
          }
        }
      }
    });
  });

  group('F · 开局场景定位（不许时间倒流）', () {
    test('letter 开局从第一章收信开始', () {
      expect(storyStartStepFor('letter')!.id, 'ps_ch1_letter');
    });

    test('diagon 开局跳过暑假信件，从对角巷开始', () {
      final s = storyStartStepFor('diagon')!;
      expect(s.id, 'ps_ch2_arrival');
      expect(s.chapterId, 'ps_ch2');
    });

    test('station 开局（9 月 1 日上午）从站台开始', () {
      final s = storyStartStepFor('station')!;
      expect(s.id, 'ps_ch3_platform');
      expect(s.chapterId, 'ps_ch3');
    });

    test('hall / eve 开局（分院在即）直接从分院夜开始', () {
      expect(storyStartStepFor('hall')!.id, 'ps_ch4_sorting');
      expect(storyStartStepFor('eve')!.id, 'ps_ch4_sorting');
    });

    test('未知开局场景回退第一章第一步，不崩', () {
      expect(storyStartStepFor('不存在的场景')!.id, 'ps_ch1_letter');
      expect(storyStartStepFor('')!.id, 'ps_ch1_letter');
    });

    test('每个定位结果的步都真实存在于书表', () {
      for (final scene in const [
        'letter', 'diagon', 'station', 'hall', 'eve',
      ]) {
        final s = storyStartStepFor(scene)!;
        expect(
          findStoryStep('ps', s.chapterId, s.id),
          isNotNull,
          reason: '开局场景 $scene 定位到的步不合法',
        );
      }
    });
  });
}
