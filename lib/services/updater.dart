import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Set to your repo. Each GitHub Release needs an .apk asset and a tag like v1.0.1
const githubRepo = 'YOUR_USER/motion_player';

enum UpdateStage { none, available, downloading, ready, error }

class Updater extends ChangeNotifier {
  UpdateStage stage = UpdateStage.none;
  double progress = 0;
  String? version, _url, _path;

  Future<void> check() async {
    try {
      final r = await Dio().get('https://api.github.com/repos/$githubRepo/releases/latest');
      final tag = (r.data['tag_name'] as String).replaceFirst('v', '');
      final cur = (await PackageInfo.fromPlatform()).version;
      final apks = (r.data['assets'] as List).where((a) => a['name'].toString().endsWith('.apk'));
      if (apks.isNotEmpty && _newer(tag, cur)) {
        version = tag; _url = apks.first['browser_download_url'];
        stage = UpdateStage.available; notifyListeners();
      }
    } catch (_) {}
  }

  bool _newer(String a, String b) {
    final x = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final y = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0;
      if (p != q) return p > q;
    }
    return false;
  }

  Future<void> download() async {
    stage = UpdateStage.downloading; progress = 0; notifyListeners();
    try {
      final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      _path = '${dir.path}/motion_player_$version.apk';
      await Dio().download(_url!, _path!, onReceiveProgress: (r, t) {
        if (t > 0) { progress = r / t; notifyListeners(); }
      });
      stage = UpdateStage.ready;
    } catch (_) { stage = UpdateStage.error; }
    notifyListeners();
  }

  Future<void> install() async =>
      OpenFilex.open(_path!, type: 'application/vnd.android.package-archive');
}

class UpdateBanner extends StatelessWidget {
  final Updater u;
  const UpdateBanner(this.u, {super.key});
  @override
  Widget build(BuildContext c) {
    if (u.stage == UpdateStage.none) return const SizedBox.shrink();
    final (String text, String? label, VoidCallback? act) = switch (u.stage) {
      UpdateStage.available => ('Version ${u.version} is available', 'Download now', u.download),
      UpdateStage.downloading => ('Downloading update… ${(u.progress * 100).toInt()}%', null, null),
      UpdateStage.ready => ('Update downloaded', 'Install now', u.install),
      _ => ('Update failed', 'Retry', u.download),
    };
    return Material(
      color: const Color(0xFF1E1E1E),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        Row(children: [
          const Icon(Icons.system_update, color: Color(0xFF00E5FF)), const SizedBox(width: 12),
          Expanded(child: Text(text)),
          if (label != null) FilledButton(onPressed: act, child: Text(label)),
        ]),
        if (u.stage == UpdateStage.downloading) LinearProgressIndicator(value: u.progress),
      ])),
    );
  }
}
