import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class Memo {
  Memo({required this.id, required this.photo, required this.createdAt, this.place, this.note = '', this.audio, this.threadId});
  final String id;
  String photo; // nombre de archivo dentro de la carpeta de la app
  final DateTime createdAt;
  String? place;
  String note;
  String? audio; // nombre de archivo
  String? threadId;

  Map<String, dynamic> toJson() => {
        'id': id, 'photo': photo, 'createdAt': createdAt.toIso8601String(),
        'place': place, 'note': note, 'audio': audio, 'threadId': threadId,
      };
  factory Memo.fromJson(Map<String, dynamic> j) => Memo(
        id: j['id'], photo: j['photo'], createdAt: DateTime.parse(j['createdAt']),
        place: j['place'], note: j['note'] ?? '', audio: j['audio'], threadId: j['threadId'],
      );
}

class Thread {
  Thread({required this.id, required this.name, this.closed = false, this.decision = ''});
  final String id;
  String name;
  bool closed;
  String decision;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'closed': closed, 'decision': decision};
  factory Thread.fromJson(Map<String, dynamic> j) =>
      Thread(id: j['id'], name: j['name'], closed: j['closed'] ?? false, decision: j['decision'] ?? '');
}

/// Guarda todo en la carpeta privada de la app (JSON + archivos). Sin base de datos: simple y fácil de respaldar.
class Store extends ChangeNotifier {
  late Directory dir;
  final List<Memo> memos = [];
  final List<Thread> threads = [];

  Future<void> init() async {
    dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'ancla'));
    await dir.create(recursive: true);
    final f = File(p.join(dir.path, 'data.json'));
    if (await f.exists()) {
      try {
        final j = jsonDecode(await f.readAsString());
        memos..clear()..addAll((j['memos'] as List).map((e) => Memo.fromJson(e)));
        threads..clear()..addAll((j['threads'] as List).map((e) => Thread.fromJson(e)));
      } catch (_) {/* archivo dañado: se empieza vacío, las fotos siguen en la carpeta */}
    }
    memos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  String path(String file) => p.join(dir.path, file);

  Future<void> _save() async {
    final tmp = File(p.join(dir.path, 'data.tmp'));
    await tmp.writeAsString(jsonEncode({'memos': memos.map((m) => m.toJson()).toList(), 'threads': threads.map((t) => t.toJson()).toList()}));
    await tmp.rename(p.join(dir.path, 'data.json')); // escritura atómica: no se corrompe si se cierra a medias
    notifyListeners();
  }

  Future<Memo> addMemo(File shot, {String? place}) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final name = '$id.jpg';
    await shot.copy(path(name));
    final m = Memo(id: id, photo: name, createdAt: DateTime.now(), place: place);
    memos.insert(0, m);
    await _save();
    return m;
  }

  Future<void> update(Memo m, {String? note, String? audio, String? threadId, String? place, bool clearThread = false, bool clearAudio = false}) async {
    if (note != null) m.note = note;
    if (place != null) m.place = place;
    if (audio != null) m.audio = audio;
    if (clearAudio) { await _rm(m.audio); m.audio = null; }
    if (threadId != null) m.threadId = threadId;
    if (clearThread) m.threadId = null;
    await _save();
  }

  Future<void> deleteMemo(Memo m) async {
    memos.removeWhere((e) => e.id == m.id);
    await _rm(m.photo);
    await _rm(m.audio);
    await _save();
  }

  Future<void> _rm(String? f) async {
    if (f == null) return;
    try { final x = File(path(f)); if (await x.exists()) await x.delete(); } catch (_) {}
  }

  Future<Thread> addThread(String name) async {
    final t = Thread(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name);
    threads.insert(0, t);
    await _save();
    return t;
  }

  Future<void> closeThread(Thread t, String decision) async {
    t.closed = true; t.decision = decision; await _save();
  }

  Future<void> reopenThread(Thread t) async { t.closed = false; await _save(); }

  Future<void> deleteThread(Thread t) async {
    for (final m in memos.where((m) => m.threadId == t.id)) { m.threadId = null; }
    threads.removeWhere((e) => e.id == t.id);
    await _save();
  }

  List<Memo> inThread(String id) => memos.where((m) => m.threadId == id).toList();
  Thread? thread(String? id) { for (final t in threads) { if (t.id == id) return t; } return null; }
}
