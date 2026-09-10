import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/quran_provider.dart';
import '../../providers/recitation_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';
import '../../widgets/surah_card.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {

  @override
  Widget build(BuildContext context) {
    final recitation = context.watch<RecitationProvider>();
    final player = recitation.player;
    final session = player.session;
    final quran = context.read<QuranProvider>();
    final settings = context.watch<SettingsProvider>();

if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Player')),
        body: player.starting
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text('Preparing audio…'),
                  ],
                ),
              )
            : const Center(child: Text('No surah is playing.')),
      );
    }

    final surah = quran.surah(session.surahNumber);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(surah?.transliteration ?? 'Surah')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ---- Hero --------------------------------------------------
          Container(
            padding: const EdgeInsets.all(24),
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
                  surah?.shortArabicName ?? '',
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 34,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${surah?.transliteration ?? ''} Â· ${recitation.reciter.englishName}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                ),
const SizedBox(height: 18),
                // Ayah progress indicator. The spinner only shows while a new
                // ayah is genuinely still loading (not yet playing); once audio
                // is active we always show the ayah counter so the play/pause
                // button never disagrees with what you're hearing.
                if (player.starting && !player.playing)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Loading audio…',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ],
                  )
                else
                  Text(
                    'Ayah ${player.currentAyah} / ${surah?.ayahCount ?? 0}',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SpeedButton(player: player),
                    IconButton.filledTonal(
                      iconSize: 30,
                      onPressed: () => recitation.playAyahAt(
                        player.previousIndex(),
                      ),
                      icon: const Icon(Icons.skip_previous),
                    ),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.white,
                      ),
                      iconSize: 42,
                      padding: const EdgeInsets.all(14),
                      onPressed: () {
                        player.playing
                            ? recitation.pause()
                            : recitation.resume();
                      },
                      icon: Icon(player.playing ? Icons.pause : Icons.play_arrow),
                    ),
                    IconButton.filledTonal(
                      iconSize: 30,
                      onPressed: () =>
                          recitation.playAyahAt(player.nextIndex()),
                      icon: const Icon(Icons.skip_next),
                    ),
                    _SleepTimerButton(player: player),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ---- Options row ------------------------------------------
          Row(
            children: [
              _OptionChip(
                icon: Icons.repeat,
                label: player.repeatSurah ? 'Repeat' : 'Once',
                active: player.repeatSurah,
                onTap: () => recitation.setRepeatSurah(!player.repeatSurah),
              ),
              const SizedBox(width: 10),
              _DownloadButton(recitation: recitation, surahNumber: session.surahNumber),
            ],
          ),
          const SizedBox(height: 20),
          Text('Ayahs', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
// ---- Ayah list ---------------------------------------------
          ...List.generate(session.ayahSources.length, (i) {
            final ayah = surah?.ayahs[i];
            final current = player.currentAyah == i + 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: current
                    ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : colorScheme.surfaceContainer,
                onTap: () => recitation.playAyahAt(i),
                leading: AyahNumber(i + 1),
                title: Text(
                  ayah == null
                      ? 'Ayah ${i + 1}'
                      : settings.showTranslation
                          ? ayah.english
                          : '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: current ? colorScheme.primary : null,
                    fontWeight: current ? FontWeight.w700 : null,
                  ),
                ),
                trailing: current
                    ? Icon(Icons.volume_up, color: colorScheme.primary)
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  final SurahAyahPlayer player;
  const _SpeedButton({required this.player});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Speed',
      initialValue: player.rate,
      onSelected: (v) {
        final rec = context.read<RecitationProvider>();
        rec.setSpeed(v);
      },
      itemBuilder: (_) => [0.75, 1.0, 1.25, 1.5, 2.0]
          .map((v) => PopupMenuItem(value: v, child: Text('${v}x')))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${player.rate}x',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SleepTimerButton extends StatelessWidget {
  final SurahAyahPlayer player;
  const _SleepTimerButton({required this.player});

  @override
  Widget build(BuildContext context) {
    final active = player.sleepTimerEnabled;
    return PopupMenuButton<int>(
      tooltip: 'Sleep timer',
      initialValue: 0,
      onSelected: (minutes) {
        final rec = context.read<RecitationProvider>();
        if (minutes <= 0) {
          rec.setSleepTimer(null);
        } else {
          rec.setSleepTimer(Duration(minutes: minutes));
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 0, child: Text('Off')),
        PopupMenuItem(value: 10, child: Text('10 min')),
        PopupMenuItem(value: 20, child: Text('20 min')),
        PopupMenuItem(value: 30, child: Text('30 min')),
        PopupMenuItem(value: 45, child: Text('45 min')),
      ],
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? AppColors.gold.withValues(alpha: 0.9) : Colors.white12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.bedtime,
          color: active ? Colors.white : Colors.white70,
          size: 22,
        ),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final RecitationProvider recitation;
  final int surahNumber;
  const _DownloadButton({required this.recitation, required this.surahNumber});

  @override
  Widget build(BuildContext context) {
    final rec = context.watch<RecitationProvider>();
    final isDownloading = rec.isDownloading(rec.reciter, surahNumber);
    final progress = rec.downloadProgress(rec.reciter, surahNumber);

    if (isDownloading) {
      return _OptionChip(
        icon: Icons.downloading,
        label: '$progress%',
        active: true,
        onTap: null,
      );
    }

    return FutureBuilder<bool>(
      future: rec.isDownloaded(rec.reciter, surahNumber),
      builder: (context, snap) {
        final downloaded = snap.data ?? false;
        return _OptionChip(
          icon: downloaded ? Icons.download_done : Icons.download,
          label: downloaded ? 'Downloaded' : 'Download',
          active: downloaded,
          onTap: () {
            if (downloaded) {
              _confirmDelete(context);
            } else {
              rec.downloadSurah(rec.reciter, surahNumber);
            }
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete download?'),
        content: const Text('This removes the offline audio for this surah.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              recitation.deleteSurah(recitation.reciter, surahNumber);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _OptionChip({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeBg = active ? Ui.goldSoft(context) : scheme.surfaceContainerHigh;
    final fg = active ? Ui.gold(context) : scheme.onSurface;
    return Material(
      color: activeBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
