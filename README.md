# 魔法人生模拟器 (Hogwarts Life Simulator)

哈利·波特魔法人生模拟器 —— 高自由度巫师人生模拟 Flutter App，由 DeepSeek AI 驱动。

## 功能特性

- 自由创建巫师角色：姓名、出生地、血统、性格特质
- 4 种时代背景：掠夺者时代 / 第一次巫师战争 / 哈利同期 / 战后时代
- 原著角色 NPC：哈利、赫敏、罗恩、邓布利多、斯内普等，各有独立人生与性格
- DeepSeek AI 实时叙事：每次行动生成剧情、影响属性与关系
- 分院帽仪式、奥利凡德魔杖店
- 本地存档 / 读档（多槽位）
- 3 种显示模式：魔法手账 / 简洁 / 沉浸

## 环境要求

- Flutter >= 3.16.0（Dart SDK >= 3.2.0）
- DeepSeek API Key（可在 https://platform.deepseek.com 免费获取）

## 快速开始

```bash
flutter pub get
flutter run
```

首次进入请在「设置」中填入 DeepSeek API Key。

## 自动构建

`.github/workflows/android-build.yml` 会在每次推送到 `main` 分支时自动构建 release APK，
构建产物可在 Actions 页面的 `release-apk` Artifact 中下载。

## 构建 Android APK（本地）

```bash
flutter build apk --release
```

输出位于 `build/app/outputs/flutter-apk/app-release.apk`。
