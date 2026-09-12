#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHANGELOG="$PROJECT_DIR/CHANGELOG.md"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"

if [ ! -f "$PUBSPEC" ]; then
  echo "Error: pubspec.yaml not found at $PUBSPEC"
  exit 1
fi
if [ ! -f "$CHANGELOG" ]; then
  echo "Error: CHANGELOG.md not found at $CHANGELOG"
  exit 1
fi

VERSION=$(grep '^version:' "$PUBSPEC" | awk '{print $2}' | cut -d+ -f1)
DATE=$(date +%Y-%m-%d)

if [ -z "$VERSION" ]; then
  echo "Error: Could not read version from pubspec.yaml"
  exit 1
fi

if grep -q "### v${VERSION}" "$CHANGELOG"; then
  echo "✅ Changelog for v${VERSION} already exists in CHANGELOG.md"
  exit 0
fi

DESCRIPTION=""

# Priority 1: UPDATE_DESC.md file
DESCRIPTION_FILE="$PROJECT_DIR/UPDATE_DESC.md"
if [ -f "$DESCRIPTION_FILE" ] && [ -s "$DESCRIPTION_FILE" ]; then
  DESCRIPTION=$(cat "$DESCRIPTION_FILE")
  rm -f "$DESCRIPTION_FILE"
# Priority 2: Command line argument
elif [ -n "$*" ]; then
  DESCRIPTION="$*"
# Priority 3: Auto-generate from git log (last commit)
elif command -v git &> /dev/null && git -C "$PROJECT_DIR" rev-parse --git-dir &> /dev/null; then
  LAST_COMMIT=$(git -C "$PROJECT_DIR" log -1 --format='%s' 2>/dev/null)
  LAST_BODY=$(git -C "$PROJECT_DIR" log -1 --format='%b' 2>/dev/null)
  if [ -n "$LAST_COMMIT" ]; then
    DESCRIPTION="**📋 变更说明**
$LAST_COMMIT
"
    if [ -n "$LAST_BODY" ]; then
      # Take first 5 lines of body
      BODY_LINES=$(echo "$LAST_BODY" | head -5)
      if [ -n "$BODY_LINES" ]; then
        DESCRIPTION="${DESCRIPTION}
${BODY_LINES}"
      fi
    fi
  else
    DESCRIPTION="**🔧 代码更新**
- 常规代码更新与优化"
  fi
else
  DESCRIPTION="**🔧 代码更新**
- 常规代码更新与优化"
fi

ENTRY_FILE=$(mktemp)
{
  echo "### v${VERSION} — ${DATE}"
  echo ""
  echo "$DESCRIPTION"
  echo ""
} > "$ENTRY_FILE"

export PROJECT_DIR VERSION ENTRY_FILE

python3 << 'PYEOF'
import os

project_dir = os.environ["PROJECT_DIR"]
version = os.environ["VERSION"]
entry_file = os.environ["ENTRY_FILE"]

os.chdir(project_dir)

with open("CHANGELOG.md", "r", encoding="utf-8") as f:
    content = f.read()

with open(entry_file, "r", encoding="utf-8") as f:
    new_entry = f.read().rstrip("\n")

# 新版本永远插入在「所有现有版本条目的最顶部」。
# 逻辑：找到全文第一个 "### v" 版本标题的位置（就是当前最新的已有版本），
# 在它之前插入。如果没有任何现有版本条目，则直接追加到文末。
import re

first_h3 = re.search(r"^### v", content, re.MULTILINE)
if first_h3:
    before = content[:first_h3.start()].rstrip("\n")
    after = content[first_h3.start():].lstrip("\n")
    updated = before + "\n\n" + new_entry + "\n\n" + after
else:
    updated = content.rstrip() + "\n\n" + new_entry + "\n"

with open("CHANGELOG.md", "w", encoding="utf-8") as f:
    f.write(updated)

print(f"✅ Changelog for v{version} added to CHANGELOG.md")
PYEOF

rm -f "$ENTRY_FILE"
