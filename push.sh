#!/bin/bash
# 提交并推送所有改动到远端（改完代码后执行）
cd /root/hogwarts_life_simulator
echo "=== 提交所有改动 ==="
git add -A
git commit -m "${1:-Update from Operit}" 2>&1
echo "=== 推送到远端 ==="
git push origin main 2>&1
echo "=== 完成 ==="
