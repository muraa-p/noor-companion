import 'package:flutter/material.dart';

import '../data/audio_repository.dart';
import '../models/models.dart';
import '../providers/recitation_provider.dart';

/// Ensures a surah is downloaded offline for [reciter] before playback.
///
/// - Already on disk → returns `true` immediately.
/// - Otherwise a dialog explains that listening needs the surah saved first,
///   starts the download on consent, shows progress and auto-dismisses with
///   `true` when finished (`false` on cancel/failure).
Future<bool> showDownloadPrompt(
  BuildContext context, {
  required RecitationProvider rec,
  required Reciter reciter,
  required Surah surah,
}) async {
  if (await rec.isDownloaded(reciter, surah.number)) return true;
  if (!context.mounted) return false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) =>
        _DownloadPromptDialog(rec: rec, reciter: reciter, surah: surah),
  );
  return result ?? false;
}

class _DownloadPromptDialog extends StatefulWidget {
  final RecitationProvider rec;
  final Reciter reciter;
  final Surah surah;

  const _DownloadPromptDialog({
    required this.rec,
    required this.reciter,
    required this.surah,
  });

  @override
  State<_DownloadPromptDialog> createState() => _DownloadPromptDialogState();
}

class _DownloadPromptDialogState extends State<_DownloadPromptDialog> {
  static String _fmtBytes(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '~${mb.toStringAsFixed(1)} MB';
    return '~${(bytes / 1024).round()} KB';
  }

  bool _popped = false;

  @override
  void initState() {
    super.initState();
    widget.rec.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.rec.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final status =
        widget.rec.downloadStatus(widget.reciter, widget.surah.number);
    if (status == DownloadStatus.done) {
      // Navigator.pop *cannot* run synchronously from inside a
      // ChangeNotifier.notifyListeners() dispatch — it throws the
      // "!_debugLocked" assertion and leaves a red error screen. Defer the
      // pop to the end of the current frame.
      if (!_popped) {
        _popped = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          }
        });
      }
      return;
    }
    setState(() {});
  }

  void _startDownload() {
    widget.rec.downloadSurah(widget.reciter, widget.surah.number);
  }

  @override
  Widget build(BuildContext context) {
    final status =
        widget.rec.downloadStatus(widget.reciter, widget.surah.number);
    final progress =
        widget.rec.downloadProgress(widget.reciter, widget.surah.number);
    final size = AudioRepository.estimateSurahBytes(
      widget.reciter,
      widget.surah.number,
    );
    final downloading = status == DownloadStatus.downloading;
    final failed = status == DownloadStatus.failed;

    return AlertDialog(
      title: const Text('Download & play'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Listen to ${widget.reciter.englishName} — this needs the surah '
            'saved on your device first. Downloads run in the background, '
            'so you can keep browsing while it saves.',
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${widget.surah.number}. ${widget.surah.transliteration}\n'
              '${widget.surah.ayahCount} verses · ${_fmtBytes(size)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress / 100, minHeight: 6),
            const SizedBox(height: 8),
            Text(
              'Downloading… $progress% — you can keep using the app.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (failed) ...[
            const SizedBox(height: 16),
            Text(
              'Download failed — check your connection and retry.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: downloading
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (!downloading) ...[
          TextButton(
            onPressed: () {
              _startDownload();
              Navigator.of(context).pop(false);
            },
            child: const Text('Background'),
          ),
          FilledButton(
            onPressed: _startDownload,
            child: Text(failed ? 'Retry' : 'Download & play'),
          ),
        ],
      ],
    );
  }
}