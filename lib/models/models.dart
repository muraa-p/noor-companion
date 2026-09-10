/// Domain models for Noor.
library;

class Surah {
  final int number;
  final String arabicName;
  final String translatedName;
  final String transliteration;
  final int ayahCount;
  final String revelationType;
  List<Ayah> ayahs;

  Surah({
    required this.number,
    required this.arabicName,
    required this.translatedName,
    required this.transliteration,
    required this.ayahCount,
    required this.revelationType,
    required this.ayahs,
  });

  String get shortArabicName {
    // Arabic name without the "سُورَةُ" prefix used by the API.
    return arabicName.replaceFirst(RegExp(r'^(سُورَةُ|سورة)\s+'), '');
  }
}

class Ayah {
  final int surahNumber;
  final int numberInSurah;
  final String arabic;
  final String english;
  final String bismillah;
  bool highlight;

  Ayah({
    required this.surahNumber,
    required this.numberInSurah,
    required this.arabic,
    required this.english,
    this.bismillah = '',
    this.highlight = false,
  });

  /// Global ayah number used for audio URLs (1..6236).
  int get globalNumber {
    var n = numberInSurah;
    for (var s = 1; s < surahNumber; s++) {
      n += AyahGlobals.ayahCounts[s - 1];
    }
    return n;
  }

  String get reference => '$surahNumber:$numberInSurah';
}

/// Holds shared static data derived from the bundled JSON.
class AyahGlobals {
  AyahGlobals._();

  /// Number of ayahs per surah (index 0 = surah 1).
  static const List<int> ayahCounts = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128,
    111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73,
    54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49,
    62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28,
    28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 20,
    15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5,
    6,
  ];
}

class Reciter {
  final String identifier;
  final String englishName;
  final String arabicName;
  final bool hasSurahAudio;

  /// Bitrate to use for per-ayah audio. Some editions on the CDN only exist
  /// at 64k (e.g. Ar-Rifai, As-Sudais); defaults to 128k.
  final int audioBitrate;

  const Reciter({
    required this.identifier,
    required this.englishName,
    required this.arabicName,
    this.hasSurahAudio = false,
    this.audioBitrate = 128,
  });

  String surahAudioUrl(int surahNumber, {int bitrate = 128}) =>
      'https://cdn.islamic.network/quran/audio-surah/$bitrate/$identifier/$surahNumber.mp3';

  String ayahAudioUrl(int globalAyahNumber, {int? bitrate}) =>
      'https://cdn.islamic.network/quran/audio/${bitrate ?? audioBitrate}/$identifier/$globalAyahNumber.mp3';
}

class NameOfAllah {
  final int number;
  final String arabic;
  final String transliteration;
  final String meaning;

  const NameOfAllah({
    required this.number,
    required this.arabic,
    required this.transliteration,
    required this.meaning,
  });
}

class Dhikr {
  final String arabic;
  final String transliteration;
  final String translation;
  final int repeat;
  final String source;

  const Dhikr({
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.repeat,
    required this.source,
  });
}

/// A dhikr the user added themselves: the text plus how many times they
/// intend to repeat it. It feeds the same daily hasanat dhikr tally as the
/// built-in adhkar (keyed by its Arabic text).
class CustomDhikr {
  final String arabic;
  final int repeat;

  const CustomDhikr({required this.arabic, required this.repeat});

  Map<String, dynamic> toMap() => {'arabic': arabic, 'repeat': repeat};

  factory CustomDhikr.fromMap(Map<String, dynamic> map) => CustomDhikr(
        arabic: map['arabic'] as String? ?? '',
        repeat: (map['repeat'] as num?)?.toInt() ?? 33,
      );
}

/// Where a reader last left a surah: the topmost ayah and (if known) the
/// mushaf page. Saved independently per surah so returning to any surah can
/// resume exactly where the user stopped.
class SurahPosition {
  final int ayah;

  /// Madani 1..604 mushaf page, or 0 when unknown.
  final int page;

  const SurahPosition({required this.ayah, this.page = 0});

  Map<String, dynamic> toMap() => {'ayah': ayah, 'page': page};

  factory SurahPosition.fromMap(Map<String, dynamic> map) => SurahPosition(
        ayah: (map['ayah'] as num?)?.toInt() ?? 1,
        page: (map['page'] as num?)?.toInt() ?? 0,
      );
}

/// A single daily hasanat record persisted on device.
class DailyHasanat {
  final DateTime date; // normalized to date-only
  final int ayahsRead;
  final Map<String, int> dhikrCounts; // keyed by dhikr arabic text
  final int prayers; // number of fard prayers marked (0-5)
  final int donated;
  final int extra;

  const DailyHasanat({
    required this.date,
    required this.ayahsRead,
    required this.dhikrCounts,
    required this.prayers,
    required this.donated,
    required this.extra,
  });

  /// Total hasanat for the day. Sources here are weighted per classical
  /// teachings to keep the counter motivating but not overstated.
  int get total {
    var t = 0;
    t += ayahsRead * kHasanatPerAyahLetter; // reading Qur'an: 10/letter
    t +=
        dhikrCounts.values.fold(0, (a, b) => a + b) * kHasanatPerDhikr; // 10 each
    t += prayers * kHasanatPerPrayer; // 50 per fard prayer completed
    t += donated + extra; // user-entered custom deeds
    return t;
  }

  DailyHasanat copyWith({
    DateTime? date,
    int? ayahsRead,
    Map<String, int>? dhikrCounts,
    int? prayers,
    int? donated,
    int? extra,
  }) {
    return DailyHasanat(
      date: date ?? this.date,
      ayahsRead: ayahsRead ?? this.ayahsRead,
      dhikrCounts: dhikrCounts ?? this.dhikrCounts,
      prayers: prayers ?? this.prayers,
      donated: donated ?? this.donated,
      extra: extra ?? this.extra,
    );
  }

  int valueFor(ActivityType type) {
    switch (type) {
      case ActivityType.ayah:
        return ayahsRead;
      case ActivityType.dhikr:
        return dhikrCounts.values.fold(0, (a, b) => a + b);
      case ActivityType.prayer:
        return prayers;
      case ActivityType.donation:
        return donated;
      case ActivityType.extra:
        return extra;
    }
  }

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'ayahsRead': ayahsRead,
        'prayers': prayers,
        'donated': donated,
        'extra': extra,
        'dhikr': dhikrCounts,
      };

  factory DailyHasanat.fromMap(Map<String, dynamic> map) => DailyHasanat(
        date: DateTime.parse(map['date'] as String),
        ayahsRead: (map['ayahsRead'] as num?)?.toInt() ?? 0,
        prayers: (map['prayers'] as num?)?.toInt() ?? 0,
        donated: (map['donated'] as num?)?.toInt() ?? 0,
        extra: (map['extra'] as num?)?.toInt() ?? 0,
        dhikrCounts: Map<String, int>.from(
          (map['dhikr'] as Map?)?.map(
                (k, v) => MapEntry(k as String, (v as num).toInt()),
              ) ??
              <String, int>{},
        ),
      );
}

enum ActivityType { ayah, dhikr, prayer, donation, extra }

/// Weightings used by [DailyHasanat.total]. Logged in the app's "About
/// hasanat" panel so the user understands the motivation behind each number.
const int kHasanatPerAyahLetter = 10;
const int kHasanatPerDhikr = 10;
const int kHasanatPerPrayer = 50;
