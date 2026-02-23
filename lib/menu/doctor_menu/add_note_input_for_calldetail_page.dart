import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddNoteInputForCallDetailPage extends StatefulWidget {
  final String doctorId;
  final String scheduledVisitId;
  const AddNoteInputForCallDetailPage({
    Key? key,
    required this.doctorId,
    required this.scheduledVisitId,
  }) : super(key: key);

  @override
  State<AddNoteInputForCallDetailPage> createState() => _AddNoteInputForCallDetailPageState();
}

class _AddNoteInputForCallDetailPageState extends State<AddNoteInputForCallDetailPage> {
  final TextEditingController _noteController = TextEditingController();
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

  String _docIdForNow() {
    final dt = DateTime.now();
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}_"
           "${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}${dt.second.toString().padLeft(2, '0')}";
  }

  Future<void> _saveNote() async {
    if (emailKey == null || emailKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User credentials not loaded.")));
      return;
    }
    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please enter a note")));
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
        .collection('callNotes')
        .doc(_docIdForNow())
        .set({
          'note': _noteController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        });
    setState(() => _isSaving = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pre-Call Plan"),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _noteController,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Enter your plan notes",
                hintText: "Discussion points, questions, things to bring, etc...",
              ),
            ),
            SizedBox(height: 28),
            if (_isSaving) Center(child: CircularProgressIndicator()),
            if (!_isSaving)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade400),
                    onPressed: () { Navigator.pop(context); },
                    child: Text("Cancel", style: TextStyle(color: Colors.black)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    onPressed: _saveNote,
                    child: Text("Done", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
