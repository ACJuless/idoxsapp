import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class SalesOrderFormPage extends StatefulWidget {
  final Map<String, dynamic> formData;
  final String docId;
  final bool readonly;

  const SalesOrderFormPage({
    Key? key,
    required this.formData,
    required this.docId,
    this.readonly = true,
  }) : super(key: key);

  @override
  State<SalesOrderFormPage> createState() => _SalesOrderFormPageState();
}

class _SalesOrderFormPageState extends State<SalesOrderFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _mrNameCtrl;
  late TextEditingController _soldToCtrl;
  late TextEditingController _dateOfOrderCtrl;
  late TextEditingController _salesOrderNoCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _shipToCtrl;
  late TextEditingController _telNoCtrl;
  late TextEditingController _specialNoteCtrl;
  late TextEditingController _specialInstructionCtrl;
  late TextEditingController _notedBy1Ctrl;
  late TextEditingController _discountCtrl;
  late ScrollController _scrollCtrl;

  String _terms   = '';
  bool _submitted = false;
  bool _isSaving  = false;
  bool _isEditMode = false;

  // Catalogs
  static const List<String> kTermsOptions = [
    'COD - Cash', 
    'COD - Check', 
    'I.S. 60 Days',
    'Net 30 Days', 
    'PDC 30 Days', 
    'PDC 60 Days',
  ];

  static const Map<String, List<String>> kFungicideCatalog = {
    'Indofil 800 WP':  ['800WP',   'Mancozeb 800 g/Kg',                                      '1 kg pouch',                             '1500.00'],
    'Indofil 600 OS':  ['600 OS',  'Mancozeb 600 g/L',                                       '60 L Drum',                              '2500.00'],
    'Indofil 455 F':   ['455 F',   'Mancozeb 455 g/L',                                       '100 L Drum',                             '3500.00'],
    'Indofil 750 WDG': ['750 WDG', 'Mancozeb 750 g/Kg',                                      '25 Kg bag',                              '1500.00'],
    'Proviso 250 EC':  ['250 EC',  'Propiconazole 250 g/L',                                  '100 L Drum',                             '3500.00'],
    'Moximate 505 WP': ['505 WP',  'Cymoxanil 40 g/Kg + Mancozeb 465 g/Kg',                '500 g and 1 kg pouch',                   '2500.00'],
    'Matco 720 WP':    ['720 WP',  'Metalaxyl 80 g/Kg + Mancozeb 640 g/Kg WP',             '100 g pouch and 25 Kg bag',              '1500.00'],
    'Nexa 250 EC':     ['250 EC',  'Difenoconazole 250 g/L',                                '250 ml & 500 ml bottle and 200 L drum',  '1500.00'],
    'Grifon SC':       ['SC',      'Copper hydroxide 223 g/L + Copper oxychloride 239 g/L', '500 ml Bottle',                          '2500.00'],
    // ============================================================================================

    // "Cramin Forte Caps": ["CRA1", "Vitamin B1 + B6 + B12", "100pcs", "1500.00"],
    // "Dayzinc Drops": [
    //   "DAZ1",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "30mL",
    //   "121.00"
    // ],
    // "Dayzinc Syrup (120ml)": [
    //   "DAZ2",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "120mL",
    //   "130"
    // ],
    // "Dayzinc Syrup (250ml)": [
    //   "DAZ6",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "250mL",
    //   "240"
    // ],
    // "Dayzinc Chew Tabs (30pcs)": [
    //   "DAZ7",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "30pcs",
    //   "195"
    // ],
    // "Dayzinc Chew Tabs 10+2": [
    //   "DAZ5",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "12pcs",
    //   "65"
    // ],
    // "Dayzinc Chew Tabs 24+6": [
    //   "DAZ12",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "30pcs",
    //   "156"
    // ],
    // "Dayzinc Cap": [
    //   "DAZ3",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "30pcs",
    //   "232.5"
    // ],
    // "Dayzinc Cap 10+2": [
    //   "DAZ8",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "12pcs",
    //   "77.5"
    // ],
    // "Dayzinc Cap 24+6": [
    //   "DAZ11",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "30pcs",
    //   "186"
    // ],
    // "Nutri 10 Plus Drops": [
    //   "NUR1",
    //   "Vitamins A-E + CGF + Taurine + Lysine + Zinc",
    //   "30mL",
    //   "145"
    // ],
    // "Nutri 10 Plus Syrup (120ml)": [
    //   "NUR2",
    //   "Vitamins A-E + CGF + Taurine + Lysine + Zinc",
    //   "120mL",
    //   "200"
    // ],
    // "Nutri 10 Plus Syrup (250ml)": [
    //   "NUR5",
    //   "Vitamins A-E + CGF + Taurine + Lysine + Zinc",
    //   "250mL",
    //   "345"
    // ],
    // "Nutri 10 Excel Cap": [
    //   "NUR3",
    //   "Vitamins A-E + CGF + Taurine + Lysine + Zinc",
    //   "30pcs",
    //   "210"
    // ],
    // "Nutri 10 Plus OB Cap": [
    //   "NUR4",
    //   "Vitamins A-D + Iron, Folic Acid",
    //   "30pcs",
    //   "210"
    // ],
    // "Nutrigrow Syrup": [
    //   "NUG2",
    //   "Vitamins + CGF + Taurine",
    //   "120mL",
    //   "155"
    // ],
    // "Nutrigrow Syrup B1G1": [
    //   "NUG3",
    //   "Vitamins + CGF + Taurine",
    //   "120mL",
    //   "155"
    // ],
    // "Aplhabetic Tablet": [
    //   "ABCD",
    //   "Ampalaya + Banaba + Camote + Duhat",
    //   "30pcs",
    //   "330"
    // ],
    // "Daycee Syrup": [
    //   "DAY3",
    //   "Ascorbic Acid (as Sodium Ascorbate)",
    //   "120mL",
    //   "125"
    // ],
    // "Daycee Syrup B1G1": [
    //   "PRM05",
    //   "Ascorbic Acid (as Sodium Ascorbate)",
    //   "120mL",
    //   "125"
    // ],
    // "Daycee Cap": ["DAY6", "Sodium Ascorbate", "30pcs", "180"],
    // "Daycee Cap Buy 60 Cap Save 150": [
    //   "PRM09",
    //   "Sodium Ascorbate",
    //   "30pcs",
    //   "180"
    // ],
    // "Calciday Tab": [
    //   "CAL1",
    //   "Calcium Carbonate + Vitamin D3",
    //   "30pcs",
    //   "210"
    // ],
    // "Calciday Tab 10+2": [
    //   "CAL2",
    //   "Calcium Carbonate + Vitamin D3",
    //   "12pcs",
    //   "70"
    // ],
    // "Perispa 50 Tab": ["PER1", "Eperisone HCI", "30pcs", "540"],
    // "Zefaxim 100PFS": ["ZEF1", "Cefixime", "60mL", "528"],
    // "Maximmune Syrup": ["MAX1", "CM-Glucan", "120mL", "360"],
    // "C2Zinc Drops": [
    //   "C2Z2",
    //   "Ascorbic Acid + Sodium Ascorbate + Zinc",
    //   "30mL",
    //   "100"
    // ],
    // "C2Zinc Syrup": [
    //   "C2Z4",
    //   "Ascorbic Acid + Sodium Ascorbate + Zinc",
    //   "120mL",
    //   "120"
    // ],
    // "SGX Cap": ["SGX2", "Salbutamol + Guaifanesin", "100pcs", "650"],
    // "CFC 50 PFOD": ["CFC1", "Cefactor", "20mL", "200"],
  };

  static const Map<String, List<String>> kHerbicideCatalog = {
    'Akostar 480 SL':  ['480 SL', 'Glyphosate as Isopropylamine salt 480 g/L', '200 mL',                             '1350.00'],
    'Glowstar 150 SL': ['150 SL', 'Glufosinate ammonium 150 g/L',              '1 L and 4 L bottle and 200 L drum',  '3350.00'],
  };

  // Product rows
  List<Map<String, dynamic>> _fungicideRows = [];
  List<Map<String, dynamic>> _herbicideRows = [];

  double _grossAmount = 0.0;
  double _netAmount   = 0.0;

  final Map<String, bool> _expanded = {};

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _isEditMode = !widget.readonly; // start in edit if not readonly
    _initControllers(widget.formData);
  }

  void _initControllers(Map<String, dynamic> d) {
    _mrNameCtrl             = TextEditingController(text: d['mrName']            ?? '');
    _soldToCtrl             = TextEditingController(text: d['soldTo']             ?? '');
    _dateOfOrderCtrl        = TextEditingController(text: d['dateOfOrder']        ?? '');
    _salesOrderNoCtrl       = TextEditingController(text: d['salesOrderNo']       ?? '');
    _addressCtrl            = TextEditingController(text: d['address']            ?? '');
    _shipToCtrl             = TextEditingController(text: d['shipTo']             ?? '');
    _telNoCtrl              = TextEditingController(text: d['telNo']              ?? '');
    _specialNoteCtrl        = TextEditingController(text: d['specialNote']        ?? '');
    _specialInstructionCtrl = TextEditingController(text: d['specialInstruction'] ?? '');
    _notedBy1Ctrl           = TextEditingController(text: d['notedBy1']           ?? '');
    _discountCtrl           = TextEditingController(text: d['discount']?.toString() ?? '');
    _terms         = _resolveTerms(d['terms'] ?? '');
    _fungicideRows = _sanitize(List<Map<String, dynamic>>.from(d['pharmaRows'] ?? []));
    _herbicideRows = _sanitize(List<Map<String, dynamic>>.from(d['dermaRows']  ?? []));
    _recalc();
  }

  void _populateFromData(Map<String, dynamic> d) {
    _mrNameCtrl.text             = d['mrName']            ?? '';
    _soldToCtrl.text             = d['soldTo']             ?? '';
    _dateOfOrderCtrl.text        = d['dateOfOrder']        ?? '';
    _salesOrderNoCtrl.text       = d['salesOrderNo']       ?? '';
    _addressCtrl.text            = d['address']            ?? '';
    _shipToCtrl.text             = d['shipTo']             ?? '';
    _telNoCtrl.text              = d['telNo']              ?? '';
    _specialNoteCtrl.text        = d['specialNote']        ?? '';
    _specialInstructionCtrl.text = d['specialInstruction'] ?? '';
    _notedBy1Ctrl.text           = d['notedBy1']           ?? '';
    _discountCtrl.text           = d['discount']?.toString() ?? '';
    _terms         = _resolveTerms(d['terms'] ?? '');
    _fungicideRows = _sanitize(List<Map<String, dynamic>>.from(d['pharmaRows'] ?? []));
    _herbicideRows = _sanitize(List<Map<String, dynamic>>.from(d['dermaRows']  ?? []));
    _expanded.clear();
  }

  String _resolveTerms(String raw) => kTermsOptions.firstWhere(
    (t) => t.toLowerCase() == raw.toLowerCase(),
    orElse: () => '',
  );

  List<Map<String, dynamic>> _sanitize(List<Map<String, dynamic>> rows) =>
      rows.map((r) => {
        ...r,
        'reg':    (r['reg']    as num?)?.toInt()    ?? 0,
        'free':   (r['free']   as num?)?.toInt()    ?? 0,
        'price':  (r['price']  ?? r['unitPrice'] ?? '0').toString(),
        'amount': (r['amount'] as num?)?.toDouble() ?? 0.0,
      }).toList();

  @override
  void dispose() {
    _mrNameCtrl.dispose();
    _soldToCtrl.dispose();
    _dateOfOrderCtrl.dispose();
    _salesOrderNoCtrl.dispose();
    _addressCtrl.dispose();
    _shipToCtrl.dispose();
    _telNoCtrl.dispose();
    _specialNoteCtrl.dispose();
    _specialInstructionCtrl.dispose();
    _notedBy1Ctrl.dispose();
    _discountCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _recalc() {
    double gross = 0;
    for (final r in [..._fungicideRows, ..._herbicideRows]) {
      final reg   = (r['reg'] as int? ?? 0).toDouble();
      final price = double.tryParse(r['price'].toString()) ?? 0.0;
      r['amount'] = reg * price;
      gross += r['amount'] as double;
    }
    _grossAmount = gross;
    final disc = double.tryParse(_discountCtrl.text) ?? 0.0;
    _netAmount  = disc > 0 ? gross * (1 - disc / 100) : gross;
  }

  // Validation
  bool get _hasProducts => _fungicideRows.isNotEmpty || _herbicideRows.isNotEmpty;

  bool _runValidation() {
    setState(() => _submitted = true);
    final formOk  = _formKey.currentState?.validate() ?? false;
    final termsOk = _terms.isNotEmpty;
    final prodsOk = _hasProducts;
    bool rowsOk   = true;
    for (final r in [..._fungicideRows, ..._herbicideRows]) {
      if ((r['reg'] as int? ?? 0) <= 0) rowsOk = false;
    }
    if (!prodsOk) {
      _toast('Please add at least one Fungicide or Herbicide.', error: true);
    } else if (!rowsOk) {
      _toast('Each product must have Qty (Reg) greater than 0.', error: true);
    } else if (!termsOk) {
      _toast('Please select Terms.', error: true);
    } else if (!formOk) {
      _toast('Please fill out all required fields.', error: true);
    }
    return formOk && termsOk && prodsOk && rowsOk;
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
  Future<void> _resetForm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Form',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
            child: const Text('Reset',
                style: TextStyle(color: kRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _submitted = false;
      _populateFromData(widget.formData);
      _recalc();
    });
    _toast('Form has been reset.');
  }

  // Submit
  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_runValidation()) return;

    setState(() => _isSaving = true);
    _recalc();

    final data = {
      'mrName':             _mrNameCtrl.text.trim(),
      'soldTo':             _soldToCtrl.text.trim(),
      'dateOfOrder':        _dateOfOrderCtrl.text.trim(),
      'salesOrderNo':       _salesOrderNoCtrl.text.trim(),
      'address':            _addressCtrl.text.trim(),
      'shipTo':             _shipToCtrl.text.trim(),
      'telNo':              _telNoCtrl.text.trim(),
      'terms':              _terms,
      'specialNote':        _specialNoteCtrl.text.trim(),
      'specialInstruction': _specialInstructionCtrl.text.trim(),
      'notedBy1':           _notedBy1Ctrl.text.trim(),
      'notedBy2':           '',
      'discount':           _discountCtrl.text.trim(),
      'pharmaRows':         _fungicideRows,
      'dermaRows':          _herbicideRows,
      'grossAmount':        _grossAmount,
      'netAmount':          _netAmount,
      'timestamp':          FieldValue.serverTimestamp(),
    };

    try {
      final prefs     = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('userEmail') ?? '';
      final userKey   = userEmail.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_');
      await FirebaseFirestore.instance
          .collection('flowDB').doc('users')
          .collection(userKey).doc('sales_orders')
          .collection('sales_orders')
          .doc(widget.docId)
          .update(data);

      if (mounted) {
        _toast('Form updated successfully.');
        setState(() {
          _isEditMode = false;
          _submitted  = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _toast('Save failed: ${e.toString()}', error: true);
        setState(() => _isSaving = false);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Product helpers
  void _addProduct(bool isFungicide) async {
    final catalog = isFungicide ? kFungicideCatalog : kHerbicideCatalog;
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isFungicide ? 'Select Fungicide' : 'Select Herbicide'),
        children: catalog.keys
            .map((k) => SimpleDialogOption(
                  child: Text(k),
                  onPressed: () => Navigator.pop(context, k),
                ))
            .toList(),
      ),
    );
    if (selected == null) return;
    final meta = catalog[selected]!;
    setState(() {
      final row = {
        'desc': selected, 'code': meta[0], 'generic': meta[1],
        'pack': meta[2],  'price': meta[3], 'reg': 0, 'free': 0, 'amount': 0.0,
      };
      if (isFungicide) {
        _fungicideRows.add(row);
        _expanded['f-${_fungicideRows.length - 1}'] = true;
      } else {
        _herbicideRows.add(row);
        _expanded['h-${_herbicideRows.length - 1}'] = true;
      }
      _recalc();
    });
  }

  Future<void> _confirmRemove(bool isFungicide, int idx, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Product',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          name.isNotEmpty ? 'Remove "$name" from the list?' : 'Remove this product row?',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: kRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        if (isFungicide) _fungicideRows.removeAt(idx);
        else             _herbicideRows.removeAt(idx);
        _recalc();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _recalc();
    final appTitle = _mrNameCtrl.text.trim().isEmpty
        ? 'Sales Order'
        : _mrNameCtrl.text.trim();

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
              'SALES ORDER FORM',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white60,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              appTitle.toUpperCase(),
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
                    _populateFromData(widget.formData);
                    _recalc();
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
                    borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
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

      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          child: _isEditMode ? _editBody() : _viewBody(),
        ),
      ),
    );
  }

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
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _gradBtn('UPDATE FORM', _submit)),
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
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white))
                  : Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );

  // View
  Widget _viewBody() {
    final disc    = double.tryParse(_discountCtrl.text) ?? 0.0;
    final discAmt = _grossAmount * disc / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secLabel('Order Information', first: true),
        _card([
          _vFull('Name', _mrNameCtrl.text),
          _vFull('Sold To', _soldToCtrl.text),
          _vTwo('Date of Order', _fmtDate(_dateOfOrderCtrl.text),
                'Sales Order No.', _salesOrderNoCtrl.text),
          _vFull('Address', _addressCtrl.text),
          _vFull('Ship To', _shipToCtrl.text),
          _vTwo('Tel No.', _telNoCtrl.text, 'Terms', _terms),
          _vFull('Special Notes on Invoice', _specialNoteCtrl.text, last: true),
        ]),

        _secLabel('Fungicides'),
        ..._fungicideRows.isEmpty
            ? [_emptyNote('No fungicide entries recorded.')]
            : _fungicideRows.asMap().entries.map((e) => _viewProdCard(e.value, e.key, 'f')),

        _secLabel('Herbicides'),
        ..._herbicideRows.isEmpty
            ? [_emptyNote('No herbicide entries recorded.')]
            : _herbicideRows.asMap().entries.map((e) => _viewProdCard(e.value, e.key, 'h')),

        _secLabel('Summary'),
        _card([
          _sView('Gross Amount',
              _grossAmount > 0 ? '₱ ${_fmt(_grossAmount)}' : null),
          _sView('Discount',
              disc > 0 ? '${_discountCtrl.text}% (₱ ${_fmt(discAmt)})' : null),
          _sView('Net Amount',
              _netAmount > 0 ? '₱ ${_fmt(_netAmount)}' : null,
              valueColor: kRed, last: true),
        ]),

        _secLabel('Additional Details'),
        _card([
          _vTwo('Noted By', _notedBy1Ctrl.text,
                'Special Instructions', _specialInstructionCtrl.text, last: true),
        ]),
      ],
    );
  }

  Widget _viewProdCard(Map<String, dynamic> row, int idx, String prefix) {
    final key    = '$prefix-$idx';
    final isOpen = _expanded[key] ?? false;
    final label  = row['desc']?.toString().isNotEmpty == true
        ? row['desc'].toString()
        : 'Product ${idx + 1}';

    return _collapsibleCard(
      key: key, label: label, index: idx, isOpen: isOpen,
      trailing: const SizedBox.shrink(),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        child: Column(children: [
          Row(children: [
            Expanded(child: _pfView('Product Code',        row['code']    ?? '')),
            const SizedBox(width: 12),
            Expanded(child: _pfView('Product Description', row['desc']    ?? '')),
          ]),
          const SizedBox(height: 14),
          _pfView('Active Ingredient', row['generic'] ?? ''),
          const SizedBox(height: 14),
          _pfView('Pack Size', row['pack'] ?? ''),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _pfView('Qty Regular', row['reg']?.toString()  ?? '0')),
            const SizedBox(width: 10),
            Expanded(child: _pfView('Qty Free',    row['free']?.toString() ?? '0')),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _pfView('Unit Price', row['price']?.toString() ?? '')),
            const SizedBox(width: 10),
            Expanded(child: _pfView('Amount',
                row['amount'] != null && (row['amount'] as double) > 0
                    ? '₱ ${_fmt(row['amount'] as double)}'
                    : '')),
          ]),
        ]),
      ),
    );
  }

  // Edit
  Widget _editBody() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secLabel('Order Information', first: true),
          _card([
            _eFull(_eField('Name', _mrNameCtrl, req: true)),
            _eFull(_eField('Sold To', _soldToCtrl, req: true)),
            _eTwo(
              _eField('Date of Order', _dateOfOrderCtrl, req: true, readOnly: true),
              _eField('Sales Order No.', _salesOrderNoCtrl, req: true),
            ),
            _eFull(_eField('Address', _addressCtrl, req: true)),
            _eFull(_eField('Ship To', _shipToCtrl, req: true)),
            _eTwo(
              _eField('Tel No.', _telNoCtrl,
                  req: true,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]'))
                  ]),
              _eTerms(),
            ),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF0EBF9)))),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _eField('Special Notes on Invoice', _specialNoteCtrl, maxLines: 2),
              ),
            ),
          ]),

          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: _pfBar('Fungicides', onAdd: () => _addProduct(true)),
          ),
          ..._fungicideRows.asMap().entries.map((e) => _editProdCard(e.value, e.key, true)),
          if (_submitted && !_hasProducts)
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text('At least one product is required.',
                  style: TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w600)),
            ),

          _pfBar('Herbicides', onAdd: () => _addProduct(false)),
          ..._herbicideRows.asMap().entries.map((e) => _editProdCard(e.value, e.key, false)),

          _secLabel('Summary'),
          _card([
            _sSummaryDisplay('Gross Amount', '₱ ${_fmt(_grossAmount)}'),
            _sDiscountRow(),
            _sSummaryDisplay('Net Amount', '₱ ${_fmt(_netAmount)}',
                valueColor: kRed, last: true),
          ]),

          _secLabel('Additional Details'),
          _card([
            _eTwo(
              _eField('Noted By', _notedBy1Ctrl, req: true),
              _eField('Special Instructions', _specialInstructionCtrl),
              last: true,
            ),
          ]),

          _footer(),
        ],
      );

  Widget _editProdCard(Map<String, dynamic> row, int idx, bool isFungicide) {
    final catalog = isFungicide ? kFungicideCatalog : kHerbicideCatalog;
    final prefix  = isFungicide ? 'f' : 'h';
    final key     = '$prefix-$idx';
    final isOpen  = _expanded[key] ?? false;
    final label   = row['desc']?.toString().isNotEmpty == true
        ? row['desc'].toString()
        : 'Product ${idx + 1}';

    final descErr = _submitted && (row['desc'] == null || row['desc'].toString().isEmpty);
    final regErr  = _submitted && (row['reg'] as int? ?? 0) <= 0;

    final regCtrl  = TextEditingController(text: row['reg']?.toString()  ?? '');
    final freeCtrl = TextEditingController(text: row['free']?.toString() ?? '');

    return _collapsibleCard(
      key: key, label: label, index: idx, isOpen: isOpen,
      trailing: GestureDetector(
        onTap: () => _confirmRemove(isFungicide, idx, row['desc']?.toString() ?? ''),
        child: Container(
          padding: const EdgeInsets.all(5),
          child: const Icon(Icons.delete_outline, color: kRed, size: 18),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _pfDropdown(
              label: 'Product Description',
              required: true,
              hasError: descErr,
              value: row['desc']?.toString().isNotEmpty == true ? row['desc'] : null,
              items: catalog.keys.toList(),
              onChanged: (v) {
                if (v == null) return;
                final meta = catalog[v]!;
                setState(() {
                  row['desc']    = v;
                  row['code']    = meta[0];
                  row['generic'] = meta[1];
                  row['pack']    = meta[2];
                  row['price']   = meta[3];
                  if (isFungicide) _fungicideRows[idx] = row;
                  else             _herbicideRows[idx] = row;
                  _recalc();
                });
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: _pfDisabled('Product Code', row['code'] ?? '')),
          ]),
          const SizedBox(height: 14),
          _pfDisabled('Active Ingredient', row['generic'] ?? ''),
          const SizedBox(height: 14),
          _pfDisabled('Pack Size', row['pack'] ?? ''),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _pfTextInput(
              label: 'Qty Regular',
              required: true,
              hasError: regErr,
              controller: regCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                row['reg'] = int.tryParse(v) ?? 0;
                if (isFungicide) _fungicideRows[idx]['reg'] = row['reg'];
                else             _herbicideRows[idx]['reg'] = row['reg'];
                setState(_recalc);
              },
            )),
            const SizedBox(width: 10),
            Expanded(child: _pfTextInput(
              label: 'Qty Free',
              controller: freeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                row['free'] = int.tryParse(v) ?? 0;
                if (isFungicide) _fungicideRows[idx]['free'] = row['free'];
                else             _herbicideRows[idx]['free'] = row['free'];
              },
            )),
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _pfDisabled('Unit Price', row['price'] ?? '')),
            const SizedBox(width: 10),
            Expanded(child: _pfDisabled('Amount',
                (row['amount'] as double? ?? 0) > 0
                    ? _fmt(row['amount'] as double)
                    : '')),
          ]),
        ]),
      ),
    );
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

  Widget _collapsibleCard({
    required String key,
    required String label,
    required int index,
    required bool isOpen,
    required Widget trailing,
    required Widget body,
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
            onTap: () => setState(() => _expanded[key] = !isOpen),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  kPrimaryDark.withValues(alpha: 0.07),
                  kPrimary.withValues(alpha: 0.03),
                ]),
              ),
              child: Row(children: [
                Container(
                  width: 26, height: 26,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [kPrimaryDark, kPrimary]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${index + 1}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: kPrimary),
                      overflow: TextOverflow.ellipsis),
                ),
                trailing,
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(Icons.keyboard_arrow_down, color: kPrimary, size: 20),
                ),
              ]),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: body,
            crossFadeState: isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ]),
      );

  Widget _pfBar(String title, {required VoidCallback onAdd}) => Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8), // added left: 8
      child: Row(children: [
        Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: kPrimary, letterSpacing: 0.5)),
        const Spacer(),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kPrimaryDark, kPrimary]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: kPrimary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: const Row(children: [
              Icon(Icons.add, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text('ADD ROW',
                  style: TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    );

  Widget _emptyNote(String msg) => Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 12, top: 2),
        child: Text(msg, style: const TextStyle(color: kEmpty, fontSize: 14)),
      );

  // View cells
  Widget _vTwo(String l1, String v1, String l2, String v2, {bool last = false}) =>
      Container(
        decoration: BoxDecoration(
            border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF0EBF9)))),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _vCell(l1, v1, rightBorder: true)),
            Expanded(child: _vCell(l2, v2)),
          ]),
        ),
      );

  Widget _vFull(String label, String val, {bool last = false}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
            border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF0EBF9)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _uppercase(label),
          const SizedBox(height: 2),
          Text(val.trim().isEmpty ? 'No data' : val,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: val.trim().isEmpty ? kEmpty : Colors.black87)),
        ]),
      );

  Widget _vCell(String label, String val, {bool rightBorder = false}) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
            border: rightBorder
                ? const Border(right: BorderSide(color: Color(0xFFF0EBF9)))
                : null),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _uppercase(label),
          const SizedBox(height: 2),
          Text(val.trim().isEmpty ? 'No data' : val,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: val.trim().isEmpty ? kEmpty : Colors.black87)),
        ]),
      );

  Widget _sView(String label, String? val, {Color? valueColor, bool last = false}) =>
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
            border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF0EBF9)))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _uppercase(label),
          Text(val ?? 'No data',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? (val == null ? kEmpty : Colors.black87))),
        ]),
      );

  // Edit cells
  Widget _eTwo(Widget left, Widget right, {bool last = false}) => Container(
        decoration: BoxDecoration(
            border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF0EBF9)))),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _ePad(left, rightBorder: true)),
            Expanded(child: _ePad(right)),
          ]),
        ),
      );

  Widget _eFull(Widget child, {bool last = false}) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
            border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF0EBF9)))),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: child,
      );

  Widget _ePad(Widget child, {bool rightBorder = false}) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
            border: rightBorder
                ? const Border(right: BorderSide(color: Color(0xFFF0EBF9)))
                : null),
        child: child,
      );

  Widget _eField(
    String label,
    TextEditingController ctrl, {
    bool req = false,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _uppercaseReq(label, req),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
          decoration: _eDeco(),
          validator: req
              ? (v) {
                  if (!_submitted) return null;
                  return (v == null || v.trim().isEmpty)
                      ? 'This field is required.'
                      : null;
                }
              : null,
          onChanged: (_) {
            if (_submitted) setState(() {});
          },
        ),
      ]);

  Widget _eTerms() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _uppercaseReq('Terms', true),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _terms.isNotEmpty ? _terms : null,
          decoration: _eDeco(),
          hint: const Text('Select Terms',
              style: TextStyle(color: Color(0xFFB0A8C8), fontSize: 15)),
          items: kTermsOptions
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setState(() => _terms = v ?? ''),
          validator: (_) {
            if (!_submitted) return null;
            return _terms.isEmpty ? 'This field is required.' : null;
          },
        ),
      ]);

  InputDecoration _eDeco() => InputDecoration(
        filled: true,
        fillColor: kFieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: kPrimary.withValues(alpha: 0.25), width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: kPrimary.withValues(alpha: 0.25), width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: kPrimary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: kRed, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: kRed, width: 1.5)),
        errorStyle: const TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w600, color: kRed),
        isDense: true,
      );

  Widget _sSummaryDisplay(String label, String value,
      {Color? valueColor, bool last = false}) =>
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
            border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF0EBF9)))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _uppercase(label),
          Container(
            width: 160, height: 38,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: kFieldFill,
              border: Border.all(color: kPrimary.withValues(alpha: 0.25), width: 1.5),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? Colors.black87)),
          ),
        ]),
      );

  Widget _sDiscountRow() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF0EBF9)))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _uppercase('Discount'),
          SizedBox(
            width: 160, height: 38,
            child: TextFormField(
              controller: _discountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
              decoration: _eDeco().copyWith(
                hintText: 'e.g., 5',
                hintStyle: const TextStyle(
                    color: Color(0xFFB0A8C8), fontWeight: FontWeight.w400),
              ),
              onChanged: (_) => setState(_recalc),
            ),
          ),
        ]),
      );

  // Product card helpers
  Widget _pfView(String label, String val) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pfLabel(label),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
        ],
      );

  Widget _pfDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool required = false,
    bool hasError = false,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _pfLabelReq(label, required),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          decoration: _pfDeco(hasError: hasError),
          isExpanded: true,
          hint: const Text('Select Product',
              style: TextStyle(color: Color(0xFFB0A8C8), fontSize: 13)),
          items: items
              .map((k) => DropdownMenuItem(
                  value: k,
                  child: Text(k, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: onChanged,
          validator: required
              ? (v) {
                  if (!_submitted) return null;
                  return (v == null || v.isEmpty) ? 'Required.' : null;
                }
              : null,
        ),
      ]);

  Widget _pfDisabled(String label, String val) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pfLabel(label),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.02),
              border: Border.all(color: kPrimary.withValues(alpha: 0.18), width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(val.trim().isEmpty ? '—' : val,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: val.trim().isEmpty ? const Color(0xFFB0A8C8) : Colors.black54)),
          ),
        ],
      );

  Widget _pfTextInput({
    required String label,
    required TextEditingController controller,
    bool required = false,
    bool hasError = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _pfLabelReq(label, required),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
          decoration: _pfDeco(hasError: hasError),
          onChanged: onChanged,
          validator: required
              ? (v) {
                  if (!_submitted) return null;
                  if (v == null || v.trim().isEmpty) return 'Required.';
                  if (int.tryParse(v) != null && int.parse(v) <= 0)
                    return 'Required.';
                  return null;
                }
              : null,
        ),
      ]);

  InputDecoration _pfDeco({bool hasError = false}) => InputDecoration(
        filled: true,
        fillColor: hasError ? const Color(0x0ADC2626) : kPrimary.withValues(alpha: 0.03),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: hasError ? kRed : kPrimary.withValues(alpha: 0.22), width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: hasError ? kRed : kPrimary.withValues(alpha: 0.22), width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: hasError ? kRed : kPrimary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kRed, width: 1.5)),
        errorStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: kRed),
        isDense: true,
      );

  Widget _uppercase(String t) => Text(t.toUpperCase(),
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: kMuted, letterSpacing: 0.5));

  Widget _uppercaseReq(String t, bool req) => Row(children: [
        _uppercase(t),
        if (req)
          const Text(' *',
              style: TextStyle(color: kRed, fontSize: 11, fontWeight: FontWeight.w700)),
      ]);

  Widget _pfLabel(String t) => Text(t.toUpperCase(),
      style: const TextStyle(
          fontSize: 10.5, fontWeight: FontWeight.w700,
          color: kMuted, letterSpacing: 0.4));

  Widget _pfLabelReq(String t, bool req) => Row(children: [
        _pfLabel(t),
        if (req)
          const Text(' *',
              style: TextStyle(color: kRed, fontSize: 10.5, fontWeight: FontWeight.w700)),
      ]);

  String _fmt(double n) => n
      .toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  String _fmtDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      const months = [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[d.month]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
    } catch (_) { return raw; }
  }
}