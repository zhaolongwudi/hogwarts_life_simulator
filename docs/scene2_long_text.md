# 场景2 · 长消息压缩观测输入（约4000字项目综述）

【第一部分：项目与仓库状态】
霍格沃茨人生模拟器项目（zhaolongwudi/hogwarts_life_simulator）是一个基于 Flutter 的巫师人生模拟游戏，核心是「离线回合制」玩法引擎：时间、学院、好感、职业、死亡等系统在 v3.x 成型，P1~P14 阶段把「世界在动」做成可叠加的模块层。当前 HEAD 为 458c99a（docs: 交接文档同步Batch45真实状态+新增极限测试附录），工作区干净。最近版本标签为 v5.1.5（2026-09-21 由 8a8b4da 打 tag）。CI 最近一次全绿为 run 629（对应 c8689c2 revert 提交），公开 API 可查无需 token。

【第二部分：Batch 45 限流治理的来龙去脉】
Batch 45 起因是 SenseNova API 频繁返回 429 限流错误。首版提交 c4626e7「fix(batch45): SenseNova补每分钟限流治429 + 叙事maxTokens放宽防截断重试」新增了 lib/services/rate_limiter.dart（71 行限流器）、lib/mixins/mixin_init.dart 的接入行、deepseek_service 的每分钟限流 4 行、test/batch45_sensenova_rpm_test.dart（67 行测试），并在 lib/mixins/mixin_systems.dart 把叙事 maxTokens 放宽（保留收益）。该提交的 CI run 628 结果为 failure。随后 c8689c2「revert: 撤回SenseNova RPM限流 保留叙事maxTokens2000」整体删除 rate_limiter.dart 71 行、mixin_init 接入、deepseek_service 限流 4 行、batch45 测试 67 行，只保留 mixin_systems 的叙事 maxTokens 放宽，CI run 629 转绿。结论：新增限流器的方案引发回归失败，整体回退；429 治理改走「多 Key 轮换 + 单 Key 熔断（3次/60s）」路线，不再新增独立限流器。

【第三部分：CHAT 上下文压缩配置基线】
CHAT 主模型为商汤 deepseek-v4-flash（配置 ID a7757af9-6675-4b28-99a6-e75651f50e38）。上下文压缩相关参数：summary_token_threshold=0.35、summary_message_count_threshold=8、context_length=48、max_context_length=128、enable_max_context_mode=true。这套参数是 2026-09-22 00:34 从旧值调整而来：summary_token_threshold 0.6→0.35、summary_message_count_threshold 16→8，且工具副作用连带 context_length 从 192 降为 48、max_context_length 从 512 降为 128。水位标注规则：●○○○ 约25%正常、🟡 超过60%建议准备交接、🔴 超过85%建议立即开新对话。自动交接工作流 ed134977「自动交接巡检」配置为 Input tokens > 500万 时触发（GT 5000000，节点「水位超限判断(>500万)」），动作链为：创建新对话（组「自动交接」，set_as_current_chat=true）→ stop_chat 停止旧对话 → send_notification 通知手动删除；定时触发 15 分钟间隔（900000ms），当前 enable=false（测试期间保持关闭）。工作流历史执行 22 次，成功 11 次失败 11 次，最近一次 lastExecutionStatus=SUCCESS。

【第四部分：极限测试方案设计】
本次测试目标：定位「对话无提示停止」的真实触发机制，判断能否回调上下文压缩设置。场景1为基线观测（20-30 轮正常聊天，观察水位何时变 🟡/🔴、AI 是否主动总结、总结后是否忘早期细节）；场景2为长消息压缩观测（发 3000-5000 字长文本，观察是否立即触发总结，总结后追问早期细节验证丢内容程度）；场景3为长对话极限测试（核心，用持续工作任务让对话自然增长，每 10 轮记录轮数/水位/是否总结/是否异常，观察何时无提示停止）；场景4为工作流联动（仅当场景3没停时做，开启工作流逼近 500万，验证超限是否触发建新对话+停旧对话+通知，以及旧对话是否还能访问）。判定表：停止时水位远低于128→疑模型窗口/网络/Operit限制与500万无关；停止时水位≈128→max_context_length 先触发工作流兜不住→需回调128或改判据；停止时Input tokens≈500万→工作流阈值触发可放心回调压缩设置；全程无停止→白天正常保持现状。回调建议：若压缩过频致丢内容且停止点=500万，则 summary_token_threshold 0.35→0.5~0.6、message_count 8→12~16、context_length 48→128~192、max_context_length 128→256~512（分档回调）；若 max_context_length 128 先触发，优先回调 max_context_length 并把工作流阈值下调或改为按上下文窗口比例判据；若无停止则不动。

【第五部分：关键源码位置与待办锚点】
- lib/data/club_data.dart:475 是 kClubTasks 定义处，决斗社首个任务 id 为 duel_ten_spars
- lib/mixins/mixin_play.dart:1037 是 duelNpc 决斗路由入口（每日次数上限、在校生过滤、60分钟计时），可复用做决斗社季度赛
- 规划文档第一梯队待办：社团专属小玩法（决斗社季度赛/魔药部限时配方/魁地奇队训练/快讯社头版事件）+ 同好 NPC 关系注入
- 第二梯队待办：来信→社团/来信→羁绊串联、奇遇结果长期痕迹
- 工程收口：README/PROJECT_GUIDE/框架对照台账三文档随迭代同步
- 交接文档路径：/root/hogwarts_life_simulator/docs/BATCH10_HANDOVER.md（含本次测试附录，禁止删除）
- 测试进度台账当前记录到第 10 轮，水位 ●○○○

【第六部分：本轮场景2观察要求】
本条消息为场景2的输入文本。观察要求：1) 本条是否立即触发上下文总结（看回复中是否有总结动作提示）；2) 总结后回答：kClubTasks 定义在哪一行、决斗社首个任务 id 是什么、Batch45 revert 后保留了什么收益、工作流 ed134977 的超限阈值是多少、当前测试进度台账记录到第几轮；3) 报告当前水位标注。请如实回答，不要编造。
