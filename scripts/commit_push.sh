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

DATE=$(date +%Y-%m-%d)

# Generate readable changelog from user input or git diff
DESCRIPTION=""
if [ $# -gt 0 ]; then
  DESCRIPTION="$*"
else
  # Auto-generate from git diff summary
  CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null || echo "")
  if [ -z "$CHANGED_FILES" ]; then
    CHANGED_FILES=$(git diff --name-only --cached 2>/dev/null || echo "")
  fi

  if [ -n "$CHANGED_FILES" ]; then
    DESCRIPTION="**🔧 本次更新内容**\n"

    # Categorize changes
    UI_CHANGES=""
    FEATURE_CHANGES=""
    BUGFIX_CHANGES=""
    CONFIG_CHANGES=""
    OTHER_CHANGES=""

    while IFS= read -r file; do
      [ -z "$file" ] && continue
      case "$file" in
        */screens/*)
          if echo "$file" | grep -qiE "screen|ui|page"; then
            UI_CHANGES="${UI_CHANGES}- 🎨 界面调整: $(basename $file .dart)\n"
          else
            FEATURE_CHANGES="${FEATURE_CHANGES}- ✨ 功能更新: $(basename $file .dart)\n"
          fi
          ;;
        */services/*)
          FEATURE_CHANGES="${FEATURE_CHANGES}- ⚙️ 服务优化: $(basename $file .dart)\n"
          ;;
        */providers/*)
          FEATURE_CHANGES="${FEATURE_CHANGES}- 🧠 逻辑更新: $(basename $file .dart)\n"
          ;;
        */models/*)
          FEATURE_CHANGES="${FEATURE_CHANGES}- 📦 数据模型: $(basename $file .dart)\n"
          ;;
        */data/*)
          FEATURE_CHANGES="${FEATURE_CHANGES}- 📚 数据更新: $(basename $file .dart)\n"
          ;;
        *.yml|*.yaml)
          CONFIG_CHANGES="${CONFIG_CHANGES}- ⚙️ 构建配置: $(basename $file)\n"
          ;;
        *.sh)
          CONFIG_CHANGES="${CONFIG_CHANGES}- 📜 脚本更新: $(basename $file)\n"
          ;;
        README.md)
          ;;
        *)
          OTHER_CHANGES="${OTHER_CHANGES}- 📝 $file\n"
          ;;
      esac
    done <<< "$CHANGED_FILES"

    [ -n "$UI_CHANGES" ] && DESCRIPTION="${DESCRIPTION}\n**界面优化**\n${UI_CHANGES}"
    [ -n "$FEATURE_CHANGES" ] && DESCRIPTION="${DESCRIPTION}\n**功能与逻辑**\n${FEATURE_CHANGES}"
    [ -n "$BUGFIX_CHANGES" ] && DESCRIPTION="${DESCRIPTION}\n**问题修复**\n${BUGFIX_CHANGES}"
    [ -n "$CONFIG_CHANGES" ] && DESCRIPTION="${DESCRIPTION}\n**配置与脚本**\n${CONFIG_CHANGES}"
    [ -n "$OTHER_CHANGES" ] && DESCRIPTION="${DESCRIPTION}\n**其他**\n${OTHER_CHANGES}"
  else
    DESCRIPTION="**🔧 代码更新**\n- 常规代码更新与优化"
  fi
fi

# Convert \n to actual newlines
DESCRIPTION=$(echo -e "$DESCRIPTION")

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

echo ""
echo "📋 更新日志预览:"
echo "----------------------------------------"
cat "$ENTRY_FILE" 2>/dev/null || echo "(已写入 README.md)"
echo "----------------------------------------"
