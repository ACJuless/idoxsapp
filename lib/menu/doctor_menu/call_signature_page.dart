import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallSignaturePage extends StatefulWidget {
  final String doctorId;
  // EXPECTED: yyyyMMdd (e.g. 20260422) for this doctor
  final String scheduledVisitId;
  final void Function(bool drawing)? onDrawing;

  const CallSignaturePage({
    Key? key,
    required this.doctorId,
    required this.scheduledVisitId,
    this.onDrawing,
  }) : super(key: key);

  @override
  State<CallSignaturePage> createState() => _CallSignaturePageState();
}

class _CallSignaturePageState extends State<CallSignaturePage> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
    disabled: false,
  );

  bool _saving = false;
  bool _hasSignature = false;

  // Flag: whether allocations have been successfully saved at least once.
  bool _allocationsSavedOnce = false;

  List<String> sampleProducts = [];
  late Map<String, int> sampleCounts;

  List<String> samples = [];
  Map<String, int> sampleQty = {};
  final List<String> medicineOptions = [
    'Indofil fungicide',
    'Zinc Phosphide',
    'Maxilizer',
    'Matco 720 WP',
    'Grifon SC',
  ];

  String? emailKey;
  String userClientType = ''; // pharma / farmers / legacy
  String _userId = ''; // MR00001 (MR code)

  @override
  void initState() {
    super.initState();
    _loadEmailKeyAndUserType();
    _loadPdfSampleProducts();
  }

  Future<void> _loadEmailKeyAndUserType() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    final storedClientType = prefs.getString('userClientType') ?? '';
    final storedUserId = prefs.getString('userId') ?? '';

    setState(() {
      emailKey = userEmail.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
      userClientType = storedClientType;
      _userId = storedUserId;
    });

    if (_userId.isNotEmpty) {
      _loadExistingSignature();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Decide which Daloy segment to use based on clientType and email.
  String _getClientSegment(String userClientType, String userEmail) {
    if (userClientType == 'farmers') return 'INDOFIL';
    if (userClientType == 'pharma') {
      final lower = userEmail.toLowerCase();
      if (lower.endsWith('@wert.com')) return 'WERT';
      return 'IVA';
    }
    return 'IVA';
  }

  /// Base doctor document:
  ///   /DaloyClients/{SEGMENT}/Users/{MR00001}/Doctor/{doctorId}
  DocumentReference<Map<String, dynamic>> _doctorDocRef() {
    final userEmail = emailKey?.replaceAll('_', '.') ?? '';
    final segment = _getClientSegment(userClientType, userEmail);

    return FirebaseFirestore.instance
        .collection('DaloyClients')
        .doc(segment)
        .collection('Users')
        .doc(_userId)
        .collection('Doctor')
        .doc(widget.doctorId);
  }

  /// Visit document (schedule meta only):
  ///   /Doctor/{doctorId}/Visits/{visitId}
  DocumentReference<Map<String, dynamic>> _visitDocRef() {
    final visitId = widget.scheduledVisitId; // yyyyMMdd
    return _doctorDocRef().collection('Visits').doc(visitId);
  }

  /// SampleAllocations document (samples + signature):
  ///   /Doctor/{doctorId}/SampleAllocations/{visitId}
  DocumentReference<Map<String, dynamic>> _sampleAllocationsDocRef() {
    final visitId = widget.scheduledVisitId; // yyyyMMdd
    return _doctorDocRef().collection('SampleAllocations').doc(visitId);
  }

  Future<void> _loadExistingSignature() async {
    if (_userId.isEmpty) return;

    try {
      final sampleAllocRef = _sampleAllocationsDocRef();
      final sampleAllocDoc = await sampleAllocRef.get();

      if (!sampleAllocDoc.exists) {
        // Nothing saved yet.
        return;
      }

      final data = sampleAllocDoc.data() ?? {};

      // ===== LOAD SAMPLE ALLOCATIONS MAP =====
      Map<String, int> loadedSampleQty = {};
      List<String> loadedSamples = [];

      if (data.containsKey('sampleAllocations')) {
        final allocMap =
            Map<String, dynamic>.from(data['sampleAllocations'] as Map);
        allocMap.forEach((key, val) {
          final qty = val is int ? val : int.tryParse(val.toString()) ?? 0;
          if (qty > 0) {
            loadedSamples.add(key);
            loadedSampleQty[key] = qty;
          }
        });
      }

      if (loadedSamples.isNotEmpty) {
        _allocationsSavedOnce = true;
      }

      // ===== LOAD SIGNATURE POINTS FROM SampleAllocations DOC =====
      if (data.containsKey('signaturePoints')) {
        final signatureData = data['signaturePoints'] as List<dynamic>;
        final List<Point> points = signatureData.map((pointData) {
          final map = pointData as Map<String, dynamic>;
          return Point(
            Offset(map['x'] as double, map['y'] as double),
            PointType.values[map['type'] as int],
            map['pressure'] as double? ?? 1.0,
          );
        }).toList();

        setState(() {
          samples = loadedSamples;
          sampleQty = loadedSampleQty;
          _controller.points = points;
          _hasSignature = true;
          _controller.disabled = true;
        });
        return;
      }

      // No signature, but allocations exist
      setState(() {
        samples = loadedSamples;
        sampleQty = loadedSampleQty;
      });
    } catch (e) {
      print('Error loading signature/sample allocations: $e');
    }
  }

  Future<void> _deleteSignature() async {
    if (_userId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Signature'),
          content: Text('Are you sure you want to delete this signature?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Yes'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Remove signature fields from SampleAllocations doc
        await _sampleAllocationsDocRef().set(
          {
            'signaturePoints': FieldValue.delete(),
            'signatureSavedAt': FieldValue.delete(),
            'submitted': false,
            'submittedAt': FieldValue.delete(),
          },
          SetOptions(merge: true),
        );

        setState(() {
          _controller.clear();
          _hasSignature = false;
          _controller.disabled = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signature deleted successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting signature: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSignatureAndSubmit() async {
    if (_userId.isEmpty) return;

    if (samples.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You must add at least one sample allocation.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _saving = true);

    try {
      final visitRef = _visitDocRef();
      final sampleAllocRef = _sampleAllocationsDocRef();

      // 1) Ensure the visit meta doc has scheduledDate (and optional time)
      final String dateId = widget.scheduledVisitId; // yyyyMMdd
      await visitRef.set(
        {
          'scheduledDate': dateId,
          // 'scheduledTime': someTimeString, // if you have it
        },
        SetOptions(merge: true),
      );

      // 2) Build the allocations map we want to keep
      final Map<String, dynamic> allocMapToSave = {};
      sampleQty.forEach((key, value) {
        if (value > 0) {
          allocMapToSave[key] = value;
        }
      });

      // 3) If there is a signature, we also purge old int64 fields (per-sample)
      //    and then write sampleAllocations + signature in one go.
      //    We also store VisitReference pointing to the Visit doc
      //    AND mark the Visit doc's submitted = true.
      if (_controller.isNotEmpty) {
        await FirebaseFirestore.instance.runTransaction((txn) async {
          final currentSnap = await txn.get(sampleAllocRef);
          Map<String, dynamic> existing = {};
          if (currentSnap.exists) {
            existing = Map<String, dynamic>.from(currentSnap.data() ?? {});
          }

          // Reserved keys we want to keep; everything else at top level is considered legacy
          const reservedKeys = {
            'sampleAllocations',
            'signaturePoints',
            'signatureSavedAt',
            'submitted',
            'submittedAt',
            'VisitReference',
          };

          final Map<String, dynamic> cleaned = {};

          // Copy only reserved keys from existing (we will override some of them below anyway)
          existing.forEach((key, value) {
            if (reservedKeys.contains(key)) {
              cleaned[key] = value;
            }
          });

          // Now override with the latest allocations and signature data
          cleaned['sampleAllocations'] = allocMapToSave;

          final points = _controller.points;
          final signatureData = points.map((point) {
            return {
              'x': point.offset.dx,
              'y': point.offset.dy,
              'type': point.type.index,
              'pressure': point.pressure,
            };
          }).toList();

          cleaned['signaturePoints'] = signatureData;
          cleaned['signatureSavedAt'] = FieldValue.serverTimestamp();
          cleaned['submitted'] = true;
          cleaned['submittedAt'] = FieldValue.serverTimestamp();

          // New: link back to the Visit document
          cleaned['VisitReference'] = visitRef;

          // Write back the cleaned SampleAllocations document
          txn.set(sampleAllocRef, cleaned);

          // Also mark the corresponding Visit document as submitted = true
          txn.update(visitRef, {'submitted': true});
        });
      } else {
        // No signature yet -> just write/merge sampleAllocations.
        // Also add VisitReference pointing to the Visit doc.
        // We do NOT mark Visit as submitted yet.
        await sampleAllocRef.set(
          {
            'sampleAllocations': allocMapToSave,
            'submitted': false,
            'VisitReference': visitRef,
          },
          SetOptions(merge: true),
        );
      }

      // Mark allocations as saved at least once
      if (!_allocationsSavedOnce) {
        setState(() {
          _allocationsSavedOnce = true;
        });
      }

      // Lock out further changes if there is a signature
      if (_controller.isNotEmpty) {
        setState(() {
          _hasSignature = true;
          _controller.disabled = true;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _controller.isNotEmpty
                ? 'Signature and samples saved and visit submitted successfully!'
                : 'Sample Allocations saved: You can add the signature later.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Only pop if signature is present
      if (_controller.isNotEmpty) {
        await Future.delayed(Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _loadPdfSampleProducts() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = jsonDecode(manifestContent);
    final pdfs = manifestMap.keys
        .where((String key) =>
            key.startsWith('assets/marketing_tools/') &&
            key.endsWith('.pdf'))
        .toList()
      ..sort();

    setState(() {
      sampleProducts = pdfs
          .map((pdfPath) => pdfPath
              .split('/')
              .last
              .replaceAll('.pdf', '')
              .replaceAll('_', ' '))
          .toList();
      sampleCounts = {for (final s in sampleProducts) s: 0};
    });
  }

  void _showAddSampleDialog() {
    String dropdownValue = medicineOptions[0];
    int tempQty = 1;
    showDialog(
      context: context,
      builder: (context) =>
          StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          title: Text('ProMat Allocation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: dropdownValue,
                items: medicineOptions
                    .map(
                        (med) => DropdownMenuItem(value: med, child: Text(med)))
                    .toList(),
                onChanged: (newVal) {
                  if (newVal != null) {
                    setStateDialog(() => dropdownValue = newVal);
                  }
                },
                decoration: InputDecoration(
                  labelText: "Select ProMats",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline,
                        color: Colors.red, size: 28),
                    onPressed: tempQty > 1
                        ? () => setStateDialog(() => tempQty--)
                        : null,
                  ),
                  Text(
                    '$tempQty',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline,
                        color: Colors.green, size: 28),
                    onPressed: () => setStateDialog(() => tempQty++),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!samples.contains(dropdownValue)) {
                  setState(() {
                    samples.add(dropdownValue);
                    sampleQty[dropdownValue] = tempQty;
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('Submit'),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Signature')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final double signPadHeight = 250;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================================
                  //       PROMO MATERIALS FIRST
                  // ================================
                  Text(
                    'Promo Materials Allocated:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  ...samples.map(
                    (sample) => Card(
                      elevation: 0,
                      margin: EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        leading: IconButton(
                          icon: Icon(Icons.close,
                              color: Colors.red, size: 22),
                          onPressed: _hasSignature
                              ? null
                              : () async {
                                  setState(() {
                                    samples.remove(sample);
                                    sampleQty.remove(sample);
                                  });

                                  if (_userId.isNotEmpty) {
                                    final sampleAllocRef =
                                        _sampleAllocationsDocRef();
                                    final current =
                                        (await sampleAllocRef.get()).data() ??
                                            {};

                                    if (current
                                        .containsKey('sampleAllocations')) {
                                      final allocMap =
                                          Map<String, dynamic>.from(
                                              current['sampleAllocations']
                                                  as Map);
                                      allocMap.remove(sample);
                                      current['sampleAllocations'] = allocMap;

                                      final hasAllocations =
                                          allocMap.isNotEmpty;
                                      final hasSignature = current
                                          .containsKey('signaturePoints');

                                      if (!hasAllocations &&
                                          !hasSignature) {
                                        await sampleAllocRef.delete();
                                      } else {
                                        await sampleAllocRef.set(
                                          current,
                                          SetOptions(merge: false),
                                        );
                                      }
                                    } else {
                                      final hasSignature = current
                                          .containsKey('signaturePoints');
                                      if (!hasSignature) {
                                        await sampleAllocRef.delete();
                                      } else {
                                        await sampleAllocRef.set(
                                          current,
                                          SetOptions(merge: false),
                                        );
                                      }
                                    }
                                  }
                                },
                        ),
                        title: Text(
                          sample,
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        trailing: Text(
                          'Qty: ${sampleQty[sample] ?? 1}',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed:
                          _hasSignature ? null : _showAddSampleDialog,
                      icon: Icon(Icons.add),
                      label: Text(
                        'Add ProMats',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),

                  // ================================
                  //   SIGNATURE ONLY AFTER:
                  //   1) has samples
                  //   2) user pressed Save & Submit at least once
                  // ================================
                  if (samples.isNotEmpty && _allocationsSavedOnce) ...[
                    Text(
                      "Draw the doctor's signature below:",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    if (_hasSignature)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade700),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Signature Saved & Submitted',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 12),
                    Listener(
                      onPointerDown: (_) =>
                          widget.onDrawing?.call(true),
                      onPointerUp: (_) =>
                          widget.onDrawing?.call(false),
                      child: Stack(
                        children: [
                          Container(
                            height: signPadHeight,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.black45, width: 2),
                              color: Colors.white,
                            ),
                            child: Signature(
                              controller: _controller,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                          if (_hasSignature)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.grey.withOpacity(0.1),
                                ),
                                child: Center(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Signature Locked',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30),
                  ],

                  // ================================
                  //           SINGLE BUTTON
                  // ================================
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_saving || samples.isEmpty)
                            ? null
                            : _saveSignatureAndSubmit,
                        icon: _saving
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.check),
                        label: Text(
                          _saving ? "Saving..." : "Save & Submit",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding:
                              EdgeInsets.symmetric(vertical: 14),
                          disabledBackgroundColor: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}