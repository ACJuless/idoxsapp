import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:ui'; // Added for signature points

class ScpFormPage extends StatefulWidget {
  const ScpFormPage({Key? key}) : super(key: key);

  @override
  State<ScpFormPage> createState() => _ScpFormPageState();
}

class _ScpFormPageState extends State<ScpFormPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _farmerNameController = TextEditingController();
  final TextEditingController _farmAddressController = TextEditingController();
  final TextEditingController _cellphoneNumberController =
      TextEditingController();
  final TextEditingController _dateOfEventController = TextEditingController();
  final TextEditingController _typeOfEventController = TextEditingController();
  final TextEditingController _venueOfEventController = TextEditingController();
  final TextEditingController _cropsPlantedController = TextEditingController();

  // kept but unused as single fields (you can remove later if not needed)
  final TextEditingController _keyConcernsController = TextEditingController();
  final TextEditingController _productRecommendationController =
      TextEditingController();

  final TextEditingController _cropAdvisorNameController =
      TextEditingController();
  final TextEditingController _cropAdvisorContactController =
      TextEditingController();

  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _packagingController = TextEditingController();

  final TextEditingController _farmerNameSecondController =
      TextEditingController();
  late SignatureController _farmerSignaturePadController;
  final TextEditingController _dateNeededController = TextEditingController();
  final TextEditingController _preferredDealerController =
      TextEditingController();

  // Dynamic lists for rows
  final List<TextEditingController> _keyConcernControllers = [];
  final List<TextEditingController> _productRecommendationControllers = [];

  final List<TextEditingController> _productNameControllers = [];
  final List<TextEditingController> _quantityControllers = [];
  final List<TextEditingController> _packagingControllers = [];

  String createdBy = '';

  @override
  void initState() {
    super.initState();
    _addKeyConcernRow();
    _addProductRow();
    _loadCreatedByFromPrefs();

    _farmerSignaturePadController = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _farmerNameController.dispose();
    _farmAddressController.dispose();
    _cellphoneNumberController.dispose();
    _dateOfEventController.dispose();
    _typeOfEventController.dispose();
    _venueOfEventController.dispose();
    _cropsPlantedController.dispose();

    _keyConcernsController.dispose();
    _productRecommendationController.dispose();
    _cropAdvisorNameController.dispose();
    _cropAdvisorContactController.dispose();

    _productNameController.dispose();
    _quantityController.dispose();
    _packagingController.dispose();

    _farmerNameSecondController.dispose();
    _dateNeededController.dispose();
    _preferredDealerController.dispose();

    for (final c in _keyConcernControllers) {
      c.dispose();
    }
    for (final c in _productRecommendationControllers) {
      c.dispose();
    }
    for (final c in _productNameControllers) {
      c.dispose();
    }
    for (final c in _quantityControllers) {
      c.dispose();
    }
    for (final c in _packagingControllers) {
      c.dispose();
    }

    _farmerSignaturePadController.dispose();

    super.dispose();
  }

  Future<void> _loadCreatedByFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    if (!mounted) return;
    setState(() {
      createdBy = userEmail;
    });
  }

  Future<String> _getSanitizedUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    // same pattern as attendance form: replace dots for doc/collection IDs
    return userEmail.replaceAll(RegExp(r'\.'), '_');
  }

  Future<void> _pickDateForController(TextEditingController controller) async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(now.year - 5);
    final DateTime lastDate = DateTime(now.year + 5);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      final String formatted =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        controller.text = formatted;
      });
    }
  }

  InputDecoration _baseDecoration({String? label, bool readOnly = false}) {
    return const InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
    ).copyWith(
      labelText: label,
      alignLabelWithHint: true,
      suffixIcon: readOnly ? const Icon(Icons.calendar_today) : null,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
    );
  }

  Widget _buildLabeledField({
    required String title,
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    bool isRequired = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        if (title.isNotEmpty) const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          textAlign: TextAlign.center,
          decoration: _baseDecoration(label: label, readOnly: readOnly),
          inputFormatters: inputFormatters,
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'Required';
            }
            // Keep the original required check for the top mandatory fields.
            if ((title == 'Name of Farmer' ||
                    title == 'Date of Event' ||
                    title == 'Crops Planted') &&
                (value == null || value.trim().isEmpty)) {
              return 'Required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPlainField({
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textAlign: TextAlign.center,
      decoration: _baseDecoration(),
      inputFormatters: inputFormatters,
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) {
         return 'Required';
        }
        return null;
      },
    );
  }

  Widget _buildPaddedField({
    required String title,
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: _buildLabeledField(
        title: title,
        label: label,
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        isRequired: isRequired,
      ),
    );
  }

  Widget _buildTwoInRow({
    required String leftTitle,
    required String leftLabel,
    required TextEditingController leftController,
    required String rightTitle,
    required String rightLabel,
    required TextEditingController rightController,
    TextInputType leftKeyboardType = TextInputType.text,
    TextInputType rightKeyboardType = TextInputType.text,
    bool leftReadOnly = false,
    bool rightReadOnly = false,
    VoidCallback? leftOnTap,
    VoidCallback? rightOnTap,
    bool leftRequired = false,
    bool rightRequired = false,
    List<TextInputFormatter>? leftInputFormatters,
    List<TextInputFormatter>? rightInputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _buildLabeledField(
              title: leftTitle,
              label: leftLabel,
              controller: leftController,
              keyboardType: leftKeyboardType,
              readOnly: leftReadOnly,
              onTap: leftOnTap,
              isRequired: leftRequired,
              inputFormatters: leftInputFormatters,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildLabeledField(
              title: rightTitle,
              label: rightLabel,
              controller: rightController,
              keyboardType: rightKeyboardType,
              readOnly: rightReadOnly,
              onTap: rightOnTap,
              isRequired: rightRequired,
              inputFormatters: rightInputFormatters,
            ),
          ),
        ],
      ),
    );
  }

  // ----- Dynamic rows logic -----
  void _addKeyConcernRow() {
    setState(() {
      _keyConcernControllers.add(TextEditingController());
      _productRecommendationControllers.add(TextEditingController());
    });
  }

  void _addProductRow() {
    setState(() {
      _productNameControllers.add(TextEditingController());
      _quantityControllers.add(TextEditingController());
      _packagingControllers.add(TextEditingController());
    });
  }

  // NEW: Export farmer signature as points (matching attendance form)
  Future<Map<String, dynamic>?> _exportFarmerSignaturePoints() async {
    final name = _farmerNameSecondController.text.trim();
    final SignatureController sc = _farmerSignaturePadController;

    // Skip if both name and signature are empty
    if (name.isEmpty && sc.isEmpty) {
      return null;
    }

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

    return {
      'name': name,
      'points': serializedPoints,
    };
  }

  bool _validateSignature() {
    if (_farmerSignaturePadController.isEmpty &&
        _farmerNameSecondController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Name of Farmer or Signature is required.')),
      );
      return false;
    }
    return true;
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    if (!_validateSignature()) {
      return;
    }

    // Ensure at least one advisory row is filled (key concern + recommendation)
    bool hasAdvisory = false;
    for (int i = 0; i < _keyConcernControllers.length; i++) {
      if (_keyConcernControllers[i].text.trim().isNotEmpty ||
          _productRecommendationControllers[i].text.trim().isNotEmpty) {
        hasAdvisory = true;
        break;
      }
    }
    if (!hasAdvisory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please provide at least one Key Concern and Product Recommendation.')),
      );
      return;
    }

    // Ensure at least one product row is filled (product name + quantity + packaging)
    bool hasProduct = false;
    for (int i = 0; i < _productNameControllers.length; i++) {
      if (_productNameControllers[i].text.trim().isNotEmpty ||
          _quantityControllers[i].text.trim().isNotEmpty ||
          _packagingControllers[i].text.trim().isNotEmpty) {
        hasProduct = true;
        break;
      }
    }
    if (!hasProduct) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please provide at least one Product (Name, Quantity, Packaging).')),
      );
      return;
    }

    // Build advisory details list
    final List<Map<String, String>> advisoryDetails = [];
    for (int i = 0; i < _keyConcernControllers.length; i++) {
      final keyConcern = _keyConcernControllers[i].text.trim();
      final recommendation =
          _productRecommendationControllers[i].text.trim();
      if (keyConcern.isEmpty && recommendation.isEmpty) continue;
      advisoryDetails.add({
        'keyConcern': keyConcern,
        'productRecommendation': recommendation,
      });
    }

    // Build product list
    final List<Map<String, String>> products = [];
    for (int i = 0; i < _productNameControllers.length; i++) {
      final name = _productNameControllers[i].text.trim();
      final qty = _quantityControllers[i].text.trim();
      final pack = _packagingControllers[i].text.trim();
      if (name.isEmpty && qty.isEmpty && pack.isEmpty) continue;
      products.add({
        'productName': name,
        'quantity': qty,
        'packaging': pack,
      });
    }

    // NEW: Export signature as points instead of PNG bytes
    Map<String, dynamic>? farmerSignaturePoints;
    try {
      farmerSignaturePoints = await _exportFarmerSignaturePoints();
    } catch (e) {
      farmerSignaturePoints = null;
    }

    try {
      final userKey = await _getSanitizedUserEmail(); // same as attendance page

      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(userKey)
          .doc('scp_forms')
          .collection('scp_forms')
          .add({
        'farmerName': _farmerNameController.text.trim(),
        'farmAddress': _farmAddressController.text.trim(),
        'cellphoneNumber': _cellphoneNumberController.text.trim(),
        'dateOfEvent': _dateOfEventController.text.trim(),
        'typeOfEvent': _typeOfEventController.text.trim(),
        'venueOfEvent': _venueOfEventController.text.trim(),
        'cropsPlanted': _cropsPlantedController.text.trim(),
        'advisoryDetails': advisoryDetails,
        'cropAdvisorName': _cropAdvisorNameController.text.trim(),
        'cropAdvisorContact': _cropAdvisorContactController.text.trim(),
        'products': products,
        'farmerNameSecond': _farmerNameSecondController.text.trim(),
        // CHANGED: Now saves points instead of base64 PNG
        'farmerSignaturePoints': farmerSignaturePoints,
        'dateNeeded': _dateNeededController.text.trim(),
        'preferredDealer': _preferredDealerController.text.trim(),
        'createdBy': createdBy,
        'timestamp': DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample Crop Prescription Form submitted.'),
        ),
      );

      _onClear();
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting form: $e'),
        ),
      );
    }
  }

  void _onClear() {
    _farmerNameController.clear();
    _farmAddressController.clear();
    _cellphoneNumberController.clear();
    _dateOfEventController.clear();
    _typeOfEventController.clear();
    _venueOfEventController.clear();
    _cropsPlantedController.clear();

    for (final c in _keyConcernControllers) {
      c.clear();
    }
    for (final c in _productRecommendationControllers) {
      c.clear();
    }
    _cropAdvisorNameController.clear();
    _cropAdvisorContactController.clear();

    for (final c in _productNameControllers) {
      c.clear();
    }
    for (final c in _quantityControllers) {
      c.clear();
    }
    for (final c in _packagingControllers) {
      c.clear();
    }

    _farmerNameSecondController.clear();
    _dateNeededController.clear();
    _preferredDealerController.clear();
    _farmerSignaturePadController.clear();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const int advisoryMaxLines = 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sample Crop Prescription Form',
          textAlign: TextAlign.center,
        ),
        centerTitle: true,
        elevation: 4,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
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
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Customer Success Meeting Form',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              _buildTwoInRow(
                leftTitle: 'Name of Farmer',
                leftLabel: '',
                leftController: _farmerNameController,
                rightTitle: 'Date of Event',
                rightLabel: '',
                rightController: _dateOfEventController,
                rightReadOnly: true,
                rightOnTap: () =>
                    _pickDateForController(_dateOfEventController),
                leftRequired: true,
                rightRequired: true,
              ),

              _buildTwoInRow(
                leftTitle: 'Farm Address',
                leftLabel: '',
                leftController: _farmAddressController,
                rightTitle: 'Type of Event',
                rightLabel: '',
                rightController: _typeOfEventController,
                leftRequired: true,
                rightRequired: true,
              ),

              _buildTwoInRow(
                leftTitle: 'Cellphone Number',
                leftLabel: '',
                leftController: _cellphoneNumberController,
                rightTitle: 'Venue of Event',
                rightLabel: '',
                rightController: _venueOfEventController,
                leftKeyboardType: TextInputType.number,
                leftRequired: true,
                rightRequired: true,
                leftInputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),

              _buildPaddedField(
                title: 'Crops Planted',
                label: '',
                controller: _cropsPlantedController,
                isRequired: true,
              ),

              const SizedBox(height: 16),

              // Advisory Details heading with + button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Advisory Details',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 28,
                    width: 28,
                    child: ElevatedButton(
                      onPressed: _addKeyConcernRow,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // All Key Concerns / Product Recommendation rows
              Column(
                children: List.generate(_keyConcernControllers.length, (index) {
                  final bool firstRow = index == 0;
                  return Padding(
                    padding: EdgeInsets.only(
                      top: index == 0 ? 6 : 4,
                      bottom: 0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: _buildLabeledField(
                          title: firstRow ? 'Key Concerns' : '',
                          label: '',
                          controller: _keyConcernControllers[index],
                          maxLines: advisoryMaxLines,
                          isRequired: firstRow,
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildLabeledField(
                          title:
                              firstRow ? 'Product Recommendation' : '',
                          label: '',
                          controller:
                              _productRecommendationControllers[index],
                          maxLines: advisoryMaxLines,
                          isRequired: firstRow,
                        )),
                      ],
                    ),
                  );
                }),
              ),

              const SizedBox(height: 10),

              _buildTwoInRow(
                leftTitle: 'Name of Crop Advisor',
                leftLabel: '',
                leftController: _cropAdvisorNameController,
                rightTitle: 'Crop Advisor Contact Number',
                rightLabel: '',
                rightController: _cropAdvisorContactController,
                rightKeyboardType: TextInputType.phone,
                leftRequired: true,
                rightRequired: true,
                rightInputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),

              const SizedBox(height: 16),

              // Product section heading + + button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Flexible(
                    child: Text(
                      'Indofil Crop Solutions and Technologies',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 28,
                    width: 28,
                    child: ElevatedButton(
                      onPressed: _addProductRow,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Product rows: each row fills screen width with proportional columns
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Column(
                  children:
                      List.generate(_productNameControllers.length, (index) {
                    final bool withTitles = index == 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: withTitles
                                ? _buildLabeledField(
                                    title: 'Product Name',
                                    label: '',
                                    controller:
                                        _productNameControllers[index],
                                    isRequired: true,
                                  )
                                : _buildPlainField(
                                    controller:
                                        _productNameControllers[index],
                                    isRequired: true,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: withTitles
                                ? _buildLabeledField(
                                    title: 'Quantity',
                                    label: '',
                                    controller: _quantityControllers[index],
                                    keyboardType: TextInputType.number,
                                    isRequired: true,
                                    inputFormatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                  )
                                : _buildPlainField(
                                    controller: _quantityControllers[index],
                                    keyboardType: TextInputType.number,
                                    isRequired: true,
                                    inputFormatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: withTitles
                                ? _buildLabeledField(
                                    title: 'Packaging',
                                    label: '',
                                    controller:
                                        _packagingControllers[index],
                                    isRequired: true,
                                  )
                                : _buildPlainField(
                                    controller:
                                        _packagingControllers[index],
                                    isRequired: true,
                                  ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 16),

              // UPDATED: Name of Farmer + Signature of Farmer (with Clear button matching attendance)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildLabeledField(
                        title: 'Name of Farmer',
                        label: '',
                        controller: _farmerNameSecondController,
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Signature of Farmer',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 4),
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Signature(
                                  controller: _farmerSignaturePadController,
                                  width: double.infinity,
                                  height: 80,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // NEW: Clear button matching attendance form style
                          SizedBox(
                            width: 100,
                            height: 32,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _farmerSignaturePadController.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: Colors.red.shade100,
                                foregroundColor: Colors.red.shade800,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text(
                                'Clear',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              _buildTwoInRow(
                leftTitle: 'Date Needed',
                leftLabel: '',
                leftController: _dateNeededController,
                rightTitle: 'Preferred Dealer',
                rightLabel: '',
                rightController: _preferredDealerController,
                leftReadOnly: true,
                leftOnTap: () =>
                    _pickDateForController(_dateNeededController),
                leftRequired: true,
                rightRequired: true,
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'submitFab',
              onPressed: _onSubmit,
              backgroundColor: const Color(0xFF5958b2),
              icon: const Icon(
                Icons.check,
                color: Colors.white,
              ),
              label: const Text(
                'Submit',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
