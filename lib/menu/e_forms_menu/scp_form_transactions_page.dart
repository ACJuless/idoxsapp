import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';

import 'scp_form_page.dart';

/// Detail page for a single SCP form.
/// Shows all fields, and supports toggling between read-only and edit mode.
class ScpFormReadonlyPage extends StatefulWidget {
  final Map<String, dynamic> formData;
  final String docId;
  final String userKey;

  const ScpFormReadonlyPage({
    Key? key,
    required this.formData,
    required this.docId,
    required this.userKey,
  }) : super(key: key);

  @override
  State<ScpFormReadonlyPage> createState() => _ScpFormReadonlyPageState();
}

class _ScpFormReadonlyPageState extends State<ScpFormReadonlyPage> {
  bool _isEditMode = false;

  // Basic details controllers
  late TextEditingController _farmerNameController;
  late TextEditingController _farmAddressController;
  late TextEditingController _cellphoneNumberController;
  late TextEditingController _dateOfEventController;
  late TextEditingController _cropsPlantedController;
  late TextEditingController _typeOfEventController;
  late TextEditingController _venueOfEventController;
  late TextEditingController _cropAdvisorNameController;
  late TextEditingController _cropAdvisorContactController;
  late TextEditingController _farmerNameSecondController;
  late TextEditingController _dateNeededController;
  late TextEditingController _preferredDealerController;

  // Advisory details & products as editable lists
  late List<Map<String, dynamic>> _advisoryDetails;
  late List<Map<String, dynamic>> _products;

  // Signature controller (farmer signature points)
  late SignatureController _farmerSignatureController;

  String _createdBy = '';

  @override
  void initState() {
    super.initState();

    // Initialize data from incoming formData
    final formData = widget.formData;

    _farmerNameController =
        TextEditingController(text: formData['farmerName'] ?? '');
    _farmAddressController =
        TextEditingController(text: formData['farmAddress'] ?? '');
    _cellphoneNumberController =
        TextEditingController(text: formData['cellphoneNumber'] ?? '');
    _dateOfEventController =
        TextEditingController(text: formData['dateOfEvent'] ?? '');
    _cropsPlantedController =
        TextEditingController(text: formData['cropsPlanted'] ?? '');
    _typeOfEventController =
        TextEditingController(text: formData['typeOfEvent'] ?? '');
    _venueOfEventController =
        TextEditingController(text: formData['venueOfEvent'] ?? '');
    _cropAdvisorNameController =
        TextEditingController(text: formData['cropAdvisorName'] ?? '');
    _cropAdvisorContactController =
        TextEditingController(text: formData['cropAdvisorContact'] ?? '');
    _farmerNameSecondController =
        TextEditingController(text: formData['farmerNameSecond'] ?? '');
    _dateNeededController =
        TextEditingController(text: formData['dateNeeded'] ?? '');
    _preferredDealerController =
        TextEditingController(text: formData['preferredDealer'] ?? '');
    _createdBy = formData['createdBy'] ?? '';

    final List<dynamic> advisoryDetailsRaw =
        formData['advisoryDetails'] ?? <dynamic>[];
    final List<dynamic> productsRaw = formData['products'] ?? <dynamic>[];

    _advisoryDetails =
        advisoryDetailsRaw.map((e) => Map<String, dynamic>.from(e)).toList();
    _products = productsRaw.map((e) => Map<String, dynamic>.from(e)).toList();

    // Initialize farmer signature controller
    _farmerSignatureController = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    _loadFarmerSignatureFromData(formData);
  }

  /// Load signature points from Firestore data into the SignatureController.
  /// Form now stores them under 'farmerSignaturePoints' as:
  /// {
  ///   "name": "...",
  ///   "points": [
  ///     {"x": ..., "y": ..., "pressure": ..., "type": "PointType.move"},
  ///     ...
  ///   ]
  /// }
  void _loadFarmerSignatureFromData(Map<String, dynamic> data) {
    final dynamic raw = data['farmerSignaturePoints'];

    if (raw is Map<String, dynamic>) {
      final dynamic pointsRawDynamic = raw['points'];

      if (pointsRawDynamic is List) {
        final List pointsRaw = pointsRawDynamic;
        final List<Point> pts = [];
        for (final p in pointsRaw) {
          if (p is Map) {
            final double? x = (p['x'] as num?)?.toDouble();
            final double? y = (p['y'] as num?)?.toDouble();
            if (x == null || y == null) continue;

            // FIRST switch (inside raw is Map<String, dynamic> branch)
            final String typeStr = (p['type'] as String?) ?? 'PointType.tap';
            PointType type;
            switch (typeStr) {
              case 'PointType.move':
                type = PointType.move;
                break;
              // 'up' and 'down' fall back to tap for compatibility
              case 'PointType.up':
              case 'PointType.down':
              default:
                type = PointType.tap;
            }


            final double pressure =
                (p['pressure'] as num?)?.toDouble() ?? 1.0;

            pts.add(Point(Offset(x, y), type, pressure));
          }
        }
        if (pts.isNotEmpty) {
          _farmerSignatureController.points = pts;
        }
      }
    } else if (raw is List) {
      // Backward compatibility: if earlier versions stored a plain List of point maps
      final List pointsRaw = raw;
      final List<Point> pts = [];
      for (final p in pointsRaw) {
        if (p is Map) {
          final double? x = (p['x'] as num?)?.toDouble();
          final double? y = (p['y'] as num?)?.toDouble();
          if (x == null || y == null) continue;

          // SECOND switch (inside raw is List branch)
          final String typeStr = (p['type'] as String?) ?? 'PointType.tap';
          PointType type;
          switch (typeStr) {
            case 'PointType.move':
              type = PointType.move;
              break;
            // 'up' and 'down' fall back to tap for compatibility
            case 'PointType.up':
            case 'PointType.down':
            default:
              type = PointType.tap;
          }


          final double pressure =
              (p['pressure'] as num?)?.toDouble() ?? 1.0;

          pts.add(Point(Offset(x, y), type, pressure));
        }
      }
      if (pts.isNotEmpty) {
        _farmerSignatureController.points = pts;
      }
    } else if (raw is String && raw.isNotEmpty) {
      // Very old case: PNG base64 string — cannot reconstruct points, so ignore for drawing
      try {
        final Uint8List bytes = base64Decode(raw);
        // Here you could display this bytes as Image if you still want backward support,
        // but we keep the Signature widget for current versions using points.
        // For simplicity we ignore this in the points-based pad.
      } catch (_) {
        // ignore invalid base64 string
      }
    }
  }

  @override
  void dispose() {
    _farmerNameController.dispose();
    _farmAddressController.dispose();
    _cellphoneNumberController.dispose();
    _dateOfEventController.dispose();
    _cropsPlantedController.dispose();
    _typeOfEventController.dispose();
    _venueOfEventController.dispose();
    _cropAdvisorNameController.dispose();
    _cropAdvisorContactController.dispose();
    _farmerNameSecondController.dispose();
    _dateNeededController.dispose();
    _preferredDealerController.dispose();
    _farmerSignatureController.dispose();
    super.dispose();
  }

  /// Export current signature points to save back to Firestore as:
  /// {
  ///   "name": "...",
  ///   "points": [ {x,y,pressure,type}, ... ]
  /// }
  Future<Map<String, dynamic>> _exportFarmerSignaturePoints() async {
    final List<Map<String, dynamic>> serializedPoints = [];
    if (!_farmerSignatureController.isEmpty) {
      final List<Point?> pts = _farmerSignatureController.points;
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

    return {
      'name': _farmerNameSecondController.text.trim(),
      'points': serializedPoints,
    };
  }

  Future<void> _saveChanges() async {
    try {
      // Build updated map
      final Map<String, dynamic> updatedData = {
        'farmerName': _farmerNameController.text.trim(),
        'farmAddress': _farmAddressController.text.trim(),
        'cellphoneNumber': _cellphoneNumberController.text.trim(),
        'dateOfEvent': _dateOfEventController.text.trim(),
        'cropsPlanted': _cropsPlantedController.text.trim(),
        'typeOfEvent': _typeOfEventController.text.trim(),
        'venueOfEvent': _venueOfEventController.text.trim(),
        'cropAdvisorName': _cropAdvisorNameController.text.trim(),
        'cropAdvisorContact': _cropAdvisorContactController.text.trim(),
        'farmerNameSecond': _farmerNameSecondController.text.trim(),
        'dateNeeded': _dateNeededController.text.trim(),
        'preferredDealer': _preferredDealerController.text.trim(),
        'createdBy': _createdBy,
        'advisoryDetails': _advisoryDetails,
        'products': _products,
      };

      // Export signature points for saving
      final farmerSignaturePoints = await _exportFarmerSignaturePoints();
      updatedData['farmerSignaturePoints'] = farmerSignaturePoints;

      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(widget.userKey)
          .doc('scp_forms')
          .collection('scp_forms')
          .doc(widget.docId)
          .update(updatedData);

      setState(() {
        _isEditMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SCP form updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update form: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SCP Form Detail'),
        backgroundColor: const Color(0xFF5958b2),
        actions: [
          IconButton(
            icon: Icon(_isEditMode ? Icons.close : Icons.edit),
            tooltip: _isEditMode ? 'Cancel edit' : 'Edit SCP Form',
            onPressed: () {
              setState(() {
                _isEditMode = !_isEditMode;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Basic details card
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
                    const Text(
                      'Sample Crop Prescription Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5958b2),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildField(
                      label: 'Farmer Name',
                      controller: _farmerNameController,
                      readOnly: !_isEditMode,
                    ),
                    _buildField(
                      label: 'Farm Address',
                      controller: _farmAddressController,
                      readOnly: !_isEditMode,
                      hideIfEmpty: true,
                    ),
                    _buildField(
                      label: 'Cellphone Number',
                      controller: _cellphoneNumberController,
                      readOnly: !_isEditMode,
                      hideIfEmpty: true,
                    ),
                    _buildField(
                      label: 'Date of Event',
                      controller: _dateOfEventController,
                      readOnly: !_isEditMode,
                    ),
                    _buildField(
                      label: 'Crops Planted',
                      controller: _cropsPlantedController,
                      readOnly: !_isEditMode,
                    ),
                    _buildField(
                      label: 'Type of Event',
                      controller: _typeOfEventController,
                      readOnly: !_isEditMode,
                      hideIfEmpty: true,
                    ),
                    _buildField(
                      label: 'Venue of Event',
                      controller: _venueOfEventController,
                      readOnly: !_isEditMode,
                      hideIfEmpty: true,
                    ),
                    if (_createdBy.isNotEmpty)
                      _readonlyField('Created By', _createdBy),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Advisory Details card
            if (_advisoryDetails.isNotEmpty)
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
                      const Text(
                        'Advisory Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5958b2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children:
                            _advisoryDetails.asMap().entries.map((entry) {
                          final int idx = entry.key + 1;
                          final Map<String, dynamic> item = entry.value;

                          final String keyConcern =
                              (item['keyConcern'] ?? '').toString();
                          final String recommendation =
                              (item['productRecommendation'] ?? '').toString();

                          // Controllers for this row in edit mode
                          final keyConcernController =
                              TextEditingController(text: keyConcern);
                          final recommendationController =
                              TextEditingController(text: recommendation);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Row $idx',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (_isEditMode)
                                  _buildDynamicField(
                                    label: 'Key Concern',
                                    controller: keyConcernController,
                                    onChanged: (val) {
                                      _advisoryDetails[entry.key]
                                          ['keyConcern'] = val;
                                    },
                                  )
                                else if (keyConcern.isNotEmpty)
                                  _readonlyField(
                                      'Key Concern', keyConcern),
                                if (_isEditMode)
                                  _buildDynamicField(
                                    label: 'Product Recommendation',
                                    controller: recommendationController,
                                    onChanged: (val) {
                                      _advisoryDetails[entry.key]
                                              ['productRecommendation'] =
                                          val;
                                    },
                                  )
                                else if (recommendation.isNotEmpty)
                                  _readonlyField(
                                    'Product Recommendation',
                                    recommendation,
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Crop Advisor card
            if (_cropAdvisorNameController.text.isNotEmpty ||
                _cropAdvisorContactController.text.isNotEmpty ||
                _isEditMode)
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
                      const Text(
                        'Crop Advisor Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5958b2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        label: 'Name of Crop Advisor',
                        controller: _cropAdvisorNameController,
                        readOnly: !_isEditMode,
                        hideIfEmpty: !_isEditMode,
                      ),
                      _buildField(
                        label: 'Crop Advisor Contact Number',
                        controller: _cropAdvisorContactController,
                        readOnly: !_isEditMode,
                        hideIfEmpty: !_isEditMode,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Products card
            if (_products.isNotEmpty)
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
                      const Text(
                        'Indofil Crop Solutions and Technologies',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5958b2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: _products.asMap().entries.map((entry) {
                          final int idx = entry.key + 1;
                          final Map<String, dynamic> item = entry.value;

                          final String productName =
                              (item['productName'] ?? '').toString();
                          final String quantity =
                              (item['quantity'] ?? '').toString();
                          final String packaging =
                              (item['packaging'] ?? '').toString();

                          // Controllers for this row when editing
                          final productNameController =
                              TextEditingController(text: productName);
                          final quantityController =
                              TextEditingController(text: quantity);
                          final packagingController =
                              TextEditingController(text: packaging);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Product $idx',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (_isEditMode)
                                  _buildDynamicField(
                                    label: 'Product Name',
                                    controller: productNameController,
                                    onChanged: (val) {
                                      _products[entry.key]['productName'] = val;
                                    },
                                  )
                                else if (productName.isNotEmpty)
                                  _readonlyField(
                                      'Product Name', productName),
                                if (_isEditMode)
                                  _buildDynamicField(
                                    label: 'Quantity',
                                    controller: quantityController,
                                    onChanged: (val) {
                                      _products[entry.key]['quantity'] = val;
                                    },
                                  )
                                else if (quantity.isNotEmpty)
                                  _readonlyField('Quantity', quantity),
                                if (_isEditMode)
                                  _buildDynamicField(
                                    label: 'Packaging',
                                    controller: packagingController,
                                    onChanged: (val) {
                                      _products[entry.key]['packaging'] = val;
                                    },
                                  )
                                else if (packaging.isNotEmpty)
                                  _readonlyField('Packaging', packaging),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Farmer signature + footer card
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
                    _buildField(
                      label: 'Name of Farmer (Signature Section)',
                      controller: _farmerNameSecondController,
                      readOnly: !_isEditMode,
                      hideIfEmpty: !_isEditMode,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Signature of Farmer',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 160,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: IgnorePointer(
                          ignoring: !_isEditMode,
                          child: Signature(
                            controller: _farmerSignatureController,
                            width: double.infinity,
                            height: 80,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (_isEditMode)
                      TextButton(
                        onPressed: () {
                          _farmerSignatureController.clear();
                        },
                        child: const Text(
                          'Clear Signature',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _buildField(
                      label: 'Date Needed',
                      controller: _dateNeededController,
                      readOnly: !_isEditMode,
                      hideIfEmpty: !_isEditMode,
                    ),
                    _buildField(
                      label: 'Preferred Dealer',
                      controller: _preferredDealerController,
                      readOnly: !_isEditMode,
                      hideIfEmpty: !_isEditMode,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isEditMode
          ? FloatingActionButton.extended(
              onPressed: _saveChanges,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text(
                'Update',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF5958b2),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// Reusable builder that shows either a read-only colored container
  /// or an editable TextField, depending on [readOnly] and [_isEditMode].
  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required bool readOnly,
    bool hideIfEmpty = false,
  }) {
    if (hideIfEmpty && controller.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    if (readOnly) {
      return _readonlyField(label, controller.text);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            decoration: BoxDecoration(
              color: Colors.cyan.shade50,
              borderRadius: BorderRadius.circular(8),
            ).toInputDecoration(),
          ),
        ],
      ),
    );
  }

  /// For dynamic per-row fields where we pass a controller and onChanged.
  Widget _buildDynamicField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: BoxDecoration(
              color: Colors.cyan.shade50,
              borderRadius: BorderRadius.circular(8),
            ).toInputDecoration(),
          ),
        ],
      ),
    );
  }

  /// Original read-only field (unchanged)
  Widget _readonlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.cyan.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small extension to convert a BoxDecoration into an InputDecoration
/// with a matching background color and rounded corners.
extension _BoxToInputDecoration on BoxDecoration {
  InputDecoration toInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: (color ?? Colors.transparent),
      contentPadding: const EdgeInsets.all(10),
      border: OutlineInputBorder(
        borderRadius: borderRadius is BorderRadius
            ? (borderRadius as BorderRadius)
            : BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class ScpFormTransactionsPage extends StatefulWidget {
  const ScpFormTransactionsPage({Key? key}) : super(key: key);

  @override
  State<ScpFormTransactionsPage> createState() =>
      _ScpFormTransactionsPageState();
}

class _ScpFormTransactionsPageState extends State<ScpFormTransactionsPage> {
  String userKey = '';

  @override
  void initState() {
    super.initState();
    _loadEmailKey();
  }

  Future<void> _loadEmailKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    setState(() {
      // same pattern as your attendance page: sanitize email for Firestore ids
      userKey = userEmail.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_');
    });
  }

  Future<void> _navigateToScpFormPage(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScpFormPage(),
      ),
    );
    if (result == true) {
      setState(() {});
    }
  }

  void _openDetail(
    BuildContext context,
    Map<String, dynamic> formData,
    String docId,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScpFormReadonlyPage(
          formData: formData,
          docId: docId,
          userKey: userKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double cardWidth = (MediaQuery.of(context).size.width - 48) / 2;
    final double cardHeight = 170.0;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          elevation: 4,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
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
            ),
          ),
          title: const Text('Sample Crop Prescription Forms'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New SCP Form',
              onPressed: () => _navigateToScpFormPage(context),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      body: userKey.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('flowDB')
                  .doc('users')
                  .collection(userKey)
                  .doc('scp_forms')
                  .collection('scp_forms')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No SCP forms yet. Tap + to create a new.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: GridView.builder(
                    itemCount: docs.length,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: cardWidth / cardHeight,
                    ),
                    itemBuilder: (context, idx) {
                      final doc = docs[idx];
                      final data = doc.data() as Map<String, dynamic>;

                      final String farmerName =
                          data['farmerName'] ?? 'Unnamed Farmer';
                      final String dateOfEvent =
                          data['dateOfEvent'] ?? '-';
                      final String cropsPlanted =
                          data['cropsPlanted'] ?? '';

                      // Descending transaction number (first cell = highest)
                      final transactionNumber = docs.length - idx;
                      final transactionLabel = 'SCP #$transactionNumber';

                      return SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openDetail(
                              context,
                              data,
                              doc.id,
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF54479d),
                                    Color(0xFF826ca4),
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.description_outlined,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            transactionLabel,
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            farmerName,
                                            maxLines: 2,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (cropsPlanted.isNotEmpty)
                                            Text(
                                              'Crop: $cropsPlanted',
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          Text(
                                            'Date: $dateOfEvent',
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
