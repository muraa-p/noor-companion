import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/audio_repository.dart';
import 'data/hasanat_repository.dart';
import 'data/notification_service.dart';
import 'data/quran_repository.dart';
import 'providers/hasanat_provider.dart';
import 'providers/quran_provider.dart';
import 'providers/recitation_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_shell.dart';
import 'services/noor_audio_handler.dart';
import 'theme/colors.dart';

/// The audio handler, initialised once and reused for the app's lifetime so
/// playback keeps reporting to the notification shade / lock screen.
late final NoorAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await NotificationService.instance.init();

  final audio = AudioRepository.instance;
  final quran = QuranProvider(QuranRepository.instance);
  await quran.ensureLoaded();

  final settings = SettingsProvider(prefs);
  await settings.load();

  // Re-assert the daily reminder every launch (Android drops inexact alarms
  // across device reboots), so an enabled reminder keeps the streak alive.
  if (settings.dailyReminder) {
    await NotificationService.instance.scheduleDailyReminder(
      hour: settings.reminderTimeMinutes ~/ 60,
      minute: settings.reminderTimeMinutes % 60,
    );
  }

  // The shared recitation provider owns the audio player; the media-service
  // handler routes notification-shade commands through it so the UI and the
  // notification always agree on playback state.
  final recitation = RecitationProvider(
    audio: audio,
    quran: quran,
    settings: settings,
  );

  audioHandler = NoorAudioHandler(recitation);
  await AudioService.init(
    builder: () => audioHandler,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.noor.quran.audio',
      androidNotificationChannelName: 'Recitation playback',
      androidNotificationOngoing: true,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: quran),
        ChangeNotifierProvider(
          create: (_) => HasanatProvider(
            repo: HasanatRepository(),
            quran: quran,
          )..load(),
        ),
        ChangeNotifierProvider.value(value: recitation),
      ],
      child: const NoorApp(),
    ),
  );
}

class NoorApp extends StatelessWidget {
  const NoorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'Noor',
      debugShowCheckedModeBanner: false,
      theme: buildNoorTheme(brightness: Brightness.light),
      darkTheme: buildNoorTheme(brightness: Brightness.dark),
      themeMode: settings.theme,
      home: const HomeShell(),
    );
  }
}