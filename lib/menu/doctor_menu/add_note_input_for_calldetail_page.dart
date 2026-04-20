import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AddNoteInputForCallDetailPage extends StatefulWidget {
  final String doctorId;
  final String scheduledVisitId;

  const AddNoteInputForCallDetailPage({
    Key? key,
    required this.doctorId,
    required this.scheduledVisitId,
  }) : super(key: key);

  @override
  State<AddNoteInputForCallDetailPage> createState() =>
      _AddNoteInputForCallDetailPageState();
}

class _AddNoteInputForCallDetailPageState
    extends State<AddNoteInputForCallDetailPage> {
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  String? _userId; // MR id like MR00001

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    setState(() {
      _userId = userId.isEmpty ? null : userId;
    });
  }

  /// Document ID format: yyyyMMddhhmmAM/PM
  /// Example: 202604171230PM (April 17, 2026 12:30 PM)
  String _docIdForNow() {
    final dt = DateTime.now();

    final datePart = DateFormat('yyyyMMdd').format(dt);     // 20260417
    final timePart = DateFormat('hhmm').format(dt);         // 1230
    final amPmPart = DateFormat('a').format(dt);            // AM or PM

    return "$datePart$timePart$amPmPart";                   // 202604171230PM
  }

  /// Human-readable time: h:mm a (e.g., 1:05 PM)
  String _displayTimeForNow() {
    final dt = DateTime.now();
    return DateFormat('h:mm a').format(dt); // 12‑hour with AM/PM [web:139]
  }

  /// Root collection for the current user's doctors
  /// /DaloyClients/IVA/Users/{_userId}/Doctor
  CollectionReference<Map<String, dynamic>> _doctorRoot() {
    if (_userId == null || _userId!.isEmpty) {
      // Dummy path while loading; guarded before writes.
      return FirebaseFirestore.instance
          .collection('DaloyClients')
          .doc('IVA')
          .collection('Users')
          .doc('_DUMMY')
          .collection('Doctor');
    }

    return FirebaseFirestore.instance
        .collection('DaloyClients')
        .doc('IVA')
        .collection('Users')
        .doc(_userId)
        .collection('Doctor');
  }

  Future<void> _saveNote() async {
    if (_userId == null || _userId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User credentials not loaded.")),
      );
      return;
    }

    final text = _noteController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a note")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final noteDocId = _docIdForNow();
      final timeDisplay = _displayTimeForNow();

      // Path:
      // /DaloyClients/IVA/Users/{userId}/Doctor/{doctorId}/CallNotes/{noteDocId}
      // Note: scheduledVisitId is stored as a field to keep the linkage.
      await _doctorRoot()
          .doc(widget.doctorId)
          .collection('CallNotes')
          .doc(noteDocId)
          .set({
        'note': text,
        'timestamp': FieldValue.serverTimestamp(),
        'timeDisplay': timeDisplay, // e.g., "1:05 PM"
        'scheduledVisitId': widget.scheduledVisitId,
        'doctorId': widget.doctorId,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save note: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUserLoaded = _userId != null && _userId!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pre-Call Plan"),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (!isUserLoaded)
              const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Loading user information...",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextField(
              controller: _noteController,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Enter your plan notes",
                hintText:
                    "Discussion points, questions, things to bring, etc...",
              ),
            ),
            const SizedBox(height: 28),
            if (_isSaving)
              const Center(child: CircularProgressIndicator()),
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
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    onPressed: isUserLoaded ? _saveNote : null,
                    child: const Text(
                      "Done",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}