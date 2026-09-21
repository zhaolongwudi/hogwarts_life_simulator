# UI 重构批次交接文档

> 交接时间：本次对话结束前
> 交接人：当前对话（UI 大幅优化第一批）
> 接收人：下一个对话
> 状态：**代码已改完并写入磁盘，但 `git commit` 尚未落地**（终端会话卡在 git 命令上无响应，HEAD 仍停在 `c43a731`）

---

## 一、本批任务

用户诉求：「对项目的整体 UI 进行大幅度优化，我允许你重构，现在的面板实在不太满意，很多地方都错位，或者是被莫名其妙的东西覆盖。」

我完成了**第一批：定位并修复「错位 / 覆盖 / 对比度」有代码证据的核心问题**，重灾区是 `world_map_screen.dart`（世界地图页）。其余页面仅做零风险语义色收敛。

---

## 二、已改动的文件与内容（均已通过 edit_file 写入磁盘）

### 1. `lib/screens/world_map_screen.dart`（核心，4 处修复）

| 问题 | 根因 | 修复 |
|---|---|---|
| 标记盖住顶部标题卡 | `build()` 的 `SafeArea > Stack` 里 `_buildLocationMarkers()` 排在 `_buildTopHeader()` 之后，Flutter Stack 后绘制者在上层 | 把 `_buildLocationMarkers()` 移到 Stack 最底层，浮层（标题卡/返回键/图例/切区按钮）全部盖在它上面 |
| 顶部标题看不清 | 标题卡是深灰 `surfaceContainerHigh` 底，标题却用更深的 `surfaceContainer` 深灰字（深底配深字） | 标题色改为 `MiuiColors.onSurface`（亮色） |
| 标记区几何预留错乱 | `headerOffset=110` 小于标题卡实际高度(~140)，标记钻到标题卡底下被遮；`bottomOffset=420` 过大，把 `usableHeight` 压到 300+，标记全被切成 compact 小圆点 | 改为 `headerOffset=140.0` / `bottomOffset=150.0` |
| 图例悬浮遮挡标记 | `_buildMapLegend` 原 `bottom:280`，悬浮在地图中央遮住标记文字 | 改为 `bottom:68`，贴紧底部切区按钮上方 |

### 2. `lib/screens/settings/settings_body.dart`（零风险语义色收敛）

- 2 处金底按钮 `foregroundColor: const Color(0xFF1A1A2E)` → `MiuiColors.onPrimary`（金底上的规范深字）

### 3. `lib/screens/game/game_play_screens.dart`（零风险语义色收敛）

- 3 处金底按钮 `foregroundColor: const Color(0xFF1A1A2E)` → `MiuiColors.onPrimary`
- 卸下按钮 `Colors.red` / `Color(0xFFE05050)` → `MiuiColors.error`

### 4. `docs/UI重构规范与台账.md`

- 新增「四·附·G：世界地图几何错位 / 覆盖 / 对比度修复（完成）」段落，完整记录了上述改动。

---

## 三、待办事项（新对话接手后立即执行）

1. **提交并推送**（终端恢复后）：
   ```bash
   cd /root/hogwarts_life_simulator
   bash push.sh "fix(ui): 世界地图错位/覆盖/对比度修复+金底深字语义色收敛"
   ```
   - 注意：`bash push.sh` 会 `git add -A && git commit && git push origin main`。
   - 若 push 报 `Failed to connect to github.com port 443`，按 `BATCH10_HANDOVER.md` 第 11 条修 /etc/hosts（`140.82.112.3 github.com`）。

2. **等 CI**（GitHub Actions，约 3-5 分钟）：`flutter analyze` 0 error + `flutter test` 全绿。

3. **同步台账**：`docs/UI重构规范与台账.md` 的「四·附·G」已写，但门禁行里的「flutter test 全绿」需在 CI 绿后确认（当前写的是「由 CI 验证，本机无 Flutter」）。

---

## 四、终端异常说明（重要）

- 执行 `bash push.sh` 后终端会话持续 `timedOut`（每个 `super_admin:terminal` 调用都无输出）。
- `git status` 显示：工作区有 4 个文件的未提交改动（world_map_screen / settings_body / game_play_screens / UI重构规范与台账），HEAD 仍是 `c43a731`。
- 可能是 `git push` 卡在 GitHub 网络（交接文档记录过 github.com DNS 常失效），也可能只是会话超时。
- **磁盘上的代码改动是确定且完整的**（已用 `read_file` 复核 `world_map_screen.dart` 的 Stack 顺序、标题色、headerOffset/bottomOffset 全部就位）。

---

## 五、下一步 UI 优化方向（供新对话参考，未开始）

本批只做了「有代码证据」的错位/覆盖/对比度修复。若用户继续要求「大幅度优化」，可继续：

1. **色板统一**（台账「四·附·F 已知残留」明确标记）：
   - `settings_body.dart` / `game_play_screens.dart` / `world_map_screen.dart` 三处仍有蓝紫旧主题残留（`0xFF1A1A2E` 底 / `0xFF8A8AAA` 文字 / `0xFF3A3A5C` / `0xFF2A2A4A` / `0xFF5A5A7A` / `0xFFB0B0C8` / `0xFF6A6A8A` 灰阶），与全库金/中性色板不一致。
   - 台账明确「需先更新边界说明再小步替换」，不建议一次性机械替换（会大范围改变观感）。

2. **世界地图悬浮卡片**：`_buildLocationCard` 用 `Colors.white.withValues(alpha:0.98)` 白底弹卡，与全库暗色液态玻璃风格不搭；`_areaChip`、返回键也用白底。可考虑统一为玻璃拟态深底。

3. **游戏主界面**：`game_screen.dart` 底部「输入栏 + 液态玻璃导航」连续 Dock 的 `_navSpace` 计算，以及 `game_narrative_tab.dart` 的横幅/选项/加载槽位高度配合，可在真机/CI golden 上进一步核对。

> 安全红线（台账第五节）：只做视觉与组织层改造，不改玩法/存档/行为逻辑；每批跑 analyze + test。

---

## 六、关键文件速查

- `docs/BATCH10_HANDOVER.md` —— 项目跨对话主锚点（不得删除）
- `docs/UI重构规范与台账.md` —— UI 唯一规范 + 台账
- `lib/screens/world_map_screen.dart` —— 本批核心修复对象
- `lib/theme/miuix_tokens.dart` —— 唯一语义色源（`MiuiColors`）
- `lib/utils/ui_helpers.dart` —— `AppColors` 兼容别名（逐步淘汰）
