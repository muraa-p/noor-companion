import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/quran_provider.dart';
import '../../providers/recitation_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';
import '../../widgets/surah_card.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../widgets/tutorial_overlay.dart';
import 'search_screen.dart';
import 'surah_reader_screen.dart';
import '../more/prayer_times_screen.dart';

class QuranScreen extends StatefulWidget {
  final ValueNotifier<int> selectedTab;
  final int tabIndex;

  const QuranScreen({
    super.key,
    required this.selectedTab,
    required this.tabIndex,
  });

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final GlobalKey _themeKey = GlobalKey();
  final GlobalKey _continueKey = GlobalKey();
  bool _tutorialQueued = false;

  @override
  void initState() {
    super.initState();
    widget.selectedTab.addListener(_maybeShowTutorial);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
    context.read<QuranProvider>().ensureLoaded();
    final rec = context.read<RecitationProvider>();
    rec.refreshAllStates(rec.reciter);
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
        seenId: 'home',
        settings: settings,
        steps: [
          TutorialStep(
            targetKey: _themeKey,
            title: 'Dark & bright mode',
            body: 'Switch between dark and bright mode any time from this '
                'button. Reading in the dark is gentler on the eyes.',
          ),
          TutorialStep(
            targetKey: _continueKey,
            title: 'Continue reading',
            body: 'Your reading position is saved automatically. Tap this '
                'card to pick up where you left off.',
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final quran = context.watch<QuranProvider>();
    final settings = context.watch<SettingsProvider>();
    final rec = context.watch<RecitationProvider>();

    return Scaffold(
      body: SafeArea(
        child: quran.isLoading
            ? const _LoadingView()
            : quran.error != null
                ? _ErrorView(error: quran.error!)
                : RefreshIndicator(
                    onRefresh: () => quran.ensureLoaded(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _Header(settings: settings, themeKey: _themeKey)),
                        SliverToBoxAdapter(
                          child: _AyahOfDayCard(ayah: quran.ayahOfTheDay(DateTime.now())),
                        ),
                        SliverToBoxAdapter(
                          child: KeyedSubtree(
                            key: _continueKey,
                            child: _ContinueReadingCard(
                              lastRead: settings.lastRead,
                              onOpen: (surah, ayah) => _openReader(
                                context,
                                surahNumber: surah,
                                ayahNumber: ayah,
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                            child: Row(
                              children: [
                                Text(
                                  'Surahs',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const SearchScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.search, size: 18),
                                  label: const Text('Search'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                          sliver: SliverList.builder(
                            itemCount: quran.surahs.length,
                            itemBuilder: (context, i) {
                              final surah = quran.surahs[i];
                              final status =
                                  rec.downloadStatus(rec.reciter, surah.number);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Builder(
                                  builder: (context) {
                                    return SurahCard(
                                      surah: surah,
                                      downloaded: status == DownloadStatus.done,
                                      isDownloading:
                                          status == DownloadStatus.downloading,
                                      downloadProgress:
                                          rec.downloadProgress(rec.reciter, surah.number) / 100,
                                      onTap: () => _openSurah(
                                        context,
                                        surah,
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  void _openReader(
    BuildContext context, {
    required int surahNumber,
    int ayahNumber = 1,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SurahReaderScreen(
          surahNumber: surahNumber,
          initialAyah: ayahNumber,
        ),
      ),
    );
  }

  /// Opens a surah from the grid. If the reader left a saved position for it,
  /// first asks whether to resume exactly there or to start over.
  Future<void> _openSurah(BuildContext context, Surah surah) async {
    final settings = context.read<SettingsProvider>();
    final pos = settings.positionOf(surah.number);
    if (pos == null || pos.ayah <= 1) {
      _openReader(context, surahNumber: surah.number);
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${surah.number}. ${surah.transliteration}',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'You left off at ayah '
                  '${QurNum.arabicDigits(pos.ayah)}. Where would you like '
                  'to go?',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.history, color: Ui.gold(ctx)),
                title: const Text(
                  'Continue from where you left',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Resume at ayah ${QurNum.arabicDigits(pos.ayah)}',
                ),
                onTap: () => Navigator.of(ctx).pop('continue'),
              ),
              ListTile(
                leading: const Icon(Icons.replay),
                title: const Text(
                  'Read from the start',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Begin from the first ayah'),
                onTap: () => Navigator.of(ctx).pop('start'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || choice == null) return;
    if (choice == 'continue') {
      _openReader(context, surahNumber: surah.number, ayahNumber: pos.ayah);
    } else {
      await settings.clearSurahPosition(surah.number);
      if (!context.mounted) return;
      _openReader(context, surahNumber: surah.number, ayahNumber: 1);
    }
  }
}

class _Header extends StatelessWidget {
  final SettingsProvider settings;
  final GlobalKey? themeKey;
  const _Header({required this.settings, this.themeKey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'As-Salamu Alaykum',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: 'Amiri',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrayerTimesScreen()),
            ),
            child: Tooltip(
              message: 'Prayer times',
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.emeraldSoft,
                child: const Icon(Icons.mosque, color: AppColors.emeraldDeep),
              ),
            ),
          ),
          const SizedBox(width: 10),
          KeyedSubtree(key: themeKey, child: const ThemeToggleButton()),
        ],
      ),
    );
  }
}

class _AyahOfDayCard extends StatelessWidget {
  final Ayah ayah;
  const _AyahOfDayCard({required this.ayah});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.emeraldDeep, AppColors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, color: AppColors.goldLight, size: 18),
              SizedBox(width: 6),
              Text(
                'Ayah of the Day',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              ayah.arabic,
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontSize: 22,
                height: 1.9,
                color: Colors.white,
              ),
            ),
          ),
          if (ayah.english.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              ayah.english,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Surah ${ayah.surahNumber}:${ayah.numberInSurah}',
            style: const TextStyle(color: AppColors.goldLight, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  final String? lastRead;
  final void Function(int surah, int ayah) onOpen;
  const _ContinueReadingCard({required this.lastRead, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = lastRead?.split(':');
    final surahNum = parts != null && parts.length == 2
        ? int.tryParse(parts[0])
        : null;
    final ayahNum = parts != null && parts.length == 2
        ? int.tryParse(parts[1])
        : null;

    if (surahNum == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        child: Text(
          'Start your journey — open any surah to begin reciting.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final quran = context.watch<QuranProvider>();
    final surah = quran.surah(surahNum);
    if (surah == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onOpen(surahNum, ayahNum ?? 1),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.history, color: Ui.gold(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Continue: ${surah.transliteration} · ${QurNum.arabicDigits(ayahNum ?? 1)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Preparing the Qur\'an...'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            const Text('Could not load the Qur\'an'),
            const SizedBox(height: 6),
            Text(error, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}