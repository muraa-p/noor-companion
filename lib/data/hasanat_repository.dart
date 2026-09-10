import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Persists the user's daily hasanat and other settings in SharedPreferences.
class HasanatRepository {
  static const _key = 'hasanat_records_v1';

  Future<Map<String, DailyHasanat>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final out = <String, DailyHasanat>{};
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        final rec = DailyHasanat.fromMap(e as Map<String, dynamic>);
        out[_dayKey(rec.date)] = rec;
      }
    }
    return out;
  }

  Future<void> save(Map<String, DailyHasanat> records) async {
    final prefs = await SharedPreferences.getInstance();
    final list = records.values.map((r) => r.toMap()).toList();
    await prefs.setString(_key, jsonEncode(list));
  }

  /// Normalizes a [DateTime] to its date-only key (local midnight).
  static String dayKey(DateTime d) => _dayKey(d);
  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---- Daily read-ayah set ------------------------------------------------
  // `read_ayahs_v1` holds only *today's* reads; the paired date stamp lets the
  // provider detect (on launch or on the same-day check) that the stored set
  // belongs to a previous day and reset it for the new one.
  static const _readKey = 'read_ayahs_v1';
  static const _readDateKey = 'read_ayahs_date_v1';

  Future<Set<String>> loadReadAyahs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_readKey);
    if (raw == null) return <String>{};
    try {
      return (jsonDecode(raw) as List).cast<String>().toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// Date stamp ("YYYY-MM-DD") of the stored read set, or null if never saved.
  Future<String?> loadReadAyahsDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_readDateKey);
  }

  Future<void> saveReadAyahs(Set<String> refs) async {
    final prefs = await SharedPreferences.getInstance();
    final stamp = _dayKey(DateTime.now());
    await Future.wait([
      prefs.setString(_readKey, jsonEncode(refs.toList()..sort())),
      prefs.setString(_readDateKey, stamp),
    ]);
  }
}

/// Computes a running streak (consecutive days with any hasanat) ending today
/// or yesterday.
int computeStreak(Map<String, DailyHasanat> records, DateTime now) {
  var day = DateTime(now.year, now.month, now.day);
  // If today has no activity, start streak from yesterday.
  if ((records[HasanatRepository.dayKey(day)]?.total ?? 0) == 0) {
    day = day.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (true) {
    final rec = records[HasanatRepository.dayKey(day)];
    if (rec == null || rec.total == 0) break;
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}
