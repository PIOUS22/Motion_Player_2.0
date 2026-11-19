# Motion Player
1. Edit `githubRepo` in `lib/services/updater.dart`.
2. Push to GitHub. Actions builds the APK (Actions tab -> artifact).
3. For updates: bump `version:` in pubspec.yaml, push tag `v1.0.1` -> release with APK -> installed apps show "Download now" / "Install now".
Notes: MainActivity must extend FlutterFragmentActivity for biometrics (`flutter create` default is FlutterActivity; change it in android/app/src/main/kotlin/.../MainActivity.kt).
Roadmap: .ass subtitles, subtitle delay/fonts, embedded audio-track switching, encrypted vault, resume position.
