# Copilot Instructions (Hogwarts Life Simulator)

> 开始任何改动前，请先读本文件与根目录 `AGENTS.md`。
> 项目已迭代到 P14（v4.8.x），存在大量历史约定（源码扫描测试、mixin 组合、版本 CI 机制），
> 不看维护文档直接改代码几乎必然踩坑或改坏已有功能。

## 动手前必读（按顺序）

1. `PROJECT_GUIDE.md` —— 项目结构与维护指南（目录地图、mixin 组合、测试契约、版本 CI、按症状定位）。
2. `docs/工作思路与后续规划.md` —— P1~P14 工作思路 + 后续内容分级规划 + 离线叙事管线顺序与铁律。想加新玩法/新系统优先看这里。
3. `.github/archive/框架对照维护台账.md` —— 各阶段需求/实现状态对照 + "明确不做"清单。判断"做没做过 / 该不该做"时查这里。

只修 bug 也至少先读 `PROJECT_GUIDE.md` 的 §4（测试契约）与 §5（版本 CI）。

## 三条铁律

- 老档兼容铁律：`models/` 新字段的 `fromJson` 必须给缺省值。
- 源码扫描测试：`test/` 有测试会读 `lib/` 源码文本并断言字符串/结构，改源码不同步断言会挂测试。
- 勿手动改版本号/CHANGELOG：`pubspec.yaml` 是唯一事实来源，CI 自动 bump；说明写进 commit body 或 `UPDATE_DESC.md`。

## 新增"世界在动"内容层

走八步流程（见 `PROJECT_GUIDE.md` §3.1）：数据收口 `data/` → 逻辑收口对应 `mixin_` → 接入 `mixin_narrative.dart` 离线管线并守互斥/冷却 → 共享夹具 `makeGame` 默认关闭随机内容 → 专项测试独立 `batchNN`。核心细节对照 `docs/工作思路与后续规划.md` 与 `框架对照维护台账.md`。