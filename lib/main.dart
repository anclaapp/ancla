import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'camera_screen.dart';
import 'store.dart';

final store = Store();

const kPurple = Color(0xFF7C5CFF);
const kBlue = Color(0xFF3D8BFF);
const kYellow = Color(0xFFFFD54A);
const kBg = Color(0xFF0E0B1F);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  await store.init();
  runApp(const AnclaApp());
}

class AnclaApp extends StatelessWidget {
  const AnclaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ancla',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kBg,
          colorScheme: const ColorScheme.dark(primary: kPurple, secondary: kYellow, surface: Color(0xFF1A1633)),
          useMaterial3: true,
        ),
        home: const CameraScreen(),
      );
}

String two(int n) => n.toString().padLeft(2, '0');
const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
String fmtDate(DateTime d) => '${d.day} ${_meses[d.month - 1]} ${d.year}';
String fmtTime(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
