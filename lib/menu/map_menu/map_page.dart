import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../base_menu_page.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapController? _mapController;
  Position? position;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
        });
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
        });
        return null;
      }

      // Get current position
      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        position = currentPosition;
        _isLoading = false;
      });

      return currentPosition;
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseMenuPage(
      title: 'Map/GPS',
      icon: Icons.map,
      description:
          'Location services, GPS tracking, and geographical features.',
      accentColor: const Color(0xFF5958b2),
      additionalContent: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _isLoading
                  ? Container(
                      color: Colors.grey.shade200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFF5958b2),
                            ),
                            const SizedBox(height: 16),
                            const Text('Getting your location...'),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () async {
                                setState(() {
                                  _isLoading = true;
                                });
                                await _getCurrentLocation();
                              },
                              child: Text(
                                'Retry',
                                style: TextStyle(
                                  color: Colors.teal.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : position != null
                      ? FlutterMap(
                          mapController:
                              _mapController ?? MapController(),
                          options: MapOptions(
                            // UPDATED: flutter_map 8.x uses initialCenter / initialZoom
                            initialCenter: LatLng(
                              position!.latitude,
                              position!.longitude,
                            ),
                            initialZoom: 16.0,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.all &
                                  ~InteractiveFlag.rotate,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.example.idoxsapp',
                              maxZoom: 19,
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 40.0,
                                  height: 40.0,
                                  point: LatLng(
                                    position!.latitude,
                                    position!.longitude,
                                  ),
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                            RichAttributionWidget(
                              attributions: [
                                TextSourceAttribution(
                                  'OpenStreetMap contributors',
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ],
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.location_off,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                const Text('Unable to get location'),
                                const SizedBox(height: 8),
                                const Text(
                                  'Please enable location services',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () async {
                                    setState(() {
                                      _isLoading = true;
                                    });
                                    await _getCurrentLocation();
                                  },
                                  child: Text(
                                    'Try Again',
                                    style: TextStyle(
                                      color: Colors.teal.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
            ),
          ),
        ),
      ],
    );
  }
}
