/// 6 个 Mixin 的 barrel 文件，供 game_provider.dart 一次性 import。
/// 设计约束：所有 Mixin 必须写 `mixin X on GameProviderBase`，而不能 `on GameProvider`。
/// 因为 GameProvider 又 `with` 这 6 个 Mixin，后者会形成 recursive_interface_inheritance 继承环（Dart 3.x 报错）。
library game_provider_mixins;

export 'mixin_init.dart';
export 'mixin_narrative.dart';
export 'mixin_narrative_continuity.dart';
export 'mixin_commands.dart';
export 'mixin_response.dart';
export 'mixin_response_affection.dart';
export 'mixin_response_choices.dart';
export 'mixin_relations.dart';
export 'mixin_systems.dart';
export 'mixin_play.dart';
