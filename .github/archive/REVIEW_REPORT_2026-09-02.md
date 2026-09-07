# 霍格沃兹人生模拟器 · 第 15 轮全面审查报告（新增角度）

> 审查日期：2026-09-01 深夜（交接文档启用日）
> 审查基线：`main` @ `5f757a3`（v3.6.7+367）
> 审查方式：**框架1（典藏版设定）+ 框架2（人生模拟框架）双文档对照** +
> 三路并行深度审查（框架对照 / 数据可靠性 / 质量·依赖·文案）+ 逐项人工复核
> 验证环境：Flutter 3.47.2 / Dart 3.13.2（沙箱重建，与项目要求完全一致）
> 验证结果：`flutter analyze` **0 error / 0 warning**；`flutter test` **1291 项全绿**（1280 基线 + 11 新增）

---

## 一、本轮审查角度（历史未系统覆盖的 6 个新增角度）

| 角度 | 审查内容 | 核心发现数 |
|---|---|---|
| 1. 框架双文档对照 | 框架1 §0-§20（顶层法则/四时代/好感/表白/声望/指令/作弊/时间/课堂/CG/自检/十三轮设定）+ 框架2 §1-§132（玩家非主角/信息限制/生活节奏/战斗死亡/坏结局/终章/显示模式/防崩坏）逐条取证 | P1×4 + P2×10 |
| 2. 存档健壮性 | save_service 迁移链/备份回滚/fromJson 缺省值/读写对称性 | P1×1 + P2×3 |
| 3. 长期状态膨胀 | 只增不减集合/NPC 聊天历史/渲染热点/crash_logger 写盘 | P1×1 + P2×3 |
| 4. 异步竞态 | AI 在飞时重置/读档、空 catch 吞错、mounted 覆盖、定时器清理 | P1×1 + P2×2 |
| 5. 依赖与工程 | pubspec 约束真实性与 lock 一致性、win32 override、lint 门禁、.gitignore | P2×4 |
| 6. 文案与测试质量 | 错别字/全半角/术语统一、占位符残留、源码扫描断言健壮性 | P2×2 |

**审查纪律**：三路 agent 的原始输出中有一批「文件 NUL 污染/混编」级发现，经与远端 blob sha 比对证实为**本地批量下载脚本并发竞态（8 线程共用临时文件）造成的传输损坏，远端仓库完好**——已全部排除并修复下载脚本，本轮所有结论均基于 sha 校验通过的核心文件。

---

## 二、框架对照结论（框架1/框架2 关键条款取证）

### 已确认实现（各一行证据，均有人工复核）
- **显示模式-immersive 真实生效**：`game_screen.dart:114-172` 隐藏顶栏/输入栏/底部导航 + 返回键二次确认
- **身份模式二分**：`mixin_init.dart:122-124` 原住民/穿越者分别注入 prompt
- **学习需要时间/学过≠实战会用**：`spell_data.dart:64-71` 熟练度封顶等级；`mixin_play.dart:1242-1243` 仅 Lv≥2 进战斗上下文
- **时间即资源/快进全结算**：`_advanceWorldClock` 结算周桶/学院杯他院/轻伤/满月/NPC位置/学年/锚点/孕期/传闻（mixin_systems.dart:44-131）
- **表白四条件**：好感≥85/暧昧≥2周/浪漫事件≥2/基础20%（balance_constants.dart:29-47 + mixin_relations.dart:1330-1403）
- **恋爱声望档位表**：与框架1 §13.3 逐字一致（game_systems.dart:469-475）
- **十三轮初始设定**：顺序锁定 + 童年≥3/性格≥3/魔杖必选校验（intro_screen.dart:23-37）
- **十二层自检注入**：world_rules.dart:134-147 压缩注入系统 prompt
- **魔杖无"最强"**：三杖芯数值平衡（wand_data.dart:39-50），无稀有度/星级
- **哑炮玩家侧已删除**：blood_status.dart:40-42 不在可选表，仅 NPC 侧保留原著标签
- **传承 generation 闭环**：mixin_systems.dart:1532-1718 buildLegacyFor→startLegacy→generation+1
- **世界线阶段+因果锚点**：五阶段+aiDirective + 8 个因果锚点门槛梯度真实（worldline_data.dart:115-164）

### 本轮修复的框架缺口（详见第三节）

### 仍遗留的框架差距（P2，详见第五节）

---

## 三、本轮修复清单（P1×5 + P2×11，已提交）

| # | 级别 | 位置 | 问题 | 修复 |
|---|---|---|---|---|
| R1 | P1 | `mixin_relations.dart` _applyLoveReputation | 恋爱声望惩罚落在 social，框架1 §13.3 表头是「学院声望」；UI 学院声望只被学院杯改动，两套口径 | 落点改 `houseReputation`，文案同步 |
| R2 | P1 | `player.dart`+`mixin_death.dart` | 坏结局二「自由尽失」完全未实现（endingType 只有 death 写入点） | 新增 imprisoned 状态机+终章+拦截（详见下） |
| R3 | P1 | `mixin_systems.dart` applySaveData | 读档中途异常留下新旧混合半截状态并可能被 autoSave 固化 | 快照 + catch 整体回滚 |
| R4 | P1 | `mixin_narrative.dart`+base | AI 在飞时重置/读档：旧局响应副作用写进新局/空指针 | 会话世代号 `_sessionEpoch` await 前后比对 |
| R5 | P1 | `mixin_systems.dart` /查看 | 开局第一天即可查看哈利精确好感/心上事/声望六维，违反框架2 §6/§125 | 按关系深度分级显示 |
| R6 | P2 | `game_narrative_tab.dart` | 沉浸模式仍显示好感变化数值卡 | immersive 不渲染 |
| R7 | P2 | `npc_chat_service.dart` | 会话历史只增不减 + 3 处空 catch | 裁剪 50 条 + debugPrint |
| R8 | P2 | `game_provider.dart` autoSave | 防抖窗口内第二次保存被丢弃 | _saveDirty 补存 |
| R9 | P2 | `crash_logger.dart`/`ai_debug_logger.dart` | 5 处空 catch | 补 debugPrint |
| R10 | P2 | `story_text_renderer.dart` | 说话人判定每行重建排序表 | 静态 final 缓存 |
| R11 | P2 | `mixin_systems.dart:1535` | 空名存档 [0] 越界 | 兜底 '林' |
| R12 | P2 | `pubspec.yaml` | SDK/Flutter 约束虚假（低于 lock 实际解析）；win32 override 历史遗留 | 对齐 >=3.12.0/>=3.44.0；删 override（验证可解析） |
| R13 | P2 | `intro_screen.dart` | 时代选项三项同名映射 + 亲世代无问卷入口 | 8→6 选项，补 Era.marauders 入口 |
| R14 | P2 | `mixin_play.dart` learnSpell | 学习咒语必成功（框架2 §44 失败很正常） | 按熟练度差距掷失败 5%/15%/30% |
| R15 | P2 | `player.dart` | 学院声望初始 0，负向变化被 clamp 吞掉 | 初始 50（老档缺省也 50） |
| R16 | P2 | 全 lib | 「其它/其他」混用 | 统一「其他」（18 处注释） |

### R2 坏结局二实现细节（本轮核心新增玩法）
```
触发（每回合 _settleAfterNarrative 结算，确定性不掷骰）：
  !isDead && !isImprisoned && !cheatInvincible
  && playerReputation.dark >= 75 && playerReputation.moral < 40
  && (grade ?? 1) >= 6        // 未成年巫师不直接判阿兹卡班
效果：
  isImprisoned=true → endingType='imprisoned' → 阿兹卡班终章叙事
  （镣铐/摄魂怪/威森加摩宣判 + 关系网络震动：好感≥50 的 NPC -8 并记 RecentEvent）
  → blockActionIfDead() 扩展拦截（只放行 /结局 /状态 /传承）
存档：is_imprisoned/imprisoned_on 新字段，老档缺省 false/null（兼容）
```

---

## 四、新增行为测试（11 项，test/round15_fixes_test.dart）

- 坏结局二五边界：触发 / dark 不过线 / 未成年 / 无敌 / 已死 + 拦截文案含「阿兹卡班」
- /查看 分级：浅关系不出现「好感 /心上事/声望：」，深关系（朋友 Lv60）展示
- Player.isImprisoned/imprisonedOn 序列化往返 + 老档缺键不崩
- 恋爱声望落点：跨学院恋爱 → 学院声望下降、社交声望不变

---

## 五、仍遗留的问题（第 15 次之后，P2 级）

| # | 项 | 说明 |
|---|---|---|
| 1 | 交互式世界线重演 | 改选择看世界变化，需完整状态快照+分支树，产品待定 |
| 2 | #16 源码断言 505 条迁移 | 分批推进；本轮已顺手把 2 条格式脆弱断言改空白符容忍正则 |
| 3 | 穿越者记忆随机等级 | 框架2 §11 六档随机 + 蝴蝶效应后记忆不可靠，需开局掷档写入存档 |
| 4 | 世界线偏离后 NPC 本地联动 | 框架2 §93：目前靠 AI prompt 自觉（worldline_data 自认唯一通道是 prompt），建议锚点 echo 落库时改写 NPC isAlive/位置 |
| 5 | 表白概率性格因子 | 框架1 §12.2 外向更主动/内向需铺垫，当前性格只影响台词 |
| 6 | 终章字段覆盖 | §121 的守护神/魔杖/最珍贵物品/最后悔选择/是否改变原作 未全入终章报告 |
| 7 | 快进家庭/NPC 人生模拟 | 框架2 §63：快进月只结算世界新闻池，家庭与 NPC 恋爱/矛盾静止 |
| 8 | 传说特质概率 | ~14%/局 + 可与「特殊资质」叠加，与框架2 §1「极其罕见」字面冲突 |
| 9 | 恋爱声望叠加说明 | 多档可叠加（clamp -30..10），/声望 恋爱 面板应注明 |
| 10 | IdentityMode 枚举残留 | 6 值 UI 仅暴露 3 个，建议清理 |
| 11 | ending_review_data 混入 EraDef | 文件头部 126 行时代定义，职责不符 |

---

## 六、历史病根再证（本轮新教训）

1. **「宣称 vs 实现」账目差仍在**：三类坏结局 README 声称全实现，实际只有死亡类 + 黑化定性——本轮补上 imprisoned 后还剩「corrupted 无写入点」一项（黑化只作为评语定性，未成为结局状态，产品语义上可接受但应在 /结局 明确标识）。
2. **同一概念散落多份定义（第 3 次复发）**：恋爱声望的「落点」与 UI「学院声望」两套口径——本轮收口到 houseReputation。
3. **源码扫描测试对字面格式的脆弱依赖**：dart format 拆行即假红——本轮 2 处改为格式容忍正则，佐证 #16「结构性契约保留」应匹配结构而非格式。
4. **工程卫生**：pubspec 约束写低但 lock 解析抬高（虚假最低版本）；win32 override 无注释说明何时可移除。

---

## 七、验证记录

| 项 | 结果 |
|---|---|
| flutter analyze | 0 error / 0 warning（689 info 级 lint，非门禁项） |
| flutter test | **1291 项全部通过**（1280 + 新增 11） |
| 修复范围 | 15 个 lib 文件 + 2 个测试文件修改 + 1 个新测试文件 |
| 回归风险 | 全量测试覆盖；2 处源码扫描断言已同步改健壮 |

---

## 八、下一轮建议路线（按性价比排序）

1. 穿越者记忆等级随机（P2-3）：开局掷档写存档 + prompt 按档注入，纯数据+prompt 改动，收益高
2. 世界线偏离 NPC 本地联动（P2-4）：锚点 echo 落库同步改写 NPC 状态，双保险
3. 传说特质概率下调 + 与特殊资质互斥（P2-8）：平衡常数 + 互斥校验
4. 终章字段补全（P2-6）：本地回退版补「很多年以后」问句段
5. corrupted 结局状态标识（遗留）：/结局 报告升格为明确结局类型
6. #16 断言迁移第二批：把行为可测的断言继续迁成行为测试
