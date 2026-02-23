import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CallOffFieldPage extends StatefulWidget {
  final String emailKey;

  const CallOffFieldPage({Key? key, required this.emailKey}) : super(key: key);

  @override
  _CallOffFieldPageState createState() => _CallOffFieldPageState();
}

class _CallOffFieldPageState extends State<CallOffFieldPage> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2010, 1, 1),
      lastDate: DateTime(2050, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitOffField() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a reason')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // For each doctor in the user's doctors collection, update/create that date's scheduled visit
      final doctorsSnap = await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(widget.emailKey)
          .doc('doctors')
          .collection('doctors')
          .get();

      final String dateKey = _dateKey(_selectedDate);

      for (var doc in doctorsSnap.docs) {
        final scheduledDocRef = doc.reference
            .collection('scheduledVisits')
            .doc(dateKey);

        // Ensure the document exists with scheduledDate; if it doesn't,
        // set it with scheduledDate and default flags, then update offField.
        await scheduledDocRef.set({
          'scheduledDate': dateKey,
          'scheduledTime': '',
          'submitted': false,
          'surprise': false,
          'offField': _reasonController.text.trim(),
        }, SetOptions(merge: true));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Off-field call recorded successfully')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting off-field call: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String dateDisplay =
        '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Call Off Field'),
        backgroundColor: Color(0xFF5958b2),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.cyan.shade50,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  suffixIcon: Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.cyan.shade600,
                  ),
                ),
                child: Text(
                  dateDisplay,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Reason',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for off-field call',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.cyan.shade50,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
            ),
            SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitOffField,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5958b2),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Submit',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
