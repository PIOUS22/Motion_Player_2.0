import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../core/theme.dart';

final eq = AndroidEqualizer();
final audioPlayer = AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [eq]));

class AudioPage extends StatefulWidget { final File file; const AudioPage({super.key, required this.file}); @override State<AudioPage> createState() => _A(); }
class _A extends State<AudioPage> {
  @override
  void initState() {
    super.initState();
    audioPlayer.setAudioSource(AudioSource.file(widget.file.path,
      tag: MediaItem(id: widget.file.path, title: widget.file.uri.pathSegments.last)))
      .then((_) => audioPlayer.play());
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Now Playing')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Icon(Icons.album, size: 140, color: orange),
      Text(widget.file.uri.pathSegments.last, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
      StreamBuilder<Duration>(stream: audioPlayer.positionStream, builder: (_, s) => Slider(
        value: (s.data ?? Duration.zero).inMilliseconds.toDouble().clamp(0, (audioPlayer.duration ?? const Duration(seconds: 1)).inMilliseconds.toDouble()),
        max: (audioPlayer.duration ?? const Duration(seconds: 1)).inMilliseconds.toDouble(),
        onChanged: (v) => audioPlayer.seek(Duration(milliseconds: v.toInt())))),
      StreamBuilder<bool>(stream: audioPlayer.playingStream, builder: (_, s) => IconButton(iconSize: 64, color: cyan,
        icon: Icon(s.data == true ? Icons.pause_circle : Icons.play_circle), onPressed: () => s.data == true ? audioPlayer.pause() : audioPlayer.play())),
      const EqualizerPanel(),
    ]),
  );
}

class EqualizerPanel extends StatefulWidget { const EqualizerPanel({super.key}); @override State<EqualizerPanel> createState() => _E(); }
class _E extends State<EqualizerPanel> {
  static const presets = {'Flat': [0.0, 0, 0, 0, 0], 'Bass': [.8, .5, 0, 0, 0], 'Rock': [.5, .2, -.1, .3, .5], 'Pop': [-.1, .3, .5, .2, -.1], 'Vocal': [-.3, 0, .5, .4, 0]};
  AndroidEqualizerParameters? p; bool bgPlay = true; double bass = 0;

  @override
  void initState() { super.initState(); eq.parameters.then((v) => setState(() => p = v)); eq.setEnabled(true); }

  void _preset(List<double> g) {
    if (p == null) return;
    for (var i = 0; i < p!.bands.length; i++) {
      final b = p!.bands[i], n = g[(i * 5 / p!.bands.length).floor()];
      b.setGain(p!.minDecibels + (n + 1) / 2 * (p!.maxDecibels - p!.minDecibels));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext c) {
    if (p == null) return const SizedBox();
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)), child: Column(children: [
      Wrap(spacing: 8, children: presets.entries.map((e) => ActionChip(label: Text(e.key), onPressed: () => _preset(e.value))).toList()),
      SizedBox(height: 180, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: p!.bands.map((b) => Column(children: [
        Expanded(child: RotatedBox(quarterTurns: 3, child: Slider(min: p!.minDecibels, max: p!.maxDecibels, value: b.gain, onChanged: (v) => setState(() => b.setGain(v))))),
        Text('${b.centerFrequency ~/ 1000 > 0 ? '${(b.centerFrequency / 1000).toStringAsFixed(0)}k' : b.centerFrequency.toInt()}', style: const TextStyle(fontSize: 11)),
      ])).toList())),
      ListTile(title: const Text('Bass boost'), subtitle: Slider(activeColor: orange, value: bass, onChanged: (v) {
        setState(() => bass = v);
        final b = p!.bands.first; b.setGain(p!.minDecibels + v * (p!.maxDecibels - p!.minDecibels));
      })),
      SwitchListTile(title: const Text('Background play'), value: bgPlay, onChanged: (v) => setState(() => bgPlay = v)),
    ]));
  }
}
