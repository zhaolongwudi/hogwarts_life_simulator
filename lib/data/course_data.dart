/// 课程数据：依据设定文档「第十部分 · 课堂系统」
import '../providers/app_provider.dart';

class CourseData {
  final String id;
  final String name;
  final String professor;
  final String attribute; // 提升属性键名
  final bool required; // 必修 or 选修
  final int minGrade; // 最低年级

  const CourseData({
    required this.id,
    required this.name,
    required this.professor,
    required this.attribute,
    required this.required,
    this.minGrade = 1,
  });
}

/// 必修课（所有年级）
const List<CourseData> requiredCourses = [
  CourseData(
      id: 'transfiguration',
      name: '变形术',
      professor: '米勒娃·麦格',
      attribute: 'transfiguration',
      required: true),
  CourseData(
      id: 'charms',
      name: '魔咒学',
      professor: '菲利乌斯·弗立维',
      attribute: 'spell_understanding',
      required: true),
  CourseData(
      id: 'dda',
      name: '黑魔法防御术',
      professor: '奇洛/洛哈特/卢平等',
      attribute: 'dda',
      required: true),
  CourseData(
      id: 'potions',
      name: '魔药学',
      professor: '西弗勒斯·斯内普',
      attribute: 'potions',
      required: true),
  CourseData(
      id: 'herbology',
      name: '草药学',
      professor: '波莫娜·斯普劳特',
      attribute: 'herbology',
      required: true),
  CourseData(
      id: 'astronomy',
      name: '天文学',
      professor: '奥罗拉·辛尼斯塔',
      attribute: 'theory',
      required: true),
  CourseData(
      id: 'history',
      name: '魔法史',
      professor: '宾斯教授',
      attribute: 'memory',
      required: true),
  CourseData(
      id: 'flying',
      name: '飞行课（一年级）',
      professor: '罗兰达·霍琦',
      attribute: 'flying',
      required: true),
];

/// 选修课（三年级起，至少选2门）
const List<CourseData> electiveCourses = [
  CourseData(
      id: 'arithmancy',
      name: '算术占卜',
      professor: '塞蒂玛·维克多',
      attribute: 'logic',
      required: false,
      minGrade: 3),
  CourseData(
      id: 'runes',
      name: '古代如尼文研究',
      professor: '芭丝茜达·芭布玲',
      attribute: 'memory',
      required: false,
      minGrade: 3),
  CourseData(
      id: 'divination',
      name: '占卜学',
      professor: '西比尔·特里劳妮',
      attribute: 'intuition',
      required: false,
      minGrade: 3),
  CourseData(
      id: 'care_of_magical_creatures',
      name: '保护神奇生物',
      professor: '鲁伯·海格（1994年起）',
      attribute: 'observation',
      required: false,
      minGrade: 3),
  CourseData(
      id: 'muggle_studies',
      name: '麻瓜研究',
      professor: '凯瑞迪·布巴吉',
      attribute: 'creativity',
      required: false,
      minGrade: 3),
];

List<CourseData> allCourses() => [...requiredCourses, ...electiveCourses];

/// 课堂互动环节（设定 10.3）
const List<String> classInteractionSteps = [
  '课堂签到（影响期末成绩与教授好感）',
  '理论知识提问（影响学术声望）',
  '实践操作（影响技能熟练度）',
  '与同桌/邻座互动（影响NPC好感度）',
];

/// 课堂事件（设定 10.3）
class ClassEvent {
  final String type;
  final String trigger;
  final String effect;
  const ClassEvent({
    required this.type,
    required this.trigger,
    required this.effect,
  });
}

const List<ClassEvent> classEvents = [
  ClassEvent(type: '教授提问', trigger: '随机触发', effect: '正确回答：声望+2，熟练度+1'),
  ClassEvent(type: '魔药事故', trigger: '魔药课操作失误', effect: '可能受伤，需去校医院'),
  ClassEvent(type: '决斗练习', trigger: '黑魔法防御课', effect: '提升战斗声望'),
  ClassEvent(type: '温室意外', trigger: '草药课', effect: '被曼德拉草叫喊击中'),
  ClassEvent(type: '深夜天文观测', trigger: '天文课（夜晚）', effect: '可触发浪漫事件'),
];

/// 各时代教授阵容名称（用于叙事上下文）
const Map<String, String> eraHeadmaster = {
  'dumbledore': '阿芒多·迪佩特',
  'marauders': '阿芒多·迪佩特（早期）→ 阿不思·邓布利多',
  'harry_same': '阿不思·邓布利多',
  'post_war': '米勒娃·麦格',
};

/// 同一门课在不同时代由谁授课。
/// 用于 formatCourses 展示，避免把 1991 子世代的教授名单套到其他时代
/// （例如 1892 邓布利多时代出现斯内普、1971 掠夺者时代出现少年斯内普当教授）。
const Map<String, Map<Era, String>> professorByEra = {
  'dda': {
    Era.dumbledore: '时任黑魔法防御术教授',
    Era.marauders: '某位神秘（甚至有吸血鬼传闻）的黑魔法防御术教授',
    Era.first_war: '某位神秘（甚至有吸血鬼传闻）的黑魔法防御术教授',
    Era.harry_same: '奇洛/洛哈特/卢平等',
    Era.post_war: '威廉·威克斯',
    Era.random: '临时就任的黑魔法防御术教授',
  },
  'potions': {
    Era.dumbledore: '霍勒斯·斯拉格霍恩',
    Era.marauders: '霍勒斯·斯拉格霍恩',
    Era.first_war: '霍勒斯·斯拉格霍恩',
    Era.harry_same: '西弗勒斯·斯内普',
    Era.post_war: '霍勒斯·斯拉格霍恩',
    Era.random: '西弗勒斯·斯内普',
  },
};

/// 返回指定课程在指定时代实际授课的教授名，未特化的课程回退到默认值。
String professorName(String courseId, String fallback, Era era) {
  final map = professorByEra[courseId];
  if (map == null) return fallback;
  return map[era] ?? fallback;
}
