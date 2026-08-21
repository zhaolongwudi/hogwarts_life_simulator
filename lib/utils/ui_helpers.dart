import 'package:flutter/material.dart';

class UiHelpers {
  static Color getHouseColor(String house) {
    final key = house.toLowerCase();
    switch (key) {
      case 'gryffindor':
        return const Color(0xFF740001);
      case 'slytherin':
        return const Color(0xFF1A472A);
      case 'ravenclaw':
        return const Color(0xFF0E1A40);
      case 'hufflepuff':
        return const Color(0xFFECB939);
      default:
        return const Color(0xFF8B949E);
    }
  }

  static String getHouseLabel(String house) {
    switch (house.toLowerCase()) {
      case 'gryffindor':
        return '格兰芬多';
      case 'slytherin':
        return '斯莱特林';
      case 'ravenclaw':
        return '拉文克劳';
      case 'hufflepuff':
        return '赫奇帕奇';
      default:
        return '未分院';
    }
  }

  static String getAffectionLabel(int affection) {
    if (affection >= 95) return '灵魂伴侣 💞';
    if (affection >= 85) return '深爱 ❤️';
    if (affection >= 70) return '亲密 💕';
    if (affection >= 50) return '信任 😊';
    if (affection >= 30) return '友好 🙂';
    if (affection >= 10) return '好感 😃';
    if (affection >= -9) return '中立 😐';
    if (affection >= -20) return '冷漠 😶';
    if (affection >= -50) return '反感 😒';
    if (affection >= -80) return '宿怨 😠';
    return '死敌 💀';
  }

  static Color getAffectionColor(int affection) {
    if (affection >= 70) return Colors.pink;
    if (affection >= 30) return Colors.green;
    if (affection >= -9) return Colors.grey;
    if (affection >= -50) return Colors.orange;
    return Colors.red;
  }

  static Color getScoreColor(int score) {
    if (score >= 50) return Colors.red;
    if (score >= 35) return Colors.pink;
    return Colors.orange;
  }
}
