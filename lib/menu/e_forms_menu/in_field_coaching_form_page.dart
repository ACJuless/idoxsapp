import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'abr_form_page.dart';


class InFieldCoachingFormPage extends StatefulWidget {
  @override
  _InFieldCoachingFormPageState createState() =>
      _InFieldCoachingFormPageState();
}


class _InFieldCoachingFormPageState extends State<InFieldCoachingFormPage> {
  static const List<String> evaluatorNames = [
    "---",
    "ANTONIO S. ADRIANO",
    "KITCHON EDWIN TEVAR",
    "PANINGBATAN ROSE ANN REYES",
    "QUINDAO EDNA HATOL",
    "VICTOR MARIA R. CHUMACERA",
  ];


  static const Map<String, String> evaluatorToPosition = {
    "ANTONIO S. ADRIANO": "District Sales Manager - Consumer",
    "KITCHON EDWIN TEVAR": "District Manager",
    "PANINGBATAN ROSE ANN REYES": "District Sales Manager",
    "QUINDAO EDNA HATOL": "District Sales Manager",
    "VICTOR MARIA R. CHUMACERA": "National Sales Manager",
  };


  String selectedEvaluator = evaluatorNames.first;
  String evaluatorPosition = '';
  DateTime date = DateTime.now();
  String medrepName = '';
  String selectedMdName = "SELECT";
  String improvementComment = '';
  List<int?> ratings = List.filled(9, null);


  List<String> questionTexts = [
    "Key Message Delivery",
    "Key Value Delivery",
    "Objective Delivery",
    "Result Delivery",
    "Conclusion Delivery",
    "Attractive Selling Skill",
    "Closing Statement",
    "Prescription Deal",
    "Relationship Capital",
  ];


  List<String> ratingLabels = [
    "Unsatisfactory",
    "Needs Improvement",
    "Satisfactory",
    "Good",
    "Excellent"
  ];


  final TextEditingController dateController = TextEditingController();


  @override
  void initState() {
    super.initState();
    dateController.text =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }


  Future<String> getSanitizedUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    return userEmail.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_');
  }


  void _clearForm() {
    setState(() {
      selectedEvaluator = evaluatorNames.first;
      evaluatorPosition = '';
      date = DateTime.now();
      dateController.text =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      medrepName = '';
      selectedMdName = "SELECT";
      improvementComment = '';
      ratings = List.filled(9, null);
    });
  }


  Future<void> _submitForm() async {
    // basic validation
    if (selectedEvaluator == "---") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please select a valid evaluator"),
        ),
      );
      return;
    }


    if (selectedMdName == "SELECT") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please select a valid MD"),
        ),
      );
      return;
    }


    // make sure all ratings are filled in (optional but recommended)
    if (ratings.any((r) => r == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please complete all ratings before submitting"),
        ),
      );
      return;
    }


    try {
      final userKey = await getSanitizedUserEmail();


      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(userKey)
          .doc('coaching_forms')
          .collection('coaching_forms')
          .add({
        'evaluator': selectedEvaluator,
        'position': evaluatorPosition,
        'date': dateController.text,
        'medrepName': medrepName,
        'mdName': selectedMdName,
        'improvementComment': improvementComment,
        'ratings': ratings,
        'timestamp': DateTime.now(),
      });


      // optional: show confirmation before closing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("In-Field Coaching Form submitted successfully"),
        ),
      );


      Navigator.of(context).pop();
    } catch (e) {
      // handle Firestore errors gracefully
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to submit form. Please try again."),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("In-Field Coaching Form"),
        backgroundColor: Color(0xFF5958b2),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
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
                    Text(
                      "Evaluator Details",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5958b2),
                      ),
                    ),
                    SizedBox(height: 18),
                    Text("Name of Evaluator"),
                    SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedEvaluator,
                      items: evaluatorNames
                          .map(
                            (name) => DropdownMenuItem<String>(
                              value: name,
                              enabled: name != "---",
                              child: Text(name),
                            ),
                          )
                          .toList(),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.cyan.shade50,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectedEvaluator = value ?? "---";
                          evaluatorPosition =
                              evaluatorToPosition[selectedEvaluator] ?? "";
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    Text("Position"),
                    SizedBox(height: 4),
                    TextField(
                      controller:
                          TextEditingController(text: evaluatorPosition),
                      enabled: false,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text("Date"),
                    SizedBox(height: 4),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    SizedBox(height: 14),
                    SizedBox(height: 12),
                    Text("Farmer Name"),
                    SizedBox(height: 4),
                    FutureBuilder<String>(
                      future: getSanitizedUserEmail(),
                      builder: (context, emailSnapshot) {
                        if (!emailSnapshot.hasData) {
                          return DropdownButtonFormField<String>(
                            value: "SELECT",
                            items: [
                              DropdownMenuItem(
                                value: "SELECT",
                                child: Text("Loading..."),
                              ),
                            ],
                            onChanged: null,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.cyan.shade50,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                          );
                        }


                        final emailKey = emailSnapshot.data!;
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('flowDB')
                              .doc('users')
                              .collection(emailKey)
                              .doc('doctors')
                              .collection('doctors')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return DropdownButtonFormField<String>(
                                value: "SELECT",
                                items: [
                                  DropdownMenuItem(
                                    value: "SELECT",
                                    child: Text("Loading..."),
                                  ),
                                ],
                                onChanged: null,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.cyan.shade50,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                              );
                            }


                            final List<String> names = ["SELECT"];
                            for (final d in snapshot.data!.docs) {
                              final dat =
                                  d.data() as Map<String, dynamic>;
                              names.add(
                                "${dat['lastName'] ?? ""}, ${dat['firstName'] ?? ""}"
                                    .trim(),
                              );
                            }


                            return DropdownButtonFormField<String>(
                              value: names.contains(selectedMdName)
                                  ? selectedMdName
                                  : "SELECT",
                              items: names
                                  .map(
                                    (md) => DropdownMenuItem<String>(
                                      value: md,
                                      child: Text(md),
                                    ),
                                  )
                                  .toList(),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.cyan.shade50,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  selectedMdName = value ?? "SELECT";
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
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
                    Text(
                      "Tick the appropriate rating",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyan.shade900,
                      ),
                    ),
                    SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(
                            label: Text(
                              "Question",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...ratingLabels.map(
                            (lbl) => DataColumn(
                              label: Text(lbl),
                            ),
                          ),
                        ],
                        rows: List.generate(questionTexts.length, (qIdx) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  "${qIdx + 1}. ${questionTexts[qIdx]}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              ...List.generate(ratingLabels.length, (rIdx) {
                                return DataCell(
                                  Center(
                                    child: Radio<int>(
                                      value: rIdx,
                                      groupValue: ratings[qIdx],
                                      onChanged: (value) {
                                        setState(() {
                                          ratings[qIdx] = value;
                                        });
                                      },
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        }),
                      ),
                    ),
                    SizedBox(height: 20),
                    _modernMultilineInput(
                      "Things to be Improved (Please comment)",
                      (val) {
                        setState(() {
                          improvementComment = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            // Signature section (currently commented out in your code)
            SizedBox(height: 40),
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
                child: Text(
                  "Clear",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),
            SizedBox(
              width: 140,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5958b2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: _submitForm,
                child: Text(
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


  Widget _modernInput(String label, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          filled: true,
          fillColor: Colors.cyan.shade50,
        ),
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 16,
        ),
      ),
    );
  }


  Widget _modernMultilineInput(String label, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: TextField(
        maxLines: 3,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          filled: true,
          fillColor: Colors.cyan.shade50,
        ),
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 16,
        ),
      ),
    );
  }
}

