#!/bin/bash
# ================================================================
# check_docs_version.sh — 文档版本一致性门禁（Issue #14）
# 作用：校验 README.md 版本 badge 与 PROJECT_GUIDE.md「当前版本」
#       是否与 pubspec.yaml 的真实版本一致。不一致则 exit 1（CI 标红）。
# 在 CI 的 Bump version 之前执行：此时仓库处于 checkout 原始状态，
# 若本次提交存在版本漂移会立刻暴露，提示先运行 sync_docs_version.sh。
# ================================================================
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"
README="$PROJECT_DIR/README.md"
GUIDE="$PROJECT_DIR/PROJECT_GUIDE.md"

VERSION=$(grep '^version:' "$PUBSPEC" | awk '{print $2}' | cut -d+ -f1)
if [ -z "$VERSION" ]; then
  echo "Error: Could not read version from pubspec.yaml"
  exit 1
fi

FAIL=0

if [ ! -f "$README" ]; then
  echo "❌ README.md 不存在"
  FAIL=1
elif ! grep -q "version-v${VERSION}" "$README"; then
  echo "❌ README.md 版本 badge 不是 v${VERSION}（当前 pubspec 版本）"
  FAIL=1
else
  echo "✅ README.md badge = v${VERSION}"
fi

if [ ! -f "$GUIDE" ]; then
  echo "❌ PROJECT_GUIDE.md 不存在"
  FAIL=1
elif ! grep -q "当前版本 v${VERSION}" "$GUIDE"; then
  echo "❌ PROJECT_GUIDE.md 当前版本不是 v${VERSION}（当前 pubspec 版本）"
  FAIL=1
else
  echo "✅ PROJECT_GUIDE.md 当前版本 = v${VERSION}"
fi

if [ "$FAIL" = "1" ]; then
  echo ""
  echo "⚠️  检测到文档版本漂移，请先运行：bash scripts/sync_docs_version.sh"
  echo "    （或将 README/PROJECT_GUIDE 版本号手动同步为 pubspec 的 v${VERSION}）"
  exit 1
fi

echo "✅ 文档版本一致性检查通过（v${VERSION}）"
