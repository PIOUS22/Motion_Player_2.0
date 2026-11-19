import 'dart:io';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/library.dart';
import '../services/updater.dart';
import 'equalizer.dart';
import 'player.dart';

String fmt(Duration d) {
  String t(int n) => n.toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:${t(d.inMinutes % 60)}:${t(d.inSeconds % 60)}' : '${t(d.inMinutes)}:${t(d.inSeconds % 60)}';
}

class Shell extends StatefulWidget { const Shell({super.key}); @override State<Shell> createState() => _S(); }
class _S extends State<Shell> {
  int i = 0; bool vaultOpen = false;

  Future<void> _tab(int n) async {
    if (n == 3 && !vaultOpen) {
      try {
        final ok = await LocalAuthentication().authenticate(localizedReason: 'Unlock Private folder');
        if (!ok) return;
        vaultOpen = true;
      } catch (_) { return; }
    }
    if (n != 3) vaultOpen = false;
    setState(() => i = n);
  }

  @override
  Widget build(BuildContext c) {
    final lib = c.watch<LibraryState>();
    final pages = [VideosPage(lib, folderMode: false), MusicPage(lib), VideosPage(lib, folderMode: true), VaultPage(lib)];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Motion Player', style: TextStyle(fontWeight: FontWeight.w800, color: cyan)),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => showSearch(context: c, delegate: _Search(lib))),
          PopupMenuButton<SortBy>(icon: const Icon(Icons.sort), onSelected: lib.setSort,
            itemBuilder: (_) => SortBy.values.map((s) => PopupMenuItem(value: s, child: Text('Sort by ${s.name}'))).toList()),
        ],
      ),
      body: Column(children: [UpdateBanner(c.watch<Updater>()), Expanded(child: pages[i])]),
      bottomNavigationBar: NavigationBar(selectedIndex: i, onDestinationSelected: _tab, destinations: const [
        NavigationDestination(icon: Icon(Icons.videocam_outlined), label: 'Videos'),
        NavigationDestination(icon: Icon(Icons.music_note_outlined), label: 'Music'),
        NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Folders'),
        NavigationDestination(icon: Icon(Icons.lock_outline), label: 'Private'),
      ]),
    );
  }
}

class _Search extends SearchDelegate {
  final LibraryState lib; _Search(this.lib);
  @override List<Widget>? buildActions(BuildContext c) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override Widget? buildLeading(BuildContext c) => BackButton(onPressed: () { lib.setQuery(''); close(c, null); });
  @override Widget buildResults(BuildContext c) { lib.setQuery(query); return VideosPage(lib, folderMode: false); }
  @override Widget buildSuggestions(BuildContext c) => buildResults(c);
}

class Thumb extends StatelessWidget {
  final AssetEntity a; const Thumb(this.a, {super.key});
  @override
  Widget build(BuildContext c) => GestureDetector(
    onTap: () async { final f = await a.originFile; if (f != null && c.mounted) Navigator.push(c, MaterialPageRoute(builder: (_) => PlayerPage(file: f))); },
    onLongPress: () => showModalBottomSheet(context: c, builder: (_) => ListTile(
      leading: const Icon(Icons.lock), title: const Text('Move to Private'),
      onTap: () { c.read<LibraryState>().hide(a); Navigator.pop(c); })),
    child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Stack(fit: StackFit.expand, children: [
      AssetEntityImage(a, isOriginal: false, thumbnailSize: const ThumbnailSize.square(400), fit: BoxFit.cover),
      Positioned(right: 6, bottom: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
        child: Text(fmt(a.videoDuration), style: const TextStyle(fontSize: 11, color: orange)))),
    ])),
  );
}

class VideosPage extends StatelessWidget {
  final LibraryState lib; final bool folderMode;
  const VideosPage(this.lib, {super.key, required this.folderMode});
  @override
  Widget build(BuildContext c) {
    const g = SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.4);
    if (!folderMode) {
      final v = lib.view(lib.videos);
      return GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: g, itemCount: v.length, itemBuilder: (_, i) => Thumb(v[i]));
    }
    final f = lib.folders().entries.toList();
    return GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: g, itemCount: f.length,
      itemBuilder: (_, i) => InkWell(
        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(f[i].key)),
          body: GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: g, itemCount: f[i].value.length, itemBuilder: (_, j) => Thumb(f[i].value[j]))))),
        child: Container(decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.folder, size: 40, color: cyan), Text(f[i].key, overflow: TextOverflow.ellipsis), Text('${f[i].value.length} videos', style: const TextStyle(color: Colors.white54, fontSize: 12))])));
  }
}

class MusicPage extends StatelessWidget {
  final LibraryState lib; const MusicPage(this.lib, {super.key});
  @override
  Widget build(BuildContext c) {
    final a = lib.view(lib.audios);
    return ListView.builder(itemCount: a.length, itemBuilder: (_, i) => ListTile(
      leading: const Icon(Icons.music_note, color: orange), title: Text(a[i].title ?? ''), subtitle: Text(fmt(a[i].videoDuration)),
      onTap: () async { final f = await a[i].originFile; if (f != null && c.mounted) Navigator.push(c, MaterialPageRoute(builder: (_) => AudioPage(file: f))); }));
  }
}

class VaultPage extends StatelessWidget {
  final LibraryState lib; const VaultPage(this.lib, {super.key});
  @override
  Widget build(BuildContext c) => lib.vault.isEmpty
    ? const Center(child: Text('Long-press a video to move it here'))
    : ListView(children: lib.vault.map((f) => ListTile(
        leading: const Icon(Icons.lock, color: cyan), title: Text(f.uri.pathSegments.last),
        trailing: IconButton(icon: const Icon(Icons.lock_open), onPressed: () => lib.unhide(f)),
        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => PlayerPage(file: f))))).toList());
}
