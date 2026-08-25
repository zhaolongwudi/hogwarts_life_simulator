/// R8：宠物叙事配置（去掉 mixin_init.dart / mixin_play.dart 中多处 kyuubi 特判）
///
/// 旧代码中 petId == 'kyuubi' 出现在：
///   - mixin_init.dart L393：importance=9 特判（其它宠物 importance=7）
///   - mixin_init.dart L1084：宠物兜底描述的 switch case
///   - mixin_commands.dart L731：化人形条件特判
///   - mixin_play.dart（化人形触发门槛）
///
/// 现在把这些配置下沉到 PetNarrativeConfig，新增一只「特殊宠物」只加数据。
class PetNarrativeConfig {
  final String petId;

  /// LongTermMemory.keyFacts 中的 importance（普通宠物 7，神话级 9）
  final int memoryImportance;

  /// 羁绊≥多少时触发特殊互动（例如化人形：九尾灵狐 60）
  final int specialInteractionBondThreshold;

  /// 特殊互动描述（给 AI 叙事注入的提示）
  final String? specialInteractionHint;

  /// 化人形/拟人化等能力是否要求达到羁绊阈值
  final bool bondGatedTransform;

  const PetNarrativeConfig({
    required this.petId,
    this.memoryImportance = 7,
    this.specialInteractionBondThreshold = 100,
    this.specialInteractionHint,
    this.bondGatedTransform = false,
  });
}

const Map<String, PetNarrativeConfig> _petNarrativeConfigMap = {
  // ===== 普通宠物（importance 7，化形禁用）=====
  'owl': PetNarrativeConfig(petId: 'owl'),
  'cat': PetNarrativeConfig(petId: 'cat'),
  'toad': PetNarrativeConfig(petId: 'toad'),
  'rat': PetNarrativeConfig(petId: 'rat'),

  // ===== 神话级特殊宠物 =====
  'kyuubi': PetNarrativeConfig(
    petId: 'kyuubi',
    memoryImportance: 9,
    specialInteractionBondThreshold: 60,
    specialInteractionHint: '羁绊≥60后会化为人形，以倾国倾城的女子姿态陪伴主角左右。',
    bondGatedTransform: true,
  ),
};

PetNarrativeConfig petNarrativeConfig(String petId) {
  return _petNarrativeConfigMap[petId] ?? PetNarrativeConfig(petId: petId);
}
