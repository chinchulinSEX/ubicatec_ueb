import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

// 📄 Importaciones locales
import 'login_new.dart';
import 'AR_bolitasPages_new.dart'; // 👈 NUEVO: pantalla AR

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setup();
  runApp(const MyApp());
}

Future<void> setup() async {
  // Cargar variables del archivo .env
  await dotenv.load(fileName: ".env");

  // Token de Mapbox
  MapboxOptions.setAccessToken(dotenv.env["MAPBOX_ACCESS_TOKEN"]!);

  // Pedir permisos de cámara y ubicación
  await Permission.camera.request();
  await Permission.locationWhenInUse.request();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ubicatec Unificado',
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),

      // 👇 Pantalla inicial
      home: const LoginNewPage(),

      // 👇 Rutas adicionales
      routes: {
        '/ar': (context) => const ARBolitasPagesNew(), // Ruta a la cámara AR
      },
    );
  }
}
