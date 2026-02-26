import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeductionInputForCallDetailPage extends StatefulWidget {
  final String doctorId;
  final String scheduledVisitId;

  const DeductionInputForCallDetailPage({
    Key? key,
    required this.doctorId,
    required this.scheduledVisitId,
  }) : super(key: key);

  @override
  State<DeductionInputForCallDetailPage> createState() =>
      _DeductionInputForCallDetailPageState();
}

class _DeductionInputForCallDetailPageState
    extends State<DeductionInputForCallDetailPage> {
  bool _halfDay = false;
  final TextEditingController _deductionController = TextEditingController();
  bool _isSaving = false;
  String? emailKey;

  @override
  void initState() {
    super.initState();
    _loadEmailKey();
  }

  Future<void> _loadEmailKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    setState(() {
      emailKey = userEmail.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
    });
  }

  Future<void> _saveDeduction() async {
    if (emailKey == null || emailKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User credentials not loaded.")),
      );
      return;
    }

    final deductionText = _deductionController.text.trim();
    if (deductionText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a deduction reason")),
      );
      return;
    }

    setState(() => _isSaving = true);

    await FirebaseFirestore.instance
        .collection('flowDB')
        .doc('users')
        .collection(emailKey!)
        .doc('doctors')
        .collection('doctors')
        .doc(widget.doctorId)
        .collection('scheduledVisits')
        .doc(widget.scheduledVisitId)
        .collection('targetDeductions')
        .add({
      'halfDay': _halfDay,
      // Store the user's free‑text input as the main option/reason
      'option': deductionText,
      // Keep extraInput for compatibility, but same content (or you can leave it empty if not needed)
      'extraInput': deductionText,
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() => _isSaving = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Call Target Deduction"),
        backgroundColor: Colors.red.shade600,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      "Half-Day?",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Spacer(),
                    Switch(
                      value: _halfDay,
                      activeColor: Colors.red.shade600,
                      onChanged: (val) => setState(() => _halfDay = val),
                    ),
                    Text(
                      _halfDay ? "Yes" : "No",
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Text(
                  "Deduction Reason:",
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _deductionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Enter deduction reason here",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 24),
                if (_isSaving) Center(child: CircularProgressIndicator()),
                SizedBox(height: 90),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                color: Colors.white.withOpacity(0.96),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade400),
                        onPressed: _isSaving
                            ? null
                            : () {
                                Navigator.pop(context);
                              },
                        child:
                            Text("Cancel", style: TextStyle(color: Colors.black)),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600),
                        onPressed: _isSaving ? null : _saveDeduction,
                        child:
                            Text("Done", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
