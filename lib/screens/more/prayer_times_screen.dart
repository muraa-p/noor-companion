import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/prayer_time_service.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  final _service = PrayerTimeService();
  bool _loading = false;
  String? _error;
  List<PrayerTimes> _week = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = context.read<SettingsProvider>();
    if (settings.prayerCity.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final week = await _service.fetchWeek(
        city: settings.prayerCity,
        country: settings.prayerCountry,
        method: settings.prayerMethod,
      );
      if (!mounted) return;
      setState(() {
        _week = week;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Times')),
      body: SafeArea(
        child: settings.prayerCity.isEmpty
            ? _PromptToSetLocation(settings: settings, onLocationSet: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Text(
                      '${settings.prayerCity}, ${settings.prayerCountry}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      PrayerTimeService.methods[settings.prayerMethod] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      _ErrorCard(
                        error: _error!,
                        onRetry: _load,
                      )
                    else if (_week.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: Text('No data yet.')),
                      )
                    else
                      for (final day in _week) _DayCard(day: day),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PromptToSetLocation extends StatelessWidget {
  final SettingsProvider settings;
  final VoidCallback onLocationSet;
  const _PromptToSetLocation({
    required this.settings,
    required this.onLocationSet,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_outlined, size: 64, color: Ui.emerald(context)),
            const SizedBox(height: 16),
            const Text(
              'Set your city to see accurate prayer times.',
              textAlign: TextAlign.center,
            ),            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrayerLocationEditor(),
                  ),
                ).then((_) => onLocationSet());
              },
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: const Text('Set location'),
            ),
          ],
        ),
      ),
    );
  }
}

class PrayerLocationEditor extends StatefulWidget {
  const PrayerLocationEditor({super.key});

  @override
  State<PrayerLocationEditor> createState() => _PrayerLocationEditorState();
}

class _PrayerLocationEditorState extends State<PrayerLocationEditor> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cityCtrl = TextEditingController(text: settings.prayerCity);
    final countryCtrl = TextEditingController(text: settings.prayerCountry);

    return Scaffold(
      appBar: AppBar(title: const Text('Location')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: cityCtrl,
                decoration: const InputDecoration(
                  labelText: 'City',
                  hintText: 'e.g. Makkah',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  hintText: 'e.g. Saudi Arabia',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await context.read<SettingsProvider>().setPrayerLocation(
                        cityCtrl.text.trim(),
                        countryCtrl.text.trim(),
                      );
                  navigator.pop();
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save location'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final PrayerTimes day;
  const _DayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = day.date.year == today.year &&
        day.date.month == today.month &&
        day.date.day == today.day;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isToday
            ? Ui.goldSoft(context)
            : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isToday ? 'Today' : DateFormat('EEEE, d MMM').format(day.date),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isToday ? Ui.gold(context) : null,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Icon(Icons.star, size: 14, color: Ui.gold(context)),
              ],
              const Spacer(),
              Text(
                DateFormat('d/M').format(day.date),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _TimeRow(label: 'Fajr', time: day.fajr, icon: Icons.nights_stay_outlined),
          _TimeRow(label: 'Sunrise', time: day.sunrise, icon: Icons.wb_sunny_outlined, muted: true),
          _TimeRow(label: 'Dhuhr', time: day.dhuhr, icon: Icons.wb_sunny),
          _TimeRow(label: 'Asr', time: day.asr, icon: Icons.wb_twilight),
          _TimeRow(label: 'Maghrib', time: day.maghrib, icon: Icons.sunny),
          _TimeRow(label: 'Isha', time: day.isha, icon: Icons.bedtime_outlined),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final bool muted;
  const _TimeRow({
    required this.label,
    required this.time,
    required this.icon,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: muted ? scheme.onSurfaceVariant : Ui.emerald(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: muted ? scheme.onSurfaceVariant : Ui.emerald(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Could not load prayer times.',
            style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
          ),
          const SizedBox(height: 4),
          Text(error, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
