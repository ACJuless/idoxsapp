import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AbrFormPage extends StatefulWidget {
  const AbrFormPage({Key? key}) : super(key: key);

  @override
  State<AbrFormPage> createState() => _AbrFormPageState();
}

class _AbrFormPageState extends State<AbrFormPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _agronomistController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _cropFocusController = TextEditingController();
  final TextEditingController _activityTypeController = TextEditingController();

  // Location controllers (value stored as final string after dropdown selection)
  final TextEditingController _plannedLocationController =
      TextEditingController();
  final TextEditingController _actualLocationController =
      TextEditingController();

  final TextEditingController _plannedDateController = TextEditingController();
  final TextEditingController _actualDateController = TextEditingController();
  final TextEditingController _targetAttendeesController =
      TextEditingController();
  final TextEditingController _actualAttendeesController =
      TextEditingController();

  // Currency-related controllers
  final TextEditingController _budgetPerAttendeeController =
      TextEditingController();
  final TextEditingController _standardBudgetRequirementController =
      TextEditingController();
  final TextEditingController _additionalBudgetRequestController =
      TextEditingController();
  final TextEditingController _totalBudgetRequestedController =
      TextEditingController();
  final TextEditingController _actualBudgetSpentController =
      TextEditingController();
  final TextEditingController _totalTargetMoveoutValueController =
      TextEditingController();
  final TextEditingController _totalActualMoveoutValueController =
      TextEditingController();
  final TextEditingController _valueOtherProductsSoldBookedController =
      TextEditingController();
  final TextEditingController _valueProductsDeliveredDealersController =
      TextEditingController();

  final TextEditingController _justificationAdditionalBudgetController =
      TextEditingController();
  final TextEditingController _remarksActivityOutputController =
      TextEditingController();
  final TextEditingController _otherProductsSoldBookedController =
      TextEditingController();
  final TextEditingController _productsDeliveredDealersController =
      TextEditingController();

  // Product Focus table controllers (dynamic rows)
  final List<TextEditingController> productFocusControllers = [];
  final List<TextEditingController> targetMoveoutVolumeControllers = [];
  final List<TextEditingController> actualMoveoutVolumeControllers = [];
  final List<TextEditingController> targetMoveoutValuePfControllers = [];
  final List<TextEditingController> actualMoveoutValuePfControllers = [];

  String createdBy = '';

  // Dropdown backing values
  String? _selectedPlannedLocation;
  String? _selectedActualLocation;

  // Example location options – replace with your own list
  final List<String> _locationOptions = [
    'Brgy. San Antonio, Quezon City, Metro Manila',
    'Brgy. Commonwealth, Quezon City, Metro Manila',
    'Brgy. Batasan Hills, Quezon City, Metro Manila',
    'Brgy. Payatas, Quezon City, Metro Manila',
    'Brgy. Fairview, Quezon City, Metro Manila',
  ];

  // Focus nodes for currency fields to format on unfocus
  final FocusNode _budgetPerAttendeeFocusNode = FocusNode();
  final FocusNode _standardBudgetRequirementFocusNode = FocusNode();
  final FocusNode _additionalBudgetRequestFocusNode = FocusNode();
  final FocusNode _totalBudgetRequestedFocusNode = FocusNode();
  final FocusNode _actualBudgetSpentFocusNode = FocusNode();
  final FocusNode _totalTargetMoveoutValueFocusNode = FocusNode();
  final FocusNode _totalActualMoveoutValueFocusNode = FocusNode();
  final FocusNode _valueOtherProductsSoldBookedFocusNode = FocusNode();
  final FocusNode _valueProductsDeliveredDealersFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _addProductFocusRow();
    _loadCreatedByFromPrefs();

    _budgetPerAttendeeFocusNode.addListener(
      () => _onCurrencyFocusChange(
        _budgetPerAttendeeFocusNode,
        _budgetPerAttendeeController,
      ),
    );
    _standardBudgetRequirementFocusNode.addListener(
      () => _onCurrencyFocusChange(
        _standardBudgetRequirementFocusNode,
        _standardBudgetRequirementController,
      ),
    );
    _additionalBudgetRequestFocusNode.addListener(
      () => _onCurrencyFocusChange(
        _additionalBudgetRequestFocusNode,
        _additionalBudgetRequestController,
      ),
    );
    _totalBudgetRequestedFocusNode.addListener(
      () => _onCurrencyFocusChange(
        _totalBudgetRequestedFocusNode,
        _totalBudgetRequestedController,
      ),
    );
    _actualBudgetSpentFocusNode.addListener(
      () => _onCurrencyFocusChange(
        _actualBudgetSpentFocusNode,
        _actualBudgetSpentController,
      ),
    );
    _totalTargetMoveoutValueFocusNode.addListener(
      () => _onCurrencyFocusChange(
        _totalTargetMoveoutValueFocusNode,
        _totalTargetMoveoutValueController,
      ),
    );
    _totalActualMoveoutValueFocusNode.addListener(
      () => _onCurrencyFocusChange(
        _totalActualMoveoutValueFocusNode,
        _totalActualMoveoutValueController,
      ),
    );
    _valueOtherProductsSoldBookedFocusNode.addListener(
      () => _onCurrencyFocusChange(
        _valueOtherProductsSoldBookedFocusNode,
        _valueOtherProductsSoldBookedController,
      ),
    );
    _valueProductsDeliveredDealersFocusNode.addListener(
      () => _onCurrencyFocusChange(
        _valueProductsDeliveredDealersFocusNode,
        _valueProductsDeliveredDealersController,
      ),
    );
  }

  @override
  void dispose() {
    _agronomistController.dispose();
    _areaController.dispose();
    _cropFocusController.dispose();
    _activityTypeController.dispose();
    _plannedLocationController.dispose();
    _actualLocationController.dispose();
    _plannedDateController.dispose();
    _actualDateController.dispose();
    _targetAttendeesController.dispose();
    _actualAttendeesController.dispose();
    _budgetPerAttendeeController.dispose();
    _standardBudgetRequirementController.dispose();
    _additionalBudgetRequestController.dispose();
    _justificationAdditionalBudgetController.dispose();
    _totalBudgetRequestedController.dispose();
    _actualBudgetSpentController.dispose();
    _totalTargetMoveoutValueController.dispose();
    _totalActualMoveoutValueController.dispose();
    _remarksActivityOutputController.dispose();
    _otherProductsSoldBookedController.dispose();
    _valueOtherProductsSoldBookedController.dispose();
    _productsDeliveredDealersController.dispose();
    _valueProductsDeliveredDealersController.dispose();

    for (final c in productFocusControllers) {
      c.dispose();
    }
    for (final c in targetMoveoutVolumeControllers) {
      c.dispose();
    }
    for (final c in actualMoveoutVolumeControllers) {
      c.dispose();
    }
    for (final c in targetMoveoutValuePfControllers) {
      c.dispose();
    }
    for (final c in actualMoveoutValuePfControllers) {
      c.dispose();
    }

    _budgetPerAttendeeFocusNode.dispose();
    _standardBudgetRequirementFocusNode.dispose();
    _additionalBudgetRequestFocusNode.dispose();
    _totalBudgetRequestedFocusNode.dispose();
    _actualBudgetSpentFocusNode.dispose();
    _totalTargetMoveoutValueFocusNode.dispose();
    _totalActualMoveoutValueFocusNode.dispose();
    _valueOtherProductsSoldBookedFocusNode.dispose();
    _valueProductsDeliveredDealersFocusNode.dispose();

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
    return userEmail.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_');
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

  // Currency format on unfocus: add "P" at start and ".00" at end if needed
  void _onCurrencyFocusChange(
      FocusNode focusNode, TextEditingController controller) {
    if (focusNode.hasFocus) {
      final raw = controller.text.trim();
      if (raw.isEmpty) return;

      String value = raw;
      if (value.startsWith('P')) {
        value = value.substring(1).trim();
      }
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    } else {
      final raw = controller.text.trim();
      if (raw.isEmpty) return;

      String value = raw;
      if (value.startsWith('P')) {
        value = value.substring(1).trim();
      }

      if (!value.contains('.')) {
        value = '$value.00';
      }

      final formatted = 'P$value';
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Widget _buildLabeledField({
    required String title,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    FocusNode? focusNode,
    Widget? prefix,
    Widget? suffix,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            isDense: true,
            prefixIcon: prefix,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }

  Widget _buildTwoInRow({
    required String leftTitle,
    required TextEditingController leftController,
    required String rightTitle,
    required TextEditingController rightController,
    int leftMaxLines = 1,
    int rightMaxLines = 1,
    TextInputType leftKeyboardType = TextInputType.text,
    TextInputType rightKeyboardType = TextInputType.text,
    bool leftReadOnly = false,
    bool rightReadOnly = false,
    VoidCallback? leftOnTap,
    VoidCallback? rightOnTap,
    FocusNode? leftFocusNode,
    FocusNode? rightFocusNode,
    Widget? leftPrefix,
    Widget? rightPrefix,
    Widget? leftSuffix,
    Widget? rightSuffix,
    List<TextInputFormatter>? leftInputFormatters,
    List<TextInputFormatter>? rightInputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildLabeledField(
              title: leftTitle,
              controller: leftController,
              maxLines: leftMaxLines,
              keyboardType: leftKeyboardType,
              readOnly: leftReadOnly,
              onTap: leftOnTap,
              focusNode: leftFocusNode,
              prefix: leftPrefix,
              suffix: leftSuffix,
              inputFormatters: leftInputFormatters,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildLabeledField(
              title: rightTitle,
              controller: rightController,
              maxLines: rightMaxLines,
              keyboardType: rightKeyboardType,
              readOnly: rightReadOnly,
              onTap: rightOnTap,
              focusNode: rightFocusNode,
              prefix: rightPrefix,
              suffix: rightSuffix,
              inputFormatters: rightInputFormatters,
            ),
          ),
        ],
      ),
    );
  }

  // ----- Product Focus table helpers -----

  void _addProductFocusRow() {
    setState(() {
      productFocusControllers.add(TextEditingController());
      targetMoveoutVolumeControllers.add(TextEditingController());
      actualMoveoutVolumeControllers.add(TextEditingController());
      targetMoveoutValuePfControllers.add(TextEditingController());
      actualMoveoutValuePfControllers.add(TextEditingController());
    });
  }

  Widget _headerCell(String label) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: Colors.cyan.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.cyan.shade200,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _dataCell(Widget child) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 4),
      child: child,
    );
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check the form before submitting.'),
        ),
      );
      return;
    }

    // Build Product Focus rows
    final List<Map<String, dynamic>> productFocusRows = [];
    for (int i = 0; i < productFocusControllers.length; i++) {
      final pf = productFocusControllers[i].text.trim();
      final targetVol = targetMoveoutVolumeControllers[i].text.trim();
      final actualVol = actualMoveoutVolumeControllers[i].text.trim();
      final targetVal = targetMoveoutValuePfControllers[i].text.trim();
      final actualVal = actualMoveoutValuePfControllers[i].text.trim();

      if (pf.isEmpty &&
          targetVol.isEmpty &&
          actualVol.isEmpty &&
          targetVal.isEmpty &&
          actualVal.isEmpty) {
        continue;
      }

      productFocusRows.add({
        'productFocus': pf,
        'targetMoveoutVolume': targetVol,
        'actualMoveoutVolume': actualVol,
        'targetMoveoutValuePf': targetVal,
        'actualMoveoutValuePf': actualVal,
      });
    }

    try {
      final userKey = await _getSanitizedUserEmail();

      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(userKey)
          .doc('abr_forms')
          .collection('abr_forms')
          .add({
        'agronomist': _agronomistController.text.trim(),
        'area': _areaController.text.trim(),
        'cropFocus': _cropFocusController.text.trim(),
        'activityType': _activityTypeController.text.trim(),
        'plannedLocation': _plannedLocationController.text.trim(),
        'actualLocation': _actualLocationController.text.trim(),
        'plannedDate': _plannedDateController.text.trim(),
        'actualDate': _actualDateController.text.trim(),
        'targetAttendees': _targetAttendeesController.text.trim(),
        'actualAttendees': _actualAttendeesController.text.trim(),
        'budgetPerAttendee': _budgetPerAttendeeController.text.trim(),
        'standardBudgetRequirement':
            _standardBudgetRequirementController.text.trim(),
        'additionalBudgetRequest':
            _additionalBudgetRequestController.text.trim(),
        'justificationAdditionalBudget':
            _justificationAdditionalBudgetController.text.trim(),
        'totalBudgetRequested': _totalBudgetRequestedController.text.trim(),
        'actualBudgetSpent': _actualBudgetSpentController.text.trim(),
        'productFocusRows': productFocusRows,
        'totalTargetMoveoutValue':
            _totalTargetMoveoutValueController.text.trim(),
        'totalActualMoveoutValue':
            _totalActualMoveoutValueController.text.trim(),
        'remarksActivityOutput':
            _remarksActivityOutputController.text.trim(),
        'otherProductsSoldBooked':
            _otherProductsSoldBookedController.text.trim(),
        'valueOtherProductsSoldBooked':
            _valueOtherProductsSoldBookedController.text.trim(),
        'productsDeliveredDealers':
            _productsDeliveredDealersController.text.trim(),
        'valueProductsDeliveredDealers':
            _valueProductsDeliveredDealersController.text.trim(),
        'createdBy': createdBy,
        'timestamp': DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity Budget Request Form submitted.'),
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
    _agronomistController.clear();
    _areaController.clear();
    _cropFocusController.clear();
    _activityTypeController.clear();
    _plannedLocationController.clear();
    _actualLocationController.clear();
    _plannedDateController.clear();
    _actualDateController.clear();
    _targetAttendeesController.clear();
    _actualAttendeesController.clear();
    _budgetPerAttendeeController.clear();
    _standardBudgetRequirementController.clear();
    _additionalBudgetRequestController.clear();
    _justificationAdditionalBudgetController.clear();
    _totalBudgetRequestedController.clear();
    _actualBudgetSpentController.clear();
    _totalTargetMoveoutValueController.clear();
    _totalActualMoveoutValueController.clear();
    _remarksActivityOutputController.clear();
    _otherProductsSoldBookedController.clear();
    _valueOtherProductsSoldBookedController.clear();
    _productsDeliveredDealersController.clear();
    _valueProductsDeliveredDealersController.clear();

    for (final c in productFocusControllers) {
      c.clear();
    }
    for (final c in targetMoveoutVolumeControllers) {
      c.clear();
    }
    for (final c in actualMoveoutVolumeControllers) {
      c.clear();
    }
    for (final c in targetMoveoutValuePfControllers) {
      c.clear();
    }
    for (final c in actualMoveoutValuePfControllers) {
      c.clear();
    }

    setState(() {
      _selectedPlannedLocation = null;
      _selectedActualLocation = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Activity Budget Request Form',
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
                'Create Budget Request',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Agronomist + Area
              _buildTwoInRow(
                leftTitle: 'Agronomist',
                leftController: _agronomistController,
                rightTitle: 'Area',
                rightController: _areaController,
              ),

              // Crop Focus + Activity Type
              _buildTwoInRow(
                leftTitle: 'Crop Focus',
                leftController: _cropFocusController,
                rightTitle: 'Activity Type',
                rightController: _activityTypeController,
              ),

              // Planned Activity Location + Actual Activity Location (dropdowns)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Planned Activity Location (Brgy, Municipality, Province)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _selectedPlannedLocation,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _locationOptions
                                .map(
                                  (loc) => DropdownMenuItem<String>(
                                    value: loc,
                                    child: Text(
                                      loc,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedPlannedLocation = value;
                                _plannedLocationController.text =
                                    value ?? '';
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Actual Activity Location (Brgy, Municipality, Province)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _selectedActualLocation,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _locationOptions
                                .map(
                                  (loc) => DropdownMenuItem<String>(
                                    value: loc,
                                    child: Text(
                                      loc,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedActualLocation = value;
                                _actualLocationController.text =
                                    value ?? '';
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Planned Activity Date + Actual Activity Date (date inputs with picker)
              _buildTwoInRow(
                leftTitle: 'Planned Activity Date',
                leftController: _plannedDateController,
                rightTitle: 'Actual Activity Date',
                rightController: _actualDateController,
                leftReadOnly: true,
                rightReadOnly: true,
                leftOnTap: () => _pickDateForController(_plannedDateController),
                rightOnTap: () => _pickDateForController(_actualDateController),
              ),

              // Target Number of Attendees + Actual Number of Attendees
              _buildTwoInRow(
                leftTitle: 'Target Number of Attendees',
                leftController: _targetAttendeesController,
                rightTitle: 'Actual Number of Attendees',
                rightController: _actualAttendeesController,
                leftKeyboardType: TextInputType.number,
                rightKeyboardType: TextInputType.number,
                leftInputFormatters: [FilteringTextInputFormatter.digitsOnly],
                rightInputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),

              // Budget per Attendee
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: _buildLabeledField(
                  title: 'Budget per Attendee',
                  controller: _budgetPerAttendeeController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  focusNode: _budgetPerAttendeeFocusNode,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                ),
              ),

              // Standard Budget Requirement
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: _buildLabeledField(
                  title: 'Standard Budget Requirement',
                  controller: _standardBudgetRequirementController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  focusNode: _standardBudgetRequirementFocusNode,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                ),
              ),

              // Additional Budget Request
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: _buildLabeledField(
                  title: 'Additional Budget Request',
                  controller: _additionalBudgetRequestController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  focusNode: _additionalBudgetRequestFocusNode,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                ),
              ),

              // Justification for Additional Budget
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: _buildLabeledField(
                  title: 'Justification for Additional Budget',
                  controller: _justificationAdditionalBudgetController,
                  maxLines: 3,
                ),
              ),

              // Total Budget Requested + Actual Budget Spent
              _buildTwoInRow(
                leftTitle: 'Total Budget Requested',
                leftController: _totalBudgetRequestedController,
                rightTitle: 'Actual Budget Spent',
                rightController: _actualBudgetSpentController,
                leftKeyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                rightKeyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                leftFocusNode: _totalBudgetRequestedFocusNode,
                rightFocusNode: _actualBudgetSpentFocusNode,
                leftInputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                rightInputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),

              const SizedBox(height: 12),

              // Product Focus table header (with + button)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.cyan.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.cyan.shade100,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      height: 26,
                      width: 26,
                      child: ElevatedButton(
                        onPressed: _addProductFocusRow,
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
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Product Focus",
                        maxLines: 2,
                        softWrap: true,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Product Focus table: header + rows
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _headerCell("Product Focus (1,2,3,etc.)"),
                        _headerCell(
                            "Target Moveout Volume (in packs or bottles)"),
                        _headerCell(
                            "Actual Moveout Volume (in packs or bottles)"),
                        _headerCell("Target Moveout Value PF"),
                        _headerCell("Actual Moveout Value PF"),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Column(
                      children:
                          List.generate(productFocusControllers.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Focus
                              _dataCell(
                                TextField(
                                  controller: productFocusControllers[index],
                                  cursorColor: Colors.black,
                                  decoration: InputDecoration(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 16.0, horizontal: 8.0),
                                    hintText: "",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 0.5),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 0.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 0.5),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ),

                              // Target Moveout Volume
                              _dataCell(
                                TextField(
                                  controller:
                                      targetMoveoutVolumeControllers[index],
                                  keyboardType: TextInputType.number,
                                  cursorColor: Colors.black,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 16.0, horizontal: 8.0),
                                    hintText: "",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 0.5),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 0.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 0.5),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ),

                              // Actual Moveout Volume
                              _dataCell(
                                TextField(
                                  controller:
                                      actualMoveoutVolumeControllers[index],
                                  keyboardType: TextInputType.number,
                                  cursorColor: Colors.black,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 16.0, horizontal: 8.0),
                                    hintText: "",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 0.5),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 0.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 0.5),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ),

                              // Target Moveout Value PF
                              _dataCell(
                                TextField(
                                  controller:
                                      targetMoveoutValuePfControllers[index],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  cursorColor: Colors.black,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                  ],
                                  decoration: InputDecoration(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 16.0, horizontal: 8.0),
                                    hintText: "",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 0.5),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 0.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 0.5),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ),

                              // Actual Moveout Value PF
                              _dataCell(
                                TextField(
                                  controller:
                                      actualMoveoutValuePfControllers[index],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  cursorColor: Colors.black,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                  ],
                                  decoration: InputDecoration(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 16.0, horizontal: 8.0),
                                    hintText: "",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 0.5),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 0.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 0.5),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Total Target Moveout Value + Total Actual Moveout Value
              _buildTwoInRow(
                leftTitle: 'Total Target Moveout Value',
                leftController: _totalTargetMoveoutValueController,
                rightTitle: 'Total Actual Moveout Value',
                rightController: _totalActualMoveoutValueController,
                leftKeyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                rightKeyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                leftFocusNode: _totalTargetMoveoutValueFocusNode,
                rightFocusNode: _totalActualMoveoutValueFocusNode,
                leftInputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                rightInputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),

              // Remarks on Activity Output
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: _buildLabeledField(
                  title: 'Remarks on Activity Output',
                  controller: _remarksActivityOutputController,
                  maxLines: 3,
                ),
              ),

              // Other Products Sold or Booked + Value of Other Products Sold or Booked
              _buildTwoInRow(
                leftTitle: 'Other Products Sold or Booked',
                leftController: _otherProductsSoldBookedController,
                rightTitle: 'Value of other Products Sold or Booked',
                rightController: _valueOtherProductsSoldBookedController,
                leftMaxLines: 2,
                leftKeyboardType: TextInputType.text,
                rightKeyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                rightFocusNode: _valueOtherProductsSoldBookedFocusNode,
                rightInputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),

              // Products delivered to Dealers + Value of products delivered to Dealers
              _buildTwoInRow(
                leftTitle: 'Products delivered to Dealers',
                leftController: _productsDeliveredDealersController,
                rightTitle: 'Value of products delivered to Dealers',
                rightController: _valueProductsDeliveredDealersController,
                leftMaxLines: 2,
                leftKeyboardType: TextInputType.text,
                rightKeyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                rightFocusNode: _valueProductsDeliveredDealersFocusNode,
                rightInputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'submitAbrFab',
        onPressed: _onSubmit,
        backgroundColor: const Color(0xFF5e1398),
        icon: const Icon(
          Icons.check,
          color: Colors.white,
        ),
        label: const Text(
          'Submit',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}