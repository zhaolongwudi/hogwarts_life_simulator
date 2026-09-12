#!/bin/bash
# 项目构建环境：本机默认 flutter 是 3.0.0（太老，项目要求 >=3.44.0）
# 用法： source /workspace/src/hogwarts_life_simulator/tools/env.sh
export FLUTTER_ROOT=/opt/flutter_new
export PATH="$FLUTTER_ROOT/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export FLUTTER_GIT_URL=https://ghfast.top/https://github.com/flutter/flutter.git
export FLUTTER_SKIP_VERSION_CHECK=1
