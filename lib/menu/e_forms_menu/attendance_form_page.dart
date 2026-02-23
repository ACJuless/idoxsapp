import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

// Location, reverse geocoding, and map
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Signature
import 'package:signature/signature.dart';

// Facebook
// import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
// import 'package:url_launcher/url_launcher.dart';

// NEW: for numeric-only input
import 'package:flutter/services.dart';

class AttendanceFormPage extends StatefulWidget {
  @override
  State<AttendanceFormPage> createState() => _AttendanceFormPageState();
}

class _AttendanceFormPageState extends State<AttendanceFormPage> {
  // Single "event name"
  final TextEditingController eventNameController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();
  final TextEditingController cropFocusController = TextEditingController();
  final TextEditingController cropStatusController = TextEditingController();

  // Dealers / Focus products
  final List<TextEditingController> nameOfDealersControllers = [
    TextEditingController(),
  ];

  final List<TextEditingController> focusProductsControllers = [
    TextEditingController(),
  ];

  // Dynamic list of attendee name controllers
  final List<TextEditingController> attendeeControllers = [
    TextEditingController(),
  ];

  // NEW: per-attendee fields
  final List<TextEditingController> addressControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> telephoneControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> hectaresControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> cropControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> insecticideControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> fungicideControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> herbicideControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> nutritionControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> dealerSourceControllers = [
    TextEditingController(),
  ];

  // Facebook link per attendee row (OPTIONAL)
  final List<TextEditingController> facebookProfileLinkControllers = [
    TextEditingController(),
  ];

  // Signature controllers per attendee
  final List<SignatureController> attendeeSignatureControllers = [
    SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    ),
  ];

  DateTime _selectedDate = DateTime.now();
  String createdBy = '';

  Position? _position;
  String? _resolvedAddress;
  bool _isGettingLocation = false;
  MapController? _mapController;

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  Future<void> _initForm() async {
    _updateDateText(_selectedDate);
    await _loadCreatedByFromPrefs();
    await _initLocation();
  }

  void _updateDateText(DateTime dt) {
    dateController.text =
        "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    eventNameController.dispose();
    dateController.dispose();
    locationController.dispose();
    remarksController.dispose();
    cropFocusController.dispose();
    cropStatusController.dispose();

    for (final c in attendeeControllers) {
      c.dispose();
    }
    for (final c in addressControllers) {
      c.dispose();
    }
    for (final c in telephoneControllers) {
      c.dispose();
    }
    for (final c in hectaresControllers) {
      c.dispose();
    }
    for (final c in cropControllers) {
      c.dispose();
    }
    for (final c in insecticideControllers) {
      c.dispose();
    }
    for (final c in fungicideControllers) {
      c.dispose();
    }
    for (final c in herbicideControllers) {
      c.dispose();
    }
    for (final c in nutritionControllers) {
      c.dispose();
    }
    for (final c in dealerSourceControllers) {
      c.dispose();
    }

    for (final c in facebookProfileLinkControllers) {
      c.dispose();
    }
    for (final sc in attendeeSignatureControllers) {
      sc.dispose();
    }
    for (final c in nameOfDealersControllers) {
      c.dispose();
    }
    for (final c in focusProductsControllers) {
      c.dispose();
    }

    super.dispose();
  }

  Future<void> _loadCreatedByFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    setState(() {
      createdBy = userEmail;
    });
  }

  Future<String> _getSanitizedUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    return userEmail.replaceAll(RegExp(r'[.#\$\[\]/]'), '_');
  }

  Widget _headerCell(String label) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF52bb5f),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _dataCell(Widget child) {
    return Container(
      width: 160,
      height: 80,
      margin: const EdgeInsets.only(right: 2),
      child: child,
    );
  }

  void _addAttendeeField() {
    setState(() {
      attendeeControllers.add(TextEditingController());
      addressControllers.add(TextEditingController());
      telephoneControllers.add(TextEditingController());
      hectaresControllers.add(TextEditingController());
      cropControllers.add(TextEditingController());
      insecticideControllers.add(TextEditingController());
      fungicideControllers.add(TextEditingController());
      herbicideControllers.add(TextEditingController());
      nutritionControllers.add(TextEditingController());
      dealerSourceControllers.add(TextEditingController());
      facebookProfileLinkControllers.add(TextEditingController());
      attendeeSignatureControllers.add(
        SignatureController(
          penStrokeWidth: 3,
          penColor: Colors.black,
          exportBackgroundColor: Colors.white,
        ),
      );
    });
  }

  void _addDealerField() {
    setState(() {
      nameOfDealersControllers.add(TextEditingController());
    });
  }

  void _addFocusProductField() {
    setState(() {
      focusProductsControllers.add(TextEditingController());
    });
  }

  Future<List<Map<String, dynamic>>> _exportAttendeeSignatures() async {
    final List<Map<String, dynamic>> result = [];

    for (int i = 0; i < attendeeControllers.length; i++) {
      final name = attendeeControllers[i].text.trim();
      final SignatureController sc = attendeeSignatureControllers[i];

      if (name.isEmpty && sc.isEmpty) {
        continue;
      }

      final List<Map<String, dynamic>> serializedPoints = [];
      if (!sc.isEmpty) {
        final List<Point?> pts = sc.points;
        for (final p in pts) {
          if (p == null) continue;
          final dynamic dp = p;
          final Offset off = dp.offset as Offset;
          serializedPoints.add({
            'x': off.dx,
            'y': off.dy,
            'pressure': dp.pressure ?? 1.0,
            'type': dp.type.toString(),
          });
        }
      }

      result.add({
        'name': name,
        'points': serializedPoints,
      });
    }

    return result;
  }

  void _clearForm() {
    setState(() {
      eventNameController.clear();
      remarksController.clear();
      cropFocusController.clear();
      cropStatusController.clear();
      for (final c in attendeeControllers) {
        c.clear();
      }
      for (final c in addressControllers) {
        c.clear();
      }
      for (final c in telephoneControllers) {
        c.clear();
      }
      for (final c in hectaresControllers) {
        c.clear();
      }
      for (final c in cropControllers) {
        c.clear();
      }
      for (final c in insecticideControllers) {
        c.clear();
      }
      for (final c in fungicideControllers) {
        c.clear();
      }
      for (final c in herbicideControllers) {
        c.clear();
      }
      for (final c in nutritionControllers) {
        c.clear();
      }
      for (final c in dealerSourceControllers) {
        c.clear();
      }
      for (final c in facebookProfileLinkControllers) {
        c.clear();
      }
      for (final sc in attendeeSignatureControllers) {
        sc.clear();
      }
      for (final c in nameOfDealersControllers) {
        c.clear();
      }
      for (final c in focusProductsControllers) {
        c.clear();
      }
      _selectedDate = DateTime.now();
      _updateDateText(_selectedDate);
      // keep last known location and address
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _updateDateText(picked);
      });
    }
  }

  Future<void> _initLocation() async {
    setState(() {
      _isGettingLocation = true;
    });
    final pos = await _getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _position = pos;
      _isGettingLocation = false;
    });
    if (pos != null) {
      final addr = await _getAddressFromCoordinates(pos);
      if (!mounted) return;
      setState(() {
        _resolvedAddress = addr;
        if (addr.isNotEmpty) {
          locationController.text = addr;
        }
      });
    }
  }

  Future<Position?> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<String> _getAddressFromCoordinates(Position pos) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isEmpty) return '';
      final p = placemarks.first;
      final parts = [
        p.street,
        p.subLocality,
        p.locality,
        p.administrativeArea,
        p.postalCode,
        p.country,
      ]
          .where((e) => e != null && e!.trim().isNotEmpty)
          .map((e) => e!.trim())
          .toList();
      return parts.join(', ');
    } catch (_) {
      return '';
    }
  }

  Future<void> _submitForm() async {
    // ===== REQUIRED FIELDS VALIDATION =====
    if (eventNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the event name.")),
      );
      return;
    }

    if (cropFocusController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the crop focus.")),
      );
      return;
    }

    if (cropStatusController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the crop status.")),
      );
      return;
    }

    if (locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please wait for location.")),
      );
      return;
    }

    // At least one dealer name (if textfields exist)
    final nonEmptyDealers = nameOfDealersControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (nonEmptyDealers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter at least one dealer name.")),
      );
      return;
    }

    // At least one focus product
    final nonEmptyFocusProducts = focusProductsControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (nonEmptyFocusProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter at least one focus product.")),
      );
      return;
    }

    // Build attendee rows & validate required fields per row
    final List<Map<String, dynamic>> attendees = [];
    bool hasAtLeastOneAttendee = false;

    for (int i = 0; i < attendeeControllers.length; i++) {
      final name = attendeeControllers[i].text.trim();
      final addr = addressControllers[i].text.trim();
      final tel = telephoneControllers[i].text.trim();
      final hect = hectaresControllers[i].text.trim();
      final crop = cropControllers[i].text.trim();
      final insect = insecticideControllers[i].text.trim();
      final fung = fungicideControllers[i].text.trim();
      final herb = herbicideControllers[i].text.trim();
      final nutr = nutritionControllers[i].text.trim();
      final dealerSrc = dealerSourceControllers[i].text.trim();
      final fbLink = facebookProfileLinkControllers[i].text.trim();

      // If entire row is empty, skip
      final allEmpty = [
        name,
        addr,
        tel,
        hect,
        crop,
        insect,
        fung,
        herb,
        nutr,
        dealerSrc,
        fbLink,
      ].every((v) => v.isEmpty);

      if (allEmpty) {
        continue;
      }

      // Required fields per attendee row (except Facebook link)
      if (name.isEmpty ||
          addr.isEmpty ||
          tel.isEmpty ||
          hect.isEmpty ||
          crop.isEmpty ||
          insect.isEmpty ||
          fung.isEmpty ||
          herb.isEmpty ||
          nutr.isEmpty ||
          dealerSrc.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Please complete all required fields for attendee row ${i + 1}.",
            ),
          ),
        );
        return;
      }

      hasAtLeastOneAttendee = true;

      attendees.add({
        'name': name,
        'address': addr,
        'telephone': tel,
        'hectares': hect,
        'crop': crop,
        'insecticide': insect,
        'fungicide': fung,
        'herbicide': herb,
        'nutrition': nutr,
        'dealerSource': dealerSrc,
        'facebookLink': fbLink, // optional
      });
    }

    if (!hasAtLeastOneAttendee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill at least one attendee row.")),
      );
      return;
    }

    // Signature export (optional, retains your existing structure)
    final List<Map<String, dynamic>> attendeeSignatures =
        await _exportAttendeeSignatures();

    final userKey = await _getSanitizedUserEmail();

    await FirebaseFirestore.instance
        .collection('flowDB')
        .doc('users')
        .collection(userKey)
        .doc('attendance_forms')
        .collection('attendance_forms')
        .add({
      'eventName': eventNameController.text.trim(),
      'cropFocus': cropFocusController.text.trim(),
      'cropStatus': cropStatusController.text.trim(),
      'date': dateController.text,
      'location': locationController.text.trim(),
      'createdBy': createdBy,
      'deviceLat': _position?.latitude,
      'deviceLng': _position?.longitude,
      'deviceAddress': _resolvedAddress,
      'timestamp': DateTime.now(),
      'remarks': remarksController.text.trim(), // optional
      'attendees': attendees, // NEW: full attendee rows
      'attendeeSignatures': attendeeSignatures,
      'dealers': nonEmptyDealers,
      'focusProducts': nonEmptyFocusProducts,
    });

    Navigator.of(context).pop();
  }

  // Future<void> _openBrandPageForLike() async {
  //   final Uri webUri =
  //       Uri.parse('https://www.facebook.com/IndofilPhilippinesInc');

  //   await launchUrl(
  //     webUri,
  //     mode: LaunchMode.externalApplication,
  //   );
  // }

  /// Facebook login and fill a specific row's Facebook link field
  // Future<void> _linkFacebookAndFillField(int rowIndex) async {
  //   try {
  //     // 1) Login or reuse existing login
  //     AccessToken? accessToken = await FacebookAuth.instance.accessToken;
  //     if (accessToken == null) {
  //       final LoginResult result = await FacebookAuth.instance.login(
  //         permissions: const ['public_profile'],
  //       );
  //       if (result.status != LoginStatus.success) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text('Facebook login failed: ${result.status}'),
  //           ),
  //         );
  //         return;
  //       }
  //     }

  //     // 2) Get user data, including profile link / id
  //     final Map<String, dynamic> userData =
  //         await FacebookAuth.instance.getUserData(
  //       fields: 'id,name,link',
  //     );
  //     final String id = userData['id'] as String;
  //     final String? linkFromGraph = userData['link'] as String?;

  //     // 3) Build final profile URL
  //     final String profileUrl =
  //         linkFromGraph ?? 'https://www.facebook.com/$id';

  //     // 4) Fill the correct row's TextField
  //     setState(() {
  //       facebookProfileLinkControllers[rowIndex].text = profileUrl;
  //     });

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Facebook profile linked.')),
  //     );
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Error linking Facebook: $e')),
  //     );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Form"),
        centerTitle: true,
        elevation: 4,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF5e1398),
                Color(0xFF6d16b1),
                Color(0xFF7d19ca),
                Color(0xFF8c1ce4),
                Color(0xFF9c1ffd),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Input Event Details and Attendees",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5958b2),
                        fontFamily: GoogleFonts.ubuntu().fontFamily,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Name of Event + Crop Focus
                    Row(
                      children: [
                        // Name of Event (REQUIRED)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.cyan.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                    child: Text(
                                      "Name of Event *",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.ubuntu(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: eventNameController,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.cyan.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Crop Focus (REQUIRED)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.cyan.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                    child: Text(
                                      "Crop Focus *",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.ubuntu(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: cropFocusController,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.cyan.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Attendees header (+ button)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.cyan.shade100,
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            height: 26,
                            width: 26,
                            child: ElevatedButton(
                              onPressed: _addAttendeeField,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Attendees",
                              maxLines: 2,
                              softWrap: true,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.ubuntu(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Attendees table
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // header row
                          Row(
                            children: [
                              _headerCell("Name of Farmer *"),
                              _headerCell("Address *"),
                              _headerCell("Telephone / CP No. *"),
                              _headerCell("Number of Hectares *"),
                              _headerCell("Crop *"),
                              _headerCell("Insecticide *"),
                              _headerCell("Fungicide *"),
                              _headerCell("Herbicide *"),
                              _headerCell("Crop Nutrition/Follar *"),
                              _headerCell("Dealer Name (Source) *"),
                              _headerCell("Facebook Link"),
                              _headerCell("Signature"),
                              _headerCell("Sig. Tools"),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Column(
                            children: List.generate(
                              attendeeControllers.length < 3
                                  ? 3
                                  : attendeeControllers.length,
                              (index) {
                                // Ensure lists are large enough
                                if (index >= attendeeControllers.length) {
                                  attendeeControllers
                                      .add(TextEditingController());
                                  addressControllers
                                      .add(TextEditingController());
                                  telephoneControllers
                                      .add(TextEditingController());
                                  hectaresControllers
                                      .add(TextEditingController());
                                  cropControllers
                                      .add(TextEditingController());
                                  insecticideControllers
                                      .add(TextEditingController());
                                  fungicideControllers
                                      .add(TextEditingController());
                                  herbicideControllers
                                      .add(TextEditingController());
                                  nutritionControllers
                                      .add(TextEditingController());
                                  dealerSourceControllers
                                      .add(TextEditingController());
                                  facebookProfileLinkControllers
                                      .add(TextEditingController());
                                  attendeeSignatureControllers.add(
                                    SignatureController(
                                      penStrokeWidth: 3,
                                      penColor: Colors.black,
                                      exportBackgroundColor: Colors.white,
                                    ),
                                  );
                                }

                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Name of Farmer
                                      _dataCell(
                                        TextField(
                                          controller:
                                              attendeeControllers[index],
                                          cursorColor: Colors.black,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 40.0),
                                            hintText: '${index + 1}',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            enabledBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            focusedBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                        ),
                                      ),

                                      // Address
                                      _dataCell(
                                        TextField(
                                          controller:
                                              addressControllers[index],
                                          cursorColor: Colors.black,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 40.0),
                                            hintText: "",
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            enabledBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            focusedBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                        ),
                                      ),

                                      // Telephone / CP (numeric only)
                                      _dataCell(
                                        TextField(
                                          controller:
                                              telephoneControllers[index],
                                          keyboardType:
                                              TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          cursorColor: Colors.black,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 40.0),
                                            hintText: "",
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            enabledBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            focusedBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                        ),
                                      ),

                                      // Number of Hectares (numeric only)
                                      _dataCell(
                                        TextField(
                                          controller:
                                              hectaresControllers[index],
                                          keyboardType:
                                              const TextInputType
                                                  .numberWithOptions(
                                                      decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d*\.?\d*'),
                                            ),
                                          ],
                                          cursorColor: Colors.black,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 40.0),
                                            hintText: "",
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            enabledBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            focusedBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                        ),
                                      ),

                                      // Crop
                                      _dataCell(
                                        TextField(
                                          controller:
                                              cropControllers[index],
                                          cursorColor: Colors.black,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 40.0),
                                            hintText: "",
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            enabledBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            focusedBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                        ),
                                      ),

                                      // Insecticide
                                      _dataCell(
                                        TextField(
                                          controller:
                                              insecticideControllers[index],
                                          cursorColor: Colors.black,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 40.0),
                                            hintText: "",
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            enabledBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            focusedBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                        ),
                                      ),

                                      // Fungicide
                                      _dataCell(
                                        TextField(
                                          controller:
                                              fungicideControllers[index],
                                          cursorColor: Colors.black,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 40.0),
                                            hintText: "",
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            enabledBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            focusedBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                        ),
                                      ),

                                      // Herbicide
                                      _dataCell(
                                        TextField(
                                          controller:
                                              herbicideControllers[index],
                                          cursorColor: Colors.black,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 40.0),
                                            hintText: "",
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            enabledBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            focusedBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                        ),
                                      ),

                                      // Crop Nutrition/Follar
                                      _dataCell(
                                        TextField(
                                          controller:
                                              nutritionControllers[index],
                                          cursorColor: Colors.black,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 40.0),
                                            hintText: "",
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            enabledBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            focusedBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                        ),
                                      ),

                                      // Dealer Name (Source)
                                      _dataCell(
                                        TextField(
                                          controller:
                                              dealerSourceControllers[index],
                                          cursorColor: Colors.black,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 40.0),
                                            hintText: "",
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            enabledBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            focusedBorder:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide:
                                                  const BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                        ),
                                      ),

                                      // // Facebook Link (OPTIONAL)
                                      // _dataCell(
                                      //   Row(
                                      //     children: [
                                      //       Expanded(
                                      //         child: TextField(
                                      //           controller:
                                      //               facebookProfileLinkControllers[
                                      //                   index],
                                      //           readOnly: true,
                                      //           cursorColor: Colors.black,
                                      //           decoration: InputDecoration(
                                      //             contentPadding:
                                      //                 const EdgeInsets
                                      //                     .symmetric(
                                      //               vertical: 40.0,
                                      //               horizontal: 8.0,
                                      //             ),
                                      //             hintText: "",
                                      //             border: OutlineInputBorder(
                                      //               borderRadius:
                                      //                   BorderRadius
                                      //                       .circular(8),
                                      //               borderSide:
                                      //                   const BorderSide(
                                      //                 color: Colors.grey,
                                      //                 width: 0.5,
                                      //               ),
                                      //             ),
                                      //             enabledBorder:
                                      //                 OutlineInputBorder(
                                      //               borderRadius:
                                      //                   BorderRadius
                                      //                       .circular(8),
                                      //               borderSide:
                                      //                   const BorderSide(
                                      //                 color: Colors.grey,
                                      //                 width: 0.5,
                                      //               ),
                                      //             ),
                                      //             focusedBorder:
                                      //                 OutlineInputBorder(
                                      //               borderRadius:
                                      //                   BorderRadius
                                      //                       .circular(8),
                                      //               borderSide:
                                      //                   const BorderSide(
                                      //                 color: Colors.grey,
                                      //                 width: 0.5,
                                      //               ),
                                      //             ),
                                      //             filled: true,
                                      //             fillColor:
                                      //                 Colors.white,
                                      //           ),
                                      //         ),
                                      //       ),
                                      //       const SizedBox(width: 4),
                                      //       SizedBox(
                                      //         width: 32,
                                      //         height: 32,
                                      //         child: ElevatedButton(
                                      //           onPressed: () =>
                                      //               _linkFacebookAndFillField(
                                      //                   index),
                                      //           style: ElevatedButton
                                      //               .styleFrom(
                                      //             padding:
                                      //                 EdgeInsets.zero,
                                      //             shape:
                                      //                 const CircleBorder(),
                                      //             backgroundColor:
                                      //                 Colors.blue,
                                      //             foregroundColor:
                                      //                 Colors.white,
                                      //           ),
                                      //           child: const Icon(
                                      //             Icons.facebook,
                                      //             size: 18,
                                      //           ),
                                      //         ),
                                      //       ),
                                      //     ],
                                      //   ),
                                      // ),

                                      // Signature
                                      Container(
                                        width: 160,
                                        margin:
                                            const EdgeInsets.only(right: 4),
                                        child: Container(
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color:
                                                  Colors.grey.shade300,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Signature(
                                              controller:
                                                  attendeeSignatureControllers[
                                                      index],
                                              width: double.infinity,
                                              height: 80,
                                              backgroundColor:
                                                  Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Clear / Undo (signature)
                                      Container(
                                        width: 70,
                                        margin:
                                            const EdgeInsets.only(right: 4),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // Clear
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color:
                                                    Colors.red.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        6),
                                              ),
                                              child: IconButton(
                                                padding: EdgeInsets.zero,
                                                iconSize: 18,
                                                onPressed: () {
                                                  setState(() {
                                                    attendeeSignatureControllers[
                                                            index]
                                                        .clear();
                                                  });
                                                },
                                                icon: Icon(
                                                  Icons.clear,
                                                  color: Colors
                                                      .red.shade800,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            // Undo (placeholder)
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: Colors
                                                    .yellow.shade200,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        6),
                                              ),
                                              child: IconButton(
                                                padding: EdgeInsets.zero,
                                                iconSize: 18,
                                                onPressed: () {
                                                  // per-row undo logic can go here
                                                },
                                                icon: Icon(
                                                  Icons.undo,
                                                  color: Colors
                                                      .orange.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Date + Crop Status
                    Row(
                      children: [
                        // Date (read-only, required but already auto-filled)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.cyan.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                    child: Text(
                                      "Date *",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.ubuntu(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: dateController,
                                readOnly: true,
                                onTap: _pickDate,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.cyan.shade50,
                                  suffixIcon: Icon(
                                    Icons.calendar_today_outlined,
                                    color: Colors.cyan.shade600,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Crop Status (REQUIRED)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.cyan.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                    child: Text(
                                      "Crop Status *",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.ubuntu(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: cropStatusController,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.cyan.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Name of Dealers + Focus Products (dynamic, both required at least one entry)
                    Row(
                      children: [
                        // Name of Dealers
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.cyan.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.cyan.shade100,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: ElevatedButton(
                                        onPressed: _addDealerField,
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Name of Dealers *",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.ubuntu(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        softWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Column(
                                children: List.generate(
                                  nameOfDealersControllers.length,
                                  (index) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 6.0),
                                      child: TextField(
                                        controller:
                                            nameOfDealersControllers[index],
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          filled: true,
                                          fillColor: Colors.cyan.shade50,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Focus Products
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.cyan.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.cyan.shade100,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: ElevatedButton(
                                        onPressed:
                                            _addFocusProductField,
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Focus Products *",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.ubuntu(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        softWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Column(
                                children: List.generate(
                                  focusProductsControllers.length,
                                  (index) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 6.0),
                                      child: TextField(
                                        controller:
                                            focusProductsControllers[index],
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          filled: true,
                                          fillColor: Colors.cyan.shade50,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Venue + Map + Address text (unchanged structure)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.cyan.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.cyan.shade100),
                          ),
                          child: Center(
                            child: Text(
                              'Venue *',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.ubuntu(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AbsorbPointer(
                          absorbing: true,
                          child: TextField(
                            controller: locationController,
                            readOnly: true,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.cyan.shade50,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Container(
                      height:
                          MediaQuery.of(context).size.height * 0.32,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _position != null
                            ? FlutterMap(
                                mapController: _mapController ?? MapController(),
                                options: MapOptions(
                                  // UPDATED: flutter_map 8.x API
                                  initialCenter: LatLng(
                                    _position!.latitude,
                                    _position!.longitude,
                                  ),
                                  initialZoom: 16.0,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                                  ),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.example.idoxsapp',
                                    maxZoom: 19,
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        width: 40.0,
                                        height: 40.0,
                                        point: LatLng(
                                          _position!.latitude,
                                          _position!.longitude,
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
                                      const TextSourceAttribution(
                                        'OpenStreetMap contributors',
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Container(
                                color: Colors.white.withOpacity(0.1),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isGettingLocation)
                                        const CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      if (_isGettingLocation) const SizedBox(height: 16),
                                      Text(
                                        _isGettingLocation
                                            ? 'Getting your location...'
                                            : 'Location unavailable',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: () async {
                                          setState(() {
                                            _isGettingLocation = true;
                                          });
                                          final pos = await _getCurrentLocation();
                                          if (!mounted) return;
                                          setState(() {
                                            _position = pos;
                                            _isGettingLocation = false;
                                          });
                                          if (pos != null) {
                                            final addr =
                                                await _getAddressFromCoordinates(pos);
                                            if (!mounted) return;
                                            setState(() {
                                              _resolvedAddress = addr;
                                              if (addr.isNotEmpty) {
                                                locationController.text = addr;
                                              }
                                            });
                                          }
                                        },
                                        child: const Text(
                                          'Retry',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                    const SizedBox(height: 12),
                    if (_position != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _resolvedAddress ??
                                    'Getting address...',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Additional Remarks (OPTIONAL)
                    Center(
                      child: Text(
                        "Additional Remarks",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ubuntu(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: remarksController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.cyan.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Center(
                      child: Text(
                        'PRIVACY NOTICE : ',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'All information collected thru this attendance sheet shall be used for the purpose of expense liquidation, '
                      'market information gathering, future marketing promotions, and as proof of activity. '
                      'If you wish to revoke these authorization, you may send as an email via indofilph@indofil.com or call us at (02) 8636 3857 '
                      'to 58. All information collected will remain secured and confidential with Indofil Philippines Inc, '
                      'and only authorized personnel shall have access to them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      // REMOVED Clear FAB as requested
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'submit_attendance',
        backgroundColor: const Color(0xFF5958b2),
        onPressed: _submitForm,
        label: const Text(
          'Submit',
          style: TextStyle(color: Colors.white),
        ),
        icon: const Icon(Icons.check, color: Colors.white),
      ),
    );
  }
}
