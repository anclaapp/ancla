import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'gallery_screen.dart';
import 'main.dart';
import 'store.dart';
import 'threads_screen.dart';
import 'viewer_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _c;
  List<CameraDescription> _cams = [];
  int _camIdx = 0;
  FlashMode _flash = FlashMode.off;
  bool _voice = false; // "foto + voz": al disparar se abre el visor grabando
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.addListener(_rebuild);
    _start();
  }

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(_rebuild);
    _c?.dispose(); // liberar la cámara SIEMPRE: si no, otras apps no pueden usarla
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final c = _c;
    if (s == AppLifecycleState.inactive || s == AppLifecycleState.paused) {
      _c = null; c?.dispose();
      if (mounted) setState(() {});
    } else if (s == AppLifecycleState.resumed && _c == null && _error == null) {
      _open();
    }
  }

  Future<void> _start() async {
    final st = await [Permission.camera, Permission.microphone].request();
    if (st[Permission.camera] != PermissionStatus.granted) {
      setState(() => _error = 'Ancla necesita la cámara para tomar fotos.\nActívala en Ajustes > Apps > Ancla > Permisos.');
      return;
    }
    try {
      _cams = await availableCameras();
      if (_cams.isEmpty) { setState(() => _error = 'No se encontró ninguna cámara.'); return; }
      await _open();
    } catch (e) {
      setState(() => _error = 'No se pudo abrir la cámara.\n$e');
    }
  }

  Future<void> _open() async {
    final old = _c; _c = null;
    await old?.dispose();
    final c = CameraController(_cams[_camIdx], ResolutionPreset.high, enableAudio: false);
    try {
      await c.initialize();
      await c.setFlashMode(_flash);
      if (!mounted) { await c.dispose(); return; }
      setState(() => _c = c);
    } catch (e) {
      await c.dispose();
      if (mounted) setState(() => _error = 'No se pudo abrir la cámara.\n$e');
    }
  }

  Future<void> _flip() async {
    if (_cams.length < 2 || _busy) return;
    _camIdx = (_camIdx + 1) % _cams.length;
    await _open();
  }

  Future<void> _toggleFlash() async {
    final c = _c; if (c == null) return;
    _flash = _flash == FlashMode.off ? FlashMode.auto : _flash == FlashMode.auto ? FlashMode.always : FlashMode.off;
    await c.setFlashMode(_flash);
    setState(() {});
  }

  Future<void> _shoot() async {
    final c = _c;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture || _busy) return;
    setState(() => _busy = true);
    try {
      final x = await c.takePicture();
      final memo = await store.addMemo(File(x.path));
      try { await File(x.path).delete(); } catch (_) {}
      _saveToPhone(memo);
      _fillPlace(memo); // en segundo plano: no hace esperar al usuario
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ViewerScreen(memos: [memo], index: 0, autoRecord: _voice)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo tomar la foto: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Copia la foto al álbum "Ancla" de la galería del teléfono (Google Fotos / Galería lo muestran).
  Future<void> _saveToPhone(Memo m) async {
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        if (!await Gal.requestAccess(toAlbum: true)) return;
      }
      await Gal.putImage(store.path(m.photo), album: 'Ancla');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo copiar la foto a la galería del teléfono.')));
    }
  }

  Future<void> _fillPlace(Memo m) async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)));
      String label = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      try {
        final pm = (await placemarkFromCoordinates(pos.latitude, pos.longitude)).first;
        final parts = [pm.street, pm.locality].where((e) => e != null && e.isNotEmpty).toList();
        if (parts.isNotEmpty) label = parts.join(', ');
      } catch (_) {/* sin internet: se queda con las coordenadas */}
      await store.update(m, place: label);
    } catch (_) {/* sin ubicación: la foto se guarda igual */}
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final last = store.memos.isEmpty ? null : store.memos.first;
    return Scaffold(
      backgroundColor: Colors.black,
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              FilledButton(onPressed: () { setState(() => _error = null); _start(); }, child: const Text('Reintentar')),
              TextButton(onPressed: openAppSettings, child: const Text('Abrir Ajustes')),
            ])))
          : Stack(fit: StackFit.expand, children: [
              if (c != null && c.value.isInitialized)
                Center(child: AspectRatio(aspectRatio: 1 / c.value.aspectRatio, child: CameraPreview(c)))
              else
                const Center(child: CircularProgressIndicator()),
              // barra superior
              SafeArea(child: Align(alignment: Alignment.topCenter, child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(children: [
                  _roundBtn(_flash == FlashMode.off ? Icons.flash_off : _flash == FlashMode.auto ? Icons.flash_auto : Icons.flash_on, _toggleFlash),
                  const Spacer(),
                  const Text('Ancla', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const Spacer(),
                  _roundBtn(Icons.link, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThreadsScreen()))),
                ]),
              ))),
              // barra inferior
              SafeArea(child: Align(alignment: Alignment.bottomCenter, child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: () => setState(() => _voice = !_voice),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: _voice ? kYellow : Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.mic, size: 18, color: _voice ? Colors.black : Colors.white),
                        const SizedBox(width: 6),
                        Text(_voice ? 'Foto + voz' : 'Solo foto', style: TextStyle(color: _voice ? Colors.black : Colors.white, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    // miniatura de la última foto -> abre la galería
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GalleryScreen())),
                      child: Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 2), color: Colors.black45),
                        clipBehavior: Clip.antiAlias,
                        child: last == null ? const Icon(Icons.photo_library_outlined) : Image.file(File(store.path(last.photo)), fit: BoxFit.cover, cacheWidth: 200),
                      ),
                    ),
                    GestureDetector(
                      onTap: _shoot,
                      child: Container(
                        width: 78, height: 78, padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                        child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: _busy ? Colors.grey : kPurple)),
                      ),
                    ),
                    _roundBtn(Icons.cameraswitch, _flip, size: 56),
                  ]),
                ]),
              ))),
            ]),
    );
  }

  Widget _roundBtn(IconData i, VoidCallback f, {double size = 44}) => GestureDetector(
        onTap: f,
        child: Container(width: size, height: size, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54), child: Icon(i, color: Colors.white)),
      );
}
