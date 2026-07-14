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

  String? _userEmail;
  String? _userClientType;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserPrefs();
  }

  Future<void> _loadUserPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    final clientType = prefs.getString('userClientType') ?? 'both';
    final userId = prefs.getString('userId') ?? '';

    setState(() {
      _userEmail = userEmail;
      _userClientType = clientType;
      _userId = userId;
    });
  }

  /// Match TmlViewPage.getClientSegment so all Daloy paths align.
  String _getClientSegment({
    required String userClientType,
    required String userEmail,
  }) {
    if (userClientType == 'farmers') return 'INDOFIL';
    if (userClientType == 'pharma') {
      final lower = userEmail.toLowerCase();
      if (lower.endsWith('@wert.com')) return 'WERT';
      return 'IVA';
    }
    final lower = userEmail.toLowerCase();
    if (lower.endsWith('@indofil.com')) return 'INDOFIL';
    if (lower.endsWith('@wert.com')) return 'WERT';
    if (lower.endsWith('@iva.com')) return 'IVA';
    return 'GENERAL';
  }

  /// /DaloyClients/{segment}/Users/{_userId}/Doctor
  CollectionReference<Map<String, dynamic>> _doctorsCollectionRef() {
    final daloyRoot = FirebaseFirestore.instance.collection('DaloyClients');

    if ((_userId ?? '').isEmpty) {
      return daloyRoot
          .doc('GENERAL')
          .collection('Users')
          .doc('_DUMMY')
          .collection('Doctor');
    }

    final segment = _getClientSegment(
      userClientType: _userClientType ?? '',
      userEmail: _userEmail ?? '',
    );

    return daloyRoot
        .doc(segment)
        .collection('Users')
        .doc(_userId)
        .collection('Doctor');
  }

  /// Visits: /DaloyClients/{segment}/Users/{_userId}/Doctor/{docId}/Visits
  CollectionReference<Map<String, dynamic>> _visitsCollection() {
    return _doctorsCollectionRef().doc(widget.docId).collection('Visits');
  }

  /// Calendar itinerary:
  /// /DaloyClients/{segment}/Users/{_userId}/Calendar/{yyyy-MM}/Days/{d}/Itinerary/{doctorId}
  DocumentReference<Map<String, dynamic>> _calendarItineraryRef(
    DateTime visitDate,
    String doctorId,
  ) {
    final monthId =
        "${visitDate.year}-${visitDate.month.toString().padLeft(2, '0')}";
    final dayId = visitDate.day.toString();

    final daloyRoot = FirebaseFirestore.instance.collection('DaloyClients');
    final segment = _getClientSegment(
      userClientType: _userClientType ?? '',
      userEmail: _userEmail ?? '',
    );

    return daloyRoot
        .doc(segment)
        .collection('Users')
        .doc(_userId)
        .collection('Calendar')
        .doc(monthId)
        .collection('Days')
        .doc(dayId)
        .collection('Itinerary')
        .doc(doctorId);
  }

  /// SampleAllocations:
  /// /DaloyClients/{segment}/Users/{_userId}/Doctor/{doctorId}/SampleAllocations/{yyyyMMdd}
  DocumentReference<Map<String, dynamic>> _sampleAllocationsRefForVisit(
    String doctorId,
    String dateId,
  ) {
    return _doctorsCollectionRef()
        .doc(doctorId)
        .collection('SampleAllocations')
        .doc(dateId);
  }

  /// CallNotes:
  /// /DaloyClients/{segment}/Users/{_userId}/Doctor/{doctorId}/CallNotes/{yyyyMMdd}
  DocumentReference<Map<String, dynamic>> _callNotesRefForVisit(
    String doctorId,
    String dateId,
  ) {
    return _doctorsCollectionRef()
        .doc(doctorId)
        .collection('CallNotes')
        .doc(dateId);
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

  String _formatDisplayDate(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  /// Firestore key format used by TML/Visits: yyyyMMdd
  String _formatScheduledDateKey(DateTime date) =>
      "${date.year.toString().padLeft(4, '0')}"
      "${date.month.toString().padLeft(2, '0')}"
      "${date.day.toString().padLeft(2, '0')}";

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return "${hour == 0 ? 12 : hour}:$minute $period";
  }

  Future<void> _saveVisit() async {
    if ((_userEmail == null || _userEmail!.isEmpty) ||
        (_userClientType == null || _userClientType!.isEmpty) ||
        (_userId == null || _userId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User credentials not loaded.")),
      );
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select both a date and time.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final visitDate = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      );

      final dateId = _formatScheduledDateKey(visitDate);
      final timeStr = _formatTime(_selectedTime!);

      final visitsRef = _visitsCollection();
      final visitDocRef = visitsRef.doc(dateId);

      final itineraryRef = _calendarItineraryRef(visitDate, widget.docId);
      final sampleAllocRef = _sampleAllocationsRefForVisit(widget.docId, dateId);
      final callNotesRef = _callNotesRefForVisit(widget.docId, dateId);
      final doctorRef = _doctorsCollectionRef().doc(widget.docId);

      // Create/merge itinerary document
      await itineraryRef.set(
        {
          'doctorId': widget.docId,
          'scheduledDate': dateId,
          'createdAt': FieldValue.serverTimestamp(),
          'DoctorReference': doctorRef,
        },
        SetOptions(merge: true),
      );

      // Visit document with all four references and surprise visit flags
      await visitDocRef.set(
        {
          "scheduledDate": dateId,
          "scheduledTime": timeStr,
          "Visit": true,
          "submitted": false,
          "surprise": true,
          "ItineraryReference": itineraryRef,
          "SampleAllocationsReference": sampleAllocRef,
          "CallNotesReference": callNotesRef,
          "DoctorReference": doctorRef,
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      setState(() => _isSaving = false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save visit: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null ||
        _userId!.isEmpty ||
        _userClientType == null ||
        _userClientType!.isEmpty ||
        _userEmail == null ||
        _userEmail!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Add Surprise Visit"),
          backgroundColor: Colors.red.shade600,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Surprise Visit"),
        backgroundColor: Colors.red.shade600,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                title: const Text("Date"),
                subtitle: Text(
                  _selectedDate != null
                      ? _formatDisplayDate(_selectedDate!)
                      : "Pick a date",
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(context),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text("Time"),
                subtitle: Text(
                  _selectedTime != null
                      ? _formatTime(_selectedTime!)
                      : "Pick a time",
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () => _pickTime(context),
              ),
            ),
            const SizedBox(height: 28),
            if (_isSaving) const Center(child: CircularProgressIndicator()),
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
                      backgroundColor: Colors.red.shade600,
                    ),
                    onPressed: _saveVisit,
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