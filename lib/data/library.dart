import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';

enum SortBy { date, size, name }

class LibraryState extends ChangeNotifier {
  List<AssetEntity> videos = [], audios = [];
  List<File> vault = [];
  SortBy sort = SortBy.date;
  String query = '';

  Future<void> scan() async {
    final p = await PhotoManager.requestPermissionExtend();
    if (!p.hasAccess) return;
    videos = await _all(RequestType.video);
    audios = await _all(RequestType.audio);
    await loadVault();
    notifyListeners();
  }

  Future<List<AssetEntity>> _all(RequestType t) async {
    final paths = await PhotoManager.getAssetPathList(type: t, onlyAll: true);
    if (paths.isEmpty) return [];
    return paths.first.getAssetListRange(start: 0, end: 5000);
  }

  void setSort(SortBy s) { sort = s; notifyListeners(); }
  void setQuery(String q) { query = q.toLowerCase(); notifyListeners(); }

  List<AssetEntity> view(List<AssetEntity> src) {
    final l = src.where((a) => (a.title ?? '').toLowerCase().contains(query)).toList();
    l.sort((a, b) => switch (sort) {
      SortBy.date => b.createDateTime.compareTo(a.createDateTime),
      SortBy.size => (b.size.width * b.size.height).compareTo(a.size.width * a.size.height),
      SortBy.name => (a.title ?? '').compareTo(b.title ?? ''),
    });
    return l;
  }

  Map<String, List<AssetEntity>> folders() {
    final m = <String, List<AssetEntity>>{};
    for (final a in view(videos)) {
      final parts = (a.relativePath ?? 'Other').split('/').where((e) => e.isNotEmpty);
      m.putIfAbsent(parts.isEmpty ? 'Other' : parts.last, () => []).add(a);
    }
    return m;
  }

  Future<Directory> _vaultDir() async {
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/.vault');
    return d.existsSync() ? d : d.create(recursive: true);
  }

  Future<void> loadVault() async =>
      vault = (await _vaultDir()).listSync().whereType<File>().toList();

  Future<void> hide(AssetEntity a) async {
    final f = await a.originFile;
    if (f == null) return;
    await f.copy('${(await _vaultDir()).path}/${a.title}');
    await PhotoManager.editor.deleteWithIds([a.id]);
    await scan();
  }

  Future<void> unhide(File f) async {
    await f.copy('/storage/emulated/0/Movies/${f.uri.pathSegments.last}');
    await f.delete();
    await scan();
  }
}
