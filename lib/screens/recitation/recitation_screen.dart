import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/quran_provider.dart';
import '../../providers/recitation_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';
import '../../widgets/download_prompt.dart';
import '../../widgets/reciter_picker.dart';
import '../../widgets/tutorial_overlay.dart';
import 'player_screen.dart';

class RecitationScreen extends StatefulWidget {
  final ValueNotifier<int> selectedTab;
  final int tabIndex;

  const RecitationScreen({
    super.key,
    required this.selectedTab,
    required this.tabIndex,
  });

  @override
  State<RecitationScreen> createState() => _RecitationScreenState();
}

class _RecitationScreenState extends State<RecitationScreen> {
  int _selectedSurah = 1;
  int _lastRev = -1;
  String? _lastReciterId; // null forces first scan
  Future<Set<int>>? _downloadedFuture;
  final GlobalKey _reciterKey = GlobalKey();
  final GlobalKey _audioKey = GlobalKey();
  bool _tutorialQueued = false;

  @override
  void initState() {
    super.initState();
    widget.selectedTab.addListener(_maybeShowTutorial);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
    final settings = context.read<SettingsProvider>();
    _selectedSurah = settings.lastRead != null
        ? int.tryParse(settings.lastRead!.split(':').first) ?? 1
        : 1;
    context.read<QuranProvider>().ensureLoaded();
    _rec = context.read<RecitationProvider>();
    _rec.addListener(_onRecChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rec.refreshDownloadState(_rec.reciter, _selectedSurah);
    });
  }

  @override
  void dispose() {
    widget.selectedTab.removeListener(_maybeShowTutorial);
    _rec.removeListener(_onRecChanged);
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
        seenId: 'recitation',
        settings: settings,
        steps: [
          TutorialStep(
            targetKey: _reciterKey,
            title: 'Choose a reciter',
            body: 'Tap here to pick the reciter whose voice you prefer.',
          ),
          TutorialStep(
            targetKey: _audioKey,
            title: 'Download once, play offline',
            body: 'Every surah downloads for the selected reciter. After '
                'downloading, it plays fully offline with no internet needed.',
          ),
        ],
      );
    });
  }

  late final RecitationProvider _rec;

  void _onRecChanged() {
    final error = _rec.takeDownloadError(_rec.reciter, _selectedSurah) ??
        _rec.takePlaybackError();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  /// Re-scans the disk only when the revision or reciter actually changed, so
  /// progress ticks (which fire often) don't trigger file-system walks.
  Future<Set<int>> _downloadedFor(RecitationProvider rec) {
    if (rec.downloadRevision != _lastRev ||
        _lastReciterId != rec.reciter.identifier) {
      _lastRev = rec.downloadRevision;
      _lastReciterId = rec.reciter.identifier;
      _downloadedFuture = rec.downloadedSurahs(rec.reciter);
    }
    return _downloadedFuture!;
  }

  /// Plays a surah tapped from the "Downloaded" section (download prompt is
  /// skipped when it's already saved).
  Future<void> _playSelected({
    required QuranProvider quran,
    required RecitationProvider rec,
  }) async {
    final surah = quran.surah(_selectedSurah);
    if (surah == null) return;
    final ready = await showDownloadPrompt(
      context,
      rec: rec,
      reciter: rec.reciter,
      surah: surah,
    );
    if (!ready || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlayerScreen()),
    );
    unawaited(rec.playSurah(rec.reciter, surah.number));
  }

  @override
  Widget build(BuildContext context) {
    final quran = context.watch<QuranProvider>();
    final rec = context.watch<RecitationProvider>();

    if (quran.isLoading || !quran.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final surah = quran.surah(_selectedSurah)!;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'Recitation',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Download a surah once, then it plays fully offline — '
              'no streaming needed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 18),
            // Reciter card.
            KeyedSubtree(
              key: _reciterKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reciter',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _openReciterPicker(),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.emeraldSoft,
                            child: Text(
                              rec.reciter.arabicName.substring(0, 1),
                              style: const TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 22,
                                color: AppColors.emeraldDeep,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rec.reciter.englishName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  rec.reciter.arabicName,
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 16,
                                    color: Ui.bismillah(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Surah selector.
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 114,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final n = i + 1;
                  final selected = n == _selectedSurah;
                  return ChoiceChip(
                    label: Text('$n'),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() => _selectedSurah = n);
                      context
                          .read<RecitationProvider>()
                          .refreshDownloadState(rec.reciter, n);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Surah info card.
            KeyedSubtree(
              key: _audioKey,
              child: _SurahAudioCard(surah: surah),
            ),
            const SizedBox(height: 24),
            // Downloaded surahs for the current reciter.
            FutureBuilder<Set<int>>(
              future: _downloadedFor(rec),
              builder: (context, snap) {
                final done = snap.data;
                if (done == null) return const SizedBox.shrink();
                final n = done.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Downloaded',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        if (n > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$n of 114',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.emeraldDeep,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (n == 0)
                      Text(
                        'Nothing downloaded for ${rec.reciter.englishName} yet. '
                        'Use the button above, or play any surah to be prompted.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in done.toList()..sort())
                            ActionChip(
                              avatar: Icon(
                                Icons.check_circle,
                                size: 16,
                                color: AppColors.emerald,
                              ),
                              label: Text(s.toString()),
                              onPressed: () {
                                setState(() => _selectedSurah = s);
                                _playSelected(quran: quran, rec: rec);
                              },
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text('Playback', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Recitation plays only from downloaded files. Pressing Play on '
              'a surah that isn\'t saved yet asks to download it first — once '
              'downloaded it works offline with the selected reciter.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  void _openReciterPicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ReciterPickerSheet(
          initialReciter: context.read<RecitationProvider>().reciter,
          scrollController: scrollController,
          onSelected: (r) {
            context.read<RecitationProvider>().selectReciter(r);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

class _SurahAudioCard extends StatelessWidget {
  final Surah surah;
  const _SurahAudioCard({required this.surah});

  @override
  Widget build(BuildContext context) {
    final rec = context.watch<RecitationProvider>();
    final status = rec.downloadStatus(rec.reciter, surah.number);
    final progress = rec.downloadProgress(rec.reciter, surah.number);

    return Container(
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
            children: [
              Text(
                '${surah.number}. ${surah.transliteration}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                QurNum.arabicDigits(surah.ayahCount),
                style: const TextStyle(color: AppColors.goldLight, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${surah.translatedName} — ${surah.revelationType}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _RectButton.light(
                icon: Icons.play_arrow,
                label: 'Play',
                onTap: () => _play(context, rec, surah),
              ),
              const SizedBox(width: 10),
              if (status == DownloadStatus.downloading) ...[
                _RectButton.light(
                  icon: Icons.hourglass_top,
                  label: '$progress%',
                  onTap: null,
                ),
              ] else if (status == DownloadStatus.done) ...[
                _RectButton.light(
                  icon: Icons.check,
                  label: 'Downloaded',
                  onTap: () => context
                      .read<RecitationProvider>()
                      .deleteSurah(rec.reciter, surah.number),
                ),
              ] else if (status == DownloadStatus.failed) ...[
                _RectButton.light(
                  icon: Icons.refresh,
                  label: 'Retry',
                  onTap: () {
                    context
                        .read<RecitationProvider>()
                        .downloadSurah(rec.reciter, surah.number);
                  },
                ),
              ] else ...[
                _RectButton.light(
                  icon: Icons.download,
                  label: 'Download',
                  onTap: () => context
                      .read<RecitationProvider>()
                      .downloadSurah(rec.reciter, surah.number),
                ),
              ],
              const SizedBox(width: 10),
              _RectButton.light(
                icon: Icons.delete_outline,
                label: 'Clear',
                onTap: () => context
                    .read<RecitationProvider>()
                    .deleteSurah(rec.reciter, surah.number),
              ),
            ],
          ),
          if (status == DownloadStatus.downloading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 6,
                backgroundColor: Colors.white24,
                color: AppColors.goldLight,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Downloading ayahs… you can keep using the app.',
              style: TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.4),
            ),
          ] else if (status == DownloadStatus.done) ...[
            const SizedBox(height: 12),
            const Text(
              'Downloaded — plays offline with this reciter.',
              style: TextStyle(color: AppColors.goldLight, fontSize: 12, height: 1.4),
            ),
          ] else if (status == DownloadStatus.failed) ...[
            const SizedBox(height: 12),
            const Text(
              'Download failed — tap Retry to try again.',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Text(
              'Tap Download to save this surah for offline listening.',
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
/// Download-first playback: prompts to save the surah for the selected
  /// reciter (with progress), then opens the player.
  Future<void> _play(
    BuildContext context,
    RecitationProvider rec,
    Surah surah,
  ) async {
    if (rec.isDownloading(rec.reciter, surah.number)) return;

    final ready = await showDownloadPrompt(
      context,
      rec: rec,
      reciter: rec.reciter,
      surah: surah,
    );
    if (!ready || !context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlayerScreen()),
    );
    unawaited(rec.playSurah(rec.reciter, surah.number));
  }
}

class _RectButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _RectButton.light({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}