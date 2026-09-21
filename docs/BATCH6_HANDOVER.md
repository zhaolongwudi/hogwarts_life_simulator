# 任务交接文档 - Batch 6 · Issue #8

## 当前状态

**已完成：**
- ✅ Batch 5 · Issue #7（P14 频次口径统一）- commit `9f353d8`
  - 所有高频活动门槛统一到每日预算表 `kDailyActivityLimits`
  - 新增 `club_activity: 1`、`club_task: 3` 两条预算
  - `maybeRunClubActivity` / `advanceClubTaskForAction` 改用 `canDoDaily/recordDailyActivity`
  - `kClubCooldownTurns` @Deprecated，`Player.clubLastTurn` 从运行时判定中除名
  - CI 通过（run 35563536460）

**当前任务：**
- 🔨 Batch 6 · Issue #8（selectYearGoal 加权随机 + 关联主线）
  - 状态：刚开始探索，**还没有做任何代码修改**
  - 工作区干净，可以直接开始

## 已收集的信息

### 1. 当前实现位置
- **文件：** `lib/data/goal_data.dart`
- **函数：** `selectYearGoal(int schoolYear, {int seed = 0})`
- **当前实现：** `(schoolYear - 1 + seed) % yearGoalPool.length`
- **调用点：** `lib/mixins/mixin_systems.dart:708`
  ```dart
  final sub = selectYearGoal(newGrade, seed: turnCount);
  ```

### 2. 数据结构
- **SubGoal 类**（`goal_data.dart:266-285`）：
  ```dart
  class SubGoal {
    final String id;
    final GoalTier tier;
    final String label;
    final String description;
    final String relatedGoalId;  // 关联的人生目标 id（空字符串表示通用）
    final String steeringHint;
    // 构造函数...
  }
  ```

- **yearGoalPool**（`goal_data.dart:288-340`）：6 个学年目标
  - `yr_first_friend` - 结交第一位挚友
  - `yr_professor_favor` - 赢得一位教授的赏识
  - `yr_house_cup` - 为学院杯贡献力量
  - `yr_skill_mastery` - 精通一门魔法技艺
  - `yr_secret_discovery` - 发现一座城堡的秘密
  - `yr_stand_up` - 在关键时刻挺身而出

- **LifeGoal 类**（`goal_data.dart:30-50`）：
  ```dart
  class LifeGoal {
    final String id;      // 如 'auror', 'potion_master', 'quidditch'
    final String name;    // 如 '成为傲罗'
    final String category;
    final String description;
    final String steeringHint;
    final GoalRequirement requirement;
  }
  ```

- **player.currentGoal**（`lib/models/player.dart:25`）：
  ```dart
  String? currentGoal;  // 存储 LifeGoal 的 name（不是 id）
  ```

### 3. 职业线映射（需要建立）
根据 LifeGoal 的 id 和 SubGoal 的内容，建议的亲和度映射：
- `yr_first_friend` → `minister`, `healer`（社交型职业）
- `yr_professor_favor` → `potion_master`, `auror`（学术型职业）
- `yr_house_cup` → `quidditch`（竞技型职业）
- `yr_skill_mastery` → `potion_master`, `auror`（技艺型职业）
- `yr_secret_discovery` → `auror`（探索型职业）
- `yr_stand_up` → `auror`, `minister`（勇气/领导力型职业）

## 下一步计划（B 方案）

### Step 1: 给 SubGoal 添加 careerAffinity 字段
```dart
class SubGoal {
  // ... 现有字段 ...
  final String relatedGoalId;
  
  /// 职业线亲和度（Batch 6 · Issue #8）：key 是 LifeGoal.id，value 是权重倍数
  /// 例如 {'auror': 1.5} 表示当玩家目标是傲罗时，这个子目标权重 ×1.5
  final Map<String, double> careerAffinity;
  
  final String steeringHint;
  
  const SubGoal({
    // ... 现有参数 ...
    this.relatedGoalId = '',
    this.careerAffinity = const {},  // 新增
    this.steeringHint = '',
  });
}
```

### Step 2: 给 yearGoalPool 的每个目标添加 careerAffinity
```dart
SubGoal(
  id: 'yr_first_friend',
  // ... 其他字段 ...
  careerAffinity: {'minister': 1.5, 'healer': 1.5},
  // ...
),
```

### Step 3: 修改 selectYearGoal 签名和实现
```dart
/// 根据学年号抽取学年目标（Batch 6 · Issue #8：加权随机 + 排除近期已用 + 关联主线）
SubGoal selectYearGoal(
  int schoolYear, {
  int seed = 0,
  String? currentGoalName,  // 新增：玩家当前人生目标名称
  List<String> recentGoalIds = const [],  // 新增：近期已选目标 id 列表
}) {
  // 1. 过滤掉近期已选的目标
  final candidates = yearGoalPool.where((g) => !recentGoalIds.contains(g.id)).toList();
  
  // 2. 计算权重
  final weights = candidates.map((g) {
    double weight = 1.0;
    // 如果玩家有当前目标，且该子目标有对应的亲和度，权重 ×1.5
    if (currentGoalName != null && currentGoalName.isNotEmpty) {
      // 需要找到 currentGoalName 对应的 LifeGoal.id
      // 这里需要遍历 lifeGoalCatalog 找到匹配的 id
      for (final lg in lifeGoalCatalog) {
        if (lg.name == currentGoalName) {
          weight = g.careerAffinity[lg.id] ?? 1.0;
          break;
        }
      }
    }
    return weight;
  }).toList();
  
  // 3. 加权随机选择
  final totalWeight = weights.reduce((a, b) => a + b);
  final random = Random(seed);
  final threshold = random.nextDouble() * totalWeight;
  
  double cumulative = 0.0;
  for (int i = 0; i < candidates.length; i++) {
    cumulative += weights[i];
    if (threshold <= cumulative) {
      return candidates[i];
    }
  }
  
  // 兜底：返回第一个候选
  return candidates.first;
}
```

### Step 4: 修改调用点（mixin_systems.dart:708）
```dart
// 旧代码
final sub = selectYearGoal(newGrade, seed: turnCount);

// 新代码
final recentGoalIds = _getRecentYearGoalIds();  // 需要实现这个辅助方法
final sub = selectYearGoal(
  newGrade,
  seed: turnCount,
  currentGoalName: player?.currentGoal,
  recentGoalIds: recentGoalIds,
);
```

### Step 5: 实现 _getRecentYearGoalIds 辅助方法
需要在 `mixin_systems.dart` 中添加一个方法，从存档或历史记录中获取最近 3 个已选的学年目标 id。

**可能的实现方式：**
1. 在 `Player` 类中添加 `List<String> recentYearGoalIds` 字段
2. 每次选择学年目标时，将目标 id 添加到列表中（保持最多 3 个）
3. 在存档中持久化这个列表

### Step 6: 更新测试
- 修改 `test/batch45_club_task_test.dart` 中相关的测试用例
- 添加新的测试用例验证加权随机逻辑

### Step 7: 更新设计审查台账
- 在 `docs/设计审查_2026-09-21.md` 中标记 Batch 6 完成

## 关键注意事项

1. **不要使用 heredoc 传递中文** - shell 会破坏 UTF-8 编码，改用 Python 脚本文件
2. **每个补丁要幂等化** - 先检查 anchor 是否存在，不存在就跳过
3. **每改一个文件立刻验证** - 用 grep 确认修改成功
4. **重要操作前先 git status** - 方便回滚
5. **CI 结果要等到绿才切下一批** - 不要跳过验证

## 文件位置速查

- `lib/data/goal_data.dart` - SubGoal 类、yearGoalPool、selectYearGoal 函数
- `lib/mixins/mixin_systems.dart:708` - selectYearGoal 调用点
- `lib/models/player.dart:25` - player.currentGoal 字段
- `test/batch45_club_task_test.dart` - 相关测试
- `docs/设计审查_2026-09-21.md` - 设计审查台账

## 工作流规则

1. 每批修复前先重新核实该问题确实存在
2. 每修复一批立即 commit 并 push
3. 等待 GitHub Actions CI 构建测试
4. 有错误先修复，成功后进入下一批
5. 每批同步更新 docs/设计审查_2026-09-21.md 的处理台账

---

**交接时间：** 2026-09-21
**交接人：** 当前对话
**接收人：** 下一个对话

**开始工作前请执行：**
```bash
cd /root/hogwarts_life_simulator
bash pull.sh  # 拉取最新代码
```