// file: lib/mapbox_demo/pages/home_page.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  mp.MapboxMap? mapboxMapController;
  gl.Position? currentPosition;
  StreamSubscription<gl.Position>? userPositionStream;

  bool showCamera = false;
  bool manuallyClosed = false;
  CameraController? _controller;
  bool _cameraReady = false;
  double _panelSize = 0.4;

  @override
  void initState() {
    super.initState();
    _setupPositionTracking();
    _initCamera();
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int hour = DateTime.now().hour;
    bool isNight = hour >= 18 || hour < 6;

    return Scaffold(
      body: Stack(
        children: [
          // 🗺️ MAPA
          mp.MapWidget(
            onMapCreated: _onMapCreated,
            styleUri:
                isNight ? mp.MapboxStyles.DARK : mp.MapboxStyles.MAPBOX_STREETS,
          ),

          // 🎥 CÁMARA DESLIZABLE
          if (_cameraReady && showCamera)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * _panelSize,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    _panelSize -= details.primaryDelta! /
                        MediaQuery.of(context).size.height;
                    _panelSize = _panelSize.clamp(0.3, 1.0);
                  });
                },
                onVerticalDragEnd: (details) {
                  if (_panelSize < 0.35) {
                    _panelSize = 0.3;
                  } else if (_panelSize > 0.85) {
                    _panelSize = 1.0;
                  }
                  setState(() {});
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 🎥 CÁMARA
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      child: CameraPreview(_controller!),
                    ),

                    // 🔴 BOLITAS ENCIMA DE LA CÁMARA
                    ..._buildCamino(context),

                    // 🧭 UI DE CÁMARA
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 70,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 28,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          "⬆️ Arrastra para ajustar la cámara ⬇️",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 40,
                      right: 20,
                      child: FloatingActionButton.small(
                        heroTag: "close_cam",
                        backgroundColor: Colors.redAccent,
                        onPressed: () => _toggleCamera(false),
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 📸 BOTÓN PARA ABRIR CÁMARA
          if (!showCamera)
            Positioned(
              bottom: 80,
              right: 20,
              child: FloatingActionButton(
                heroTag: "open_cam",
                backgroundColor: Colors.indigo,
                onPressed: () => _toggleCamera(true),
                child: const Icon(Icons.camera_alt, color: Colors.white),
              ),
            ),

          // 📍 MI UBICACIÓN
          Positioned(
            bottom: 160,
            right: 20,
            child: FloatingActionButton(
              heroTag: "my_loc",
              onPressed: _goToMyLocation,
              backgroundColor: Colors.redAccent,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.my_location, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  // 🔴 BOLITAS SOBRE LA CÁMARA
  List<Widget> _buildCamino(BuildContext context) {
    final List<Map<String, dynamic>> puntos = [
      {'lat': -17.7815185, 'lon': -63.1612936}, // inicio
      {'lat': -17.7815592, 'lon': -63.1613101},
      {'lat': -17.7815990, 'lon': -63.1613355},
      {'lat': -17.7816350, 'lon': -63.1613559},
      {'lat': -17.7815629, 'lon': -63.1614225}, // destino
    ];

    const baseLat = -17.7815185;
    const baseLon = -63.1612936;

    final List<Widget> widgets = [];
    for (final p in puntos) {
      final dx = (p['lon'] - baseLon) * 111320;
      final dz = (p['lat'] - baseLat) * 110540;

      final posX = 0.5 + (dx / 120) / MediaQuery.of(context).size.width;
      final posY = 0.6 - (dz / 120) / MediaQuery.of(context).size.height;

      widgets.add(Positioned(
        left: MediaQuery.of(context).size.width * posX.clamp(0.05, 0.9),
        top: MediaQuery.of(context).size.height * posY.clamp(0.05, 0.9),
        child: Image.asset(
          'assets/icons/punto_mapa_rojo_f.png',
          width: 50,
          height: 50,
        ),
      ));
    }

    return widgets;
  }

  // 📸 CÁMARA
  Future<void> _initCamera() async {
    await Permission.camera.request();
    final cameras = await availableCameras();
    _controller = CameraController(cameras.first, ResolutionPreset.high);
    await _controller!.initialize();
    setState(() => _cameraReady = true);
  }

  void _toggleCamera(bool value) {
    setState(() {
      manuallyClosed = !value;
      showCamera = value;
      if (!value) _panelSize = 0.4;
    });
  }

  // 🌍 MAPA
  Future<void> _onMapCreated(mp.MapboxMap controller) async {
    mapboxMapController = controller;
    await _checkAndRequestLocationPermission();

    await mapboxMapController?.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );

    final ByteData bytes =
        await rootBundle.load('assets/icons/punto_mapa_rojo_f.png');
    final Uint8List imageData = bytes.buffer.asUint8List();

    final pointAnnotationManager =
        await mapboxMapController?.annotations.createPointAnnotationManager();

    const double latCasa = -17.7815629;
    const double lonCasa = -63.1614225;

    final pointAnnotationOptions = mp.PointAnnotationOptions(
      geometry: mp.Point(coordinates: mp.Position(lonCasa, latCasa)),
      image: imageData,
      iconSize: 0.35,
    );

    await pointAnnotationManager?.create(pointAnnotationOptions);
  }

  // 🚶‍♂️ UBICACIÓN EN VIVO
  Future<void> _setupPositionTracking() async {
    await _checkAndRequestLocationPermission();
    gl.LocationSettings locationSettings = const gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 20,
    );

    userPositionStream?.cancel();
    userPositionStream = gl.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((gl.Position? position) {
      if (position != null) currentPosition = position;
    });
  }

  // 🎯 IR A MI UBICACIÓN
  Future<void> _goToMyLocation() async {
    if (currentPosition == null || mapboxMapController == null) return;
    await mapboxMapController!.flyTo(
      mp.CameraOptions(
        center: mp.Point(
          coordinates:
              mp.Position(currentPosition!.longitude, currentPosition!.latitude),
        ),
        zoom: 17.5,
        pitch: 45.0,
      ),
      mp.MapAnimationOptions(duration: 2000, startDelay: 0),
    );
  }

  // 🔐 PERMISOS
  Future<void> _checkAndRequestLocationPermission() async {
    bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('⚠️ Servicios de ubicación deshabilitados.');
    }

    gl.LocationPermission permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        return Future.error('❌ Permiso de ubicación denegado.');
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      return Future.error(
          '🚫 Permiso de ubicación denegado permanentemente. Actívalo en Ajustes.');
    }
  }
}
