import 'package:flutter_test/flutter_test.dart';

import 'package:quran/models/models.dart';
import 'package:quran/providers/quran_provider.dart';

void main() {
  test('DailyHasanat totals weight deeds correctly', () {
    final record = DailyHasanat(
      date: DateTime(2026, 1, 1),
      ayahsRead: 100, // 100 letters -> 1000 hasanat
      dhikrCounts: const {'سُبْحَانَ اللَّه': 10}, // 10 x 10 = 100
      prayers: 5, // 5 x 50 = 250
      donated: 3,
      extra: 7,
    );

    expect(record.total, 1000 + 100 + 250 + 3 + 7);
  });

  test('Arabic letter counting ignores diacritics', () {
    expect(Arabic.countLetters('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'), 19);
  });

  test('Arabic digits conversion', () {
    expect(QurNum.arabicDigits(12), '١٢');
  });

  test('stripTashkeel removes diacritics', () {
    expect(Arabic.stripTashkeel('بِسْمِ اللَّهِ'), 'بسم الله');
  });
}