import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_doctor_page.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class TmlViewPage extends StatefulWidget {
  @override
  State<TmlViewPage> createState() => _TmlViewPageState();
}

class _TmlViewPageState extends State<TmlViewPage> {
  bool editMode = false;
  bool isSaving = false;
  bool isOpeningScheduleDialog = false;
  int? selectedDoctorIdx;
  String? selectedDoctorId;
  Map<String, dynamic>? selectedDoctorRowData;

  static const double boxSize = 26.0;
  static const double minMdNameColWidth = 160;
  static const double minWeekColWidth = 210;
  static const double rowHeight = 62.0;

  // doctorId -> 5-element list of "Su","M","T","W","Th","F","Sa" or ""
  Map<String, List<String>> weekSelections = {};
  // doctorId -> {weekIndex(0–4) : "HH:mm"}
  Map<String, Map<int, String>> scheduledTimes = {};

  final ScrollController _leftController = ScrollController();
  final ScrollController _rightController = ScrollController();
  String userEmail = '';
  String emailKey = '';
  String _userClientType = '';
  String _userId = ''; // MR id (MR00001) from SharedPreferences

  // Keep current month/year and month grid so date calculations are consistent
  late DateTime _currentMonthBase;
  late List<List<DateTime?>> _monthGrid;

  @override
  void initState() {
    super.initState();
    _initSyncedScroll();
    _initCurrentMonth();
    _loadUserPrefs();
  }

  void _initCurrentMonth() {
    final now = DateTime.now();
    _currentMonthBase = DateTime(now.year, now.month, 1);
    _monthGrid = _buildMonthGrid(_currentMonthBase.year, _currentMonthBase.month);
  }

  void _initSyncedScroll() {
    _leftController.addListener(() {
      if (_rightController.hasClients &&
          _rightController.offset != _leftController.offset) {
        _rightController.jumpTo(_leftController.offset);
      }
    });
    _rightController.addListener(() {
      if (_leftController.hasClients &&
          _rightController.offset != _rightController.offset) {
        _leftController.jumpTo(_rightController.offset);
      }
    });
  }

  Future<void> _loadUserPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString('userEmail') ?? '';
    final clientType = prefs.getString('userClientType') ?? 'both';
    final userId = prefs.getString('userId') ?? ''; // MR00001, etc.

    setState(() {
      emailKey = userEmail.replaceAll(RegExp(r'[.#$\\\[\]/]'), '_');
      _userClientType = clientType;
      _userId = userId;
    });
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  /// Doctors: /DaloyClients/IVA/Users/{_userId}/Doctor
  CollectionReference<Map<String, dynamic>> _doctorsCollectionRef() {
    if (_userId.isEmpty) {
      // Dummy path while loading; UI shows loader until _userId is set
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

  /// Visits: /DaloyClients/IVA/Users/{_userId}/Doctor/{docId}/Visits/{yyyyMMdd}
  CollectionReference<Map<String, dynamic>> _visitsRootForDoctor(
    String docId,
  ) {
    return _doctorsCollectionRef().doc(docId).collection('Visits');
  }

  /// Calendar itinerary:
  /// /DaloyClients/IVA/Users/{_userId}/Calendar/{yyyy-MM}/Days/{d}/Itinerary/{doctorId}
  DocumentReference<Map<String, dynamic>> _calendarItineraryRef(
    DateTime visitDate,
    String doctorId,
  ) {
    final monthId =
        "${visitDate.year}-${visitDate.month.toString().padLeft(2, '0')}";
    final dayId = visitDate.day.toString(); // "6" for 6th of month

    return FirebaseFirestore.instance
        .collection('DaloyClients')
        .doc('IVA')
        .collection('Users')
        .doc(_userId)
        .collection('Calendar')
        .doc(monthId)
        .collection('Days')
        .doc(dayId)
        .collection('Itinerary')
        .doc(doctorId);
  }

  /// SampleAllocations reference:
  /// /DaloyClients/IVA/Users/{_userId}/Doctor/{doctorId}/SampleAllocations/{yyyyMMdd}
  DocumentReference<Map<String, dynamic>> _sampleAllocationsRefForVisit(
    String doctorId,
    String dateId,
  ) {
    return _doctorsCollectionRef()
        .doc(doctorId)
        .collection('SampleAllocations')
        .doc(dateId);
  }

  /// CallNotes reference:
  /// /DaloyClients/IVA/Users/{_userId}/Doctor/{doctorId}/CallNotes/{yyyyMMdd}
  DocumentReference<Map<String, dynamic>> _callNotesRefForVisit(
    String doctorId,
    String dateId,
  ) {
    return _doctorsCollectionRef()
        .doc(doctorId)
        .collection('CallNotes')
        .doc(dateId);
  }

  void _goToAddDoctor() async {
    final added = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddDoctorPage()),
    );
    if (added == true) setState(() {});
  }

  void _selectDoctorForEdit(
    Map<String, dynamic> data,
    int idx,
    String docId,
  ) {
    selectedDoctorIdx = idx;
    selectedDoctorRowData = data;
    selectedDoctorId = docId;

    if (!weekSelections.containsKey(docId)) {
      weekSelections[docId] = [
        for (int w = 1; w <= 5; w++) (data['week_$w'] ?? "").toString(),
      ];
    }
    if (!scheduledTimes.containsKey(docId)) {
      scheduledTimes[docId] = {for (int w = 0; w < 5; w++) w: ""};
    }
  }

  void _selectDoctorForDetail(
    Map<String, dynamic> data,
    int idx,
    String docId,
  ) {
    setState(() {
      selectedDoctorIdx = idx;
      selectedDoctorRowData = data;
      selectedDoctorId = docId;
    });
  }

  void _handleWeekBoxTap(
    String docId,
    int weekIdx,
    String selectedDay,
  ) {
    final current = weekSelections[docId] ?? ["", "", "", "", ""];
    final updated = List<String>.from(current);
    updated[weekIdx] = updated[weekIdx] == selectedDay ? "" : selectedDay;
    setState(() {
      weekSelections[docId] = updated;
    });
  }

  bool _isExceededFreq(List<String> selected, int freq) {
    final count = selected.where((e) => e.isNotEmpty).length;
    return count > freq;
  }

  /// Update week_1..week_5 for a doctor, then sync that doctor's Visits + Itinerary.
  /// For each week there will be at most one Visits/{yyyyMMdd} entry and one
  /// matching Itinerary doc (linked by ItineraryReference field).
  Future<void> _saveEditedWeeksWithTimes(
    Map<String, dynamic> originalData,
    List<String> editedWeeks,
    String docId,
    Map<int, String> times,
  ) async {
    final doctorRef = _doctorsCollectionRef().doc(docId);

    final Map<String, dynamic> weekUpdate = {};
    for (int i = 0; i < 5; i++) {
      final orig = (originalData['week_${i + 1}'] ?? "").toString();
      final edited = editedWeeks[i];
      if (orig != edited) {
        weekUpdate['week_${i + 1}'] = edited;
      }
    }
    if (weekUpdate.isNotEmpty) {
      await doctorRef.update(weekUpdate);
    }

    await _syncVisitsWithTmlScheduleAndTimes(
      docId,
      originalData,
      editedWeeks,
      times,
    );
  }

  DateTime _startOfWeekSunday(DateTime d) {
    final delta = d.weekday % 7;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: delta));
  }

  bool _isSameCalendarWeek(DateTime a, DateTime b) {
    final sa = _startOfWeekSunday(a);
    final sb = _startOfWeekSunday(b);
    return sa.year == sb.year && sa.month == sb.month && sa.day == sb.day;
  }

  /// Sync week selections into flat Visits/{yyyymmdd} docs AND matching Itinerary docs.
  ///
  /// Behaviour per week index (0–4):
  /// - At most one visit doc in Visits for that calendar week.
  /// - When a new date in that week is selected, any existing visit in that
  ///   calendar week is deleted, and its referenced Itinerary doc (via ItineraryReference)
  ///   is also deleted.
  /// - For the new date, a visit doc is created/merged and an Itinerary doc
  ///   is created/merged, and the visit's "ItineraryReference" field stores the
  ///   DocumentReference to that itinerary doc.
  /// - Additionally, each visit doc stores:
  ///   "SampleAllocationsReference" -> /DaloyClients/IVA/Users/{_userId}/Doctor/{docId}/SampleAllocations/{yyyyMMdd}
  ///   "CallNotesReference" -> /DaloyClients/IVA/Users/{_userId}/Doctor/{docId}/CallNotes/{yyyyMMdd}
  Future<void> _syncVisitsWithTmlScheduleAndTimes(
    String docId,
    Map<String, dynamic> doctorData,
    List<String> weeks,
    Map<int, String> scheduledTimesMap,
  ) async {
    final visitsRootRef = _visitsRootForDoctor(docId);

    final now = _currentMonthBase;
    final year = now.year;
    final month = now.month;

    // 1. Compute the desired date per week from the grid (new UI state)
    final desiredDatePerWeek = <int, DateTime>{};
    for (int w = 0; w < 5; w++) {
      final dayCode = weeks[w];
      if (dayCode.isEmpty) continue;

      final weekRow = _monthGrid[w];
      final weekdayIndex = _dayCodeToGridIndex(dayCode);
      if (weekdayIndex == null) continue;
      final dt = weekRow[weekdayIndex];
      if (dt == null || dt.month != month) continue;
      desiredDatePerWeek[w] = dt;
    }

    // 2. Fetch existing Visits docs for this month to detect duplicates.
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);
    final String startId = DateFormat("yyyyMMdd").format(monthStart);
    final String endId = DateFormat("yyyyMMdd").format(monthEnd);

    final existingSnap = await visitsRootRef
        .where('scheduledDate', isGreaterThanOrEqualTo: startId)
        .where('scheduledDate', isLessThanOrEqualTo: endId)
        .get();

    final existingById = <String, Map<String, dynamic>>{};
    for (final doc in existingSnap.docs) {
      existingById[doc.id] = doc.data();
    }

    DateTime? _parseDateId(String id) {
      try {
        return DateTime.parse(
            "${id.substring(0, 4)}-${id.substring(4, 6)}-${id.substring(6, 8)}");
      } catch (_) {
        return null;
      }
    }

    // 3. For each week, delete any old visit in the same calendar week
    //    but with a different dateId, and also delete its referenced
    //    Itinerary document via the ItineraryReference field.
    for (final entry in desiredDatePerWeek.entries) {
      final newDate = entry.value;
      final newDateId = DateFormat("yyyyMMdd").format(newDate);

      for (final existingEntry in existingById.entries) {
        final existingId = existingEntry.key;
        final existingData = existingEntry.value;

        if (existingId == newDateId) {
          continue;
        }

        final existingDt = _parseDateId(existingId);
        if (existingDt == null) continue;
        if (existingDt.year != year || existingDt.month != month) continue;

        if (_isSameCalendarWeek(existingDt, newDate)) {
          // Delete the visit doc
          await visitsRootRef.doc(existingId).delete();

          // If it has an ItineraryReference to an itinerary doc, delete that too
          final refField = existingData['ItineraryReference'];
          if (refField is DocumentReference) {
            try {
              await refField.delete();
            } catch (e) {
              debugPrint(
                  'Failed to delete itinerary doc via ItineraryReference for $existingId: $e');
            }
          }
        }
      }
    }

    // 4. (Re)create visit docs per week with times and ItineraryReference,
    //    SampleAllocationsReference, CallNotesReference.
    for (int w = 0; w < 5; w++) {
      final dt = desiredDatePerWeek[w];
      if (dt == null) continue;
      final dateId = DateFormat("yyyyMMdd").format(dt);

      final fromUser = (scheduledTimesMap[w] ?? "").toString().trim();
      String? finalTime = fromUser.isNotEmpty ? fromUser : null;

      // Build itinerary document reference for Calendar path
      final itineraryRef = _calendarItineraryRef(dt, docId);

      // Build SampleAllocations and CallNotes references for this visit
      final sampleAllocRef = _sampleAllocationsRefForVisit(docId, dateId);
      final callNotesRef = _callNotesRefForVisit(docId, dateId);

      // Ensure calendar itinerary doc exists/updated (merge to not overwrite).
      await itineraryRef.set(
        {
          'doctorId': docId,
          'scheduledDate': dateId,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final flatData = <String, dynamic>{
        "scheduledDate": dateId,
        "Visit": true,
        "submitted": false,
        "surprise": false,
        "ItineraryReference": itineraryRef, // renamed from "Reference"
        "SampleAllocationsReference": sampleAllocRef,
        "CallNotesReference": callNotesRef,
      };
      if (finalTime != null) {
        flatData["scheduledTime"] = finalTime;
      }
      await visitsRootRef.doc(dateId).set(flatData, SetOptions(merge: true));
    }
  }

  List<int> _getNewVisitWeekIndices(
    List<String> oldWeeks,
    List<String> newWeeks,
  ) {
    final indices = <int>[];
    for (int i = 0; i < 5; i++) {
      final oldVal = oldWeeks[i];
      final newVal = newWeeks[i];
      if (oldVal.isEmpty && newVal.isNotEmpty) {
        indices.add(i);
      }
    }
    return indices;
  }

  Future<void> _autoSetScheduledTimeForVisit({
    required String docId,
    required String dayCode,
    required int weekIndex,
  }) async {
    final base = _currentMonthBase;
    final year = base.year;
    final month = base.month;

    final visitDate = _getDateFromGrid(weekIndex, dayCode, year, month);
    if (visitDate == null) return;

    final dateId = DateFormat("yyyyMMdd").format(visitDate);

    final visitsRootRef = _visitsRootForDoctor(docId);
    final dateDocRef = visitsRootRef.doc(dateId);
    final snap = await dateDocRef.get();

    var existingTime = "";
    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>;
      existingTime = (data['scheduledTime'] ?? "").toString().trim();
    }

    final finalTime = existingTime.isNotEmpty ? existingTime : "09:00";

    // Also wire the ItineraryReference / Calendar doc here in case auto-set runs alone.
    final itineraryRef = _calendarItineraryRef(visitDate, docId);

    // Build SampleAllocations and CallNotes references for this visit
    final sampleAllocRef = _sampleAllocationsRefForVisit(docId, dateId);
    final callNotesRef = _callNotesRefForVisit(docId, dateId);

    await itineraryRef.set(
      {
        'doctorId': docId,
        'scheduledDate': dateId,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await dateDocRef.set(
      {
        "scheduledDate": dateId,
        "scheduledTime": finalTime,
        "Visit": true,
        "submitted": false,
        "surprise": false,
        "ItineraryReference": itineraryRef,
        "SampleAllocationsReference": sampleAllocRef,
        "CallNotesReference": callNotesRef,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _autoSetTimesForNewVisits({
    required String docId,
    required Map<String, dynamic> originalData,
    required List<String> newWeeks,
  }) async {
    final oldWeeks = <String>[
      for (int i = 1; i <= 5; i++) (originalData['week_$i'] ?? "").toString(),
    ];

    final newVisitIndices = _getNewVisitWeekIndices(oldWeeks, newWeeks);

    for (final weekIndex in newVisitIndices) {
      final dayCode = newWeeks[weekIndex];
      if (dayCode.isEmpty) continue;
      await _autoSetScheduledTimeForVisit(
        docId: docId,
        dayCode: dayCode,
        weekIndex: weekIndex,
      );
    }
  }

  Future<List<Map<String, String>>> _getDoctorsForDate(
    String scheduledDateId,
  ) async {
    final doctorsSnap = await _doctorsCollectionRef().get();
    final result = <Map<String, String>>[];

    for (final doc in doctorsSnap.docs) {
      final data = doc.data();
      final lastName = (data['lastName'] ?? '').toString();
      final firstName = (data['firstName'] ?? '').toString();
      final doctorName = "$lastName, $firstName";

      final visitsRootRef = _visitsRootForDoctor(doc.id);
      final dateDocRef = visitsRootRef.doc(scheduledDateId);

      final dateSnap = await dateDocRef.get();
      if (!dateSnap.exists) continue;

      final dateData = dateSnap.data() as Map<String, dynamic>;
      final time = (dateData['scheduledTime'] ?? '').toString().trim();
      if (time.isEmpty) continue;

      result.add({'doctorName': doctorName, 'time': time});
    }

    result.sort((a, b) {
      final t1 = a['time'] ?? '';
      final t2 = b['time'] ?? '';
      final cmpT = t1.compareTo(t2);
      if (cmpT != 0) return cmpT;
      final n1 = a['doctorName'] ?? '';
      final n2 = b['doctorName'] ?? '';
      return n1.compareTo(n2);
    });

    return result;
  }

  Future<Set<int>> _getBookedHoursForDate(String scheduledDateId) async {
    final doctorsList = await _getDoctorsForDate(scheduledDateId);
    final booked = <int>{};
    for (final row in doctorsList) {
      final time = row['time'] ?? '';
      if (time.length >= 2) {
        final hourStr = time.split(':').first;
        final h = int.tryParse(hourStr);
        if (h != null) booked.add(h);
      }
    }
    return booked;
  }

  Future<void> _showHourSlotsDialog({
    required String docId,
    required Map<String, dynamic> doctorData,
    required DateTime visitDate,
    required String dayLabel,
    required int weekIndex,
  }) async {
    final headerDate = DateFormat('MMMM d, yyyy').format(visitDate);
    final scheduledDateId = DateFormat("yyyyMMdd").format(visitDate);

    final visitsRootRef = _visitsRootForDoctor(docId);

    Future<void> saveHour(int hour) async {
      final dateId = scheduledDateId;
      final timeStr = "${hour.toString().padLeft(2, '0')}:00";

      // Ensure calendar itinerary doc exists
      final itineraryRef = _calendarItineraryRef(visitDate, docId);

      // Build SampleAllocations and CallNotes references for this visit
      final sampleAllocRef = _sampleAllocationsRefForVisit(docId, dateId);
      final callNotesRef = _callNotesRefForVisit(docId, dateId);

      await itineraryRef.set(
        {
          'doctorId': docId,
          'scheduledDate': dateId,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await visitsRootRef.doc(dateId).set({
        "scheduledDate": dateId,
        "scheduledTime": timeStr,
        "Visit": true,
        "submitted": false,
        "surprise": false,
        "ItineraryReference": itineraryRef,
        "SampleAllocationsReference": sampleAllocRef,
        "CallNotesReference": callNotesRef,
      }, SetOptions(merge: true));

      setState(() {
        scheduledTimes.putIfAbsent(docId, () => {});
        scheduledTimes[docId]![weekIndex] = timeStr;
      });

      if (mounted) {
        await _showScheduledTimesDialogForDate(dateId);
      }
    }

    final bookedHours = await _getBookedHoursForDate(scheduledDateId);

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF7030f8),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$dayLabel, $headerDate",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Schedule Overview",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        for (int hour = 8; hour <= 17; hour++) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${hour.toString().padLeft(2, '0')}:00",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      bookedHours.contains(hour)
                                          ? "Not available"
                                          : "Available",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: bookedHours.contains(hour)
                                            ? Colors.red
                                            : Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: bookedHours.contains(hour)
                                      ? null
                                      : () async {
                                          await saveHour(hour);
                                          Navigator.of(context).pop();
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: bookedHours.contains(hour)
                                          ? Colors.red
                                          : null,
                                      gradient: bookedHours.contains(hour)
                                          ? null
                                          : const LinearGradient(
                                              colors: [
                                                Color(0xFF8226f9),
                                                Color(0xFF7030f8),
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          bookedHours.contains(hour)
                                              ? Icons.block
                                              : Icons.add,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          bookedHours.contains(hour)
                                              ? "Booked"
                                              : "Schedule",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectTimeForVisit({
    required String docId,
    required Map<String, dynamic> doctorData,
    required int weekIndex,
    required String dayCode,
  }) async {
    final year = _currentMonthBase.year;
    final month = _currentMonthBase.month;

    final visitDate = _getDateFromGrid(weekIndex, dayCode, year, month);
    if (visitDate == null) return;

    final weekdayNames = {
      "Su": "Sunday",
      "M": "Monday",
      "T": "Tuesday",
      "W": "Wednesday",
      "Th": "Thursday",
      "F": "Friday",
      "Sa": "Saturday",
    };
    final dayLabel = weekdayNames[dayCode] ?? dayCode;

    setState(() => isOpeningScheduleDialog = true);
    try {
      await _showHourSlotsDialog(
        docId: docId,
        doctorData: doctorData,
        visitDate: visitDate,
        dayLabel: dayLabel,
        weekIndex: weekIndex,
      );
    } finally {
      if (mounted) {
        setState(() => isOpeningScheduleDialog = false);
      }
    }
  }

  Future<void> _showScheduledTimesDialogForDate(
    String scheduledDateId,
  ) async {
    final year = int.parse(scheduledDateId.substring(0, 4));
    final month = int.parse(scheduledDateId.substring(4, 6));
    final day = int.parse(scheduledDateId.substring(6, 8));
    final dateObj = DateTime(year, month, day);
    final headerDate = DateFormat('MMMM d, yyyy').format(dateObj);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Scheduled Times"),
              const SizedBox(height: 4),
              Text(
                headerDate,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: FutureBuilder<List<Map<String, String>>>(
              future: _getDoctorsForDate(scheduledDateId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const Text("No scheduled times for this date.");
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final row = items[index];
                    final doctorName = row['doctorName'] ?? '';
                    final time = row['time'] ?? '';
                    return ListTile(
                      dense: true,
                      title: Text(
                        doctorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        time,
                        style: const TextStyle(
                          fontSize: 13,
                        ),
                      ),
                      leading: const Icon(
                        Icons.person,
                        size: 20,
                        color: Colors.deepPurple,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  List<List<DateTime?>> _buildMonthGrid(int year, int month) {
    final firstOfMonth = DateTime(year, month, 1);
    final firstWeekday = firstOfMonth.weekday; // Mon=1..Sun=7
    final daysBackToSunday = firstWeekday % 7;
    final gridStart = firstOfMonth.subtract(Duration(days: daysBackToSunday));

    final lastOfMonth = DateTime(year, month + 1, 0);
    final totalDaysSpan = lastOfMonth.difference(gridStart).inDays + 1;
    final totalWeeks = (totalDaysSpan / 7.0).ceil();

    var weeks = <List<DateTime?>>[];
    var cursor = gridStart;
    for (int w = 0; w < totalWeeks; w++) {
      final row = <DateTime?>[];
      for (int d = 0; d < 7; d++) {
        if (cursor.month == month) {
          row.add(cursor);
        } else {
          row.add(null);
        }
        cursor = cursor.add(const Duration(days: 1));
      }
      weeks.add(row);
    }

    while (weeks.length < 5) {
      weeks.add(List<DateTime?>.filled(7, null));
    }
    if (weeks.length > 5) {
      weeks = weeks.sublist(0, 5);
    }
    return weeks;
  }

  int? _dayCodeToGridIndex(String dayCode) {
    const weekDays = ["Su", "M", "T", "W", "Th", "F", "Sa"];
    final idx = weekDays.indexOf(dayCode);
    if (idx < 0) return null;
    return idx;
  }

  DateTime? _getDateFromGrid(int weekIndex, String dayCode, int year, int month) {
    if (weekIndex < 0 || weekIndex >= _monthGrid.length) return null;
    final weekRow = _monthGrid[weekIndex];
    final col = _dayCodeToGridIndex(dayCode);
    if (col == null || col < 0 || col >= weekRow.length) return null;
    final dt = weekRow[col];
    if (dt == null || dt.month != month || dt.year != year) return null;
    return dt;
  }

  LinearGradient get _purpleRowGradient => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFF8226f9),
          Color(0xFF772df8),
          Color(0xFF7030f8),
          Color(0xFF6035f7),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final mdNameColWidth = minMdNameColWidth;
    final availableWidth = screenWidth - mdNameColWidth;
    final weekColWidth =
        (availableWidth / 5 > minWeekColWidth) ? availableWidth / 5 : minWeekColWidth;
    final tableWidth = weekColWidth * 5 + 4;

    final now = _currentMonthBase;
    final monthYearLabel = DateFormat('MMMM yyyy').format(now);
    final year = now.year;
    final month = now.month;

    _monthGrid = _buildMonthGrid(year, month);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: editMode ? Colors.red : Colors.deepPurple,
            title: Text(editMode ? 'Edit Mode' : 'Planner'),
            leading: editMode
                ? IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    tooltip: "Add Doctor",
                    onPressed: _goToAddDoctor,
                  )
                : null,
            actions: [
              if (editMode)
                TextButton(
                  child: const Text(
                    "Done",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: () async {
                    if (isSaving) return;

                    setState(() {
                      isSaving = true;
                    });

                    try {
                      if (weekSelections.isNotEmpty ||
                          scheduledTimes.isNotEmpty) {
                        final doctorsSnap =
                            await _doctorsCollectionRef().get();
                        final originalById =
                            <String, Map<String, dynamic>>{
                          for (final d in doctorsSnap.docs)
                            d.id: d.data(),
                        };

                        final affectedDoctorIds = <String>{
                          ...weekSelections.keys,
                          ...scheduledTimes.keys,
                        };

                        for (final docId in affectedDoctorIds) {
                          final originalData = originalById[docId] ?? {};

                          final newWeeks = weekSelections[docId] ??
                              [
                                for (int w = 1; w <= 5; w++)
                                  (originalData['week_$w'] ?? "")
                                      .toString(),
                              ];

                          final timesForDoctor =
                              scheduledTimes[docId] ?? {};

                          await _saveEditedWeeksWithTimes(
                            originalData,
                            newWeeks,
                            docId,
                            timesForDoctor,
                          );

                          await _autoSetTimesForNewVisits(
                            docId: docId,
                            originalData: originalData,
                            newWeeks: newWeeks,
                          );
                        }
                      }

                      if (!mounted) return;
                      setState(() {
                        selectedDoctorIdx = null;
                        selectedDoctorRowData = null;
                        selectedDoctorId = null;
                        editMode = false;
                        weekSelections.clear();
                        scheduledTimes.clear();
                      });
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Error saving schedule: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          isSaving = false;
                        });
                      }
                    }
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  tooltip: 'Edit',
                  onPressed: () {
                    setState(() {
                      editMode = true;
                    });
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Select the name first before editing the schedule.',
                        ),
                        duration: Duration(seconds: 5),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
            ],
          ),
          body: _userId.isEmpty || _userClientType.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
                  stream: _doctorsCollectionRef().snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final doctors = snapshot.data!.docs.toList();
                    doctors.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aLast =
                          (aData['lastName'] ?? '').toString().toLowerCase();
                      final bLast =
                          (bData['lastName'] ?? '').toString().toLowerCase();
                      final cmpLast = aLast.compareTo(bLast);
                      if (cmpLast != 0) return cmpLast;
                      final aFirst =
                          (aData['firstName'] ?? '').toString().toLowerCase();
                      final bFirst =
                          (bData['firstName'] ?? '').toString().toLowerCase();
                      return aFirst.compareTo(bFirst);
                    });

                    return Column(
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // LEFT column: doctor list
                              Container(
                                width: mdNameColWidth,
                                color: Colors.purple.shade50,
                                child: Column(
                                  children: [
                                    Container(
                                      height: 40,
                                      color: Colors.purple.shade50,
                                    ),
                                    Container(
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        gradient: _purpleRowGradient,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Doctor',
                                        style: GoogleFonts.ubuntu(
                                          fontSize: 20,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        gradient: _purpleRowGradient,
                                        border: Border(
                                          bottom: BorderSide(
                                              color: Colors.grey.shade400),
                                        ),
                                      ),
                                      child: const Text(
                                        'Details',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        controller: _leftController,
                                        itemCount: doctors.length,
                                        itemBuilder: (context, rowIdx) {
                                          final doc = doctors[rowIdx];
                                          final docId = doc.id;
                                          final data =
                                              doc.data() as Map<String, dynamic>;
                                          final localWeeks =
                                              weekSelections[docId] ??
                                                  [
                                                    for (int w = 1; w <= 5; w++)
                                                      (data['week_$w'] ?? "")
                                                          .toString(),
                                                  ];
                                          weekSelections[docId] =
                                              localWeeks;

                                          final freqField =
                                              (data['freq'] ??
                                                  data['frequency']);
                                          final freq = int.tryParse(
                                                  freqField
                                                          ?.toString()
                                                          .replaceAll(
                                                              RegExp(r'\D'),
                                                              '') ??
                                                      "1") ??
                                              1;
                                          final overFreq = _isExceededFreq(
                                              localWeeks, freq);

                                          final isSelectedRow =
                                              selectedDoctorIdx == rowIdx;
                                          final nameRowColor = overFreq
                                              ? Colors.red.shade200
                                              : (editMode && isSelectedRow
                                                  ? Colors
                                                      .purple.shade100
                                                      .withOpacity(0.9)
                                                  : (isSelectedRow
                                                      ? Colors
                                                          .purple.shade50
                                                          .withOpacity(0.8)
                                                      : null));

                                          return GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                if (editMode) {
                                                  _selectDoctorForEdit(
                                                    data,
                                                    rowIdx,
                                                    docId,
                                                  );
                                                } else {
                                                  _selectDoctorForDetail(
                                                    data,
                                                    rowIdx,
                                                    docId,
                                                  );
                                                }
                                              });
                                            },
                                            child: Container(
                                              height: rowHeight,
                                              alignment: Alignment.centerLeft,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12),
                                              decoration: BoxDecoration(
                                                color: nameRowColor,
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color:
                                                        Colors.grey.shade400,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                "${data['lastName'] ?? ''}, ${data['firstName'] ?? ''}",
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // RIGHT: calendar & week selectors
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: Column(
                                      children: [
                                        Container(
                                          width: tableWidth,
                                          height: 40,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.deepPurple.shade100,
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            monthYearLabel,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors
                                                  .deepPurple.shade900,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          height: 36,
                                          width: tableWidth,
                                          decoration: BoxDecoration(
                                            gradient: _purpleRowGradient,
                                          ),
                                          child: Row(
                                            children: [
                                              for (int w = 1; w <= 5; w++) ...[
                                                Container(
                                                  width: weekColWidth,
                                                  height: 36,
                                                  alignment:
                                                      Alignment.center,
                                                  child: Text(
                                                    "WEEK $w",
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                if (w < 5)
                                                  Container(
                                                    width: 1,
                                                    height: 36,
                                                    color: Colors.white
                                                        .withOpacity(0.3),
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Container(
                                          height: 36,
                                          width: tableWidth,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              for (int w = 0; w < 5; w++) ...[
                                                Container(
                                                  width: weekColWidth,
                                                  alignment:
                                                      Alignment.center,
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: List.generate(
                                                        7, (d) {
                                                      final date =
                                                          _monthGrid[w][d];
                                                      final display = (date !=
                                                                  null &&
                                                              date.month ==
                                                                  month)
                                                          ? date.day
                                                              .toString()
                                                          : "";
                                                      return SizedBox(
                                                        width: boxSize,
                                                        child: Center(
                                                          child: Text(
                                                            display,
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                ),
                                                if (w < 4)
                                                  Container(
                                                    width: 1,
                                                    height: 36,
                                                    color:
                                                        Colors.grey[400],
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: ListView.builder(
                                            controller: _rightController,
                                            itemCount: doctors.length,
                                            itemBuilder:
                                                (context, rowIdx) {
                                              final doc =
                                                  doctors[rowIdx];
                                              final docId = doc.id;
                                              final data = doc.data()
                                                  as Map<String, dynamic>;

                                              final freqField =
                                                  (data['freq'] ??
                                                      data['frequency']);
                                              final freq = int.tryParse(
                                                      freqField
                                                              ?.toString()
                                                              .replaceAll(
                                                                  RegExp(
                                                                      r'\D'),
                                                                  '') ??
                                                          "1") ??
                                                  1;

                                              final currentWeeks =
                                                  weekSelections[docId] ??
                                                      [
                                                        for (int w = 1;
                                                            w <= 5;
                                                            w++)
                                                          (data['week_$w'] ??
                                                                  "")
                                                              .toString(),
                                                      ];
                                              weekSelections[docId] =
                                                  currentWeeks;

                                              final overFreq =
                                                  _isExceededFreq(
                                                      currentWeeks,
                                                      freq);
                                              final isSelectedRow =
                                                  selectedDoctorIdx ==
                                                      rowIdx;

                                              return Container(
                                                height: rowHeight,
                                                color: overFreq
                                                    ? Colors.red
                                                        .withOpacity(0.4)
                                                    : (editMode &&
                                                            isSelectedRow
                                                        ? Colors
                                                            .purple.shade100
                                                            .withOpacity(
                                                                0.9)
                                                        : (isSelectedRow
                                                            ? Colors
                                                                .purple
                                                                .shade100
                                                                .withOpacity(
                                                                    0.8)
                                                            : null)),
                                                child: Row(
                                                  children: [
                                                    for (int w = 0;
                                                        w < 5;
                                                        w++) ...[
                                                      Container(
                                                        width:
                                                            weekColWidth,
                                                        height: rowHeight,
                                                        decoration:
                                                            const BoxDecoration(
                                                          border: Border(
                                                            bottom:
                                                                BorderSide(
                                                              color: Color(
                                                                  0xFFDDDDDD),
                                                            ),
                                                          ),
                                                        ),
                                                        child:
                                                            _weekInteractiveBoxes(
                                                          weekIndex: w,
                                                          currentValue:
                                                              currentWeeks[
                                                                  w],
                                                          isEnabled:
                                                              editMode &&
                                                                  !isOpeningScheduleDialog,
                                                          onChanged:
                                                              (newVal) async {
                                                            if (!editMode ||
                                                                isOpeningScheduleDialog) {
                                                              return;
                                                            }

                                                            if (selectedDoctorIdx !=
                                                                    rowIdx ||
                                                                selectedDoctorId !=
                                                                    docId) {
                                                              setState(
                                                                  () {
                                                                _selectDoctorForEdit(
                                                                  data,
                                                                  rowIdx,
                                                                  docId,
                                                                );
                                                              });
                                                            }

                                                            if (newVal
                                                                .isEmpty) {
                                                              _handleWeekBoxTap(
                                                                docId,
                                                                w,
                                                                "",
                                                              );
                                                              return;
                                                            }

                                                            _handleWeekBoxTap(
                                                              docId,
                                                              w,
                                                              newVal,
                                                            );

                                                            await _selectTimeForVisit(
                                                              docId:
                                                                  docId,
                                                              doctorData:
                                                                  data,
                                                              weekIndex:
                                                                  w,
                                                              dayCode:
                                                                  newVal,
                                                            );
                                                          },
                                                          boxWidth:
                                                              boxSize,
                                                        ),
                                                      ),
                                                      if (w < 4)
                                                        Container(
                                                          width: 1,
                                                          height: rowHeight,
                                                          color: Colors
                                                              .grey[400],
                                                        ),
                                                    ],
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selectedDoctorRowData != null)
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 4,
                                  children: [
                                    _labelValue(
                                      "MD ID:",
                                      selectedDoctorRowData?['doc_id'] ??
                                          '',
                                    ),
                                    _labelValue(
                                      "LASTNAME:",
                                      selectedDoctorRowData?['lastName'] ??
                                          '',
                                    ),
                                    _labelValue(
                                      "FIRSTNAME:",
                                      selectedDoctorRowData?['firstName'] ??
                                          '',
                                    ),
                                    _labelValue(
                                      "SPECIALTY:",
                                      selectedDoctorRowData?['specialty'] ??
                                          '',
                                    ),
                                    _labelValue(
                                      "FREQUENCY:",
                                      selectedDoctorRowData?['freq'] ?? '',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 16,
                                  children: [
                                    _labelValue(
                                      "ADDRESS:",
                                      selectedDoctorRowData?['hospital'] ??
                                          '',
                                    ),
                                    _labelValue(
                                      "CITY:",
                                      selectedDoctorRowData?['city'] ?? '',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        if (isSaving)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        if (isOpeningScheduleDialog)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _weekInteractiveBoxes({
    required int weekIndex,
    required String currentValue,
    required bool isEnabled,
    required Function(String day) onChanged,
    required double boxWidth,
  }) {
    final weekDays = ["Su", "M", "T", "W", "Th", "F", "Sa"];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        7,
        (i) {
          final day = weekDays[i];
          final selected = currentValue == day;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: GestureDetector(
              onTap: isEnabled ? () => onChanged(day) : null,
              child: Container(
                width: boxSize,
                height: boxSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.deepPurple.shade400
                      : Colors.grey.shade400,
                  border: Border.all(
                    color:
                        selected ? Colors.green.shade400 : Colors.white,
                    width: selected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _labelValue(String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}