import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../menu/e_forms_menu/forms_page.dart';
import '../menu/itinerary_menu/itinerary_page.dart';
import '../menu/doctor_menu/doctor_page.dart';
import '../webview/webview_in_field_page.dart';
import '../webview/webview_attendance_form_page.dart';
import '../webview/webview_abr_form_page.dart';
import '../webview/webview_scp_form_page.dart';
import '../webview/webview_incidental_coverage_form_page.dart';
import '../webview/webview_sales_order_form_page.dart';
import 'package:signature/signature.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'login_page.dart';
import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'dart:async';
// import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/messages_page.dart';
import '../pages/notif_page.dart';
import '../menu/profile_view_page.dart';
import 'package:flutter/services.dart';

import '../menu/doctor_menu/call_detail_page.dart';
import '../constants/app_constants.dart';

final logger = Logger();

String sanitizeEmail(String email) {
  return email.replaceAll(RegExp(r'[.@]'), '_');
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

List<String> toolAssets = [];
bool toolsScanned = false;
bool _isHeaderCollapsed = false;
bool _isTimedIn = false; 
Map<String, Map<String, bool>> doctorChecklistStates = {};
Map<int, bool> checkedStates = {};

// SAMPLES TO BRING
  Future<List<Map<String, dynamic>>> getTodaySamplesFlat(
    String emailKey,
    String userName,
    String userClientType,
  ) async {
    if (emailKey.isEmpty) return [];

    final DateTime now = DateTime.now();
    // visitId used in CallSignaturePage: scheduledVisitId = yyyyMMdd
    final String todayVisitId =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'; // yyyyMMdd

    final firestore = FirebaseFirestore.instance;

    // Match CallSignaturePage._getClientSegment
    String _getClientSegment(String userClientType, String userEmail) {
      if (userClientType == 'farmers') return 'INDOFIL';
      if (userClientType == 'pharma') {
        final lower = userEmail.toLowerCase();
        if (lower.endsWith('@wert.com')) return 'WERT';
        return 'IVA';
      }
      return 'IVA';
    }

    // emailKey here is your sanitized email; restore to get the real email
    final String userEmail = emailKey.replaceAll('_', '.');
    final String segment = _getClientSegment(userClientType, userEmail);

    // We need the MR code used in CallSignaturePage (_userId, e.g. MR00001).
    // Assuming you stored it in SharedPreferences as 'userId' and
    // loaded it into a field like `mrCode` on this page.
    final prefs = await SharedPreferences.getInstance();
    final String mrCode = prefs.getString('userId') ?? '';
    if (mrCode.isEmpty) return [];

    // Mirror CallSignaturePage._doctorDocRef:
    // /DaloyClients/{SEGMENT}/Users/{MR00001}/Doctor/{doctorId}
    final doctorsCollection = firestore
        .collection('DaloyClients')
        .doc(segment)
        .collection('Users')
        .doc(mrCode)
        .collection('Doctor');

    final doctorsSnap = await doctorsCollection.get();

    if (doctorsSnap.docs.isEmpty) return [];

    final List<Map<String, dynamic>> result = [];

    for (final doc in doctorsSnap.docs) {
      final docData = doc.data() as Map<String, dynamic>;
      final String doctorName =
          "${docData['lastName'] ?? ''}, ${docData['firstName'] ?? ''}".trim();

      // SampleAllocations document (same as CallSignaturePage._sampleAllocationsDocRef):
      // /Doctor/{doctorId}/SampleAllocations/{visitId}
      final sampleAllocDocRef =
          doc.reference.collection('SampleAllocations').doc(todayVisitId);

      final sampleAllocDoc = await sampleAllocDocRef.get();
      if (!sampleAllocDoc.exists) continue;

      final data = sampleAllocDoc.data() as Map<String, dynamic>? ?? {};

      // Read sampleAllocations map: e.g. { Maxilizer: 1, ... }
      if (!data.containsKey('sampleAllocations')) continue;

      final Map<String, dynamic> allocMap =
          Map<String, dynamic>.from(data['sampleAllocations'] as Map);

      allocMap.forEach((sampleName, qtyRaw) {
        final int qty =
            qtyRaw is int ? qtyRaw : int.tryParse(qtyRaw.toString()) ?? 0;

        if (qty <= 0) return;

        result.add({
          'sample': sampleName, // e.g. "Maxilizer"
          'qty': qty, // e.g. 1
          'doctorName': doctorName,
          'doctorId': doc.id,
          'scheduledDate': todayVisitId, // yyyyMMdd
        });
      });
    }

    // Optional: sort by sample then doctor name
    result.sort((a, b) {
      final sa = (a['sample'] ?? '').toString();
      final sb = (b['sample'] ?? '').toString();
      final da = (a['doctorName'] ?? '').toString();
      final db = (b['doctorName'] ?? '').toString();
      final c1 = sa.compareTo(sb);
      if (c1 != 0) return c1;
      return da.compareTo(db);
    });

    return result;
  }

// CALL PERFORMANCE STATS

// MONTHLY CALL PERFORMANCE
Future<Map<String, int>> _getAccomplishedVisitsForMonth(
    String emailKey, String userName) async {
  final now = DateTime.now();
  final String monthPrefix =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  int totalCount = 0;
  int accomplishedCount = 0;

  final doctorSnapshot = await FirebaseFirestore.instance
      .collection('flowDB')
      .doc('users')
      .collection(emailKey)
      .doc('doctors')
      .collection('doctors')
      .get();

  for (var doc in doctorSnapshot.docs) {
    var scheduledVisitsSnap =
        await doc.reference.collection('scheduledVisits').get();

    for (var v in scheduledVisitsSnap.docs) {
      final visitData = v.data();
      final visitDateString = visitData['scheduledDate'] ?? '';
      if (visitDateString.startsWith(monthPrefix)) {
        totalCount += 1;
        if (visitData.containsKey('signaturePoints') &&
            visitData['signaturePoints'] != null &&
            (visitData['signaturePoints'] as List).isNotEmpty) {
          accomplishedCount += 1;
        }
      }
    }
  }
  return {
    "total": totalCount,
    "accomplished": accomplishedCount,
  };
}

// Call Reach
Future<Map<String, dynamic>> _getCallReachStats(
    String emailKey, String userName) async {
  final doctorsSnap = await FirebaseFirestore.instance
      .collection('flowDB')
      .doc('users')
      .collection(emailKey)
      .doc('doctors')
      .collection('doctors')
      .get();

  int totalDoctors = doctorsSnap.docs.length;
  int visitedDoctors = 0;

  for (final doc in doctorsSnap.docs) {
    final scheduledSnapshots =
        await doc.reference.collection('scheduledVisits').get();

    bool hasSignaturePoints = false;

    for (final visit in scheduledSnapshots.docs) {
      final visitData = visit.data();
      if (visitData.containsKey('signaturePoints') &&
          visitData['signaturePoints'] != null &&
          (visitData['signaturePoints'] as List).isNotEmpty) {
        hasSignaturePoints = true;
        break;
      }
    }

    if (hasSignaturePoints) visitedDoctors++;
  }

  double callReach = 0.0;
  if (totalDoctors > 0) {
    callReach = (visitedDoctors / totalDoctors) * 100.0;
  }

  return {
    'callReach': callReach,
    'totalDoctors': totalDoctors,
    'visitedDoctors': visitedDoctors,
  };
}

// Call Frequency
Future<Map<String, dynamic>> _getCallFrequencyStats(
    String emailKey, String userName) async {
  final now = DateTime.now();
  final String monthPrefix =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';

  final doctorsSnap = await FirebaseFirestore.instance
      .collection('flowDB')
      .doc('users')
      .collection(emailKey)
      .doc('doctors')
      .collection('doctors')
      .get();

  int totalDoctors = doctorsSnap.docs.length;
  int completedFrequency = 0;

  for (final doc in doctorsSnap.docs) {
    final scheduledVisitsSnap =
        await doc.reference.collection('scheduledVisits').get();

    final thisMonthVisits = scheduledVisitsSnap.docs.where((v) {
      final visitData = v.data();
      final visitDateString = visitData['scheduledDate'] ?? '';
      return visitDateString.startsWith(monthPrefix);
    }).toList();

    if (thisMonthVisits.isEmpty) continue;

    bool allVisited = thisMonthVisits.every((visit) {
      final visitData = visit.data();
      return visitData.containsKey('signaturePoints') &&
          visitData['signaturePoints'] != null &&
          (visitData['signaturePoints'] as List).isNotEmpty;
    });

    if (allVisited) completedFrequency++;
  }

  double frequencyPercent = 0.0;
  if (totalDoctors > 0) {
    frequencyPercent = (completedFrequency / totalDoctors) * 100.0;
  }
  return {
    'frequencyPercent': frequencyPercent,
    'totalDoctors': totalDoctors,
    'completedFrequency': completedFrequency,
  };
}

class _DonutPainter extends CustomPainter {
  final double progress; // 0.0 â€“ 1.0
  final Color color;
  final double strokeWidth;
  final Color backgroundColor;

  _DonutPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // full grey ring
    canvas.drawArc(
      rect,
      -3.1415926 / 2,
      2 * 3.1415926,
      false,
      bgPaint,
    );

    final Paint fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final double sweep = 2 * 3.1415926 * progress.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(
        rect,
        -3.1415926 / 2,
        sweep,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _HomePageState extends State<HomePage> {
  Uint8List? signature;
  MapController? _mapController;
// bool _isHeaderCollapsed = false; 

  String userName = '';
  String userEmail = '';
  String emailKey = '';
  String _userId = '';
  bool _hasSubmittedSignature = false;
  bool _isLoading = true;
  String userClientType = ''; // 'pharma', 'farmers', or legacy/other

  int _selectedIndex = 0;
  bool _isOffline = false;

  // Loading progress for signature submission
  bool _isSubmittingSignature = false;

  // Unplanned Visit form controllers
  final TextEditingController _unplannedDoctorNameController =
      TextEditingController();
  final TextEditingController _unplannedLocationController =
      TextEditingController();
  final TextEditingController _unplannedStartTimeController =
      TextEditingController();
  final TextEditingController _unplannedEndTimeController =
      TextEditingController();
  final TextEditingController _unplannedPreCallPlanController =
      TextEditingController();
  final List<TextEditingController> _unplannedProductControllers = [];
  final List<TextEditingController> _unplannedQuantityControllers = [];
  final GlobalKey<FormState> _unplannedFormKey = GlobalKey<FormState>();

  final _doctorNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  final _preCallPlanController = TextEditingController();

  // Controllers for Add New Client
final _firstNameController = TextEditingController();
final _lastNameController = TextEditingController();
final _middleNameController = TextEditingController();
final _birthDateController = TextEditingController();
final _specialtyController = TextEditingController();
final _contactNumberController = TextEditingController();
final _emailController = TextEditingController();
final _hospitalClinicController = TextEditingController();
final _frequencyController = TextEditingController();
final ScrollController _doctorsScrollController = ScrollController();

// Gender dropdown state
String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openSignatureDialog();
    });

    // initialize with one product row
    _addUnplannedProductRow();
  }

  @override
  void dispose() {
    _mapController?.dispose();

    _unplannedDoctorNameController.dispose();
    _unplannedLocationController.dispose();
    _unplannedStartTimeController.dispose();
    _unplannedEndTimeController.dispose();
    _unplannedPreCallPlanController.dispose();
    for (final c in _unplannedProductControllers) {
      c.dispose();
    }
    for (final c in _unplannedQuantityControllers) {
      c.dispose();
    }
    _doctorsScrollController.dispose();

    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  // simple network check
  Future<bool> _hasNetwork() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    String storedEmail = prefs.getString('userEmail') ?? '';
    String storedName = prefs.getString('userName') ?? '';
    String storedClientType = prefs.getString('userClientType') ?? '';
    String fetchEmailKey = storedEmail.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
    String storedUserId = prefs.getString('userId') ?? '';

    bool online = await _hasNetwork();
    bool wentOffline = !online;

    if ((storedName.isEmpty || storedClientType.isEmpty) &&
        storedEmail.isNotEmpty &&
        online) {
      try {
        final userDocs = await FirebaseFirestore.instance
            .collection('flowDB')
            .doc('users')
            .collection(fetchEmailKey)
            .get();

        for (var doc in userDocs.docs) {
          final data = doc.data();
          if (data.containsKey('name') && storedName.isEmpty) {
            storedName = data['name'] ?? '';
            await prefs.setString('userName', storedName);
          }
          if (data.containsKey('clientType') && storedClientType.isEmpty) {
            storedClientType = data['clientType']?.toString() ?? '';
            await prefs.setString('userClientType', storedClientType);
          }
        }
      } catch (e) {
        print('Error fetching user profile: $e');
        wentOffline = true;
      }
    }

    setState(() {
      userEmail = storedEmail;
      userName = storedName;
      emailKey = storedEmail.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
      userClientType = storedClientType;
      _userId = storedUserId; // MR00001
      _hasSubmittedSignature =
          prefs.getBool('hasSubmittedSignature') ?? false;
      _isLoading = false;
      _isOffline = wentOffline;
    });
  }
  
  Future<bool?> _openTimeInDialog() async {
    Position? position;
    bool _isSubmittingTimeIn = false;
    final SignatureController timeInSignatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    position = await _getCurrentLocation();

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final String currentTimeString =
                TimeOfDay.fromDateTime(DateTime.now()).format(dialogContext);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1F1B2E).withOpacity(0.95),
                          const Color(0xFF2E2950).withOpacity(0.95),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      // Header row
      Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(6),
            child: const Icon(
              Icons.access_time,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Confirm Time In',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close,
              color: Colors.white70,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
          ),
        ],
      ),
      const SizedBox(height: 12),

      // Current time
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.schedule,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Text(
              'Current Time:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              currentTimeString,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // Location map
      Container(
        height: MediaQuery.of(dialogContext).size.height * 0.22,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: position != null
              ? FlutterMap(
                  mapController: _mapController ?? MapController(),
                  options: MapOptions(
                    initialCenter: LatLng(
                      position!.latitude,
                      position!.longitude,
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
                  color: Colors.white.withOpacity(0.05),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Getting your location...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () async {
                            Position? newPosition =
                                await _getCurrentLocation();
                            setDialogState(() {
                              position = newPosition;
                            });
                          },
                          child: const Text(
                            'Retry',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      
      ),
      const SizedBox(height: 10),

      if (position != null)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          child: FutureBuilder<String>(
            future: _getAddressFromCoordinates(position!),
            builder: (context, snapshot) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      snapshot.data ?? 'Getting address...',
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
              );
            },
          ),
        ),
      if (position != null) const SizedBox(height: 10),

      // Signature pad
      Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withOpacity(0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Signature(
            controller: timeInSignatureController,
            width: double.infinity,
            height: 200,
            backgroundColor: Colors.white,
          ),
        ),
      ),
      const SizedBox(height: 8),

      // Clear / Undo buttons
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: () => timeInSignatureController.clear(),
            icon: const Icon(
              Icons.clear,
              size: 18,
              color: Colors.white,
            ),
            label: const Text(
              'Clear',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => timeInSignatureController.undo(),
            icon: const Icon(
              Icons.undo,
              size: 18,
              color: Colors.white,
            ),
            label: const Text(
              'Undo',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.orange.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),

      if (_isSubmittingTimeIn)
        Column(
          children: [
            LinearProgressIndicator(
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFf7ad01),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Submitting time in...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),

      // Action buttons
      Row(
        children: [
          // Cancel button
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.black.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.2,
                    ),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Confirm Time In button
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _isSubmittingTimeIn
                    ? null
                    : () async {
                        if (timeInSignatureController.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please provide your signature before confirming time in.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setDialogState(() {
                          _isSubmittingTimeIn = true;
                        });

                        try {
                          // Get current time and location
                          final DateTime now = DateTime.now();
                          final String timestamp = now.toIso8601String();
                          final Position? latestPosition =
                              await _getCurrentLocation();

                          // Prepare Firestore data (current time + location only)
                          final Map<String, dynamic> timeInData = {
                            'type': 'time_in',
                            'timestamp': timestamp,
                            'created_at': FieldValue.serverTimestamp(),
                            'date_only': DateTime(now.year, now.month, now.day),
                            'device_time': now.toIso8601String(),
                            'location': latestPosition != null
                                ? {
                                    'lat': latestPosition.latitude,
                                    'lng': latestPosition.longitude,
                                    'address': await _getAddressFromCoordinates(latestPosition),
                                  }
                                : null,
                            'user_id': FirebaseAuth.instance.currentUser?.uid,
                          };

                          // Save to Firestore
                          await FirebaseFirestore.instance
                              .collection('time_records')
                              .add(timeInData);

                          final String locationInfo =
                              latestPosition != null
                                  ? '\nLocation: ${await _getAddressFromCoordinates(latestPosition)}'
                                  : '\nLocation: Not available';

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Time In recorded!\nTimestamp: $timestamp$locationInfo',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );

                          Navigator.of(dialogContext).pop(true);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to save time in: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          setDialogState(() {
                            _isSubmittingTimeIn = false;
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.black.withOpacity(0.5),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Ink(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF4e2f80),
                        Color(0xFF715999),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: const Text(
                      'Confirm Time In',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
    
  Future<bool?> _openTimeOutDialog() async {
  Position? position;
  bool _isSubmittingTimeOut = false;

  position = await _getCurrentLocation();

  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final String currentTimeString =
              TimeOfDay.fromDateTime(DateTime.now()).format(dialogContext);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1F1B2E).withOpacity(0.95),
                        const Color(0xFF2E2950).withOpacity(0.95),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.logout,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Confirm Time Out',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              Navigator.of(dialogContext).pop(false);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Warning text
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.4),
                          ),
                        ),
                        child: const Text(
                          'Are you sure you want to clock out? This will end your current field session.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Current time
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Current Time:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currentTimeString,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Location map
                      Container(
                        height: MediaQuery.of(dialogContext).size.height * 0.22,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: position != null
                              ? FlutterMap(
                                  mapController: _mapController ?? MapController(),
                                  options: MapOptions(
                                    initialCenter: LatLng(
                                      position!.latitude,
                                      position!.longitude,
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
                                  color: Colors.white.withOpacity(0.05),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Getting your location...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextButton(
                                          onPressed: () async {
                                            Position? newPosition =
                                                await _getCurrentLocation();
                                            setDialogState(() {
                                              position = newPosition;
                                            });
                                          },
                                          child: const Text(
                                            'Retry',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (position != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: FutureBuilder<String>(
                            future: _getAddressFromCoordinates(position!),
                            builder: (context, snapshot) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      snapshot.data ?? 'Getting address...',
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
                              );
                            },
                          ),
                        ),
                      if (position != null) const SizedBox(height: 12),

                      if (_isSubmittingTimeOut)
                        Column(
                          children: [
                            LinearProgressIndicator(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.redAccent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Submitting time out...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),

                      // Action buttons
                      Row(
                        children: [
                          // Cancel (grey floating)
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(dialogContext).pop(false);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.withOpacity(0.2),
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shadowColor: Colors.black.withOpacity(0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Confirm Time Out (red gradient floating)
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: _isSubmittingTimeOut
                                    ? null
                                    : () async {
                                        setDialogState(() {
                                          _isSubmittingTimeOut = true;
                                        });

                                        final DateTime now = DateTime.now();
                                        final String timestamp =
                                            now.toIso8601String();
                                        final Position? latestPosition =
                                            await _getCurrentLocation();

                                        // TODO: Save Time Out record here
                                        // using timestamp and latestPosition.

                                        String locationInfo =
                                            latestPosition != null
                                                ? '\nLocation: ${await _getAddressFromCoordinates(latestPosition)}'
                                                : '\nLocation: Not available';

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Time Out recorded!\nTimestamp: $timestamp$locationInfo',
                                            ),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );

                                        setDialogState(() {
                                          _isSubmittingTimeOut = false;
                                        });

                                        Navigator.of(dialogContext).pop(true);
                                      },
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.black.withOpacity(0.5),
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Ink(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFD32F2F),
                                        Color(0xFFFF5252),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(12),
                                    ),
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Confirm Time Out',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

  Future<void> _saveSignatureOffline(
    List<Point> points,
    String timestamp,
    Position? position,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final List<Map<String, dynamic>> signaturePoints = points.map((point) {
      return {
        'x': point.offset.dx,
        'y': point.offset.dy,
        'pressure': point.pressure,
        'type': point.type.toString(),
      };
    }).toList();

    final Map<String, dynamic> payload = {
      'points': signaturePoints,
      'timestamp': timestamp,
      'hasPosition': position != null,
      'lat': position?.latitude,
      'lng': position?.longitude,
      'accuracy': position?.accuracy,
    };

    await prefs.setString('pendingSignature', jsonEncode(payload));

    setState(() {
      _hasSubmittedSignature = true; // allow user to proceed
    });
  }

  Future<List<Map<String, dynamic>>> getAllScheduledVisitsForToday({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> doctorDocs,
    required DateTime selectedDay,
  }) async {
    // If there are no doctors, nothing to do.
    if (doctorDocs.isEmpty) return [];

    final List<Map<String, dynamic>> allVisits = [];

    // Today formatted as "yyyyMMdd" to match VisitsTab and Daloy Visit docs.
    final String targetDateKey = DateFormat('yyyyMMdd').format(selectedDay); // [web:9]

    for (final doc in doctorDocs) {
      final Map<String, dynamic> docData = doc.data();
      final String doctorId = docData['doc_id']?.toString() ?? doc.id;
      final String doctorName =
          "${docData['lastName'] ?? ''}, ${docData['firstName'] ?? ''}";

      final String hospital = (docData['hospital'] ?? '').toString();
      final String specialty = (docData['specialty'] ?? '').toString();

      // New structure:
      // /DaloyClients/{segment}/Users/{_userId}/Doctor/{docId}/Visits/{yyyyMMdd}
      final visitsColRef = doc.reference.collection('Visits');

      // Only visits scheduled for today:
      // scheduledDate == targetDateKey ("yyyyMMdd"), order by scheduledTime string.[web:1][web:5]
      final QuerySnapshot<Map<String, dynamic>> visitsSnap =
          await visitsColRef
              .where('scheduledDate', isEqualTo: targetDateKey)
              .orderBy('scheduledTime')
              .get();

      for (final v in visitsSnap.docs) {
        final Map<String, dynamic> visitData = v.data();

        // Field or doc id (yyyyMMdd), similar to VisitsTab.
        final String scheduledDateRaw =
            (visitData['scheduledDate'] ?? v.id).toString();

        // Defensive check: skip if not exactly today.
        if (scheduledDateRaw != targetDateKey) continue;

        final String scheduledTime =
            (visitData['scheduledTime'] ?? '').toString();

        allVisits.add({
          'doctorName': doctorName,
          'scheduledTime': scheduledTime,
          'hospital': hospital,
          'specialty': specialty,
          'doctor': docData,
          'doctorId': doctorId,
          'visitId': v.id,       // yyyyMMdd
          'visitData': visitData,
        });
      }
    }

    // Safety: final sort by time string (HH:mm).[web:1]
    allVisits.sort(
      (a, b) => (a['scheduledTime'] ?? '').compareTo(b['scheduledTime'] ?? ''),
    );

    return allVisits;
  }

  Future<Map<String, int>> getAccomplishedVisitsForToday(
      String emailKey, String userName) async {
    final String todayKey =
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    int totalCount = 0;
    int accomplishedCount = 0;

    final doctorSnapshot = await FirebaseFirestore.instance
        .collection('flowDB')
        .doc('users')
        .collection(emailKey)
        .doc('doctors')
        .collection('doctors')
        .get(); 

    for (var doc in doctorSnapshot.docs) {
      var scheduledVisitsSnap =
          await doc.reference.collection('scheduledVisits').get();
      for (var v in scheduledVisitsSnap.docs) {
        final visitData = v.data();
        final visitDateString = visitData['scheduledDate'] ?? '';
        if (visitDateString == todayKey) {
          totalCount += 1;
          if (visitData.containsKey('signaturePoints') &&
              visitData['signaturePoints'] != null &&
              (visitData['signaturePoints'] as List).isNotEmpty) {
            accomplishedCount += 1;
          }
        }
      }
    }
    return {
      "total": totalCount,
      "accomplished": accomplishedCount,
    };
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _isLoading = true;
    });

    // 1) Background connectivity check
    final bool online = await _hasNetwork();

    if (online) {
      // 2a) Firestore back online so futures hit the server and sync cache
      try {
        await FirebaseFirestore.instance.enableNetwork(); // background sync
      } catch (e) {
        print('Error enabling Firestore network: $e');
      }

      setState(() {
        _isOffline = false;
      });
    } else {
      // 2b) Still offline: just set the flag, don't disable network
      // This allows Firestore to serve from cache
      setState(() {
        _isOffline = true;
      });
    }

    // 3) Reload user/dashboard data (will read from server if online, cache if offline)
    await _loadUserData();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('userEmail');
      if (userEmail != null && userEmail.isNotEmpty) {
        final emailKey =
            userEmail.replaceAll(RegExp(r'[.#$\[\]/]'), '_');

        try {
          final docsSnap = await FirebaseFirestore.instance
              .collection('flowDB')
              .doc('users')
              .collection(emailKey)
              .get();

          for (final doc in docsSnap.docs) {
            await doc.reference.update({
              'isActive': false,
              'lastLogout': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          // If offline at sign-out, skip Firestore update but still clear local state
          print('Sign-out Firestore update failed (offline?): $e');
        }
      }

      await prefs.remove('isLoggedIn');
      await prefs.remove('userEmail');
      await prefs.remove('userName');
      await prefs.remove('userId');
      await prefs.remove('territoryId');
      await prefs.remove('loginTimestamp');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signed out successfully'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error signing out. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleDrawerItemTap(String title, String route) {
    Navigator.pop(context);
    if (route == '/profile') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileViewPage(
            userName: userName,
            userEmail: userEmail,
          ),
        ),
      );
      return;
    }
    if (route == '/home') {
      return;
    }
    Navigator.pushNamed(context, route);
  }

  Future<bool> _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
    }
    return status.isGranted;
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      print('Checking location permission...');
      bool hasPermission = await _requestLocationPermission();
      if (!hasPermission) {
        print('Location permission denied');
        return null;
      }
      print('Location permission granted');

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }
      print('Location services are enabled');

      print('Getting current position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print(
          'Location obtained: ${position.latitude}, ${position.longitude}');
      print('Accuracy: ${position.accuracy}m');
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  bool _isAddPressed = false; // put this above in the StatefulBuilder scope if not yet declared
  Future<void> _openSignatureDialog() async {
    final SignatureController dialogController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    Position? position = await _getCurrentLocation();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return WillPopScope(
              onWillPop: () async => false,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF5958b2),
                            Color(0xFF5958b2),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: BackdropFilter(
                      filter:
                          ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Dialog(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        child: Container(
                          width:
                              MediaQuery.of(context).size.width * 0.95,
                          height:
                              MediaQuery.of(context).size.height * 0.85,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius:
                                BorderRadius.circular(24),
                            border: Border.all(
                              color:
                                  Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(20),
                          
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                SizedBox(height: 8),
                                Text(
                                  'Digital Signature Required',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black
                                            .withOpacity(0.3),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 16),
                                Container(
                                  height: MediaQuery.of(context)
                                          .size
                                          .height *
                                      0.32,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withOpacity(0.2),
                                    border: Border.all(
                                      color: Colors.white
                                          .withOpacity(0.4),
                                      width: 2,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withOpacity(0.2),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: position != null
                                        ? FlutterMap(
                                            mapController: _mapController ?? MapController(),
                                            options: MapOptions(
                                              initialCenter: LatLng(
                                                position!.latitude,
                                                position!.longitude,
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
                                            color: Colors.white.withOpacity(0.1),
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const CircularProgressIndicator(
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                    'Getting your location...',
                                                    style: TextStyle(color: Colors.white),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  TextButton(
                                                    onPressed: () async {
                                                      Position? newPosition = await _getCurrentLocation();
                                                      setDialogState(() {
                                                        position = newPosition;
                                                      });
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
                                SizedBox(height: 12),
                                if (position != null)
                                  Container(
                                    padding:
                                        EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withOpacity(0.2),
                                      borderRadius:
                                          BorderRadius.circular(
                                              8),
                                      border: Border.all(
                                        color: Colors.white
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    child:
                                        FutureBuilder<String>(
                                      future:
                                          _getAddressFromCoordinates(
                                              position!),
                                      builder: (context,
                                          snapshot) {
                                        return Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                snapshot.data ??
                                                    'Getting address...',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors
                                                      .white,
                                                  fontWeight:
                                                      FontWeight
                                                          .w500,
                                                ),
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  height: 250,
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withOpacity(0.9),
                                    border: Border.all(
                                      color: Colors.white
                                          .withOpacity(0.5),
                                      width: 2,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(
                                            12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withOpacity(0.2),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(
                                            10),
                                    child: Signature(
                                      controller:
                                          dialogController,
                                      width: double.infinity,
                                      height: 250,
                                      backgroundColor:
                                          Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceEvenly,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () =>
                                          dialogController
                                              .clear(),
                                      icon: Icon(
                                          Icons.clear,
                                          size: 18,
                                          color:
                                              Colors.white),
                                      label: Text(
                                        'Clear',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors
                                                .white),
                                      ),
                                      style:
                                          TextButton.styleFrom(
                                        backgroundColor: Colors
                                            .red
                                            .withOpacity(
                                                0.3),
                                        padding: EdgeInsets
                                            .symmetric(
                                                horizontal:
                                                    20,
                                                vertical:
                                                    10),
                                        shape:
                                            RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                                      10),
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          dialogController
                                              .undo(),
                                      icon: Icon(
                                          Icons.undo,
                                          size: 18,
                                          color:
                                              Colors.white),
                                      label: Text(
                                        'Undo',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors
                                                .white),
                                      ),
                                      style:
                                          TextButton.styleFrom(
                                        backgroundColor: Colors
                                            .orange
                                            .withOpacity(
                                                0.3),
                                        padding: EdgeInsets
                                            .symmetric(
                                                horizontal:
                                                    20,
                                                vertical:
                                                    10),
                                        shape:
                                            RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                                      10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                if (_isSubmittingSignature)
                                  Column(
                                    children: [
                                      LinearProgressIndicator(
                                        backgroundColor: Colors.white.withOpacity(0.3),
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFf7ad01)),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Submitting signature...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                    ],
                                  ),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSubmittingSignature ? null : () async {
                                      if (dialogController.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Please provide your signature before submitting.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }

                                      setDialogState(() {
                                        _isSubmittingSignature = true;
                                      });

                                      final points = dialogController.points;
                                      final timestamp = DateTime.now().toIso8601String();
                                      final position = await _getCurrentLocation();

                                      // Let _saveSignatureToFirestore decide whether to go online or offline
                                      await _saveSignatureToFirestore(points, timestamp, position);

                                      setState(() {
                                        _hasSubmittedSignature = true;
                                      });

                                      String locationInfo = position != null
                                          ? '\nLocation: ${await _getAddressFromCoordinates(position)}'
                                          : '\nLocation: Not available';

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            _isOffline
                                                ? 'Signature stored offline and will sync when online.\nTimestamp: $timestamp$locationInfo'
                                                : 'Signature saved successfully!\nTimestamp: $timestamp$locationInfo',
                                          ),
                                          backgroundColor: _isOffline ? Colors.orange : Colors.green,
                                        ),
                                      );

                                      setDialogState(() {
                                        _isSubmittingSignature = false;
                                      });

                                      Navigator.of(context).pop(); // always close dialog so it proceeds
                                    },
                                    style: ElevatedButton
                                        .styleFrom(
                                      backgroundColor: _isSubmittingSignature
                                          ? Colors.grey.withOpacity(0.3)
                                          : Colors.white.withOpacity(0.3),
                                      foregroundColor:
                                          Colors.white,
                                      padding: EdgeInsets
                                          .symmetric(
                                              vertical:
                                                  14),
                                      shape:
                                          RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                                    12),
                                        side: BorderSide(
                                          color: Colors
                                              .white
                                              .withOpacity(
                                                  0.5),
                                          width: 2,
                                        ),
                                      ),
                                      elevation: 5,
                                      shadowColor: Colors
                                          .black
                                          .withOpacity(
                                              0.3),
                                    ),
                                    child: Text(
                                      _isSubmittingSignature ? 'Submitting...' : 'Submit Signature',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                        letterSpacing:
                                            0.5,
                                      ),
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
              ),
            );
          },
        );
      },
    );
  }

  Future<String> _getAddressFromCoordinates(
      Position position) async {
    try {
      List<geocoding.Placemark> placemarks =
          await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        geocoding.Placemark place = placemarks[0];
        return '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}';
      }
      return 'Address not found';
    } catch (e) {
      print('Error getting address: $e');
      return 'Error getting address';
    }
  }

/// Base Doctor collection for this MR in Daloy:
/// /DaloyClients/{segment}/Users/{_userId}/Doctor/{docId}
CollectionReference<Map<String, dynamic>> _doctorCollectionRefForHome({
  required String userClientType,
  required String userId, // MR00001
}) {
  final daloyRoot = FirebaseFirestore.instance.collection('DaloyClients');

  String clientSegment;
  if (userClientType == 'farmers') {
    clientSegment = 'INDOFIL';
  } else if (userClientType == 'pharma') {
    clientSegment = 'IVA';
  } else {
    clientSegment = 'GENERAL';
  }

  final userDocRef =
      daloyRoot.doc(clientSegment).collection('Users').doc(userId);

  return userDocRef.collection('Doctor');
}

  Future<void> _saveSignatureToFirestore(
    List<Point> points,
    String timestamp,
    Position? position,
  ) async {
    try {
      if (userEmail.isEmpty) {
        throw Exception('User email missing');
      }

      String address = position != null
          ? await _getAddressFromCoordinates(position)
          : 'Location not available';

      final List<Map<String, dynamic>> signaturePoints = points.map((point) {
        return {
          'x': point.offset.dx,
          'y': point.offset.dy,
          'pressure': point.pressure,
          'type': point.type.toString(),
        };
      }).toList();

      Map<String, dynamic> signatureData = {
        'userEmail': userEmail,
        'userName': userName,
        'timestamp': timestamp,
        'createdAt': FieldValue.serverTimestamp(),
        'signaturePoints': signaturePoints,
        'address': address,
      };

      if (position != null) {
        signatureData['location'] = {
          'address': address,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'altitude': position.altitude,
          'heading': position.heading,
          'speed': position.speed,
          'speedAccuracy': position.speedAccuracy,
          'timestamp': DateTime.now().toIso8601String(),
        };
        signatureData['hasLocation'] = true;
      }

      String docId = '${userEmail}_$timestamp';

      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('signatures')
          .collection('signatures')
          .doc(docId)
          .set(signatureData);

      print('âœ“ Vector signature saved successfully');
    } catch (e) {
      // Instead of throwing, cache offline and let user proceed
      print('âœ— Error saving signature (probably offline): $e');
      await _saveSignatureOffline(points, timestamp, position);
    }
  }

  // ===== UNPLANNED VISIT HELPERS =====

  void _addUnplannedProductRow() {
    final productController = TextEditingController();
    final quantityController = TextEditingController();
    _unplannedProductControllers.add(productController);
    _unplannedQuantityControllers.add(quantityController);
  }

  Future<void> _pickTimeForController(
      TextEditingController controller) async {
    final TimeOfDay now = TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: now,
    );
    if (picked != null) {
      final String formatted =
          picked.format(context); // locale-aware time
      controller.text = formatted;
    }
  }

  void _openUnplannedVisitDialog() {
    // reset form fields
    _unplannedDoctorNameController.clear();
    _unplannedLocationController.clear();
    _unplannedStartTimeController.clear();
    _unplannedEndTimeController.clear();
    _unplannedPreCallPlanController.clear();

    for (final c in _unplannedProductControllers) {
      c.dispose();
    }
    for (final c in _unplannedQuantityControllers) {
      c.dispose();
    }
    _unplannedProductControllers.clear();
    _unplannedQuantityControllers.clear();
    _addUnplannedProductRow();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // HEADER
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 30, // higher header
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4e2f80),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.add,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Add Unplanned Visit',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _unplannedFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Doctor Name heading
                              const Text(
                                'Doctor Name',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _unplannedDoctorNameController,
                                decoration: const InputDecoration(
                                  labelText: 'e.g., Dr John Smith',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter doctor name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Location / Hospital heading
                              const Text(
                                'Location / Hospital',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _unplannedLocationController,
                                decoration: const InputDecoration(
                                  labelText: 'e.g., Manila Medical Center',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter location or hospital';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Start / End Time heading
                              const Text(
                                'Start Time / End Time',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _unplannedStartTimeController,
                                      readOnly: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Select Time',
                                        border: OutlineInputBorder(),
                                        suffixIcon: Icon(Icons.access_time),
                                      ),
                                      onTap: () {
                                        _pickTimeForController(
                                            _unplannedStartTimeController);
                                      },
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Select start time';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _unplannedEndTimeController,
                                      readOnly: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Select Time',
                                        border: OutlineInputBorder(),
                                        suffixIcon: Icon(Icons.access_time),
                                      ),
                                      onTap: () {
                                        _pickTimeForController(
                                            _unplannedEndTimeController);
                                      },
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Select end time';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Products title + Add button on the right
                              Row(
                                children: [
                                  const Text(
                                    'Products',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTapDown: (_) {
                                      setState(() {
                                        _isAddPressed = true;
                                      });
                                    },
                                    onTapUp: (_) {
                                      setState(() {
                                        _isAddPressed = false;
                                      });
                                      _addUnplannedProductRow();
                                    },
                                    onTapCancel: () {
                                      setState(() {
                                        _isAddPressed = false;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 120),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: _isAddPressed
                                            ? null
                                            : const LinearGradient(
                                                colors: [
                                                  Color(0xFF4e2f80),
                                                  Color(0xFF836da6),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                        color: _isAddPressed
                                            ? const Color(0xFF4e2f80) // plain purple when pressed
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.add,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Add',
                                            style: TextStyle(
                                              color: Colors.white, // white text
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                                                            
                              const SizedBox(height: 8),

                              Column(
                                children: List.generate(
                                  _unplannedProductControllers.length,
                                  (index) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: TextFormField(
                                              controller:
                                                  _unplannedProductControllers[
                                                      index],
                                              decoration: const InputDecoration(
                                                labelText: 'Product',
                                                border: OutlineInputBorder(),
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.trim().isEmpty) {
                                                  return 'Enter product';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 2,
                                            child: TextFormField(
                                              controller:
                                                  _unplannedQuantityControllers[
                                                      index],
                                              decoration: const InputDecoration(
                                                labelText: 'Quantity',
                                                border: OutlineInputBorder(),
                                              ),
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              validator: (value) {
                                                if (value == null ||
                                                    value.trim().isEmpty) {
                                                  return 'Enter qty';
                                                }
                                                final n = int.tryParse(value);
                                                if (n == null || n <= 0) {
                                                  return 'Qty must be > 0';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Pre-Call Plan heading
                              const Text(
                                'Pre-Call Plan',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _unplannedPreCallPlanController,
                                decoration: const InputDecoration(
                                  labelText: 'Enter your plan for this visit...',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 3,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter pre-call plan';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Grey Cancel button
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              if (_unplannedFormKey.currentState!.validate()) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Unplanned visit added (not yet wired to Firestore).',
                                    ),
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4e2f80),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            child: const Text('Add Unplanned Visit'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

void _openCreateEFormDialog() {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20, // higher header
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF4e2f80),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: const [
                    Icon(
                      Icons.description_outlined, // document-like icon
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Create New E-Form',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select the type of form you want to create:',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Attendance Form
                      _buildEFormTypeTile(
                        icon: Icons.people_outline,
                        title: 'Attendance Form',
                        subtitle: 'Monitor attendance for your events',
                        color: Colors.deepPurple,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AttendanceFormWebviewPage(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // Sample Crop Prescription Form
                      _buildEFormTypeTile(
                        icon: Icons.grass_outlined,
                        title: 'Sample Crop Prescription Form',
                        subtitle: "Get your farmer's specific crops needed",
                        color: Colors.green.shade700,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ScpFormWebviewPage(),
                            ),
                          );
                        },
                      ),


                      const SizedBox(height: 12),

                      // Activity Budget Request Form
                      _buildEFormTypeTile(
                        icon: Icons.request_page_outlined,
                        title: 'Activity Budget Request Form',
                        subtitle:
                            'Request for Additional Budget for your future needs',
                        color: Colors.orange.shade700,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AbrFormWebviewPage(),
                            ),
                          );
                        },
                      ),


                      const SizedBox(height: 12),

                      // In-Field Coaching Form
                      _buildEFormTypeTile(
                        icon: Icons.school_outlined,
                        title: 'In-Field Coaching Form',
                        subtitle: 'Document coaching sessions and farmer field visits',
                        color: Colors.blue.shade700,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const WebviewInFieldPage(),
                            ),
                          );
                        },
                      ),


                      const SizedBox(height: 12),

                      // Incidental Coverage Form
                      _buildEFormTypeTile(
                        icon: Icons.event_available_outlined,
                        title: 'Incidental Coverage Form',
                        subtitle: 'Record incidental activities and field coverages',
                        color: Colors.teal.shade700,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const IncidentalCoverageFormWebviewPage(),
                            ),
                          );
                        },
                      ),


                      const SizedBox(height: 12),

                      // Sales Order Form
                      _buildEFormTypeTile(
                        icon: Icons.shopping_cart_outlined,
                        title: 'Sales Order Form',
                        subtitle: 'Create and track sales orders for your customers',
                        color: Colors.red.shade700,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const WebviewSalesOrderFormPage(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              Container(
                width: double.infinity,
                color: Colors.grey[200],
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Cancel'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  void _openAddPlannedVisitDialog() {
  _doctorNameController.clear();
  _locationController.clear();
  _startTimeController.clear();
  _endTimeController.clear();
  _productController.clear();
  _quantityController.clear();
  _preCallPlanController.clear();

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF4e2f80),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.add,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Add Planned Visit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Doctor Name title
                      const Text(
                        'Doctor Name',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Doctor Name
                      TextField(
                        controller: _doctorNameController,
                        decoration: const InputDecoration(
                          labelText: 'e.g., Dr. John Smith',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Location / Hospital title
                      const Text(
                        'Location / Hospital',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Location / Hospital
                      TextField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'e.g., Manila Medical Center',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Start Time / End Time titles + fields
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Start Time',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _startTimeController,
                                  readOnly: true,
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: ctx,
                                      initialTime: TimeOfDay.now(),
                                    );
                                    if (picked != null) {
                                      _startTimeController.text =
                                          picked.format(ctx);
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Select Time',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'End Time',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _endTimeController,
                                  readOnly: true,
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: ctx,
                                      initialTime: TimeOfDay.now(),
                                    );
                                    if (picked != null) {
                                      _endTimeController.text =
                                          picked.format(ctx);
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Select Time',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Products / Quantity
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Products',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _productController,
                                  decoration: const InputDecoration(
                                    labelText: 'Products Name',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Pre-Call Plan title
                      const Text(
                        'Pre-Call Plan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Pre-Call Plan
                      TextField(
                        controller: _preCallPlanController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Enter your plan for the visit...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    // Cancel button (grey)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[800],
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Add Planned Visit button (purple gradient)
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            backgroundColor: Colors.transparent,
                          ),
                          onPressed: () {
                            // TODO: Handle save planned visit logic here
                            Navigator.of(ctx).pop();
                          },
                          child: Ink(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF4e2f80),
                                  Color(0xFF715999),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: const Text(
                                'Add Planned Visit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  void _openAddNewClientDialog() {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF4e2f80),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: const Text(
                  'Add New Client',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // First Name / Last Name (1st row)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(
                                labelText: 'First Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(
                                labelText: 'Last Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Middle Name (2nd row)
                      TextField(
                        controller: _middleNameController,
                        decoration: const InputDecoration(
                          labelText: 'Middle Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Birth Date + Gender (3rd row)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _birthDateController,
                              readOnly: true,
                              onTap: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime(now.year - 25),
                                  firstDate: DateTime(1900),
                                  lastDate: now,
                                );
                                if (picked != null) {
                                  _birthDateController.text =
                                      '${picked.year.toString().padLeft(4, '0')}-'
                                      '${picked.month.toString().padLeft(2, '0')}-'
                                      '${picked.day.toString().padLeft(2, '0')}';
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Birth Date',
                                hintText: 'YYYY-MM-DD',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Male',
                                  child: Text('Male'),
                                ),
                                DropdownMenuItem(
                                  value: 'Female',
                                  child: Text('Female'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedGender = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Specialty (4th row)
                      TextField(
                        controller: _specialtyController,
                        decoration: const InputDecoration(
                          labelText: 'Specialty',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Contact Number + Email (4th row continuation)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _contactNumberController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Contact Number',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Hospital / Clinic (5th row)
                      TextField(
                        controller: _hospitalClinicController,
                        decoration: const InputDecoration(
                          labelText: 'Hospital / Clinic',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Frequency of Planned Visits per Month (numeric only, up to 4)
                      TextField(
                        controller: _frequencyController,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        decoration: const InputDecoration(
                          labelText: 'Frequency of Planned Visits per Month',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // Floating buttons inside form
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    // Cancel (grey)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[800],
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Add Client (purple gradient)
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            backgroundColor: Colors.transparent,
                          ),
                          onPressed: () {
                            // TODO: Add validation & save client logic here
                            Navigator.of(ctx).pop();
                          },
                          child: Ink(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF4e2f80),
                                  Color(0xFF715999),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: const Text(
                                'Add Client',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildEFormTypeTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== BODY WITH TABS =====

  Widget _buildHomeDashboard() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    final String todayStr =
        DateFormat('MMMM d, yyyy').format(DateTime.now());
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFdedef0),
            Color(0xFFdedef0),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // STICKY
            // APPBAR EXTENSION
            // WRAP the whole gradient + card in AnimatedSize so the bar can collapse/expand
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4E3385),
                      Color(0xFF514499),
                      Color(0xFF5455AD),
                      Color(0xFF5A6EC4),
                      Color(0xFF6098D9),
                      Color(0xFF67C6ED),                
                    ],
                    stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(50.0),
                    bottomRight: Radius.circular(50.0),
                  ),
                ),
                child: Card(
                  color: Colors.transparent,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // This part collapses (avatar + name/email + right icons)
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              child: _isHeaderCollapsed
                                  ? const SizedBox.shrink()
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        const SizedBox(width: 16),

                                        // Name + email
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _isLoading ? 'Loading...' : userName,
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white70,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _isLoading ? 'Loading...' : userEmail,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.white70,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                        const Spacer(),

                                        // Right-side icons (also hidden when collapsed)
                                        if (_isOffline)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8.0),
                                            child: Row(
                                              children: const [
                                                Icon(
                                                  Icons.cloud_off,
                                                  color: Colors.yellow,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Offline',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        // Mail icon inside grey transparent container
                                        InkWell(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: true,
                                              builder: (ctx) {
                                                return Dialog(
                                                  // 1) Make the whole dialog have rounded corners (all sides)
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  insetPadding: const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 24,
                                                  ),
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      maxHeight: MediaQuery.of(ctx).size.height * 0.8,
                                                      maxWidth: MediaQuery.of(ctx).size.width * 0.9,
                                                    ),
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        // 2) Header no longer sets only top radii; it just uses same radius
                                                        //    so the dialog's shape controls all corners (top & bottom).
                                                        Container(
                                                          width: double.infinity,
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 16,
                                                          ),
                                                          decoration: const BoxDecoration(
                                                            color: Color(0xFF4e2f80),
                                                            borderRadius: BorderRadius.only(
                                                              topLeft: Radius.circular(16),
                                                              topRight: Radius.circular(16),
                                                              bottomLeft: Radius.circular(16),
                                                              bottomRight: Radius.circular(16),
                                                            ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              const Icon(
                                                                Icons.mail_outline,
                                                                color: Colors.white,
                                                                size: 22,
                                                              ),
                                                              const SizedBox(width: 8),
                                                              const Text(
                                                                'Messages',
                                                                style: TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 18,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                              ),
                                                              const Spacer(),
                                                              TextButton.icon(
                                                                onPressed: () {
                                                                  // TODO: hook to your "create new message" flow
                                                                },
                                                                style: TextButton.styleFrom(
                                                                  foregroundColor: Colors.white,
                                                                  backgroundColor: Colors.white.withOpacity(0.15),
                                                                  padding: const EdgeInsets.symmetric(
                                                                    horizontal: 10,
                                                                    vertical: 6,
                                                                  ),
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius: BorderRadius.circular(8),
                                                                  ),
                                                                ),
                                                                icon: const Icon(
                                                                  Icons.add,
                                                                  size: 18,
                                                                  color: Colors.white,
                                                                ),
                                                                label: const Text(
                                                                  'New Message',
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    color: Colors.white,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),

                                                        // 3) Body â€“ by default respects dialog radius at bottom
                                                        const Expanded(
                                                          child: MessagesPage(),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(18),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(28),
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.all(15.0),
                                              child: Icon(
                                                Icons.mail_outline,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 6),

                                        // Notifications icon inside grey transparent container
                                        InkWell(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: true, // tap outside to close
                                              builder: (context) => const NotifPageDialog(),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(18),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(28),
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.all(15.0),
                                              child: Icon(
                                                Icons.notifications_none,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),

                            const SizedBox(height: 8),

                            // "Time In" button (also hidden when header is collapsed)
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              child: _isHeaderCollapsed
                                  ? const SizedBox.shrink()
                                  : Align(
                                      alignment: Alignment.center,
                                      child: InkWell(
                                        onTap: () async {
                                          if (!_isTimedIn) {
                                            // Currently not timed in -> open Time In dialog
                                            final bool? didTimeIn = await _openTimeInDialog();
                                            if (didTimeIn == true) {
                                              setState(() {
                                                _isTimedIn = true;
                                              });
                                            }
                                          } else {
                                            // Already timed in -> open Time Out dialog
                                            final bool? didTimeOut = await _openTimeOutDialog();
                                            if (didTimeOut == true) {
                                              setState(() {
                                                _isTimedIn = false;
                                              });
                                            }
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _isTimedIn
                                                ? Colors.red.withOpacity(0.8) // Time Out state
                                                : Colors.grey.withOpacity(0.3), // Time In state
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _isTimedIn ? 'Time Out' : 'Time In',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            /// Place this method inside the same State class as your button.
                            /// Assumes you already have:
                            /// - Position? position;
                            /// - SignatureController timeInSignatureController;
                            /// - bool _isSubmittingTimeIn = false;
                            /// - Future<Position?> _getCurrentLocation();
                            /// - Future<String> _getAddressFromCoordinates(Position position);
                            /// and you imported `package:signature/signature.dart`, `package:geolocator/geolocator.dart` etc.

                            const SizedBox(height: 8),

                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.all(1), // even smaller padding
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    iconSize: 18,
                                    icon: Icon(
                                      _isHeaderCollapsed
                                          ? Icons.keyboard_arrow_down
                                          : Icons.keyboard_arrow_up,
                                      color: Colors.white70,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isHeaderCollapsed = !_isHeaderCollapsed;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // SCROLLABLE CONTENT
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshDashboard,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.only(left: 0, right: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 12),
                        SizedBox(height: 4),

                        // ===================== SCHEDULED DOCTOR SECTION HEADER =====================
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.0),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double availableWidth = constraints.maxWidth;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            "Scheduled Doctors for Today",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize:
                                                  availableWidth < 360 ? 13 : 15,
                                              color: Color(0xFFf7ad01),
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            todayStr,
                                            style: TextStyle(
                                              fontFamily: 'OpenSauce',
                                              fontWeight: FontWeight.w700,
                                              fontSize:
                                                  availableWidth < 360 ? 15 : 17,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            "Completed Visits",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize:
                                                  availableWidth < 360 ? 13 : 15,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "0/X",
                                          style: TextStyle(
                                            fontFamily: 'OpenSauce',
                                            fontWeight: FontWeight.w700,
                                            fontSize:
                                                availableWidth < 360 ? 15 : 17,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        SizedBox(height: 8),

                        Padding(
                          padding: EdgeInsets.only(left: 20, right: 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // FUTUREBUILDER OF SCHEDULED DOCTORS FOR TODAY
                              FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                future: (() {
                                  // Build the Doctor collection for this MR using the same logic as DoctorDetailPage.[file:11]
                                  final doctorsCol = _doctorCollectionRefForHome(
                                    userClientType: userClientType,
                                    userId: _userId, // MR00001 from SharedPreferences
                                  );

                                  return doctorsCol.get().timeout(
                                    const Duration(seconds: 10),
                                    onTimeout: () {
                                      throw TimeoutException('Failed to load doctors data');
                                    },
                                  );
                                })(),
                                builder: (context, doctorSnapshot) {
                                  if (doctorSnapshot.hasError) {
                                    print('Error loading doctors: ${doctorSnapshot.error}');
                                    return Container(
                                      alignment: Alignment.center,
                                      height: 140,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.error_outline, color: Colors.red, size: 40),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Error loading doctors\n${doctorSnapshot.error}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.red, fontSize: 12),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setState(() {});
                                            },
                                            child: const Text('Retry'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  if (doctorSnapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }

                                  if (!doctorSnapshot.hasData || doctorSnapshot.data!.docs.isEmpty) {
                                    return Container(
                                      alignment: Alignment.center,
                                      height: 140,
                                      child: Text(
                                        _isOffline
                                            ? 'Offline: showing last available data from cache.'
                                            : 'No doctors found.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 14,
                                        ),
                                      ),
                                    );
                                  }

                                  final List<QueryDocumentSnapshot<Map<String, dynamic>>> doctorDocs =
                                      doctorSnapshot.data!.docs;

                                  return FutureBuilder<List<Map<String, dynamic>>>(
                                    future: getAllScheduledVisitsForToday(
                                      doctorDocs: doctorDocs,
                                      selectedDay: DateTime.now(), // today
                                    ).timeout(
                                      const Duration(seconds: 10),
                                      onTimeout: () {
                                        print('Timeout loading scheduled visits');
                                        return <Map<String, dynamic>>[];
                                      },
                                    ),
                                    builder: (context, visitsSnapshot) {
                                      if (visitsSnapshot.hasError) {
                                        print('Error loading visits: ${visitsSnapshot.error}');
                                        return Container(
                                          alignment: Alignment.center,
                                          height: 140,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.error_outline, color: Colors.red, size: 40),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Error loading visits\n${visitsSnapshot.error}',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(color: Colors.red, fontSize: 12),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  setState(() {});
                                                },
                                                child: const Text('Retry'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      if (visitsSnapshot.connectionState == ConnectionState.waiting &&
                                          !visitsSnapshot.hasData) {
                                        return const Center(child: CircularProgressIndicator());
                                      }

                                      if (!visitsSnapshot.hasData || visitsSnapshot.data!.isEmpty) {
                                        return Center(
                                          child: Text(
                                            _isOffline
                                                ? "Offline: showing cached schedule (none cached for today)."
                                                : "No scheduled visits for today.",
                                            textAlign: TextAlign.center,
                                          ),
                                        );
                                      }

                                      final List<Map<String, dynamic>> visitsForDay =
                                          visitsSnapshot.data!;

                                      // This uses your existing UI: purple next card, visited borders, auto-scroll, etc.
                                      return _buildScheduledDoctorsRow(visitsForDay);
                                    },
                                  );
                                },
                              ),
                              
                              SizedBox(height: 12),

                              // SAMPLES TO BRING SECTION

                              Padding(
                                padding: EdgeInsets.only(left: 20),
                                child: Text(
                                  "Samples to Bring",
                                  style: TextStyle(
                                    fontFamily: 'Lato',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),

                              Padding(
                                padding: EdgeInsets.only(left: 1, top: 12, right: 0, bottom: 10),
                                child: FutureBuilder<List<Map<String, dynamic>>>(
                                  future: getTodaySamplesFlat(emailKey, userName, userClientType).timeout(
                                    Duration(seconds: 10),
                                    onTimeout: () {
                                      print('Timeout loading samples');
                                      return <Map<String, dynamic>>[];
                                    },
                                  ),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      print('Error loading samples: ${snapshot.error}');
                                      return Container(
                                        padding: EdgeInsets.all(16),
                                        child: Column(
                                          children: [
                                            Icon(Icons.error_outline, color: Colors.red, size: 30),
                                            SizedBox(height: 8),
                                            Text(
                                              'Error loading samples\n${snapshot.error}',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: Colors.red, fontSize: 12),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                setState(() {});
                                              },
                                              child: Text('Retry'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    if (snapshot.connectionState == ConnectionState.waiting &&
                                        !snapshot.hasData) {
                                      return Center(child: CircularProgressIndicator());
                                    }

                                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                      return Text(
                                        _isOffline
                                            ? "Offline: showing cached samples (none cached for today)."
                                            : "No scheduled samples to bring today.",
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 14,
                                        ),
                                      );
                                    }

                                    final samplesList = snapshot.data!;

                                    return _buildSamplesToBringRow(samplesList);
                                  },
                                ),
                              ),

                              SizedBox(height: 24),
                              
                              Padding(
                                padding: EdgeInsets.only(left: 20),
                                child: Text(
                                  'Call Performance',
                                  style: TextStyle(
                                    fontFamily: 'Lato',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    // TODAY'S ACCOMPLISHED
                                    Container(
                                      width: 220,
                                      margin: const EdgeInsets.only(right: 16),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: FutureBuilder<Map<String, int>>(
                                        future: getAccomplishedVisitsForToday(emailKey, userName)
                                            .timeout(
                                              Duration(seconds: 10),
                                              onTimeout: () {
                                                print('Timeout loading today accomplished');
                                                return {"total": 0, "accomplished": 0};
                                              },
                                            ),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasError) {
                                            print('Error loading today accomplished: ${snapshot.error}');
                                            return Container(
                                              height: 120,
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.error_outline, color: Colors.red, size: 24),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    'Error loading data',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(color: Colors.red, fontSize: 11),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      setState(() {});
                                                    },
                                                    child: Text('Retry', style: TextStyle(fontSize: 10)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }

                                          if (snapshot.connectionState == ConnectionState.waiting &&
                                              !snapshot.hasData) {
                                            return const SizedBox(
                                              height: 120,
                                              child: Center(
                                                child: CircularProgressIndicator(),
                                              ),
                                            );
                                          }

                                          if (!snapshot.hasData) {
                                            return SizedBox(
                                              height: 120,
                                              child: Center(
                                                child: Text(
                                                  _isOffline
                                                      ? "Offline: showing last known performance from cache."
                                                      : "Unable to load today's data.",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          final Map<String, int> data = snapshot.data!;
                                          final int total = data['total'] ?? 0;
                                          final int accomplished = data['accomplished'] ?? 0;
                                          final double ratio = total == 0 ? 0.0 : accomplished / total;
                                          final double percent = ratio.clamp(0.0, 1.0);

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Today's Accomplished",
                                                style: TextStyle(
                                                  fontFamily: 'Lato',
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const SizedBox.shrink(),
                                                  Container(
                                                    width: 26,
                                                    height: 26,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFFF5F4FF),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.speed,
                                                      size: 16,
                                                      color: Colors.purple.shade400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              SizedBox(
                                                height: 96,
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        ratio.toStringAsFixed(2),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontFamily: 'Lato',
                                                          fontSize: 32,
                                                          fontWeight: FontWeight.w900,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 70,
                                                      height: 70,
                                                      child: CustomPaint(
                                                        painter: _DonutPainter(
                                                          progress: percent,
                                                          color: Colors.green.shade500,
                                                          strokeWidth: 12,
                                                          backgroundColor: const Color(0xFFE8ECEF),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$accomplished / $total',
                                                style: const TextStyle(
                                                  fontFamily: 'Lato',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),

                                    // MONTH'S ACCOMPLISHED
                                    Container(
                                      width: 220,
                                      margin: const EdgeInsets.only(right: 16),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: FutureBuilder<Map<String, int>>(
                                        future: _getAccomplishedVisitsForMonth(emailKey, userName)
                                            .timeout(
                                              Duration(seconds: 10),
                                              onTimeout: () {
                                                print('Timeout loading month accomplished');
                                                return {"total": 0, "accomplished": 0};
                                              },
                                            ),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasError) {
                                            print('Error loading month accomplished: ${snapshot.error}');
                                            return Container(
                                              height: 120,
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.error_outline, color: Colors.red, size: 24),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    'Error loading data',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(color: Colors.red, fontSize: 11),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      setState(() {});
                                                    },
                                                    child: Text('Retry', style: TextStyle(fontSize: 10)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }

                                          if (snapshot.connectionState == ConnectionState.waiting &&
                                              !snapshot.hasData) {
                                            return const SizedBox(
                                              height: 120,
                                              child: Center(
                                                child: CircularProgressIndicator(),
                                              ),
                                            );
                                          }

                                          if (!snapshot.hasData) {
                                            return SizedBox(
                                              height: 120,
                                              child: Center(
                                                child: Text(
                                                  _isOffline
                                                      ? "Offline: showing last known monthly performance from cache."
                                                      : "Unable to load month's data.",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          final Map<String, int> data = snapshot.data!;
                                          final int total = data['total'] ?? 0;
                                          final int accomplished = data['accomplished'] ?? 0;
                                          final double ratio = total == 0 ? 0.0 : accomplished / total;
                                          final double percent = ratio.clamp(0.0, 1.0);

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Month's Accomplished",
                                                style: TextStyle(
                                                  fontFamily: 'Lato',
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const SizedBox.shrink(),
                                                  Container(
                                                    width: 26,
                                                    height: 26,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFFF5F4FF),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.date_range,
                                                      size: 16,
                                                      color: Colors.purple.shade400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              SizedBox(
                                                height: 96,
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        ratio.toStringAsFixed(2),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontFamily: 'Lato',
                                                          fontSize: 32,
                                                          fontWeight: FontWeight.w900,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 70,
                                                      height: 70,
                                                      child: CustomPaint(
                                                        painter: _DonutPainter(
                                                          progress: percent,
                                                          color: Colors.blue.shade500,
                                                          strokeWidth: 12,
                                                          backgroundColor: const Color(0xFFE8ECEF),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$accomplished / $total',
                                                style: const TextStyle(
                                                  fontFamily: 'Lato',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),

                                    // CALL REACH
                                    Container(
                                      width: 220,
                                      margin: const EdgeInsets.only(right: 16),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: FutureBuilder<Map<String, dynamic>>(
                                        future: _getCallReachStats(emailKey, userName)
                                            .timeout(
                                              Duration(seconds: 10),
                                              onTimeout: () {
                                                print('Timeout loading call reach');
                                                return {
                                                  'callReach': 0.0,
                                                  'totalDoctors': 0,
                                                  'visitedDoctors': 0,
                                                };
                                              },
                                            ),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasError) {
                                            print('Error loading call reach: ${snapshot.error}');
                                            return Container(
                                              height: 120,
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.error_outline, color: Colors.red, size: 24),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    'Error loading data',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(color: Colors.red, fontSize: 11),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      setState(() {});
                                                    },
                                                    child: Text('Retry', style: TextStyle(fontSize: 10)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }

                                          if (snapshot.connectionState == ConnectionState.waiting &&
                                              !snapshot.hasData) {
                                            return const SizedBox(
                                              height: 120,
                                              child: Center(
                                                child: CircularProgressIndicator(),
                                              ),
                                            );
                                          }

                                          if (!snapshot.hasData) {
                                            return SizedBox(
                                              height: 120,
                                              child: Center(
                                                child: Text(
                                                  _isOffline
                                                      ? "Offline: showing last known call reach from cache."
                                                      : "Unable to load call reach data.",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          final Map<String, dynamic> data = snapshot.data!;
                                          final double callReach = (data['callReach'] ?? 0.0) as double;
                                          final int totalDoctors = (data['totalDoctors'] ?? 0) as int;
                                          final int visitedDoctors = (data['visitedDoctors'] ?? 0) as int;
                                          final double percent = (callReach / 100.0).clamp(0.0, 1.0);

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Call Reach",
                                                style: TextStyle(
                                                  fontFamily: 'Lato',
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const SizedBox.shrink(),
                                                  Container(
                                                    width: 26,
                                                    height: 26,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFFF5F4FF),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.track_changes,
                                                      size: 16,
                                                      color: Colors.purple.shade400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              SizedBox(
                                                height: 96,
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        callReach.toStringAsFixed(2),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontFamily: 'Lato',
                                                          fontSize: 32,
                                                          fontWeight: FontWeight.w900,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 70,
                                                      height: 70,
                                                      child: CustomPaint(
                                                        painter: _DonutPainter(
                                                          progress: percent,
                                                          color: Colors.orange.shade600,
                                                          strokeWidth: 12,
                                                          backgroundColor: const Color(0xFFE8ECEF),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$visitedDoctors / $totalDoctors',
                                                style: const TextStyle(
                                                  fontFamily: 'Lato',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),

                                    // CALL FREQUENCY
                                    Container(
                                      width: 220,
                                      margin: const EdgeInsets.only(right: 16),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: FutureBuilder<Map<String, dynamic>>(
                                        future: _getCallFrequencyStats(emailKey, userName)
                                            .timeout(
                                              Duration(seconds: 10),
                                              onTimeout: () {
                                                print('Timeout loading call frequency');
                                                return {
                                                  'frequencyPercent': 0.0,
                                                  'totalDoctors': 0,
                                                  'completedFrequency': 0,
                                                };
                                              },
                                            ),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasError) {
                                            print('Error loading call frequency: ${snapshot.error}');
                                            return Container(
                                              height: 120,
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.error_outline, color: Colors.red, size: 24),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    'Error loading data',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(color: Colors.red, fontSize: 11),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      setState(() {});
                                                    },
                                                    child: Text('Retry', style: TextStyle(fontSize: 10)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }

                                          if (snapshot.connectionState == ConnectionState.waiting &&
                                              !snapshot.hasData) {
                                            return const SizedBox(
                                              height: 120,
                                              child: Center(
                                                child: CircularProgressIndicator(),
                                              ),
                                            );
                                          }

                                          if (!snapshot.hasData) {
                                            return SizedBox(
                                              height: 120,
                                              child: Center(
                                                child: Text(
                                                  _isOffline
                                                      ? "Offline: showing last known call frequency from cache."
                                                      : "Unable to load call frequency data.",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          final Map<String, dynamic> data = snapshot.data!;
                                          final double frequencyPercent =
                                              (data['frequencyPercent'] ?? 0.0) as double;
                                          final int totalDoctors = (data['totalDoctors'] ?? 0) as int;
                                          final int completedFrequency =
                                              (data['completedFrequency'] ?? 0) as int;
                                          final double percent =
                                              (frequencyPercent / 100.0).clamp(0.0, 1.0);

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Call Frequency",
                                                style: TextStyle(
                                                  fontFamily: 'Lato',
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const SizedBox.shrink(),
                                                  Container(
                                                    width: 26,
                                                    height: 26,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFFF5F4FF),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.repeat,
                                                      size: 16,
                                                      color: Colors.purple.shade400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              SizedBox(
                                                height: 96,
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        frequencyPercent.toStringAsFixed(2),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontFamily: 'Lato',
                                                          fontSize: 32,
                                                          fontWeight: FontWeight.w900,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 70,
                                                      height: 70,
                                                      child: CustomPaint(
                                                        painter: _DonutPainter(
                                                          progress: percent,
                                                          color: Colors.purple.shade600,
                                                          strokeWidth: 12,
                                                          backgroundColor: const Color(0xFFE8ECEF),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$completedFrequency / $totalDoctors',
                                                style: const TextStyle(
                                                  fontFamily: 'Lato',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // MARK MARK MARK

                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyWithTabs() {
    if (!_hasSubmittedSignature) {
      return SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          color: Colors.blue.shade50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.blue.shade700,
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 200.0,
                  vertical: 200.0,
                ),
                child: Text(
                  ".",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _buildHomeDashboard(),
        FormsPage(),
        ItineraryPage(),
        DoctorPage(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
      return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF4e3385),
                Color(0xFF4e3385),
                // Color(0xFF37215a),
                // Color(0xFF3e2666),
                // Color(0xFF462a73),
                // Color(0xFF4e2f80),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 5, bottom: 5),
            child: Center(
              child: Text(
                'iDoXs',
                style: const TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.7,
                  colors: const [
                    Color.fromRGBO(20, 20, 40, 0.95),
                    Color.fromRGBO(60, 30, 100, 0.95),
                    Color.fromRGBO(100, 50, 150, 0.95),
                    Color.fromRGBO(140, 80, 200, 0.95),
                    Color.fromRGBO(200, 150, 255, 0.95),
                    Color(0xFF5958b2),
                    Color(0xFF5958b2),
                  ],
                ),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                // fixed height (or null if you want it to wrap content naturally)
                height: null,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Content (avatar + name + email) â€“ always visible now
                      Padding(
                        padding: EdgeInsets.all(AppSizes.paddingL),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFfda756),
                                    borderRadius: BorderRadius.circular(35),
                                    border: Border.all(
                                      color: const Color(0xFFfda756),
                                      width: 2,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () =>
                                        _handleDrawerItemTap('Profile', '/profile'),
                                    borderRadius: BorderRadius.circular(35),
                                    child: Center(
                                      child: _isLoading
                                          ? const CircularProgressIndicator(
                                              color: Colors.white,
                                            )
                                          : Text(
                                              userName.isNotEmpty
                                                  ? userName[0].toUpperCase()
                                                  : 'U',
                                              style:
                                                  AppTextStyles.heading2.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: AppSizes.paddingM),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _isLoading ? 'Loading...' : userName,
                                        style:
                                            AppTextStyles.heading3.copyWith(
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        _isLoading ? 'Loading...' : userEmail,
                                        style: AppTextStyles.body2.copyWith(
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),


            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: AppSizes.paddingS),
                itemCount: MenuItems.drawerItems.length,
                itemBuilder: (context, index) {
                  final item = MenuItems.drawerItems[index];
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingM,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item['icon'],
                        color: Color(0xFF9810fa),
                        size: AppSizes.iconM,
                      ),
                    ),
                    title: Text(
                      item['title'],
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () =>
                        _handleDrawerItemTap(item['title'], item['route']),
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.all(AppSizes.paddingM),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.textLight.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.logout,
                    color: AppColors.error,
                    size: AppSizes.iconM,
                  ),
                ),
                title: Text(
                  'Sign Out',
                  style: AppTextStyles.body1.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _signOut();
                },
              ),
            ),
          ],
        ),
      ),


      body: _buildBodyWithTabs(),
      
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF564ca4),
              Color(0xFF4b2675),
              // Color(0xFF715999),
              // Color(0xFF836da6),
              // Color(0xFF9582b3),
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        height: 115,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            BottomNavigationBar(
              backgroundColor: Colors.transparent,
              currentIndex: _selectedIndex,
              onTap: _onTabTapped,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: const Color(0xFFfdc700),
              unselectedItemColor: Colors.white70,
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.article_outlined),
                  activeIcon: Icon(Icons.article),
                  label: 'E-Forms',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today_outlined),
                  activeIcon: Icon(Icons.calendar_month),
                  label: 'Itinerary',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_alt_outlined),
                  activeIcon: Icon(Icons.people),
                  label: 'Contacts',
                ),
              ],
            ),
            Positioned(
              top: -24,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    if (_selectedIndex == 0) {
                      _openUnplannedVisitDialog();
                    } else if (_selectedIndex == 1) {
                      _openCreateEFormDialog();
                    } else if (_selectedIndex == 2) {
                      _openAddPlannedVisitDialog();
                    } else if (_selectedIndex == 3) {
                      _openAddNewClientDialog();
                    }
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4e2f80),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.85),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    }

  // Scheduled doctors for today section
  Widget _buildScheduledDoctorsRow(List<Map<String, dynamic>> visitsForDay) {
  // Sort by time, visited first (defensive: data may not be sorted yet)
  visitsForDay.sort((a, b) {
    final aVisitData = a['visitData'] as Map<String, dynamic>;
    final bVisitData = b['visitData'] as Map<String, dynamic>;

    final aSig = aVisitData['signaturePoints'];
    final bSig = bVisitData['signaturePoints'];

    final bool aVisited = aSig != null && aSig is List;
    final bool bVisited = bSig != null && bSig is List;

    if (aVisited && !bVisited) return -1;
    if (!aVisited && bVisited) return 1;

    final aTime = a['scheduledTime'] as String? ?? '';
    final bTime = b['scheduledTime'] as String? ?? '';
    return aTime.compareTo(bTime);
  });

  // Find the doctor to visit (purple card)
  final int nextIdx = visitsForDay.indexWhere((v) {
    final visitData = v['visitData'] as Map<String, dynamic>;
    final signaturePoints = visitData['signaturePoints'];
    return signaturePoints == null ||
        (signaturePoints is List && signaturePoints.isEmpty);
  });

  // Auto-scroll to the next (purple) doctor card
  if (nextIdx > 0) {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!_doctorsScrollController.hasClients) return;
      if (!_doctorsScrollController.position.hasContentDimensions) return;

      // Resize card width so that it is always longer than the longest doctor name
      const double minCardWidth = 280.0;
      const double maxCardWidth = 380.0;
      const double charsPerLine = 18.0;
      const double extraWidthPerChar = 7.0;
      const double badgeOverflow = 10.0;
      const double cardGap = 12.0;

      // Find the doctor with the longest name among all displayed cards
      // All card widths remain uniform
      final String longestName = visitsForDay
          .map((v) => (v['doctorName'] as String? ?? ''))
          .reduce((a, b) => a.length > b.length ? a : b);

      final double cardWidth = longestName.length > charsPerLine
          ? (minCardWidth +
                  (longestName.length - charsPerLine) * extraWidthPerChar)
              .clamp(minCardWidth, maxCardWidth)
          : minCardWidth;

      final double itemStride = cardWidth + badgeOverflow + cardGap;
      final double offset = (nextIdx * itemStride).clamp(
        0.0,
        _doctorsScrollController.position.maxScrollExtent,
      );

      _doctorsScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  const double badgeOverflow = 10.0;
  const double shadowPadding = 12.0;
  return SizedBox(
    height: 220 + badgeOverflow + shadowPadding,
    child: ListView.builder(
      controller: _doctorsScrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(
        left: 5,
        top: badgeOverflow,
        bottom: shadowPadding,
      ),
      itemCount: visitsForDay.length,
      itemBuilder: (context, idx) {
        final visit = visitsForDay[idx];
        final visitData = visit['visitData'] as Map<String, dynamic>;
        final scheduledTime = visit['scheduledTime'] as String? ?? '';
        final String doctorName = visit['doctorName'] as String? ?? '-';
        final String hospital = visit['hospital'] as String? ?? '';
        final bool isUnplanned = visitData['unplanned'] == true;
        final String visitTypeLabel =
            isUnplanned ? '(Unplanned)' : '(Planned)';

        final signaturePoints = visitData['signaturePoints'];
        final bool isVisited =
            signaturePoints != null && signaturePoints is List;

        final int nextIdxLocal = nextIdx;
        final bool isNext = !isVisited && idx == nextIdxLocal;

        const double visitedCardHeight = 200.0;
        const double normalCardHeight = 212.0;
        final double cardHeight =
            isVisited ? visitedCardHeight : normalCardHeight;

        const double minCardWidth = 280.0;
        const double maxCardWidth = 380.0;
        const double charsPerLine = 18.0;
        const double extraWidthPerChar = 7.0;

        final String longestName = visitsForDay
            .map((v) => (v['doctorName'] as String? ?? ''))
            .reduce((a, b) => a.length > b.length ? a : b);

        final double dynamicWidth = longestName.length > charsPerLine
            ? (minCardWidth +
                    (longestName.length - charsPerLine) * extraWidthPerChar)
                .clamp(minCardWidth, maxCardWidth)
            : minCardWidth;

        final double cardWidth = dynamicWidth;

        final Color iconBoxBg = isNext
            ? Colors.white.withValues(alpha: 0.18)
            : const Color(0xFFF0F0F2);
        final Color iconColor =
            isNext ? Colors.white : const Color(0xFF5A5A7A);
        final Color titleColor =
            isNext ? Colors.white : Colors.black87;
        final Color timeColor =
            isNext ? Colors.white70 : Colors.grey.shade700;
        final Color hospitalColor =
            isNext ? Colors.white60 : Colors.grey.shade600;

        return Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: cardWidth + badgeOverflow,
              height: cardHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: badgeOverflow,
                    top: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: cardWidth,
                      height: cardHeight,
                      decoration: BoxDecoration(
                        color: isNext ? null : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        gradient: isNext
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF4A2371),
                                  Color(0xFF4A2371),
                                  Color(0xFF5958B2)
                                ],
                                stops: [0.0, 0.55, 1.0],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        border: isVisited
                            ? Border.all(
                                color: const Color(0xFF4CAF50),
                                width: 2.2,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: isNext
                                ? const Color(0xFF3B2A7E)
                                    .withValues(alpha: 0.35)
                                : Colors.black
                                    .withValues(alpha: 0.07),
                            blurRadius: isNext ? 16 : 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: null, // card tap does nothing; navigation only via Start Call
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: iconBoxBg,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.assignment_outlined,
                                      size: 26,
                                      color: iconColor,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "Doctor's Visit",
                                          style: TextStyle(
                                            fontFamily: 'OpenSauce',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: titleColor,
                                          ),
                                        ),
                                        Text(
                                          visitTypeLabel,
                                          style: TextStyle(
                                            fontFamily: 'OpenSauce',
                                            fontWeight: FontWeight.w500,
                                            fontSize: 10,
                                            color: isNext
                                                ? Colors.white60
                                                : Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                doctorName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'OpenSauce',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: titleColor,
                                  height: 1.2,
                                  shadows: isNext
                                      ? [
                                          Shadow(
                                            color: Colors.white
                                                .withValues(alpha: 0.3),
                                            blurRadius: 0,
                                            offset:
                                                const Offset(0.4, 0),
                                          )
                                        ]
                                      : [
                                          Shadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.15),
                                            blurRadius: 0,
                                            offset:
                                                const Offset(0.4, 0),
                                          )
                                        ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    scheduledTime,
                                    style: TextStyle(
                                      fontFamily: 'OpenSauce',
                                      fontWeight: FontWeight.w400,
                                      fontSize: 14,
                                      color: timeColor,
                                    ),
                                  ),
                                  if (hospital.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      hospital,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'OpenSauce',
                                        fontWeight: FontWeight.w400,
                                        fontSize: 12,
                                        color: hospitalColor,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const Spacer(),
                              if (!isVisited)
                                Container(
                                  width: double.infinity,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    gradient: isNext
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFF4CAF50),
                                              Color(0xFF388E3C)
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: isNext
                                        ? null
                                        : const Color(0xFFE8F5E9),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              CallDetailPage(
                                            doctor: visit['doctor']
                                                as Map<String, dynamic>,
                                            scheduledVisitId:
                                                visit['visitId']
                                                    as String,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.play_arrow,
                                      size: 17,
                                    ),
                                    label: const Text(
                                      'Start Call',
                                      style: TextStyle(
                                        fontFamily: 'OpenSauce',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.transparent,
                                      foregroundColor: isNext
                                          ? Colors.white
                                          : const Color(0xFF2E7D32),
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isVisited)
                    Positioned(
                      top: -4,
                      left: -2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x334CAF50),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
  
Widget _buildSamplesToBringRow(List<Map<String, dynamic>> samplesList) {
  return StatefulBuilder(
    builder: (context, setBoxState) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: samplesList.asMap().entries.map((entry) {
            int idx = entry.key;
            var item = entry.value;
            final bool isChecked = checkedStates[idx] ?? false;
            final String promoName = item['sample'] ?? '';
            final int qty = item['qty'] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  checkedStates[idx] = !(checkedStates[idx] ?? false);
                  setBoxState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: 160,
                  height: 160,
                  padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
                  decoration: BoxDecoration(
                    color: isChecked
                        ? Colors.green.shade50
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isChecked
                          ? Colors.green
                          : Colors.grey.shade200,
                      width: isChecked ? 1.5 : 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isChecked
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: isChecked
                            ? Colors.green.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        width: 55,
                        height: 55,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEEDFE),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.package,
                          size: 26,
                          color: Color(0xFF4A2371),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Product name
                      Text(
                        promoName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'OpenSauce',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Quantity
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 14),
                          children: [
                            TextSpan(
                              text: 'Qty: ',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                              ),
                            ),
                            TextSpan(
                              text: '${qty}x',
                              style: const TextStyle(
                                color: Color(0xFF4A2371),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    },
  );
}

}