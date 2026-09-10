import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/static_content.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../widgets/tutorial_overlay.dart';
import '../adhkar/names_of_allah_screen.dart';
import 'prayer_times_screen.dart';
import 'settings_screen.dart';

/// Who Noor is made for, shown on the Sadaqah Jariyah screen.
const String kDedication = 'my family, my beloved ones, my friends, my '
    'acquaintances, my grandparents — both those alive and those who have '
    'passed away — and all Muslims, living and those who have passed away, '
    'and every person who makes use of this app. '
    'أُهديه إلى عائلتي وأحبابي وأصدقائي ومعارفي، وإلى أجدادي أحياءً وأمواتًا، '
    'وإلى جميع المسلمين أحياءً وأمواتًا، وإلى كل من يستفيد من هذا العمل';

class MoreScreen extends StatefulWidget {
  final ValueNotifier<int> selectedTab;
  final int tabIndex;

  const MoreScreen({
    super.key,
    required this.selectedTab,
    required this.tabIndex,
  });

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final GlobalKey _prayerTimesKey = GlobalKey();
  final GlobalKey _settingsKey = GlobalKey();
  bool _tutorialQueued = false;

  @override
  void initState() {
    super.initState();
    widget.selectedTab.addListener(_maybeShowTutorial);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  @override
  void dispose() {
    widget.selectedTab.removeListener(_maybeShowTutorial);
    super.dispose();
  }

  void _maybeShowTutorial() {
    if (_tutorialQueued) return;
    if (widget.selectedTab.value != widget.tabIndex) return;
    if (!mounted) return;
    _tutorialQueued = true;
    final settings = context.read<SettingsProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showTutorialOnce(
        context,
        seenId: 'more',
        settings: settings,
        steps: [
          TutorialStep(
            targetKey: _prayerTimesKey,
            title: 'Prayer times',
            body: 'Take a moment to set your city once — the app then shows '
                'prayer times, keeps them handy, and can remind you.',
          ),
          TutorialStep(
            targetKey: _settingsKey,
            title: 'Make it yours',
            body: 'Tune the theme, font size, reciter, and reminders from '
                'the settings screen.',
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'More',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const ThemeToggleButton(),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tools, knowledge and settings.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            KeyedSubtree(
              key: _prayerTimesKey,
              child: _Tile(
                icon: Icons.access_time,
                iconBg: AppColors.emeraldSoft,
                iconColor: AppColors.emerald,
                title: 'Prayer Times',
                subtitle: 'Fajr to Isha, based on your city',
                onTap: () => _push(context, const PrayerTimesScreen()),
              ),
            ),
            KeyedSubtree(
              key: _settingsKey,
              child: _Tile(
                icon: Icons.settings,
                iconBg: AppColors.emeraldSoft,
                iconColor: AppColors.emerald,
                title: 'Settings',
                subtitle: 'Theme, fonts, reciter, reminders',
                onTap: () => _push(context, const SettingsScreen()),
              ),
            ),
            _Tile(
              icon: Icons.filter_9_plus,
              iconBg: AppColors.goldSoft,
              iconColor: AppColors.goldDark,
              title: '99 Beautiful Names',
              subtitle: 'Memorise and count',
              onTap: () => _push(context, const NamesOfAllahScreen()),
            ),
            _Tile(
              icon: Icons.eco,
              iconBg: AppColors.emeraldSoft,
              iconColor: AppColors.emerald,
              title: 'How hasanat are counted',
              subtitle: 'The teaching behind the tally',
              onTap: () => _showMethodology(context),
            ),
            _Tile(
              icon: Icons.volunteer_activism,
              iconBg: AppColors.goldSoft,
              iconColor: AppColors.goldDark,
              title: 'Sadaqah Jariyah',
              subtitle: 'Who this app is made for, & thanks',
              onTap: () => _showDedication(context),
            ),
            _Tile(
              icon: Icons.storefront,
              iconBg: AppColors.emeraldSoft,
              iconColor: AppColors.emerald,
              title: 'Share Noor',
              subtitle: 'Open it on the Play Store',
              onTap: () => _shareOrOpenStore(context),
            ),
            const SizedBox(height: 30),
            const Center(
              child: Text(
                'نُور',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: AppColors.emerald,
                ),
              ),
            ),
            Center(
              child: Text(
                'Noor — Qur\'an, hasanat & remembrance',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _showMethodology(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How hasanat are counted'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MethRow(
                name: 'Reading the Qur\'an',
                value: '10 hasanat per letter read',
                detail: 'Narrated by At-Tirmidhi (2910): whoever reads a letter '
                    'of the Qur\'an earns a good deed, and a good deed is '
                    'multiplied tenfold.',
              ),
              _MethRow(
                name: 'Dhikr & tasbih',
                value: '10 per utterance',
                detail: 'Remembrance of Allah is the most beloved of deeds; '
                    'counted modestly at ten per utterance.',
              ),
              _MethRow(
                name: 'Fard prayers',
                value: '50 for a completed prayer',
                detail: 'The five daily prayers are weighted as significant '
                    'acts of worship carried out throughout the day.',
              ),
              _MethRow(
                name: 'Sadaqah & extra',
                value: 'Add your own',
                detail: 'You may add custom good deeds (e.g. helping, patience) '
                    'as your own honest tally.',
              ),
              _MethRow(
                name: 'Read once, counted once',
                value: 'Fair counting',
                detail: 'Each ayah is credited on its first mark so users don\'t '
                    'farm the counter by re-reading the same lines.',
              ),
              _MethRow(
                name: 'Remember',
                value: 'Sincerity',
                detail: 'True reward (thawab) is with Allah. Use this tally as '
                    'motivation, not as a precise amal al-mizan.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDedication(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sadaqah Jariyah'),
        content: const SingleChildScrollView(
          child: Text(
            'هذا العمل صدقة جارية\n\n'
            'This app is made as Sadaqah Jariyah — an ongoing charity whose '
            'reward continues after us, by the will of Allah.\n\n'
            'It is dedicated to:\n\n$kDedication\n\n'
            'اللهم تقبلها واجعلها خالصة لوجهك الكريم، واجعلها في ميزان حسنات '
            'كل من ساهم فيها واستفاد منها\n\n'
            'With deep thanks to every hand that helped and every heart that '
            'encouraged this work along the way — may Allah reward you all.\n\n'
            'Data credits: Qur\'an text (quran-api, Uthmani script), '
            'translation (M.A.S. Abdel Haleem, Oxford), audio (Islamic Network '
            'CDN) and prayer times (Aladhan API).',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Opens the Play Store listing once published; until [kPlayStoreUrl] is
  /// set, falls back to sharing a short invite message.
  Future<void> _shareOrOpenStore(BuildContext context) async {
    if (kPlayStoreUrl.isNotEmpty) {
      final uri = Uri.parse(kPlayStoreUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the Play Store.')),
        );
      }
      return;
    }
    await SharePlus.instance.share(ShareParams(
      text:
          'Noor — a serene Qur\'an app with recitation, adhkar and '
          'a daily hasanat counter. May Allah accept it from us all.',
    ));
  }
}

class _MethRow extends StatelessWidget {
  final String name;
  final String value;
  final String detail;
  const _MethRow({required this.name, required this.value, required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name — $value',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(fontSize: 13, height: 1.4, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Tile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: iconColor),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}