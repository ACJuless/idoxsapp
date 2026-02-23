import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallLocPage extends StatefulWidget {
  final String doctorId;
  final String scheduledVisitId;

  const CallLocPage({
    Key? key,
    required this.doctorId,
    required this.scheduledVisitId,
  }) : super(key: key);

  @override
  State<CallLocPage> createState() => _CallLocPageState();
}

class _CallLocPageState extends State<CallLocPage> {
  MapController? _mapController;
  Position? position;
  String? address;
  bool _isLoading = true;
  String? emailKey;

  LatLng? updatedLatLng;
  String? updatedAddress;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initEmailAndLocation();
  }

  Future<void> _initEmailAndLocation() async {
    await _loadEmailKey();
    await _initLocationData();
  }

  Future<void> _loadEmailKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    setState(() {
      emailKey = userEmail.replaceAll(RegExp(r'[.#\$\[\]/]'), '_');
    });
  }

  Future<void> _initLocationData() async {
    await _getCurrentLocation();
    await _loadUpdatedLocationFromFirestore();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String? addressText = await _getAddressFromLatLng(
        currentPosition.latitude,
        currentPosition.longitude,
      );

      setState(() {
        position = currentPosition;
        address = addressText;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        String a = '';
        if (place.street != null && place.street!.isNotEmpty) {
          a += place.street!;
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          a += ', ${place.locality}';
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          a += ', ${place.administrativeArea}';
        }
        if (place.country != null && place.country!.isNotEmpty) {
          a += ', ${place.country}';
        }
        return a;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> _loadUpdatedLocationFromFirestore() async {
    if (emailKey == null) return;
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(emailKey!)
          .doc('doctors')
          .collection('doctors')
          .doc(widget.doctorId)
          .collection('scheduledVisits')
          .doc(widget.scheduledVisitId)
          .get();

      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null &&
            data['updatedLat'] != null &&
            data['updatedLng'] != null) {
          setState(() {
            updatedLatLng = LatLng(
              (data['updatedLat'] as num).toDouble(),
              (data['updatedLng'] as num).toDouble(),
            );
            updatedAddress = data['updatedAddress'];
          });
        }
      }
    } catch (e) {
      // silently fail
    }
  }

  Future<void> _onMapTap(LatLng latlng) async {
    if (position == null) return;

    final Distance distCalc = Distance();
    final LatLng initialLatLng =
        LatLng(position!.latitude, position!.longitude);
    double dist = distCalc(initialLatLng, latlng);

    if (dist <= 150) {
      String? newAddr =
          await _getAddressFromLatLng(latlng.latitude, latlng.longitude);
      setState(() {
        updatedLatLng = latlng;
        updatedAddress = newAddr;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New location must be within 150 meters!')),
      );
    }
  }

  Future<void> _updateLocationFirestore(
      LatLng latLng, String? address) async {
    if (emailKey == null) return;

    await FirebaseFirestore.instance
        .collection('flowDB')
        .doc('users')
        .collection(emailKey!)
        .doc('doctors')
        .collection('doctors')
        .doc(widget.doctorId)
        .collection('scheduledVisits')
        .doc(widget.scheduledVisitId)
        .update({
      'updatedLat': latLng.latitude,
      'updatedLng': latLng.longitude,
      'updatedAddress': address,
      'updatedTimestamp': FieldValue.serverTimestamp(),
    });

    // Reload from database to ensure UI is in sync
    await _loadUpdatedLocationFromFirestore();
  }

  @override
  Widget build(BuildContext context) {
    if (emailKey == null || emailKey!.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    LatLng? initialLatLng =
        position != null ? LatLng(position!.latitude, position!.longitude) : null;

    return Column(
      children: [
        if (position != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Current Location",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                address != null
                    ? Text(address!, style: const TextStyle(fontSize: 15))
                    : const Text(
                        "Getting address...",
                        style: TextStyle(fontSize: 15),
                      ),
                if (updatedLatLng != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Updated Location",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        SizedBox(
                          child: Text(
                            updatedAddress ??
                                "Lat: ${updatedLatLng!.latitude.toStringAsFixed(6)}, "
                                    "Lng: ${updatedLatLng!.longitude.toStringAsFixed(6)}",
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (position != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Accuracy: ${position!.accuracy.toStringAsFixed(1)}m",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _isLoading
                      ? Container(
                          color: Colors.grey.shade200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.red.shade600,
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
                                      color: Colors.red.shade600,
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
                                initialCenter: LatLng(
                                  position!.latitude,
                                  position!.longitude,
                                ),
                                initialZoom: 16.0,
                                interactionOptions:
                                    const InteractionOptions(
                                  flags: InteractiveFlag.all &
                                      ~InteractiveFlag.rotate,
                                ),
                                onTap: (tapPos, latlng) =>
                                    _onMapTap(latlng),
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
                                    if (initialLatLng != null)
                                      Marker(
                                        width: 40.0,
                                        height: 40.0,
                                        point: initialLatLng,
                                        child: const Icon(
                                          Icons.location_pin,
                                          color: Colors.red,
                                          size: 40,
                                        ),
                                      ),
                                    if (updatedLatLng != null)
                                      Marker(
                                        width: 38,
                                        height: 38,
                                        point: updatedLatLng!,
                                        child: const Icon(
                                          Icons.location_pin,
                                          color: Colors.green,
                                          size: 38,
                                        ),
                                      ),
                                  ],
                                ),
                                CircleLayer(
                                  circles: [
                                    if (initialLatLng != null)
                                      CircleMarker(
                                        point: initialLatLng,
                                        color: Colors.red
                                            .withOpacity(0.09),
                                        borderColor: Colors.red
                                            .withOpacity(0.18),
                                        borderStrokeWidth: 2,
                                        useRadiusInMeter: true,
                                        radius: 150,
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
                                          color: Colors.red.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                ),
                if (updatedLatLng != null)
                  Positioned(
                    top: 20,
                    right: 16,
                    child: FloatingActionButton.extended(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      icon: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                      ),
                      label: const Text("Update"),
                      onPressed: () async {
                        if (updatedLatLng == null) return;
                        await _updateLocationFirestore(
                          updatedLatLng!,
                          updatedAddress,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Location updated!'),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
