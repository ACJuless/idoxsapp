import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'abr_form_page.dart';

/// Read‑only / editable detail page for a single ABR form.
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
  bool _isSaving = false;

  late Map<String, dynamic> _originalFormData;

  // Controllers for main fields
  late TextEditingController _agronomistCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _cropFocusCtrl;
  late TextEditingController _activityTypeCtrl;
  late TextEditingController _plannedLocationCtrl;
  late TextEditingController _actualLocationCtrl;
  late TextEditingController _plannedActivityDateCtrl;
  late TextEditingController _actualActivityDateCtrl;
  late TextEditingController _targetAttendeesCtrl;
  late TextEditingController _actualAttendeesCtrl;
  late TextEditingController _budgetPerAttendeeCtrl;
  late TextEditingController _standardBudgetRequirementCtrl;
  late TextEditingController _additionalBudgetRequestCtrl;
  late TextEditingController _justificationForAdditionalBudgetCtrl;
  late TextEditingController _totalBudgetRequestedCtrl;
  late TextEditingController _actualBudgetSpentCtrl;
  late TextEditingController _totalTargetMoveoutValueCtrl;
  late TextEditingController _totalActualMoveoutValueCtrl;
  late TextEditingController _remarksOnActivityOutputCtrl;
  late TextEditingController _otherProductsSoldOrBookedCtrl;
  late TextEditingController _valueOfOtherProductsSoldOrBookedCtrl;
  late TextEditingController _productsDeliveredToDealersCtrl;
  late TextEditingController _valueOfProductsDeliveredToDealersCtrl;

  String _createdBy = '';

  // Product focus rows: list of maps, each with controllers
  List<_ProductFocusRowControllers> _productFocusControllers = [];

  @override
  void initState() {
    super.initState();
    _originalFormData = Map<String, dynamic>.from(widget.formData);
    _initFromFormData(_originalFormData);
  }

  void _initFromFormData(Map<String, dynamic> formData) {
    _agronomistCtrl =
        TextEditingController(text: formData['agronomist'] ?? '');
    _areaCtrl = TextEditingController(text: formData['area'] ?? '');
    _cropFocusCtrl = TextEditingController(text: formData['cropFocus'] ?? '');
    _activityTypeCtrl =
        TextEditingController(text: formData['activityType'] ?? '');
    _plannedLocationCtrl =
        TextEditingController(text: formData['plannedLocation'] ?? '');
    _actualLocationCtrl =
        TextEditingController(text: formData['actualLocation'] ?? '');
    _plannedActivityDateCtrl =
        TextEditingController(text: formData['plannedDate'] ?? '');
    _actualActivityDateCtrl =
        TextEditingController(text: formData['actualDate'] ?? '');
    _targetAttendeesCtrl = TextEditingController(
        text: formData['targetAttendees']?.toString() ?? '');
    _actualAttendeesCtrl = TextEditingController(
        text: formData['actualAttendees']?.toString() ?? '');
    _budgetPerAttendeeCtrl = TextEditingController(
        text: formData['budgetPerAttendee']?.toString() ?? '');
    _standardBudgetRequirementCtrl = TextEditingController(
        text: formData['standardBudgetRequirement']?.toString() ?? '');
    _additionalBudgetRequestCtrl = TextEditingController(
        text: formData['additionalBudgetRequest']?.toString() ?? '');
    _justificationForAdditionalBudgetCtrl =
        TextEditingController(text: formData['justificationAdditionalBudget'] ?? '');
    _totalBudgetRequestedCtrl = TextEditingController(
        text: formData['totalBudgetRequested']?.toString() ?? '');
    _actualBudgetSpentCtrl = TextEditingController(
        text: formData['actualBudgetSpent']?.toString() ?? '');
    _totalTargetMoveoutValueCtrl = TextEditingController(
        text: formData['totalTargetMoveoutValue']?.toString() ?? '');
    _totalActualMoveoutValueCtrl = TextEditingController(
        text: formData['totalActualMoveoutValue']?.toString() ?? '');
    _remarksOnActivityOutputCtrl =
        TextEditingController(text: formData['remarksActivityOutput'] ?? '');
    _otherProductsSoldOrBookedCtrl =
        TextEditingController(text: formData['otherProductsSoldBooked'] ?? '');
    _valueOfOtherProductsSoldOrBookedCtrl = TextEditingController(
        text: formData['valueOtherProductsSoldBooked']?.toString() ?? '');
    _productsDeliveredToDealersCtrl =
        TextEditingController(text: formData['productsDeliveredDealers'] ?? '');
    _valueOfProductsDeliveredToDealersCtrl = TextEditingController(
        text: formData['valueProductsDeliveredDealers']?.toString() ?? '');

    _createdBy = formData['createdBy'] ?? '';

    final List<dynamic> productFocusRaw =
        formData['productFocusRows'] ?? [];
    _productFocusControllers = productFocusRaw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .map((row) => _ProductFocusRowControllers(
              productFocus: TextEditingController(
                  text: row['productFocus']?.toString() ?? ''),
              targetMoveoutVolume: TextEditingController(
                  text: row['targetMoveoutVolume']?.toString() ?? ''),
              actualMoveoutVolume: TextEditingController(
                  text: row['actualMoveoutVolume']?.toString() ?? ''),
              targetMoveoutValuePf: TextEditingController(
                  text: row['targetMoveoutValuePf']?.toString() ?? ''),
              actualMoveoutValuePf: TextEditingController(
                  text: row['actualMoveoutValuePf']?.toString() ?? ''),
            ))
        .toList();
  }

  void _resetToOriginal() {
    // dispose old controllers and recreate from original data
    _agronomistCtrl.dispose();
    _areaCtrl.dispose();
    _cropFocusCtrl.dispose();
    _activityTypeCtrl.dispose();
    _plannedLocationCtrl.dispose();
    _actualLocationCtrl.dispose();
    _plannedActivityDateCtrl.dispose();
    _actualActivityDateCtrl.dispose();
    _targetAttendeesCtrl.dispose();
    _actualAttendeesCtrl.dispose();
    _budgetPerAttendeeCtrl.dispose();
    _standardBudgetRequirementCtrl.dispose();
    _additionalBudgetRequestCtrl.dispose();
    _justificationForAdditionalBudgetCtrl.dispose();
    _totalBudgetRequestedCtrl.dispose();
    _actualBudgetSpentCtrl.dispose();
    _totalTargetMoveoutValueCtrl.dispose();
    _totalActualMoveoutValueCtrl.dispose();
    _remarksOnActivityOutputCtrl.dispose();
    _otherProductsSoldOrBookedCtrl.dispose();
    _valueOfOtherProductsSoldOrBookedCtrl.dispose();
    _productsDeliveredToDealersCtrl.dispose();
    _valueOfProductsDeliveredToDealersCtrl.dispose();
    for (final p in _productFocusControllers) {
      p.dispose();
    }
    _initFromFormData(_originalFormData);
  }

  @override
  void dispose() {
    _agronomistCtrl.dispose();
    _areaCtrl.dispose();
    _cropFocusCtrl.dispose();
    _activityTypeCtrl.dispose();
    _plannedLocationCtrl.dispose();
    _actualLocationCtrl.dispose();
    _plannedActivityDateCtrl.dispose();
    _actualActivityDateCtrl.dispose();
    _targetAttendeesCtrl.dispose();
    _actualAttendeesCtrl.dispose();
    _budgetPerAttendeeCtrl.dispose();
    _standardBudgetRequirementCtrl.dispose();
    _additionalBudgetRequestCtrl.dispose();
    _justificationForAdditionalBudgetCtrl.dispose();
    _totalBudgetRequestedCtrl.dispose();
    _actualBudgetSpentCtrl.dispose();
    _totalTargetMoveoutValueCtrl.dispose();
    _totalActualMoveoutValueCtrl.dispose();
    _remarksOnActivityOutputCtrl.dispose();
    _otherProductsSoldOrBookedCtrl.dispose();
    _valueOfOtherProductsSoldOrBookedCtrl.dispose();
    _productsDeliveredToDealersCtrl.dispose();
    _valueOfProductsDeliveredToDealersCtrl.dispose();
    for (final p in _productFocusControllers) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Rebuild productFocusRows list from controllers
      final List<Map<String, dynamic>> productFocusRows =
          _productFocusControllers.map((p) {
        return {
          'productFocus': p.productFocus.text,
          'targetMoveoutVolume': p.targetMoveoutVolume.text,
          'actualMoveoutVolume': p.actualMoveoutVolume.text,
          'targetMoveoutValuePf': p.targetMoveoutValuePf.text,
          'actualMoveoutValuePf': p.actualMoveoutValuePf.text,
        };
      }).toList();

      final updateData = {
        'agronomist': _agronomistCtrl.text,
        'area': _areaCtrl.text,
        'cropFocus': _cropFocusCtrl.text,
        'activityType': _activityTypeCtrl.text,
        'plannedLocation': _plannedLocationCtrl.text,
        'actualLocation': _actualLocationCtrl.text,
        'plannedDate': _plannedActivityDateCtrl.text,
        'actualDate': _actualActivityDateCtrl.text,
        'targetAttendees': _targetAttendeesCtrl.text,
        'actualAttendees': _actualAttendeesCtrl.text,
        'budgetPerAttendee': _budgetPerAttendeeCtrl.text,
        'standardBudgetRequirement': _standardBudgetRequirementCtrl.text,
        'additionalBudgetRequest': _additionalBudgetRequestCtrl.text,
        'justificationAdditionalBudget':
            _justificationForAdditionalBudgetCtrl.text,
        'totalBudgetRequested': _totalBudgetRequestedCtrl.text,
        'actualBudgetSpent': _actualBudgetSpentCtrl.text,
        'totalTargetMoveoutValue': _totalTargetMoveoutValueCtrl.text,
        'totalActualMoveoutValue': _totalActualMoveoutValueCtrl.text,
        'remarksActivityOutput': _remarksOnActivityOutputCtrl.text,
        'otherProductsSoldBooked': _otherProductsSoldOrBookedCtrl.text,
        'valueOtherProductsSoldBooked':
            _valueOfOtherProductsSoldOrBookedCtrl.text,
        'productsDeliveredDealers': _productsDeliveredToDealersCtrl.text,
        'valueProductsDeliveredDealers':
            _valueOfProductsDeliveredToDealersCtrl.text,
        'productFocusRows': productFocusRows,
      };

      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(widget.userKey)
          .doc('abr_forms')
          .collection('abr_forms')
          .doc(widget.docId)
          .update(updateData);

      // Update local original copy so cancel will revert to latest saved state next time
      _originalFormData.addAll(updateData);

      setState(() {
        _isEditMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ABR form updated successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ABR Form Detail'),
        backgroundColor: const Color(0xFF5958b2),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel edit',
              onPressed: () {
                setState(() {
                  _resetToOriginal();
                  _isEditMode = false;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: () {
                setState(() {
                  _isEditMode = true;
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Core budget request info
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
                    const Text(
                      'Create Budget Request',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5958b2),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildField(
                      label: 'Agronomist',
                      controller: _agronomistCtrl,
                    ),
                    _buildField(
                      label: 'Area',
                      controller: _areaCtrl,
                    ),
                    _buildField(
                      label: 'Crop Focus',
                      controller: _cropFocusCtrl,
                    ),
                    _buildField(
                      label: 'Activity Type',
                      controller: _activityTypeCtrl,
                    ),
                    _buildField(
                      label:
                          'Planned Activity Location (Brgy, Municipality, Province)',
                      controller: _plannedLocationCtrl,
                    ),
                    _buildField(
                      label:
                          'Actual Activity Location (Brgy, Municipality, Province)',
                      controller: _actualLocationCtrl,
                    ),
                    _buildField(
                      label: 'Planned Activity Date',
                      controller: _plannedActivityDateCtrl,
                    ),
                    _buildField(
                      label: 'Actual Activity Date',
                      controller: _actualActivityDateCtrl,
                    ),
                    _buildField(
                      label: 'Target Number of Attendees',
                      controller: _targetAttendeesCtrl,
                      keyboardType: TextInputType.number,
                    ),
                    _buildField(
                      label: 'Actual Number of Attendees',
                      controller: _actualAttendeesCtrl,
                      keyboardType: TextInputType.number,
                    ),
                    _buildField(
                      label: 'Budget per Attendee',
                      controller: _budgetPerAttendeeCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    _buildField(
                      label: 'Standard Budget Requirement',
                      controller: _standardBudgetRequirementCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    _buildField(
                      label: 'Additional Budget Request',
                      controller: _additionalBudgetRequestCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    _buildField(
                      label: 'Justification for Additional Budget',
                      controller: _justificationForAdditionalBudgetCtrl,
                      maxLines: 3,
                    ),
                    _buildField(
                      label: 'Total Budget Requested',
                      controller: _totalBudgetRequestedCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    _buildField(
                      label: 'Actual Budget Spent',
                      controller: _actualBudgetSpentCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Product Focus + moveout info
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
                    const Text(
                      'Product Focus',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5958b2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_productFocusControllers.isNotEmpty)
                      Column(
                        children:
                            _productFocusControllers.asMap().entries.map((e) {
                          final index = e.key;
                          final row = e.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildField(
                                  label:
                                      'Product Focus (1,2,3,etc.) #${index + 1}',
                                  controller: row.productFocus,
                                ),
                                _buildField(
                                  label:
                                      'Target Moveout Volume (in packs or bottles)',
                                  controller: row.targetMoveoutVolume,
                                  keyboardType: TextInputType.number,
                                ),
                                _buildField(
                                  label:
                                      'Actual Moveout Volume (in packs or bottles)',
                                  controller: row.actualMoveoutVolume,
                                  keyboardType: TextInputType.number,
                                ),
                                _buildField(
                                  label: 'Target Moveout Value PF',
                                  controller: row.targetMoveoutValuePf,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                ),
                                _buildField(
                                  label: 'Actual Moveout Value PF',
                                  controller: row.actualMoveoutValuePf,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    _buildField(
                      label: 'Total Target Moveout Value',
                      controller: _totalTargetMoveoutValueCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    _buildField(
                      label: 'Total Actual Moveout Value',
                      controller: _totalActualMoveoutValueCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    _buildField(
                      label: 'Remarks on Activity Output',
                      controller: _remarksOnActivityOutputCtrl,
                      maxLines: 3,
                    ),
                    _buildField(
                      label: 'Other Products Sold or Booked',
                      controller: _otherProductsSoldOrBookedCtrl,
                      maxLines: 2,
                    ),
                    _buildField(
                      label: 'Value of other Products Sold or Booked',
                      controller: _valueOfOtherProductsSoldOrBookedCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    _buildField(
                      label: 'Products delivered to Dealers',
                      controller: _productsDeliveredToDealersCtrl,
                      maxLines: 2,
                    ),
                    _buildField(
                      label: 'Value of products delivered to Dealers',
                      controller: _valueOfProductsDeliveredToDealersCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_createdBy.isNotEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.person,
                          size: 20, color: Color(0xFF5958b2)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Created by: $_createdBy',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 80), // extra space so FAB doesn't cover content
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isEditMode
          ? SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5958b2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Update',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            )
          : null,
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    if (!_isEditMode) {
      final value = controller.text;
      if (value.isEmpty) return const SizedBox.shrink();
      return _readonlyField(label, value);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.cyan.shade50,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.cyan.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFocusRowControllers {
  final TextEditingController productFocus;
  final TextEditingController targetMoveoutVolume;
  final TextEditingController actualMoveoutVolume;
  final TextEditingController targetMoveoutValuePf;
  final TextEditingController actualMoveoutValuePf;

  _ProductFocusRowControllers({
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

// ----------------------------------------------------------------------
// AbrFormTransactionsPage – unchanged from previous version
// ----------------------------------------------------------------------

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
    final userEmail = prefs.getString('userEmail') ?? '';
    setState(() {
      userKey = userEmail.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_');
    });
  }

  Future<void> _navigateToAbrFormPage(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AbrFormPage(),
      ),
    );
    if (result == true) {
      setState(() {});
    }
  }

  void _openDetail(
    BuildContext context,
    Map<String, dynamic> formData,
    String docId,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AbrFormReadonlyPage(
          formData: formData,
          docId: docId,
          userKey: userKey,
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic ts, String fallback) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final double cardWidth = (MediaQuery.of(context).size.width - 48) / 2;
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
          title: const Text('Activity Budget Request Form'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Activity Budget Request',
              onPressed: () => _navigateToAbrFormPage(context),
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
                  .doc('abr_forms')
                  .collection('abr_forms')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No ABR forms yet. Tap + to create a new.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: GridView.builder(
                    itemCount: docs.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: cardWidth / cardHeight,
                    ),
                    itemBuilder: (context, idx) {
                      final doc = docs[idx];
                      final data = doc.data() as Map<String, dynamic>;

                      final String activityName =
                          (data['agronomist'] as String?) ??
                              'No agronomist';

                      final dynamic ts = data['timestamp'];
                      final String plannedDate =
                          (data['plannedDate'] as String?) ??
                              (data['plannedActivityDate'] as String?) ??
                              '';
                      final String date = _formatTimestamp(
                          ts, plannedDate.isEmpty ? '-' : plannedDate);

                      final String location =
                          (data['plannedLocation'] as String?) ??
                              (data['plannedActivityLocation'] as String?) ??
                              (data['location'] as String?) ??
                              '';

                      final transactionNumber = docs.length - idx;
                      final transactionLabel = 'ABR #$transactionNumber';

                      return SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openDetail(context, data, doc.id),
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
                                          Icons.request_page_outlined,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            transactionLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
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
                                            activityName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (location.isNotEmpty)
                                            Text(
                                              'Location: $location',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
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
