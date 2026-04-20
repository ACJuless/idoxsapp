import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'in_field_coaching_form_page.dart';

// Dropdowns
const Map<String, String> _kEvaluatorPositions = {
  'Antonio S. Adriano':         'District Sales Manager - Consumer',
  'Kitchon Edwin Tevar':        'District Manager',
  'Paningbatan Rose Ann Reyes': 'District Sales Manager',
  'Quindao Edna Hatol':         'District Sales Manager',
  'Victor Maria R. Chumacera':  'National Sales Manager',
};

// Questions
const List<String> _kQuestions = [
  'Key Message Delivery',
  'Key Value Delivery',
  'Objective Delivery',
  'Result Delivery',
  'Conclusion Delivery',
  'Attractive Selling Skill',
  'Closing Statement',
  'Prescription Deal',
  'Relationship Capital',
];

// Ratings
const List<String> _kRatingLabels = [
  'Unsatisfactory',
  'Needs Improvement',
  'Satisfactory',
  'Good',
  'Excellent',
];

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

Color _ratingBg(int i) => const [
  Color(0xFFFEE2E2), Color(0xFFFEF3C7), Color(0xFFDBEAFE),
  Color(0xFFDCFCE7), Color(0xFFF3E8FF),
][i.clamp(0, 4)];

Color _ratingDot(int i) => const [
  Color(0xFFDC2626), Color(0xFFD97706), Color(0xFF2563EB),
  Color(0xFF16A34A), Color(0xFF7C3AED),
][i.clamp(0, 4)];

Color _ratingText(int i) => const [
  Color(0xFF991B1B), Color(0xFF92400E), Color(0xFF1E40AF),
  Color(0xFF166534), Color(0xFF6B21A8),
][i.clamp(0, 4)];

Color _ratingBorder(int i) => const [
  Color(0xFFFCA5A5), Color(0xFFFCD34D), Color(0xFF93C5FD),
  Color(0xFF86EFAC), Color(0xFFC084FC),
][i.clamp(0, 4)];

class InFieldCoachingFormReadonlyPage extends StatefulWidget {
  final Map<String, dynamic> formData;
  final String docId;
  final String userKey;

  const InFieldCoachingFormReadonlyPage({
    Key? key,
    required this.formData,
    required this.docId,
    required this.userKey,
  }) : super(key: key);

  @override
  State<InFieldCoachingFormReadonlyPage> createState() =>
      _InFieldCoachingFormReadonlyPageState();
}

class _InFieldCoachingFormReadonlyPageState
    extends State<InFieldCoachingFormReadonlyPage> {

  bool _isEditMode = false;
  bool _isSaving   = false;
  bool _submitted  = false;

  late Map<String, dynamic> _original = {};

  String? _selEvaluator;
  late TextEditingController _positionCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _medrepCtrl;
  late TextEditingController _doctorCtrl;
  late TextEditingController _improvementCtrl;
  late List<int?> _ratings;

  @override
  void initState() {
    super.initState();
    _original = Map<String, dynamic>.from(widget.formData);
    _init(_original);
  }

  void _init(Map<String, dynamic> d) {
    final ev = (d['evaluator'] as String? ?? '').trim();
    _selEvaluator    = _kEvaluatorPositions.containsKey(ev) ? ev : null;
    _positionCtrl    = TextEditingController(text: d['position']           as String? ?? '');
    _dateCtrl        = TextEditingController(text: d['date']               as String? ?? '');
    _medrepCtrl      = TextEditingController(
        text: ((d['medrepName'] ?? d['mdName'] ?? '') as String).trim());
    _doctorCtrl      = TextEditingController(text: d['doctorName']         as String? ?? '');
    _improvementCtrl = TextEditingController(text: d['improvementComment'] as String? ?? '');

    final raw = d['ratings'] as List<dynamic>?;
    _ratings = List<int?>.generate(
      _kQuestions.length,
      (i) => (raw != null && i < raw.length && raw[i] != null)
          ? (raw[i] as num).toInt()
          : null,
    );
  }

  void _disposeControllers() {
    _positionCtrl.dispose();
    _dateCtrl.dispose();
    _medrepCtrl.dispose();
    _doctorCtrl.dispose();
    _improvementCtrl.dispose();
  }

  void _populateFromOriginal() {
    final d = _original;
    final ev = (d['evaluator'] as String? ?? '').trim();
    _selEvaluator          = _kEvaluatorPositions.containsKey(ev) ? ev : null;
    _positionCtrl.text     = d['position']           as String? ?? '';
    _dateCtrl.text         = d['date']               as String? ?? '';
    _medrepCtrl.text       = ((d['medrepName'] ?? d['mdName'] ?? '') as String).trim();
    _doctorCtrl.text       = d['doctorName']         as String? ?? '';
    _improvementCtrl.text  = d['improvementComment'] as String? ?? '';

    final raw = d['ratings'] as List<dynamic>?;
    _ratings = List<int?>.generate(
      _kQuestions.length,
      (i) => (raw != null && i < raw.length && raw[i] != null)
          ? (raw[i] as num).toInt()
          : null,
    );
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  // Validation
  bool get _evaluatorValid => _selEvaluator != null;
  bool get _positionValid  => _positionCtrl.text.trim().isNotEmpty;
  bool get _dateValid      => _dateCtrl.text.trim().isNotEmpty;
  bool get _medrepValid    => _medrepCtrl.text.trim().isNotEmpty;
  bool get _doctorValid    => _doctorCtrl.text.trim().isNotEmpty;
  bool get _commentValid   => _improvementCtrl.text.trim().isNotEmpty;

  bool get _formValid =>
      _evaluatorValid &&
      _positionValid  &&
      _dateValid      &&
      _medrepValid    &&
      _doctorValid    &&
      _commentValid;

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
        'evaluator':          _selEvaluator ?? '',
        'position':           _positionCtrl.text.trim(),
        'date':               _dateCtrl.text.trim(),
        'medrepName':         _medrepCtrl.text.trim(),
        'doctorName':         _doctorCtrl.text.trim(),
        'improvementComment': _improvementCtrl.text.trim(),
        'ratings':            _ratings,
      };
      await FirebaseFirestore.instance
          .collection('flowDB').doc('users')
          .collection(widget.userKey).doc('coaching_forms')
          .collection('coaching_forms').doc(widget.docId)
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
      const m = [
        'January','February','March','April','May','June',
        'July','August','September','October','November','December'
      ];
      return '${m[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
    } catch (_) { return raw; }
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

  @override
  Widget build(BuildContext context) {
    final appTitle = (_selEvaluator?.isNotEmpty == true
            ? _selEvaluator!
            : (_original['evaluator'] as String? ?? ''))
        .trim();
    final displayTitle =
        appTitle.isNotEmpty ? appTitle.toUpperCase() : 'IN-FIELD COACHING';

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
              'IN-FIELD COACHING FORM',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white60,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              displayTitle,
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)
                ),
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
                _sectionLabel('Evaluator Details', first: true),
                _buildEvaluatorCard(),

                _sectionLabel('Rating'),
                _buildRatingCard(),

                _sectionLabel('Comments'),
                _buildCommentsCard(),

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
                    borderRadius: BorderRadius.circular(15)
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                'RESET',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
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
          onTap: _isSaving ? null : _save,
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
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Text(
                      'UPDATE FORM',
                      style: TextStyle(
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
    required Widget child,
    bool req = false,
    bool isLast = false,
  }) =>
      Container(
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
              if (req)
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
            child,
          ],
        ),
      );

  // Evaluator card
  Widget _buildEvaluatorCard() {
    if (!_isEditMode) {
      final ev  = (_original['evaluator']   as String? ?? '').trim();
      final pos = (_original['position']    as String? ?? '').trim();
      final dt  = (_original['date']        as String? ?? '').trim();
      final md  = ((_original['medrepName'] ?? _original['mdName'] ?? '') as String).trim();
      final dr  = (_original['doctorName']  as String? ?? '').trim();

      return _card([
        _vRow('Name of Evaluator', ev),
        _vRow('Position',          pos),
        _vRow('Date',              _formatDate(dt)),
        _vRow('Medrep Name',       md),
        _vRow('Doctor Name',       dr, isLast: true),
      ]);
    }

    final evalError   = _submitted && !_evaluatorValid;
    final dateError   = _submitted && !_dateValid;
    final medrepError = _submitted && !_medrepValid;
    final doctorError = _submitted && !_doctorValid;

    return _card([
      _eRow(
        label: 'Name of Evaluator',
        req: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: evalError ? const Color(0x0ADC2626) : kFieldFill,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: evalError ? kRed : kPrimary.withValues(alpha: 0.25),
                  width: evalError ? 1.8 : 1.5,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: ButtonTheme(
                  alignedDropdown: true,
                  child: DropdownButton<String>(
                    value: _selEvaluator != null &&
                            _kEvaluatorPositions.containsKey(_selEvaluator)
                        ? _selEvaluator
                        : null,
                    hint: const Text(
                      'Select Evaluator',
                      style: TextStyle(
                        color: Color(0xFFB0A8C8),
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                      ),
                    ),
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                    items: _kEvaluatorPositions.keys
                        .toSet()
                        .map((n) => DropdownMenuItem(
                              value: n,
                              child: Text(n),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() {
                      _selEvaluator      = val;
                      _positionCtrl.text = val != null
                          ? (_kEvaluatorPositions[val] ?? '')
                          : '';
                      if (_submitted) setState(() {});
                    }),
                  ),
                ),
              ),
            ),
            if (evalError) _errorMsg(),
          ],
        ),
      ),

      _eRow(
        label: 'Position',
        req: true,
        child: TextFormField(
          controller: _positionCtrl,
          readOnly: true,
          decoration: _eDeco(hint: 'Auto-filled from evaluator'),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _positionCtrl.text.isNotEmpty
                ? Colors.black87
                : const Color(0xFFB0A8C8),
          ),
        ),
      ),

      _eRow(
        label: 'Date',
        req: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _dateCtrl,
              keyboardType: TextInputType.datetime,
              decoration: _eDeco(
                  hasError: dateError, hint: 'e.g., 2025-01-30'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              onChanged: (_) { if (_submitted) setState(() {}); },
            ),
            if (dateError) _errorMsg(),
          ],
        ),
      ),

      _eRow(
        label: 'Medrep Name',
        req: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _medrepCtrl,
              decoration: _eDeco(
                  hasError: medrepError, hint: 'e.g., Juan Dela Cruz'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              onChanged: (_) { if (_submitted) setState(() {}); },
            ),
            if (medrepError) _errorMsg(),
          ],
        ),
      ),

      _eRow(
        label: 'Doctor Name',
        req: true,
        isLast: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _doctorCtrl,
              decoration: _eDeco(
                  hasError: doctorError, hint: 'e.g., Maria Santos'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              onChanged: (_) { if (_submitted) setState(() {}); },
            ),
            if (doctorError) _errorMsg(),
          ],
        ),
      ),
    ]);
  }

  // Rating card
  Widget _buildRatingCard() => _card(
        List.generate(
          _kQuestions.length,
          (i) => _isEditMode ? _ratingEditRow(i) : _ratingViewRow(i),
        ),
      );

  Widget _ratingViewRow(int i) {
    final r      = _ratings[i];
    final isLast = i == _kQuestions.length - 1;
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
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: '${i + 1}. ',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              TextSpan(
                text: _kQuestions[i].toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 7),
          if (r == null)
            Text('No data', style: TextStyle(fontSize: 14, color: kEmpty))
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: _ratingBg(r),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: _ratingDot(r),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _kRatingLabels[r].toUpperCase(),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _ratingText(r),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _ratingEditRow(int qi) {
    final sel    = _ratings[qi];
    final isLast = qi == _kQuestions.length - 1;
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
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: '${qi + 1}. ',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              TextSpan(
                text: _kQuestions[qi].toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kRed,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          ...List.generate(_kRatingLabels.length, (ri) {
            final isSel = sel == ri;
            return GestureDetector(
              onTap: () => setState(() => _ratings[qi] = ri),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isSel
                      ? _ratingBg(ri)
                      : const Color.fromRGBO(89, 88, 178, 0.02),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel
                        ? _ratingBorder(ri)
                        : const Color.fromRGBO(89, 88, 178, 0.14),
                    width: 1.5,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSel ? _ratingDot(ri) : Colors.transparent,
                      border: Border.all(
                        color: isSel
                            ? _ratingDot(ri)
                            : const Color.fromRGBO(89, 88, 178, 0.28),
                        width: 2,
                      ),
                    ),
                    child: isSel
                        ? const Icon(Icons.check,
                            size: 10, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 11),
                  Text(
                    _kRatingLabels[ri].toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSel ? FontWeight.w700 : FontWeight.w600,
                      color: isSel
                          ? _ratingText(ri)
                          : const Color(0xFF2B2B2B),
                    ),
                  ),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCommentsCard() {
    if (!_isEditMode) {
      final comment =
          (_original['improvementComment'] as String? ?? '').trim();
      return _card([
        _vRow('Things to be Improved', comment, isLast: true),
      ]);
    }

    final commentError = _submitted && !_commentValid;

    return _card([
      _eRow(
        label: 'Things to be Improved',
        req: true,
        isLast: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _improvementCtrl,
              maxLines: 4,
              decoration: _eDeco(
                hasError: commentError,
                hint:
                    'e.g., Work on closing techniques and follow-up strategies…',
              ),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              onChanged: (_) { if (_submitted) setState(() {}); },
            ),
            if (commentError) _errorMsg(),
          ],
        ),
      ),
    ]);
  }
}

class InFieldCoachingFormTransactionsPage extends StatefulWidget {
  @override
  State<InFieldCoachingFormTransactionsPage> createState() =>
      _InFieldCoachingFormTransactionsPageState();
}

class _InFieldCoachingFormTransactionsPageState
    extends State<InFieldCoachingFormTransactionsPage> {

  String _userKey = '';

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail') ?? '';
    setState(() =>
        _userKey = email.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_'));
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
          title: const Text(
            'IN-FIELD COACHING FORM TRANSACTIONS',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New Coaching Form',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => InFieldCoachingFormPage()),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      body: _userKey.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('flowDB').doc('users')
                  .collection(_userKey).doc('coaching_forms')
                  .collection('coaching_forms')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData ||
                    snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No coaching forms yet. Tap '+' to create one.",
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
                      final doc   = docs[idx];
                      final data  = doc.data() as Map<String, dynamic>;
                      final ev    = (data['evaluator'] as String? ?? '').trim();
                      final date  = (data['date']       as String? ?? '-').trim();
                      final label = 'Form #${docs.length - idx}';

                      return SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InFieldCoachingFormReadonlyPage(
                                  formData: data,
                                  docId:    doc.id,
                                  userKey:  _userKey,
                                ),
                              ),
                            ),
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
                                    const Icon(Icons.manage_search, color: Colors.white, size: 30),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ]),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ev.isNotEmpty
                                              ? ev
                                              : 'No Evaluator',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Date: $date',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}