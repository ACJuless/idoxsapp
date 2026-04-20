import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'abr_form_page.dart';

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

const _kGrad = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF4A2371), Color(0xFF4A2371), Color(0xFF5958B2)],
  stops: [0.0, 0.55, 1.0],
);

// Required fields
const Map<String, bool> _kRequired = {
  'agronomist':                    true,
  'area':                          true,
  'cropFocus':                     true,
  'activityType':                  true,
  'plannedLocation':               true,
  'actualLocation':                false,
  'plannedDate':                   true,
  'actualDate':                    false,
  'targetAttendees':               true,
  'actualAttendees':               false,
  'budgetPerAttendee':             true,
  'standardBudgetRequirement':     true,
  'additionalBudgetRequest':       false,
  'justificationAdditionalBudget': false,
  'totalBudgetRequested':          true,
  'actualBudgetSpent':             false,
  'totalTargetMoveoutValue':       true,
  'totalActualMoveoutValue':       false,
  'remarksActivityOutput':         true,
  'otherProductsSoldBooked':       false,
  'valueOtherProductsSoldBooked':  false,
  'productsDeliveredDealers':      false,
  'valueProductsDeliveredDealers': false,
  'productFocus':                  true,
  'targetMoveoutVolume':           true,
  'actualMoveoutVolume':           false,
  'targetMoveoutValuePf':          true,
  'actualMoveoutValuePf':          false,
};

class AbrFormReadonlyPage extends StatefulWidget {
  final Map<String, dynamic> formData;
  final String docId;
  final String userKey;

  const AbrFormReadonlyPage({
    Key? key,
    required this.formData,
    required this.docId,
    required this.userKey,
  }) : super(key: key);

  @override
  State<AbrFormReadonlyPage> createState() => _AbrFormReadonlyPageState();
}

class _AbrFormReadonlyPageState extends State<AbrFormReadonlyPage> {
  bool _isEditMode = false;
  bool _isSaving   = false;
  bool _submitted  = false;

  late Map<String, dynamic> _original;
  late TextEditingController _agronomistCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _cropFocusCtrl;
  late TextEditingController _activityTypeCtrl;
  late TextEditingController _plannedLocationCtrl;
  late TextEditingController _actualLocationCtrl;
  late TextEditingController _plannedDateCtrl;
  late TextEditingController _actualDateCtrl;
  late TextEditingController _targetAttendeesCtrl;
  late TextEditingController _actualAttendeesCtrl;
  late TextEditingController _budgetPerAttendeeCtrl;
  late TextEditingController _standardBudgetCtrl;
  late TextEditingController _additionalBudgetCtrl;
  late TextEditingController _justificationCtrl;
  late TextEditingController _totalBudgetCtrl;
  late TextEditingController _actualBudgetSpentCtrl;
  late TextEditingController _totalTargetMoveoutCtrl;
  late TextEditingController _totalActualMoveoutCtrl;
  late TextEditingController _remarksCtrl;
  late TextEditingController _otherProductsCtrl;
  late TextEditingController _valueOtherProductsCtrl;
  late TextEditingController _productsDeliveredCtrl;
  late TextEditingController _valueDeliveredCtrl;

  String _createdBy = '';
  List<_PFRowCtrls> _pfRows = [];
  final Set<int> _openPF    = {};

  @override
  void initState() {
    super.initState();
    _original = Map<String, dynamic>.from(widget.formData);
    _initControllers(_original);
  }

  void _initControllers(Map<String, dynamic> d) {
    _agronomistCtrl = TextEditingController(text: d['agronomist'] ?? '');
    _areaCtrl = TextEditingController(text: d['area'] ?? '');
    _cropFocusCtrl = TextEditingController(text: d['cropFocus'] ?? '');
    _activityTypeCtrl = TextEditingController(text: d['activityType'] ?? '');
    _plannedLocationCtrl = TextEditingController(text: d['plannedLocation'] ?? '');
    _actualLocationCtrl = TextEditingController(text: d['actualLocation'] ?? '');
    _plannedDateCtrl = TextEditingController(text: d['plannedDate'] ?? '');
    _actualDateCtrl = TextEditingController(text: d['actualDate'] ?? '');
    _targetAttendeesCtrl = TextEditingController(text: d['targetAttendees']?.toString() ?? '');
    _actualAttendeesCtrl = TextEditingController(text: d['actualAttendees']?.toString() ?? '');
    _budgetPerAttendeeCtrl = TextEditingController(text: d['budgetPerAttendee']?.toString() ?? '');
    _standardBudgetCtrl = TextEditingController(text: d['standardBudgetRequirement']?.toString() ?? '');
    _additionalBudgetCtrl = TextEditingController(text: d['additionalBudgetRequest']?.toString() ?? '');
    _justificationCtrl = TextEditingController(text: d['justificationAdditionalBudget'] ?? '');
    _totalBudgetCtrl = TextEditingController(text: d['totalBudgetRequested']?.toString() ?? '');
    _actualBudgetSpentCtrl = TextEditingController(text: d['actualBudgetSpent']?.toString() ?? '');
    _totalTargetMoveoutCtrl = TextEditingController(text: d['totalTargetMoveoutValue']?.toString() ?? '');
    _totalActualMoveoutCtrl = TextEditingController(text: d['totalActualMoveoutValue']?.toString() ?? '');
    _remarksCtrl = TextEditingController(text: d['remarksActivityOutput'] ?? '');
    _otherProductsCtrl = TextEditingController(text: d['otherProductsSoldBooked'] ?? '');
    _valueOtherProductsCtrl = TextEditingController(text: d['valueOtherProductsSoldBooked']?.toString() ?? '');
    _productsDeliveredCtrl = TextEditingController(text: d['productsDeliveredDealers'] ?? '');
    _valueDeliveredCtrl = TextEditingController(text: d['valueProductsDeliveredDealers']?.toString() ?? '');
    _createdBy = d['createdBy'] ?? '';

    final List<dynamic> raw = d['productFocusRows'] ?? [];
    _pfRows = raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .map((m) => _PFRowCtrls(
              productFocus: TextEditingController(text: m['productFocus']?.toString() ?? ''),
              targetMoveoutVolume: TextEditingController(text: m['targetMoveoutVolume']?.toString() ?? ''),
              actualMoveoutVolume: TextEditingController(text: m['actualMoveoutVolume']?.toString() ?? ''),
              targetMoveoutValuePf: TextEditingController(text: m['targetMoveoutValuePf']?.toString() ?? ''),
              actualMoveoutValuePf: TextEditingController(text: m['actualMoveoutValuePf']?.toString() ?? ''),
            ))
        .toList();
    _openPF.clear();
  }

  void _populateFromOriginal() {
    final d = _original;
    _agronomistCtrl.text         = d['agronomist']                            ?? '';
    _areaCtrl.text               = d['area']                                   ?? '';
    _cropFocusCtrl.text          = d['cropFocus']                              ?? '';
    _activityTypeCtrl.text       = d['activityType']                           ?? '';
    _plannedLocationCtrl.text    = d['plannedLocation']                        ?? '';
    _actualLocationCtrl.text     = d['actualLocation']                         ?? '';
    _plannedDateCtrl.text        = d['plannedDate']                            ?? '';
    _actualDateCtrl.text         = d['actualDate']                             ?? '';
    _targetAttendeesCtrl.text    = d['targetAttendees']?.toString()            ?? '';
    _actualAttendeesCtrl.text    = d['actualAttendees']?.toString()            ?? '';
    _budgetPerAttendeeCtrl.text  = d['budgetPerAttendee']?.toString()          ?? '';
    _standardBudgetCtrl.text     = d['standardBudgetRequirement']?.toString()  ?? '';
    _additionalBudgetCtrl.text   = d['additionalBudgetRequest']?.toString()    ?? '';
    _justificationCtrl.text      = d['justificationAdditionalBudget']          ?? '';
    _totalBudgetCtrl.text        = d['totalBudgetRequested']?.toString()       ?? '';
    _actualBudgetSpentCtrl.text  = d['actualBudgetSpent']?.toString()          ?? '';
    _totalTargetMoveoutCtrl.text = d['totalTargetMoveoutValue']?.toString()    ?? '';
    _totalActualMoveoutCtrl.text = d['totalActualMoveoutValue']?.toString()    ?? '';
    _remarksCtrl.text            = d['remarksActivityOutput']                  ?? '';
    _otherProductsCtrl.text      = d['otherProductsSoldBooked']                ?? '';
    _valueOtherProductsCtrl.text = d['valueOtherProductsSoldBooked']?.toString() ?? '';
    _productsDeliveredCtrl.text  = d['productsDeliveredDealers']               ?? '';
    _valueDeliveredCtrl.text     = d['valueProductsDeliveredDealers']?.toString()  ?? '';

    for (final r in _pfRows) r.dispose();
    final List<dynamic> raw = d['productFocusRows'] ?? [];
    _pfRows = raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .map((m) => _PFRowCtrls(
              productFocus:         TextEditingController(text: m['productFocus']?.toString()         ?? ''),
              targetMoveoutVolume:  TextEditingController(text: m['targetMoveoutVolume']?.toString()  ?? ''),
              actualMoveoutVolume:  TextEditingController(text: m['actualMoveoutVolume']?.toString()  ?? ''),
              targetMoveoutValuePf: TextEditingController(text: m['targetMoveoutValuePf']?.toString() ?? ''),
              actualMoveoutValuePf: TextEditingController(text: m['actualMoveoutValuePf']?.toString() ?? ''),
            ))
        .toList();
    _openPF.clear();
  }

  @override
  void dispose() {
    _agronomistCtrl.dispose();
    _areaCtrl.dispose();
    _cropFocusCtrl.dispose();
    _activityTypeCtrl.dispose();
    _plannedLocationCtrl.dispose();
    _actualLocationCtrl.dispose();
    _plannedDateCtrl.dispose();
    _actualDateCtrl.dispose();
    _targetAttendeesCtrl.dispose();
    _actualAttendeesCtrl.dispose();
    _budgetPerAttendeeCtrl.dispose();
    _standardBudgetCtrl.dispose();
    _additionalBudgetCtrl.dispose();
    _justificationCtrl.dispose();
    _totalBudgetCtrl.dispose();
    _actualBudgetSpentCtrl.dispose();
    _totalTargetMoveoutCtrl.dispose();
    _totalActualMoveoutCtrl.dispose();
    _remarksCtrl.dispose();
    _otherProductsCtrl.dispose();
    _valueOtherProductsCtrl.dispose();
    _productsDeliveredCtrl.dispose();
    _valueDeliveredCtrl.dispose();
    for (final r in _pfRows) r.dispose();
    super.dispose();
  }

  // Validation
  bool _req(String key, TextEditingController ctrl) =>
      !(_kRequired[key] == true) || ctrl.text.trim().isNotEmpty;

  bool get _formValid =>
      _req('agronomist',                _agronomistCtrl)        &&
      _req('area',                      _areaCtrl)              &&
      _req('cropFocus',                 _cropFocusCtrl)         &&
      _req('activityType',              _activityTypeCtrl)      &&
      _req('plannedLocation',           _plannedLocationCtrl)   &&
      _req('plannedDate',               _plannedDateCtrl)       &&
      _req('targetAttendees',           _targetAttendeesCtrl)   &&
      _req('budgetPerAttendee',         _budgetPerAttendeeCtrl) &&
      _req('standardBudgetRequirement', _standardBudgetCtrl)    &&
      _req('totalBudgetRequested',      _totalBudgetCtrl)       &&
      _req('totalTargetMoveoutValue',   _totalTargetMoveoutCtrl)&&
      _req('remarksActivityOutput',     _remarksCtrl)           &&
      _pfRows.every((r) =>
          r.productFocus.text.trim().isNotEmpty &&
          r.targetMoveoutVolume.text.trim().isNotEmpty &&
          r.targetMoveoutValuePf.text.trim().isNotEmpty);

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
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600
                )
            ),
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

  // Confirm dialogs
  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    String confirmLabel = 'CONFIRM',
    Color confirmColor  = _kRed,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)
          ),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E)
              )
          ),
          content: Text(message,
              style: const TextStyle(
                  fontSize: 14, color: Colors.black54, height: 1.5
              )
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('CANCEL',
                  style: TextStyle(color: Colors.grey)
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                  foregroundColor: confirmColor,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700)),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );

  // Reset
  Future<void> _handleReset() async {
    final confirmed = await _showConfirmDialog(
      title: 'RESET FORM',
      message: 'This will restore all fields to their last saved values. Continue?',
      confirmLabel: 'RESET',
    );
    if (confirmed != true) return;
    setState(() {
      _submitted = false;
      _populateFromOriginal();
    });
    _toast('Form has been reset.');
  }

  // Product Focus
  void _addPFRow() {
    setState(() {
      _pfRows.add(_PFRowCtrls(
        productFocus:         TextEditingController(),
        targetMoveoutVolume:  TextEditingController(),
        actualMoveoutVolume:  TextEditingController(),
        targetMoveoutValuePf: TextEditingController(),
        actualMoveoutValuePf: TextEditingController(),
      ));
      _openPF.add(_pfRows.length - 1);
    });
  }

  Future<void> _confirmRemovePF(int idx) async {
    final name = _pfRows[idx].productFocus.text.trim();
    final ok = await _showConfirmDialog(
      title: 'REMOVE PRODUCT FOCUS',
      message: name.isNotEmpty
          ? 'Remove "$name" from the list?'
          : 'Remove this product focus entry?',
      confirmLabel: 'REMOVE',
    );
    if (ok != true || !mounted) return;
    setState(() {
      _pfRows[idx].dispose();
      _pfRows.removeAt(idx);
      final rebuilt = <int>{};
      for (final k in _openPF) {
        if (k < idx) rebuilt.add(k);
        else if (k > idx) rebuilt.add(k - 1);
      }
      _openPF..clear()..addAll(rebuilt);
    });
  }

  // Save
  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_formValid) {
      _toast('Please fill out all required fields.', error: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final pfData = _pfRows.map((r) => {
        'productFocus':         r.productFocus.text.trim(),
        'targetMoveoutVolume':  r.targetMoveoutVolume.text.trim(),
        'actualMoveoutVolume':  r.actualMoveoutVolume.text.trim(),
        'targetMoveoutValuePf': r.targetMoveoutValuePf.text.trim(),
        'actualMoveoutValuePf': r.actualMoveoutValuePf.text.trim(),
      }).toList();

      final update = {
        'agronomist':                    _agronomistCtrl.text.trim(),
        'area':                          _areaCtrl.text.trim(),
        'cropFocus':                     _cropFocusCtrl.text.trim(),
        'activityType':                  _activityTypeCtrl.text.trim(),
        'plannedLocation':               _plannedLocationCtrl.text.trim(),
        'actualLocation':                _actualLocationCtrl.text.trim(),
        'plannedDate':                   _plannedDateCtrl.text.trim(),
        'actualDate':                    _actualDateCtrl.text.trim(),
        'targetAttendees':               _targetAttendeesCtrl.text.trim(),
        'actualAttendees':               _actualAttendeesCtrl.text.trim(),
        'budgetPerAttendee':             _budgetPerAttendeeCtrl.text.trim(),
        'standardBudgetRequirement':     _standardBudgetCtrl.text.trim(),
        'additionalBudgetRequest':       _additionalBudgetCtrl.text.trim(),
        'justificationAdditionalBudget': _justificationCtrl.text.trim(),
        'totalBudgetRequested':          _totalBudgetCtrl.text.trim(),
        'actualBudgetSpent':             _actualBudgetSpentCtrl.text.trim(),
        'totalTargetMoveoutValue':       _totalTargetMoveoutCtrl.text.trim(),
        'totalActualMoveoutValue':       _totalActualMoveoutCtrl.text.trim(),
        'remarksActivityOutput':         _remarksCtrl.text.trim(),
        'otherProductsSoldBooked':       _otherProductsCtrl.text.trim(),
        'valueOtherProductsSoldBooked':  _valueOtherProductsCtrl.text.trim(),
        'productsDeliveredDealers':      _productsDeliveredCtrl.text.trim(),
        'valueProductsDeliveredDealers': _valueDeliveredCtrl.text.trim(),
        'productFocusRows':              pfData,
      };

      await FirebaseFirestore.instance
          .collection('flowDB').doc('users')
          .collection(widget.userKey).doc('abr_forms')
          .collection('abr_forms').doc(widget.docId)
          .update(update);

      _original.addAll(update);
      setState(() {
        _isEditMode = false;
        _submitted  = false;
      });
      _toast('ABR form updated successfully.');
    } catch (e) {
      if (mounted) _toast('Failed to update: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _agronomistCtrl.text.trim().isEmpty
        ? 'Activity Budget Request'
        : _agronomistCtrl.text.trim();

    return Scaffold(
      backgroundColor: _kSurface,

      // App Bar
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: _kGrad,
            borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(22),
                bottomRight: Radius.circular(22)
            ),
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
            const Text('ACTIVITY BUDGET REQUEST',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white60,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            Text(title.toUpperCase(),
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
              onPressed: _isSaving ? null : () {
                if (_isEditMode) {
                  setState(() {
                    _populateFromOriginal();
                    _submitted  = false;
                    _isEditMode = false;
                  });
                } else {
                  setState(() => _isEditMode = true);
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              ),
              child: Text(
                _isEditMode 
                    ? 'CANCEL' 
                    : 'EDIT',
                style: TextStyle(
                    color:
                        _isEditMode ? Colors.white60 : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                _secLabel('GENERAL INFORMATION', first: true),
                _buildGeneralCard(),

                _secLabel('BUDGET INFORMATION'),
                _buildBudgetCard(),

                _isEditMode
                    ? _sectionBar('PRODUCT FOCUS', onAdd: _addPFRow)
                    : _secLabel('PRODUCT FOCUS'),
                _buildPFSection(),

                _secLabel('MOVEOUT SUMMARY'),
                _buildMoveoutCard(),

                _secLabel('OTHER SALES & DELIVERIES'),
                _buildOtherSalesCard(),

                if (_createdBy.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildCreatedByCard(),
                ],

                if (_isEditMode) _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Footer
  Widget _footer() => Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 28),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : _handleReset,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kPrimary,
                backgroundColor: _kSurface,
                side: const BorderSide(color: _kPrimary, width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('RESET',
                  style: TextStyle(
                    fontSize: 15, 
                    fontWeight: FontWeight.w700
                  )
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _gradBtn('UPDATE FORM', _save)),
        ]),
      );

  Widget _gradBtn(String label, VoidCallback onTap) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _isSaving ? null : onTap,
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              gradient: _kGrad,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: _kPrimary.withValues(alpha: 0.44),
                    blurRadius: 18,
                    offset: const Offset(0, 5)
                )
              ],
            ),
            child: Center(
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, 
                          color: Colors.white
                        )
                    )
                  : Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700
                      )
                    ),
            ),
          ),
        ),
      );

  // Section Headers
  Widget _secLabel(String t, {bool first = false}) => Padding(
        padding: EdgeInsets.only(left: 8, bottom: 8, top: first ? 4 : 20),
        child: Text(t,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kPrimary,
                letterSpacing: 0.5
            )
        ),
      );

  Widget _sectionBar(String title, {VoidCallback? onAdd}) => Padding(
        padding: const EdgeInsets.only(left: 8, right: 8, top: 20, bottom: 8),
        child: Row(children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kPrimary,
                  letterSpacing: 0.5
              )
          ),
          const Spacer(),
          if (onAdd != null)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6
                ),
                decoration: BoxDecoration(
                  gradient: _kGrad,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: _kPrimary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2)
                    )
                  ],
                ),
                child: const Row(children: [
                  Icon(Icons.add, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('ADD ROW',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700
                      )
                  ),
                ]),
              ),
            ),
        ]),
      );

  // Cards
  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 3))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children),
      );

  // Section cards
  Widget _buildGeneralCard() => _card([
        _eTwo(
          _field('AGRONOMIST',    _agronomistCtrl,   'agronomist'),
          _field('AREA',          _areaCtrl,          'area'),
        ),
        _eTwo(
          _field('CROP FOCUS',    _cropFocusCtrl,    'cropFocus'),
          _field('ACTIVITY TYPE', _activityTypeCtrl, 'activityType'),
        ),
        _eFull(_field('PLANNED ACTIVITY LOCATION', _plannedLocationCtrl, 'plannedLocation')),
        _eFull(_field('ACTUAL ACTIVITY LOCATION',  _actualLocationCtrl,  'actualLocation')),
        _eTwo(
          _field('PLANNED ACTIVITY DATE', _plannedDateCtrl, 'plannedDate'),
          _field('ACTUAL ACTIVITY DATE',  _actualDateCtrl,  'actualDate'),
        ),
        _eTwo(
          _field('TARGET NO. OF ATTENDEES', _targetAttendeesCtrl, 'targetAttendees',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          _field('ACTUAL NO. OF ATTENDEES', _actualAttendeesCtrl, 'actualAttendees',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          last: true,
        ),
      ]);

  Widget _buildBudgetCard() => _card([
        _eFull(_pesoField('BUDGET PER ATTENDEE',         _budgetPerAttendeeCtrl, 'budgetPerAttendee')),
        _eFull(_pesoField('STANDARD BUDGET REQUIREMENT', _standardBudgetCtrl,    'standardBudgetRequirement')),
        _eFull(_pesoField('ADDITIONAL BUDGET REQUEST',   _additionalBudgetCtrl,  'additionalBudgetRequest')),
        _eFull(_field('JUSTIFICATION FOR ADDITIONAL BUDGET',
            _justificationCtrl, 'justificationAdditionalBudget', maxLines: 3)),
        _eTwo(
          _pesoField('TOTAL BUDGET REQUESTED', _totalBudgetCtrl,       'totalBudgetRequested'),
          _pesoField('ACTUAL BUDGET SPENT',    _actualBudgetSpentCtrl, 'actualBudgetSpent'),
          last: true,
        ),
      ]);

  Widget _buildMoveoutCard() => _card([
        _eTwo(
          _pesoField('TOTAL TARGET MOVEOUT VALUE', _totalTargetMoveoutCtrl, 'totalTargetMoveoutValue'),
          _pesoField('TOTAL ACTUAL MOVEOUT VALUE',  _totalActualMoveoutCtrl, 'totalActualMoveoutValue'),
        ),
        _eFull(
          _field('REMARKS ON ACTIVITY OUTPUT', _remarksCtrl,
              'remarksActivityOutput', maxLines: 3),
          last: true,
        ),
      ]);

  Widget _buildOtherSalesCard() => _card([
        _eTwo(
          _field('OTHER PRODUCTS SOLD / BOOKED',  _otherProductsCtrl,    'otherProductsSoldBooked',  maxLines: 2),
          _field('PRODUCTS DELIVERED TO DEALERS', _productsDeliveredCtrl,'productsDeliveredDealers', maxLines: 2),
        ),
        _eTwo(
          _pesoField('VALUE OF OTHER PRODUCTS',    _valueOtherProductsCtrl, 'valueOtherProductsSoldBooked'),
          _pesoField('VALUE OF DELIVERED PRODUCTS', _valueDeliveredCtrl,    'valueProductsDeliveredDealers'),
          last: true,
        ),
      ]);

  Widget _buildCreatedByCard() => Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const Icon(Icons.person, size: 18, color: _kPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('CREATED BY: ${_createdBy.toUpperCase()}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kMuted)),
          ),
        ]),
      );

  // Product Focus
  Widget _buildPFSection() {
    if (_pfRows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 12),
        child: Text('No product focus entries recorded.',
            style: const TextStyle(fontSize: 14, color: _kEmpty)),
      );
    }
    return Column(
      children: _pfRows.asMap().entries.map((e) {
        final idx    = e.key;
        final row    = e.value;
        final isOpen = _openPF.contains(idx);
        final label  = row.productFocus.text.trim().isNotEmpty
            ? row.productFocus.text.trim().toUpperCase()
            : 'PRODUCT FOCUS ${idx + 1}';

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
              onTap: () => setState(() {
                isOpen ? _openPF.remove(idx) : _openPF.add(idx);
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _kPrimaryDark.withValues(alpha: 0.07),
                    _kPrimary.withValues(alpha: 0.03),
                  ]),
                ),
                child: Row(children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                        gradient: _kGrad, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${idx + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kPrimary)),
                  ),
                  if (_isEditMode)
                    GestureDetector(
                      onTap: () => _confirmRemovePF(idx),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.delete_outline,
                            color: _kRed, size: 18),
                      ),
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
              firstChild:
                  const SizedBox(width: double.infinity, height: 0),
              secondChild: _buildPFBody(row, idx),
              crossFadeState: isOpen
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildPFBody(_PFRowCtrls row, int idx) {
    final pfErr   = _submitted && row.productFocus.text.trim().isEmpty;
    final tMvErr  = _submitted && row.targetMoveoutVolume.text.trim().isEmpty;
    final tMvVErr = _submitted && row.targetMoveoutValuePf.text.trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      child: Column(children: [
        _pfField('PRODUCT FOCUS', row.productFocus, 'productFocus',
            hasError: pfErr,
            onChanged: (_) => setState(() {})),
        _pfTwoCol(
          _pfField('TARGET MOVEOUT VOLUME', row.targetMoveoutVolume,
              'targetMoveoutVolume',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              hasError: tMvErr,
              onChanged: (_) { if (_submitted) setState(() {}); }),
          _pfField('ACTUAL MOVEOUT VOLUME', row.actualMoveoutVolume,
              'actualMoveoutVolume',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        ),
        _pfTwoCol(
          _pfPesoField('TARGET MOVEOUT VALUE PF', row.targetMoveoutValuePf,
              'targetMoveoutValuePf',
              hasError: tMvVErr,
              onChanged: (_) { if (_submitted) setState(() {}); }),
          _pfPesoField('ACTUAL MOVEOUT VALUE PF', row.actualMoveoutValuePf,
              'actualMoveoutValuePf'),
        ),
      ]),
    );
  }

  // Helpers
  Widget _eTwo(Widget left, Widget right, {bool last = false}) =>
      Container(
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

  Widget _eFull(Widget child, {bool last = false}) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: _kDivider))),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: child,
      );

  Widget _ePad(Widget child, {bool rightBorder = false}) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
            border: rightBorder
                ? const Border(right: BorderSide(color: _kDivider))
                : null),
        child: child,
      );

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

  Widget _field(
    String label,
    TextEditingController ctrl,
    String key, {
    int maxLines                    = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    if (!_isEditMode) return _viewCell(label, ctrl.text);

    final required  = _kRequired[key] == true;
    final showError = _submitted && required && ctrl.text.trim().isEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _labelRow(label, required),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
        decoration: _eDeco(hasError: showError),
        onChanged: (_) { if (_submitted) setState(() {}); },
      ),
      if (showError) _errText(),
    ]);
  }

  Widget _pesoField(
    String label,
    TextEditingController ctrl,
    String key,
  ) {
    if (!_isEditMode) {
      final val = ctrl.text.trim();
      return _viewCell(label, val.isNotEmpty ? '₱ $val' : '');
    }

    final required  = _kRequired[key] == true;
    final showError = _submitted && required && ctrl.text.trim().isEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _labelRow(label, required),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
        ],
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
        decoration: _eDeco(hasError: showError).copyWith(
          prefixText: '₱ ',
          prefixStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kMuted),
        ),
        onChanged: (_) { if (_submitted) setState(() {}); },
      ),
      if (showError) _errText(),
    ]);
  }

  Widget _pfField(
    String label,
    TextEditingController ctrl,
    String key, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool hasError              = false,
    ValueChanged<String>? onChanged,
  }) {
    if (!_isEditMode) return _pfViewCell(label, ctrl.text);

    final required = _kRequired[key] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _labelRow(label, required, small: true),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87),
          decoration: _pfDeco(hasError: hasError),
          onChanged: onChanged,
        ),
        if (hasError) _errText(small: true),
      ]),
    );
  }

  Widget _pfPesoField(
    String label,
    TextEditingController ctrl,
    String key, {
    bool hasError              = false,
    ValueChanged<String>? onChanged,
  }) {
    if (!_isEditMode) {
      final val = ctrl.text.trim();
      return _pfViewCell(label, val.isNotEmpty ? '₱ $val' : '');
    }

    final required = _kRequired[key] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _labelRow(label, required, small: true),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          ],
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87),
          decoration: _pfDeco(hasError: hasError).copyWith(
            prefixText: '₱ ',
            prefixStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kMuted),
          ),
          onChanged: onChanged,
        ),
        if (hasError) _errText(small: true),
      ]),
    );
  }

  Widget _viewCell(String label, String val) {
    final empty = val.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _kMuted,
                letterSpacing: 0.5)),
        const SizedBox(height: 3),
        Text(
          empty ? '—' : val.trim(),
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: empty ? _kEmpty : Colors.black87),
        ),
      ],
    );
  }

  Widget _pfViewCell(String label, String val) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _kMuted,
                  letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
                color: const Color(0xFFF9F7FD),
                border: Border.all(color: _kBorder),
                borderRadius: BorderRadius.circular(8)),
            child: Text(val.trim().isEmpty ? '—' : val,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: val.trim().isEmpty ? _kEmpty : Colors.black87)),
          ),
        ]),
      );

  InputDecoration _eDeco({bool hasError = false}) => InputDecoration(
        filled: true,
        fillColor: hasError ? const Color(0x0ADC2626) : _kFieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(
                color: hasError ? _kRed : _kPrimary.withValues(alpha: 0.25),
                width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(
                color: hasError ? _kRed : _kPrimary.withValues(alpha: 0.25),
                width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(
                color: hasError ? _kRed : _kPrimary, width: 1.5)),
        isDense: true,
      );

  InputDecoration _pfDeco({bool hasError = false}) => InputDecoration(
        filled: true,
        fillColor: hasError
            ? const Color(0x0ADC2626)
            : _kPrimary.withValues(alpha: 0.03),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: hasError ? _kRed : _kPrimary.withValues(alpha: 0.22),
                width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: hasError ? _kRed : _kPrimary.withValues(alpha: 0.22),
                width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: hasError ? _kRed : _kPrimary, width: 1.5)),
        isDense: true,
      );

  Widget _labelRow(String label, bool required, {bool small = false}) =>
      Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: small ? 10.5 : 11,
                fontWeight: FontWeight.w700,
                color: _kMuted,
                letterSpacing: 0.5)),
        if (required)
          Text(' *',
              style: TextStyle(
                  fontSize: small ? 10.5 : 11,
                  fontWeight: FontWeight.w700,
                  color: _kRed)),
      ]);

  Widget _errText({bool small = false}) => Padding(
        padding: const EdgeInsets.only(top: 3, left: 2),
        child: Text('This field is required.',
            style: TextStyle(
                fontSize: small ? 11.0 : 11.5,
                fontWeight: FontWeight.w600,
                color: _kRed)),
      );
}

class _PFRowCtrls {
  final TextEditingController productFocus;
  final TextEditingController targetMoveoutVolume;
  final TextEditingController actualMoveoutVolume;
  final TextEditingController targetMoveoutValuePf;
  final TextEditingController actualMoveoutValuePf;

  _PFRowCtrls({
    required this.productFocus,
    required this.targetMoveoutVolume,
    required this.actualMoveoutVolume,
    required this.targetMoveoutValuePf,
    required this.actualMoveoutValuePf,
  });

  void dispose() {
    productFocus.dispose();
    targetMoveoutVolume.dispose();
    actualMoveoutVolume.dispose();
    targetMoveoutValuePf.dispose();
    actualMoveoutValuePf.dispose();
  }
}

class AbrFormTransactionsPage extends StatefulWidget {
  const AbrFormTransactionsPage({Key? key}) : super(key: key);

  @override
  State<AbrFormTransactionsPage> createState() =>
      _AbrFormTransactionsPageState();
}

class _AbrFormTransactionsPageState extends State<AbrFormTransactionsPage> {
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
        context, MaterialPageRoute(builder: (_) => AbrFormPage()));
    if (result == true) setState(() {});
  }

  void _openDetail(
      BuildContext context, Map<String, dynamic> formData, String docId) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AbrFormReadonlyPage(
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
              gradient: _kGrad,
            ),
          ),
          title: const Text('ABR FORM TRANSACTIONS',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New ABR Form',
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
                  .collection(userKey).doc('abr_forms')
                  .collection('abr_forms')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                        'No ABR forms yet. Tap + to create a new.',
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
                      final doc         = docs[idx];
                      final data        = doc.data() as Map<String, dynamic>;
                      final agronomist  = data['agronomist']?.toString() ?? '';
                      final plannedDate = data['plannedDate']?.toString() ?? '-';
                      final label       = 'ABR #${docs.length - idx}';

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
                                gradient: _kGrad,
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      const Icon(Icons.assignment,
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
                                            agronomist.isNotEmpty
                                                ? agronomist.toUpperCase()
                                                : 'UNNAMED',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.white)),
                                        const SizedBox(height: 4),
                                        Text('DATE: $plannedDate',
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