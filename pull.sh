#!/bin/bash
# 拉取远端最新代码（新对话开始时执行）
cd /root/hogwarts_life_simulator
echo "=== 拉取远端最新代码 ==="
git pull origin main 2>&1
echo "=== 当前状态 ==="
git status -s | head -20
echo "=== 完成 ==="
