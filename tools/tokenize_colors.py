#!/usr/bin/env python3
"""将 UI 层残存的老 GitHub 配色收敛到 MiuiColors token（值等价映射）。

用法：python3 tools/tokenize_colors.py <file1> [file2...]
只改 Dart 源文件里的 Color(0x…) 构造；品牌语义色（学院红 0xFF740001、
DeepSeek 蓝 0xFF4D6BFE、Agnes 橙 0xFFFF8A3D 等）不在映射表内，保留。

注意：需要手工给每个文件补 `import`（脚本只做有把握的色值替换），
替换后跑 flutter analyze 验证无编译错误。
"""
import re
import sys

MAPPING = {
    "0xFF0d1117": "MiuiColors.background",
    "0xFF0D1117": "MiuiColors.background",
    "0xFF161b22": "MiuiColors.surface",
    "0xFF161B22": "MiuiColors.surface",
    "0xFF21262d": "MiuiColors.surfaceContainer",
    "0xFF21262D": "MiuiColors.surfaceContainer",
    "0xFF252c36": "MiuiColors.surfaceContainer",
    "0xFF252C36": "MiuiColors.surfaceContainer",
    "0xFF1c232d": "MiuiColors.surfaceContainerHigh",
    "0xFF1C232D": "MiuiColors.surfaceContainerHigh",
    "0xFF1a1f2b": "MiuiColors.surfaceContainerHigh",
    "0xFF1A1F2B": "MiuiColors.surfaceContainerHigh",
    "0xFF30363d": "MiuiColors.outline",
    "0xFF30363D": "MiuiColors.outline",
    "0xFF484f58": "MiuiColors.disabledOnSurface",
    "0xFF484F58": "MiuiColors.disabledOnSurface",
    "0xFF8B949E": "MiuiColors.onSurfaceVariantSummary",
    "0xFF8b949e": "MiuiColors.onSurfaceVariantSummary",
    "0xFF6B7280": "MiuiColors.onSurfaceVariantActions",
    "0xFF6b7280": "MiuiColors.onSurfaceVariantActions",
    "0xFFC9D1D9": "MiuiColors.onSurface",
    "0xFFc9d1d9": "MiuiColors.onSurface",
    "0xFFE6EDF3": "MiuiColors.onSurface",
    "0xFFe6edf3": "MiuiColors.onSurface",
    "0xFFD3A625": "MiuiColors.primary",
    "0xFFd3a625": "MiuiColors.primary",
    "0xFF10B981": "MiuiColors.success",
    "0xFF10b981": "MiuiColors.success",
    "0xFFEF4444": "MiuiColors.error",
    "0xFFef4444": "MiuiColors.error",
    "0xFF79C0FF": "MiuiColors.info",
    "0xFF79c0ff": "MiuiColors.info",
}

# withValues 场景不能保留 const 前缀（const MiuiColors.x.withValues 语法非法）
CONST_AWARE = "withValues"


def tokenize(path: str) -> int:
    s = open(path, encoding="utf-8").read()
    orig = s
    n = 0

    # 先处理带 .withValues 的形式（去 const 前缀）
    for hexv, tok in MAPPING.items():
        pat = re.compile(
            r"const\s+Color\(" + hexv + r"\)(?=\s*\.withValues)", re.IGNORECASE
        )
        s, c = pat.subn(tok, s)
        n += c

    # 再处理普通 const Color / Color 构造
    for hexv, tok in MAPPING.items():
        pat = re.compile(r"const\s+Color\(" + hexv + r"\)", re.IGNORECASE)
        s, c = pat.subn(tok, s)
        n += c
        pat2 = re.compile(r"(?<!const\s)Color\(" + hexv + r"\)", re.IGNORECASE)
        s, c = pat2.subn(tok, s)
        n += c

    # 公共色（语义强、视觉稳定）
    for color, tok in [
        ("Colors.grey", "MiuiColors.onSurfaceVariantActions"),
    ]:
        # 不替换 Colors.grey 以免误伤禁用态——交给调用方审阅
        pass

    if s != orig:
        open(path, "w", encoding="utf-8").write(s)
    return n


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    total = 0
    for f in sys.argv[1:]:
        if not f.endswith(".dart"):
            continue
        cnt = tokenize(f)
        print(f"{f}: {cnt} 处替换")
        total += cnt
    print(f"总计 {total} 处。别忘了为每个文件补 miuix_tokens import。")
