import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/prayer_time_service.dart';
import '../models/models.dart';

/// App settings persisted in SharedPreferences.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'theme_mode';
  static const _translationKey = 'show_translation';
  static const _arabicSizeKey = 'arabic_font_size';
  static const _latinSizeKey = 'latin_font_size';
  static const _reciterKey = 'reciter_id';
  static const _reminderKey = 'daily_reminder';
  static const _reminderTimeKey = 'reminder_time_minutes';
  static const _prayerCityKey = 'prayer_city';
  static const _prayerCountryKey = 'prayer_country';
  static const _prayerMethodKey = 'prayer_method';
  static const _hapticsKey = 'haptics';
  static const _lastReadKey = 'last_read_surah_ayah';
  static const _positionsKey = 'surah_positions_v1';
  static const _readerTutorialSeenKey = 'reader_tutorial_seen';
  static const _tutorialPrefix = 'tutorial_seen_';
  static const _customDhikrsKey = 'custom_dhikrs_v1';

  ThemeMode _theme = ThemeMode.system;
  bool _showTranslation = true;
  double _arabicFontSize = 26;
  double _latinFontSize = 16;
  String _reciterId = 'ar.alafasy';
  bool _dailyReminder = false;
  int _reminderTimeMinutes = 8 * 60 + 30; // 08:30
  String _prayerCity = '';
  String _prayerCountry = '';
  int _prayerMethod = 3; // Muslim World League
  bool _haptics = true;

  /// Per-surah reading positions, keyed by surah number.
  Map<int, SurahPosition> _surahPositions = {};

  // ---- Load ---------------------------------------------------------------

  Future<void> load() async {
    _theme = ThemeMode.values.firstWhere(
      (e) => e.name == _prefs.getString(_themeKey),
      orElse: () => ThemeMode.system,
    );
    _showTranslation = _prefs.getBool(_translationKey) ?? true;
    _arabicFontSize = _prefs.getDouble(_arabicSizeKey) ?? 26;
    _latinFontSize = _prefs.getDouble(_latinSizeKey) ?? 16;
    _reciterId = _prefs.getString(_reciterKey) ?? 'ar.alafasy';
    _dailyReminder = _prefs.getBool(_reminderKey) ?? false;
    _reminderTimeMinutes = _prefs.getInt(_reminderTimeKey) ?? (8 * 60 + 30);
    _prayerCity = _prefs.getString(_prayerCityKey) ?? '';
    _prayerCountry = _prefs.getString(_prayerCountryKey) ?? '';
    _prayerMethod = _prefs.getInt(_prayerMethodKey) ?? 3;
    // Guard against a removed/renamed method (e.g. persisted 0 after the
    // Shia method was dropped) falling back to the safe default.
    if (!PrayerTimeService.methods.containsKey(_prayerMethod)) {
      _prayerMethod = 3;
    }
    _haptics = _prefs.getBool(_hapticsKey) ?? true;
    _surahPositions = _loadSurahPositions();
    notifyListeners();
  }

  Map<int, SurahPosition> _loadSurahPositions() {
    final raw = _prefs.getString(_positionsKey);
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final result = <int, SurahPosition>{};
      json.forEach((key, value) {
        final n = int.tryParse(key);
        if (n == null) return;
        result[n] =
            SurahPosition.fromMap(Map<String, dynamic>.from(value as Map));
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  // ---- Getters ------------------------------------------------------------

  ThemeMode get theme => _theme;
  bool get showTranslation => _showTranslation;
  double get arabicFontSize => _arabicFontSize;
  double get latinFontSize => _latinFontSize;
  String get reciterId => _reciterId;
  bool get dailyReminder => _dailyReminder;
  int get reminderTimeMinutes => _reminderTimeMinutes;
  String get prayerCity => _prayerCity;
  String get prayerCountry => _prayerCountry;
  int get prayerMethod => _prayerMethod;
  bool get haptics => _haptics;

  // ---- Setters ------------------------------------------------------------

  Future<void> setTheme(ThemeMode value) async {
    _theme = value;
    await _prefs.setString(_themeKey, value.name);
    notifyListeners();
  }

  Future<void> setShowTranslation(bool value) async {
    _showTranslation = value;
    await _prefs.setBool(_translationKey, value);
    notifyListeners();
  }

  Future<void> setArabicFontSize(double value) async {
    _arabicFontSize = value.roundToDouble();
    await _prefs.setDouble(_arabicSizeKey, _arabicFontSize);
    notifyListeners();
  }

  Future<void> setLatinFontSize(double value) async {
    _latinFontSize = value.roundToDouble();
    await _prefs.setDouble(_latinSizeKey, _latinFontSize);
    notifyListeners();
  }

  Future<void> setReciter(String id) async {
    _reciterId = id;
    await _prefs.setString(_reciterKey, id);
    notifyListeners();
  }

  Future<void> setDailyReminder(bool value) async {
    _dailyReminder = value;
    await _prefs.setBool(_reminderKey, value);
    notifyListeners();
  }

  Future<void> setReminderTime(String hourMinute) async {
    final parts = hourMinute.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    _reminderTimeMinutes = h * 60 + m;
    await _prefs.setInt(_reminderTimeKey, _reminderTimeMinutes);
    notifyListeners();
  }

  Future<void> setPrayerLocation(String city, String country) async {
    _prayerCity = city;
    _prayerCountry = country;
    await _prefs.setString(_prayerCityKey, city);
    await _prefs.setString(_prayerCountryKey, country);
    notifyListeners();
  }

  Future<void> setPrayerMethod(int method) async {
    _prayerMethod = method;
    await _prefs.setInt(_prayerMethodKey, method);
    notifyListeners();
  }

  Future<void> setHaptics(bool value) async {
    _haptics = value;
    await _prefs.setBool(_hapticsKey, value);
    notifyListeners();
  }

  // ---- Last-read position ------------------------------------------------

  /// 'surah:ayah' of the most recently opened reader, or null.
  String? get lastRead => _prefs.getString(_lastReadKey);

  Future<void> setLastRead(int surah, int ayah) async {
    await _prefs.setString(_lastReadKey, '$surah:$ayah');
    notifyListeners();
  }

  // ---- Per-surah reading positions ---------------------------------------

  /// Where the reader last left [surah], or null if never read before.
  SurahPosition? positionOf(int surah) => _surahPositions[surah];

  /// Saves the reading position for a single surah so it can be resumed
  /// exactly where the user left. [page] is the mushaf page or 0 when unknown.
  Future<void> setSurahPosition(int surah, int ayah, {int page = 0}) async {
    _surahPositions[surah] = SurahPosition(ayah: ayah, page: page);
    await _persistSurahPositions();
    notifyListeners();
  }

  /// Removes a surah's saved position (used when the user chooses to read
  /// that surah again from the very beginning).
  Future<void> clearSurahPosition(int surah) async {
    if (_surahPositions.remove(surah) != null) {
      await _persistSurahPositions();
      notifyListeners();
    }
  }

  Future<void> _persistSurahPositions() async {
    await _prefs.setString(
      _positionsKey,
      jsonEncode(_surahPositions.map(
        (k, v) => MapEntry(k.toString(), v.toMap()),
      )),
    );
  }

  // ---- First-run tutorial -------------------------------------------------

  /// Whether the in-reader coach-mark tutorial has been shown (or skipped).
  bool get readerTutorialSeen => _prefs.getBool(_readerTutorialSeenKey) ?? false;

  Future<void> setReaderTutorialSeen() =>
      _prefs.setBool(_readerTutorialSeenKey, true);

  /// Per-screen first-run coach marks. Each tab/screen has its own id.
  bool tutorialSeen(String id) =>
      _prefs.getBool('$_tutorialPrefix$id') ?? false;

  Future<void> setTutorialSeen(String id) =>
      _prefs.setBool('$_tutorialPrefix$id', true);

  // ---- My dhikr -----------------------------------------------------------

  /// The user's own dhikr list (Arabic text + repeat count), shown in Adhkar.
  List<CustomDhikr> get customDhikrs {
    final raw = _prefs.getString(_customDhikrsKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => CustomDhikr.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Adds or replaces (same Arabic text) a user-defined dhikr.
  Future<void> addCustomDhikr(CustomDhikr dhikr) async {
    final list = List<CustomDhikr>.of(customDhikrs);
    final index = list.indexWhere((e) => e.arabic == dhikr.arabic);
    if (index >= 0) {
      list[index] = dhikr;
    } else {
      list.add(dhikr);
    }
    await _prefs.setString(
      _customDhikrsKey,
      jsonEncode(list.map((e) => e.toMap()).toList()),
    );
    notifyListeners();
  }

  Future<void> removeCustomDhikr(String arabic) async {
    final list = List<CustomDhikr>.of(customDhikrs)
      ..removeWhere((e) => e.arabic == arabic);
    await _prefs.setString(
      _customDhikrsKey,
      jsonEncode(list.map((e) => e.toMap()).toList()),
    );
    notifyListeners();
  }
}