import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'main.dart';
import 'store.dart';

/// Foto a pantalla completa. Encima solo: grabar voz, reproducir, borrar e info.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.memos, required this.index, this.autoRecord = false});
  final List<Memo> memos;
  final int index;
  final bool autoRecord;
  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final PageController _pc = PageController(initialPage: widget.index);
  @override
  void dispose() { _pc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          controller: _pc,
          itemCount: widget.memos.length,
          itemBuilder: (_, i) => MemoPage(key: ValueKey(widget.memos[i].id), memo: widget.memos[i], autoRecord: widget.autoRecord && i == widget.index),
        ),
      );
}

class MemoPage extends StatefulWidget {
  const MemoPage({super.key, required this.memo, required this.autoRecord});
  final Memo memo;
  final bool autoRecord;
  @override
  State<MemoPage> createState() => _MemoPageState();
}

class _MemoPageState extends State<MemoPage> {
  final _rec = AudioRecorder();
  final _player = AudioPlayer();
  bool _recording = false, _playing = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  StreamSubscription? _sub;
  Memo get m => widget.memo;

  @override
  void initState() {
    super.initState();
    _sub = _player.onPlayerComplete.listen((_) { if (mounted) setState(() => _playing = false); });
    if (widget.autoRecord) WidgetsBinding.instance.addPostFrameCallback((_) => _startRec());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    // Si se sale grabando, NO se pierde la nota: se cierra y se guarda.
    if (_recording) { _stopAndSave(); } else { _rec.dispose(); }
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRec() async {
    if (_recording) return;
    if (!await _rec.hasPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activa el permiso del micrófono en Ajustes para grabar voz.')));
      return;
    }
    await _player.stop();
    final file = '${m.id}.m4a';
    await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1), path: store.path(file));
    _elapsed = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _elapsed += const Duration(seconds: 1)); });
    if (mounted) setState(() { _recording = true; _playing = false; });
  }

  Future<void> _stopAndSave() async {
    _timer?.cancel();
    final path = await _rec.stop();
    await _rec.dispose();
    if (path != null) await store.update(m, audio: '${m.id}.m4a');
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _togglePlay() async {
    if (m.audio == null) return;
    if (_playing) { await _player.pause(); setState(() => _playing = false); return; }
    await _player.play(DeviceFileSource(store.path(m.audio!)));
    setState(() => _playing = true);
  }

  Future<void> _delete() async {
    // Sin preguntar dos veces: borra y vuelve directo a la cámara.
    _timer?.cancel();
    if (_recording) { await _rec.stop(); }
    await _player.stop();
    await store.deleteMemo(m);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _info() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1A1633),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => InfoSheet(memo: m));
  }

  String _clock(Duration d) => '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';

  @override
  Widget build(BuildContext context) {
    final hasAudio = m.audio != null;
    return Stack(fit: StackFit.expand, children: [
      InteractiveViewer(maxScale: 5, child: Image.file(File(store.path(m.photo)), fit: BoxFit.contain)),
      SafeArea(child: Align(alignment: Alignment.topCenter, child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          _btn(Icons.arrow_back, () => Navigator.of(context).maybePop()),
          const Spacer(),
          if (_recording) Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
            child: Text('● ${_clock(_elapsed)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          _btn(Icons.info_outline, _info),
        ]),
      ))),
      SafeArea(child: Align(alignment: Alignment.bottomCenter, child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          // reproducir (solo si hay nota de voz)
          hasAudio && !_recording ? _btn(_playing ? Icons.pause : Icons.play_arrow, _togglePlay, size: 56, color: kBlue) : const SizedBox(width: 56),
          // grabar / detener (sin límite de duración)
          GestureDetector(
            onTap: _recording ? _stopAndSave : _startRec,
            child: Container(
              width: 76, height: 76,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _recording ? Colors.red : (hasAudio ? kPurple : kYellow)),
              child: Icon(_recording ? Icons.stop : Icons.mic, size: 38, color: _recording || hasAudio ? Colors.white : Colors.black),
            ),
          ),
          _btn(Icons.delete_outline, _delete, size: 56),
        ]),
      ))),
    ]);
  }

  Widget _btn(IconData i, VoidCallback f, {double size = 44, Color color = Colors.black54}) => GestureDetector(
        onTap: f,
        child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color), child: Icon(i, color: Colors.white)),
      );
}

class InfoSheet extends StatefulWidget {
  const InfoSheet({super.key, required this.memo});
  final Memo memo;
  @override
  State<InfoSheet> createState() => _InfoSheetState();
}

class _InfoSheetState extends State<InfoSheet> {
  late final TextEditingController _note = TextEditingController(text: widget.memo.note);
  Memo get m => widget.memo;

  @override
  void dispose() {
    if (_note.text != m.note) store.update(m, note: _note.text);
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final th = store.thread(m.threadId);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _row(Icons.calendar_today, fmtDate(m.createdAt)),
        _row(Icons.access_time, fmtTime(m.createdAt)),
        _row(Icons.place_outlined, m.place ?? 'Sin lugar (activa la ubicación para guardarlo)'),
        const SizedBox(height: 12),
        TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(labelText: 'Nota (por qué la guardaste)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          ActionChip(
            avatar: const Icon(Icons.link, size: 18),
            label: Text(th == null ? 'Añadir a un hilo' : 'Hilo: ${th.name}'),
            onPressed: () async { await _pickThread(); if (mounted) setState(() {}); },
          ),
          if (th != null) ActionChip(label: const Text('Quitar del hilo'), onPressed: () async { await store.update(m, clearThread: true); if (mounted) setState(() {}); }),
        ]),
      ]),
    );
  }

  Widget _row(IconData i, String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Icon(i, size: 20, color: kYellow), const SizedBox(width: 12), Expanded(child: Text(t, style: const TextStyle(fontSize: 16)))]));

  Future<void> _pickThread() async {
    final open = store.threads.where((t) => !t.closed).toList();
    final choice = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(title: const Text('Elige un hilo'), children: [
      for (final t in open) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, t.id), child: Text(t.name)),
      SimpleDialogOption(onPressed: () => Navigator.pop(ctx, '__new'), child: const Text('+ Crear hilo nuevo', style: TextStyle(color: kYellow))),
    ]));
    if (choice == null) return;
    if (choice == '__new') {
      final name = await askText(context, 'Nombre del hilo', 'Ej: Casa nueva');
      if (name == null || name.trim().isEmpty) return;
      final t = await store.addThread(name.trim());
      await store.update(m, threadId: t.id);
    } else {
      await store.update(m, threadId: choice);
    }
  }
}

Future<String?> askText(BuildContext context, String title, String hint, {String initial = ''}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
    title: Text(title),
    content: TextField(controller: c, autofocus: true, decoration: InputDecoration(hintText: hint)),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Aceptar'))],
  ));
}
