import 'dart:io';
import 'package:flutter/material.dart';
import 'main.dart';
import 'store.dart';
import 'viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String _filter = 'todas';
  @override
  void initState() { super.initState(); store.addListener(_r); }
  @override
  void dispose() { store.removeListener(_r); super.dispose(); }
  void _r() { if (mounted) setState(() {}); }

  List<Memo> get _items => store.memos.where((m) => switch (_filter) {
        'voz' => m.audio != null,
        'sinhilo' => m.threadId == null,
        _ => true,
      }).toList();

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Galería'), backgroundColor: kBg),
      body: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
          for (final f in const [['todas', 'Todas'], ['voz', 'Con voz'], ['sinhilo', 'Sin hilo']])
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(f[1]), selected: _filter == f[0], onSelected: (_) => setState(() => _filter = f[0]))),
        ])),
        Expanded(child: items.isEmpty
            ? const Center(child: Text('Aún no hay fotos aquí.', style: TextStyle(color: Colors.white54)))
            : GridView.builder(
                padding: const EdgeInsets.all(4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 3, crossAxisSpacing: 3),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final m = items[i];
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewerScreen(memos: items, index: i))),
                    child: Stack(fit: StackFit.expand, children: [
                      Image.file(File(store.path(m.photo)), fit: BoxFit.cover, cacheWidth: 300),
                      if (m.audio != null) const Positioned(right: 4, bottom: 4, child: CircleAvatar(radius: 11, backgroundColor: kYellow, child: Icon(Icons.mic, size: 14, color: Colors.black))),
                    ]),
                  );
                },
              )),
      ]),
    );
  }
}
