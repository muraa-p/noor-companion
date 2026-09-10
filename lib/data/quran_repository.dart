import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/models.dart';

/// Loads the bundled Qur'an text (Arabic + English) and surah metadata.
class QuranRepository {
  QuranRepository._();

  static QuranRepository? _instance;
  static QuranRepository get instance => _instance ??= QuranRepository._();

  final List<Surah> _surahs = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;

    final rawAr = await rootBundle.loadString('assets/json/quran_ar.json');
    final rawEn = await rootBundle.loadString('assets/json/quran_en.json');
    final rawMeta = await rootBundle.loadString('assets/json/surah_meta.json');

    final arList = (jsonDecode(rawAr)['quran'] as List)
        .map((e) => _arEntry(e))
        .toList();
    final enMap = <String, String>{};
    for (final e in (jsonDecode(rawEn)['quran'] as List)) {
      enMap['${e['chapter']}:${e['verse']}'] = e['text'] as String;
    }

    final meta = (jsonDecode(rawMeta)['data'] as List).cast<Map<String, dynamic>>();

    // Metadata is in surah-number order (API returns 1..114 already).
    final metaByNumber = <int, Map<String, dynamic>>{
      for (final m in meta) (m['number'] as num).toInt(): m,
    };

    for (var i = 0; i < arList.length;) {
      final surahNumber = arList[i].surahNumber;
      final metaEntry = metaByNumber[surahNumber]!;

      final ayahsThisSurah =
          arList.skip(i).takeWhile((a) => a.surahNumber == surahNumber).toList();

      final bismillahirAyah = ayahsThisSurah.first;
      final String bismillah = _extractBismillah(bismillahirAyah.arabic);

      final List<Ayah> ayahs = [];
      for (var j = 0; j < ayahsThisSurah.length; j++) {
        final src = ayahsThisSurah[j];
        final isFirst = j == 0;
        // Surah 1 and 9 do not include bismillah as part of verse 1/content.
        final bool firstHasBismillah = surahNumber != 1 && surahNumber != 9;
        String body;
        if (isFirst && firstHasBismillah) {
          body = bismillah.isEmpty
              ? src.arabic
              : src.arabic.substring(bismillah.length).trim();
        } else {
          body = src.arabic;
        }
        ayahs.add(
          Ayah(
            surahNumber: surahNumber,
            numberInSurah: src.numberInSurah,
            arabic: body,
            english: enMap['$surahNumber:${src.numberInSurah}'] ?? '',
            bismillah: isFirst && firstHasBismillah ? bismillah : '',
          ),
        );
      }

      _surahs.add(
        Surah(
          number: surahNumber,
          arabicName:
              metaEntry['name'] as String? ?? _fallbackArabicName(surahNumber),
          translatedName: metaEntry['englishNameTranslation'] as String? ??
              _fallbackEnglishName(surahNumber),
          transliteration:
              metaEntry['englishName'] as String? ?? '',
          ayahCount: ayahs.length,
          revelationType: metaEntry['revelationType'] as String? ?? '',
          ayahs: ayahs,
        ),
      );

      i += ayahsThisSurah.length;
    }

    _loaded = true;
  }

  List<Surah> get allSurahs => List.unmodifiable(_surahs);

  Surah? surah(int number) =>
      number >= 1 && number <= _surahs.length ? _surahs[number - 1] : null;

  /// Reads a verse. `bismillah` boolean decides whether to show bismillah.
  static _ArEntry _arEntry(dynamic e) => _ArEntry(
        surahNumber: (e['chapter'] as num).toInt(),
        numberInSurah: (e['verse'] as num).toInt(),
        arabic: e['text'] as String,
      );
}

class _ArEntry {
  final int surahNumber;
  final int numberInSurah;
  final String arabic;
  _ArEntry({required this.surahNumber, required this.numberInSurah, required this.arabic});
}

// The bismillah string in the simple script used across Qur'an datasets.
// Different editions render the hamza/alef and tashkeel differently, so
// extraction below compares text with all diacritics stripped.
const String _kBas = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

String _extractBismillah(String firstAyah) {
  final normBas = _normalizeBismillah(_kBas);
  if (normBas.isEmpty) return '';
  final normAyah = _normalizeBismillah(firstAyah);
  if (!normAyah.startsWith(normBas)) return '';

  // Walk the raw string to find the exact prefix whose normalized form equals
  // the bismillah's normalized form (handles ligatures, waṣla alef, spacing).
  final buf = StringBuffer();
  for (var i = 0; i < firstAyah.length; i++) {
    buf.write(firstAyah[i]);
    if (_normalizeBismillah(buf.toString()) == normBas) {
      return buf.toString().replaceFirst(RegExp(r'\s+$'), '');
    }
  }
  return '';
}

/// Strips diacritics, removes whitespace and normalizes presentation-form
/// ligatures and waṣla alef so different renderings compare equal.
String _normalizeBismillah(String s) {
  var t = _stripMarks(s);
  // Lam-alef presentation forms (U+FEF5..U+FEFC).
  t = t
      .replaceAll('\uFEF5', 'لا')
      .replaceAll('\uFEF6', 'لا')
      .replaceAll('\uFEF7', 'لا')
      .replaceAll('\uFEF8', 'لا')
      .replaceAll('\uFEF9', 'لا')
      .replaceAll('\uFEFA', 'لا')
      .replaceAll('\uFEFB', 'لا')
      .replaceAll('\uFEFC', 'لا');
  // Alef-wasla and hamza variants used in Uthmani script.
  t = t.replaceAll('\u0671', 'ا');
  return t.replaceAll(RegExp(r'\s'), '');
}

/// Removes Arabic diacritics and Qur'anic annotation marks (same ranges as
/// `Arabic.stripTashkeel`, kept here to avoid a provider dependency).
String _stripMarks(String s) {
  final sb = StringBuffer();
  for (final rune in s.runes) {
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

String _fallbackArabicName(int n) => _arabicNames[n - 1];
String _fallbackEnglishName(int n) => _englishNames[n - 1];

const List<String> _arabicNames = [
  'سُورَةُ الْفَاتِحَةِ', 'سُورَةُ الْبَقَرَةِ', 'سُورَةُ آلِ عِمْرَانَ', 'سُورَةُ النِّسَاءِ',
  'سُورَةُ الْمَائِدَةِ', 'سُورَةُ الْأَنْعَامِ', 'سُورَةُ الْأَعْرَافِ', 'سُورَةُ الْأَنْفَالِ',
  'سُورَةُ التَّوْبَةِ', 'سُورَةُ يُونُسَ', 'سُورَةُ هُودٍ', 'سُورَةُ يُوسُفَ',
  'سُورَةُ الرَّعْدِ', 'سُورَةُ إِبْرَاهِيمَ', 'سُورَةُ الْحِجْرِ', 'سُورَةُ النَّحْلِ',
  'سُورَةُ الْإِسْرَاءِ', 'سُورَةُ الْكَهْفِ', 'سُورَةُ مَرْيَمَ', 'سُورَةُ طَهَ',
  'سُورَةُ الْأَنْبِيَاءِ', 'سُورَةُ الْحَجِّ', 'سُورَةُ الْمُؤْمِنُونَ', 'سُورَةُ النُّورِ',
  'سُورَةُ الْفُرْقَانِ', 'سُورَةُ الشُّعَرَاءِ', 'سُورَةُ النَّمْلِ', 'سُورَةُ الْقَصَصِ',
  'سُورَةُ الْعَنْكَبُوتِ', 'سُورَةُ الرُّومِ', 'سُورَةُ لُقْمَانَ', 'سُورَةُ السَّجْدَةِ',
  'سُورَةُ الْأَحْزَابِ', 'سُورَةُ سَبَأٍ', 'سُورَةُ فَاطِرٍ', 'سُورَةُ يس',
  'سُورَةُ الصَّافَّاتِ', 'سُورَةُ ص', 'سُورَةُ الزُّمَرِ', 'سُورَةُ غَافِرٍ',
  'سُورَةُ فُصِّلَتْ', 'سُورَةُ الشُّورَى', 'سُورَةُ الزُّخْرُفِ', 'سُورَةُ الدُّخَانِ',
  'سُورَةُ الْجَاثِيَةِ', 'سُورَةُ الْأَحْقَافِ', 'سُورَةُ مُحَمَّدٍ', 'سُورَةُ الْفَتْحِ',
  'سُورَةُ الْحُجُرَاتِ', 'سُورَةُ ق', 'سُورَةُ الذَّارِيَاتِ', 'سُورَةُ الطُّورِ',
  'سُورَةُ النَّجْمِ', 'سُورَةُ الْقَمَرِ', 'سُورَةُ الرَّحْمَنِ', 'سُورَةُ الْوَاقِعَةِ',
  'سُورَةُ الْحَدِيدِ', 'سُورَةُ الْمُجَادِلَةِ', 'سُورَةُ الْحَشْرِ', 'سُورَةُ الْمُمْتَحَنَةِ',
  'سُورَةُ الصَّفِّ', 'سُورَةُ الْجُمُعَةِ', 'سُورَةُ الْمُنَافِقُونَ', 'سُورَةُ التَّغَابُنِ',
  'سُورَةُ الطَّلَاقِ', 'سُورَةُ التَّحْرِيمِ', 'سُورَةُ الْمُلْكِ', 'سُورَةُ الْقَلَمِ',
  'سُورَةُ الْحَاقَّةِ', 'سُورَةُ الْمَعَارِجِ', 'سُورَةُ نُوحٍ', 'سُورَةُ الْجِنِّ',
  'سُورَةُ الْمُزَّمِّلِ', 'سُورَةُ الْمُدَّثِّرِ', 'سُورَةُ الْقِيَامَةِ', 'سُورَةُ الْإِنْسَانِ',
  'سُورَةُ الْمُرْسَلَاتِ', 'سُورَةُ النَّبَإِ', 'سُورَةُ النَّازِعَاتِ', 'سُورَةُ عَبَسَ',
  'سُورَةُ التَّكْوِيرِ', 'سُورَةُ الْإِنْفِطَارِ', 'سُورَةُ الْمُطَفِّفِينَ', 'سُورَةُ الْإِنْشِقَاقِ',
  'سُورَةُ الْبُرُوجِ', 'سُورَةُ الطَّارِقِ', 'سُورَةُ الْأَعْلَى', 'سُورَةُ الْغَاشِيَةِ',
  'سُورَةُ الْفَجْرِ', 'سُورَةُ الْبَلَدِ', 'سُورَةُ الشَّمْسِ', 'سُورَةُ اللَّيْلِ',
  'سُورَةُ الضُّحَى', 'سُورَةُ الشَّرْحِ', 'سُورَةُ التِّينِ', 'سُورَةُ الْعَلَقِ',
  'سُورَةُ الْقَدْرِ', 'سُورَةُ الْبَيِّنَةِ', 'سُورَةُ الزَّلْزَلَةِ', 'سُورَةُ الْعَادِيَاتِ',
  'سُورَةُ الْقَارِعَةِ', 'سُورَةُ التَّكَاثُرِ', 'سُورَةُ الْعَصْرِ', 'سُورَةُ الْهُمَزَةِ',
  'سُورَةُ الْفِيلِ', 'سُورَةُ قُرَيْشٍ', 'سُورَةُ الْمَاعُونِ', 'سُورَةُ الْكَوْثَرِ',
  'سُورَةُ الْكَافِرُونَ', 'سُورَةُ النَّصْرِ', 'سُورَةُ الْمَسَدِّ', 'سُورَةُ الْإِخْلَاصِ',
  'سُورَةُ الْفَلَقِ', 'سُورَةُ النَّاسِ',
];

const List<String> _englishNames = [
  'The Opening', 'The Cow', 'Family of Imran', 'The Women', 'The Table Spread',
  'The Cattle', 'The Heights', 'The Spoils of War', 'The Repentance', 'Jonah',
  'Hud', 'Joseph', 'The Thunder', 'Abraham', 'The Rocky Tract', 'The Bee',
  'The Night Journey', 'The Cave', 'Mary', 'Ta-Ha', 'The Prophets', 'The Pilgrimage',
  'The Believers', 'The Light', 'The Criterion', 'The Poets', 'The Ant', 'The Stories',
  'The Spider', 'The Romans', 'Luqman', 'The Prostration', 'The Combined Forces',
  'Sheba', 'Originator', 'Ya Sin', 'Those who set the Ranks', 'Sad', 'The Groups',
  'The Forgiver', 'Fussilat', 'The Consultation', 'The Ornaments of Gold',
  'The Smoke', 'The Crouching', 'The Wind-Curved Sandhills', 'Muhammad', 'The Victory',
  'The Rooms', 'Qaf', 'The Winnowing Winds', 'The Mount', 'The Star', 'The Moon',
  'The Beneficent', 'The Inevitable', 'The Iron', 'The Pleading Woman', 'The Exile',
  'She that is to be examined', 'The Ranks', 'Friday', 'The Hypocrites', 'Mutual Disillusion',
  'Divorce', 'The Prohibition', 'The Sovereignty', 'The Pen', 'The Reality',
  'The Ascending Stairways', 'Noah', 'The Jinn', 'The Enshrouded One',
  'The Cloaked One', 'The Resurrection', 'Man', 'The Emissaries', 'The Tidings',
  'Those who drag forth', 'He frowned', 'The Overthrowing', 'The Cleaving', 'The Defrauders',
  'The Sundering', 'The Mansions of the Stars', 'The Nightcomer', 'The Most High',
  'The Overwhelming', 'The Dawn', 'The City', 'The Sun', 'The Night', 'The Morning Hours',
  'The Relief', 'The Fig', 'The Clot', 'The Power', 'The Clear Proof', 'The Earthquake',
  'The Courser', 'The Calamity', 'Abundance', 'The Declining Day', 'The Traducer',
  'The Elephant', 'Quraysh', 'Small Kindnesses', 'Abundance', 'The Disbelievers',
  'Divine Support', 'The Palm Fibre', 'The Sincerity', 'The Daybreak', 'Mankind',
];
