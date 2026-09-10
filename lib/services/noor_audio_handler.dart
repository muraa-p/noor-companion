import 'package:audio_service/audio_service.dart';

import '../providers/recitation_provider.dart';

/// Bridges the app's playback to the OS media session so it appears in the
/// notification shade / lock screen with transport controls (play/pause +
/// prev/next). All media-session commands are routed through
/// [RecitationProvider] — the same code the in-app controls use — so the
/// notification and the UI never disagree on state (e.g. restarting a finished
/// surah always behaves identically).
class NoorAudioHandler extends BaseAudioHandler {
  NoorAudioHandler(this._recitation) {
    _recitation.addListener(_pushState);
    _pushState();
  }

  final RecitationProvider _recitation;
  String? _currentMediaId;

  SurahAyahPlayer get _player => _recitation.player;

  void _pushState() {
    final session = _player.session;

    // Only publish a new notification title when the surah/reciter changes,
    // not on every ayah advance (which would churn the notification each ayah).
    if (session != null) {
      final id = 'surah-${session.surahNumber}';
      if (id != _currentMediaId) {
        _currentMediaId = id;
        mediaItem.add(
          MediaItem(
            id: id,
            title: session.title,
            artist: session.reciter.englishName,
            duration: const Duration(seconds: 0),
          ),
        );
      }
    } else {
      _currentMediaId = null;
    }

    final playing = _recitation.player.playing;
    List<MediaControl> controls;
    if (session == null) {
      controls = const [];
    } else {
      controls = [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ];
    }

    playbackState.add(
      playbackState.value.copyWith(
        playing: playing,
        controls: controls,
        androidCompactActionIndices: session == null
            ? const []
            : const [0, 1, 2],
        processingState: _player.starting
            ? AudioProcessingState.loading
            : (session == null
                ? AudioProcessingState.idle
                : AudioProcessingState.ready),
      ),
    );
  }

  @override
  Future<void> play() async {
    await _recitation.resume();
  }

  @override
  Future<void> pause() async {
    await _recitation.pause();
  }

  @override
  Future<void> stop() async {
    await _recitation.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    // Per-ayah files have no meaningful intra-ayah timeline; treat a seek
    // (e.g. tapping the notification progress bar) as a no-op.
  }

  @override
  Future<void> skipToNext() async {
    await _recitation.playAyahAt(_player.nextIndex());
  }

  @override
  Future<void> skipToPrevious() async {
    await _recitation.playAyahAt(_player.previousIndex());
  }

  @override
  Future<void> setSpeed(double speed) async {
    _recitation.setSpeed(speed);
  }

  @override
  Future<void> onTaskRemoved() async {
    // When the user swipes the app away, stop playback and the notification.
    await _recitation.stop();
    await super.stop();
  }
}
