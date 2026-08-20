#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

README="$PROJECT_DIR/README.md"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"

if [ ! -f "$PUBSPEC" ]; then
  echo "Error: pubspec.yaml not found"
  exit 1
fi

BASE_VERSION=$(grep '^version:' "$PUBSPEC" | awk '{print $2}' | cut -d+ -f1)
BUILD_NUM=$(grep '^version:' "$PUBSPEC" | awk '{print $2}' | cut -d+ -f2)

IFS='.' read -r MAJOR MINOR PATCH <<< "$BASE_VERSION"

if [ "$PATCH" -ge 9 ]; then
  PATCH=0
  MINOR=$((MINOR + 1))
else
  PATCH=$((PATCH + 1))
fi

if [ "$MINOR" -ge 10 ]; then
  MINOR=0
  MAJOR=$((MAJOR + 1))
fi

BUILD_NUM=$((BUILD_NUM + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}+${BUILD_NUM}"

sed -i "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC"
echo "📦 版本号: $BASE_VERSION -> ${MAJOR}.${MINOR}.${PATCH}+${BUILD_NUM}"

DESCRIPTION=""
DATE=$(date +%Y-%m-%d)

if [ $# -gt 0 ]; then
  DESCRIPTION="$*"
else
  LAST_MSG=$(git log --format=%s -1 2>/dev/null || echo "")
  if [ -n "$LAST_MSG" ]; then
    DESCRIPTION="**📋 提交说明**
$LAST_MSG"
  else
    DESCRIPTION="**🔧 代码更新**
- 常规代码更新与优化"
  fi
fi

ENTRY_FILE=$(mktemp)
{
  echo "### v${MAJOR}.${MINOR}.${PATCH} — ${DATE}"
  echo ""
  echo "$DESCRIPTION"
  echo ""
} > "$ENTRY_FILE"

export PROJECT_DIR NEW_VERSION ENTRY_FILE MAJOR MINOR PATCH DATE

python3 << 'PYEOF'
import os

project_dir = os.environ["PROJECT_DIR"]
entry_file = os.environ["ENTRY_FILE"]
major = os.environ["MAJOR"]
minor = os.environ["MINOR"]
patch = os.environ["PATCH"]
date = os.environ["DATE"]
version = f"{major}.{minor}.{patch}"

os.chdir(project_dir)

with open("README.md", "r", encoding="utf-8") as f:
    content = f.read()

with open(entry_file, "r", encoding="utf-8") as f:
    new_entry = f.read().rstrip("\n")

if f"### v{version}" in content:
    print(f"⚠️  Changelog for v{version} already exists, skipping")
else:
    marker = "## 📝 更新日志\n"
    if marker in content:
        idx = content.index(marker) + len(marker)
        updated = content[:idx] + "\n" + new_entry + "\n" + content[idx:]
    else:
        updated = content.rstrip() + "\n\n" + marker + "\n" + new_entry + "\n"

    with open("README.md", "w", encoding="utf-8") as f:
        f.write(updated)

    print(f"✅ 更新日志 v{version} 已写入 README.md")

PYEOF

rm -f "$ENTRY_FILE"
