import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'attendance_form_page.dart';
import 'package:signature/signature.dart';

/// Small helper to create a filled InputDecoration similar to your web design.
InputDecoration _filledDecoration({
  String? hintText,
  EdgeInsets contentPadding =
      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
}) {
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: const Color.fromRGBO(107, 33, 200, 0.04),
    hintStyle: const TextStyle(
      color: Color(0xFFB0A8C8),
      fontWeight: FontWeight.w400,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(
        color: Color.fromRGBO(107, 33, 200, 0.25),
        width: 1.5,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(
        color: Color.fromRGBO(107, 33, 200, 0.25),
        width: 1.5,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(
        color: Color(0xFF5958B2),
        width: 1.6,
      ),
    ),
    isDense: true,
    contentPadding: contentPadding,
  );
}

/// Detail page: view attendance + attendee signatures and full data (restyled).
class AttendanceFormReadonlyPage extends StatefulWidget {
  final Map<String, dynamic> formData;
  final String docId;
  final String userKey;

  AttendanceFormReadonlyPage({
    Key? key,
    required this.formData,
    required this.docId,
    required this.userKey,
  }) : super(key: key);

  @override
  State<AttendanceFormReadonlyPage> createState() =>
      _AttendanceFormReadonlyPageState();
}

class _AttendanceFormReadonlyPageState
    extends State<AttendanceFormReadonlyPage> {
  // Signature + attendee name controllers
  late List<SignatureController> _signatureControllers;
  late List<TextEditingController> _nameControllers;
  late List<String> _attendeeNames;

  // Parsed attendees and other fields
  late List<Map<String, dynamic>> _attendees;
  late List<String> _dealers;
  late List<String> _focusProducts;
  late String _cropFocus;
  late String _cropStatus;

  // Edit mode flag
  bool _isEditMode = false;

  // Controllers for Attendance Details fields
  late TextEditingController _eventNameController;
  late TextEditingController _cropFocusController;
  late TextEditingController _cropStatusController;
  late TextEditingController _dateController;
  late TextEditingController _locationController;
  late TextEditingController _remarksController;
  late TextEditingController _dealersController;
  late TextEditingController _focusProductsController;

  // Controllers for attendee extra fields
  late List<TextEditingController> _addressControllers;
  late List<TextEditingController> _telephoneControllers;
  late List<TextEditingController> _hectaresControllers;
  late List<TextEditingController> _cropControllers;
  late List<TextEditingController> _insecticideControllers;
  late List<TextEditingController> _fungicideControllers;
  late List<TextEditingController> _herbicideControllers;
  late List<TextEditingController> _nutritionControllers;
  late List<TextEditingController> _dealerSourceControllers;
  late List<TextEditingController> _facebookLinkControllers;

  // Local expand state for attendees
  final Map<int, bool> _attExpanded = {};

  @override
  void initState() {
    super.initState();
    _initializeFromData();
  }

  void _initializeFromData() {
    final data = widget.formData;

    // Initialize main fields
    _cropFocus = (data['cropFocus'] ?? '').toString();
    _cropStatus = (data['cropStatus'] ?? '').toString();

    final List<dynamic> rawDealers = data['dealers'] ?? [];
    _dealers = rawDealers.map((e) => e.toString()).toList();

    final List<dynamic> rawFocusProducts = data['focusProducts'] ?? [];
    _focusProducts = rawFocusProducts.map((e) => e.toString()).toList();

    final List<dynamic> attendeesRaw = data['attendees'] ?? [];
    _attendees = attendeesRaw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();

    _initializeDetailControllers(data);
    _initializeAttendeeControllers();
    _initializeSignaturesAndNames(data);
  }

  void _initializeDetailControllers(Map<String, dynamic> data) {
    _eventNameController =
        TextEditingController(text: (data['eventName'] ?? '').toString());
    _cropFocusController =
        TextEditingController(text: (data['cropFocus'] ?? '').toString());
    _cropStatusController =
        TextEditingController(text: (data['cropStatus'] ?? '').toString());
    _dateController =
        TextEditingController(text: (data['date'] ?? '').toString());
    _locationController =
        TextEditingController(text: (data['location'] ?? '').toString());
    _remarksController =
        TextEditingController(text: (data['remarks'] ?? '').toString());
    _dealersController = TextEditingController(text: _dealers.join(', '));
    _focusProductsController =
        TextEditingController(text: _focusProducts.join(', '));
  }

  void _initializeAttendeeControllers() {
    _addressControllers = [];
    _telephoneControllers = [];
    _hectaresControllers = [];
    _cropControllers = [];
    _insecticideControllers = [];
    _fungicideControllers = [];
    _herbicideControllers = [];
    _nutritionControllers = [];
    _dealerSourceControllers = [];
    _facebookLinkControllers = [];

    for (final row in _attendees) {
      _addressControllers.add(
          TextEditingController(text: (row['address'] ?? '').toString()));
      _telephoneControllers.add(
          TextEditingController(text: (row['telephone'] ?? '').toString()));
      _hectaresControllers.add(
          TextEditingController(text: (row['hectares'] ?? '').toString()));
      _cropControllers
          .add(TextEditingController(text: (row['crop'] ?? '').toString()));
      _insecticideControllers.add(
          TextEditingController(text: (row['insecticide'] ?? '').toString()));
      _fungicideControllers.add(
          TextEditingController(text: (row['fungicide'] ?? '').toString()));
      _herbicideControllers.add(
          TextEditingController(text: (row['herbicide'] ?? '').toString()));
      _nutritionControllers.add(
          TextEditingController(text: (row['nutrition'] ?? '').toString()));
      _dealerSourceControllers.add(
          TextEditingController(text: (row['dealerSource'] ?? '').toString()));
      _facebookLinkControllers.add(
          TextEditingController(text: (row['facebookLink'] ?? '').toString()));
    }
  }

  void _initializeSignaturesAndNames(Map<String, dynamic> data) {
    final List<dynamic> namesRaw = data['attendeeNames'] ?? [];
    if (namesRaw.isNotEmpty) {
      _attendeeNames = namesRaw.map((e) => e.toString()).toList();
    } else {
      _attendeeNames = _attendees
          .map((row) => (row['name'] ?? '').toString())
          .where((name) => name.isNotEmpty)
          .toList();
    }

    final List<dynamic> signaturesRaw = data['attendeeSignatures'] ?? [];

    _signatureControllers = [];
    _nameControllers = [];

    for (int index = 0; index < _attendeeNames.length; index++) {
      final name = _attendeeNames[index];

      final nameController = TextEditingController(text: name);
      _nameControllers.add(nameController);

      final controller = SignatureController(
        penStrokeWidth: 3,
        penColor: Colors.black,
        exportBackgroundColor: Colors.white,
      );

      Map<String, dynamic>? entry;
      for (final item in signaturesRaw) {
        if (item is Map && item['name'] == name) {
          entry = Map<String, dynamic>.from(item);
          break;
        }
      }

      if (entry != null && entry['points'] is List) {
        final List pointsRaw = entry['points'];
        final List<Point> pts = [];
        for (final p in pointsRaw) {
          if (p is Map) {
            final double? x = (p['x'] as num?)?.toDouble();
            final double? y = (p['y'] as num?)?.toDouble();
            if (x == null || y == null) continue;

            final String typeStr =
                (p['type'] as String?) ?? 'PointType.tap';
            PointType type;
            switch (typeStr) {
              case 'PointType.move':
                type = PointType.move;
                break;
              default:
                type = PointType.tap;
            }

            final double pressure =
                (p['pressure'] as num?)?.toDouble() ?? 1.0;

            pts.add(Point(Offset(x, y), type, pressure));
          }
        }
        if (pts.isNotEmpty) {
          controller.points = pts;
        }
      }

      _signatureControllers.add(controller);
    }

    if (_attendeeNames.isEmpty) {
      if (_attendees.isNotEmpty) {
        for (final row in _attendees) {
          final name = (row['name'] ?? '').toString();
          _attendeeNames.add(name);
          _nameControllers.add(TextEditingController(text: name));
          _signatureControllers.add(
            SignatureController(
              penStrokeWidth: 3,
              penColor: Colors.black,
              exportBackgroundColor: Colors.white,
            ),
          );
        }
      } else {
        _attendeeNames = [];
        _nameControllers.add(TextEditingController());
        _signatureControllers.add(
          SignatureController(
            penStrokeWidth: 3,
            penColor: Colors.black,
            exportBackgroundColor: Colors.white,
          ),
        );
      }
    }

    final int rows = _maxAttendeeRows();
    void ensureListLength(List<TextEditingController> list) {
      while (list.length < rows) {
        list.add(TextEditingController());
      }
    }

    ensureListLength(_addressControllers);
    ensureListLength(_telephoneControllers);
    ensureListLength(_hectaresControllers);
    ensureListLength(_cropControllers);
    ensureListLength(_insecticideControllers);
    ensureListLength(_fungicideControllers);
    ensureListLength(_herbicideControllers);
    ensureListLength(_nutritionControllers);
    ensureListLength(_dealerSourceControllers);
    ensureListLength(_facebookLinkControllers);
  }

  @override
  void dispose() {
    for (final c in _signatureControllers) {
      c.dispose();
    }
    for (final n in _nameControllers) {
      n.dispose();
    }

    _eventNameController.dispose();
    _cropFocusController.dispose();
    _cropStatusController.dispose();
    _dateController.dispose();
    _locationController.dispose();
    _remarksController.dispose();
    _dealersController.dispose();
    _focusProductsController.dispose();

    for (final c in _addressControllers) {
      c.dispose();
    }
    for (final c in _telephoneControllers) {
      c.dispose();
    }
    for (final c in _hectaresControllers) {
      c.dispose();
    }
    for (final c in _cropControllers) {
      c.dispose();
    }
    for (final c in _insecticideControllers) {
      c.dispose();
    }
    for (final c in _fungicideControllers) {
      c.dispose();
    }
    for (final c in _herbicideControllers) {
      c.dispose();
    }
    for (final c in _nutritionControllers) {
      c.dispose();
    }
    for (final c in _dealerSourceControllers) {
      c.dispose();
    }
    for (final c in _facebookLinkControllers) {
      c.dispose();
    }

    super.dispose();
  }

  void _addAttendeeRow() {
    if (!_isEditMode) return;
    setState(() {
      _attendeeNames.add('');
      _nameControllers.add(TextEditingController());
      _signatureControllers.add(
        SignatureController(
          penStrokeWidth: 3,
          penColor: Colors.black,
          exportBackgroundColor: Colors.white,
        ),
      );

      _addressControllers.add(TextEditingController());
      _telephoneControllers.add(TextEditingController());
      _hectaresControllers.add(TextEditingController());
      _cropControllers.add(TextEditingController());
      _insecticideControllers.add(TextEditingController());
      _fungicideControllers.add(TextEditingController());
      _herbicideControllers.add(TextEditingController());
      _nutritionControllers.add(TextEditingController());
      _dealerSourceControllers.add(TextEditingController());
      _facebookLinkControllers.add(TextEditingController());

      _attendees.add(<String, dynamic>{});
      _attExpanded[_attendeeNames.length - 1] = true;
    });
  }

  Future<List<Map<String, dynamic>>> _exportAllSignatures() async {
    final List<Map<String, dynamic>> result = [];

    for (int i = 0; i < _nameControllers.length; i++) {
      final String name = _nameControllers[i].text.trim();
      final SignatureController sc = _signatureControllers[i];

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

  Future<void> _updateSignatures() async {
    if (!_isEditMode) return;

    try {
      final List<String> updatedNames = _nameControllers
          .map((c) => c.text.trim())
          .where((name) => name.isNotEmpty)
          .toList();

      final List<Map<String, dynamic>> updatedAttendees = [];
      final int rows = _maxAttendeeRows();
      for (int i = 0; i < rows; i++) {
        final String name =
            i < _nameControllers.length ? _nameControllers[i].text.trim() : '';
        final String address = i < _addressControllers.length
            ? _addressControllers[i].text.trim()
            : '';
        final String tel = i < _telephoneControllers.length
            ? _telephoneControllers[i].text.trim()
            : '';
        final String hectares = i < _hectaresControllers.length
            ? _hectaresControllers[i].text.trim()
            : '';
        final String crop = i < _cropControllers.length
            ? _cropControllers[i].text.trim()
            : '';
        final String insecticide = i < _insecticideControllers.length
            ? _insecticideControllers[i].text.trim()
            : '';
        final String fungicide = i < _fungicideControllers.length
            ? _fungicideControllers[i].text.trim()
            : '';
        final String herbicide = i < _herbicideControllers.length
            ? _herbicideControllers[i].text.trim()
            : '';
        final String nutrition = i < _nutritionControllers.length
            ? _nutritionControllers[i].text.trim()
            : '';
        final String dealerSource = i < _dealerSourceControllers.length
            ? _dealerSourceControllers[i].text.trim()
            : '';
        final String facebookLink = i < _facebookLinkControllers.length
            ? _facebookLinkControllers[i].text.trim()
            : '';

        final bool isEmptyRow = name.isEmpty &&
            address.isEmpty &&
            tel.isEmpty &&
            hectares.isEmpty &&
            crop.isEmpty &&
            insecticide.isEmpty &&
            fungicide.isEmpty &&
            herbicide.isEmpty &&
            nutrition.isEmpty &&
            dealerSource.isEmpty &&
            facebookLink.isEmpty;

        if (isEmptyRow) continue;

        updatedAttendees.add({
          'name': name,
          'address': address,
          'telephone': tel,
          'hectares': hectares,
          'crop': crop,
          'insecticide': insecticide,
          'fungicide': fungicide,
          'herbicide': herbicide,
          'nutrition': nutrition,
          'dealerSource': dealerSource,
          'facebookLink': facebookLink,
        });
      }

      final signatures = await _exportAllSignatures();

      final List<String> updatedDealers = _dealersController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final List<String> updatedFocusProducts =
          _focusProductsController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

      final docRef = FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(widget.userKey)
          .doc('attendance_forms')
          .collection('attendance_forms')
          .doc(widget.docId);

      await docRef.update({
        'eventName': _eventNameController.text.trim(),
        'cropFocus': _cropFocusController.text.trim(),
        'cropStatus': _cropStatusController.text.trim(),
        'date': _dateController.text.trim(),
        'location': _locationController.text.trim(),
        'remarks': _remarksController.text.trim(),
        'dealers': updatedDealers,
        'focusProducts': updatedFocusProducts,
        'attendeeNames': updatedNames,
        'attendeeSignatures': signatures,
        'attendees': updatedAttendees,
      });

      setState(() {
        widget.formData['eventName'] = _eventNameController.text.trim();
        widget.formData['cropFocus'] = _cropFocusController.text.trim();
        widget.formData['cropStatus'] = _cropStatusController.text.trim();
        widget.formData['date'] = _dateController.text.trim();
        widget.formData['location'] = _locationController.text.trim();
        widget.formData['remarks'] = _remarksController.text.trim();
        widget.formData['dealers'] = updatedDealers;
        widget.formData['focusProducts'] = updatedFocusProducts;
        widget.formData['attendeeNames'] = updatedNames;
        widget.formData['attendeeSignatures'] = signatures;
        widget.formData['attendees'] = updatedAttendees;
        _attendees = updatedAttendees;
        _dealers = updatedDealers;
        _focusProducts = updatedFocusProducts;
        _isEditMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Form updated successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // ignore: avoid_print
      print('Error updating form: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating form. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearSignatureAt(int index) {
    if (!_isEditMode) return;
    setState(() {
      _signatureControllers[index].clear();
    });
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  int _maxAttendeeRows() {
    return _attendees.length > _nameControllers.length
        ? _attendees.length
        : _nameControllers.length;
  }

  Widget _secLabel(String text, {bool first = false}) {
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
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _vRow(String label, String value) {
    final trimmed = value.trim();
    final isEmpty = trimmed.isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          const SizedBox(height: 3),
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

  Widget _editableField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    bool requiredField = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            readOnly: !_isEditMode,
            maxLines: maxLines,
            decoration: _filledDecoration(),
          ),
        ],
      ),
    );
  }

  Widget _readonlyField(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F7FD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE9E3F5)),
            ),
            child: Text(
              value.trim().isEmpty ? 'No data' : value,
              style: TextStyle(
                fontSize: 16,
                color: value.trim().isEmpty
                    ? const Color(0xFF9CA3AF)
                    : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendeeViewRow(String label, String value) {
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

  Widget _attendeeEditRow({
    required String label,
    required TextEditingController controller,
    bool requiredField = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2B2B2B),
              letterSpacing: 0.4,
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
        const SizedBox(height: 3),
        TextField(
          controller: controller,
          readOnly: !_isEditMode,
          decoration: _filledDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _attendeeCard(int index) {
    final rowData = index < _attendees.length
        ? _attendees[index]
        : <String, dynamic>{};

    final sigController = index < _signatureControllers.length
        ? _signatureControllers[index]
        : null;

    final nameController = index < _nameControllers.length
        ? _nameControllers[index]
        : TextEditingController();

    final addressController = _addressControllers[index];
    final telController = _telephoneControllers[index];
    final hectaresController = _hectaresControllers[index];
    final cropController = _cropControllers[index];
    final insecticideController = _insecticideControllers[index];
    final fungicideController = _fungicideControllers[index];
    final herbicideController = _herbicideControllers[index];
    final nutritionController = _nutritionControllers[index];
    final dealerController = _dealerSourceControllers[index];
    final fbController = _facebookLinkControllers[index];

    final bool isOpen = _attExpanded[index] ?? false;

    final headerLabel = nameController.text.trim().isEmpty
        ? 'Attendee ${index + 1}'
        : nameController.text.trim();

    final bool isTrulyEmptyRow =
        index >= _attendees.length &&
            nameController.text.trim().isEmpty &&
            addressController.text.trim().isEmpty &&
            telController.text.trim().isEmpty &&
            hectaresController.text.trim().isEmpty &&
            cropController.text.trim().isEmpty &&
            insecticideController.text.trim().isEmpty &&
            fungicideController.text.trim().isEmpty &&
            herbicideController.text.trim().isEmpty &&
            nutritionController.text.trim().isEmpty &&
            dealerController.text.trim().isEmpty &&
            fbController.text.trim().isEmpty;

    if (isTrulyEmptyRow) {
      return const SizedBox.shrink();
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
                _attExpanded[index] = !isOpen;
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        fontSize: 13,
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
                  if (_isEditMode)
                    IconButton(
                      onPressed: () {
                        if (!_isEditMode) return;
                        setState(() {
                          if (index < _attendees.length) {
                            _attendees.removeAt(index);
                          }
                          if (index < _nameControllers.length) {
                            _nameControllers.removeAt(index).dispose();
                          }
                          if (index < _signatureControllers.length) {
                            _signatureControllers.removeAt(index).dispose();
                          }
                          _addressControllers.removeAt(index).dispose();
                          _telephoneControllers.removeAt(index).dispose();
                          _hectaresControllers.removeAt(index).dispose();
                          _cropControllers.removeAt(index).dispose();
                          _insecticideControllers.removeAt(index).dispose();
                          _fungicideControllers.removeAt(index).dispose();
                          _herbicideControllers.removeAt(index).dispose();
                          _nutritionControllers.removeAt(index).dispose();
                          _dealerSourceControllers.removeAt(index).dispose();
                          _facebookLinkControllers.removeAt(index).dispose();
                          _attExpanded.remove(index);
                        });
                      },
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Color(0xFFDC2626),
                      ),
                      padding: const EdgeInsets.all(2),
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
                    _attendeeEditRow(
                      label: 'Full Name',
                      controller: nameController,
                      requiredField: true,
                    )
                  else
                    _attendeeViewRow(
                      'Full Name',
                      rowData['name']?.toString() ?? nameController.text,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _isEditMode
                            ? _attendeeEditRow(
                                label: 'Telephone / CP No.',
                                controller: telController,
                              )
                            : _attendeeViewRow(
                                'Telephone / CP No.',
                                rowData['telephone']?.toString() ??
                                    telController.text,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isEditMode
                            ? _attendeeEditRow(
                                label: 'Hectares',
                                controller: hectaresController,
                              )
                            : _attendeeViewRow(
                                'Hectares',
                                rowData['hectares']?.toString() ??
                                    hectaresController.text,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _isEditMode
                      ? _attendeeEditRow(
                          label: 'Address',
                          controller: addressController,
                        )
                      : _attendeeViewRow(
                          'Address',
                          rowData['address']?.toString() ??
                              addressController.text,
                        ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _isEditMode
                            ? _attendeeEditRow(
                                label: 'Crop',
                                controller: cropController,
                              )
                            : _attendeeViewRow(
                                'Crop',
                                rowData['crop']?.toString() ??
                                    cropController.text,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isEditMode
                            ? _attendeeEditRow(
                                label: 'Insecticide',
                                controller: insecticideController,
                              )
                            : _attendeeViewRow(
                                'Insecticide',
                                rowData['insecticide']?.toString() ??
                                    insecticideController.text,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _isEditMode
                            ? _attendeeEditRow(
                                label: 'Fungicide',
                                controller: fungicideController,
                              )
                            : _attendeeViewRow(
                                'Fungicide',
                                rowData['fungicide']?.toString() ??
                                    fungicideController.text,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isEditMode
                            ? _attendeeEditRow(
                                label: 'Herbicide',
                                controller: herbicideController,
                              )
                            : _attendeeViewRow(
                                'Herbicide',
                                rowData['herbicide']?.toString() ??
                                    herbicideController.text,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _isEditMode
                            ? _attendeeEditRow(
                                label: 'Crop Nutrition / Foliar',
                                controller: nutritionController,
                              )
                            : _attendeeViewRow(
                                'Crop Nutrition / Foliar',
                                rowData['nutrition']?.toString() ??
                                    nutritionController.text,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isEditMode
                            ? _attendeeEditRow(
                                label: 'Dealer Name (Source)',
                                controller: dealerController,
                              )
                            : _attendeeViewRow(
                                'Dealer Name (Source)',
                                rowData['dealerSource']?.toString() ??
                                    dealerController.text,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _isEditMode
                      ? _attendeeEditRow(
                          label: 'Facebook Link',
                          controller: fbController,
                        )
                      : _attendeeViewRow(
                          'Facebook Link',
                          rowData['facebookLink']?.toString() ??
                              fbController.text,
                        ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'SIGNATURE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2B2B2B),
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Text(
                        ' *',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: const Color(0xFFE9E3F5),
                        width: 1,
                      ),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: IgnorePointer(
                        ignoring: !_isEditMode,
                        child: sigController == null
                            ? const SizedBox.shrink()
                            : Signature(
                                controller: sigController,
                                width: double.infinity,
                                height: 80,
                                backgroundColor: Colors.white,
                              ),
                      ),
                    ),
                  ),
                  if (_isEditMode)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _clearSignatureAt(index),
                        child: const Text(
                          'Clear Signature',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
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
    final data = widget.formData;
    final String createdBy = data['createdBy'] ?? '';
    final String appTitle = _eventNameController.text.trim().isEmpty
        ? 'Attendance Form'
        : _eventNameController.text.trim();

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
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attendance Form',
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
                    onPressed: _toggleEditMode,
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
                _secLabel('Basic Information', first: true),
                _formCard(
                  Column(
                    children: [
                      _isEditMode
                          ? _editableField(
                              label: 'Event Name',
                              controller: _eventNameController,
                              requiredField: true,
                            )
                          : _vRow('Event Name', _eventNameController.text),
                      _isEditMode
                          ? _editableField(
                              label: 'Date',
                              controller: _dateController,
                              requiredField: true,
                            )
                          : _vRow('Date', _dateController.text),
                      _isEditMode
                          ? _editableField(
                              label: 'Location',
                              controller: _locationController,
                            )
                          : _vRow('Location', _locationController.text),
                      _isEditMode
                          ? _editableField(
                              label: 'Focus Products',
                              controller: _focusProductsController,
                            )
                          : _vRow('Focus Products',
                              _focusProductsController.text),
                      if (createdBy.isNotEmpty)
                        _readonlyField('Created By', createdBy),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _secLabel('Crop & Dealer Information'),
                _formCard(
                  Column(
                    children: [
                      _isEditMode
                          ? _editableField(
                              label: 'Crop Focus',
                              controller: _cropFocusController,
                            )
                          : _vRow('Crop Focus', _cropFocusController.text),
                      _isEditMode
                          ? _editableField(
                              label: 'Crop Status',
                              controller: _cropStatusController,
                            )
                          : _vRow('Crop Status', _cropStatusController.text),
                      _isEditMode
                          ? _editableField(
                              label: 'Name of Dealers',
                              controller: _dealersController,
                            )
                          : _vRow('Name of Dealers', _dealersController.text),
                      _isEditMode
                          ? _editableField(
                              label: 'Remarks',
                              controller: _remarksController,
                              maxLines: 3,
                            )
                          : _vRow('Remarks', _remarksController.text),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text(
                        'Attendees',
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
                        onPressed: _addAttendeeRow,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text(
                          'Add Attendee',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_maxAttendeeRows() == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'No attendees recorded.',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 15,
                      ),
                    ),
                  )
                else
                  Column(
                    children: List.generate(
                      _maxAttendeeRows(),
                      (index) => _attendeeCard(index),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isEditMode
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF4A2371),
              onPressed: _updateSignatures,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text(
                'Update Form',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }
}

// ======================
// Transactions Page
// ======================

class AttendanceFormTransactionsPage extends StatefulWidget {
  @override
  State<AttendanceFormTransactionsPage> createState() =>
      _AttendanceFormTransactionsPageState();
}

class _AttendanceFormTransactionsPageState
    extends State<AttendanceFormTransactionsPage> {
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

  Future<void> _navigateToAddForm(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AttendanceFormPage()),
    );
    if (result == true) setState(() {});
  }

  void _openDetail(
      BuildContext context, Map<String, dynamic> formData, String docId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceFormReadonlyPage(
          formData: formData,
          docId: docId,
          userKey: userKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double cardWidth =
        (MediaQuery.of(context).size.width - 48) / 2;
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
          title: const Text("Attendance Form Transactions"),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: "New Attendance Form",
              onPressed: () => _navigateToAddForm(context),
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
                  .doc('attendance_forms')
                  .collection('attendance_forms')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No attendance forms yet. Tap + to create a new.",
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 12),
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
                      final data =
                          doc.data() as Map<String, dynamic>;
                      final String eventName =
                          data["eventName"] ?? "";
                      final String date = data["date"] ?? "-";

                      final transactionNumber = docs.length - idx;
                      final transactionLabel =
                          "Event #$transactionNumber";

                      return SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () =>
                                _openDetail(context, data, doc.id),
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
                                          Icons.event_note,
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
                                            eventName.isNotEmpty
                                                ? eventName
                                                : "Unnamed Event",
                                            maxLines: 2,
                                            overflow: TextOverflow
                                                .ellipsis,
                                            style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Date: $date",
                                            maxLines: 1,
                                            overflow: TextOverflow
                                                .ellipsis,
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
