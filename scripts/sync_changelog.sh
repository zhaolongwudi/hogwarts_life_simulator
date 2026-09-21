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

# ================================================================
# 同步 README 的「最近更新」表（只保留最近 5 条版本概要）。
# 此前 README 更新表是手工硬编码，CI 只写 CHANGELOG，导致首页更新列表
# 永远停在手工维护时的版本——现在每次 CI 同步 CHANGELOG 后自动重写。
# ================================================================
export PROJECT_DIR VERSION
python3 << 'PYEOF'
import os, re
project_dir = os.environ["PROJECT_DIR"]
os.chdir(project_dir)

changelog = open("CHANGELOG.md", encoding="utf-8").read()
readme_path = "README.md"

# 解析顶部版本块（### vX.Y.Z 开头，到下一个 ### v 或文末）
blocks = re.findall(r"### v([\d.]+)[^\n]*\n(.*?)(?=### v|\Z)", changelog, flags=re.S)
rows = []
for ver, body in blocks[:5]:
    lines = [ln.strip() for ln in body.strip("\n").split("\n") if ln.strip()]
    summary = ""
    for ln in lines:
        # 跳过 **📋 变更说明** 这类装饰行，取第一条真实内容
        if ln.startswith("**") and ln.endswith("**"):
            continue
        summary = ln
        break
    if not summary:
        summary = "常规更新"
    if len(summary) > 70:
        summary = summary[:67] + "…"
    rows.append(f"| **v{ver}** | {summary} |")

if not rows:
    print("⚠️ 未能从 CHANGELOG 解析版本，跳过 README 更新表同步")
    raise SystemExit(0)

new_table = "| 版本 | 概要 |\n|------|------|\n" + "\n".join(rows)

readme = open(readme_path, encoding="utf-8").read()
# 定位「**最近更新：**」之后的表格区（| 版本 | 概要 | 开头，到下一个空行或 > 版本策略）
marker = "**最近更新：**"
idx = readme.find(marker)
if idx == -1:
    print("⚠️ README 未找到「最近更新：」标记，跳过更新表同步")
    raise SystemExit(0)

start = readme.find("| 版本 | 概要 |", idx)
if start == -1:
    print("⚠️ README 未找到更新表头，跳过更新表同步")
    raise SystemExit(0)
# 表格结束：下一个空行或「> 版本策略」
end = start
while end < len(readme):
    line_end = readme.find("\n", end)
    if line_end == -1:
        end = len(readme)
        break
    line = readme[end:line_end].strip()
    if line == "" or line.startswith(">"):
        end = end  # 空行/> 行前就是表格尾
        break
    end = line_end + 1

updated = readme[:start] + new_table + "\n" + readme[end:]
with open(readme_path, "w", encoding="utf-8") as f:
    f.write(updated)
print(f"✅ README 最近更新表已同步（顶部 {len(rows)} 条版本）")
PYEOF
