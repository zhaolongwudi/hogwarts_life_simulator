# 沙箱推送脚本 commit message 残留 bug 说明

> 维护提示：如果你看到 main 分支有连续几条标题完全相同的提交，根因在这里。

## 发生了什么
2026-09-01 深夜（沙箱重建后的会话里），从第 15 轮开始用 `scripts` 目录外的
`/opt/ghproxy/api_push.py` 直接走 GitHub REST API 推送 commit（绕开 git
smart-HTTP 的 TLS 大包传输问题）。脚本里 commit message 从外部文件读取：

```python
with open(msg_path) as f:
    message = f.read()
```

`msg_path = '/tmp/commit_msg.txt'` 在第 15 轮推送时被一次性写入了第 15 轮的
提交说明，**后续推送脚本没有重新从 git HEAD 取**，所以第 16 轮 A/B 与档案
更新共 4 个 API 创建的 commit（`c278ff3edb`、`249405ef77`、`53a3fe2aa2`）
**全都用了第 15 轮的标题**：

```
fix: 第15轮审查修复 P1×5 + P2×11——坏结局二囚禁/读档回滚/在飞世代守卫/信息分级/恋爱声望落点
```

## 实际内容（差异在 diff，不在标题）
- `c278ff3edb` — 第 16 轮 A 遗留项修复（穿越者记忆/NPC联动/传说特质降频等）
- `249405ef77` — 第 16 轮 B 内容质量审查 F1-F7（【在场】档位化、防韩文、声望数据驱动等）
- `53a3fe2aa2` — 档案总览补第 16 轮 B 记录

点开任一 commit 看 `Files changed` 即可看到真实改动。

## 为什么没改 commit message
**GitHub REST API 不允许修改已存在 commit 的 message**（git data API 只能改
refs/trees/blobs，commit 创建后 message 是不可变字段）。唯一办法是 force push
重写历史——会改 SHA、破坏 CI commit 引用、且改动范围会扩散到所有下游消费者，
风险远大于收益，故不修。

## 修复
`api_push.py` 改为**每次推送实时从 git HEAD 读 message 与日期**，彻底避免残留：

```python
message = subprocess.check_output(
    ["git", "-C", "/workspace/hls_git", "log", "-1", "--format=%B", "HEAD"],
    text=True,
).strip()
head_meta = subprocess.check_output(
    ["git", "-C", "/workspace/hls_git", "log", "-1", "--format=%cI", "HEAD"],
    text=True,
).strip()  # ISO 8601 带时区，GitHub API 直接接受
```

本条 `docs:` commit 就是用修好后的脚本推送的——你看到这条的标题/日期与
`git log -1 HEAD` 一致，证明修复生效。