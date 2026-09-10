import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/hasanat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';
import '../../widgets/tutorial_overlay.dart';
import 'tasbih_screen.dart';

const _prayerLabels = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

class HasanatScreen extends StatefulWidget {
  final ValueNotifier<int> selectedTab;
  final int tabIndex;

  const HasanatScreen({
    super.key,
    required this.selectedTab,
    required this.tabIndex,
  });

  @override
  State<HasanatScreen> createState() => _HasanatScreenState();
}

class _HasanatScreenState extends State<HasanatScreen> {
  final GlobalKey _heroKey = GlobalKey();
  final GlobalKey _prayerKey = GlobalKey();
  final GlobalKey _quickDhikrKey = GlobalKey();
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
        seenId: 'hasanat',
        settings: settings,
        steps: [
          TutorialStep(
            targetKey: _heroKey,
            title: 'Your daily hasanat',
            body: 'Everything you do — reading, dhikr, prayer — is tallied '
                'here. Let it encourage you, not overwhelm you: Allah is '
                'always more generous than any counter can show.',
          ),
          TutorialStep(
            targetKey: _prayerKey,
            title: 'Mark your prayers',
            body: 'Tap each prayer as you complete it, Fajr through Isha, to '
                'keep today\'s record honest.',
          ),
          TutorialStep(
            targetKey: _quickDhikrKey,
            title: 'Quick dhikr',
            body: 'Tap any phrase to count it — or open the full tasbih '
                'from the "Dhikr & tasbih" row above.',
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasanat = context.watch<HasanatProvider>();
    final today = hasanat.todayRecord;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'Hasanat',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Every good deed is counted — a gentle, encouraging tally.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 18),
            KeyedSubtree(
              key: _heroKey,
              child: _HeroCard(hasanat: hasanat, today: today),
            ),
            const SizedBox(height: 20),
            _SectionTitle(
              title: "Today's breakdown",
              trailing: DateFormat('d MMM yyyy').format(hasanat.now),
            ),
            _Ribbon(
              icon: Icons.auto_stories,
              label: 'Qur\'an read',
              detail: '${today.ayahsRead} letters · +${today.ayahsRead * kHasanatPerAyahLetter}',
              value: today.ayahsRead * kHasanatPerAyahLetter,
            ),
            _Ribbon(
              icon: Icons.favorite_border,
              label: 'Dhikr & tasbih',
              detail: '${_totalDhikr(today)} utterances · +${_totalDhikr(today) * kHasanatPerDhikr}',
              value: _totalDhikr(today) * kHasanatPerDhikr,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TasbihScreen()),
              ),
            ),
            _Ribbon(
              icon: Icons.check_circle_outline,
              label: 'Fard prayers',
              detail: '${today.prayers} / 5 · +${today.prayers * kHasanatPerPrayer}',
              value: today.prayers * kHasanatPerPrayer,
            ),
            _Ribbon(
              icon: Icons.volunteer_activism,
              label: 'Sadaqah & extra',
              detail: '+${today.donated + today.extra} custom',
              value: today.donated + today.extra,
            ),
            const SizedBox(height: 20),
            KeyedSubtree(
              key: _prayerKey,
              child: _PrayerTracker(hasanat: hasanat),
            ),
            const SizedBox(height: 20),
            KeyedSubtree(
              key: _quickDhikrKey,
              child: _DhikrQuickAdd(hasanat: hasanat),
            ),
            const SizedBox(height: 20),
            _CustomDeeds(hasanat: hasanat),
            const SizedBox(height: 20),
            _SectionTitle(title: 'Last 7 days'),
            _SevenDayChart(days: hasanat.lastDays(7)),
            const SizedBox(height: 24),
            _HasanatDeclaration(),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'اللّهُ أَكْبَر',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 20,
                  color: Ui.bismillah(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _totalDhikr(DailyHasanat d) =>
      d.dhikrCounts.values.fold(0, (a, b) => a + b);
}

class _HeroCard extends StatelessWidget {
  final HasanatProvider hasanat;
  final DailyHasanat today;
  const _HeroCard({required this.hasanat, required this.today});

  @override
  Widget build(BuildContext context) {
    final total = today.total;
    final formatted = NumberFormat.decimalPattern().format(total);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.emeraldDeep, AppColors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Text(
            formatted,
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 52,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          const Text(
            'hasanat earned today',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Stat(
                icon: Icons.local_fire_department,
                iconColor: AppColors.goldLight,
                label: 'Streak',
                value: '${hasanat.streak()}',
              ),
              const SizedBox(width: 36),
              _Stat(
                icon: Icons.hourglass_full,
                iconColor: Colors.white70,
                label: 'All time',
                value: NumberFormat.compact().format(hasanat.totalAllTime()),
              ),
              const SizedBox(width: 36),
              _Stat(
                icon: Icons.eco,
                iconColor: Colors.lightGreenAccent,
                label: 'Ayahs read',
                value: NumberFormat.compact().format(today.ayahsRead),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final int value;
  final VoidCallback? onTap;
  const _Ribbon({
    required this.icon,
    required this.label,
    required this.detail,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = NumberFormat.compact().format(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.emerald),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(detail, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text(
                  '+$shown',
                  style: TextStyle(color: Ui.gold(context), fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrayerTracker extends StatelessWidget {
  final HasanatProvider hasanat;
  const _PrayerTracker({required this.hasanat});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Today\'s prayers',
          trailing:
              '${hasanat.todayRecord.prayers} / 5 · +${hasanat.todayRecord.prayers * kHasanatPerPrayer}',
        ),
        Row(
          children: List.generate(5, (i) {
            final marked = hasanat.todayRecord.prayers > i;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: marked
                      ? AppColors.emeraldSoft
                      : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      final current = hasanat.todayRecord.prayers;
                      if (marked && current == i + 1) {
                        hasanat.removePrayer();
                      } else {
                        // Mark up to this prayer as completed.
                        final needed = (i + 1) - current;
                        for (var k = 0; k < needed; k++) {
                          hasanat.addPrayer();
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        children: [
                          Icon(
                            marked ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: marked ? AppColors.emerald : scheme.onSurfaceVariant,
                            size: 22,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _prayerLabels[i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: marked ? Ui.emerald(context) : scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _DhikrQuickAdd extends StatelessWidget {
  final HasanatProvider hasanat;
  const _DhikrQuickAdd({required this.hasanat});

  static const _quick = [
    ('سُبْحَانَ اللَّه', 'Subhan Allah'),
    ('الْحَمْدُ لِلَّه', 'Alhamdulillah'),
    ('اللَّهُ أَكْبَر', 'Allahu Akbar'),
    ('أَسْتَغْفِرُ الله', 'Astaghfirullah'),
    ('لَا إِلَهَ إِلَّا الله', 'La ilaha illallah'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = hasanat.todayRecord;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Quick dhikr',
          trailing: '+${_total(today) * kHasanatPerDhikr} · ${_total(today)}',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (ar, en) in _quick)
              Material(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => hasanat.increaseDhikr(ar),
                  onLongPress: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TasbihScreen()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      children: [
                        Text(
                          ar,
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 18,
                            color: Ui.bismillah(context),
                          ),
                        ),
                        Text(
                          en,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  int _total(DailyHasanat d) => d.dhikrCounts.values.fold(0, (a, b) => a + b);
}

class _CustomDeeds extends StatelessWidget {
  final HasanatProvider hasanat;
  const _CustomDeeds({required this.hasanat});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Sadaqah & extra deeds'),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => hasanat.addDonation(amount: 1),
              icon: const Icon(Icons.volunteer_activism, size: 18),
              label: const Text('Sadaqah +1'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => hasanat.addExtra(1),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Extra +1'),
            ),
            const SizedBox(width: 10),
            IconButton.outlined(
              tooltip: 'Muslims — custom good deed',
              onPressed: () => hasanat.addExtra(10),
              icon: const Text('+10'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SevenDayChart extends StatelessWidget {
  final List<DailyHasanat> days;
  const _SevenDayChart({required this.days});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    double maxVal = 1;
    for (final d in days) {
      if (d.total > maxVal) maxVal = d.total.toDouble();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(days.length, (i) {
          final d = days[i];
          final height = 120 * (d.total / maxVal);
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (d.total > 0)
                  Text(
                    NumberFormat.compact().format(d.total),
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                  ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: height.clamp(2, 120),
                  decoration: BoxDecoration(
                    gradient: height > 30
                        ? const LinearGradient(
                            colors: [AppColors.emerald, AppColors.teal],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          )
                        : null,
                    color: height > 30 ? null : AppColors.goldSoft,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('E').format(d.date),
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// A gentle, honest note about how this tally relates to true reward.
class _HasanatDeclaration extends StatelessWidget {
  const _HasanatDeclaration();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.goldSoft.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.12 : 1,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, size: 18, color: Ui.gold(context)),
              const SizedBox(width: 8),
              Text(
                'An honest note',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Ui.gold(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Allah is always far more generous than any counter can show. '
            'This tally is only a gentle encouragement, built to match Islamic '
            'teachings as faithfully as the developer could. Allah knows '
            'best — and He is ever Merciful.',
            style: TextStyle(fontSize: 13, height: 1.5, color: scheme.onSurface),
          ),
          const SizedBox(height: 10),
          Text(
            'Whatever in this app was done right, every credit belongs to '
            'Allah. For any shortcoming, the developer seeks Allah\'s '
            'forgiveness, and asks Allah to accept this work and have mercy '
            'on him and on everyone who helps or benefits from it. '
            'اللَّهُمَّ تَقَبَّلْ وَارْحَمْ.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}