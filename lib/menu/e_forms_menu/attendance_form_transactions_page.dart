import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'attendance_form_page.dart';
import 'package:signature/signature.dart';

/// Detail page: view attendance + attendee signatures and full data
class AttendanceFormReadonlyPage extends StatefulWidget {
  final Map<String, dynamic> formData;
  final String docId;
  final String userKey;

  AttendanceFormReadonlyPage({
    required this.formData,
    required this.docId,
    required this.userKey,
  });

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

  // Controllers for attendee extra fields (parallel to _attendees / rows)
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
    _dealersController =
        TextEditingController(text: _dealers.join(', '));
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
      _addressControllers.add(TextEditingController(
          text: (row['address'] ?? '').toString()));
      _telephoneControllers.add(TextEditingController(
          text: (row['telephone'] ?? '').toString()));
      _hectaresControllers.add(TextEditingController(
          text: (row['hectares'] ?? '').toString()));
      _cropControllers.add(
          TextEditingController(text: (row['crop'] ?? '').toString()));
      _insecticideControllers.add(TextEditingController(
          text: (row['insecticide'] ?? '').toString()));
      _fungicideControllers.add(TextEditingController(
          text: (row['fungicide'] ?? '').toString()));
      _herbicideControllers.add(TextEditingController(
          text: (row['herbicide'] ?? '').toString()));
      _nutritionControllers.add(TextEditingController(
          text: (row['nutrition'] ?? '').toString()));
      _dealerSourceControllers.add(TextEditingController(
          text: (row['dealerSource'] ?? '').toString()));
      _facebookLinkControllers.add(TextEditingController(
          text: (row['facebookLink'] ?? '').toString()));
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

      // Try to find matching signature entry by name
      Map<String, dynamic>? entry;
      for (final item in signaturesRaw) {
        if (item is Map && item['name'] == name) {
          entry = Map<String, dynamic>.from(item);
          break;
        }
      }

      // Load points if present
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

    // If there were no attendee names saved, derive rows from _attendees or create one empty row
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

    // Ensure attendee parallel lists have same length as rows
    final int rows = _maxAttendeeRows();
    void _ensureListLength(List<TextEditingController> list) {
      while (list.length < rows) {
        list.add(TextEditingController());
      }
    }

    _ensureListLength(_addressControllers);
    _ensureListLength(_telephoneControllers);
    _ensureListLength(_hectaresControllers);
    _ensureListLength(_cropControllers);
    _ensureListLength(_insecticideControllers);
    _ensureListLength(_fungicideControllers);
    _ensureListLength(_herbicideControllers);
    _ensureListLength(_nutritionControllers);
    _ensureListLength(_dealerSourceControllers);
    _ensureListLength(_facebookLinkControllers);
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

      // Also create empty row map so _attendees length stays in sync
      _attendees.add(<String, dynamic>{});
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
      // Build attendeeNames from the editable controllers
      final List<String> updatedNames = _nameControllers
          .map((c) => c.text.trim())
          .where((name) => name.isNotEmpty)
          .toList();

      // Build updated attendees rows from controllers
      final List<Map<String, dynamic>> updatedAttendees = [];
      final int rows = _maxAttendeeRows();
      for (int i = 0; i < rows; i++) {
        final String name =
            i < _nameControllers.length ? _nameControllers[i].text.trim() : '';
        final String address =
            i < _addressControllers.length ? _addressControllers[i].text.trim() : '';
        final String tel =
            i < _telephoneControllers.length ? _telephoneControllers[i].text.trim() : '';
        final String hectares =
            i < _hectaresControllers.length ? _hectaresControllers[i].text.trim() : '';
        final String crop =
            i < _cropControllers.length ? _cropControllers[i].text.trim() : '';
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

        // Skip completely empty rows
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

      // Parse dealers and focus products from comma-separated text fields
      final List<String> updatedDealers = _dealersController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final List<String> updatedFocusProducts = _focusProductsController.text
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
        SnackBar(
          content: Text('Form updated successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating form: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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

  @override
  Widget build(BuildContext context) {
    final data = widget.formData;
    final String createdBy = data['createdBy'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text("Attendance Form (Detail)"),
        backgroundColor: Color(0xFF5958b2),
        actions: [
          IconButton(
            icon: Icon(_isEditMode ? Icons.close : Icons.edit),
            tooltip: _isEditMode ? 'Cancel edit' : 'Edit',
            onPressed: _toggleEditMode,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Top card: basic details
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
                      "Attendance Details",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5958b2),
                      ),
                    ),
                    SizedBox(height: 18),
                    _editableField(
                      label: "Event Name",
                      controller: _eventNameController,
                    ),
                    _editableField(
                      label: "Crop Focus",
                      controller: _cropFocusController,
                    ),
                    _editableField(
                      label: "Crop Status",
                      controller: _cropStatusController,
                    ),
                    _editableField(
                      label: "Date",
                      controller: _dateController,
                    ),
                    _editableField(
                      label: "Location",
                      controller: _locationController,
                    ),
                    _editableField(
                      label: "Remarks",
                      controller: _remarksController,
                      maxLines: 3,
                    ),
                    _editableField(
                      label: "Name of Dealers",
                      controller: _dealersController,
                    ),
                    _editableField(
                      label: "Focus Products",
                      controller: _focusProductsController,
                    ),
                    if (createdBy.isNotEmpty)
                      _readonlyField("Created By", createdBy),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // Attendees card with table and signatures
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
                    Row(
                      children: [
                        Text(
                          "Attendees",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          height: 26,
                          width: 26,
                          child: ElevatedButton(
                            onPressed: _isEditMode ? _addAttendeeRow : null,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: CircleBorder(),
                              backgroundColor: _isEditMode
                                  ? Color(0xFF5958b2)
                                  : Colors.grey,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade400,
                            ),
                            child: Icon(
                              Icons.add,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),

                    // Attendee table-like view
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row
                          Row(
                            children: const [
                              _AttendeeHeaderCell("Name of Farmer"),
                              _AttendeeHeaderCell("Address"),
                              _AttendeeHeaderCell("Telephone / CP No."),
                              _AttendeeHeaderCell("Number of Hectares"),
                              _AttendeeHeaderCell("Crop"),
                              _AttendeeHeaderCell("Insecticide"),
                              _AttendeeHeaderCell("Fungicide"),
                              _AttendeeHeaderCell("Herbicide"),
                              _AttendeeHeaderCell("Crop Nutrition/Follar"),
                              _AttendeeHeaderCell("Dealer Name (Source)"),
                              _AttendeeHeaderCell("Facebook Link"),
                              _AttendeeHeaderCell("Signature"),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Rows
                          Column(
                            children: List.generate(
                              _maxAttendeeRows(),
                              (index) {
                                final rowData =
                                    index < _attendees.length
                                        ? _attendees[index]
                                        : <String, dynamic>{};

                                final SignatureController? sigController =
                                    index < _signatureControllers.length
                                        ? _signatureControllers[index]
                                        : null;

                                final String name =
                                    index < _nameControllers.length
                                        ? _nameControllers[index].text
                                        : (rowData['name']?.toString() ?? '');
                                final String address =
                                    index < _addressControllers.length
                                        ? _addressControllers[index].text
                                        : (rowData['address']?.toString() ?? '');
                                final String tel =
                                    index < _telephoneControllers.length
                                        ? _telephoneControllers[index].text
                                        : (rowData['telephone']?.toString() ?? '');
                                final String hectares =
                                    index < _hectaresControllers.length
                                        ? _hectaresControllers[index].text
                                        : (rowData['hectares']?.toString() ?? '');
                                final String crop =
                                    index < _cropControllers.length
                                        ? _cropControllers[index].text
                                        : (rowData['crop']?.toString() ?? '');
                                final String insecticide =
                                    index < _insecticideControllers.length
                                        ? _insecticideControllers[index].text
                                        : (rowData['insecticide']?.toString() ?? '');
                                final String fungicide =
                                    index < _fungicideControllers.length
                                        ? _fungicideControllers[index].text
                                        : (rowData['fungicide']?.toString() ?? '');
                                final String herbicide =
                                    index < _herbicideControllers.length
                                        ? _herbicideControllers[index].text
                                        : (rowData['herbicide']?.toString() ?? '');
                                final String nutrition =
                                    index < _nutritionControllers.length
                                        ? _nutritionControllers[index].text
                                        : (rowData['nutrition']?.toString() ?? '');
                                final String dealerSource =
                                    index < _dealerSourceControllers.length
                                        ? _dealerSourceControllers[index].text
                                        : (rowData['dealerSource']?.toString() ?? '');
                                final String facebookLink =
                                    index < _facebookLinkControllers.length
                                        ? _facebookLinkControllers[index].text
                                        : (rowData['facebookLink']?.toString() ?? '');

                                // If everything is empty and index >= actual data length, do not show extra rows
                                final bool isTrulyEmptyRow =
                                    index >= _attendees.length &&
                                        name.isEmpty &&
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

                                if (isTrulyEmptyRow) {
                                  return const SizedBox.shrink();
                                }

                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _AttendeeDataCell(
                                        TextField(
                                          controller:
                                              _nameControllers[index],
                                          readOnly: !_isEditMode,
                                          decoration:
                                              const InputDecoration(
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _AttendeeDataCell(
                                        TextField(
                                          controller:
                                              _addressControllers[index],
                                          readOnly: !_isEditMode,
                                          maxLines: 2,
                                          decoration:
                                              const InputDecoration(
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _AttendeeDataCell(
                                        TextField(
                                          controller:
                                              _telephoneControllers[index],
                                          readOnly: !_isEditMode,
                                          decoration:
                                              const InputDecoration(
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _AttendeeDataCell(
                                        TextField(
                                          controller:
                                              _hectaresControllers[index],
                                          readOnly: !_isEditMode,
                                          decoration:
                                              const InputDecoration(
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _AttendeeDataCell(
                                        TextField(
                                          controller:
                                              _cropControllers[index],
                                          readOnly: !_isEditMode,
                                          maxLines: 2,
                                          decoration:
                                              const InputDecoration(
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _AttendeeDataCell(
                                        TextField(
                                          controller:
                                              _insecticideControllers[index],
                                          readOnly: !_isEditMode,
                                          maxLines: 2,
                                          decoration:
                                              const InputDecoration(
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _AttendeeDataCell(
                                        TextField(
                                          controller:
                                              _fungicideControllers[index],
                                          readOnly: !_isEditMode,
                                          maxLines: 2,
                                          decoration:
                                              const InputDecoration(
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _AttendeeDataCell(
                                        TextField(
                                          controller:
                                              _herbicideControllers[index],
                                          readOnly: !_isEditMode,
                                          maxLines: 2,
                                          decoration:
                                              const InputDecoration(
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _AttendeeDataCell(
                                        TextField(
                                          controller:
                                              _nutritionControllers[index],
                                          readOnly: !_isEditMode,
                                          maxLines: 2,
                                          decoration:
                                              const InputDecoration(
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _AttendeeDataCell(
                                        TextField(
                                          controller:
                                              _dealerSourceControllers[index],
                                          readOnly: !_isEditMode,
                                          maxLines: 2,
                                          decoration:
                                              const InputDecoration(
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _AttendeeDataCell(
                                        TextField(
                                          controller:
                                              _facebookLinkControllers[index],
                                          readOnly: !_isEditMode,
                                          maxLines: 2,
                                          decoration:
                                              const InputDecoration(
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _AttendeeDataCell(
                                        sigController == null
                                            ? const SizedBox.shrink()
                                            : Column(
                                                children: [
                                                  Container(
                                                    decoration:
                                                        BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(8),
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                      ),
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                                  8),
                                                      child: IgnorePointer(
                                                        ignoring:
                                                            !_isEditMode,
                                                        child: Signature(
                                                          controller:
                                                              sigController,
                                                          width:
                                                              double.infinity,
                                                          height: 80,
                                                          backgroundColor:
                                                              Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (_isEditMode)
                                                    TextButton(
                                                      onPressed: () =>
                                                          _clearSignatureAt(
                                                              index),
                                                      child: const Text(
                                                        'Clear',
                                                        style: TextStyle(
                                                          fontSize: 12,
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
                    SizedBox(height: 80), // space above floating Update button
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isEditMode
          ? FloatingActionButton.extended(
              backgroundColor: Color(0xFF5958b2),
              onPressed: _updateSignatures,
              label: Text(
                'Update',
                style: TextStyle(color: Colors.white),
              ),
              icon: Icon(Icons.check, color: Colors.white),
            )
          : null,
    );
  }

  int _maxAttendeeRows() {
    return _attendees.length > _nameControllers.length
        ? _attendees.length
        : _nameControllers.length;
  }

  Widget _editableField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            readOnly: !_isEditMode,
            maxLines: maxLines,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.cyan.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readonlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontWeight: FontWeight.w600)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10),
            margin: EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.cyan.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small helpers for the attendee table in the detail page
class _AttendeeHeaderCell extends StatelessWidget {
  final String label;
  const _AttendeeHeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 2),
      padding:
          const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF52bb5f),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _AttendeeDataCell extends StatelessWidget {
  final Widget child;
  const _AttendeeDataCell(this.child);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 80,
      margin: const EdgeInsets.only(right: 2),
      child: Center(child: child),
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
      userKey =
          userEmail.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_');
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

                      // Descending transaction number (first cell = highest)
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
                                            overflow: TextOverflow
                                                .ellipsis,
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
