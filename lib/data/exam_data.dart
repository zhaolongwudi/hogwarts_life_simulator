/// 考试成绩系统（框架2 第60条 · 考试真实存在 + 框架1 10.1 · 课堂系统）
///
/// 设计：
///  · 成绩受平时熟练度（attributes）主导 + 少量临场随机，杜绝"每学期全优"；
///  · 期末考每学年结算一次（Y1~Y7），O.W.L（五年级末）与 N.E.W.T（七年级末）
///    是特殊大考，成绩写入永久记录；
///  · 成绩等级沿用原著：O（优秀）/ E（良好）/ A（及格）/ P（差）/ D（极差）/ T（糟透）；
///  · O.W.L 优秀是多数高阶职业的敲门砖——成绩单会成为毕业抉择的参照。
library;

/// 考试科目：id / 名称 / 关联属性（加权取均）
class ExamSubject {
  final String id;
  final String name;
  final List<String> attributes;
  const ExamSubject(this.id, this.name, this.attributes);
}

/// 8 门必修课的考试科目（对应 course_data.requiredCourses）
const List<ExamSubject> examSubjects = [
  ExamSubject('transfiguration', '变形术', ['transfiguration', 'magic_control']),
  ExamSubject('charms', '魔咒学', ['spell_understanding', 'magic_control']),
  ExamSubject('dda', '黑魔法防御术', ['dda', 'reaction_time']),
  ExamSubject('potions', '魔药学', ['potions', 'observation']),
  ExamSubject('herbology', '草药学', ['herbology', 'observation']),
  ExamSubject('astronomy', '天文学', ['theory', 'observation']),
  ExamSubject('history', '魔法史', ['memory', 'theory']),
  ExamSubject('flying', '飞行课', ['flying', 'reaction_time']),
];

/// 成绩等级（原著标准）
class ExamGrade {
  final String label;
  final String cn;
  final String desc;
  const ExamGrade(this.label, this.cn, this.desc);
}

const List<ExamGrade> examGrades = [
  ExamGrade('O', '优秀', 'Outstanding'),
  ExamGrade('E', '良好', 'Exceeds Expectations'),
  ExamGrade('A', '及格', 'Acceptable'),
  ExamGrade('P', '差', 'Poor'),
  ExamGrade('D', '极差', 'Dreadful'),
  ExamGrade('T', '糟透', 'Troll'),
];

/// 根据得分（0~100）返回成绩等级。
String examGradeFor(double score) {
  if (score >= 85) return 'O';
  if (score >= 70) return 'E';
  if (score >= 55) return 'A';
  if (score >= 40) return 'P';
  if (score >= 25) return 'D';
  return 'T';
}

ExamGrade? examGradeOf(String label) {
  for (final g in examGrades) {
    if (g.label == label) return g;
  }
  return null;
}

/// 计算一科考试成绩：属性均值 × 平时系数 + 临场波动。
///
/// [dice] 0~1 随机数；[owl]/[newt] 大考时临场波动更大（更考验硬实力）。
/// 平时成绩（熟练度）决定下限：属性 90+ 再差也有 A；属性 40 以下再顺也到不了 E。
double examScoreFor({
  required List<String> attributes,
  required Map<String, int> playerAttrs,
  required double dice,
  bool owl = false,
  bool newt = false,
}) {
  var sum = 0;
  for (final a in attributes) {
    sum += (playerAttrs[a] ?? 50);
  }
  final avg = sum / attributes.length;
  final fluctuation = owl || newt ? 18.0 : 12.0;
  final luck = (dice - 0.5) * 2 * fluctuation;
  final score = avg * 0.82 + luck * 1.2;
  return score.clamp(0.0, 100.0);
}

/// 结算一次完整考试：返回 Map<科目id, 成绩等级>。
Map<String, String> settleExams({
  required Map<String, int> playerAttrs,
  required double Function() nextDouble,
  bool owl = false,
  bool newt = false,
}) {
  final result = <String, String>{};
  for (final s in examSubjects) {
    final score = examScoreFor(
      attributes: s.attributes,
      playerAttrs: playerAttrs,
      dice: nextDouble(),
      owl: owl,
      newt: newt,
    );
    result[s.id] = examGradeFor(score);
  }
  return result;
}

/// 成绩单格式化（按固定科目顺序）。
String formatExamSheet(Map<String, String> records) {
  final buf = StringBuffer('【考试成绩单】\n');
  for (final s in examSubjects) {
    final grade = records[s.id];
    if (grade == null) continue;
    buf.writeln('· ${s.name}：$grade');
  }
  return buf.toString().trimRight();
}

/// 统计某次考试的成绩分布（用于成就/通知）。
({int oCount, int eCount, int aPlusCount}) examSummary(
    Map<String, String> records) {
  var o = 0, e = 0, aUp = 0;
  for (final g in records.values) {
    if (g == 'O') o++;
    if (g == 'E') e++;
    if (g == 'O' || g == 'E' || g == 'A') aUp++;
  }
  return (oCount: o, eCount: e, aPlusCount: aUp);
}
