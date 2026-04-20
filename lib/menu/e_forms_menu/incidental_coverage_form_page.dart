import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Theme constants
const Color kPrimary     = Color(0xFF5958B2);
const Color kPrimaryDark = Color(0xFF4A2371);
const Color kSurface     = Color(0xFFF9F5FF);
const Color kCard        = Color(0xFFFFFFFF);
const Color kFieldFill   = Color(0x0A6B21C8);
const Color kMuted       = Color(0xFF2B2B2B);
const Color kRed         = Color(0xFFDC2626);
const Color kGreen       = Color(0xFF059669);
const Color kEmpty       = Color(0xFF9CA3AF);

const _kGrad = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF4A2371), Color(0xFF4A2371), Color(0xFF5958B2)],
  stops: [0.0, 0.55, 1.0],
);

class IncidentalCoverageFormPage extends StatefulWidget {
  final Map<String, dynamic> formData;
  final String docId;
  final String userKey;

  const IncidentalCoverageFormPage({
    required this.formData,
    required this.docId,
    required this.userKey,
    Key? key,
  }) : super(key: key);

  @override
  State<IncidentalCoverageFormPage> createState() =>
      _IncidentalCoverageFormPageState();
}

class _IncidentalCoverageFormPageState
    extends State<IncidentalCoverageFormPage> {

  bool _isEditMode = false;
  bool _isSaving   = false;
  bool _submitted  = false;

  late Map<String, dynamic> _original;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _firstNameCtrl;
  late TextEditingController _middleNameCtrl;
  late TextEditingController _specialtyCtrl;
  late TextEditingController _hospitalCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _preCallCtrl;
  late TextEditingController _postCallCtrl;

  @override
  void initState() {
    super.initState();
    _original = Map<String, dynamic>.from(widget.formData);
    _init(_original);
  }

  void _init(Map<String, dynamic> d) {
    _lastNameCtrl   = TextEditingController(text: d['lastName']             as String? ?? '');
    _firstNameCtrl  = TextEditingController(text: d['firstName']            as String? ?? '');
    _middleNameCtrl = TextEditingController(text: d['middleName']           as String? ?? '');
    _specialtyCtrl  = TextEditingController(text: d['specialty']            as String? ?? '');
    _hospitalCtrl   = TextEditingController(text: d['hospitalPharmacyName'] as String? ?? '');
    _dateCtrl       = TextEditingController(text: d['dateOfCover']          as String? ?? '');
    _preCallCtrl    = TextEditingController(text: d['preCallNotes']         as String? ?? '');
    _postCallCtrl   = TextEditingController(text: d['postCallNotes']        as String? ?? '');
  }

  void _disposeControllers() {
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _specialtyCtrl.dispose();
    _hospitalCtrl.dispose();
    _dateCtrl.dispose();
    _preCallCtrl.dispose();
    _postCallCtrl.dispose();
  }

  void _populateFromOriginal() {
    _lastNameCtrl.text   = _original['lastName']             as String? ?? '';
    _firstNameCtrl.text  = _original['firstName']            as String? ?? '';
    _middleNameCtrl.text = _original['middleName']           as String? ?? '';
    _specialtyCtrl.text  = _original['specialty']            as String? ?? '';
    _hospitalCtrl.text   = _original['hospitalPharmacyName'] as String? ?? '';
    _dateCtrl.text       = _original['dateOfCover']          as String? ?? '';
    _preCallCtrl.text    = _original['preCallNotes']         as String? ?? '';
    _postCallCtrl.text   = _original['postCallNotes']        as String? ?? '';
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dateCtrl.text) ?? DateTime.now();
    final picked  = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kPrimary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dateCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  // Validation
  bool get _lastNameValid   => _lastNameCtrl.text.trim().isNotEmpty;
  bool get _firstNameValid  => _firstNameCtrl.text.trim().isNotEmpty;
  bool get _middleNameValid => _middleNameCtrl.text.trim().isNotEmpty;
  bool get _specialtyValid  => _specialtyCtrl.text.trim().isNotEmpty;
  bool get _hospitalValid   => _hospitalCtrl.text.trim().isNotEmpty;
  bool get _dateValid       => _dateCtrl.text.trim().isNotEmpty;
  bool get _preCallValid    => _preCallCtrl.text.trim().isNotEmpty;
  bool get _postCallValid   => _postCallCtrl.text.trim().isNotEmpty;
  bool get _formValid =>
      _lastNameValid && _firstNameValid && _middleNameValid &&
      _specialtyValid && _hospitalValid && _dateValid &&
      _preCallValid && _postCallValid;

  // Toast
  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
            error ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        backgroundColor: error ? kRed : kGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
  }

  // Reset
  Future<void> _handleReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Reset Form',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This will restore all fields to their last saved values. Continue?',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Reset',
              style: TextStyle(color: kRed, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _submitted = false;
      _populateFromOriginal();
    });
    _toast('Form has been reset.');
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
      final update = {
        'lastName':             _lastNameCtrl.text.trim(),
        'firstName':            _firstNameCtrl.text.trim(),
        'middleName':           _middleNameCtrl.text.trim(),
        'specialty':            _specialtyCtrl.text.trim(),
        'hospitalPharmacyName': _hospitalCtrl.text.trim(),
        'dateOfCover':          _dateCtrl.text.trim(),
        'preCallNotes':         _preCallCtrl.text.trim(),
        'postCallNotes':        _postCallCtrl.text.trim(),
      };

      await FirebaseFirestore.instance
          .collection('flowDB').doc('users')
          .collection(widget.userKey).doc('inc_cov_forms')
          .collection('inc_cov_forms').doc(widget.docId)
          .update(update);

      _original.addAll(update);

      setState(() {
        _isEditMode = false;
        _submitted  = false;
      });
      _toast('Form updated successfully.');
    } catch (e) {
      if (mounted) _toast('Failed to update: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Helpers
  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      const months = [
        'January','February','March','April','May','June',
        'July','August','September','October','November','December',
      ];
      return '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
    } catch (_) { return raw; }
  }

  String get _appbarTitle {
    final first  = _firstNameCtrl.text.trim();
    final middle = _middleNameCtrl.text.trim();
    final last   = _lastNameCtrl.text.trim();
    final name   = [first, middle, last].where((s) => s.isNotEmpty).join(' ');
    return name.isNotEmpty ? name : 'Incidental Coverage';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: _kGrad,
            borderRadius: BorderRadius.only(
              bottomLeft:  Radius.circular(22),
              bottomRight: Radius.circular(22),
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
            const Text(
              'INCIDENTAL COVERAGE FORM',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white60,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              _appbarTitle.toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              ),
              child: Text(
                _isEditMode ? 'CANCEL' : 'EDIT',
                style: TextStyle(
                  color: _isEditMode ? Colors.white60 : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
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
                _sectionLabel('Personal Information', first: true),
                _buildPersonalCard(_isEditMode),

                _sectionLabel('Coverage Details'),
                _buildCoverageCard(_isEditMode),

                _sectionLabel('Call Notes'),
                _buildCallNotesCard(_isEditMode),

                if (_isEditMode) _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer() => Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 28),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : _handleReset,
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimary,
                backgroundColor: kSurface,
                side: const BorderSide(color: kPrimary, width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                'RESET',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kPrimaryDark, kPrimaryDark, kPrimary],
                stops: [0.0, 0.55, 1.0],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: kPrimary.withValues(alpha: 0.44),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: _isSaving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      );

  // Section label
  Widget _sectionLabel(String text, {bool first = false}) => Padding(
        padding: EdgeInsets.only(left: 8, bottom: 8, top: first ? 4 : 20),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kPrimary,
            letterSpacing: 0.5,
          ),
        ),
      );

  // Card
  Widget _card(List<Widget> rows) => Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        ),
      );

  // View
  Widget _vRow(String label, String value, {bool isLast = false}) {
    final empty = value.trim().isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF0EBF9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            empty ? 'No data' : value.trim(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: empty ? kEmpty : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Edit
  Widget _eRow({
    required String label,
    required TextEditingController ctrl,
    required bool isValid,
    bool isLast = false,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    final showError = _submitted && !isValid;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF0EBF9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kMuted,
                letterSpacing: 0.5,
              ),
            ),
            const Text(
              ' *',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kRed,
              ),
            ),
          ]),
          const SizedBox(height: 4),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            maxLines: maxLines,
            readOnly: readOnly,
            onTap: onTap,
            decoration: _eDeco(hasError: showError, hint: hint)
                .copyWith(suffixIcon: suffixIcon),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            onChanged: (_) {
              if (_submitted) setState(() {});
            },
          ),
          if (showError) _errorMsg(),
        ],
      ),
    );
  }

  InputDecoration _eDeco({bool hasError = false, String? hint}) =>
      InputDecoration(
        filled: true,
        fillColor: hasError ? const Color(0x0ADC2626) : kFieldFill,
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFFB0A8C8),
          fontWeight: FontWeight.w400,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(
            color: hasError ? kRed : kPrimary.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(
            color: hasError ? kRed : kPrimary.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(
            color: hasError ? kRed : kPrimary,
            width: 1.5,
          ),
        ),
        isDense: true,
      );

  Widget _errorMsg() => const Padding(
        padding: EdgeInsets.only(top: 5, left: 2),
        child: Text(
          'This field is required.',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: kRed,
          ),
        ),
      );

  Widget _buildPersonalCard(bool isEditing) {
    if (!isEditing) {
      return _card([
        _vRow('Last Name',   (_original['lastName']   as String? ?? '').trim()),
        _vRow('First Name',  (_original['firstName']  as String? ?? '').trim()),
        _vRow('Middle Name', (_original['middleName'] as String? ?? '').trim()),
        _vRow('Specialty',   (_original['specialty']  as String? ?? '').trim(),
            isLast: true),
      ]);
    }
    return _card([
      _eRow(label: 'Last Name',   ctrl: _lastNameCtrl,
            isValid: _lastNameValid,   hint: 'e.g., Reyes'),
      _eRow(label: 'First Name',  ctrl: _firstNameCtrl,
            isValid: _firstNameValid,  hint: 'e.g., Maria'),
      _eRow(label: 'Middle Name', ctrl: _middleNameCtrl,
            isValid: _middleNameValid, hint: 'e.g., Santos'),
      _eRow(label: 'Specialty',   ctrl: _specialtyCtrl,
            isValid: _specialtyValid,  hint: 'e.g., Cardiologist',
            isLast: true),
    ]);
  }

  Widget _buildCoverageCard(bool isEditing) {
    if (!isEditing) {
      return _card([
        _vRow('Hospital / Pharmacy Name',
            (_original['hospitalPharmacyName'] as String? ?? '').trim()),
        _vRow('Date of Cover',
            _formatDate((_original['dateOfCover'] as String? ?? '').trim()),
            isLast: true),
      ]);
    }
    return _card([
      _eRow(
        label: 'Hospital / Pharmacy Name',
        ctrl: _hospitalCtrl,
        isValid: _hospitalValid,
        hint: "e.g., St. Luke's Medical Center, BGC",
      ),
      _eRow(
        label: 'Date of Cover',
        ctrl: _dateCtrl,
        isValid: _dateValid,
        hint: 'Tap to pick a date',
        readOnly: true,
        onTap: _pickDate,
        suffixIcon: const Icon(Icons.calendar_today_outlined,
            color: kPrimary, size: 18),
        isLast: true,
      ),
    ]);
  }

  Widget _buildCallNotesCard(bool isEditing) {
    if (!isEditing) {
      return _card([
        _vRow('Pre-Call Notes',
            (_original['preCallNotes']  as String? ?? '').trim()),
        _vRow('Post-Call Notes',
            (_original['postCallNotes'] as String? ?? '').trim(), isLast: true),
      ]);
    }
    return _card([
      _eRow(
        label: 'Pre-Call Notes',
        ctrl: _preCallCtrl,
        isValid: _preCallValid,
        hint: 'e.g., Discuss Amlodipine 10mg samples…',
        maxLines: 4,
      ),
      _eRow(
        label: 'Post-Call Notes',
        ctrl: _postCallCtrl,
        isValid: _postCallValid,
        hint: 'e.g., Dr. Reyes requested product brochures…',
        maxLines: 4,
        isLast: true,
      ),
    ]);
  }
}