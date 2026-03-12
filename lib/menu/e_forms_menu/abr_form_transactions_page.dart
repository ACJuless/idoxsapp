import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'abr_form_page.dart';

/// Read‑only / editable detail page for a single ABR form.
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

  // Product focus rows
  List<_ProductFocusRowControllers> _productFocusControllers = [];

  // For collapsible PF cards (view/edit)
  final Set<int> _openPF = {};

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
    _justificationForAdditionalBudgetCtrl = TextEditingController(
        text: formData['justificationAdditionalBudget'] ?? '');
    _totalBudgetRequestedCtrl = TextEditingController(
        text: formData['totalBudgetRequested']?.toString() ?? '');
    _actualBudgetSpentCtrl = TextEditingController(
        text: formData['actualBudgetSpent']?.toString() ?? '');
    _totalTargetMoveoutValueCtrl = TextEditingController(
        text: formData['totalTargetMoveoutValue']?.toString() ?? '');
    _totalActualMoveoutValueCtrl = TextEditingController(
        text: formData['totalActualMoveoutValue']?.toString() ?? '');
    _remarksOnActivityOutputCtrl = TextEditingController(
        text: formData['remarksActivityOutput'] ?? '');
    _otherProductsSoldOrBookedCtrl = TextEditingController(
        text: formData['otherProductsSoldBooked'] ?? '');
    _valueOfOtherProductsSoldOrBookedCtrl = TextEditingController(
        text: formData['valueOtherProductsSoldBooked']?.toString() ?? '');
    _productsDeliveredToDealersCtrl = TextEditingController(
        text: formData['productsDeliveredDealers'] ?? '');
    _valueOfProductsDeliveredToDealersCtrl = TextEditingController(
        text: formData['valueProductsDeliveredDealers']?.toString() ?? '');

    _createdBy = formData['createdBy'] ?? '';

    final List<dynamic> productFocusRaw = formData['productFocusRows'] ?? [];
    _productFocusControllers = productFocusRaw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .map(
          (row) => _ProductFocusRowControllers(
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
          ),
        )
        .toList();
    _openPF.clear();
  }

  void _resetToOriginal() {
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
    const surfaceColor = Color(0xFFF9F5FF);
    const maxWidth = 760.0;

    final agronomistName =
        _agronomistCtrl.text.isNotEmpty ? _agronomistCtrl.text : 'Activity Budget Request';

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(22),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4A2371),
                  Color(0xFF4A2371),
                  Color(0xFF5958B2),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(76, 29, 149, 0.3),
                  blurRadius: 28,
                  offset: Offset(0, 6),
                ),
              ],
            ),
          ),
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(left: 12, right: 10, top: 2),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    minimumSize: const Size(34, 34),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Activity Budget Request',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color.fromRGBO(255, 255, 255, 0.65),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        agronomistName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          if (_isEditMode) {
                            setState(() {
                              _resetToOriginal();
                              _isEditMode = false;
                            });
                          } else {
                            setState(() {
                              _isEditMode = true;
                            });
                          }
                        },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.22),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    _isEditMode ? 'Cancel' : 'Edit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          _isEditMode ? FontWeight.w600 : FontWeight.w700,
                      color: _isEditMode
                          ? const Color.fromRGBO(255, 255, 255, 0.65)
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('General Information', first: true),
                  _buildGeneralInfoCard(),
                  const _SectionLabel('Budget Information'),
                  _buildBudgetCard(),
                  const _SectionLabel('Product Focus'),
                  _buildProductFocusSection(),
                  const _SectionLabel('Moveout Summary'),
                  _buildMoveoutCard(),
                  const _SectionLabel('Other Sales & Deliveries'),
                  _buildOtherSalesCard(),
                  if (_createdBy.isNotEmpty) const SizedBox(height: 12),
                  if (_createdBy.isNotEmpty) _buildCreatedByCard(),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isEditMode
          ? SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  elevation: 8,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  backgroundColor: Colors.transparent,
                  shadowColor: const Color.fromRGBO(107, 33, 200, 0.44),
                ).copyWith(
                  backgroundColor:
                      MaterialStateProperty.all(Colors.transparent),
                ),
                child: Ink(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4A2371),
                        Color(0xFF4A2371),
                        Color(0xFF5958B2),
                      ],
                    ),
                  ),
                  child: Center(
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
                            'Update Form',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildGeneralInfoCard() {
    return _FormCard(
      child: Column(
        children: [
          _twoColRow(
            _field('Agronomist', _agronomistCtrl),
            _field('Area', _areaCtrl),
          ),
          _twoColRow(
            _field('Crop Focus', _cropFocusCtrl),
            _field('Activity Type', _activityTypeCtrl),
          ),
          _field('Planned Activity Location', _plannedLocationCtrl),
          _field('Actual Activity Location', _actualLocationCtrl),
          _twoColRow(
            _field('Planned Activity Date', _plannedActivityDateCtrl),
            _field('Actual Activity Date', _actualActivityDateCtrl),
          ),
          _twoColRow(
            _field('Target No. of Attendees', _targetAttendeesCtrl,
                keyboardType: TextInputType.number),
            _field('Actual No. of Attendees', _actualAttendeesCtrl,
                keyboardType: TextInputType.number),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard() {
    return _FormCard(
      child: Column(
        children: [
          _pesoField('Budget per Attendee', _budgetPerAttendeeCtrl),
          _pesoField('Standard Budget Requirement',
              _standardBudgetRequirementCtrl),
          _pesoField('Additional Budget Request',
              _additionalBudgetRequestCtrl),
          _field('Justification for Additional Budget',
              _justificationForAdditionalBudgetCtrl,
              maxLines: 3),
          _twoColRow(
            _pesoField('Total Budget Requested', _totalBudgetRequestedCtrl),
            _pesoField('Actual Budget Spent', _actualBudgetSpentCtrl),
          ),
        ],
      ),
    );
  }

  Widget _buildProductFocusSection() {
    if (_productFocusControllers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          'No product focus entries recorded.',
          style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
        ),
      );
    }

    return Column(
      children: _productFocusControllers.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        final isOpen = _openPF.contains(index);
        final title =
            row.productFocus.text.isNotEmpty ? row.productFocus.text : 'Product Focus ${index + 1}';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Card(
            color: Colors.white,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            shadowColor: Colors.black.withOpacity(0.06),
            child: Column(
              children: [
                InkWell(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  onTap: () {
                    setState(() {
                      if (isOpen) {
                        _openPF.remove(index);
                      } else {
                        _openPF.add(index);
                      }
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.fromRGBO(107, 33, 200, 0.07),
                          Color.fromRGBO(156, 64, 255, 0.03),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFF4A2371),
                                Color(0xFF5958B2),
                              ],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5958B2),
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: isOpen ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.expand_more,
                            size: 20,
                            color: Color(0xFF5958B2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: Column(
                      children: [
                        _field('Product Focus', row.productFocus),
                        _twoColRow(
                          _field('Target Moveout Volume',
                              row.targetMoveoutVolume,
                              keyboardType: TextInputType.number),
                          _field('Actual Moveout Volume',
                              row.actualMoveoutVolume,
                              keyboardType: TextInputType.number),
                        ),
                        _twoColRow(
                          _pesoField('Target Moveout Value PF',
                              row.targetMoveoutValuePf),
                          _pesoField('Actual Moveout Value PF',
                              row.actualMoveoutValuePf),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMoveoutCard() {
    return _FormCard(
      child: Column(
        children: [
          _twoColRow(
            _pesoField('Total Target Moveout Value',
                _totalTargetMoveoutValueCtrl),
            _pesoField(
                'Total Actual Moveout Value', _totalActualMoveoutValueCtrl),
          ),
          _field('Remarks on Activity Output',
              _remarksOnActivityOutputCtrl,
              maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildOtherSalesCard() {
    return _FormCard(
      child: Column(
        children: [
          _twoColRow(
            _field('Other Products Sold / Booked',
                _otherProductsSoldOrBookedCtrl,
                maxLines: 2),
            _field('Products Delivered to Dealers',
                _productsDeliveredToDealersCtrl,
                maxLines: 2),
          ),
          _twoColRow(
            _pesoField('Value of Other Products',
                _valueOfOtherProductsSoldOrBookedCtrl),
            _pesoField('Value of Delivered Products',
                _valueOfProductsDeliveredToDealersCtrl),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatedByCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.person, size: 20, color: Color(0xFF5958B2)),
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
    );
  }

  // Helpers

  Widget _twoColRow(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [
              left,
              right,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 10),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    if (!_isEditMode) {
      final value = controller.text.trim();
      if (value.isEmpty) return const SizedBox.shrink();
      return _readonlyField(label, value);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2B2B2B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color.fromRGBO(107, 33, 200, 0.04),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: Color.fromRGBO(107, 33, 200, 0.25),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: Color.fromRGBO(107, 33, 200, 0.25),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide:
                    const BorderSide(color: Color(0xFF5958B2), width: 1.6),
              ),
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF000000),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pesoField(String label, TextEditingController controller) {
    if (!_isEditMode) {
      final value = controller.text.trim();
      if (value.isEmpty) return const SizedBox.shrink();
      return _readonlyField(label, '₱$value');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2B2B2B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color.fromRGBO(107, 33, 200, 0.04),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              prefixText: '₱ ',
              prefixStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2B2B2B),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: Color.fromRGBO(107, 33, 200, 0.25),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: Color.fromRGBO(107, 33, 200, 0.25),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide:
                    const BorderSide(color: Color(0xFF5958B2), width: 1.6),
              ),
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF000000),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readonlyField(String label, String value) {
    final isPeso = value.startsWith('₱');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2B2B2B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F7FD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE9E3F5)),
            ),
            child: isPeso
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '₱',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        value.substring(1).trim(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF000000),
                        ),
                      ),
                    ],
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF000000),
                    ),
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

class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFFFFF),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      shadowColor: Colors.black.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: child,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool first;

  const _SectionLabel(this.text, {Key? key, this.first = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, first ? 4 : 20, 0, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF5958B2),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
