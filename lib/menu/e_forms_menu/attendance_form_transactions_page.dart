import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'attendance_form_page.dart';
import 'package:signature/signature.dart';

// Theme constants
const Color _kPrimary     = Color(0xFF5958B2);
const Color _kPrimaryDark = Color(0xFF4A2371);
const Color _kSurface     = Color(0xFFF9F5FF);
const Color _kCard        = Color(0xFFFFFFFF);
const Color _kBorder      = Color(0xFFE9E3F5);
const Color _kMuted       = Color(0xFF2B2B2B);
const Color _kRed         = Color(0xFFDC2626);
const Color _kGreen       = Color(0xFF059669);
const Color _kFieldFill   = Color(0x0A6B21C8);
const Color _kEmpty       = Color(0xFF9CA3AF);
const Color _kDivider     = Color(0xFFF0EBF9);

InputDecoration _attDeco({bool hasError = false, String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          color: Color(0xFFB0A8C8), 
          fontWeight: FontWeight.w400
      ),
      filled: true,
      fillColor: hasError 
          ? const Color(0x0ADC2626) 
          : _kFieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: hasError ? _kRed : _kPrimary.withValues(alpha: 0.25), width: 1.5)
      ),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: hasError ? _kRed : _kPrimary.withValues(alpha: 0.25), width: 1.5)
      ),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: hasError ? _kRed : _kPrimary, width: 1.6)
      ),
      isDense: true,
    );

InputDecoration _pfDeco({bool hasError = false, String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0A8C8), fontWeight: FontWeight.w400),
      filled: true,
      fillColor: hasError 
          ? const Color(0x0ADC2626) 
          : _kPrimary.withValues(alpha: 0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: hasError ? _kRed : _kPrimary.withValues(alpha: 0.22), width: 1.5)
      ),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: hasError ? _kRed : _kPrimary.withValues(alpha: 0.22), width: 1.5)
      ),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: hasError ? _kRed : _kPrimary, width: 1.5)
      ),
      isDense: true,
    );

class AttendanceFormReadonlyPage extends StatefulWidget {
  final Map<String, dynamic> formData;
  final String docId;
  final String userKey;

  const AttendanceFormReadonlyPage({
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
  List<SignatureController> _sigControllers = [];
  List<TextEditingController> _nameCtrl = [];
  List<String> _attendeeNames = [];

  // Parsed attendees and other fields
  List<Map<String, dynamic>> _attendees = [];
  List<String> _dealers = [];
  List<String> _focusProducts = [];

  // Mode flags
  bool _isEditMode = false;
  bool _isSaving   = false;
  bool _submitted  = false;

  Map<String, dynamic> _editSnapshot = {};
  final ScrollController _scrollCtrl = ScrollController();

  // Controller for headers
  late TextEditingController _eventNameCtrl;
  late TextEditingController _cropFocusCtrl;
  late TextEditingController _cropStatusCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _remarksCtrl;
  late TextEditingController _dealersCtrl;
  late TextEditingController _focusProductsCtrl;

  // Controllers for Attendance Details fields
  List<TextEditingController> _addressCtrl = [];
  List<TextEditingController> _telephoneCtrl = [];
  List<TextEditingController> _hectaresCtrl = [];
  List<TextEditingController> _cropCtrl = [];
  List<TextEditingController> _insecticideCtrl = [];
  List<TextEditingController> _fungicideCtrl = [];
  List<TextEditingController> _herbicideCtrl = [];
  List<TextEditingController> _nutritionCtrl = [];
  List<TextEditingController> _dealerSrcCtrl = [];
  List<TextEditingController> _facebookCtrl = [];

  // Validation flags
  List<bool> _nameErrors = [];
  List<bool> _sigErrors  = [];

  final Map<int, bool> _attExpanded = {};

  @override
  void initState() {
    super.initState();
    _initAll(widget.formData);
  }

  static List<String> _toStringList(dynamic raw) {
    if (raw == null) return [];
    return (raw as List<dynamic>).map((e) => e?.toString() ?? '').toList();
  }

  void _initAll(Map<String, dynamic> data) {
    _dealers       = _toStringList(data['dealers']);
    _focusProducts = _toStringList(data['focusProducts']);
    _attendees     = (data['attendees'] ?? [])
        .whereType<Map>()
        .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
        .toList();

    _eventNameCtrl = TextEditingController(text: (data['eventName'] ?? '').toString());
    _cropFocusCtrl = TextEditingController(text: (data['cropFocus'] ?? '').toString());
    _cropStatusCtrl = TextEditingController(text: (data['cropStatus'] ?? '').toString());
    _dateCtrl = TextEditingController(text: (data['date'] ?? '').toString());
    _locationCtrl = TextEditingController(text: (data['location'] ?? '').toString());
    _remarksCtrl = TextEditingController(text: (data['remarks'] ?? '').toString());
    _dealersCtrl = TextEditingController(text: _dealers.join(', '));
    _focusProductsCtrl = TextEditingController(text: _focusProducts.join(', '));

    _initAttendeeFieldCtrl();
    _initSigsAndNames(data);

    _submitted  = false;
    _nameErrors = List.filled(_rowCount, false);
    _sigErrors  = List.filled(_rowCount, false);
  }

  void _initAttendeeFieldCtrl() {
    for (final list in [_addressCtrl, _telephoneCtrl, _hectaresCtrl, _cropCtrl,
        _insecticideCtrl, _fungicideCtrl, _herbicideCtrl,
        _nutritionCtrl, _dealerSrcCtrl, _facebookCtrl]) {
      for (final c in list) c.dispose();
    }
    String r(Map<String, dynamic> row, String key) => (row[key] ?? '').toString();
    _addressCtrl = _attendees.map((row) => TextEditingController(text: r(row, 'address'))).toList();
    _telephoneCtrl = _attendees.map((row) => TextEditingController(text: r(row, 'telephone'))).toList();
    _hectaresCtrl = _attendees.map((row) => TextEditingController(text: r(row, 'hectares'))).toList();
    _cropCtrl = _attendees.map((row) => TextEditingController(text: r(row, 'crop'))).toList();
    _insecticideCtrl = _attendees.map((row) => TextEditingController(text: r(row, 'insecticide'))).toList();
    _fungicideCtrl = _attendees.map((row) => TextEditingController(text: r(row, 'fungicide'))).toList();
    _herbicideCtrl = _attendees.map((row) => TextEditingController(text: r(row, 'herbicide'))).toList();
    _nutritionCtrl = _attendees.map((row) => TextEditingController(text: r(row, 'nutrition'))).toList();
    _dealerSrcCtrl = _attendees.map((row) => TextEditingController(text: r(row, 'dealerSource'))).toList();
    _facebookCtrl = _attendees.map((row) => TextEditingController(text: r(row, 'facebookLink'))).toList();
  }

  void _initSigsAndNames(Map<String, dynamic> data) {
    for (final c in _sigControllers) c.dispose();
    for (final c in _nameCtrl) c.dispose();
    _sigControllers = [];
    _nameCtrl       = [];
    _attendeeNames  = [];

    final List<String> namesRaw = _toStringList(data['attendeeNames']);
    _attendeeNames = namesRaw.isNotEmpty
        ? namesRaw
        : _attendees
            .map((r) => (r['name'] ?? '').toString())
            .where((n) => n.isNotEmpty)
            .toList();

    final sigsRaw = data['attendeeSignatures'] ?? [];

    for (int i = 0; i < _attendeeNames.length; i++) {
      final name = _attendeeNames[i];
      _nameCtrl.add(TextEditingController(text: name));
      final sc = SignatureController(
          penStrokeWidth: 3,
          penColor: Colors.black,
          exportBackgroundColor: Colors.white);

      final entry = (sigsRaw as List<dynamic>).firstWhere(
          (s) => s is Map && s['name'] == name,
          orElse: () => null);
      if (entry != null && entry['points'] is List) {
        final pts = <Point>[];
        for (final p in (entry['points'] as List<dynamic>)) {
          if (p is! Map) continue;
          final x = (p['x'] as num?)?.toDouble();
          final y = (p['y'] as num?)?.toDouble();
          if (x == null || y == null) continue;
          final type = (p['type'] as String?) == 'PointType.move'
              ? PointType.move
              : PointType.tap;
          pts.add(Point(Offset(x, y), type,
              (p['pressure'] as num?)?.toDouble() ?? 1.0));
        }
        if (pts.isNotEmpty) sc.points = pts;
      }
      _sigControllers.add(sc);
    }

    if (_attendeeNames.isEmpty) {
      for (final row in _attendees) {
        final name = (row['name'] ?? '').toString();
        _attendeeNames.add(name);
        _nameCtrl.add(TextEditingController(text: name));
        _sigControllers.add(SignatureController(
            penStrokeWidth: 3,
            penColor: Colors.black,
            exportBackgroundColor: Colors.white));
      }
      if (_attendees.isEmpty) {
        _attendeeNames.add('');
        _nameCtrl.add(TextEditingController());
        _sigControllers.add(
          SignatureController(
            penStrokeWidth: 3,
            penColor: Colors.black,
            exportBackgroundColor: Colors.white
          )
        );
        _attendees.add({});
      }
    }

    final rows = _rowCount;
    void pad(List<TextEditingController> list) {
      while (list.length < rows) list.add(TextEditingController());
    }
    pad(_addressCtrl); pad(_telephoneCtrl); pad(_hectaresCtrl); pad(_cropCtrl);
    pad(_insecticideCtrl); pad(_fungicideCtrl); pad(_herbicideCtrl);
    pad(_nutritionCtrl); pad(_dealerSrcCtrl); pad(_facebookCtrl);
  }

  int get _rowCount =>
      _nameCtrl.length > _attendees.length 
          ? _nameCtrl.length 
          : _attendees.length;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _eventNameCtrl.dispose(); _cropFocusCtrl.dispose(); _cropStatusCtrl.dispose();
    _dateCtrl.dispose(); _locationCtrl.dispose(); _remarksCtrl.dispose();
    _dealersCtrl.dispose(); _focusProductsCtrl.dispose();
    for (final c in _sigControllers)   c.dispose();
    for (final c in _nameCtrl)         c.dispose();
    for (final c in _addressCtrl)      c.dispose();
    for (final c in _telephoneCtrl)    c.dispose();
    for (final c in _hectaresCtrl)     c.dispose();
    for (final c in _cropCtrl)         c.dispose();
    for (final c in _insecticideCtrl)  c.dispose();
    for (final c in _fungicideCtrl)    c.dispose();
    for (final c in _herbicideCtrl)    c.dispose();
    for (final c in _nutritionCtrl)    c.dispose();
    for (final c in _dealerSrcCtrl)    c.dispose();
    for (final c in _facebookCtrl)     c.dispose();
    super.dispose();
  }

  // Snapshot helpers
  Map<String, dynamic> _buildSnapshot() => {
        'eventName':     _eventNameCtrl.text,
        'date':          _dateCtrl.text,
        'location':      _locationCtrl.text,
        'cropFocus':     _cropFocusCtrl.text,
        'cropStatus':    _cropStatusCtrl.text,
        'remarks':       _remarksCtrl.text,
        'dealers':       _dealersCtrl.text,
        'focusProducts': _focusProductsCtrl.text,
        'attendees': List.generate(_rowCount, (i) => {
          'name':         i < _nameCtrl.length        ? _nameCtrl[i].text        : '',
          'address':      i < _addressCtrl.length     ? _addressCtrl[i].text     : '',
          'telephone':    i < _telephoneCtrl.length   ? _telephoneCtrl[i].text   : '',
          'hectares':     i < _hectaresCtrl.length    ? _hectaresCtrl[i].text    : '',
          'crop':         i < _cropCtrl.length        ? _cropCtrl[i].text        : '',
          'insecticide':  i < _insecticideCtrl.length ? _insecticideCtrl[i].text : '',
          'fungicide':    i < _fungicideCtrl.length   ? _fungicideCtrl[i].text   : '',
          'herbicide':    i < _herbicideCtrl.length   ? _herbicideCtrl[i].text   : '',
          'nutrition':    i < _nutritionCtrl.length   ? _nutritionCtrl[i].text   : '',
          'dealerSource': i < _dealerSrcCtrl.length   ? _dealerSrcCtrl[i].text   : '',
          'facebookLink': i < _facebookCtrl.length    ? _facebookCtrl[i].text    : '',
        }),
      };

  void _restoreFromSnapshot() {
    _eventNameCtrl.text     = _editSnapshot['eventName']     ?? '';
    _dateCtrl.text          = _editSnapshot['date']          ?? '';
    _locationCtrl.text      = _editSnapshot['location']      ?? '';
    _cropFocusCtrl.text     = _editSnapshot['cropFocus']     ?? '';
    _cropStatusCtrl.text    = _editSnapshot['cropStatus']    ?? '';
    _remarksCtrl.text       = _editSnapshot['remarks']       ?? '';
    _dealersCtrl.text       = _editSnapshot['dealers']       ?? '';
    _focusProductsCtrl.text = _editSnapshot['focusProducts'] ?? '';

    final List<dynamic> snap = _editSnapshot['attendees'] ?? [];
    while (_nameCtrl.length > snap.length) {
      final last = _nameCtrl.length - 1;
      _nameCtrl.removeAt(last).dispose();
      if (last < _sigControllers.length)  _sigControllers.removeAt(last).dispose();
      if (last < _attendees.length)       _attendees.removeAt(last);
      if (last < _addressCtrl.length)     _addressCtrl.removeAt(last).dispose();
      if (last < _telephoneCtrl.length)   _telephoneCtrl.removeAt(last).dispose();
      if (last < _hectaresCtrl.length)    _hectaresCtrl.removeAt(last).dispose();
      if (last < _cropCtrl.length)        _cropCtrl.removeAt(last).dispose();
      if (last < _insecticideCtrl.length) _insecticideCtrl.removeAt(last).dispose();
      if (last < _fungicideCtrl.length)   _fungicideCtrl.removeAt(last).dispose();
      if (last < _herbicideCtrl.length)   _herbicideCtrl.removeAt(last).dispose();
      if (last < _nutritionCtrl.length)   _nutritionCtrl.removeAt(last).dispose();
      if (last < _dealerSrcCtrl.length)   _dealerSrcCtrl.removeAt(last).dispose();
      if (last < _facebookCtrl.length)    _facebookCtrl.removeAt(last).dispose();
    }
    for (int i = 0; i < snap.length; i++) {
      final row = snap[i] as Map;
      if (i < _nameCtrl.length)        _nameCtrl[i].text        = row['name']         ?? '';
      if (i < _addressCtrl.length)     _addressCtrl[i].text     = row['address']       ?? '';
      if (i < _telephoneCtrl.length)   _telephoneCtrl[i].text   = row['telephone']     ?? '';
      if (i < _hectaresCtrl.length)    _hectaresCtrl[i].text    = row['hectares']      ?? '';
      if (i < _cropCtrl.length)        _cropCtrl[i].text        = row['crop']          ?? '';
      if (i < _insecticideCtrl.length) _insecticideCtrl[i].text = row['insecticide']   ?? '';
      if (i < _fungicideCtrl.length)   _fungicideCtrl[i].text   = row['fungicide']     ?? '';
      if (i < _herbicideCtrl.length)   _herbicideCtrl[i].text   = row['herbicide']     ?? '';
      if (i < _nutritionCtrl.length)   _nutritionCtrl[i].text   = row['nutrition']     ?? '';
      if (i < _dealerSrcCtrl.length)   _dealerSrcCtrl[i].text   = row['dealerSource']  ?? '';
      if (i < _facebookCtrl.length)    _facebookCtrl[i].text    = row['facebookLink']  ?? '';
    }
    _attExpanded.clear();
    _submitted  = false;
    _nameErrors = List.filled(_rowCount, false);
    _sigErrors  = List.filled(_rowCount, false);
  }

  // Edit toggle
  void _toggleEditMode() {
    if (!_isEditMode) {
      _editSnapshot = _buildSnapshot();
      setState(() { _isEditMode = true; _submitted = false; });
    } else {
      setState(() { _restoreFromSnapshot(); _isEditMode = false; });
    }
  }

  // Add attendee
  void _addAttendeeRow() {
    setState(() {
      _attendeeNames.add('');
      _nameCtrl.add(TextEditingController());
      _sigControllers.add(SignatureController(
          penStrokeWidth: 3,
          penColor: Colors.black,
          exportBackgroundColor: Colors.white));
      _addressCtrl.add(TextEditingController());
      _telephoneCtrl.add(TextEditingController());
      _hectaresCtrl.add(TextEditingController());
      _cropCtrl.add(TextEditingController());
      _insecticideCtrl.add(TextEditingController());
      _fungicideCtrl.add(TextEditingController());
      _herbicideCtrl.add(TextEditingController());
      _nutritionCtrl.add(TextEditingController());
      _dealerSrcCtrl.add(TextEditingController());
      _facebookCtrl.add(TextEditingController());
      _attendees.add({});
      _attExpanded[_nameCtrl.length - 1] = true;
      _nameErrors.add(false);
      _sigErrors.add(false);
    });
  }

  // Delete attendee
  Future<void> _confirmDeleteAttendee(int index) async {
    if (_rowCount <= 1) {
      _toast('At least one attendee is required.', error: true);
      return;
    }
    final name = index < _nameCtrl.length ? _nameCtrl[index].text.trim() : '';
    final confirmed = await _showConfirmDialog(
        title: 'Remove Attendee',
        message: 'Remove ${name.isNotEmpty ? '"$name"' : 'this attendee'} from the list?',
        confirmLabel: 'Remove');
    if (confirmed != true || !mounted) return;
    setState(() {
      void rem<T>(List<T> list, int i, {void Function(T)? dispose}) {
        if (i < list.length) {
          if (dispose != null) dispose(list[i]);
          list.removeAt(i);
        }
      }
      rem(_attendees, index);
      rem(_nameCtrl, index,
          dispose: (c) => (c as TextEditingController).dispose());
      rem(_sigControllers, index,
          dispose: (c) => (c as SignatureController).dispose());
      rem(_addressCtrl, index,
          dispose: (c) => (c as TextEditingController).dispose());
      rem(_telephoneCtrl, index,
          dispose: (c) => (c as TextEditingController).dispose());
      rem(_hectaresCtrl, index,
          dispose: (c) => (c as TextEditingController).dispose());
      rem(_cropCtrl, index,
          dispose: (c) => (c as TextEditingController).dispose());
      rem(_insecticideCtrl, index,
          dispose: (c) => (c as TextEditingController).dispose());
      rem(_fungicideCtrl, index,
          dispose: (c) => (c as TextEditingController).dispose());
      rem(_herbicideCtrl, index,
          dispose: (c) => (c as TextEditingController).dispose());
      rem(_nutritionCtrl, index,
          dispose: (c) => (c as TextEditingController).dispose());
      rem(_dealerSrcCtrl, index,
          dispose: (c) => (c as TextEditingController).dispose());
      rem(_facebookCtrl, index,
          dispose: (c) => (c as TextEditingController).dispose());
      if (index < _nameErrors.length) _nameErrors.removeAt(index);
      if (index < _sigErrors.length)  _sigErrors.removeAt(index);
      final shifted = <int, bool>{};
      _attExpanded.forEach((k, v) {
        if (k < index) shifted[k] = v;
        else if (k > index) shifted[k - 1] = v;
      });
      _attExpanded..clear()..addAll(shifted);
    });
  }

  // Confirm dialogs
  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E)
              )
          ),
          content: Text(message,
              style: const TextStyle(
                  fontSize: 14, 
                  color: Colors.black54, 
                  height: 1.5
              )
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey))
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                  foregroundColor: _kRed,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700)
              ),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );

  // Toast
  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
              error 
                  ? Icons.error_outline 
                  : Icons.check_circle_outline,
              color: Colors.white,
              size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.w600
                  )
              )
          ),
        ]),
        backgroundColor: error 
            ? _kRed 
            : _kGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
  }

  // Validations
  bool _validateForm() {
    setState(() => _submitted = true);
    bool valid = true;
    final rows = _rowCount;
    while (_nameErrors.length < rows) _nameErrors.add(false);
    while (_sigErrors.length < rows)  _sigErrors.add(false);

    if (_eventNameCtrl.text.trim().isEmpty  ||
        _dateCtrl.text.trim().isEmpty       ||
        _locationCtrl.text.trim().isEmpty   ||
        _cropFocusCtrl.text.trim().isEmpty  ||
        _cropStatusCtrl.text.trim().isEmpty ||
        _dealersCtrl.text.trim().isEmpty    ||
        _focusProductsCtrl.text.trim().isEmpty ||
        _remarksCtrl.text.trim().isEmpty) valid = false;

    if (rows == 0) {
      _toast('Please add at least one attendee.', error: true);
      return false;
    }

    for (int i = 0; i < rows; i++) {
      final nameEmpty =
          i < _nameCtrl.length ? _nameCtrl[i].text.trim().isEmpty : true;
      _nameErrors[i] = nameEmpty;
      if (nameEmpty) { _attExpanded[i] = true; valid = false; }

      final sigEmpty =
          i < _sigControllers.length ? _sigControllers[i].isEmpty : true;
      _sigErrors[i] = sigEmpty;
      if (sigEmpty) { _attExpanded[i] = true; valid = false; }
    }

    setState(() {});
    if (!valid) _toast('Please fill out all required fields.', error: true);
    return valid;
  }

  // Export signatures
  List<Map<String, dynamic>> _exportSignatures() {
    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < _nameCtrl.length; i++) {
      final name = _nameCtrl[i].text.trim();
      final sc   = _sigControllers[i];
      final pts  = <Map<String, dynamic>>[];
      if (!sc.isEmpty) {
        for (final p in sc.points) {
          if (p == null) continue;
          final dp  = p as dynamic;
          final off = dp.offset as Offset;
          pts.add({
            'x':        off.dx,
            'y':        off.dy,
            'pressure': dp.pressure ?? 1.0,
            'type':     dp.type.toString(),
          });
        }
      }
      result.add({'name': name, 'points': pts});
    }
    return result;
  }

  // Save changes
  Future<void> _saveChanges() async {
    if (!_validateForm()) return;
    setState(() => _isSaving = true);
    try {
      final updatedAttendees = <Map<String, dynamic>>[];
      for (int i = 0; i < _rowCount; i++) {
        final name        = i < _nameCtrl.length        ? _nameCtrl[i].text.trim()        : '';
        final address     = i < _addressCtrl.length     ? _addressCtrl[i].text.trim()     : '';
        final tel         = i < _telephoneCtrl.length   ? _telephoneCtrl[i].text.trim()   : '';
        final hectares    = i < _hectaresCtrl.length    ? _hectaresCtrl[i].text.trim()    : '';
        final crop        = i < _cropCtrl.length        ? _cropCtrl[i].text.trim()        : '';
        final insecticide = i < _insecticideCtrl.length ? _insecticideCtrl[i].text.trim() : '';
        final fungicide   = i < _fungicideCtrl.length   ? _fungicideCtrl[i].text.trim()   : '';
        final herbicide   = i < _herbicideCtrl.length   ? _herbicideCtrl[i].text.trim()   : '';
        final nutrition   = i < _nutritionCtrl.length   ? _nutritionCtrl[i].text.trim()   : '';
        final dealerSrc   = i < _dealerSrcCtrl.length   ? _dealerSrcCtrl[i].text.trim()   : '';
        final fb          = i < _facebookCtrl.length    ? _facebookCtrl[i].text.trim()    : '';
        final isEmpty     = [name, address, tel, hectares, crop, insecticide,
                              fungicide, herbicide, nutrition, dealerSrc, fb]
            .every((s) => s.isEmpty);
        if (isEmpty) continue;
        updatedAttendees.add({
          'name': name, 'address': address, 'telephone': tel,
          'hectares': hectares, 'crop': crop, 'insecticide': insecticide,
          'fungicide': fungicide, 'herbicide': herbicide,
          'nutrition': nutrition, 'dealerSource': dealerSrc,
          'facebookLink': fb,
        });
      }

      final signatures   = _exportSignatures();
      final updatedNames = _nameCtrl
          .map((c) => c.text.trim())
          .where((n) => n.isNotEmpty)
          .toList()
          .cast<String>();
      final updDealers = _dealersCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList()
          .cast<String>();
      final updFocus = _focusProductsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList()
          .cast<String>();

      await FirebaseFirestore.instance
          .collection('flowDB').doc('users')
          .collection(widget.userKey).doc('attendance_forms')
          .collection('attendance_forms').doc(widget.docId)
          .update({
        'eventName':           _eventNameCtrl.text.trim(),
        'cropFocus':           _cropFocusCtrl.text.trim(),
        'cropStatus':          _cropStatusCtrl.text.trim(),
        'date':                _dateCtrl.text.trim(),
        'location':            _locationCtrl.text.trim(),
        'remarks':             _remarksCtrl.text.trim(),
        'dealers':             updDealers,
        'focusProducts':       updFocus,
        'attendeeNames':       updatedNames,
        'attendeeSignatures':  signatures,
        'attendees':           updatedAttendees,
      });

      widget.formData['eventName']          = _eventNameCtrl.text.trim();
      widget.formData['cropFocus']          = _cropFocusCtrl.text.trim();
      widget.formData['cropStatus']         = _cropStatusCtrl.text.trim();
      widget.formData['date']               = _dateCtrl.text.trim();
      widget.formData['location']           = _locationCtrl.text.trim();
      widget.formData['remarks']            = _remarksCtrl.text.trim();
      widget.formData['dealers']            = updDealers;
      widget.formData['focusProducts']      = updFocus;
      widget.formData['attendeeNames']      = updatedNames;
      widget.formData['attendeeSignatures'] = signatures;
      widget.formData['attendees']          = updatedAttendees;

      setState(() {
        _attendees  = updatedAttendees;
        _dealers    = updDealers;
        _focusProducts = updFocus;
        _isEditMode = false;
        _submitted  = false;
        _attExpanded.clear();
      });
      _toast('Form updated successfully.');
    } catch (e) {
      _toast('Error updating form: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Reset
  Future<void> _resetForm() async {
    final confirmed = await _showConfirmDialog(
      title: 'Reset Form',
      message:
          'This will restore all fields to their last saved values. Continue?',
      confirmLabel: 'Reset',
    );
    if (confirmed != true) return;
    setState(() => _restoreFromSnapshot());
    _toast('Form has been reset.');
  }

  Widget _secLabel(String t, {bool first = false}) => Padding(
        padding: EdgeInsets.only(left: 8, bottom: 8, top: first ? 4 : 20),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kPrimary,
                letterSpacing: 0.5)),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .06),
                  blurRadius: 14,
                  offset: const Offset(0, 3))
            ]),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  // View
  Widget _vFull(String label, String val, {bool last = false}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: _kDivider))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl(label),
          const SizedBox(height: 3),
          Text(val.trim().isEmpty ? 'No data' : val,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: val.trim().isEmpty ? _kEmpty : Colors.black87)),
        ]),
      );

  Widget _vTwo(String l1, String v1, String l2, String v2,
      {bool last = false}) =>
      Container(
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: _kDivider))),
        child: IntrinsicHeight(
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _vCell(l1, v1, rightBorder: true)),
                Expanded(child: _vCell(l2, v2)),
              ]),
        ),
      );

  Widget _vCell(String label, String val, {bool rightBorder = false}) =>
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
            border: rightBorder
                ? const Border(right: BorderSide(color: _kDivider))
                : null),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl(label),
          const SizedBox(height: 3),
          Text(val.trim().isEmpty ? 'No data' : val,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: val.trim().isEmpty ? _kEmpty : Colors.black87)),
        ]),
      );

  // Edit
  Widget _eFull(Widget child, {bool last = false}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: _kDivider))),
        child: child,
      );

  Widget _eTwo(Widget left, Widget right, {bool last = false}) => Container(
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: _kDivider))),
        child: IntrinsicHeight(
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _ePad(left, rightBorder: true)),
                Expanded(child: _ePad(right)),
              ]),
        ),
      );

  Widget _ePad(Widget child, {bool rightBorder = false}) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
            border: rightBorder
                ? const Border(right: BorderSide(color: _kDivider))
                : null),
        child: child,
      );

  Widget _eField(String label, TextEditingController ctrl,
      {bool req = false, int maxLines = 1, TextInputType? keyboardType}) {
    final bool err = _submitted && req && ctrl.text.trim().isEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lblReq(label, req),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
        decoration: _attDeco(hasError: err, hint: _placeholder(label)),
        onChanged: (_) {
          if (_submitted) setState(() {});
        },
      ),
      if (err)
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Text('This field is required.',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _kRed)),
        ),
    ]);
  }

  // Attendee cards
  Widget _pfView(String label, String val) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _pfLbl(label),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFF9F7FD),
                border: Border.all(color: _kBorder),
                borderRadius: BorderRadius.circular(8)),
            child: Text(val.trim().isEmpty ? 'No data' : val,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: val.trim().isEmpty ? _kEmpty : Colors.black87)),
          ),
        ]),
      );

  Widget _pfEdit(String label, TextEditingController ctrl,
      {bool req = false,
      bool hasError = false,
      TextInputType? keyboardType}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _pfLblReq(label, req),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87),
            decoration:
                _pfDeco(hasError: hasError, hint: _placeholder(label)),
            onChanged: (_) {
              if (_submitted) setState(() {});
            },
          ),
          if (req && hasError)
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Text('This field is required.',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kRed)),
            ),
        ]),
      );

  Widget _pf(String label, TextEditingController ctrl,
      {bool req = false,
      bool hasError = false,
      TextInputType? keyboardType}) {
    if (!_isEditMode) return _pfView(label, ctrl.text);
    return _pfEdit(label, ctrl,
        req: req, hasError: hasError, keyboardType: keyboardType);
  }

  Widget _pfTwoCol(Widget left, Widget right) => LayoutBuilder(
        builder: (ctx, constraints) {
          if (constraints.maxWidth < 340)
            return Column(children: [left, right]);
          return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 8),
                Expanded(child: right),
              ]);
        },
      );

  // Section bar
  Widget _sectionBar(String title,
    {VoidCallback? onAdd, String addLabel = 'Add Row'}) =>
    Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8), // added left: 8
      child: Row(children: [
        Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kPrimary,
                letterSpacing: 0.5)),
        const Spacer(),
        if (onAdd != null)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_kPrimaryDark, _kPrimary]),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Row(children: [
                const Icon(Icons.add, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(addLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
      ]),
    );

  Widget _emptyNote(String msg) => Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 12, top: 2),
        child: Text(msg,
            style: const TextStyle(color: _kEmpty, fontSize: 14)),
      );

  // Attendee collapsible card
  Widget _attendeeCard(int index) {
    final sc  = index < _sigControllers.length  ? _sigControllers[index]  : null;
    final nc  = index < _nameCtrl.length        ? _nameCtrl[index]        : TextEditingController();
    final ac  = index < _addressCtrl.length     ? _addressCtrl[index]     : TextEditingController();
    final tc  = index < _telephoneCtrl.length   ? _telephoneCtrl[index]   : TextEditingController();
    final hc  = index < _hectaresCtrl.length    ? _hectaresCtrl[index]    : TextEditingController();
    final cc  = index < _cropCtrl.length        ? _cropCtrl[index]        : TextEditingController();
    final ic  = index < _insecticideCtrl.length ? _insecticideCtrl[index] : TextEditingController();
    final fc  = index < _fungicideCtrl.length   ? _fungicideCtrl[index]   : TextEditingController();
    final hbc = index < _herbicideCtrl.length   ? _herbicideCtrl[index]   : TextEditingController();
    final nt  = index < _nutritionCtrl.length   ? _nutritionCtrl[index]   : TextEditingController();
    final dc  = index < _dealerSrcCtrl.length   ? _dealerSrcCtrl[index]   : TextEditingController();
    final fb  = index < _facebookCtrl.length    ? _facebookCtrl[index]    : TextEditingController();

    final isOpen  = _attExpanded[index] ?? false;
    final nameErr = index < _nameErrors.length ? _nameErrors[index] : false;
    final sigErr  = index < _sigErrors.length  ? _sigErrors[index]  : false;
    final label   = nc.text.trim().isEmpty
        ? 'Attendee ${index + 1}'
        : nc.text.trim();

    if (!_isEditMode) {
      final emptyRow = index >= _attendees.length &&
          nc.text.trim().isEmpty &&
          ac.text.trim().isEmpty &&
          tc.text.trim().isEmpty;
      if (emptyRow) return const SizedBox.shrink();
    }

    bool fieldErr(TextEditingController c) =>
        _submitted && c.text.trim().isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 3))
          ]),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // ── Header
        InkWell(
          onTap: () => setState(() => _attExpanded[index] = !isOpen),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
              _kPrimaryDark.withValues(alpha: 0.07),
              _kPrimary.withValues(alpha: 0.03),
            ])),
            child: Row(children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_kPrimaryDark, _kPrimary]),
                    shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('${index + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kPrimary),
                      overflow: TextOverflow.ellipsis)),
              if (_isEditMode)
                GestureDetector(
                  onTap: () => _confirmDeleteAttendee(index),
                  child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          color: _kRed, size: 18)),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.keyboard_arrow_down,
                    color: _kPrimary, size: 20),
              ),
            ]),
          ),
        ),

        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _pf('Full Name', nc, req: true, hasError: nameErr),
              _pfTwoCol(
                _pf('Telephone / CP No.', tc,
                    req: true,
                    hasError: fieldErr(tc),
                    keyboardType: TextInputType.phone),
                _pf('Hectares', hc,
                    req: true,
                    hasError: fieldErr(hc),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true)),
              ),
              _pf('Address', ac, req: true, hasError: fieldErr(ac)),
              _pfTwoCol(
                _pf('Crop', cc,
                    req: true, hasError: fieldErr(cc)),
                _pf('Insecticide', ic,
                    req: true, hasError: fieldErr(ic)),
              ),
              _pfTwoCol(
                _pf('Fungicide', fc,
                    req: true, hasError: fieldErr(fc)),
                _pf('Herbicide', hbc,
                    req: true, hasError: fieldErr(hbc)),
              ),
              _pfTwoCol(
                _pf('Crop Nutrition / Foliar', nt,
                    req: true, hasError: fieldErr(nt)),
                _pf('Dealer Name (Source)', dc,
                    req: true, hasError: fieldErr(dc)),
              ),
              _pf('Facebook Link', fb,
                  req: true, hasError: fieldErr(fb)),

              const SizedBox(height: 2),
              Row(children: [
                _pfLbl('Signature'),
                if (_isEditMode)
                  const Text(' *',
                      style: TextStyle(
                          color: _kRed,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: sigErr && _isEditMode ? _kRed : _kBorder,
                      width: sigErr && _isEditMode ? 1.5 : 1),
                  color: Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: IgnorePointer(
                    ignoring: !_isEditMode,
                    child: sc == null
                        ? const SizedBox.shrink()
                        : Signature(
                            controller: sc,
                            width: double.infinity,
                            height: 80,
                            backgroundColor: Colors.white),
                  ),
                ),
              ),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (sigErr && _isEditMode)
                      const Text('This field is required.',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _kRed))
                    else
                      const SizedBox.shrink(),
                    if (_isEditMode)
                      TextButton(
                        onPressed: () => setState(() {
                          sc?.clear();
                          if (index < _sigErrors.length)
                            _sigErrors[index] = false;
                        }),
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap),
                        child: const Text('✕  CLEAR SIGNATURE',
                            style: TextStyle(
                                fontSize: 12, color: _kRed)),
                      ),
                  ]),
              if (!_isEditMode && sc != null && sc.isEmpty)
                const Center(
                    child: Text('NO SIGNATURE ON RECORD',
                        style: TextStyle(
                            fontSize: 12,
                            color: _kEmpty,
                            fontStyle: FontStyle.italic))),
            ]),
          ),
          crossFadeState: isOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ]),
    );
  }

  // Section cards
  Widget _buildBasicInfoCard() {
    final createdBy = (widget.formData['createdBy'] ?? '').toString().trim();
    if (!_isEditMode) {
      return _card([
        _vFull('Event Name', _eventNameCtrl.text),
        _vFull('Date', _dateCtrl.text),
        _vFull('Location', _locationCtrl.text),
        _vFull('Focus Products', _focusProductsCtrl.text),
        if (createdBy.isNotEmpty)
          _vFull('Created By', createdBy, last: true)
        else
          _vFull('Focus Products', _focusProductsCtrl.text, last: true),
      ]);
    }
    return _card([
      _eFull(_eField('Event Name', _eventNameCtrl, req: true)),
      _eFull(_eField('Date', _dateCtrl, req: true)),
      _eFull(_eField('Location', _locationCtrl, req: true)),
      _eFull(_eField('Focus Products', _focusProductsCtrl, req: true),
          last: true),
    ]);
  }

  Widget _buildCropDealerCard() {
    if (!_isEditMode) {
      return _card([
        _vTwo('Crop Focus', _cropFocusCtrl.text, 'Crop Status',
            _cropStatusCtrl.text),
        _vFull('Name of Dealers', _dealersCtrl.text),
        _vFull('Remarks', _remarksCtrl.text, last: true),
      ]);
    }
    return _card([
      _eTwo(
        _eField('Crop Focus', _cropFocusCtrl, req: true),
        _eField('Crop Status', _cropStatusCtrl, req: true),
      ),
      _eFull(_eField('Name of Dealers', _dealersCtrl, req: true)),
      _eFull(
          _eField('Remarks', _remarksCtrl, req: true, maxLines: 3),
          last: true),
    ]);
  }

  Widget _lbl(String t) => Text(t.toUpperCase(),
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _kMuted,
          letterSpacing: 0.5));

  Widget _lblReq(String t, bool req) => Row(children: [
        _lbl(t),
        if (req)
          const Text(' *',
              style: TextStyle(
                  color: _kRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
      ]);

  Widget _pfLbl(String t) => Text(t.toUpperCase(),
      style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: _kMuted,
          letterSpacing: 0.4));

  Widget _pfLblReq(String t, bool req) => Row(children: [
        _pfLbl(t),
        if (req)
          const Text(' *',
              style: TextStyle(
                  color: _kRed,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700)),
      ]);

  // Placeholders
  String _placeholder(String label) {
    const map = {
      'Event Name':             'e.g., Field Day – Corn Farmers',
      'Date':                   'e.g., 2026-02-14',
      'Location':               'e.g., Brgy. Mabini, Davao del Norte',
      'Focus Products':         'e.g., Indofil 800 WP, Proviso 250 EC',
      'Crop Focus':             'e.g., Corn',
      'Crop Status':            'e.g., Vegetative',
      'Name of Dealers':        'e.g., AgriMart Davao, GreenLeaf Supply',
      'Remarks':                'e.g., Good turnout from farmers',
      'Full Name':              'e.g., Juan Dela Cruz',
      'Telephone / CP No.':     'e.g., 09171234567',
      'Hectares':               'e.g., 3.5',
      'Address':                'e.g., Brgy. Mabini, Davao del Norte',
      'Crop':                   'e.g., Corn',
      'Insecticide':            'e.g., Primex 25 WP',
      'Fungicide':              'e.g., Indofil 800 WP',
      'Herbicide':              'e.g., Akostar 480 SL',
      'Crop Nutrition / Foliar':'e.g., Indolizer',
      'Dealer Name (Source)':   'e.g., AgriMart Davao',
      'Facebook Link':          'e.g., fb.com/juan.delacruz',
    };
    return map[label] ?? '';
  }

  Widget _footer() => Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 28),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : _resetForm,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kPrimary,
                backgroundColor: _kSurface,
                side: const BorderSide(color: _kPrimary, width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('RESET',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _gradBtn()),
        ]),
      );

  Widget _gradBtn() => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _isSaving ? null : _saveChanges,
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kPrimaryDark, _kPrimaryDark, _kPrimary],
                  stops: [0, 0.55, 1]),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: _kPrimary.withValues(alpha: 0.44),
                    blurRadius: 18,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Center(
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white))
                  : const Text('UPDATE FORM',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final appTitle = _eventNameCtrl.text.trim().isEmpty
        ? 'Attendance Form'
        : _eventNameCtrl.text.trim();

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kPrimaryDark, _kPrimaryDark, _kPrimary],
                stops: [0, 0.55, 1]),
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22)),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ATTENDANCE FORM',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white60,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            Text(appTitle.toUpperCase(),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
                overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton(
              onPressed: _isSaving ? null : _toggleEditMode,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              ),
              child: Text(
                _isEditMode ? 'CANCEL' : 'EDIT',
                style: TextStyle(
                    color: _isEditMode ? Colors.white60 : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secLabel('Basic Information', first: true),
                _buildBasicInfoCard(),

                _secLabel('Crop & Dealer Information'),
                _buildCropDealerCard(),

                _isEditMode
                    ? _sectionBar('Attendees',
                        onAdd: _addAttendeeRow,
                        addLabel: 'Add Attendee')
                    : _secLabel('Attendees'),

                if (_rowCount == 0)
                  _emptyNote('No attendees recorded.')
                else
                  Column(
                      children: List.generate(
                          _rowCount, (i) => _attendeeCard(i))),

                if (_isEditMode && _submitted && _rowCount == 0)
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 4),
                    child: Text('AT LEAST ONE ATTENDEE IS REQUIRED.',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kRed)),
                  ),

                if (_isEditMode) _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================
// Transactions Page
// ======================

class AttendanceFormTransactionsPage extends StatefulWidget {
  const AttendanceFormTransactionsPage({Key? key}) : super(key: key);

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
    final email = prefs.getString('userEmail') ?? '';
    setState(
        () => userKey = email.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_'));
  }

  Future<void> _navigateToAddForm(BuildContext context) async {
    final result = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => AttendanceFormPage()));
    if (result == true) setState(() {});
  }

  void _openDetail(BuildContext context, Map<String, dynamic> formData,
      String docId) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AttendanceFormReadonlyPage(
              formData: formData, docId: docId, userKey: userKey)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth  = (MediaQuery.of(context).size.width - 48) / 2;
    const cardHeight = 170.0;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          elevation: 4,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: true,
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(24))),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(24)),
              gradient: LinearGradient(
                colors: [_kPrimaryDark, _kPrimaryDark, _kPrimary],
                stops: [0, 0.55, 1],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Text('ATTENDANCE FORM TRANSACTIONS',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New Attendance Form',
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
                  .collection('flowDB').doc('users')
                  .collection(userKey).doc('attendance_forms')
                  .collection('attendance_forms')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(
                      child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                        'No attendance forms yet. Tap + to create a new.',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center),
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
                      final doc       = docs[idx];
                      final data      = doc.data() as Map<String, dynamic>;
                      final eventName = data['eventName']?.toString() ?? '';
                      final date      = data['date']?.toString() ?? '-';
                      final label     = 'Event #${docs.length - idx}';

                      return SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () =>
                                _openDetail(context, data, doc.id),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_kPrimaryDark, _kPrimary],
                                ),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      const Icon(Icons.event_note,
                                          color: Colors.white, size: 30),
                                      const SizedBox(width: 6),
                                      Expanded(
                                          child: Text(label,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600))),
                                    ]),
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
                                                : 'Unnamed Event',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: Colors.white)),
                                        const SizedBox(height: 4),
                                        Text('Date: $date',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12)),
                                      ],
                                    )),
                                  ]),
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