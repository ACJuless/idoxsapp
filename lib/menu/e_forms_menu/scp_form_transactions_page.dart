import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';

import 'scp_form_page.dart';

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

  // Local expand/collapse state for advisory and products in view/edit mode
  final Map<int, bool> _advExpanded = {};
  final Map<int, bool> _prodExpanded = {};

  @override
  void initState() {
    super.initState();

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

    _farmerSignatureController = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    _loadFarmerSignatureFromData(formData);
  }

  /// Load signature points from Firestore data into the SignatureController.
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

            final String typeStr = (p['type'] as String?) ?? 'PointType.tap';
            PointType type;
            switch (typeStr) {
              case 'PointType.move':
                type = PointType.move;
                break;
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
      final List pointsRaw = raw;
      final List<Point> pts = [];
      for (final p in pointsRaw) {
        if (p is Map) {
          final double? x = (p['x'] as num?)?.toDouble();
          final double? y = (p['y'] as num?)?.toDouble();
          if (x == null || y == null) continue;

          final String typeStr = (p['type'] as String?) ?? 'PointType.tap';
          PointType type;
          switch (typeStr) {
            case 'PointType.move':
              type = PointType.move;
              break;
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
      try {
        final Uint8List bytes = base64Decode(raw);
        // You could show this PNG if needed; ignored here.
        bytes;
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

  /// Export current signature points to save back to Firestore.
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

  // Helpers for section headers (matching HTML style roughly)
  Widget _sectionLabel(String text, {bool first = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, first ? 6 : 20, 8, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF5958B2),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _formCard(Widget child) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      margin: EdgeInsets.zero,
      child: child,
    );
  }

  // View-mode row (vrow)
  Widget _vRow(String label, String value) {
    final trimmed = value.trim();
    final isEmpty = trimmed.isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2B2B2B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isEmpty ? 'No data' : trimmed,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: isEmpty ? const Color(0xFF9CA3AF) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // Edit-mode row (erow) — simple text field
  Widget _eRow({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool requiredField = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2B2B2B),
                letterSpacing: 0.5,
              ),
              children: requiredField
                  ? const [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]
                  : const [],
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(107, 33, 200, 0.04),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: const Color.fromRGBO(107, 33, 200, 0.25),
                width: 1.5,
              ),
            ).toInputDecoration(),
          ),
        ],
      ),
    );
  }

  // Detail view row inside section-card
  Widget _detailVRow(String label, String value) {
    final trimmed = value.trim();
    final isEmpty = trimmed.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2B2B2B),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F7FD),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE9E3F5)),
          ),
          child: Text(
            isEmpty ? 'No data' : trimmed,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isEmpty ? const Color(0xFF9CA3AF) : Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  // Detail edit row (input)
  Widget _detailERow({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2B2B2B),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(107, 33, 200, 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color.fromRGBO(107, 33, 200, 0.22),
              width: 1.5,
            ),
          ).toInputDecoration(),
        ),
      ],
    );
  }

  // Advisory section card (view/edit)
  Widget _advisoryCard(int index) {
    final adv = _advisoryDetails[index];
    final keyConcern = (adv['keyConcern'] ?? '').toString();
    final recommendation =
        (adv['productRecommendation'] ?? adv['recommendation'] ?? '').toString();
    final bool isOpen = _advExpanded[index] ?? false;

    final keyConcernController =
        TextEditingController(text: keyConcern); // for edit
    final recommendationController =
        TextEditingController(text: recommendation); // for edit

    String headerLabel;
    if (keyConcern.isEmpty) {
      headerLabel = 'Advisory Detail ${index + 1}';
    } else {
      headerLabel = keyConcern.length > 40
          ? '${keyConcern.substring(0, 40)}…'
          : keyConcern;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _advExpanded[index] = !isOpen;
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                gradient: LinearGradient(
                  colors: [
                    Color.fromRGBO(107, 33, 200, 0.07),
                    Color.fromRGBO(156, 64, 255, 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4A2371), Color(0xFF5958B2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      headerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF5958B2),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Color(0xFF5958B2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isEditMode)
                    _detailERow(
                      label: 'Key Concerns',
                      controller: keyConcernController,
                    )
                  else
                    _detailVRow('Key Concerns', keyConcern),
                  const SizedBox(height: 8),
                  if (_isEditMode)
                    _detailERow(
                      label: 'Product Recommendation',
                      controller: recommendationController,
                    )
                  else
                    _detailVRow('Product Recommendation', recommendation),
                ],
              ),
            ),
            crossFadeState:
                isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  // Product section card (view/edit)
  Widget _productCard(int index) {
    final prod = _products[index];
    final productName = (prod['productName'] ?? '').toString();
    final quantity = (prod['quantity'] ?? '').toString();
    final packaging = (prod['packaging'] ?? '').toString();
    final bool isOpen = _prodExpanded[index] ?? false;

    final productNameController =
        TextEditingController(text: productName); // edit
    final quantityController = TextEditingController(text: quantity); // edit
    final packagingController = TextEditingController(text: packaging); // edit

    final headerLabel =
        productName.isEmpty ? 'Product ${index + 1}' : productName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _prodExpanded[index] = !isOpen;
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                gradient: LinearGradient(
                  colors: [
                    Color.fromRGBO(107, 33, 200, 0.07),
                    Color.fromRGBO(156, 64, 255, 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4A2371), Color(0xFF5958B2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      headerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF5958B2),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Color(0xFF5958B2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isEditMode)
                    _detailERow(
                      label: 'Product Name',
                      controller: productNameController,
                    )
                  else
                    _detailVRow('Product Name', productName),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _isEditMode
                            ? _detailERow(
                                label: 'Quantity',
                                controller: quantityController,
                                keyboardType: TextInputType.number,
                              )
                            : _detailVRow('Quantity', quantity),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isEditMode
                            ? _detailERow(
                                label: 'Packaging',
                                controller: packagingController,
                              )
                            : _detailVRow('Packaging', packaging),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState:
                isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String appTitle =
        _farmerNameController.text.trim().isEmpty ? 'Crop Prescription' : _farmerNameController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F5FF),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: AppBar(
          elevation: 6,
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(22),
              ),
              gradient: LinearGradient(
                colors: [Color(0xFF4A2371), Color(0xFF4A2371), Color(0xFF5958B2)],
                stops: [0, 0.55, 1],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(76, 29, 149, 0.3),
                  blurRadius: 28,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isEditMode
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: Colors.white,
                    disabledColor: Colors.white.withOpacity(0.3),
                    padding: const EdgeInsets.all(0),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sample Crop Prescription',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color.fromRGBO(255, 255, 255, 0.7),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          appTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isEditMode = !_isEditMode;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      backgroundColor:
                          const Color.fromRGBO(255, 255, 255, 0.22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      _isEditMode ? 'Cancel' : 'Edit',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            _isEditMode ? FontWeight.w600 : FontWeight.w700,
                        color: _isEditMode
                            ? const Color.fromRGBO(255, 255, 255, 0.65)
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // General information
                _sectionLabel('General Information', first: true),
                _formCard(
                  Column(
                    children: [
                      _isEditMode
                          ? _eRow(
                              label: 'Name of Farmer',
                              controller: _farmerNameController,
                              requiredField: true,
                            )
                          : _vRow(
                              'Farmer Name', _farmerNameController.text),
                      _isEditMode
                          ? _eRow(
                              label: 'Date of Event',
                              controller: _dateOfEventController,
                              requiredField: true,
                            )
                          : _vRow(
                              'Date of Event', _dateOfEventController.text),
                      Row(
                        children: [
                          Expanded(
                            child: _isEditMode
                                ? _eRow(
                                    label: 'Farm Address',
                                    controller: _farmAddressController,
                                    requiredField: true,
                                  )
                                : _vRow('Farm Address',
                                    _farmAddressController.text),
                          ),
                          Expanded(
                            child: _isEditMode
                                ? _eRow(
                                    label: 'Type of Event',
                                    controller: _typeOfEventController,
                                    requiredField: true,
                                  )
                                : _vRow('Type of Event',
                                    _typeOfEventController.text),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _isEditMode
                                ? _eRow(
                                    label: 'Cellphone Number',
                                    controller: _cellphoneNumberController,
                                    keyboardType: TextInputType.phone,
                                    requiredField: true,
                                  )
                                : _vRow('Cellphone Number',
                                    _cellphoneNumberController.text),
                          ),
                          Expanded(
                            child: _isEditMode
                                ? _eRow(
                                    label: 'Venue of Event',
                                    controller: _venueOfEventController,
                                    requiredField: true,
                                  )
                                : _vRow('Venue of Event',
                                    _venueOfEventController.text),
                          ),
                        ],
                      ),
                      _isEditMode
                          ? _eRow(
                              label: 'Crops Planted',
                              controller: _cropsPlantedController,
                              requiredField: true,
                            )
                          : _vRow(
                              'Crops Planted', _cropsPlantedController.text),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Advisory details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text(
                        'Advisory Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5958B2),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    if (_isEditMode)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          backgroundColor: const Color(0xFF4A2371),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          setState(() {
                            _advisoryDetails.add({
                              'keyConcern': '',
                              'productRecommendation': '',
                            });
                          });
                        },
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text(
                          'Add Advisory',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_advisoryDetails.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'No advisory details recorded.',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  Column(
                    children: List.generate(
                      _advisoryDetails.length,
                      (index) => _advisoryCard(index),
                    ),
                  ),
                const SizedBox(height: 16),

                // Crop advisor info
                _sectionLabel('Crop Advisor Information'),
                _formCard(
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _isEditMode
                                ? _eRow(
                                    label: 'Name of Crop Advisor',
                                    controller: _cropAdvisorNameController,
                                    requiredField: true,
                                  )
                                : _vRow('Name of Crop Advisor',
                                    _cropAdvisorNameController.text),
                          ),
                          Expanded(
                            child: _isEditMode
                                ? _eRow(
                                    label: 'Crop Advisor Contact Number',
                                    controller: _cropAdvisorContactController,
                                    keyboardType: TextInputType.phone,
                                    requiredField: true,
                                  )
                                : _vRow(
                                    'Crop Advisor Contact Number',
                                    _cropAdvisorContactController.text),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Products
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text(
                        'Indofil Crop Solutions & Technologies',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5958B2),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    if (_isEditMode)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          backgroundColor: const Color(0xFF4A2371),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          setState(() {
                            _products.add({
                              'productName': '',
                              'quantity': '',
                              'packaging': '',
                            });
                          });
                        },
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text(
                          'Add Product',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'No products recorded.',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  Column(
                    children: List.generate(
                      _products.length,
                      (index) => _productCard(index),
                    ),
                  ),
                const SizedBox(height: 16),

                // Farmer acknowledgment
                _sectionLabel('Farmer Acknowledgment'),
                _formCard(
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      children: [
                        _isEditMode
                            ? _eRow(
                                label: 'Name of Farmer (Signature Section)',
                                controller: _farmerNameSecondController,
                                requiredField: true,
                              )
                            : _vRow('Name of Farmer',
                                _farmerNameSecondController.text),
                        _isEditMode
                            ? _eRow(
                                label: 'Date Needed',
                                controller: _dateNeededController,
                                requiredField: true,
                              )
                            : _vRow(
                                'Date Needed', _dateNeededController.text),
                        _isEditMode
                            ? _eRow(
                                label: 'Preferred Dealer',
                                controller: _preferredDealerController,
                                requiredField: true,
                              )
                            : _vRow('Preferred Dealer',
                                _preferredDealerController.text),
                        // Signature
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: const TextSpan(
                                  text: 'Signature of Farmer',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2B2B2B),
                                    letterSpacing: 0.5,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: ' *',
                                      style: TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: const Color(0xFFE9E3F5),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: IgnorePointer(
                                    ignoring: !_isEditMode,
                                    child: Signature(
                                      controller: _farmerSignatureController,
                                      width: double.infinity,
                                      height: 100,
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              if (_isEditMode)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      _farmerSignatureController.clear();
                                    },
                                    child: const Text(
                                      'Clear Signature',
                                      style: TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 12.5,
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
                ),
                const SizedBox(height: 72),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _isEditMode
          ? Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FloatingActionButton.extended(
                onPressed: _saveChanges,
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text(
                  'Update Form',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: const Color(0xFF4A2371),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
                                              fontWeight:
                                                  FontWeight.w600,
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
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (cropsPlanted.isNotEmpty)
                                            Text(
                                              'Crop: $cropsPlanted',
                                              maxLines: 1,
                                              overflow: TextOverflow
                                                  .ellipsis,
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
