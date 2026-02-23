import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddVisitPage extends StatefulWidget {
  final String docId; // Firestore doctor document ID (e.g. CS-00001)

  const AddVisitPage({Key? key, required this.docId}) : super(key: key);

  @override
  State<AddVisitPage> createState() => _AddVisitPageState();
}

class _AddVisitPageState extends State<AddVisitPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
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

  Future<void> _pickDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() => _selectedDate = pickedDate);
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() => _selectedTime = pickedTime);
    }
  }

  String _formatDate(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return "${hour == 0 ? 12 : hour}:$minute $period";
  }

  Future<void> _saveVisit() async {
    if (emailKey == null || emailKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User credentials not loaded.")),
      );
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select both a date and time.")),
      );
      return;
    }
    setState(() => _isSaving = true);

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final chosenOnly = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
    final isSurprise = todayOnly == chosenOnly;

    final visitDocId = _formatDate(_selectedDate!);
    await FirebaseFirestore.instance
        .collection('flowDB')
        .doc('users')
        .collection(emailKey!)
        .doc('doctors')
        .collection('doctors')
        .doc(widget.docId)
        .collection('scheduledVisits')
        .doc(visitDocId)
        .set({
          'scheduledDate': visitDocId,
          'scheduledTime': _formatTime(_selectedTime!),
          'timestamp': FieldValue.serverTimestamp(),
          'surprise': isSurprise,
          // Add more visit fields here if needed
        });

    setState(() => _isSaving = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (emailKey == null || emailKey!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Add Visit"),
          backgroundColor: Colors.red.shade600,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Add Visit"),
        backgroundColor: Colors.red.shade600,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                title: Text("Date"),
                subtitle: Text(_selectedDate != null
                    ? _formatDate(_selectedDate!)
                    : "Pick a date"),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _pickDate(context),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: ListTile(
                title: Text("Time"),
                subtitle: Text(_selectedTime != null
                    ? _formatTime(_selectedTime!)
                    : "Pick a time"),
                trailing: Icon(Icons.access_time),
                onTap: () => _pickTime(context),
              ),
            ),
            SizedBox(height: 28),
            if (_isSaving) Center(child: CircularProgressIndicator()),
            if (!_isSaving)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade400,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text("Cancel", style: TextStyle(color: Colors.black)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                    ),
                    onPressed: _saveVisit,
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
