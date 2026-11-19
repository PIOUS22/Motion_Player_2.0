import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'data/library.dart';
import 'services/updater.dart';
import 'ui/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.motionplayer.audio',
    androidNotificationChannelName: 'Motion Player', androidNotificationOngoing: true);
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LibraryState()..scan()),
      ChangeNotifierProvider(create: (_) => Updater()..check()),
    ],
    child: MaterialApp(title: 'Motion Player', debugShowCheckedModeBanner: false, theme: darkTheme, home: const Shell()),
  ));
}
