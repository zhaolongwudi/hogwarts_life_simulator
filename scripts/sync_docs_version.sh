#!/bin/bash
# ================================================================
# sync_docs_version.sh — 文档版本同步（Issue #14）
# 作用：把 README.md 的版本 badge 与 PROJECT_GUIDE.md 的「当前版本」
#       同步为 pubspec.yaml 的真实版本号。
# 幂等：版本已一致时不产生任何 diff，可直接重复执行。
# 在 CI 的 Sync changelog 步骤中调用（此时 pubspec 已被 bump 为新版本）。
# ================================================================
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"
README="$PROJECT_DIR/README.md"
GUIDE="$PROJECT_DIR/PROJECT_GUIDE.md"

if [ ! -f "$PUBSPEC" ]; then
  echo "Error: pubspec.yaml not found at $PUBSPEC"
  exit 1
fi

VERSION=$(grep '^version:' "$PUBSPEC" | awk '{print $2}' | cut -d+ -f1)
if [ -z "$VERSION" ]; then
  echo "Error: Could not read version from pubspec.yaml"
  exit 1
fi

CHANGED=0

# ---- README.md 版本 badge：version-vX.Y.Z ----
if [ -f "$README" ]; then
  if grep -q "version-v${VERSION}" "$README"; then
    echo "✅ README.md badge 已是 v${VERSION}，跳过"
  else
    sed -i "s/version-v[0-9][0-9.]*/version-v${VERSION}/" "$README"
    echo "✅ README.md badge 已同步为 v${VERSION}"
    CHANGED=1
  fi
fi

# ---- PROJECT_GUIDE.md 当前版本：vX.Y.Z ----
if [ -f "$GUIDE" ]; then
  if grep -q "当前版本 v${VERSION}" "$GUIDE"; then
    echo "✅ PROJECT_GUIDE.md 当前版本已是 v${VERSION}，跳过"
  else
    sed -i "s/当前版本 v[0-9][0-9.]*/当前版本 v${VERSION}/" "$GUIDE"
    echo "✅ PROJECT_GUIDE.md 当前版本已同步为 v${VERSION}"
    CHANGED=1
  fi
fi

if [ "$CHANGED" = "0" ]; then
  echo "✅ 文档版本全部一致（v${VERSION}），无需改动"
fi
