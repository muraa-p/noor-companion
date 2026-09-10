import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../data/audio_repository.dart';
import '../data/notification_service.dart';
import '../data/static_content.dart';
import '../models/models.dart';
import 'quran_provider.dart';
import 'settings_provider.dart';

/// A surah playback session, always backed by downloaded local files.
class SurahPlayerSession {
  final Reciter reciter;
  final int surahNumber;
  final String title; // e.g. "55. Ar-Rahman"
  final List<String> ayahSources; // local file paths
  final bool singleShot; // true when only one ayah should be played

  SurahPlayerSession({
    required this.reciter,
    required this.surahNumber,
    required this.title,
    required this.ayahSources,
    this.singleShot = false,
  });

  int get ayahCount => ayahSources.length;
}

enum PlayerPhase { stopped, playing, paused, ended, error }

/// Lifecycle of a surah audio download.
enum DownloadStatus { none, downloading, done, failed }

/// Manages reciter selection, surah downloads and sequential ayah playback.
class RecitationProvider extends ChangeNotifier {
  final AudioRepository _audio;
  final QuranProvider _quran;
  final SettingsProvider _settings;
  final SurahAyahPlayer _player;

  RecitationProvider({
    required AudioRepository audio,
    required QuranProvider quran,
    required SettingsProvider settings,
    SurahAyahPlayer? player,
  })  : _audio = audio,
        _quran = quran,
        _settings = settings,
        _player = player ?? SurahAyahPlayer() {
    // Bridge the player's internal changes (each ayah advancing during
    // background playback, play/pause/stop) up to this provider. Without this
    // the UI (which watches THIS provider) and the media notification would
    // never rebuild as playback moves through a surah — the highlighted ayah
    // would stay frozen until the user pressed play/pause.
    _player.addListener(notifyListeners);
  }

  late Reciter _reciter =
      kReciters.firstWhere((r) => r.identifier == _settings.reciterId,
          orElse: () => kReciters.first);

  // ---- Reciter ------------------------------------------------------------

  Reciter get reciter => _reciter;

  void selectReciter(Reciter r) {
    _reciter = r;
    _settings.setReciter(r.identifier);
    _stopPlaying();
    notifyListeners();
  }

  // ---- Download state -----------------------------------------------------

  final Map<String, int> _downloadProgress = {}; // "reciter|surah" -> percent
  final Map<String, DownloadStatus> _downloadStatus = {}; // per reciter|surah

  String _statusKey(Reciter r, int surah) => '${r.identifier}|$surah';

  DownloadStatus downloadStatus(Reciter r, int surah) =>
      _downloadStatus[_statusKey(r, surah)] ?? DownloadStatus.none;

  bool isDownloading(Reciter r, int surah) =>
      downloadStatus(r, surah) == DownloadStatus.downloading;

  int downloadProgress(Reciter r, int surah) =>
      _downloadProgress[_statusKey(r, surah)] ?? 0;

  // ---- Active download (app-wide banner) -------------------------------

  bool get anyDownloadActive =>
      _downloadStatus.containsValue(DownloadStatus.downloading);

  /// Label of the currently running download, e.g. "55. Ar-Rahman · Minshawi".
  String? get activeDownloadLabel {
    for (final e in _downloadStatus.entries) {
      if (e.value == DownloadStatus.downloading) {
        final parts = e.key.split('|');
        if (parts.length != 2) continue;
        final r = kReciters.firstWhere(
          (r) => r.identifier == parts[0],
          orElse: () => kReciters.first,
        );
        final s = int.tryParse(parts[1]) ?? 0;
        final surah = _quran.surah(s);
        return '${surah?.transliteration ?? 'Surah $s'} · ${r.englishName}';
      }
    }
    return null;
  }

  /// Download percent of the currently running download.
  int get activeDownloadProgress {
    for (final e in _downloadStatus.entries) {
      if (e.value == DownloadStatus.downloading) {
        return _downloadProgress[e.key] ?? 0;
      }
    }
    return 0;
  }

  /// Clears and returns one pending download error message (for a snackbar).
  String? takeDownloadError(Reciter r, int surah) {
    final key = '${r.identifier}|$surah';
    if (!_downloadErrors.containsKey(key)) return null;
    final e = _downloadErrors.remove(key);
    return e;
  }

  /// Clears and returns one pending playback error message (for a snackbar).
  String? takePlaybackError() => _player.takeError();

  final Map<String, String> _downloadErrors = {};

  Future<bool> isDownloaded(Reciter r, int surah) =>
      _audio.surahDownloaded(r, surah);

  /// Resolves on-disk download state for one surah into the status map.
  Future<bool> refreshDownloadState(Reciter r, int surah) async {
    final done = await _audio.surahDownloaded(r, surah);
    _downloadStatus[_statusKey(r, surah)] =
        done ? DownloadStatus.done : DownloadStatus.none;
    notifyListeners();
    return done;
  }

  /// Resolves on-disk state for every surah (used by the index screen).
  Future<void> refreshAllStates(Reciter r) async {
    for (var s = 1; s <= 114; s++) {
      final done = await _audio.surahDownloaded(r, s);
      _downloadStatus[_statusKey(r, s)] =
          done ? DownloadStatus.done : DownloadStatus.none;
    }
    notifyListeners();
  }

  Future<void> downloadSurah(Reciter r, int surah) async {
    final key = _statusKey(r, surah);
    if (_downloadStatus[key] == DownloadStatus.downloading) return;

    _downloadStatus[key] = DownloadStatus.downloading;
    _downloadProgress[key] = 0;
    _downloadErrors.remove(key);
    notifyListeners();

    final surahTitle = _quran.surah(surah);
    final label = surahTitle == null
        ? 'Surah $surah'
        : '${surahTitle.transliteration} · ${r.englishName}';
    final notif = NotificationService.instance;

    try {
      final shownSteps = <int>{};
      await _audio.downloadSurah(
        r,
        surah,
        onProgress: (done, total) {
          if (total > 0) {
            _downloadProgress[key] = (done / total * 100).round();
          }
          notifyListeners();
          // Throttle notification updates: only every ~5% to avoid spamming.
          final currentPct = _downloadProgress[key] ?? 0;
          final pct = currentPct ~/ 5 * 5;
          if (total > 0 && shownSteps.add(pct)) {
            unawaited(notif.showDownloadProgress(
              currentPct,
              title: label,
            ));
          }
        },
      );
      final ok = await _audio.surahDownloaded(r, surah);
      _downloadStatus[key] = ok ? DownloadStatus.done : DownloadStatus.failed;
      _downloadProgress[key] = ok ? 100 : (_downloadProgress[key] ?? 0);
      unawaited(
        notif.finishDownload(title: ok ? 'Downloaded $label' : label),
      );
      if (ok) _downloadRevision++;
      if (!ok) {
        _downloadErrors[key] =
            'Some audio files failed to download. Please retry.';
      }
    } catch (e) {
      _downloadStatus[key] = DownloadStatus.failed;
      _downloadErrors[key] = e.toString();
      unawaited(notif.finishDownload(title: label));
    } finally {
      _downloadRevision++;
      notifyListeners();
    }
  }

  Future<void> deleteSurah(Reciter r, int surah) async {
    if (_player.surahNumber == surah &&
        _player.reciter?.identifier == r.identifier) {
      await _stopPlaying();
    }
    await _audio.deleteSurah(r, surah);
    _downloadStatus[_statusKey(r, surah)] = DownloadStatus.none;
    _downloadProgress[_statusKey(r, surah)] = 0;
    _downloadRevision++;
    notifyListeners();
  }

  // ---- Downloaded-state queries (reciter badges, "Downloaded" section) ---

  int _downloadRevision = 0;

  /// Bumped whenever a download completes or is removed; widgets that display
  /// on-disk state (e.g. the "Downloaded" section) key their FutureBuilder on
  /// this to avoid re-scanning the disk on every progress tick.
  int get downloadRevision => _downloadRevision;

  Future<Set<int>> downloadedSurahs(Reciter r) => _audio.downloadedSurahs(r);

  Future<int> downloadedCountFor(Reciter r) => _audio.downloadedCountFor(r);

  // ---- Playback ------------------------------------------------------------

  SurahAyahPlayer get player => _player;

  SurahPlayerSession? _session;

  bool get hasSession => _session != null;

  SurahPlayerSession? get session => _session;

  /// Begins playing a surah from its downloaded local files only. Returns
  /// false when the surah isn't fully downloaded for [r] yet — triggering the
  /// download (via [lib/widgets/download_prompt.dart]) is the caller's job.
  Future<bool> playSurah(
    Reciter r,
    int surahNumber,
  ) async {
    final surah = _quran.surah(surahNumber);
    if (surah == null) return false;

    if (!await _audio.surahDownloaded(r, surahNumber)) return false;

    await _stopPlaying();
    selectReciter(r);

    final ayahSources = <String>[];
    for (var v = 1; v <= surah.ayahCount; v++) {
      final ok = await _audio.ayahExists(r, surahNumber, v);
      if (!ok) return false;
      ayahSources.add(await _audio.ayahPath(r, surahNumber, v));
    }
    if (ayahSources.isEmpty) return false;

    _session = SurahPlayerSession(
      reciter: r,
      surahNumber: surahNumber,
      title: '${surah.number}. ${surah.transliteration}',
      ayahSources: ayahSources,
    );
    notifyListeners();

    await _player.playSession(_session!);
    return true;
  }

  /// Plays only the given ayah — single-shot mode used by per-ayah "Play"
  /// chips. The session ends after one ayah, so the user gets immediate
  /// feedback without starting continuous surah playback.
  Future<bool> playSingleAyah(
    Reciter r,
    int surahNumber,
    int ayahNumber,
  ) async {
    final surah = _quran.surah(surahNumber);
    if (surah == null) return false;
    if (!await _audio.surahDownloaded(r, surahNumber)) return false;

    await _stopPlaying();
    selectReciter(r);

    final source = await _audio.ayahPath(r, surahNumber, ayahNumber);
    _session = SurahPlayerSession(
      reciter: r,
      surahNumber: surahNumber,
      title: '${surah.number}. ${surah.transliteration}',
      ayahSources: [source],
      singleShot: true,
    );
    notifyListeners();
    await _player.playSession(_session!);
    return true;
  }

  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  /// Resumes playback; if the session already finished, restarts it from the
  /// first ayah instead of trying to resume from a "completed" state (which
  /// Android MediaPlayer silently ignores). Single-shot sessions are cleared
  /// on end so the bottom bar can start a fresh continuous surah.
  Future<void> resume() async {
    if (_player.phase == PlayerPhase.ended) {
      if (_session?.singleShot == true) {
        await _stopPlaying();
        return;
      }
      if (_player.session != null) {
        await _player.jumpToAyah(0);
      }
    } else {
      await _player.resume();
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await _stopPlaying();
  }

  Future<void> _stopPlaying() async {
    await _player.stop();
    _session = null;
    notifyListeners();
  }

  Future<void> playAyahAt(int ayahIndex) async {
    await _player.jumpToAyah(ayahIndex);
    notifyListeners();
  }

  void setSpeed(double speed) {
    _player.rate = speed;
    notifyListeners();
  }

  void setSleepTimer(Duration? duration) {
    _player.sleepTimer = duration;
    notifyListeners();
  }

  void setRepeatSurah(bool enabled) {
    _player.repeatSurah = enabled;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

/// A sequential player that walks ayah-by-ayah (or plays one full-surah file).
/// Wraps audioplayers with resilience for flaky Android MediaPlayer backends:
/// an explicit audio context (stable focus/usage on MIUI), a full teardown and
/// recreation of the underlying player when a source fails, and a per-source
/// retry before skipping a bad ayah.
class SurahAyahPlayer extends ChangeNotifier {
  final AudioContext _audioContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gain,
    ),
  );

  AudioPlayer? _player;
  int _generation = 0;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;

  // Broadcast controllers so screens that subscribed survive a player
  // recreation (the underlying audioplayers instance may be disposed and
  // replaced on failure).
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();

  SurahPlayerSession? _session;
  int _index = 0;
  bool _playing = false;
  bool _starting = false;
  PlayerPhase _phase = PlayerPhase.stopped;
  double _rate = 1.0;
  bool repeatSurah = false;
  bool _sleepTimerEnabled = false;
  Timer? _sleepTimer;
  String? _lastError;
  int _sourceFailures = 0; // consecutive failures for the current source
  int _startRetries = 0; // times a source failed to reach "playing"

  int get currentAyah => _index + 1;
  bool get playing => _playing;
  bool get starting => _starting;
  PlayerPhase get phase => _phase;
  double get rate => _rate;
  bool get sleepTimerEnabled => _sleepTimerEnabled;

  /// Last playback failure (e.g. a missing network file). Read and cleared by
  /// the provider so it can be shown as a snackbar.
  String? takeError() {
    final e = _lastError;
    _lastError = null;
    return e;
  }

  SurahPlayerSession? get session => _session;

  Reciter? get reciter => _session?.reciter;
  int? get surahNumber => _session?.surahNumber;

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;

  SurahAyahPlayer() {
    _attachNewPlayer();
  }

  /// Creates a fresh audioplayers instance, wires its events up to this class
  /// and re-applies the configured playback rate.
  Future<void> _attachNewPlayer() async {
    _generation++;
    final p = AudioPlayer(playerId: 'surah_player$_generation');
    _player = p;
    try {
      await p.setAudioContext(_audioContext);
    } catch (_) {}

    _stateSub = p.onPlayerStateChanged.listen((state) {
      _playing = state == PlayerState.playing;
      if (state == PlayerState.playing) _starting = false;
      _phase = _playing
          ? PlayerPhase.playing
          : (state == PlayerState.paused ? PlayerPhase.paused : _phase);
      _phase = state == PlayerState.completed ? PlayerPhase.ended : _phase;
      notifyListeners();
    });
    _completeSub = p.onPlayerComplete.listen((_) => _onComplete());
    _posSub = p.onPositionChanged.listen(_positionController.add);
    _durSub = p.onDurationChanged.listen(_durationController.add);

    if (_rate != 1.0) {
      try {
        await p.setPlaybackRate(_rate);
      } catch (_) {}
    }
  }

  /// Tears the current player down completely (a wedged MediaPlayer usually
  /// recovers after this) and re-attaches. Event listeners reinstated on the
  /// new instance keep [positionStream]/[durationStream] alive.
  Future<void> _recreatePlayer() async {
    final old = _player;
    _player = null;
    await _stateSub?.cancel();
    await _completeSub?.cancel();
    await _posSub?.cancel();
    await _durSub?.cancel();
    _stateSub = null;
    _completeSub = null;
    _posSub = null;
    _durSub = null;
    if (old != null) {
      try {
        await old.stop();
        await old.dispose();
      } catch (_) {}
    }
    await _attachNewPlayer();
  }

  set rate(double v) {
    _rate = v;
    final p = _player;
    if (p != null) _applyRate(p);
    notifyListeners();
  }

  Future<void> _applyRate(AudioPlayer p) async {
    try {
      await p.setPlaybackRate(_rate);
    } catch (_) {}
  }

  set sleepTimer(Duration? d) {
    if (d == null) {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      _sleepTimerEnabled = false;
    } else {
      _sleepTimer?.cancel();
      _sleepTimer = Timer(d, () async {
        _sleepTimerEnabled = true;
        await stop();
        notifyListeners();
      });
      _sleepTimerEnabled = true;
    }
    notifyListeners();
  }

  Duration get sleepTimerRemaining => const Duration(seconds: 0);

  Future<void> playSession(SurahPlayerSession session) async {
    _session = session;
    _index = 0;
    _sourceFailures = 0;
    _phase = PlayerPhase.playing;
    _playing = true;
    _starting = true;
    _sleepTimerEnabled = false;
    notifyListeners();
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    final s = _session;
    if (s == null) return;
    _sourceFailures = 0;
    _startRetries = 0;
    await _playCurrentSource(s);
  }

  Future<void> _playCurrentSource(SurahPlayerSession s) async {
    final p = _player;
    if (p == null || _session != s) return;
    _starting = true;
    _playing = true;
    _phase = PlayerPhase.playing;
    notifyListeners();
    if (_index >= s.ayahSources.length) return;
    final source = s.ayahSources[_index];
    var started = false;
    var skipAyah = false;
    try {
      await p.stop();
      await p.play(DeviceFileSource(source));
      // Watchdog: on a rare Android quirk, MediaPlayer stays wedged after
      // stop()+play() and never actually starts. Poll the native player state
      // directly (NOT the instance `_playing` flag, which a stale "stopped"
      // event from our own stop() can corrupt) and only give up after a real
      // timeout — otherwise we'd tear the player down on every ayah.
      for (var t = 0; t < 10; t++) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        final st = p.state;
        if (st == PlayerState.playing) {
          started = true;
          break;
        }
        if (st == PlayerState.completed || st == PlayerState.disposed) break;
        if (p != _player || _session != s) return;
      }
    } catch (e) {
      _sourceFailures++;
      if (_sourceFailures == 1 && _session == s) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await _recreatePlayer();
        await _playCurrentSource(s);
        return;
      }
      skipAyah = _index > 0 &&
          _index < s.ayahSources.length - 1 &&
          _session == s;
      if (skipAyah) {
        _index++;
        _sourceFailures = 0;
        await Future<void>.delayed(const Duration(milliseconds: 400));
        notifyListeners();
        await _playCurrentSource(s);
        return;
      }
      _lastError = e.toString();
      _phase = PlayerPhase.ended;
      _playing = false;
      notifyListeners();
      return;
    }
    if (started) {
      _sourceFailures = 0;
      _startRetries = 0;
      _starting = false;
      _playing = true;
      notifyListeners();
      return;
    }
    // Never saw "playing" within the timeout / hit an error state. Recreate a
    // fresh MediaPlayer and retry, but only a bounded number of times so a
    // genuinely broken file can't spin into an infinite teardown/restart loop
    // (which also floods the log with MediaPlayer churn).
    if (_session != s) return;
    _startRetries++;
    if (_startRetries <= 2) {
      await _recreatePlayer();
      await _playCurrentSource(s);
    } else {
      _lastError = 'Could not start playback for this ayah.';
      _phase = PlayerPhase.ended;
      _playing = false;
      notifyListeners();
    }
  }

  Future<void> _onComplete() async {
    final s = _session;
    if (s == null) return;
    // Guard against audioplayers firing onPlayerComplete more than once for a
    // single source (a known Android quirk) — if we're already moving to the
    // next ayah, ignore the duplicate event.
    if (_starting) return;
    if (_index < s.ayahSources.length - 1) {
      _index++;
      _sourceFailures = 0;
      _starting = true;
      _playing = true;
      notifyListeners();
      await _playCurrent();
      return;
    } else if (repeatSurah && !s.singleShot) {
      _index = 0;
      _sourceFailures = 0;
      _starting = true;
      _playing = true;
      notifyListeners();
      await _playCurrent();
      return;
    }
    _phase = PlayerPhase.ended;
    _playing = false;
    notifyListeners();
  }

  Future<void> jumpToAyah(int ayahIndex) async {
    final s = _session;
    if (s == null) return;
    if (ayahIndex < 0 || ayahIndex >= s.ayahSources.length) return;
    _index = ayahIndex;
    _sourceFailures = 0;
    _phase = PlayerPhase.playing;
    _playing = true;
    notifyListeners();
    await _playCurrent();
  }

  /// 0-based index of the next ayah (wraps when repeating).
  int nextIndex() {
    final s = _session;
    if (s == null) return 0;
    if (repeatSurah && _index >= s.ayahSources.length - 1) return 0;
    return (_index + 1).clamp(0, s.ayahSources.length - 1);
  }

  /// 0-based index of the previous ayah.
  int previousIndex() {
    final s = _session;
    if (s == null) return 0;
    return (_index - 1).clamp(0, s.ayahSources.length - 1);
  }

  Future<void> seek(Duration position) async {
    final p = _player;
    if (p != null) {
      try {
        await p.seek(position);
      } catch (_) {}
    }
  }

  Future<void> next() async {
    final s = _session;
    if (s == null) return;
    final target = repeatSurah && _index == s.ayahSources.length - 1
        ? 0
        : (_index + 1).clamp(0, s.ayahSources.length - 1);
    await jumpToAyah(target);
  }

  Future<void> previous() async {
    final s = _session;
    if (s == null) return;
    final target = (_index - 1).clamp(0, s.ayahSources.length - 1);
    await jumpToAyah(target);
  }

  Future<void> pause() async {
    // Set state optimistically so the play/pause button flips immediately and
    // a double-tap never gets stuck showing "pause" while audio is starting.
    _playing = false;
    _phase = PlayerPhase.paused;
    _starting = false;
    notifyListeners();
    final p = _player;
    if (p != null) {
      try {
        await p.pause();
      } catch (_) {}
    }
  }

  Future<void> resume() async {
    _playing = true;
    _phase = PlayerPhase.playing;
    _starting = false;
    notifyListeners();
    final p = _player;
    if (p != null) {
      try {
        await p.resume();
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEnabled = false;
    final p = _player;
    if (p != null) {
      try {
        await p.stop();
      } catch (_) {}
    }
    _phase = PlayerPhase.stopped;
    _playing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    final p = _player;
    _player = null;
    _stateSub?.cancel();
    _completeSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _positionController.close();
    _durationController.close();
    if (p != null) {
      p.stop();
      p.dispose();
    }
    super.dispose();
  }
}