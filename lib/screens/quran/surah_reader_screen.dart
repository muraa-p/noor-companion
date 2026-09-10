import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/models.dart';
import '../../providers/hasanat_provider.dart';
import '../../providers/quran_provider.dart';
import '../../providers/recitation_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';
import '../../data/mushaf_pages.dart';
import '../../widgets/ayah_tile.dart';
import '../../widgets/download_prompt.dart';
import '../../widgets/reciter_picker.dart';
import '../../widgets/tutorial_overlay.dart';
import '../recitation/player_screen.dart';

class SurahReaderScreen extends StatefulWidget {
  final int surahNumber;
  final int initialAyah;

  const SurahReaderScreen({
    super.key,
    required this.surahNumber,
    this.initialAyah = 1,
  });

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  final List<GlobalKey> _ayahKeys = [];
  final ScrollController _controller = ScrollController();
  bool _showTranslation = true;
  bool _scrolledToInitial = false;
  SettingsProvider? _settings;
  BuildContext? _viewportContext;

  // Coach-mark targets: jump-to-ayah (AppBar), Read page + play (bottom bar).
  final GlobalKey _jumpKey = GlobalKey();
  final GlobalKey _readPageKey = GlobalKey();
  final GlobalKey _playKey = GlobalKey();

  /// Topmost visible ayah as of the last scroll (saved on exit as the
  /// "Continue reading" bookmark).
  int _lastTopAyah = 1;

  /// Current mushaf page number (1..604) based on Madani 15-line pagination.
  int _currentMushafPage = 1;

  @override
  void initState() {
    super.initState();
    _showTranslation = context.read<SettingsProvider>().showTranslation;
    _settings = context.read<SettingsProvider>();
    _lastTopAyah = widget.initialAyah;
    _controller.addListener(_trackPage);
    final quran = context.read<QuranProvider>();
    if (!quran.isLoaded) {
      quran.ensureLoaded();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeShowTutorial();
    });
  }

  /// First-visit coach marks: spotlight the reader's core actions once, then
  /// never again (persisted, so a skipped tutorial also counts as seen).
  void _maybeShowTutorial() {
    final settings = context.read<SettingsProvider>();
    if (settings.readerTutorialSeen) return;
    final surah = context.read<QuranProvider>().surah(widget.surahNumber);
    if (surah == null) return;

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            TutorialOverlay(
          steps: [
            TutorialStep(
              targetKey: _readPageKey,
              title: 'Read page',
              body: 'Tap "Read page" to count every ayah on this mushaf page '
                  'and earn hasanat for its letters.',
            ),
            TutorialStep(
              targetKey: _jumpKey,
              title: 'Jump to any ayah',
              body: 'Use this button to jump straight to a specific ayah in '
                  'this surah.',
            ),
            TutorialStep(
              targetKey: _playKey,
              title: 'Listen to this surah',
              body: 'Pick a reciter, download the surah, then play it. Tap any '
                  'ayah to play from that point, or open the full player from '
                  'the bar below.',
            ),
          ],
          onFinished: () => settings.setReaderTutorialSeen(),
        ),
      ),
    );
  }

  void _trackPage() {
    if (!_controller.hasClients) return;
    final surah = context.read<QuranProvider>().surah(widget.surahNumber);
    if (surah == null) return;
    // First visible ayah, tracked exactly from each built ayah's render
    // position so resuming lands on the very line the user stopped at.
    final first = _firstVisibleAyah(surah);
    _lastTopAyah = first;
    // Convert first visible ayah to global number, then to mushaf page
    final firstAyah = surah.ayahs[first - 1];
    final globalAyah = firstAyah.globalNumber;
    final mushafPage = MushafPages.pageOfGlobalAyah(globalAyah);
    if (mushafPage != _currentMushafPage) {
      setState(() {
        _currentMushafPage = mushafPage.clamp(1, 604).toInt();
      });
    }
  }

  /// Exact topmost ayah using each built ayah's render position; falls back
  /// to the average-height estimate while the list is still laying out (the
  /// raw estimate is negative near the header or past the last ayah at the
  /// bottom, so it is clamped to the surah's range).
  int _firstVisibleAyah(Surah surah) {
    final vp = _viewportContext;
    if (vp != null) {
      final ro = vp.findRenderObject();
      if (ro is RenderBox) {
        final vpTop = ro.localToGlobal(Offset.zero).dy;
        final vpBottom = vpTop + ro.size.height;
        for (var i = 1; i < _ayahKeys.length; i++) {
          final ctx = _ayahKeys[i].currentContext;
          if (ctx == null) continue;
          final box = ctx.findRenderObject();
          if (box is! RenderBox) continue;
          final top = box.localToGlobal(Offset.zero).dy;
          final bottom = top + box.size.height;
          if (bottom > vpTop && top < vpBottom) {
            return i;
          }
        }
      }
    }
    return (((_controller.offset - _estimateOffset(1)) / _avgAyahHeight())
                .floor() +
            1)
        .clamp(1, surah.ayahCount);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize keys once the surah is known.
    final surah = context.read<QuranProvider>().surah(widget.surahNumber);
    if (surah != null && _ayahKeys.isEmpty) {
      for (var i = 0; i <= surah.ayahCount; i++) {
        _ayahKeys.add(GlobalKey());
      }
    }
    if (surah != null && !_scrolledToInitial && _ayahKeys.isNotEmpty) {
      _scrolledToInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToAyah(widget.initialAyah);
      });
    }
  }

  @override
  void dispose() {
    // Bookmark where the reader was left so "Continue reading" on the home
    // screen and this surah's own resume point both reopen at the exact ayah.
    _settings?.setLastRead(widget.surahNumber, _lastTopAyah);
    _settings?.setSurahPosition(
      widget.surahNumber,
      _lastTopAyah,
      page: _currentMushafPage,
    );
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quran = context.watch<QuranProvider>();
    final settings = context.watch<SettingsProvider>();
    final surah = quran.surah(widget.surahNumber);

    if (surah == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${surah.number}. ${surah.transliteration}'),
            Text(
              surah.translatedName,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: _jumpKey,
            tooltip: 'Jump to ayah',
            onPressed: _showJumpSheet,
            icon: const Icon(Icons.center_focus_strong_outlined),
          ),
          IconButton(
            tooltip: 'Toggle translation',
            onPressed: () {
              setState(() => _showTranslation = !_showTranslation);
              settings.setShowTranslation(_showTranslation);
            },
            icon: Icon(
              _showTranslation
                  ? Icons.translate
                  : Icons.translate_outlined,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (listContext) {
                _viewportContext = listContext;
                return ListView.builder(
                  controller: _controller,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
                  itemCount: surah.ayahCount + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _ReaderHeader(
                        surah: surah,
                        onMarkAll: _markSurahRead,
                        unreadCount: _unreadCount(surah),
                      );
                    }
                    final ayah = surah.ayahs[index - 1];
                    return KeyedSubtree(
                      key: _ayahKeys[index],
                      child: Column(
                        children: [
                          if (index == 1 && ayah.bismillah.isNotEmpty)
                            _Bismillah(bismillah: ayah.bismillah),
                          AyahTile(
                            ayah: ayah,
                            isPlaying: _isPlaying(ayah),
                            onTap: () {
                              _markRead(ayah);
                              _onAyahTap(ayah);
                            },
                            onLongPress: () => _showAyahActions(ayah),
                            onPlay: () => _playFromAyah(ayah),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _ReaderActionBar(
            surah: surah,
            mushafPage: _currentMushafPage,
            onMarkPage: _markPageRead,
            onPlay: _onBottomPlay,
            onOpenPlayer: _openPlayer,
            onChangeReciter: _onChangeReciter,
            readPageKey: _readPageKey,
            playKey: _playKey,
          ),
        ],
      ),
    );
  }

  /// Single bottom play/pause control. With a live session for this surah it
  /// toggles play/pause (auto-restarting a finished session); otherwise it
  /// walks through reciter → download → play. A finished single-shot session
  /// is cleared so the next press starts a fresh continuous surah.
  void _onBottomPlay() {
    final rec = context.read<RecitationProvider>();
    final surah = context.read<QuranProvider>().surah(widget.surahNumber);
    if (surah == null) return;
    if (rec.session?.surahNumber == widget.surahNumber) {
      if (rec.player.playing) {
        rec.pause();
      } else if (rec.session?.singleShot == true &&
          rec.player.phase == PlayerPhase.ended) {
        rec.stop();
        _showReciterPickerAndPlay(context, rec, surah);
      } else {
        rec.resume();
      }
      return;
    }
    _showReciterPickerAndPlay(context, rec, surah);
  }

  Future<void> _showReciterPickerAndPlay(
    BuildContext context,
    RecitationProvider rec,
    Surah surah,
  ) async {
    final selectedReciter = await _pickReciter(context, rec.reciter);
    if (selectedReciter == null || !context.mounted) return;

    // Listening is offline-first: ask before saving the surah for this
    // reciter, then play from the downloaded files.
    final ready = await showDownloadPrompt(
      context,
      rec: rec,
      reciter: selectedReciter,
      surah: surah,
    );
    if (!ready || !context.mounted) return;

    final ok = await rec.playSurah(selectedReciter, surah.number);
    if (!ok || !context.mounted) return;

    // Seek to the first ayah of the current mushaf page
    final surahForSeek = context.read<QuranProvider>().surah(widget.surahNumber);
    if (surahForSeek != null) {
      int firstAyahOfPage = 1;
      for (var n = 1; n <= surahForSeek.ayahCount; n++) {
        final ayah = surahForSeek.ayahs[n - 1];
        if (MushafPages.pageOfGlobalAyah(ayah.globalNumber) == _currentMushafPage) {
          firstAyahOfPage = n;
          break;
        }
      }
      if (firstAyahOfPage > 1) {
        await rec.playAyahAt(firstAyahOfPage - 1);
      }
    }

    // Open the full player so playback is visible and controllable.
    if (context.mounted && Navigator.of(context).canPop()) {
      _openPlayer();
    }
  }

  int _unreadCount(Surah surah) {
    final hasanat = context.read<HasanatProvider>();
    var n = 0;
    for (final a in surah.ayahs) {
      if (!hasanat.isRead(a.reference)) n++;
    }
    return n;
  }

  bool _isPlaying(Ayah ayah) {
    final rec = context.read<RecitationProvider>();
    return rec.player.playing &&
        rec.player.surahNumber == ayah.surahNumber &&
        rec.player.currentAyah == ayah.numberInSurah;
  }

  Future<void> _playFromAyah(Ayah ayah) async {
    final rec = context.read<RecitationProvider>();
    final quran = context.read<QuranProvider>();
    final surah = quran.surah(ayah.surahNumber);
    if (surah == null) return;

    // Download-first: even one ayah requires the surah to be saved for the
    // selected reciter. Then play just this ayah (single-shot).
    final ready = await showDownloadPrompt(
      context,
      rec: rec,
      reciter: rec.reciter,
      surah: surah,
    );
    if (!ready || !mounted) return;

    try {
      final ok = await rec.playSingleAyah(
        rec.reciter,
        surah.number,
        ayah.numberInSurah,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio not available. Try downloading again.'),
            duration: Duration(milliseconds: 2000),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio failed to load. Please try again.'),
            duration: Duration(milliseconds: 2000),
          ),
        );
      }
    }
  }

  /// Marks the current mushaf page as read and rewards its letters.
  Future<void> _markPageRead() async {
    final quran = context.read<QuranProvider>();
    final hasanat = context.read<HasanatProvider>();
    final surah = quran.surah(widget.surahNumber);
    if (surah == null) return;

    // Find ayahs on the current mushaf page for this surah
    final refs = <String>[];
    for (var n = 1; n <= surah.ayahCount; n++) {
      final ayah = surah.ayahs[n - 1];
      if (MushafPages.pageOfGlobalAyah(ayah.globalNumber) == _currentMushafPage) {
        if (!hasanat.isRead(ayah.reference)) refs.add(ayah.reference);
      }
    }
    if (refs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This page is already counted.'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }
    await _awardPage(refs, hasanat, surah);
  }

  Future<void> _markSurahRead() async {
    final quran = context.read<QuranProvider>();
    final hasanat = context.read<HasanatProvider>();
    final surah = quran.surah(widget.surahNumber);
    if (surah == null) return;
    final refs = surah.ayahs
        .where((a) => !hasanat.isRead(a.reference))
        .map((a) => a.reference)
        .toList();
    if (refs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This surah is already fully counted.'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }
    await _awardPage(refs, hasanat, surah);
  }

  Future<void> _awardPage(
    List<String> refs,
    HasanatProvider hasanat,
    Surah surah,
  ) async {
    final letters = await hasanat.addAyahsRead(refs);
    if (!mounted) return;
    if (context.read<SettingsProvider>().haptics) {
      HapticFeedback.mediumImpact();
    }
    final first = int.tryParse(refs.first.split(':').last) ?? 1;
    final last = refs.last.split(':').last;
    final hasanatValue = letters * kHasanatPerAyahLetter;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Read ${surah.transliteration} $first–$last · +$hasanatValue hasanat',
          ),
          duration: const Duration(milliseconds: 1800),
        ),
      );
  }

  void _markRead(Ayah ayah) {
    final hasanat = context.read<HasanatProvider>();
    if (!hasanat.isRead(ayah.reference)) {
      hasanat.addAyahRead(ayah.reference);
      if (context.read<SettingsProvider>().haptics) {
        HapticFeedback.selectionClick();
      }
      final hasanatValue =
          context.read<QuranProvider>().lettersOf(ayah) * kHasanatPerAyahLetter;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '+$hasanatValue hasanat · ${ayah.reference}',
          ),
          duration: const Duration(milliseconds: 1100),
        ),
      );
    }
  }

  void _onAyahTap(Ayah ayah) {
    final recitation = context.read<RecitationProvider>();
    if (recitation.hasSession &&
        recitation.player.surahNumber == ayah.surahNumber) {
      recitation.playAyahAt(ayah.numberInSurah - 1);
    }
  }

  void _showJumpSheet() {
    final surah = context.read<QuranProvider>().surah(widget.surahNumber)!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Jump to ayah', style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: surah.ayahCount,
                  itemBuilder: (context, i) {
                    final ayahNumber = i + 1;
                    return Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _scrollToAyah(ayahNumber);
                        },
                        child: Center(
                          child: Text(QurNum.arabicDigits(ayahNumber)),
                        ),
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

  void _scrollToAyah(int ayahNumber) {
    if (ayahNumber < 1 || ayahNumber >= _ayahKeys.length) return;
    if (!_controller.hasClients) return;

    final ctx = _ayahKeys[ayahNumber].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        alignment: 0.2,
      );
      return;
    }

    // The ayah hasn't been built yet (lazy ListView), so estimate its offset
    // from the average height of already-visible ayahs, scroll there, then
    // snap precisely with ensureVisible once it's built.
    final target = _estimateOffset(ayahNumber);
    unawaited(_controller.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c2 = _ayahKeys[ayahNumber].currentContext;
      if (c2 != null) {
        Scrollable.ensureVisible(
          c2,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic,
          alignment: 0.2,
        );
      }
    });
  }

  double _avgAyahHeight() {
    var totalHeight = 0.0;
    var built = 0;
    for (var i = 1; i < _ayahKeys.length; i++) {
      final c = _ayahKeys[i].currentContext;
      if (c != null) {
        totalHeight += c.size?.height ?? 0;
        built++;
      }
    }
    return built > 0 ? totalHeight / built : 130.0;
  }

  double _estimateOffset(int ayahNumber) {
    final avg = _avgAyahHeight();
    final headerHeight = _ayahKeys[0].currentContext?.size?.height ?? 120.0;
    final estimated = headerHeight + (ayahNumber - 1) * avg;
    return estimated.clamp(0.0, _controller.position.maxScrollExtent);
  }

  void _showAyahActions(Ayah ayah) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                ayah.reference,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontFamily: 'Amiri',
                      color: AppColors.emerald,
                    ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all),
              title: const Text('Copy ayah (Arabic)'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: '${ayah.arabic}\n(${ayah.reference})'));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy with translation'),
              onTap: () {
                final ref = ayah.reference;
                Clipboard.setData(
                  ClipboardData(text: '${ayah.arabic}\n${ayah.english}\n($ref)'),
                );
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.of(ctx).pop();
                SharePlus.instance.share(ShareParams(
                  text: '${ayah.arabic}\n${ayah.english}\n(${ayah.reference})',
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Mark as read'),
              onTap: () {
                Navigator.of(ctx).pop();
                _markRead(ayah);
              },
            ),
            ListTile(
              leading: const Icon(Icons.headphones),
              title: const Text('Play from this ayah'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _playFromAyah(ayah);
                if (mounted) _openPlayer();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openPlayer() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlayerScreen()),
    );
  }

  void _onChangeReciter() async {
    final rec = context.read<RecitationProvider>();
    final newReciter = await _pickReciter(context, rec.reciter);
    if (newReciter == null || !context.mounted) return;
    rec.selectReciter(newReciter);
  }

  Future<Reciter?> _pickReciter(
    BuildContext context,
    Reciter currentReciter,
  ) async {
    return showModalBottomSheet<Reciter>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.98,
        builder: (context, scrollController) => ReciterPickerSheet(
          initialReciter: currentReciter,
          scrollController: scrollController,
          onSelected: (reciter) => Navigator.of(ctx).pop(reciter),
        ),
      ),
    );
  }
}

class _ReaderHeader extends StatelessWidget {
  final Surah surah;
  final VoidCallback onMarkAll;
  final int unreadCount;
  const _ReaderHeader({
    required this.surah,
    required this.onMarkAll,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Text(
            surah.shortArabicName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontFamily: 'Amiri',
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${surah.transliteration} · ${surah.translatedName}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${QurNum.arabicDigits(surah.ayahCount)} verses · ${surah.revelationType}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ActionChip(
                avatar: const Icon(Icons.done_all, size: 18),
                label: Text(
                  unreadCount > 0 ? 'Mark all ($unreadCount)' : 'All counted',
                ),
                onPressed: unreadCount > 0 ? onMarkAll : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bismillah extends StatelessWidget {
  final String bismillah;
  const _Bismillah({required this.bismillah});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          bismillah,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Amiri',
            color: Ui.bismillah(context),
            fontSize: 24,
            height: 1.8,
          ),
        ),
      ),
    );
  }
}

/// Persistent bottom bar: page label (left), "Read page", and a single
/// play/pause control that also shows the reciter + live ayah (tapping it
/// opens the full player). Formerly two separate bars — a source of duplicate
/// play/pause buttons and confusing state.
class _ReaderActionBar extends StatelessWidget {
  final Surah surah;
  final int mushafPage;
  final VoidCallback onMarkPage;
  final VoidCallback onPlay;
  final VoidCallback onOpenPlayer;
  final VoidCallback onChangeReciter;
  final GlobalKey? readPageKey;
  final GlobalKey? playKey;
  const _ReaderActionBar({
    required this.surah,
    required this.mushafPage,
    required this.onMarkPage,
    required this.onPlay,
    required this.onOpenPlayer,
    required this.onChangeReciter,
    this.readPageKey,
    this.playKey,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recitation = context.watch<RecitationProvider>();
    final hasLiveSession =
        recitation.session?.surahNumber == surah.number;
    final isPlaying = hasLiveSession && recitation.player.playing;
    final liveAyah = hasLiveSession ? recitation.player.currentAyah : null;

    // Ayah range for this mushaf page within the current surah.
    int firstAyahInPage = 1;
    int lastAyahInPage = surah.ayahCount;
    for (var n = 1; n <= surah.ayahCount; n++) {
      if (MushafPages.pageOfGlobalAyah(surah.ayahs[n - 1].globalNumber) ==
          mushafPage) {
        firstAyahInPage = n;
        break;
      }
    }
    for (var n = surah.ayahCount; n >= 1; n--) {
      if (MushafPages.pageOfGlobalAyah(surah.ayahs[n - 1].globalNumber) ==
          mushafPage) {
        lastAyahInPage = n;
        break;
      }
    }

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: hasLiveSession ? onOpenPlayer : null,
                  borderRadius: BorderRadius.circular(12),
                  child: hasLiveSession
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${recitation.reciter.englishName} — Ayah $liveAyah',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: onChangeReciter,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.swap_horiz,
                                    size: 16,
                                    color: Ui.emerald(context),
                                  ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Page $mushafPage · ${QurNum.arabicDigits(firstAyahInPage)}–${QurNum.arabicDigits(lastAyahInPage)}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if (isPlaying)
                              Text(
                                'Tap to open player',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        )
                      : Text(
                          'Page $mushafPage · ${QurNum.arabicDigits(firstAyahInPage)}–${QurNum.arabicDigits(lastAyahInPage)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              KeyedSubtree(
                key: readPageKey,
                child: ActionChip(
                  avatar: const Icon(Icons.menu_book, size: 18),
                  label: const Text('Read page'),
                  onPressed: onMarkPage,
                ),
              ),
              const SizedBox(width: 4),
              KeyedSubtree(
                key: playKey,
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                  ),
                  tooltip: isPlaying
                      ? 'Pause'
                      : hasLiveSession
                          ? 'Play'
                          : 'Select reciter & play',
                  onPressed: onPlay,
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}