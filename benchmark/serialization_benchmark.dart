// P1：序列化吞吐基准（纯 Dart，可 `dart run benchmark/serialization_benchmark.dart`）。
//
// 覆盖目标：Player 存档对象 toJson / fromJson 往返吞吐 —— 这是存档保存（saveNow）
// 与读档（loadSave）的核心热路径。渲染帧率 / 启动耗时属设备侧指标，见审查文档
// §8.2 P1 的登记理由，需在真机/模拟器上用 profiling 工具测，不在此文件内。
//
// 用法：
//   dart run benchmark/serialization_benchmark.dart
//
// 说明：本文件不 import 任何 Flutter SDK 库（Player 模型链是纯 Dart），
// 因此不依赖 flutter test 环境，普通 dart VM 即可运行。

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:hogwarts_life_simulator/models/player.dart';

/// 构造一份「接近真实存档规模」的 Player JSON。
/// 字段形状对齐 saveNow 产出的 toJson；数值取中等规模，避免基准失真。
Map<String, dynamic> _buildRealisticPlayerJson() {
  return {
    'id': 'p-bench-0001',
    'name': '基准测试巫师',
    'birth_year': '1979',
    'blood_status': 'pureblood',
    'birth_location': '伦敦',
    'personality_traits': ['勇敢', '聪明', '乐观'],
    'attributes': {
      'spell_understanding': 78,
      'transfiguration': 65,
      'potions': 72,
      'herbology': 58,
      'theory': 81,
      'memory': 74,
      'courage': 88,
      'wisdom': 79,
      'loyalty': 70,
      'ambition': 62,
      'social': 66,
      'flying': 60,
      'reaction_time': 69,
    },
    'initial_attributes': {
      'spell_understanding': 50,
      'transfiguration': 50,
      'potions': 50,
      'herbology': 50,
      'theory': 50,
      'memory': 50,
      'courage': 50,
      'wisdom': 50,
      'loyalty': 50,
      'ambition': 50,
      'social': 50,
      'flying': 50,
      'reaction_time': 50,
    },
    'learned_spells': {
      'lumos': {'spell_name': 'lumos', 'level': 2, 'practice_count': 12},
      'expecto_patronum': {
        'spell_name': 'expecto_patronum',
        'level': 1,
        'practice_count': 6,
      },
    },
    'inventory': [
      {
        'id': 'galleon',
        'name': '加隆',
        'description': '',
        'type': 'currency',
      },
      {
        'id': 'wand_holly_phoenix',
        'name': '冬青木魔杖',
        'description': '凤凰羽毛杖芯',
        'type': 'wand',
      },
    ],
    'relationships': {
      'hermione': {
        'target_id': 'hermione',
        'target_name': '赫敏·格兰杰',
        'relation_type': 'friend',
        'level': 72,
        'history': [],
      },
      'ron': {
        'target_id': 'ron',
        'target_name': '罗恩·韦斯莱',
        'relation_type': 'friend',
        'level': 65,
        'history': [],
      },
      'draco': {
        'target_id': 'draco',
        'target_name': '德拉科·马尔福',
        'relation_type': 'rival',
        'level': -30,
        'history': [],
      },
    },
    'current_goal': '通过OWLs',
    'world_line_deviation': 0.18,
    'faculty_rank_id': null,
    'faculty_subject': null,
    'faculty_service_years': 0,
    'faculty_offer_declined': false,
    'health': 92,
    'injuries': ['左手小指旧伤'],
    'scars': [
      {'site': 'face', 'since': '1995 年决斗'},
      {'site': 'wand_arm', 'since': '1995 年禁林'},
    ],
    'wand_id': 'holly_phoenix_11',
    'pet_id': 'hedwig',
    'house': 'gryffindor',
    'grade': 5,
    'magic': 84,
    'spirit': 76,
    'satiety': 80,
    'energy': 65,
    'house_dimensions': {
      'courage': 88,
      'wisdom': 72,
      'loyalty': 70,
      'ambition': 55,
    },
    'gender': '男',
    'signature': '以勇气为咒，以智慧为盾',
    'birth_day': '07-31',
    'sex_orientation': 'heterosexual',
    'appearance': '黑发绿眼，额头有闪电形伤疤',
    'family_background': '纯血世家，父母为傲罗',
    'childhood_experiences': ['在花园里让玩具自己飘起来'],
    'beliefs': '没有绝对的对错，只看立场',
    'initial_talent': '魔咒学天赋',
    'current_job_title': null,
    'magic_aptitude': null,
    'generation': 1,
    'house_preference': 'gryffindor',
    'simulation_style': 'immersive',
    'birth_identity': null,
    'pet_name': '海德薇',
    'pet_bond': 45,
    'love_state': {
      'status': '单身',
      'partner_id': null,
      'partner_name': null,
      'awaiting_confession': false,
      'considering_npc': null,
      'history': [],
    },
    'player_reputation': {
      'academic': 18,
      'social': 21,
      'combat': 26,
      'moral': 32,
      'leadership': 15,
      'dark': 5,
    },
    'house_reputation': 62,
    'diary': [
      {
        'date': '1995-09-01',
        'time': '09:00',
        'title': '开学日',
        'content': '分院帽把我分进了格兰芬多。',
        'mood': '😄',
      },
      {
        'date': '1995-09-15',
        'time': '14:00',
        'title': '第一节魔咒课',
        'content': '第一次让羽毛飘了起来。',
        'mood': '✨',
      },
    ],
    // 其余可选字段缺省走 readX 的 fallback，真实老档也大量缺省。
  };
}

class PlayerRoundTripBenchmark extends BenchmarkBase {
  PlayerRoundTripBenchmark() : super('Player toJson/fromJson 往返');

  late Map<String, dynamic> _json;

  @override
  void setup() {
    _json = _buildRealisticPlayerJson();
  }

  @override
  void run() {
    // 完整往返：反序列化一次 + 序列化一次，模拟「读档→改→存档」。
    final player = Player.fromJson(_json);
    player.toJson();
  }
}

void main() {
  PlayerRoundTripBenchmark().report();
}
