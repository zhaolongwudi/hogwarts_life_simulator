import 'package:dio/dio.dart';
import '../providers/app_provider.dart';
import '../utils/ai_debug_logger.dart';
import '../data/provider_defaults.dart';
import 'deepseek_service.dart';
import 'ai_timeouts.dart' as timeouts;
// rate_limiter 里除了两个限流闸门，还放了 ResponseCache（响应缓存）——
// 本文件只用到后者。闸门统一由 DeepSeekService._acquireSlot() 负责，这里不要再调。
import 'rate_limiter.dart';
import 'empty_response_monitor.dart';
import '../utils/debug_log.dart';

enum AiScene { narrative, summary, npcChat, choice }

class AiRouterConfig {
  final AiProvider narrativeProvider;
  final AiProvider summaryProvider;
  final AiProvider npcChatProvider;
  final AiProvider choiceProvider;
  final List<AiProvider> fallbackOrder;

  const AiRouterConfig({
    this.narrativeProvider = AiProvider.sensenova,
    this.summaryProvider = AiProvider.sensenova,
    this.npcChatProvider = AiProvider.agnes,
    this.choiceProvider = AiProvider.sensenova,
    this.fallbackOrder = const [AiProvider.sensenova, AiProvider.agnes],
  });

  AiProvider providerFor(AiScene scene) {
    switch (scene) {
      case AiScene.narrative:
        return narrativeProvider;
      case AiScene.summary:
        return summaryProvider;
      case AiScene.npcChat:
        return npcChatProvider;
      case AiScene.choice:
        return choiceProvider;
    }
  }
}

class AiRouter {
  /// 每个提供商可能有多个服务（每个 API Key 一个服务）
  final Map<AiProvider, List<DeepSeekService>> _services = {};
  final Map<AiProvider, List<AiConfig>> _configs = {};
  final AiRouterConfig _config;
  final _responseCache = ResponseCache.instance;
  int _roundRobinIndex = 0; // 轮询索引，用于随机选择多 key

  // ====== 单 Key 熔断 ======
  // 一个坏 Key 若每回合都走完整惩罚流程，会持续偷走时间预算、拖垮健康 Key。
  // 连续失败达到阈值后该 Key 进入冷却窗口，窗口内直接跳过；窗口过后的下一次
  // 请求作为半开试探，成功即清零恢复。
  static const int _circuitThreshold = 3;
  static const Duration _circuitCooldown = Duration(seconds: 60);

  /// 熔断阈值与冷却窗口，公开给测试：用例不该自己抄一份 3 / 60s，
  /// 否则调参时测试假红、不调参时又形同虚设。
  static int get circuitThreshold => _circuitThreshold;
  static Duration get circuitCooldown => _circuitCooldown;
  /// 单次 Key 调用的超时上限，**按提供商区分**。
  ///
  /// 实现已收口到 `ai_timeouts.dart`（F48 单一来源），这里保留转发入口：
  /// 调用点与测试引用 `AiRouter.perCallTimeoutFor` / `perCallTimeoutOverride`
  /// 不变，策略数字只在一处维护。
  static Duration? get perCallTimeoutOverride => timeouts.perCallTimeoutOverride;
  static set perCallTimeoutOverride(Duration? v) =>
      timeouts.perCallTimeoutOverride = v;

  static Duration perCallTimeoutFor(AiProvider provider) =>
      timeouts.perCallTimeoutFor(provider);

  /// 所有 provider 里最长的单次调用超时。全局超时按它取上界，
  /// 保证算出来的预算对任何 provider 都成立。
  static Duration get _maxPerCallTimeout => timeouts.maxPerCallTimeout;

  /// 每个 Key 最多重试几次（0 = 只尝试 1 次）。
  ///
  /// 设为 **0** 是刻意的，不是偷懒。一旦允许重试，单个 Key 的最坏耗时就变成
  /// perCallTimeout×(重试数+1)+退避：2 次重试是 50×3+6 = 156s，1 次也有 102s，
  /// 而按这个预算倒推的全局超时在 summary 场景上限只有 60s、narrative 120s——
  /// 容不下。于是第一个坏 Key 就能把时间吃光，后面的 Key 一次都轮不到，
  /// 熔断也记不满（第七轮 P0-3 的老问题换个形式复发，第八次审查 P1-D）。
  ///
  /// 不重试之后，单 Key 预算恒等于一次 perCallTimeout，全局超时**在任何场景
  /// 都真正容得下每个 Key**。容错交给另外两件事：切下一个 Key，以及熔断。
  static const int _maxRetriesPerService = 0;
  /// 重试的指数退避基数：第 n 次重试等 n * 2s。当前重试次数为 0，故恒为 0；
  /// 保留它是为了让 [perKeyBudgetFor] 在调大重试次数时自动跟随，而不是去改
  /// 一个写死的预算常数。
  static const int _retryBackoffMsStep = 2000;

  final Map<DeepSeekService, _KeyCircuit> _circuits = {};

  /// 测试注入点：直接给定每个提供商的 Key 列表，绕开真实网络。
  ///
  /// 以前 `_services` 只能在 register() 里用真实 AiConfig 构造，
  /// 熔断 / 故障转移这两条主动脉没有任何测试能覆盖——
  /// 第六次审查实测「AI 异常路径」行为测试为 0 就是这个原因。
  AiRouter(this._config, {Map<AiProvider, List<DeepSeekService>>? services}) {
    if (services != null) {
      for (final entry in services.entries) {
        if (entry.value.isEmpty) continue;
        _services[entry.key] = List<DeepSeekService>.of(entry.value);
        _configs[entry.key] = entry.value
            .map((s) => AiConfig(
                  provider: entry.key,
                  apiKey: s.config.apiKey,
                  baseUrl: s.config.baseUrl,
                  model: s.config.model,
                  chatPath: s.config.chatPath,
                  balancePath: s.config.balancePath,
                ))
            .toList();
      }
    }
  }

  /// 一个坏 Key 从第一次尝试到放弃，最多要吃掉多少时间预算。
  ///
  /// 公式保持通用（重试次数与退避都是参数），当前 [_maxRetriesPerService] 为 0，
  /// 所以它就等于一次 [_maxPerCallTimeout]。
  ///
  /// 以前这里按「只算 1 次超时 + 退避」得出 41s，而非超时错误其实还会重试
  /// 2 次，真实最坏序列是 35+2+35+4+35 = 111s —— 预算公式与自己要估的东西
  /// 差了 2.7 倍，据此倒推的全局超时（60s）根本容不下（第八次审查 P1-D）。
  /// 现在公式与 [globalTimeoutFor] 用同一个参数算，两者不会再各说各话。
  static Duration perKeyBudgetFor(int keyCount) {
    final perCall = _maxPerCallTimeout;
    final calls = _maxRetriesPerService + 1;
    final backoff = Duration(
        milliseconds: _retryBackoffMsStep *
            (_maxRetriesPerService * (_maxRetriesPerService + 1) ~/ 2));
    return perCall * calls + backoff;
  }

  /// 全局超时必须按「实际配置的 Key 数」算，而不是写死一个 75 秒。
  ///
  /// 以前 narrative 固定 75s，而单个 Key 的惩罚序列是
  /// 35s + 2s + 35s + 4s + 35s = 111s：第一个坏 Key 跑到第二三次尝试时
  /// 全局超时就先炸，后面的 Key 一次都轮不到，_recordFailure 也记不满 3 次，
  /// 熔断阈值永远达不到——加熔断时忘了删全局超时，熔断被自己人架空。
  ///
  /// 现在按 keyCount 给预算（每个 Key 一份 _perKeyBudget + 尾部余量），
  /// 再按场景 clamp 到上下限：玩家最多等 ceil 秒，但健康 Key 一定能轮到。
  static Duration globalTimeoutFor(AiScene scene, int keyCount) {
    final keys = keyCount < 1 ? 1 : keyCount;
    final raw =
        const Duration(seconds: 5) + perKeyBudgetFor(keys) * keys;
    final floor = switch (scene) {
      AiScene.narrative => const Duration(seconds: 60),
      AiScene.choice => const Duration(seconds: 50),
      _ => const Duration(seconds: 35),
    };
    final ceil = switch (scene) {
      AiScene.narrative => const Duration(seconds: 120),
      AiScene.choice => const Duration(seconds: 100),
      _ => const Duration(seconds: 60),
    };
    if (raw < floor) return floor;
    if (raw > ceil) return ceil;
    return raw;
  }

  /// 注册一个 API Key 对应的配置
  void register(AiConfig cfg) {
    (_configs[cfg.provider] ??= []).add(cfg);
    (_services[cfg.provider] ??= []).add(DeepSeekService(config: cfg));
  }

  /// 释放所有底层服务（Dio 连接池）。
  ///
  /// Dio 泄漏修复：GameProvider.updateClient() 每次重建 AiRouter 前调用，
  /// 否则旧的 HttpClient/socket 从不关闭，反复切换 API Key 会泄漏连接。
  /// 测试注入的 MockDio 由 DeepSeekService.close() 内部 try/catch 兜底。
  void dispose() {
    for (final services in _services.values) {
      for (final s in services) {
        s.close();
      }
    }
    _services.clear();
    _configs.clear();
  }
  /// 是否存在任何可用 AI 服务。任一提供商已注册（配置了 key）即可通过 fallback 生成叙事，
  /// 不再只检查主 narrativeProvider，避免「有备用 key 却被挡死」。
  bool get hasNarrativeService => _configs.values.any((list) => list.isNotEmpty);

  bool _circuitOpen(DeepSeekService s) {
    final c = _circuits[s];
    if (c == null || c.failures < _circuitThreshold) return false;
    // 冷却窗口内保持熔断；窗口过后放一次试探（半开）
    return DateTime.now().isBefore(c.openUntil);
  }

  void _recordSuccess(DeepSeekService s) {
    final c = _circuits[s];
    if (c != null) c.failures = 0;
  }

  void _recordFailure(DeepSeekService s) {
    final c = _circuits.putIfAbsent(s, () => _KeyCircuit());
    c.failures++;
    if (c.failures >= _circuitThreshold) {
      c.openUntil = DateTime.now().add(_circuitCooldown);
    }
  }

  /// 本次调用真正会尝试的 Key 数（没配 key 的提供商不算）。
  ///
  /// 全局超时按它算：写死的 75 秒在只有 1 个 Key 时绰绰有余，在 3 个 Key
  /// 时却连第二个 Key 都轮不到。
  int _attemptedKeyCount(AiProvider primary) {
    final candidates = <AiProvider>[primary];
    for (final p in _config.fallbackOrder) {
      if (!candidates.contains(p)) candidates.add(p);
    }
    var n = 0;
    for (final p in candidates) {
      n += _services[p]?.length ?? 0;
    }
    return n;
  }
  /// 正在执行的那条调用链的共享取消令牌。
  ///
  /// Q5：UI 的「取消」按钮通过 [cancelCurrentCall] 掐断它。令牌只在
  /// chatComplete 生命周期内有效，调用结束即清空，避免误取消下一次请求。
  CancelToken? _activeChainToken;
  _CancelBridge? _activeBridge;

  /// Q9：最近一次「模型连续空响应 → 跳过提供商降级」的提示文案。
  ///
  /// 调用方（callDeepSeek）在**成功**拿到结果后读取一次并追加到通知栏，
  /// 随后调用 [clearDegradeNotice] 防重复；失败路径由异常自身的文案兜底
  /// （AiEmptyResponseException.toString 自带换模型建议）。
  String? _lastDegradeNotice;
  String? get lastDegradeNotice => _lastDegradeNotice;
  void clearDegradeNotice() => _lastDegradeNotice = null;

  /// Q9：已提示过降级的「提供商/模型」键集合。
  ///
  /// 模型**持续**不稳定期间（连续空响应未中断），每次叙事都会触发一次降级，
  /// 若每次都刷「换稳定模型」提示就成了弹窗轰炸。只有模型恢复稳定
  /// （一次成功响应清零连续计数）后再次降级，才重新提示。
  final Set<String> _degradeNotified = {};

  String _degradeKey(String provider, String model) => '$provider/$model';

  /// 用户主动取消当前正在执行的调用链（Q5）。
  ///
  /// 掐掉共享令牌 + 通过 bridge 转发给此刻正在跑的那次尝试，底层 HTTP
  /// 请求随之终止。没有进行中的调用时是安全的 no-op。
  void cancelCurrentCall({String reason = '用户取消'}) {
    _activeBridge?.cancelCurrent(reason);
    final token = _activeChainToken;
    if (token != null && !token.isCancelled) {
      token.cancel(reason);
    }
    _activeChainToken = null;
    _activeBridge = null;
  }

  Future<ChatResult> chatComplete({
    required AiScene scene,
    required String prompt,
    String? systemPrompt,
    double temperature = 0.8,
    int maxTokens = 2500,
  }) async {
    // F7：全库此前一处 assert 都没有。这里是最值得断言的入口 ——
    // 这几个条件被破坏时不会立刻崩，而是变成"AI 返回空/半截内容"这种极难定位
    // 的症状（排查成本以小时计）。开发期直接炸在调用点，比事后翻日志便宜得多。
    assert(prompt.isNotEmpty, 'prompt 不能为空：空 prompt 只会白耗一个 Key 预算');
    assert(maxTokens > 0, 'maxTokens 必须为正：收到 $maxTokens');
    assert(temperature >= 0 && temperature <= 2, 'temperature 越界：$temperature');
    final primary = _config.providerFor(scene);
    final timestamp = DateTime.now().toIso8601String();
    final sceneLabel = scene.toString().split('.').last;
    // 调试日志不再截断 prompt/response 重要内容，完整保存
    final promptPreview = prompt;

    // 记录调用开始 → 返回 callId，后续完成阶段用 callId 拼成完整一条
    final callId = await AiDebugLogger.instance.logStart(
      timestamp: timestamp,
      scene: sceneLabel,
      provider: getProviderLabel(primary),
      promptPreview: promptPreview,
      systemPrompt: systemPrompt,
    );

    // cancelToken 是**整条调用链**的取消令牌，只有全局超时才会取消它。
    // 单次尝试另有自己的令牌（见 _callWithFallback），两者通过 bridge 单向连通。
    final cancelToken = CancelToken();
    final bridge = _CancelBridge();
    _activeChainToken = cancelToken;
    _activeBridge = bridge;
    try {
      return await _runChainWithGlobalTimeout(
        scene: scene,
        prompt: prompt,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
        callId: callId,
        cancelToken: cancelToken,
        bridge: bridge,
        primary: primary,
        sceneLabel: sceneLabel,
        keyCount: _attemptedKeyCount(primary),
      );
    } finally {
      // 调用链结束（无论成败/取消）都要摘掉活动令牌，
      // 否则下一次请求会误取消到上一次的令牌（Q5）。
      if (_activeChainToken == cancelToken) _activeChainToken = null;
      if (identical(_activeBridge, bridge)) _activeBridge = null;
    }
  }

  /// chatComplete 的主体：起调用链 future + 按场景挂全局超时。
  ///
  /// 拆出来单独成方法，是为了让 chatComplete 能用 try/finally 管理
  /// [_activeChainToken]/[_activeBridge] 的生命周期，同时保持超时逻辑
  /// 与原先完全一致。
  Future<ChatResult> _runChainWithGlobalTimeout({
    required AiScene scene,
    required String prompt,
    String? systemPrompt,
    required double temperature,
    required int maxTokens,
    required String? callId,
    required CancelToken cancelToken,
    required _CancelBridge bridge,
    required AiProvider primary,
    required String sceneLabel,
    required int keyCount,
  }) async {
    final future = _callWithFallback(
      primary: primary,
      prompt: prompt,
      systemPrompt: systemPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
      useCache: scene != AiScene.narrative && scene != AiScene.choice,
      scene: scene,
      callId: callId,
      cancelToken: cancelToken,
      cancelBridge: bridge,
    );

    // 全局超时按「实际会尝试的 Key 数」动态算，而不是写死一个值——
    // 写死 75s 时，3 个 Key 的惩罚序列（111s）会在第二个 Key 还没上场前
    // 就被掐断，熔断永远达不到阈值（详见 globalTimeoutFor 的注释）。
    final globalTimeout = globalTimeoutFor(scene, keyCount);
    final seconds = globalTimeout.inSeconds;

    Future<ChatResult> withGlobalTimeout(String label, String errorText) {
      return future.timeout(
        globalTimeout,
        onTimeout: () async {
          cancelToken.cancel('$label timeout');
          // 内层每次尝试用的是自己的令牌，共享令牌取消不到它——必须显式
          // 转发一次，否则全局超时之后那次请求还在后台继续跑、占着连接。
          bridge.cancelCurrent();
          await AiDebugLogger.instance.logComplete(
            callId: callId,
            timestamp: DateTime.now().toIso8601String(),
            scene: sceneLabel,
            provider: getProviderLabel(primary),
            action: 'TIMEOUT',
            error: errorText,
          );
          throw AiRetryableException(errorText, isTimeout: true);
        },
      );
    }

    if (scene == AiScene.narrative) {
      return withGlobalTimeout('narrative',
          '剧情生成超时（${seconds}秒，共 $keyCount 个 Key），请重试或切换提供商');
    }
    if (scene == AiScene.choice) {
      return withGlobalTimeout('choice', '选项生成超时（${seconds}秒），请重试');
    }
    // summary / npcChat 之前没有超时：最坏 2 provider × N key × 3 次 × 45s，
    // UI 会长时间转圈。这里给一个整体兜底超时（同样按 Key 数算）。
    return withGlobalTimeout(
        'summary/npcChat', '摘要/闲聊生成超时（${seconds}秒），请重试');
  }

  Future<ChatResult> _callWithFallback({
    required AiProvider primary,
    required String prompt,
    String? systemPrompt,
    required double temperature,
    required int maxTokens,
    bool useCache = true,
    AiScene? scene,
    String? callId,
    CancelToken? cancelToken,
    _CancelBridge? cancelBridge,
  }) async {
    // 缓存键必须带上「生成者身份」（provider + model）：否则玩家在设置页把模型
    // 从 A 换成 B 之后，5 分钟 TTL 内同一 prompt 会命中 A 的输出——
    // 「换了模型，内容一个字没变」（第八次审查 P1-F）。
    // 因此缓存读写下沉到每个 Key：不同 Key 可能配着不同 model，各用各的缓存。
    String? cacheLookup(AiProvider provider, String model) {
      if (!useCache) return null;
      return _responseCache.get(
        prompt,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
        provider: provider.name,
        model: model,
      );
    }

    // 候选提供商列表：primary 优先，随后按 fallbackOrder 去重。
    final candidates = <AiProvider>[primary];
    for (final p in _config.fallbackOrder) {
      if (!candidates.contains(p)) candidates.add(p);
    }

    // 真正会被尝试的候选：没配 key 的会被下面 continue 跳过。
    // 之前 isLastKey 直接比 `provider == candidates.last`，
    // 一旦名单最后一位没配 key，就永远轮不到 isLastKey=true——
    // 所有失败都记成 FALLBACK、keepPending 恒为真，
    // 那条标记整个调用链彻底失败的 ERROR 日志一次都写不出来，
    // 排查时只能看到一串"降级"却看不到终局。
    final attempted = candidates
        .where((p) => (_services[p]?.length ?? 0) > 0)
        .toList(growable: false);

    // 同一把 Key 的重试次数。当前为 0 —— 一把 Key 一次调用只点一次，失败就让位
    // 给下一个 Key。原因：重试会把单 Key 最坏耗时翻倍，让 perKeyBudget 失去
    // 意义（第八次审查 P1-D）。改这个值前请先看 [perKeyBudgetFor] 的注释。
    const maxRetriesPerService = _maxRetriesPerService;

    // 整条链上一共几个 Key。只有「没别人可切」时才值得退避重试同一把。
    final totalKeyCount =
        attempted.fold<int>(0, (n, p) => n + (_services[p]?.length ?? 0));

    Object? lastError;
    // Q9：连续空响应 = 模型不稳定，跳过该提供商**全部** Key 直接降级到
    // 下一个提供商。用 label 从内层 Key 循环直接跳出外层提供商循环。
    providers: for (final provider in attempted) {
      final services = _services[provider]!;

      // 轮询选择起始 key，避免每次从头开始（让多个 key 均匀分配流量）
      _roundRobinIndex = (_roundRobinIndex + 1) % services.length;
      // 从轮询起始点开始，遍历所有 key
      for (int ki = 0; ki < services.length; ki++) {
        final serviceIdx = (_roundRobinIndex + ki) % services.length;
        final service = services[serviceIdx];
        final keyHash = service.config.apiKey.length > 8
            ? service.config.apiKey.substring(0, 8)
            : service.config.apiKey;

        // 命中缓存就直接返回，不再发请求
        final cached = cacheLookup(provider, service.config.model);
        if (cached != null) {
          final cacheSceneLabel = scene?.toString().split('.').last ?? 'unknown';
          await AiDebugLogger.instance.logComplete(
            callId: callId,
            timestamp: DateTime.now().toIso8601String(),
            scene: cacheSceneLabel,
            provider: '${getProviderLabel(provider)}[$keyHash]',
            action: 'CACHE',
            responsePreview: cached,
          );
          return ChatResult(
            content: cached,
            usage: const TokenUsage(
                promptTokens: 0, completionTokens: 0, totalTokens: 0),
          );
        }

        for (var attempt = 0; attempt <= maxRetriesPerService; attempt++) {
          // Q5：用户取消后链上令牌已掐断，不再发起新的尝试——
          // 否则「取消」与「下一次请求发出」之间出现竞态，玩家点了取消
          // 剧情还是继续生成。
          if (cancelToken?.isCancelled == true) {
            throw AiCanceledException('请求已取消');
          }
          if (_circuitOpen(service)) {
            // 熔断中的 Key 直接跳过，不再点卯
            debugLog('⚠️ ${provider.name}[$keyHash] 熔断中，跳过');
            break;
          }
          // 每次尝试用**自己的** CancelToken。以前整条 Key 链共用一个 token，
          // 单 Key 超时取消的是那个共享 token，于是下面 catch 里的
          // `isCancelled → rethrow` 会直接跳出三层循环：不切下一个 Key、
          // 不记熔断，还抛出「已切换 Key」的假消息——而 perCallTimeout
          // 恒小于 receiveTimeout 决定了生产环境**任何**真实超时都必然走这条
          // 路径（第八次审查 P0）。
          final callToken = CancelToken();
          cancelBridge?.attach(callToken);
          try {
            // 限流闸门在 DeepSeekService.chatComplete 内部（_acquireSlot），
            // 这里不要再加一层，否则同一个 Key 会被两道互不知情的闸门串着等。
            final perCallTimeout = perCallTimeoutFor(provider);
            final result = await service
                .chatComplete(
                  prompt: prompt,
                  systemPrompt: systemPrompt ?? '',
                  temperature: temperature,
                  maxTokens: maxTokens,
                  cancelToken: callToken,
                )
                .timeout(
                  perCallTimeout,
                  onTimeout: () {
                    // 掐断的同时也要撤掉底层请求：以前只 throw 不 cancel，
                    // 那次请求还在后台占着连接继续跑，等它自己收到响应才停。
                    // 现在只取消**这一次**的 token，共享 token 不受影响，
                    // 下面的 catch 才会走正常的「记失败 + 切下一个 Key」。
                    callToken.cancel('per-call timeout');
                    // 秒取整会把测试注入的亚秒超时显示成「0秒」，
                    // 日志里看着像配置没生效，所以短于 1 秒就报毫秒。
                    final budget = perCallTimeout.inSeconds >= 1
                        ? '${perCallTimeout.inSeconds}秒'
                        : '${perCallTimeout.inMilliseconds}毫秒';
                    throw AiRetryableException(
                        '单次 AI 请求超时（$budget）',
                        isTimeout: true);
                  },
                );
            cancelBridge?.detach(callToken);
            _recordSuccess(service);
            // Q9：该模型恢复稳定（连续空响应清零）后，移除降级提示去重键——
            // 下次再降级可以重新提示一次。
            final stableKey =
                _degradeKey(provider.name, service.config.model);
            if (_degradeNotified.contains(stableKey) &&
                !EmptyResponseMonitor.instance
                    .isDegraded(provider.name, service.config.model)) {
              _degradeNotified.remove(stableKey);
            }
            // 缓存成功响应（带上这把 Key 的 provider/model，见上面 cacheLookup）
            if (useCache) {
              _responseCache.set(
                prompt,
                result.content,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens,
                provider: provider.name,
                model: service.config.model,
              );
            }
            final sceneLabel = scene?.toString().split('.').last ?? 'unknown';
            await AiDebugLogger.instance.logComplete(
              callId: callId,
              timestamp: DateTime.now().toIso8601String(),
              scene: sceneLabel,
              provider: getProviderLabel(provider),
              action: 'RESPONSE',
              responsePreview: result.content,
              promptTokens: result.usage.promptTokens,
              completionTokens: result.usage.completionTokens,
              totalTokens: result.usage.totalTokens,
            );
            return result;
          } catch (e) {
            cancelBridge?.detach(callToken);
            // 只有**全局超时**（共享 token 被取消）才放弃整条链往上抛。
            //
            // 单次超时 / 请求失败一律按「这把 Key 不行」处理：记账 + 切下一个。
            // 以前这里看的是共享 token，而 per-call 超时取消的恰恰就是共享
            // token，于是每一次超时都 rethrow —— 后面健康的 Key 一次都不试、
            // _recordFailure 也永远执行不到，熔断计数涨不上去（P0 的三条后果）。
            if (cancelToken?.isCancelled == true) {
              rethrow;
            }

            // ki 是相对轮询起点的偏移量，不是"第几个 key"；但循环覆盖了
            // 全部 serviceIdx，所以 ki 走到最后一轮时确实就是这条链的最后一次尝试。
            // 提前计算：Q9 降级分支与常规失败分支都要用它区分 ERROR/FALLBACK。
            final isLastKey =
                (ki == services.length - 1) && provider == attempted.last;

            // Q9：连续空响应 = 模型不稳定，不是 Key 问题。
            // 不记 Key 熔断（冷却 60 秒对模型质量毫无意义），直接跳过该
            // 提供商全部 Key 降级到备用提供商，并留下「换稳定模型」提示。
            if (e is AiEmptyResponseException) {
              // 只在「该模型首次降级」时设置提示；持续不稳定期间的后续降级
              // 不重复设置（模型恢复稳定后 _recordSuccess 会移除键，重新放行）。
              if (_degradeNotified.add(_degradeKey(e.provider, e.model))) {
                _lastDegradeNotice =
                    '${getProviderLabel(provider)} 模型 ${e.model} 连续'
                    '${EmptyResponseMonitor.degradeThreshold}次空响应，已自动切换备用'
                    '提供商；若频繁出现，建议在设置页更换稳定模型';
              }
              debugLog('⚠️ ${provider.name}[$keyHash] ${e.model} 连续空响应，'
                  '跳过整个提供商降级: $e');
              final degradeSceneLabel =
                  scene?.toString().split('.').last ?? 'unknown';
              await AiDebugLogger.instance.logComplete(
                callId: callId,
                timestamp: DateTime.now().toIso8601String(),
                scene: degradeSceneLabel,
                provider: '${getProviderLabel(provider)}[$keyHash]',
                action: isLastKey ? 'ERROR' : 'FALLBACK',
                error: e.toString(),
                keepPending: !isLastKey,
              );
              lastError = e;
              continue providers; // 跳过本提供商剩余 Key，降级到下一个提供商
            }

            // Q9：偶发空响应同样是模型质量问题，不记 Key 熔断——否则模型
            // 连续空 3 次（刚够判定不稳定）之前，Key 先被 60 秒冷却，换模型
            // 后冷却还在，白等。
            final isEmptyResponse = e is AiEmptyRetryableException;
            lastError = e;
            if (!isEmptyResponse) {
              _recordFailure(service);
            }

            // 可重试错误且还有重试机会：指数退避后重试同一 key。
            //
            // 但**超时不重试**：对端这会儿就是慢，再试一次只会再吃满一个
            // perCallTimeout 窗口。有多个 Key 时连非超时错误也不重试——直接
            // 换人，把预算留给别的 Key（理由见 perKeyBudgetFor 的注释）。
            // 偶发空响应也不重试：mixin 层已有「强化指令重试」接管，路由层
            // 重试同 Key 只会再拿一次空输出。
            final timedOut = e is AiRetryableException && e.isTimeout;
            if (!timedOut &&
                !isEmptyResponse &&
                totalKeyCount <= 1 &&
                e is AiRetryableException &&
                attempt < maxRetriesPerService) {
              final backoffMs = (attempt + 1) * _retryBackoffMsStep;
              debugLog('⚠️ ${provider.name}[$keyHash] 第${attempt + 1}次失败，${backoffMs}ms后重试: $e');
              await Future.delayed(Duration(milliseconds: backoffMs));
              continue;
            }

            // 当前 key 所有重试耗尽，记录日志并尝试下一个 key
            debugLog('⚠️ ${provider.name}[$keyHash] 已耗尽，尝试下一个 Key: $e');
            final sceneLabel = scene?.toString().split('.').last ?? 'unknown';
            await AiDebugLogger.instance.logComplete(
              callId: callId,
              timestamp: DateTime.now().toIso8601String(),
              scene: sceneLabel,
              provider: '${getProviderLabel(provider)}[$keyHash]',
              action: isLastKey ? 'ERROR' : 'FALLBACK',
              error: e.toString(),
              keepPending: !isLastKey,
            );
            break; // 切到下一个 key
          }
        }
      }
    }

    if (lastError != null) throw lastError;
    // 能走到这里，说明所有候选 Key 都被跳过了（全部处在熔断冷却窗口）——这和
    // 「一个 Key 都没配」是两回事：前者等 60 秒冷却就好，后者得去设置页填 Key。
    // 以前一律抛「所有AI服务均不可用」，玩家会去查 API Key，方向完全相反
    // （第八次审查 P2-8）。
    if (totalKeyCount == 0) {
      throw AiNonRetryableException('尚未配置任何 AI 服务，请在设置页填写 API Key');
    }
    throw AiNonRetryableException(
        '全部 $totalKeyCount 个 Key 都在熔断冷却中（${_circuitCooldown.inSeconds}秒后自动恢复），请稍后再试');
  }

  /// 提供商展示名。表在 lib/data/provider_defaults.dart 的 displayName 字段
  /// （设置页卡片用的是同一个值，以前这里是手抄的第二份）。
  String getProviderLabel(AiProvider provider) =>
      providerDisplayName(provider.name);

  }

/// 把「整条调用链的取消」单向转发给「当前正在跑的那一次尝试」。
///
/// 内层每次尝试持有自己的 CancelToken（否则单 Key 超时会炸掉整条链，见
/// _callWithFallback 的注释），全局超时取消的却是外层那个共享 token，两者
/// 互不知情。这个桥就是中间那根线：外层取消时，把取消传给此刻挂着的那个
/// 单次令牌，避免超时之后请求还在后台继续跑。
class _CancelBridge {
  CancelToken? _current;

  void attach(CancelToken token) => _current = token;

  /// 只在自己仍是「当前」时才摘除，避免把后挂上来的那次尝试误摘掉。
  void detach(CancelToken token) {
    if (_current == token) _current = null;
  }

  void cancelCurrent([String reason = 'cancelled']) {
    final token = _current;
    if (token != null && !token.isCancelled) {
      token.cancel(reason);
    }
  }
}

/// 单个 Key 的熔断状态：连续失败次数 + 熔断窗口截止时间。
class _KeyCircuit {
  int failures = 0;
  DateTime openUntil = DateTime.fromMillisecondsSinceEpoch(0);
}
