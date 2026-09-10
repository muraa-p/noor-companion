import 'package:flutter/foundation.dart';

import '../data/hasanat_repository.dart';
import '../models/models.dart';
import 'quran_provider.dart';

/// Manages the user's daily hasanat records.
class HasanatProvider extends ChangeNotifier {
  final HasanatRepository _repo;
  final QuranProvider _quran;

  HasanatProvider({required HasanatRepository repo, required QuranProvider quran})
      : _repo = repo,
        _quran = quran;

  Map<String, DailyHasanat> _records = {};
  Set<String> _readAyahs = {};
  DateTime _now = DateTime.now();
  String? _lastDayKey;
  bool _loaded = false;

  Map<String, DailyHasanat> get records => Map.unmodifiable(_records);

  DateTime get now => _now;

  /// Normalizes to a local-midnight DateTime.
  DateTime get _today {
    final d = _now;
    return DateTime(d.year, d.month, d.day);
  }

  String get _todayKey => HasanatRepository.dayKey(_today);

  DailyHasanat get _todayRecord => _records[_todayKey] ?? empty(_today);

  DailyHasanat empty(DateTime day) => DailyHasanat(
        date: day,
        ayahsRead: 0,
        dhikrCounts: {},
        prayers: 0,
        donated: 0,
        extra: 0,
      );

  Future<void> load() async {
    if (_loaded) return;
    final results = await Future.wait([
      _repo.loadAll(),
      _repo.loadReadAyahs(),
      _repo.loadReadAyahsDate(),
    ]);
    _records = results[0] as Map<String, DailyHasanat>;
    final refreshed = _maybeResetAyahsForToday(
      results[1] as Set<String>,
      results[2] as String?,
    );
    _loaded = true;
    if (refreshed) {
      // Persist the reset so the stored set (and its date) match today, and so
      // the lifetime/daily hasanat records aren't double-counted on restart.
      await _repo.saveReadAyahs(_readAyahs);
    }
    notifyListeners();
  }

  /// If [stored] belongs to an earlier day than today, clears it so reading
  /// starts fresh (and can re-earn hasanat) on the new day. Returns true when
  /// a reset occurred.
  bool _maybeResetAyahsForToday(Set<String> stored, String? storedDate) {
    final todayKey = _todayKey;
    if (storedDate == todayKey) {
      _readAyahs = stored;
      return false;
    }
    _readAyahs = <String>{};
    // Only signal a reset worth persisting when there was something to clear.
    return stored.isNotEmpty;
  }

  /// Re-resolves "today" and reports whether the day changed (midnight
  /// rollover while the app stayed open). Screens rebuild automatically and
  /// start counting into the new day's record.
  bool refreshClock() {
    final before = _lastDayKey ?? _todayKey;
    _now = DateTime.now();
    final todayKey = _todayKey;
    final rolled = todayKey != before;
    _lastDayKey = todayKey;
    if (rolled) {
      // Midnight rollover: today's read set belongs to the old day, so reading
      // starts fresh (and can re-earn hasanat) on the new day.
      _readAyahs = <String>{};
    }
    notifyListeners();
    return rolled;
  }

  // --- Mutations -----------------------------------------------------------

  bool isRead(String ref) => _readAyahs.contains(ref);

  /// Marks an ayah as read and credits its letters' hasanat to today (only the
  /// first time it is read).
  Future<void> addAyahRead(String ref) async {
    if (_readAyahs.contains(ref)) return;
    final ayah = _quran.ayah(ref);
    if (ayah == null) return;
    final letters = _quran.lettersOf(ayah);
    final today = _today;
    final old = _records[_todayKey] ?? empty(today);

    _records[_todayKey] = DailyHasanat(
      date: old.date,
      ayahsRead: old.ayahsRead + letters,
      dhikrCounts: old.dhikrCounts,
      prayers: old.prayers,
      donated: old.donated,
      extra: old.extra,
    );
    _readAyahs.add(ref);
    await Future.wait([_persist(), _repo.saveReadAyahs(_readAyahs)]);
    notifyListeners();
  }

  /// Marks a whole group of ayahs (e.g. "this page") as read. Returns the
  /// number of new letters credited, or 0 when everything was already read.
  Future<int> addAyahsRead(Iterable<String> refs) async {
    var letters = 0;
    final fresh = <String>[];
    for (final ref in refs) {
      if (_readAyahs.contains(ref)) continue;
      final ayah = _quran.ayah(ref);
      if (ayah == null) continue;
      letters += _quran.lettersOf(ayah);
      fresh.add(ref);
    }
    if (fresh.isEmpty) return 0;
    final today = _today;
    final old = _records[_todayKey] ?? empty(today);
    _records[_todayKey] = DailyHasanat(
      date: old.date,
      ayahsRead: old.ayahsRead + letters,
      dhikrCounts: old.dhikrCounts,
      prayers: old.prayers,
      donated: old.donated,
      extra: old.extra,
    );
    _readAyahs.addAll(fresh);
    await Future.wait([_persist(), _repo.saveReadAyahs(_readAyahs)]);
    notifyListeners();
    return letters;
  }

  Future<void> increaseDhikr(String dhikr) async {
    final today = _today;
    final old = _records[_todayKey] ?? empty(today);
    final counts = Map<String, int>.of(old.dhikrCounts);
    counts[dhikr] = (counts[dhikr] ?? 0) + 1;
    _records[_todayKey] = DailyHasanat(
      date: old.date,
      ayahsRead: old.ayahsRead,
      dhikrCounts: counts,
      prayers: old.prayers,
      donated: old.donated,
      extra: old.extra,
    );
    await _persist();
    notifyListeners();
  }

  /// Increments (clamped to 5) the count of fard prayers completed today.
  Future<void> addPrayer() async {
    final today = _today;
    final old = _records[_todayKey] ?? empty(today);
    final prayers = (old.prayers + 1).clamp(0, 5);
    _records[_todayKey] = old.copyWith(prayers: prayers);
    await _persist();
    notifyListeners();
  }

  /// Decrements (clamped to 0) the fard-prayer count for today.
  Future<void> removePrayer() async {
    final today = _today;
    final old = _records[_todayKey] ?? empty(today);
    final prayers = (old.prayers - 1).clamp(0, 5);
    _records[_todayKey] = old.copyWith(prayers: prayers);
    await _persist();
    notifyListeners();
  }

  int get todayPrayers => _todayRecord.prayers;

  Future<void> addDonation({double amount = 1}) async {
    final today = _today;
    final old = _records[_todayKey] ?? empty(today);
    _records[_todayKey] = old.copyWith(
      donated: old.donated + (amount.round()),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> addExtra(int amount) async {
    final today = _today;
    final old = _records[_todayKey] ?? empty(today);
    _records[_todayKey] = old.copyWith(extra: old.extra + amount);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() => _repo.save(_records);

  // --- Queries -------------------------------------------------------------

  /// Where "hasanat" is roughly the value of one good deed.
  int get todayHasanat => _todayRecord.total;
  DailyHasanat get todayRecord => _todayRecord;

  int streak() => computeStreak(_records, _now);

  int totalAllTime() {
    var t = 0;
    for (final r in _records.values) {
      t += r.total;
    }
    return t;
  }

  /// List of the last [days] days (oldest first) for charts.
  List<DailyHasanat> lastDays(int days) {
    final out = <DailyHasanat>[];
    final now = _now;
    for (var i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final day = DateTime(d.year, d.month, d.day);
      out.add(_records[HasanatRepository.dayKey(day)] ?? empty(day));
    }
    return out;
  }
}