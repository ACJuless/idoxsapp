import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'in_field_coaching_form_page.dart';

// Detail (read-only view of a single coaching form)
class InFieldCoachingFormReadonlyPage extends StatelessWidget {
  final Map<String, dynamic> formData;

  InFieldCoachingFormReadonlyPage({required this.formData});

  final List<String> questionTexts = [
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

  final List<String> ratingLabels = [
    "Unsatisfactory",
    "Needs Improvement",
    "Satisfactory",
    "Good",
    "Excellent",
  ];

  @override
  Widget build(BuildContext context) {
    // ratings stored as List<dynamic> in Firestore
    final List<dynamic>? ratings = formData['ratings'] as List<dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: Text("Coaching Form (Read-only)"),
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
                    _readonlyField("Evaluator", formData["evaluator"] ?? ""),
                    _readonlyField("Position", formData["position"] ?? ""),
                    _readonlyField("Date", formData["date"] ?? ""),
                    // You switched to mdName for the farmer in the form
                    _readonlyField("Farmer Name", formData["mdName"] ?? ""),
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
                      "Ratings",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
                                Text("${qIdx + 1}. ${questionTexts[qIdx]}"),
                              ),
                              ...List.generate(ratingLabels.length, (rIdx) {
                                return DataCell(
                                  Center(
                                    child: Radio<int>(
                                      value: rIdx,
                                      // ratings list contains int indices (0–4)
                                      groupValue: ratings != null &&
                                              qIdx < ratings.length
                                          ? (ratings[qIdx] as int?)
                                          : null,
                                      onChanged: null, // read-only
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
                    _readonlyField(
                      "Things to be Improved",
                      formData["improvementComment"] ?? "",
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readonlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10),
            margin: EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.cyan.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Transactions list page (shows all coaching forms from Firestore)
class InFieldCoachingFormTransactionsPage extends StatefulWidget {
  @override
  State<InFieldCoachingFormTransactionsPage> createState() =>
      _InFieldCoachingFormTransactionsPageState();
}

class _InFieldCoachingFormTransactionsPageState
    extends State<InFieldCoachingFormTransactionsPage> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("In-Field Coaching Form Transactions"),
        backgroundColor: Color(0xFF5958b2),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InFieldCoachingFormPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: userKey.isEmpty
          ? Center(
              child: CircularProgressIndicator(),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('flowDB')
                  .doc('users')
                  .collection(userKey)
                  .doc('coaching_forms')
                  .collection('coaching_forms')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    !snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      "No coaching forms yet. Tap '+' to create a new.",
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => Divider(),
                  itemBuilder: (context, idx) {
                    final QueryDocumentSnapshot doc = docs[idx];
                    final Map<String, dynamic> dat =
                        doc.data() as Map<String, dynamic>;

                    final String evaluator = dat['evaluator'] ?? '';
                    final String position = dat['position'] ?? '';
                    final String date = dat['date'] ?? '';

                    final String title = '$evaluator - $position';

                    return Card(
                      child: ListTile(
                        title: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(date),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InFieldCoachingFormReadonlyPage(
                                formData: dat,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
