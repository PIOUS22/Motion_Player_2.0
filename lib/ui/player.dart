import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:floating/floating.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';
import '../core/theme.dart';
import 'home.dart' show fmt;

class PlayerPage extends StatefulWidget { final File file; const PlayerPage({super.key, required this.file}); @override State<PlayerPage> createState() => _P(); }
class _P extends State<PlayerPage> {
  late VideoPlayerController v;
  bool ready = false, ui = true, locked = false, subs = true;
  double brightness = .5, volume = .5, zoom = 1, speed = 1;
  Duration? a, b, seekTo; String hud = '';
  static const speeds = [.25, .5, .75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    v = VideoPlayerController.file(widget.file)..initialize().then((_) { setState(() => ready = true); v.play(); });
    v.addListener(() { if (b != null && a != null && v.value.position >= b!) v.seekTo(a!); if (mounted) setState(() {}); });
    ScreenBrightness().current.then((x) => brightness = x);
    VolumeController().getVolume().then((x) => volume = x);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
    v.dispose(); super.dispose();
  }

  void _skip(int s) => v.seekTo(v.value.position + Duration(seconds: s));

  Future<void> _loadSubs() async {
    final r = await FilePicker.platform.pickFiles();
    if (r == null) return;
    final p = r.files.single.path!;
    final txt = await File(p).readAsString();
    if (!p.toLowerCase().endsWith('.srt')) return; // .ass: see README roadmap
    await v.setClosedCaptionFile(Future.value(SubRipCaptionFile(txt)));
  }

  @override
  Widget build(BuildContext c) {
    if (!ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final w = MediaQuery.of(c).size.width;
    return Scaffold(backgroundColor: Colors.black, body: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => ui = !ui),
      onDoubleTapDown: (d) { final x = d.localPosition.dx;
        x < w / 3 ? _skip(-10) : x > w * 2 / 3 ? _skip(10) : (v.value.isPlaying ? v.pause() : v.play()); },
      onScaleUpdate: (d) {
        if (locked) return;
        if (d.pointerCount > 1) { setState(() => zoom = (zoom * d.scale).clamp(1.0, 4.0)); return; }
        final dx = d.focalPointDelta.dx, dy = d.focalPointDelta.dy;
        if (dy.abs() > dx.abs()) {
          final left = d.localFocalPoint.dx < w / 2;
          if (left) { brightness = (brightness - dy / 400).clamp(0.0, 1.0); ScreenBrightness().setScreenBrightness(brightness); hud = 'Brightness ${(brightness * 100).toInt()}%'; }
          else { volume = (volume - dy / 400).clamp(0.0, 1.0); VolumeController().setVolume(volume, showSystemUI: false); hud = 'Volume ${(volume * 100).toInt()}%'; }
        } else {
          seekTo = (seekTo ?? v.value.position) + Duration(milliseconds: (dx * 150).toInt());
          hud = fmt(seekTo!);
        }
        setState(() {});
      },
      onScaleEnd: (_) { if (seekTo != null) v.seekTo(seekTo!); seekTo = null; setState(() => hud = ''); },
      child: Stack(fit: StackFit.expand, children: [
        Center(child: Transform.scale(scale: zoom, child: AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v)))),
        if (subs) Positioned(bottom: 50, left: 20, right: 20, child: Text(v.value.caption.text, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, backgroundColor: Colors.black54))),
        if (hud.isNotEmpty) Center(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: Text(hud, style: const TextStyle(fontSize: 22)))),
        if (ui) _controls(c),
      ]),
    ));
  }

  Widget _controls(BuildContext c) => Container(color: Colors.black38, child: Column(children: [
    Row(children: [
      BackButton(onPressed: () => Navigator.pop(c)),
      Expanded(child: Text(widget.file.uri.pathSegments.last, overflow: TextOverflow.ellipsis)),
      ActionChip(label: Text('${speed}x'), backgroundColor: cyan.withOpacity(.25), onPressed: () {
        speed = speeds[(speeds.indexOf(speed) + 1) % speeds.length]; v.setPlaybackSpeed(speed); }),
      IconButton(icon: Icon(subs ? Icons.subtitles : Icons.subtitles_off), onPressed: () => setState(() => subs = !subs), onLongPress: _loadSubs),
      IconButton(icon: const Icon(Icons.picture_in_picture_alt), onPressed: () => Floating().enable(const ImmediatePiP())),
    ]),
    const Spacer(),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(iconSize: 36, icon: const Icon(Icons.replay_10), onPressed: () => _skip(-10)),
      IconButton(iconSize: 64, color: cyan, icon: Icon(v.value.isPlaying ? Icons.pause_circle : Icons.play_circle), onPressed: () => v.value.isPlaying ? v.pause() : v.play()),
      IconButton(iconSize: 36, icon: const Icon(Icons.forward_10), onPressed: () => _skip(10)),
    ]),
    const Spacer(),
    VideoProgressIndicator(v, allowScrubbing: true, colors: const VideoProgressColors(playedColor: cyan)),
    Row(children: [
      Text(' ${fmt(v.value.position)} / ${fmt(v.value.duration)}'), const Spacer(),
      TextButton(onPressed: () => setState(() { if (a == null) a = v.value.position; else if (b == null) b = v.value.position; else { a = b = null; } }),
        child: Text(a == null ? 'A-B' : b == null ? 'A set' : 'A-B on', style: const TextStyle(color: orange))),
      IconButton(icon: Icon(locked ? Icons.screen_lock_rotation : Icons.screen_rotation), onPressed: () => setState(() => locked = !locked)),
    ]),
  ]));
}
