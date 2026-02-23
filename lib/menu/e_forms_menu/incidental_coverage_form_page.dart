import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IncidentalCoverageFormPage extends StatefulWidget {
  final Map<String, dynamic>? formData;
  final bool readonly;
  IncidentalCoverageFormPage({this.formData, this.readonly = false});

  @override
  _IncidentalCoverageFormPageState createState() => _IncidentalCoverageFormPageState();
}

class _IncidentalCoverageFormPageState extends State<IncidentalCoverageFormPage> {
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
            "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.readonly
            ? "Incidental Coverage Details"
            : "Incidental Coverage Form"),
        backgroundColor: Color(0xFF5958b2),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 3,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Information",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5958b2))),
                    SizedBox(height: 18),
                    _modernInput("Last Name", lastName, (val) => setState(() => lastName = val)),
                    _modernInput("First Name", firstName, (val) => setState(() => firstName = val)),
                    _modernInput("Middle Name", middleName, (val) => setState(() => middleName = val)),
                    _modernInput("Specialty", specialty, (val) => setState(() => specialty = val)),
                    _modernInput("Location/Farm Name", hospitalPharmacyName, (val) => setState(() => hospitalPharmacyName = val)),
                    SizedBox(height: 18),
                    Text("Date of Cover"),
                    SizedBox(height: 4),
                    TextField(
                      controller: dateController,
                      style: TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        suffixIcon: Icon(Icons.calendar_today_outlined,
                            color: Colors.cyan.shade600),
                        filled: true,
                        fillColor: Colors.cyan.shade50,
                      ),
                      readOnly: true,
                      enabled: !widget.readonly,
                      onTap: () => _selectDate(context),
                    ),
                    SizedBox(height: 18),
                    _modernMultilineInput(
                        "Pre-Call Notes", preCallNotes, (val) => setState(() => preCallNotes = val)),
                    _modernMultilineInput(
                        "Post-Call Notes", postCallNotes, (val) => setState(() => postCallNotes = val)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Card(
              elevation: 3,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            // Signature Section
              // child: Padding(
              //   padding: const EdgeInsets.all(18.0),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       Text("Signature",
              //           textAlign: TextAlign.center,
              //           style: TextStyle(
              //               fontSize: 20,
              //               fontWeight: FontWeight.bold,
              //               color: Color(0xFF5958b2))),
              //       SizedBox(height: 14),
              //       Container(
              //         height: 120,
              //         decoration: BoxDecoration(
              //           border: Border.all(color: Colors.grey.shade300),
              //           borderRadius: BorderRadius.circular(13),
              //           color: Colors.grey.shade100,
              //         ),
              //         child: Center(
              //             child: Text(
              //                 widget.readonly
              //                     ? "Signature Pad (Read-only)"
              //                     : "Signature Pad",
              //                 style: TextStyle(color: Colors.grey))),
              //       ),
              //       // Buttons moved to persistentFooterButtons, so nothing here
              //     ],
              //   ),
              // ),
            
            
            ),
            SizedBox(height: 80), // space so content doesn't hide behind footer
          ],
        ),
      ),

      // FLOATING/CENTERED CLEAR & SUBMIT BUTTONS
      persistentFooterButtons: !widget.readonly
          ? [
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
                            borderRadius: BorderRadius.circular(12)),
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
                        backgroundColor: Color(0xFF5958b2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
            ]
          : null,
    );
  }

  Widget _modernInput(
      String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: TextField(
        enabled: !widget.readonly,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          filled: true,
          fillColor: Colors.cyan.shade50,
        ),
        onChanged: onChanged,
        controller: TextEditingController.fromValue(
          TextEditingValue(
              text: value, selection: TextSelection.collapsed(offset: value.length)),
        ),
        style: TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _modernMultilineInput(
      String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: TextField(
        maxLines: 3,
        enabled: !widget.readonly,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          filled: true,
          fillColor: Colors.cyan.shade50,
        ),
        onChanged: onChanged,
        controller: TextEditingController.fromValue(
          TextEditingValue(
              text: value, selection: TextSelection.collapsed(offset: value.length)),
        ),
        style: TextStyle(fontSize: 16),
      ),
    );
  }
}
