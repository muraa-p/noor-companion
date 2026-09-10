import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/notification_service.dart';
import '../../data/prayer_time_service.dart';
import '../../data/static_content.dart';
import '../../providers/recitation_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TimeOfDay? _draftReminderTime;

  @override
  void initState() {
    super.initState();
    final minutes = context.read<SettingsProvider>().reminderTimeMinutes;
    _draftReminderTime = TimeOfDay(
      hour: minutes ~/ 60,
      minute: minutes % 60,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _SectionLabel('Appearance'),
            SwitchListTile(
              secondary: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
              ),
              title: const Text('Dark theme'),
              subtitle: const Text('Follows what\'s on screen right now'),
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (v) => settings.setTheme(
                v ? ThemeMode.dark : ThemeMode.light,
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.translate),
              title: const Text('Show English translation'),
              subtitle: const Text('In the surah reader'),
              value: settings.showTranslation,
              onChanged: (v) => settings.setShowTranslation(v),
            ),
            _Tile(
              icon: Icons.brightness_6,
              title: 'Theme',
              subtitle: settings.theme.name,
              onTap: () => _pickTheme(context),
            ),
            _SliderTile(
              icon: Icons.text_fields,
              title: 'Arabic font size',
              value: settings.arabicFontSize,
              min: 18,
              max: 40,
              divisions: 11,
              label: '${settings.arabicFontSize}',
              onChange: (v) => settings.setArabicFontSize(v),
            ),
            _SliderTile(
              icon: Icons.format_size,
              title: 'Translation font size',
              value: settings.latinFontSize,
              min: 12,
              max: 24,
              divisions: 12,
              label: '${settings.latinFontSize}',
              onChange: (v) => settings.setLatinFontSize(v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration),
              title: const Text('Haptic feedback'),
              value: settings.haptics,
              onChanged: (v) => settings.setHaptics(v),
            ),
            const Divider(),
            _SectionLabel('Daily reminder'),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Daily Qur\'an reminder'),
              subtitle: const Text('A soft nudge to read a little each day'),
              value: settings.dailyReminder,
              onChanged: (v) => _setReminder(v),
            ),
            if (settings.dailyReminder) ...[
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Reminder time'),
                subtitle: Text(_format(_draftReminderTime!)),
                onTap: () => _pickReminderTime(),
              ),
            ],
            _SectionLabel('Recitation'),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Default reciter'),
              subtitle: Text(
                context.watch<RecitationProvider>().reciter.englishName,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openReciterSheet(),
            ),
            const Divider(),
            _SectionLabel('Prayer times'),
            ListTile(
              leading: const Icon(Icons.location_city),
              title: const Text('City / Country'),
              subtitle: Text(
                settings.prayerCity.isEmpty
                    ? 'Set your location for accurate times'
                    : '${settings.prayerCity}, ${settings.prayerCountry}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _editLocation(),
            ),
            _Tile(
              icon: Icons.wb_sunny_outlined,
              title: 'Calculation method',
              subtitle: PrayerTimeService.methods[settings.prayerMethod] ?? '',
              onTap: () => _pickMethod(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _format(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final suffix = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $suffix';
  }

  Future<void> _setReminder(bool enabled) async {
    final settings = context.read<SettingsProvider>();
    await settings.setDailyReminder(enabled);
    final t = _draftReminderTime!;
    if (enabled) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: t.hour,
        minute: t.minute,
      );
    } else {
      await NotificationService.instance.cancelDaily();
    }
  }

  Future<void> _pickReminderTime() async {
    final settings = context.read<SettingsProvider>();
    final picked = await showTimePicker(
      context: context,
      initialTime: _draftReminderTime!,
    );
    if (picked == null || !mounted) return;
    setState(() => _draftReminderTime = picked);
    await settings.setReminderTime(
      '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
    );
    if (settings.dailyReminder) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: picked.hour,
        minute: picked.minute,
      );
    }
  }

  void _pickTheme(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: context.watch<SettingsProvider>().theme,
          onChanged: (v) {
            if (v != null) {
              context.read<SettingsProvider>().setTheme(v);
              Navigator.of(ctx).pop();
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in ThemeMode.values)
                RadioListTile<ThemeMode>(
                  title: Text(mode.name),
                  value: mode,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openReciterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: kReciters.length,
          itemBuilder: (context, i) {
            final r = kReciters[i];
            final rec = context.watch<RecitationProvider>();
            final selected = r.identifier == rec.reciter.identifier;
            return ListTile(
              title: Text(r.englishName),
              subtitle: Text(r.arabicName),
              trailing: selected
                  ? const Icon(Icons.check_circle, color: AppColors.emerald)
                  : null,
              onTap: () {
                context.read<RecitationProvider>().selectReciter(r);
                Navigator.of(ctx).pop();
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _editLocation() async {
    final settings = context.read<SettingsProvider>();
    final cityController = TextEditingController(text: settings.prayerCity);
    final countryController = TextEditingController(text: settings.prayerCountry);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Prayer times location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cityController,
              decoration: const InputDecoration(labelText: 'City', hintText: 'e.g. Makkah'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: countryController,
              decoration: const InputDecoration(labelText: 'Country', hintText: 'e.g. Saudi Arabia'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop((
              cityController.text.trim(),
              countryController.text.trim(),
            )),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await settings.setPrayerLocation(result.$1, result.$2);
    }
  }

  void _pickMethod() {
    final settings = context.read<SettingsProvider>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: PrayerTimeService.methods.length,
          itemBuilder: (context, i) {
            final entry = PrayerTimeService.methods.entries.elementAt(i);
            final selected = entry.key == settings.prayerMethod;
            return ListTile(
              title: Text(entry.value),
              trailing: selected
                  ? const Icon(Icons.check_circle, color: AppColors.emerald)
                  : null,
              onTap: () {
                settings.setPrayerMethod(entry.key);
                Navigator.of(ctx).pop();
              },
            );
          },
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChange;
  const _SliderTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChange,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: Ui.gold(context),
        ),
      ),
    );
  }
}