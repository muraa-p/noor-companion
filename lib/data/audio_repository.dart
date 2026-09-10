import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Downloads recitation audio files (per-ayah) so the app can play offline.
/// Streaming and sequential ayah playback live in [RecitationProvider].
class AudioRepository {
  AudioRepository._();
  static AudioRepository? _instance;
  static AudioRepository get instance => _instance ??= AudioRepository._();

  final _downloadingAyahs = <String>{};

  Future<Directory> _baseDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/recitations');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> _surahDirPath(Reciter reciter, int surah) async =>
      '${(await _baseDir()).path}/${reciter.identifier}/${surah.toString().padLeft(3, '0')}';

  /// Absolute path to a single ayah's audio file.
  Future<String> ayahPath(Reciter reciter, int surah, int verse) async =>
      '${await _surahDirPath(reciter, surah)}/${verse.toString().padLeft(3, '0')}.mp3';

  /// Whether a specific ayah's audio file is saved to disk.
  Future<bool> ayahExists(Reciter reciter, int surah, int verse) async =>
      File(await ayahPath(reciter, surah, verse)).existsSync();

  /// Number of ayahs of the given surah already downloaded.
  Future<int> downloadedCount(Reciter reciter, int surah) async {
    final dir = Directory(await _surahDirPath(reciter, surah));
    if (!await dir.exists()) return 0;
    final files = await dir.list().toList();
    return files.where((f) => f.path.endsWith('.mp3')).length;
  }

  static int ayahCount(int surah) => _ayahCounts[surah - 1];

  /// Approximate bytes per ayah for the given reciter's bitrate (used only to
  /// size the downloadable in the download-prompt dialog).
  static int estimatePerAyahBytes(Reciter r) =>
      (r.audioBitrate == 128 ? 90 : 45) * 1024;

  /// Approximate full-surah size in bytes for the download prompt.
  static int estimateSurahBytes(Reciter r, int surah) =>
      estimatePerAyahBytes(r) * ayahCount(surah);

  /// Global ayah number (1..6236) used by the audio CDN.
  static int globalAyah(int surah, int verse) {
    var n = verse;
    for (var s = 1; s < surah; s++) {
      n += _ayahCounts[s - 1];
    }
    return n;
  }

  /// Downloads a single ayah (idempotent). Files are written to a `.part`
  /// sibling and atomically renamed so interrupted downloads never leave a
  /// corrupted file behind (which would otherwise block future retries).
  /// If the primary bitrate is unavailable on the CDN, the sibling bitrate
  /// (64 when the reciter defaults to 128 and vice versa) is tried.
  Future<void> downloadAyah(
    Reciter reciter,
    int surah,
    int verse, {
    void Function(int bytes, int total)? onProgress,
  }) async {
    final global = globalAyah(surah, verse);
    final target = File(await ayahPath(reciter, surah, verse));
    // A zero-length artifact counts as missing; clean it and redownload.
    if (await target.exists() && await target.length() > 0) return;
    if (await target.exists()) await target.delete();

    final fallbackBitrate = reciter.audioBitrate == 128 ? 64 : 128;
    final urls = <String>{
      reciter.ayahAudioUrl(global),
      reciter.ayahAudioUrl(global, bitrate: fallbackBitrate),
    };

    var lastError = 'Unknown error';
    for (final url in urls) {
      if (_downloadingAyahs.contains(url)) continue;
      final dir = Directory(target.parent.path);
      if (!await dir.exists()) await dir.create(recursive: true);
      final tmp = File('${target.path}.part');
      if (await tmp.exists()) await tmp.delete();
      _downloadingAyahs.add(url);
      try {
        await _httpDownload(url, tmp, onProgress: onProgress);
        if (await tmp.length() == 0) {
          throw HttpException('Empty file: $url');
        }
        await tmp.rename(target.path);
        return;
      } catch (e) {
        lastError = e.toString();
      } finally {
        _downloadingAyahs.remove(url);
      }
    }
    throw HttpException('Download failed: $lastError');
  }

  /// Downloads sync with 4 concurrent ayahs. Each file is a small HTTPS
  /// request whose TCP/TLS handshake dominates on high-latency links, so
  /// streaming a few at once shortens a full surah download considerably.
  static const int _parallelism = 4;

  /// Downloads every ayah of a surah. Progress: 0..count. Idempotent — ayahs
  /// already on disk are skipped, so interrupted downloads resume cleanly.
  Future<void> downloadSurah(
    Reciter reciter,
    int surah, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final count = ayahCount(surah);
    var next = 1;
    var completed = 0;

    Future<void> worker() async {
      while (true) {
        final verse = next++;
        if (verse > count) return;
        await downloadAyah(reciter, surah, verse);
        completed++;
        onProgress?.call(completed, count);
      }
    }

    await Future.wait(List.generate(_parallelism, (_) => worker()));
  }

  /// Whether the whole surah is saved to disk.
  Future<bool> surahDownloaded(Reciter reciter, int surah) async {
    final got = await downloadedCount(reciter, surah);
    return got >= ayahCount(surah);
  }

  /// Surah numbers fully downloaded for a reciter (used by the reciter
  /// badges and the "Downloaded" section). Iterates all 114 surahs rather
  /// than listing directories — simpler and more reliable across platforms.
  Future<Set<int>> downloadedSurahs(Reciter reciter) async {
    final result = <int>{};
    for (var s = 1; s <= 114; s++) {
      if (await surahDownloaded(reciter, s)) result.add(s);
    }
    return result;
  }

  /// Number of surahs fully downloaded for a reciter.
  Future<int> downloadedCountFor(Reciter reciter) async =>
      (await downloadedSurahs(reciter)).length;

  Future<void> deleteSurah(Reciter reciter, int surah) async {
    final dir = Directory(await _surahDirPath(reciter, surah));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> _httpDownload(
    String url,
    File target, {
    void Function(int bytes, int total)? onProgress,
  }) async {
    var lastError = 'Unknown error';
    for (var attempt = 0; attempt < 3; attempt++) {
      final client = HttpClient();
      try {
        client.connectionTimeout = const Duration(seconds: 20);
        final req = await client.getUrl(Uri.parse(url))..followRedirects = true;
        req.headers.set(HttpHeaders.userAgentHeader, 'Noor/1.0');
        final res = await req.close();
        if (res.statusCode != 200) {
          lastError = 'HTTP ${res.statusCode} for $url';
          throw HttpException(lastError);
        }
        final len = res.contentLength > 0 ? res.contentLength : 1;
        final sink = target.openWrite();
        var received = 0;
        await for (final chunk in res) {
          received += chunk.length;
          sink.add(chunk);
          onProgress?.call(received, len);
        }
        await sink.close();
        return;
      } on HttpException catch (e) {
        lastError = e.message;
      } on HandshakeException catch (e) {
        lastError = 'TLS handshake failed — ${e.message}';
      } on OSError catch (e) {
        lastError = e.message;
      } catch (e) {
        lastError = e.toString();
      } finally {
        client.close();
      }
      // Retry after a short backoff (transient network failures are common).
      await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    }
    throw HttpException('Download failed after retries: $lastError');
  }

  void dispose() {}
}

const List<int> _ayahCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111,
  110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45,
  83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55,
  78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20,
  56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21,
  11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,
];