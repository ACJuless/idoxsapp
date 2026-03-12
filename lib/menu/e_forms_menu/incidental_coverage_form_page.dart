import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IncidentalCoverageFormPage extends StatefulWidget {
  final Map<String, dynamic>? formData;
  final bool readonly;
  IncidentalCoverageFormPage({this.formData, this.readonly = false, Key? key})
      : super(key: key);

  @override
  _IncidentalCoverageFormPageState createState() =>
      _IncidentalCoverageFormPageState();
}

class _IncidentalCoverageFormPageState
    extends State<IncidentalCoverageFormPage> {
  late String lastName;
  late String firstName;
  late String middleName;
  late String specialty;
  late String hospitalPharmacyName;
  late DateTime selectedDate;
  late String preCallNotes;
  late String postCallNotes;
  late TextEditingController dateController;

  @override
  void initState() {
    super.initState();
    final d = widget.formData;
    lastName = d?['lastName'] ?? "";
    firstName = d?['firstName'] ?? "";
    middleName = d?['middleName'] ?? "";
    specialty = d?['specialty'] ?? "";
    hospitalPharmacyName = d?['hospitalPharmacyName'] ?? "";
    selectedDate = d?['dateOfCover'] != null
        ? DateTime.tryParse(d!['dateOfCover']) ?? DateTime.now()
        : DateTime.now();
    preCallNotes = d?['preCallNotes'] ?? "";
    postCallNotes = d?['postCallNotes'] ?? "";
    dateController = TextEditingController(
      text:
          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
    );
  }

  Future<String> getSanitizedUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    return userEmail.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_');
  }

  Future<void> _selectDate(BuildContext context) async {
    if (widget.readonly) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        dateController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _resetFields() {
    if (widget.readonly) return;
    setState(() {
      lastName = "";
      firstName = "";
      middleName = "";
      specialty = "";
      hospitalPharmacyName = "";
      selectedDate = DateTime.now();
      dateController.text =
          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
      preCallNotes = "";
      postCallNotes = "";
    });
  }

  Future<void> _submitForm() async {
    if (widget.readonly) return;
    final userKey = await getSanitizedUserEmail();
    await FirebaseFirestore.instance
        .collection('flowDB')
        .doc('users')
        .collection(userKey)
        .doc('inc_cov_forms')
        .collection('inc_cov_forms')
        .add({
      'lastName': lastName,
      'firstName': firstName,
      'middleName': middleName,
      'specialty': specialty,
      'hospitalPharmacyName': hospitalPharmacyName,
      'dateOfCover': dateController.text,
      'preCallNotes': preCallNotes,
      'postCallNotes': postCallNotes,
      'timestamp': FieldValue.serverTimestamp(),
    });
    Navigator.pop(context, true);
  }

  String _displayTitle() {
    final parts = [
      firstName.trim(),
      middleName.trim(),
      lastName.trim(),
    ].where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) {
      return widget.readonly ? 'Incidental Coverage Details' : 'New Form';
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isReadonly = widget.readonly;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F5FF),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: AppBar(
          elevation: 6,
          automaticallyImplyLeading: true,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(22),
              ),
              gradient: LinearGradient(
                colors: [
                  Color(0xFF4A2371),
                  Color(0xFF4A2371),
                  Color(0xFF5958B2),
                ],
                stops: [0, 0.55, 1],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(76, 29, 149, 0.3),
                  blurRadius: 28,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Incidental Coverage',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color.fromRGBO(255, 255, 255, 0.65),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _displayTitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          titleSpacing: 0,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionLabel('Personal Information', first: true),
                _card(
                  Column(
                    children: [
                      isReadonly
                          ? _viewRow('Last Name', lastName)
                          : _editRow(
                              label: 'Last Name',
                              value: lastName,
                              onChanged: (v) =>
                                  setState(() => lastName = v),
                            ),
                      isReadonly
                          ? _viewRow('First Name', firstName)
                          : _editRow(
                              label: 'First Name',
                              value: firstName,
                              onChanged: (v) =>
                                  setState(() => firstName = v),
                            ),
                      isReadonly
                          ? _viewRow('Middle Name', middleName)
                          : _editRow(
                              label: 'Middle Name',
                              value: middleName,
                              onChanged: (v) =>
                                  setState(() => middleName = v),
                            ),
                      isReadonly
                          ? _viewRow('Specialty', specialty)
                          : _editRow(
                              label: 'Specialty',
                              value: specialty,
                              onChanged: (v) =>
                                  setState(() => specialty = v),
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                _sectionLabel('Coverage Details'),
                _card(
                  Column(
                    children: [
                      isReadonly
                          ? _viewRow(
                              'Hospital / Pharmacy Name',
                              hospitalPharmacyName,
                            )
                          : _editRow(
                              label: 'Hospital / Pharmacy Name',
                              value: hospitalPharmacyName,
                              onChanged: (v) =>
                                  setState(() => hospitalPharmacyName = v),
                            ),
                      isReadonly
                          ? _viewRow(
                              'Date of Cover',
                              _formatDateText(dateController.text),
                            )
                          : _dateRow(context),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                _sectionLabel('Call Notes'),
                _card(
                  Column(
                    children: [
                      isReadonly
                          ? _viewRow('Pre-Call Notes', preCallNotes)
                          : _editMultilineRow(
                              label: 'Pre-Call Notes',
                              value: preCallNotes,
                              onChanged: (v) =>
                                  setState(() => preCallNotes = v),
                            ),
                      isReadonly
                          ? _viewRow('Post-Call Notes', postCallNotes)
                          : _editMultilineRow(
                              label: 'Post-Call Notes',
                              value: postCallNotes,
                              onChanged: (v) =>
                                  setState(() => postCallNotes = v),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      persistentFooterButtons: isReadonly
          ? null
          : [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _resetFields,
                      child: const Text(
                        "Clear",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF5958B2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _submitForm,
                      child: const Text(
                        "Submit",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
    );
  }

  Widget _sectionLabel(String text, {bool first = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, first ? 6 : 20, 8, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF5958B2),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _viewRow(String label, String value) {
    final trimmed = value.trim();
    final isEmpty = trimmed.isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF0EBF9),
            width: 1,
          ),
        ),
      ),
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
          Text(
            isEmpty ? 'No data' : trimmed,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: isEmpty ? const Color(0xFF9CA3AF) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _editRow({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF0EBF9),
            width: 1,
          ),
        ),
      ),
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
          TextField(
            enabled: !widget.readonly,
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              filled: true,
              fillColor: const Color.fromRGBO(107, 33, 200, 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: Color.fromRGBO(107, 33, 200, 0.25),
                  width: 1.5,
                ),
              ),
            ),
            controller: TextEditingController.fromValue(
              TextEditingValue(
                text: value,
                selection:
                    TextSelection.collapsed(offset: value.length),
              ),
            ),
            onChanged: onChanged,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _editMultilineRow({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF0EBF9),
            width: 1,
          ),
        ),
      ),
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
          TextField(
            enabled: !widget.readonly,
            maxLines: 3,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              filled: true,
              fillColor: const Color.fromRGBO(107, 33, 200, 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: Color.fromRGBO(107, 33, 200, 0.25),
                  width: 1.5,
                ),
              ),
            ),
            controller: TextEditingController.fromValue(
              TextEditingValue(
                text: value,
                selection:
                    TextSelection.collapsed(offset: value.length),
              ),
            ),
            onChanged: onChanged,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _dateRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF0EBF9),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DATE OF COVER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2B2B2B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: dateController,
            readOnly: true,
            enabled: !widget.readonly,
            onTap: () => _selectDate(context),
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              filled: true,
              fillColor: const Color.fromRGBO(107, 33, 200, 0.04),
              suffixIcon: const Icon(
                Icons.calendar_today_outlined,
                color: Color(0xFF5958B2),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: Color.fromRGBO(107, 33, 200, 0.25),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateText(String raw) {
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      return "${_monthName(d.month)} ${d.day.toString().padLeft(2, '0')}, ${d.year}";
    } catch (_) {
      return raw;
    }
  }

  String _monthName(int m) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return (m >= 1 && m <= 12) ? names[m] : '';
  }
}
