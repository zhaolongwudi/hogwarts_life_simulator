// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DisplayMode { magazine, compact, immersive }
enum IdentityMode { native, transmigration }
enum Era { marauders, first_war, harry_same, post_war, random }

class AppProvider extends ChangeNotifier {
  String? _apiKey;
  bool _isGameStarted = false;
  DisplayMode _displayMode = DisplayMode.magazine;
  IdentityMode _identityMode = IdentityMode.native;
  Era _era = Era.harry_same;

  String? get apiKey => _apiKey;
  bool get isGameStarted => _isGameStarted;
  DisplayMode get displayMode => _displayMode;
  IdentityMode get identityMode => _identityMode;
  Era get era => _era;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('api_key');
    _isGameStarted = prefs.getBool('game_started') ?? false;
    _displayMode = DisplayMode.values[prefs.getInt('display_mode') ?? 0];
    _identityMode = IdentityMode.values[prefs.getInt('identity_mode') ?? 0];
    _era = Era.values[prefs.getInt('era') ?? 2];
    notifyListeners();
  }

  Future<void> saveApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', key);
    notifyListeners();
  }

  void setGameStarted(bool started) {
    _isGameStarted = started;
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('game_started', started));
    notifyListeners();
  }

  void setDisplayMode(DisplayMode mode) {
    _displayMode = mode;
    SharedPreferences.getInstance().then((prefs) => prefs.setInt('display_mode', mode.index));
    notifyListeners();
  }

  void setIdentityMode(IdentityMode mode) {
    _identityMode = mode;
    SharedPreferences.getInstance().then((prefs) => prefs.setInt('identity_mode', mode.index));
    notifyListeners();
  }

  void setEra(Era era) {
    _era = era;
    SharedPreferences.getInstance().then((prefs) => prefs.setInt('era', era.index));
    notifyListeners();
  }

  void clearApiKey() {
    _apiKey = null;
    SharedPreferences.getInstance().then((prefs) => prefs.remove('api_key'));
    notifyListeners();
  }
}
