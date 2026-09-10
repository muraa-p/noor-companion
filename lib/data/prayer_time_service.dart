import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class PrayerTimes {
  final DateTime date;
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;

  const PrayerTimes({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });
}

/// Fetches prayer times from the free Aladhan API (v7).
class PrayerTimeService {
  static const _base = 'https://api.aladhan.com/v1';

  /// Maps prayer method id -> name for the settings screen.
  /// (The Shia Ithna-Ashari method is intentionally excluded.)
  static const Map<int, String> methods = {
    1: 'University of Islamic Sciences, Karachi',
    2: 'Islamic Society of North America',
    3: 'Muslim World League',
    4: 'Umm Al-Qura University, Makkah',
    5: 'Egyptian General Authority of Survey',
    7: 'Institute of Geophysics, University of Tehran',
    8: 'Gulf Region',
    9: 'Kuwait',
    10: 'Qatar',
    11: 'Majlis Ugama Islam Singapura',
    12: 'Union Organization islamic de France',
    13: 'Diyanet İşleri Başkanlığı, Turkey',
    14: 'Spiritual Administration of Muslims of Russia',
  };

  /// Fetches a whole week (today + 6 days) using the Aladhan calendarByCity API.
  /// Returns exactly 7 days starting from today (index 0 = today).
  Future<List<PrayerTimes>> fetchWeek({
    required String city,
    required String country,
    required int method,
  }) async {
    final now = DateTime.now();
    final neededMonths = <String>[];
    for (var i = 0; i < 7; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      final key = '${d.year}-${d.month}';
      if (!neededMonths.contains(key)) neededMonths.add(key);
    }

    final byDay = <DateTime, PrayerTimes>{};
    for (final key in neededMonths) {
      final parts = key.split('-');
      final monthList = await _fetchMonth(
        city: city,
        country: country,
        method: method,
        year: int.parse(parts[0]),
        month: int.parse(parts[1]),
      );
      for (final p in monthList) {
        byDay[DateTime(p.date.year, p.date.month, p.date.day)] = p;
      }
    }

    final week = <PrayerTimes>[];
    for (var i = 0; i < 7; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      final hit = byDay[DateTime(d.year, d.month, d.day)];
      if (hit != null) week.add(hit);
    }
    return week;
  }

  Future<List<PrayerTimes>> _fetchMonth({
    required String city,
    required String country,
    required int method,
    required int year,
    required int month,
  }) async {
    final uri = Uri.parse('$_base/calendarByCity/$year/$month').replace(
      queryParameters: {
        'city': city.trim(),
        'country': country.trim(),
        'method': '$method',
      },
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Prayer time request failed (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'] as List;
    return data.map((e) {
      final item = e as Map<String, dynamic>;
      final greg = item['date']['gregorian'] as Map<String, dynamic>;
      // Aladhan returns DD-MM-YYYY; DateTime.parse requires ISO-8601, so
      // build the date from its parts instead.
      final dateParts = (greg['date'] as String).split('-');
      final dayDate = DateTime(
        int.parse(dateParts[2]),
        int.parse(dateParts[1]),
        int.parse(dateParts[0]),
      );
      final timings = item['timings'] as Map<String, dynamic>;
      return PrayerTimes(
        date: dayDate,
        fajr: timings['Fajr'] as String,
        sunrise: timings['Sunrise'] as String,
        dhuhr: timings['Dhuhr'] as String,
        asr: timings['Asr'] as String,
        maghrib: timings['Maghrib'] as String,
        isha: timings['Isha'] as String,
      );
    }).toList();
  }
}