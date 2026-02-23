import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebviewFormPage extends StatefulWidget {
  const WebviewFormPage({Key? key}) : super(key: key);

  @override
  State<WebviewFormPage> createState() => _WebviewFormPageState();
}

class _WebviewFormPageState extends State<WebviewFormPage> {
  // Example static list for "Form Type" or "Legacy E-Form Name"
  static const List<String> webviewFormTypes = [
    "---",
    "Other Activity Form",
    "Legacy Attendance Form",
    "Legacy SCP Form",
  ];

  String selectedFormType = webviewFormTypes.first;
  DateTime date = DateTime.now();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    dateController.text =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<String> _getSanitizedUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    return userEmail.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_');
  }

  void _clearForm() {
    setState(() {
      selectedFormType = webviewFormTypes.first;
      date = DateTime.now();
      dateController.text =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      titleController.clear();
      descriptionController.clear();
    });
  }

  Future<void> _submitForm() async {
    if (selectedFormType == "---") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a valid Webview Form type"),
        ),
      );
      return;
    }

    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a title for this Webview Form entry"),
        ),
      );
      return;
    }

    if (descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a description or notes"),
        ),
      );
      return;
    }

    try {
      final userKey = await _getSanitizedUserEmail();

      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(userKey)
          .doc('webview_forms')
          .collection('webview_forms')
          .add({
        'formType': selectedFormType,
        'date': dateController.text,
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'timestamp': DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Webview Form entry submitted successfully"),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to submit Webview Form. Please try again."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Webview Form"),
        backgroundColor: const Color(0xFF5958b2),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
                      "Webview Form Details",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5958b2),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text("Form Type"),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedFormType,
                      items: webviewFormTypes
                          .map(
                            (type) => DropdownMenuItem<String>(
                              value: type,
                              enabled: type != "---",
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.cyan.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectedFormType = value ?? webviewFormTypes.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text("Date"),
                    const SizedBox(height: 4),
                    TextField(
                      controller: dateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.cyan.shade50,
                        suffixIcon: Icon(
                          Icons.calendar_today_outlined,
                          color: Colors.cyan.shade600,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _modernInput(
                      "Title / Subject",
                      titleController,
                    ),
                    _modernMultilineInput(
                      "Description / Notes",
                      descriptionController,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      persistentFooterButtons: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 140,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _clearForm,
                child: const Text(
                  "Clear",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 140,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5958b2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: _submitForm,
                child: const Text(
                  "Submit",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _modernInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          filled: true,
          fillColor: Colors.cyan.shade50,
        ),
        style: const TextStyle(
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _modernMultilineInput(
      String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: TextField(
        controller: controller,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          filled: true,
          fillColor: Colors.cyan.shade50,
        ),
        style: const TextStyle(
          fontSize: 16,
        ),
      ),
    );
  }
}
