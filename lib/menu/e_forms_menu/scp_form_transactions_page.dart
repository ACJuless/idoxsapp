import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';

import 'scp_form_page.dart';

// Theme constants
const Color kPrimary     = Color(0xFF5958B2);
const Color kPrimaryDark = Color(0xFF4A2371);
const Color kSurface     = Color(0xFFF9F5FF);
const Color kCard        = Color(0xFFFFFFFF);
const Color kBorder      = Color(0xFFE9E3F5);
const Color kMuted       = Color(0xFF2B2B2B);
const Color kRed         = Color(0xFFDC2626);
const Color kGreen       = Color(0xFF059669);
const Color kFieldFill   = Color(0x0A6B21C8);
const Color kEmpty       = Color(0xFF9CA3AF);
const Color kDivider     = Color(0xFFF0EBF9);

InputDecoration _filledDecoration({
  String? hintText,
  bool hasError = false,
  EdgeInsets contentPadding =
      const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
}) {
  final borderColor = hasError ? kRed : kPrimary.withValues(alpha: 0.25);
  final fillColor   = hasError ? const Color(0x0ADC2626) : kFieldFill;
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: fillColor,
    hintStyle: const TextStyle(
        color: Color(0xFFB0A8C8), fontWeight: FontWeight.w400),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: borderColor, width: 1.5)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: borderColor, width: 1.5)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: hasError ? kRed : kPrimary, width: 1.6)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: kRed, width: 1.5)),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: kRed, width: 1.5)),
    errorStyle: const TextStyle(
        fontSize: 11.5, fontWeight: FontWeight.w600, color: kRed),
    isDense: true,
    contentPadding: contentPadding,
  );
}

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
  late TextEditingController _farmerNameCtrl;
  late TextEditingController _farmAddressCtrl;
  late TextEditingController _cellphoneCtrl;
  late TextEditingController _dateOfEventCtrl;
  late TextEditingController _cropsPlantedCtrl;
  late TextEditingController _typeOfEventCtrl;
  late TextEditingController _venueOfEventCtrl;
  late TextEditingController _cropAdvisorNameCtrl;
  late TextEditingController _cropAdvisorContactCtrl;
  late TextEditingController _farmerNameSecondCtrl;
  late TextEditingController _dateNeededCtrl;
  late TextEditingController _preferredDealerCtrl;
  late ScrollController _scrollController;

  List<Map<String, dynamic>> _advisoryDetails = [];
  List<Map<String, dynamic>> _products = [];

  List<TextEditingController> _advKeyConcernCtrl     = [];
  List<TextEditingController> _advRecommendationCtrl = [];

  List<TextEditingController> _prodNameCtrl      = [];
  List<TextEditingController> _prodQuantityCtrl  = [];
  List<TextEditingController> _prodPackagingCtrl = [];

  late SignatureController _sigController;

  bool _isEditMode  = false;
  bool _isSaving    = false;
  bool _initialized = false;
  bool _submitted   = false;
  Map<String, dynamic> _editSnapshot = {};

  final Map<int, bool> _advExpanded  = {};
  final Map<int, bool> _prodExpanded = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _sigController = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _farmerNameCtrl         = TextEditingController();
    _farmAddressCtrl        = TextEditingController();
    _cellphoneCtrl          = TextEditingController();
    _dateOfEventCtrl        = TextEditingController();
    _cropsPlantedCtrl       = TextEditingController();
    _typeOfEventCtrl        = TextEditingController();
    _venueOfEventCtrl       = TextEditingController();
    _cropAdvisorNameCtrl    = TextEditingController();
    _cropAdvisorContactCtrl = TextEditingController();
    _farmerNameSecondCtrl   = TextEditingController();
    _dateNeededCtrl         = TextEditingController();
    _preferredDealerCtrl    = TextEditingController();
    _populateFromData(widget.formData);
    _initialized = true;
  }

  void _populateFromData(Map<String, dynamic> data) {
    String s(String key) => (data[key] ?? '').toString();

    _farmerNameCtrl.text         = s('farmerName');
    _farmAddressCtrl.text        = s('farmAddress');
    _cellphoneCtrl.text          = s('cellphoneNumber');
    _dateOfEventCtrl.text        = s('dateOfEvent');
    _cropsPlantedCtrl.text       = s('cropsPlanted');
    _typeOfEventCtrl.text        = s('typeOfEvent');
    _venueOfEventCtrl.text       = s('venueOfEvent');
    _cropAdvisorNameCtrl.text    = s('cropAdvisorName');
    _cropAdvisorContactCtrl.text = s('cropAdvisorContact');
    _farmerNameSecondCtrl.text   = s('farmerNameSecond');
    _dateNeededCtrl.text         = s('dateNeeded');
    _preferredDealerCtrl.text    = s('preferredDealer');

    final List<dynamic> advisoryRaw =
        data['advisoryDetails'] is List ? data['advisoryDetails'] as List : [];
    _advisoryDetails = advisoryRaw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    _rebuildAdvisoryControllers();

    final List<dynamic> prodRaw =
        data['products'] is List ? data['products'] as List : [];
    _products = prodRaw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    _rebuildProductControllers();

    if (_initialized) {
      _sigController.dispose();
      _sigController = SignatureController(
        penStrokeWidth: 2,
        penColor: Colors.black,
        exportBackgroundColor: Colors.white,
      );
    }
    _loadSignaturePoints(data);
    _advExpanded.clear();
    _prodExpanded.clear();
  }

  void _rebuildAdvisoryControllers() {
    for (final c in _advKeyConcernCtrl)     c.dispose();
    for (final c in _advRecommendationCtrl) c.dispose();
    _advKeyConcernCtrl = _advisoryDetails
        .map((a) => TextEditingController(
            text: (a['keyConcern'] ?? '').toString()))
        .toList();
    _advRecommendationCtrl = _advisoryDetails.map((a) {
      final rec = a['productRecommendation'] ?? a['recommendation'] ?? '';
      return TextEditingController(text: rec.toString());
    }).toList();
  }

  void _rebuildProductControllers() {
    for (final c in _prodNameCtrl)      c.dispose();
    for (final c in _prodQuantityCtrl)  c.dispose();
    for (final c in _prodPackagingCtrl) c.dispose();
    _prodNameCtrl = _products
        .map((p) => TextEditingController(
            text: (p['productName'] ?? '').toString()))
        .toList();
    _prodQuantityCtrl = _products
        .map((p) => TextEditingController(
            text: (p['quantity'] ?? '').toString()))
        .toList();
    _prodPackagingCtrl = _products
        .map((p) => TextEditingController(
            text: (p['packaging'] ?? '').toString()))
        .toList();
  }

  void _loadSignaturePoints(Map<String, dynamic> data) {
    final dynamic raw = data['farmerSignaturePoints'];
    List? pointsList;
    if (raw is Map && raw['points'] is List) {
      pointsList = raw['points'] as List;
    } else if (raw is List) {
      pointsList = raw;
    }
    if (pointsList == null || pointsList.isEmpty) return;
    final List<Point> pts = [];
    for (final p in pointsList) {
      if (p is! Map) continue;
      final double? x = (p['x'] as num?)?.toDouble();
      final double? y = (p['y'] as num?)?.toDouble();
      if (x == null || y == null) continue;
      final String typeStr = (p['type'] as String?) ?? '';
      final PointType type =
          (typeStr == 'PointType.move' || typeStr == 'move')
              ? PointType.move
              : PointType.tap;
      final double pressure = (p['pressure'] as num?)?.toDouble() ?? 1.0;
      pts.add(Point(Offset(x, y), type, pressure));
    }
    if (pts.isNotEmpty) _sigController.points = pts;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _farmerNameCtrl.dispose();
    _farmAddressCtrl.dispose();
    _cellphoneCtrl.dispose();
    _dateOfEventCtrl.dispose();
    _cropsPlantedCtrl.dispose();
    _typeOfEventCtrl.dispose();
    _venueOfEventCtrl.dispose();
    _cropAdvisorNameCtrl.dispose();
    _cropAdvisorContactCtrl.dispose();
    _farmerNameSecondCtrl.dispose();
    _dateNeededCtrl.dispose();
    _preferredDealerCtrl.dispose();
    _sigController.dispose();
    for (final c in _advKeyConcernCtrl)     c.dispose();
    for (final c in _advRecommendationCtrl) c.dispose();
    for (final c in _prodNameCtrl)          c.dispose();
    for (final c in _prodQuantityCtrl)      c.dispose();
    for (final c in _prodPackagingCtrl)     c.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildSnapshot() => {
        'farmerName':         _farmerNameCtrl.text,
        'farmAddress':        _farmAddressCtrl.text,
        'cellphoneNumber':    _cellphoneCtrl.text,
        'dateOfEvent':        _dateOfEventCtrl.text,
        'cropsPlanted':       _cropsPlantedCtrl.text,
        'typeOfEvent':        _typeOfEventCtrl.text,
        'venueOfEvent':       _venueOfEventCtrl.text,
        'cropAdvisorName':    _cropAdvisorNameCtrl.text,
        'cropAdvisorContact': _cropAdvisorContactCtrl.text,
        'farmerNameSecond':   _farmerNameSecondCtrl.text,
        'dateNeeded':         _dateNeededCtrl.text,
        'preferredDealer':    _preferredDealerCtrl.text,
        'advisoryDetails': List.generate(_advisoryDetails.length, (i) => {
          'keyConcern': i < _advKeyConcernCtrl.length
              ? _advKeyConcernCtrl[i].text : '',
          'productRecommendation': i < _advRecommendationCtrl.length
              ? _advRecommendationCtrl[i].text : '',
        }),
        'products': List.generate(_products.length, (i) => {
          'productName': i < _prodNameCtrl.length
              ? _prodNameCtrl[i].text : '',
          'quantity': i < _prodQuantityCtrl.length
              ? _prodQuantityCtrl[i].text : '',
          'packaging': i < _prodPackagingCtrl.length
              ? _prodPackagingCtrl[i].text : '',
        }),
        'farmerSignaturePoints': _exportSignature(),
      };

  void _toggleEditMode() {
    if (!_isEditMode) {
      _editSnapshot = _buildSnapshot();
      setState(() { _isEditMode = true; _submitted = false; });
    } else {
      setState(() {
        _populateFromData(_editSnapshot);
        _isEditMode = false;
        _submitted  = false;
      });
    }
  }

  // Add
  void _addAdvisory() {
    setState(() {
      _advisoryDetails.add({'keyConcern': '', 'productRecommendation': ''});
      _advKeyConcernCtrl.add(TextEditingController());
      _advRecommendationCtrl.add(TextEditingController());
      _advExpanded[_advisoryDetails.length - 1] = true;
    });
  }

  // Confirm delete
  Future<void> _confirmDeleteAdvisory(int index) async {
    final kc = index < _advKeyConcernCtrl.length
        ? _advKeyConcernCtrl[index].text.trim() : '';
    final confirmed = await _showConfirmDialog(
      title: 'Remove Advisory Detail',
      message: 'Remove ${kc.isNotEmpty ? '"$kc"' : 'this advisory detail'} from the list?',
      confirmLabel: 'Remove',
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _advisoryDetails.removeAt(index);
      if (index < _advKeyConcernCtrl.length)
        _advKeyConcernCtrl.removeAt(index).dispose();
      if (index < _advRecommendationCtrl.length)
        _advRecommendationCtrl.removeAt(index).dispose();
      _shiftExpandedMap(_advExpanded, index);
    });
  }

  void _addProduct() {
    setState(() {
      _products.add({'productName': '', 'quantity': '', 'packaging': ''});
      _prodNameCtrl.add(TextEditingController());
      _prodQuantityCtrl.add(TextEditingController());
      _prodPackagingCtrl.add(TextEditingController());
      _prodExpanded[_products.length - 1] = true;
    });
  }

  Future<void> _confirmDeleteProduct(int index) async {
    final name = index < _prodNameCtrl.length
        ? _prodNameCtrl[index].text.trim() : '';
    final confirmed = await _showConfirmDialog(
      title: 'Remove Product',
      message: 'Remove ${name.isNotEmpty ? '"$name"' : 'this product'} from the list?',
      confirmLabel: 'Remove',
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _products.removeAt(index);
      if (index < _prodNameCtrl.length)
        _prodNameCtrl.removeAt(index).dispose();
      if (index < _prodQuantityCtrl.length)
        _prodQuantityCtrl.removeAt(index).dispose();
      if (index < _prodPackagingCtrl.length)
        _prodPackagingCtrl.removeAt(index).dispose();
      _shiftExpandedMap(_prodExpanded, index);
    });
  }

  void _shiftExpandedMap(Map<int, bool> map, int removed) {
    final rebuilt = <int, bool>{};
    map.forEach((k, v) {
      if (k < removed)      rebuilt[k]     = v;
      else if (k > removed) rebuilt[k - 1] = v;
    });
    map..clear()..addAll(rebuilt);
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool isDanger = true,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E))),
          content: Text(message,
              style: const TextStyle(
                  fontSize: 14, color: Colors.black54, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                  foregroundColor: isDanger ? kRed : kPrimary,
                  textStyle:
                      const TextStyle(fontWeight: FontWeight.w700)),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );

  // Validation
  bool _validateForm() {
    setState(() => _submitted = true);
    bool valid = true;

    final required = [
      _farmerNameCtrl, _dateOfEventCtrl, _farmAddressCtrl,
      _typeOfEventCtrl, _cellphoneCtrl, _venueOfEventCtrl,
      _cropsPlantedCtrl, _cropAdvisorNameCtrl, _cropAdvisorContactCtrl,
      _farmerNameSecondCtrl, _dateNeededCtrl, _preferredDealerCtrl,
    ];
    if (required.any((c) => c.text.trim().isEmpty)) valid = false;

    for (int i = 0; i < _advisoryDetails.length; i++) {
      final kcEmpty = i < _advKeyConcernCtrl.length
          ? _advKeyConcernCtrl[i].text.trim().isEmpty : true;
      final recEmpty = i < _advRecommendationCtrl.length
          ? _advRecommendationCtrl[i].text.trim().isEmpty : true;
      if (kcEmpty || recEmpty) {
        _advExpanded[i] = true;
        valid = false;
      }
    }

    for (int i = 0; i < _products.length; i++) {
      final nameEmpty = i < _prodNameCtrl.length
          ? _prodNameCtrl[i].text.trim().isEmpty : true;
      final qtyText = i < _prodQuantityCtrl.length
          ? _prodQuantityCtrl[i].text.trim() : '';
      final qtyInvalid =
          qtyText.isEmpty || int.tryParse(qtyText) == null;
      final packEmpty = i < _prodPackagingCtrl.length
          ? _prodPackagingCtrl[i].text.trim().isEmpty : true;
      if (nameEmpty || qtyInvalid || packEmpty) {
        _prodExpanded[i] = true;
        valid = false;
      }
    }

    if (_sigController.isEmpty) valid = false;

    if (!valid) _toast('Please fill out all required fields.', error: true);
    return valid;
  }

  // Toast
  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
        backgroundColor: error ? kRed : kGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
  }

  Map<String, dynamic> _exportSignature() {
    final List<Map<String, dynamic>> pts = [];
    if (!_sigController.isEmpty) {
      for (final p in _sigController.points) {
        if (p == null) continue;
        final dp  = p as dynamic;
        final Offset off = dp.offset as Offset;
        pts.add({
          'x':        off.dx,
          'y':        off.dy,
          'pressure': (dp.pressure ?? 1.0) as double,
          'type':     dp.type.toString(),
        });
      }
    }
    return {'name': _farmerNameSecondCtrl.text.trim(), 'points': pts};
  }

  Future<void> _saveChanges() async {
    if (!_validateForm()) return;
    setState(() => _isSaving = true);
    try {
      final List<Map<String, dynamic>> updatedAdv =
          List.generate(_advisoryDetails.length, (i) => {
            'keyConcern': i < _advKeyConcernCtrl.length
                ? _advKeyConcernCtrl[i].text.trim() : '',
            'productRecommendation': i < _advRecommendationCtrl.length
                ? _advRecommendationCtrl[i].text.trim() : '',
          });

      final List<Map<String, dynamic>> updatedProd =
          List.generate(_products.length, (i) => {
            'productName': i < _prodNameCtrl.length
                ? _prodNameCtrl[i].text.trim() : '',
            'quantity': i < _prodQuantityCtrl.length
                ? (int.tryParse(_prodQuantityCtrl[i].text.trim()) ?? 0) : 0,
            'packaging': i < _prodPackagingCtrl.length
                ? _prodPackagingCtrl[i].text.trim() : '',
          });

      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(widget.userKey)
          .doc('scp_forms')
          .collection('scp_forms')
          .doc(widget.docId)
          .update({
        'farmerName':            _farmerNameCtrl.text.trim(),
        'farmAddress':           _farmAddressCtrl.text.trim(),
        'cellphoneNumber':       _cellphoneCtrl.text.trim(),
        'dateOfEvent':           _dateOfEventCtrl.text.trim(),
        'cropsPlanted':          _cropsPlantedCtrl.text.trim(),
        'typeOfEvent':           _typeOfEventCtrl.text.trim(),
        'venueOfEvent':          _venueOfEventCtrl.text.trim(),
        'cropAdvisorName':       _cropAdvisorNameCtrl.text.trim(),
        'cropAdvisorContact':    _cropAdvisorContactCtrl.text.trim(),
        'farmerNameSecond':      _farmerNameSecondCtrl.text.trim(),
        'dateNeeded':            _dateNeededCtrl.text.trim(),
        'preferredDealer':       _preferredDealerCtrl.text.trim(),
        'advisoryDetails':       updatedAdv,
        'products':              updatedProd,
        'farmerSignaturePoints': _exportSignature(),
      });

      setState(() {
        _advisoryDetails = updatedAdv;
        _products        = updatedProd;
        _isEditMode      = false;
        _submitted       = false;
        _advExpanded.clear();
        _prodExpanded.clear();
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
    setState(() {
      _submitted = false;
      _populateFromData(_editSnapshot);
    });
    _toast('Form has been reset.');
  }

  // Placeholder
  String _placeholder(String label) {
    const map = {
      'Name of Farmer':              'e.g. Juan Dela Cruz',
      'Date of Event':               'e.g. 2026-02-14',
      'Farm Address':                'e.g. Brgy. San Jose, Laguna',
      'Type of Event':               'e.g. Field Day, Training',
      'Cellphone Number':            'e.g. 09XX XXX XXXX',
      'Venue of Event':              'e.g. Barangay Hall, San Jose',
      'Crops Planted':               'e.g. Rice, Corn, Vegetables',
      'Name of Crop Advisor':        'e.g. Maria Santos',
      'Crop Advisor Contact Number': 'e.g. 09XX XXX XXXX',
      'Date Needed':                 'e.g. 2026-03-01',
      'Preferred Dealer':            'e.g. AgriMart, San Jose',
      'Key Concerns':                'e.g. Pest infestation, disease outbreak…',
      'Product Recommendation':      'e.g. Apply Indofil M-45 at 2g/L every 7 days…',
      'Product Name':                'e.g. Indofil M-45',
      'Quantity':                    'e.g. 10',
      'Packaging':                   'e.g. 1 kg bag',
    };
    return map[label] ?? '';
  }

  Widget _secLabel(String t, {bool first = false}) => Padding(
        padding: EdgeInsets.only(left: 8, bottom: 8, top: first ? 4 : 20),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kPrimary,
                letterSpacing: 0.5)),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 3))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  // View helpers
  Widget _vFull(String label, String val, {bool last = false}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: kDivider))),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _uppercase(label),
              const SizedBox(height: 4),
              Text(
                val.trim().isEmpty ? 'No data' : val,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: val.trim().isEmpty ? kEmpty : Colors.black87),
              ),
            ]),
      );

  Widget _vTwo(String l1, String v1, String l2, String v2,
      {bool last = false}) =>
      Container(
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: kDivider))),
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
                ? const Border(right: BorderSide(color: kDivider))
                : null),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _uppercase(label),
              const SizedBox(height: 4),
              Text(
                val.trim().isEmpty ? 'No data' : val,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color:
                        val.trim().isEmpty ? kEmpty : Colors.black87),
              ),
            ]),
      );

  // Edit helpers
  Widget _eFull(Widget child, {bool last = false}) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: kDivider))),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: child,
      );

  Widget _eTwo(Widget left, Widget right, {bool last = false}) =>
      Container(
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: kDivider))),
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
                ? const Border(right: BorderSide(color: kDivider))
                : null),
        child: child,
      );

  Widget _eField(
    String label,
    TextEditingController ctrl, {
    bool req = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final bool isEmpty = _submitted && req && ctrl.text.trim().isEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _uppercaseReq(label, req),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black87),
        decoration: _filledDecoration(
          hintText: _placeholder(label),
          hasError: isEmpty,
        ),
        onChanged: (_) {
          if (_submitted) setState(() {});
        },
      ),
      if (isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Text('This field is required.',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: kRed)),
        ),
    ]);
  }

  Widget _dfView(String label, String val) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pfLabel(label),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F7FD),
                  border: Border.all(color: kBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  val.trim().isEmpty ? 'No data' : val,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: val.trim().isEmpty ? kEmpty : Colors.black87),
                ),
              ),
            ]),
      );

  Widget _dfEdit(
    String label,
    TextEditingController ctrl, {
    bool req = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final bool isEmpty = _submitted && req && ctrl.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pfLabelReq(label, req),
            const SizedBox(height: 4),
            TextField(
              controller: ctrl,
              maxLines: maxLines,
              keyboardType: keyboardType,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87),
              decoration: _filledDecoration(
                hintText: _placeholder(label),
                hasError: isEmpty,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
              ),
              onChanged: (_) {
                if (_submitted) setState(() {});
              },
            ),
            if (isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text('This field is required.',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kRed)),
              ),
          ]),
    );
  }

  Widget _df(
    String label,
    TextEditingController ctrl, {
    bool req = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    if (!_isEditMode) return _dfView(label, ctrl.text);
    return _dfEdit(label, ctrl,
        req: req, maxLines: maxLines, keyboardType: keyboardType);
  }

  Widget _dfTwoCol(Widget left, Widget right) => LayoutBuilder(
        builder: (context, constraints) {
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

  Widget _collapsibleCard({
    required String label,
    required int index,
    required bool isOpen,
    required Map<int, bool> expandedMap,
    required Widget body,
    Widget? trailing,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 3))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          InkWell(
            onTap: () =>
                setState(() => expandedMap[index] = !isOpen),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  kPrimaryDark.withValues(alpha: 0.07),
                  kPrimary.withValues(alpha: 0.03),
                ]),
              ),
              child: Row(children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [kPrimaryDark, kPrimary]),
                    shape: BoxShape.circle,
                  ),
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
                          color: kPrimary),
                      overflow: TextOverflow.ellipsis),
                ),
                if (trailing != null) trailing,
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(Icons.keyboard_arrow_down,
                      color: kPrimary, size: 20),
                ),
              ]),
            ),
          ),
          AnimatedCrossFade(
            firstChild:
                const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              child: body,
            ),
            crossFadeState: isOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ]),
      );

  // Section headers
  Widget _sectionBar(String title,
    {VoidCallback? onAdd, String? addLabel}) =>
    Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 20), // added left: 8
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kPrimary,
                    letterSpacing: 0.5)),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [kPrimaryDark, kPrimary]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: kPrimary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(addLabel ?? 'Add Row',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

  Widget _emptyNote(String msg) => Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 12, top: 2),
        child: Text(msg,
            style: const TextStyle(color: kEmpty, fontSize: 14)),
      );


  Widget _advisoryCard(int index) {
    final kcCtrl  = index < _advKeyConcernCtrl.length
        ? _advKeyConcernCtrl[index]     : TextEditingController();
    final recCtrl = index < _advRecommendationCtrl.length
        ? _advRecommendationCtrl[index] : TextEditingController();
    final isOpen  = _advExpanded[index] ?? false;

    final raw = kcCtrl.text.trim();
    final headerLabel = raw.isEmpty
        ? 'Advisory Detail ${index + 1}'
        : (raw.length > 40 ? '${raw.substring(0, 40)}…' : raw);

    return _collapsibleCard(
      label: headerLabel,
      index: index,
      isOpen: isOpen,
      expandedMap: _advExpanded,
      trailing: _isEditMode
          ? GestureDetector(
              onTap: () => _confirmDeleteAdvisory(index),
              child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline,
                      color: kRed, size: 18)),
            )
          : null,
      body: Column(children: [
        _df('Key Concerns', kcCtrl, req: true, maxLines: 2),
        _df('Product Recommendation', recCtrl, req: true, maxLines: 2),
      ]),
    );
  }

  Widget _productCard(int index) {
    final nameCtrl = index < _prodNameCtrl.length
        ? _prodNameCtrl[index]      : TextEditingController();
    final qtyCtrl  = index < _prodQuantityCtrl.length
        ? _prodQuantityCtrl[index]  : TextEditingController();
    final packCtrl = index < _prodPackagingCtrl.length
        ? _prodPackagingCtrl[index] : TextEditingController();
    final isOpen   = _prodExpanded[index] ?? false;

    final bool qtyErr = _submitted &&
        (qtyCtrl.text.trim().isEmpty ||
            int.tryParse(qtyCtrl.text.trim()) == null);

    final headerLabel = nameCtrl.text.trim().isEmpty
        ? 'Product ${index + 1}'
        : nameCtrl.text.trim();

    return _collapsibleCard(
      label: headerLabel,
      index: index,
      isOpen: isOpen,
      expandedMap: _prodExpanded,
      trailing: _isEditMode
          ? GestureDetector(
              onTap: () => _confirmDeleteProduct(index),
              child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline,
                      color: kRed, size: 18)),
            )
          : null,
      body: Column(children: [
        _df('Product Name', nameCtrl, req: true),
        _dfTwoCol(
          _isEditMode
              ? _dfEdit('Quantity', qtyCtrl,
                  req: true,
                  keyboardType: TextInputType.number)
              : _dfView('Quantity', qtyCtrl.text),
          _df('Packaging', packCtrl, req: true),
        ),
      ]),
    );
  }

  Widget _buildGeneralInfoCard() => _card([
        _eFull(_eField('Name of Farmer', _farmerNameCtrl, req: true)),
        _eFull(_eField('Date of Event', _dateOfEventCtrl, req: true)),
        _eTwo(
          _eField('Farm Address', _farmAddressCtrl, req: true),
          _eField('Type of Event', _typeOfEventCtrl, req: true),
        ),
        _eTwo(
          _eField('Cellphone Number', _cellphoneCtrl,
              req: true, keyboardType: TextInputType.phone),
          _eField('Venue of Event', _venueOfEventCtrl, req: true),
        ),
        _eFull(_eField('Crops Planted', _cropsPlantedCtrl, req: true),
            last: true),
      ]);

  Widget _buildGeneralInfoViewCard() => _card([
        _vFull('Name of Farmer', _farmerNameCtrl.text),
        _vFull('Date of Event', _dateOfEventCtrl.text),
        _vTwo('Farm Address', _farmAddressCtrl.text,
            'Type of Event', _typeOfEventCtrl.text),
        _vTwo('Cellphone Number', _cellphoneCtrl.text,
            'Venue of Event', _venueOfEventCtrl.text),
        _vFull('Crops Planted', _cropsPlantedCtrl.text, last: true),
      ]);

  Widget _buildCropAdvisorCard() => _isEditMode
      ? _card([
          _eTwo(
            _eField('Name of Crop Advisor', _cropAdvisorNameCtrl,
                req: true),
            _eField('Crop Advisor Contact Number',
                _cropAdvisorContactCtrl,
                req: true, keyboardType: TextInputType.phone),
            last: true,
          ),
        ])
      : _card([
          _vTwo(
            'Name of Crop Advisor', _cropAdvisorNameCtrl.text,
            'Crop Advisor Contact Number', _cropAdvisorContactCtrl.text,
            last: true,
          ),
        ]);

  Widget _buildFarmerAcknowledgmentCard() {
    final bool sigErr =
        _submitted && _isEditMode && _sigController.isEmpty;
    return _card([
      _isEditMode
          ? _eFull(
              _eField('Name of Farmer', _farmerNameSecondCtrl, req: true))
          : _vFull('Name of Farmer', _farmerNameSecondCtrl.text),
      _isEditMode
          ? _eTwo(
              _eField('Date Needed', _dateNeededCtrl, req: true),
              _eField('Preferred Dealer', _preferredDealerCtrl, req: true),
            )
          : _vTwo(
              'Date Needed', _dateNeededCtrl.text,
              'Preferred Dealer', _preferredDealerCtrl.text,
            ),
      // Signature
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _uppercase('Signature of Farmer'),
            if (_isEditMode)
              const Text(' *',
                  style: TextStyle(
                      color: kRed,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: sigErr ? kRed : kBorder,
                width: sigErr ? 1.5 : 1,
              ),
              color: Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: IgnorePointer(
                ignoring: !_isEditMode,
                child: Signature(
                  controller: _sigController,
                  width: double.infinity,
                  height: 100,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (sigErr)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('This field is required.',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: kRed)),
                  )
                else
                  const SizedBox.shrink(),
                if (_isEditMode)
                  TextButton(
                    onPressed: () =>
                        setState(() => _sigController.clear()),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('✕  CLEAR SIGNATURE',
                        style: TextStyle(fontSize: 12, color: kRed)),
                  ),
              ]),
          if (!_isEditMode && _sigController.isEmpty)
            const Center(
              child: Text('NO SIGNATURE ON RECORD',
                  style: TextStyle(
                      fontSize: 12,
                      color: kEmpty,
                      fontStyle: FontStyle.italic)),
            ),
        ]),
      ),
    ]);
  }

  Widget _uppercase(String t) => Text(t.toUpperCase(),
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: kMuted,
          letterSpacing: 0.5));

  Widget _uppercaseReq(String t, bool req) => Row(children: [
        _uppercase(t),
        if (req)
          const Text(' *',
              style: TextStyle(
                  color: kRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
      ]);

  Widget _pfLabel(String t) => Text(t.toUpperCase(),
      style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: kMuted,
          letterSpacing: 0.4));

  Widget _pfLabelReq(String t, bool req) => Row(children: [
        _pfLabel(t),
        if (req)
          const Text(' *',
              style: TextStyle(
                  color: kRed,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700)),
      ]);

  Widget _footer() => Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 28),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : _resetForm,
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimary,
                backgroundColor: kSurface,
                side: const BorderSide(color: kPrimary, width: 2),
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
                colors: [kPrimaryDark, kPrimaryDark, kPrimary],
                stops: [0, 0.55, 1],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: kPrimary.withValues(alpha: 0.44),
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
    final String appTitle = _farmerNameCtrl.text.trim().isEmpty
        ? 'Crop Prescription'
        : _farmerNameCtrl.text.trim();

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kPrimaryDark, kPrimaryDark, kPrimary],
              stops: [0, 0.55, 1],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(22),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left,
              color: Colors.white, size: 30),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('SAMPLE CROP PRESCRIPTION',
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 5),
              ),
              child: Text(
                _isEditMode ? 'CANCEL' : 'EDIT',
                style: TextStyle(
                    color: _isEditMode
                        ? Colors.white60
                        : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secLabel('General Information', first: true),
                _isEditMode
                    ? _buildGeneralInfoCard()
                    : _buildGeneralInfoViewCard(),

                _isEditMode
                    ? _sectionBar('Advisory Details',
                        onAdd: _addAdvisory,
                        addLabel: 'Add Advisory')
                    : _secLabel('Advisory Details'),
                if (_advisoryDetails.isEmpty)
                  _emptyNote('No advisory details recorded.')
                else
                  Column(
                    children: List.generate(
                        _advisoryDetails.length,
                        (i) => _advisoryCard(i)),
                  ),

                _secLabel('Crop Advisor Information'),
                _buildCropAdvisorCard(),

                _isEditMode
                    ? _sectionBar(
                        'Indofil Crop Solutions & Technologies',
                        onAdd: _addProduct,
                        addLabel: 'Add Product')
                    : _secLabel(
                        'Indofil Crop Solutions & Technologies'),
                if (_products.isEmpty)
                  _emptyNote('No products recorded.')
                else
                  Column(
                    children: List.generate(
                        _products.length, (i) => _productCard(i)),
                  ),

                _secLabel('Farmer Acknowledgment'),
                _buildFarmerAcknowledgmentCard(),

                if (_isEditMode) _footer(),
              ],
            ),
          ),
        ),
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

class _ScpFormTransactionsPageState
    extends State<ScpFormTransactionsPage> {
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

  Future<void> _navigateToScpFormPage(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScpFormPage()),
    );
    if (result == true) setState(() {});
  }

  void _openDetail(BuildContext context,
      Map<String, dynamic> formData, String docId) {
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
    final double cardWidth =
        (MediaQuery.of(context).size.width - 48) / 2;
    const double cardHeight = 170.0;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          elevation: 4,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24))),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24)),
              gradient: LinearGradient(
                colors: [kPrimaryDark, kPrimaryDark, kPrimary],
                stops: [0, 0.55, 1],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Text('SAMPLE CROP PRESCRIPTION FORMS',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
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
                  return const Center(
                      child: CircularProgressIndicator());
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
                      final doc  = docs[idx];
                      final data =
                          doc.data() as Map<String, dynamic>;
                      final String farmerName =
                          (data['farmerName'] ?? 'Unnamed Farmer')
                              .toString();
                      final String dateOfEvent =
                          (data['dateOfEvent'] ?? '-').toString();
                      final String cropsPlanted =
                          (data['cropsPlanted'] ?? '').toString();
                      final transactionLabel =
                          'SCP #${docs.length - idx}';

                      return SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () =>
                                _openDetail(context, data, doc.id),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [kPrimaryDark, kPrimary],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      const Icon(
                                          Icons.description_outlined,
                                          color: Colors.white,
                                          size: 30),
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
                                                    FontWeight.w600)),
                                      ),
                                    ]),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(farmerName,
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 18,
                                                  color: Colors.white)),
                                          const SizedBox(height: 4),
                                          if (cropsPlanted.isNotEmpty)
                                            Text(
                                                'Crop: $cropsPlanted',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12)),
                                          Text('Date: $dateOfEvent',
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12)),
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