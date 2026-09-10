import 'package:flutter/foundation.dart';

import '../data/quran_repository.dart';
import '../models/models.dart';

/// Exposes the loaded Qur'an data and derived utilities.
class QuranProvider extends ChangeNotifier {
  final QuranRepository _repo;

  QuranProvider(this._repo);

  bool _loading = false;
  String? _error;
  late List<Surah> _surahs = [];
  late Map<String, Ayah> _ayahIndex = {};
  final Map<String, int> _letterCache = {};

  bool get isLoading => _loading;
  String? get error => _error;
  List<Surah> get surahs => _surahs;
  bool get isLoaded => _surahs.isNotEmpty;

  Future<void> ensureLoaded() async {
    if (isLoaded || _loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.load();
      _surahs = _repo.allSurahs;
      _ayahIndex = {
        for (final s in _surahs)
          for (final a in s.ayahs) '${s.number}:${a.numberInSurah}': a,
      };
      for (final s in _surahs) {
        for (final a in s.ayahs) {
          _letterCache['${s.number}:${a.numberInSurah}'] =
              Arabic.countLetters(a.arabic);
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Resolves when the corpus has finished loading (or failed).
  Future<void> whenLoaded() async {
    while (!isLoaded && _loading) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Surah? surah(int n) =>
      (n >= 1 && n <= _surahs.length) ? _surahs[n - 1] : null;

  Ayah? ayah(String ref) => _ayahIndex[ref];

  /// Cached letter count for an ayah (10 hasanat per letter).
  int lettersOf(Ayah ayah) =>
      _letterCache[ayah.reference] ?? Arabic.countLetters(ayah.arabic);

  /// Random ayah of the day, seeded by the day-of-year so it's stable all day.
  Ayah ayahOfTheDay(DateTime date) {
    if (_surahs.isEmpty) {
      throw StateError("Qur'an not loaded yet");
    }
    final dayOfYear = date.difference(DateTime(date.year)).inDays + 1;
    final total = _surahs.fold<int>(0, (s, su) => s + su.ayahs.length);
    final target = (dayOfYear * 37 + date.year) % total;
    var idx = 0;
    for (final s in _surahs) {
      for (final a in s.ayahs) {
        if (idx == target) return a;
        idx++;
      }
    }
    return _surahs.first.ayahs.first;
  }
}

/// Arabic text utilities.
class Arabic {
  /// The Arabic letter code points (hamza, alef variants, ba–ya, and the
  /// regional yaa/waw variants used in Uthmani script), excluding all
  /// diacritical marks, tatweel and Qur'anic annotation signs.
  static final Set<int> letters = _build();

  static Set<int> _build() {
    final set = <int>{};
    for (var c = 0x0621; c <= 0x063A; c++) {
      set.add(c); // hamza … ghayn
    }
    for (var c = 0x0641; c <= 0x064A; c++) {
      set.add(c); // fa … yaa (no tatweel 0x0640)
    }
    for (var c = 0x0671; c <= 0x06D3; c++) {
      set.add(c); // alef wasla … yaa-barree variants
    }
    return set;
  }

  /// Counts the number of Qur'anic letters (diacritics ignored).
  static int countLetters(String text) {
    var count = 0;
    for (final rune in text.runes) {
      if (letters.contains(rune)) count++;
    }
    return count;
  }

  /// Removes tashkeel (diacritics), tatweel and Qur'anic annotation marks so
  /// that text can be compared and searched diacritic-insensitively.
  static String stripTashkeel(String text) {
    final sb = StringBuffer();
    for (final rune in text.runes) {
      // Diacritics & marks: 0x0610–0x061A, 0x064B–0x065F, 0x0670, 0x06D6–0x06DC,
      // 0x06DF–0x06E4, 0x06E7–0x06E8, 0x06EA–0x06ED, small alef variants, tatweel.
      if ((rune >= 0x0610 && rune <= 0x061A) ||
          (rune >= 0x064B && rune <= 0x065F) ||
          (rune >= 0x0670 && rune <= 0x0670) ||
          (rune >= 0x06D6 && rune <= 0x06E4) ||
          (rune >= 0x06E7 && rune <= 0x06E8) ||
          (rune >= 0x06EA && rune <= 0x06ED) ||
          rune == 0x0640 ||
          rune == 0x06E5 ||
          rune == 0x06E6 ||
          rune == 0x06EE ||
          rune == 0x06EF) {
        continue;
      }
      sb.writeCharCode(rune);
    }
    return sb.toString();
  }
}

/// Converts Western digits to Arabic-Indic numerals.
class QurNum {
  static String arabicDigits(int n) {
    const base = 0x0660;
    final sb = StringBuffer();
    for (final c in n.toString().codeUnits) {
      if (c >= 0x30 && c <= 0x39) {
        sb.writeCharCode(base + (c - 0x30));
      } else {
        sb.writeCharCode(c);
      }
    }
    return sb.toString();
  }
}