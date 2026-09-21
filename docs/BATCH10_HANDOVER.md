# 任务交接文档 - Batch 10 剩余 + Batch 9

## 当前状态（HEAD: c1e0ed3，已全量 push，CI 全绿）

**已完成（CI 全绿）：**
- ✅ Batch 5 · Issue #7（P14 频次口径统一）
- ✅ Batch 6 · Issue #8（selectYearGoal 加权随机 + 关联主线）
- ✅ Batch 7 · Issue #11（论坛评论写真实评论实体）
- ✅ Batch 8 · Issue #12（传闻生成去重 + 节流）
- ✅ Batch 8 · Issue #15（foreshadow 实体一致性放行通道）
- ✅ Batch 8 · Issue #16（scene_illustration Color 显式豁免）
- ✅ Batch 8 · Issue #17（narrative_prompts 分级 T0/T1/T2）
- ✅ Batch 8 · Issue #18（长期记忆 importance 按事件类型集中配置）
- ✅ Batch 10 · Issue #23（CI 静态扫描纯计数增量必须配套实体）
  - `658905c` 首次提交，CI 红（自检用例正则匹配不到 `commentList.add`）
  - `faaeb94` 修复：`_entityWritePattern` 正则从 `\.\w*(List|Entries|Items|Records)\s*\.(add|insert)` 放宽为 `\.\w+\s*\.(add|insert)`，并同步改断言用例 → CI 全绿
  - `c1e0ed3` 台账标记完成

**Issue #4 已核实，建议「不采纳」（同 Issue #22）：**
- 实测旧分段映射 0~40 全表：已单调不减、无跳变 >1、上限 ±10 守住。
- 报告说的「非连续」实为 round 取整的平台期（如 5、6 都→5），是取整固有舍入，非 bug。
- 报告建议的 `sqrt(d*2)` 反而有害：落地区间整体缩水（中等 4~6→3~4、重大 7~9→4~6）、层次差距变小、跨档重叠，倒退 P0-1「拉开层次」成果，且会让 `provider_logic_test` / `audit_round9_test` 回归锁全红。
- **结论：不改。** 若用户仍要动，必须先推翻上述实测依据并重核测试回归锁。

## 待做清单（按优先级，一批一改一推）

### 🔨 Batch 10 · 工程基建（推荐先做 Issue #19）
1. **Issue #19** story_data 五书时间单调性静态校验（532KB 原著当前零审查，推荐）
   - 文件：`lib/data/story_data.dart` + `story_data_poa.dart` + `story_data_gof.dart` + `story_data_ootp.dart` + `story_data_hbp.dart` + `story_data_dh.dart`
   - 测试：新增 `test/batch10_story_data_monotonic_test.dart`
2. Issue #13 CI 全开 smoke 套件
3. Issue #14 文档纳入 CI 同步流程

### ⚪ Issue #4 压缩函数（建议跳过，见上）

## 工作流规则（必须遵守）
1. **每批修复前先重新核实该问题确实存在**（grep 源码确认）
2. **每修复一批立即 commit 并 push**（沿用 `bash pull.sh` / `bash push.sh "说明"`）
3. **等待 GitHub Actions CI 构建测试**（约 3-5 分钟）
4. **有错误先修复，成功后进入下一批**
5. **每批同步更新 docs/设计审查_2026-09-21.md 的处理台账**

## 关键注意事项
1. **不要用 heredoc 传中文** - shell 会破坏 UTF-8 编码，改用 Python 脚本文件或 edit_file 工具
2. **每个补丁要幂等化** - 先检查 anchor 是否存在，不存在就跳过
3. **每改一个文件立刻验证** - 用 grep 确认修改成功
4. **重要操作前先 git status** - 方便回滚
5. **CI 结果要等到绿才切下一批** - 不要跳过验证
6. **存档字段数变更要同步更新 progression_fix_test.dart** - 该测试硬编码了 `_saveExtraData` 字段数（当前 21），新增字段要 +1
7. **测试里不要用 `isA<List>().having(length, ...)`** - 会报未定义标识符，先 cast 再断言
8. **测试里未使用的 import 要移除** - CI 报 unused_import warning（不卡门禁但保持干净）
9. **本机无 Flutter** - 测试只能靠 GitHub Actions CI 验证，改完推上去看 CI
10. **查 CI 状态/日志**：
    ```bash
    TOKEN=$(grep -o 'github_pat_[A-Za-z0-9_]*' ~/.git-credentials | head -1)
    curl -s -H "Authorization: Bearer $TOKEN" 'https://api.github.com/repos/zhaolongwudi/hogwarts_life_simulator/actions/runs?per_page=5'
    ```

## 文件位置速查
- `lib/data/balance_constants.dart` - 平衡常量（含 compressAffectionDelta，Issue #4）
- `lib/data/story_data.dart` + `story_data_{poa,gof,ootp,hbp,dh}.dart` - 主线剧情数据（Issue #19）
- `lib/models/story_progress.dart` - 剧情进度/书序
- `lib/mixins/mixin_systems.dart` - 系统逻辑
- `test/batch10_counter_entity_test.dart` - Batch 10 Issue #23 静态扫描测试（已就位）
- `docs/设计审查_2026-09-21.md` - 设计审查台账（必须每批更新）

## 开始工作前请执行
```bash
cd /root/hogwarts_life_simulator
bash pull.sh  # 拉取最新代码
```

---
**交接时间：** 2026-09-21
**交接人：** 当前对话
**接收人：** 下一个对话
**当前 HEAD：** `c1e0ed3`（docs: Batch 10 Issue #23 CI 全绿，台账标记完成）
