#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
README="$PROJECT_DIR/README.md"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"

if [ ! -f "$PUBSPEC" ]; then
  echo "Error: pubspec.yaml not found at $PUBSPEC"
  exit 1
fi
if [ ! -f "$README" ]; then
  echo "Error: README.md not found at $README"
  exit 1
fi

VERSION=$(grep '^version:' "$PUBSPEC" | awk '{print $2}' | cut -d+ -f1)
DATE=$(date +%Y-%m-%d)

if [ -z "$VERSION" ]; then
  echo "Error: Could not read version from pubspec.yaml"
  exit 1
fi

if grep -q "### v${VERSION}" "$README"; then
  echo "✅ Changelog for v${VERSION} already exists in README.md"
  exit 0
fi

DESCRIPTION_FILE="$PROJECT_DIR/UPDATE_DESC.md"
if [ -f "$DESCRIPTION_FILE" ] && [ -s "$DESCRIPTION_FILE" ]; then
  DESCRIPTION=$(cat "$DESCRIPTION_FILE")
  rm -f "$DESCRIPTION_FILE"
elif [ -n "$*" ]; then
  DESCRIPTION="$*"
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

with open("README.md", "r", encoding="utf-8") as f:
    content = f.read()

with open(entry_file, "r", encoding="utf-8") as f:
    new_entry = f.read().rstrip("\n")

marker = "## 📝 更新日志\n"
if marker in content:
    idx = content.index(marker) + len(marker)
    updated = content[:idx] + "\n" + new_entry + "\n" + content[idx:]
else:
    updated = content.rstrip() + "\n\n" + marker + "\n" + new_entry + "\n"

with open("README.md", "w", encoding="utf-8") as f:
    f.write(updated)

print(f"✅ Changelog for v{version} added to README.md")
PYEOF

rm -f "$ENTRY_FILE"
