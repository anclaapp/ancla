import 'dart:io';
import 'package:flutter/material.dart';
import 'main.dart';
import 'store.dart';
import 'viewer_screen.dart';

class ThreadsScreen extends StatefulWidget {
  const ThreadsScreen({super.key});
  @override
  State<ThreadsScreen> createState() => _ThreadsScreenState();
}

class _ThreadsScreenState extends State<ThreadsScreen> {
  @override
  void initState() { super.initState(); store.addListener(_r); }
  @override
  void dispose() { store.removeListener(_r); super.dispose(); }
  void _r() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Hilos'), backgroundColor: kBg),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: kYellow, foregroundColor: Colors.black,
          icon: const Icon(Icons.add), label: const Text('Nuevo hilo'),
          onPressed: () async {
            final n = await askText(context, 'Nombre del hilo', 'Ej: Casa nueva');
            if (n != null && n.trim().isNotEmpty) await store.addThread(n.trim());
          },
        ),
        body: store.threads.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Un hilo agrupa fotos de un mismo proyecto (casa, viaje, compra) hasta que tomas una decisión.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))))
            : ListView(children: [
                for (final t in store.threads)
                  ListTile(
                    leading: CircleAvatar(backgroundColor: t.closed ? Colors.green : kPurple, child: Icon(t.closed ? Icons.check : Icons.link, color: Colors.white)),
                    title: Text(t.name),
                    subtitle: Text(t.closed ? 'Cerrado: ${t.decision}' : '${store.inThread(t.id).length} fotos · abierto'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ThreadDetail(thread: t))),
                  ),
              ]),
      );
}

class ThreadDetail extends StatefulWidget {
  const ThreadDetail({super.key, required this.thread});
  final Thread thread;
  @override
  State<ThreadDetail> createState() => _ThreadDetailState();
}

class _ThreadDetailState extends State<ThreadDetail> {
  Thread get t => widget.thread;
  @override
  void initState() { super.initState(); store.addListener(_r); }
  @override
  void dispose() { store.removeListener(_r); super.dispose(); }
  void _r() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final items = store.inThread(t.id)..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return Scaffold(
      appBar: AppBar(title: Text(t.name), backgroundColor: kBg, actions: [
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'close') {
              final d = await askText(context, 'Decisión final', 'Ej: Compramos la de la calle Sol');
              if (d != null && d.trim().isNotEmpty) await store.closeThread(t, d.trim());
            } else if (v == 'open') {
              await store.reopenThread(t);
            } else if (v == 'del') {
              await store.deleteThread(t); // las fotos NO se borran, solo salen del hilo
              if (mounted) Navigator.pop(context);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: t.closed ? 'open' : 'close', child: Text(t.closed ? 'Reabrir hilo' : 'Cerrar con una decisión')),
            const PopupMenuItem(value: 'del', child: Text('Eliminar hilo (conserva las fotos)')),
          ],
        ),
      ]),
      body: Column(children: [
        if (t.closed) Container(width: double.infinity, color: Colors.green.withAlpha(60), padding: const EdgeInsets.all(14), child: Text('Decisión: ${t.decision}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        Expanded(child: items.isEmpty
            ? const Center(child: Text('Añade fotos desde el botón de información (i) de cada foto.', style: TextStyle(color: Colors.white54), textAlign: TextAlign.center))
            : GridView.builder(
                padding: const EdgeInsets.all(4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 3, crossAxisSpacing: 3),
                itemCount: items.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewerScreen(memos: items, index: i))),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.file(File(store.path(items[i].photo)), fit: BoxFit.cover, cacheWidth: 300),
                    if (items[i].audio != null) const Positioned(right: 4, bottom: 4, child: CircleAvatar(radius: 11, backgroundColor: kYellow, child: Icon(Icons.mic, size: 14, color: Colors.black))),
                  ]),
                ),
              )),
      ]),
    );
  }
}
