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
  int? selectedDoctorIdx;
  String? selectedDoctorId;
  Map<String, dynamic>? selectedDoctorRowData;

  static const double boxSize = 26.0;
  static const double minMdNameColWidth = 160;
  static const double minWeekColWidth = 210;
  static const double rowHeight = 62.0;

  /// weekSelections[docId] = list of 5 strings (week_1..week_5)
  Map<String, List<String>> weekSelections = {};
  
  /// scheduledTimes[docId][weekIndex] = scheduled time string (e.g. "09:00")
  Map<String, Map<int, String>> scheduledTimes = {};
  
  final ScrollController _leftController = ScrollController();
  final ScrollController _rightController = ScrollController();
  String userEmail = '';
  String emailKey = '';

  @override
  void initState() {
    super.initState();
    _initSyncedScroll();
    _loadUserEmail();
  }

  void _initSyncedScroll() {
    _leftController.addListener(() {
      if (_rightController.hasClients &&
          (_rightController.offset != _leftController.offset)) {
        _rightController.jumpTo(_leftController.offset);
      }
    });
    _rightController.addListener(() {
      if (_leftController.hasClients &&
          (_leftController.offset != _rightController.offset)) {
        _leftController.jumpTo(_rightController.offset);
      }
    });
  }

  Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString('userEmail') ?? '';
    setState(() {
      emailKey = userEmail.replaceAll(RegExp(r'[.#$\\\[\]/]'), '_');
    });
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
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
    setState(() {
      selectedDoctorIdx = idx;
      selectedDoctorRowData = data;
      selectedDoctorId = docId;
      if (!weekSelections.containsKey(docId)) {
        weekSelections[docId] = [
          for (int w = 1; w <= 5; w++) (data['week_$w'] ?? "")
        ];
      }
      // Initialize scheduledTimes for this doctor
      if (!scheduledTimes.containsKey(docId)) {
        scheduledTimes[docId] = {for (int w = 0; w < 5; w++) w: ""};
      }
    });
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
    int doctorIdx,
    String docId,
    int weekIdx,
    String selectedDay,
    int freq,
  ) {
    setState(() {
      var doctorWeek = weekSelections[docId] ?? ["", "", "", "", ""];
      doctorWeek[weekIdx] =
          doctorWeek[weekIdx] == selectedDay ? "" : selectedDay;
      weekSelections[docId] = doctorWeek;
    });
  }

  bool _isExceededFreq(List<String> selected, int freq) {
    int count = selected.where((e) => e.isNotEmpty).length;
    return count > freq;
  }

  /// NEW: Save both week pattern AND scheduled times to Firestore
  Future<void> _saveEditedWeeksWithTimes(
    Map<String, dynamic> originalData,
    List<String> editedWeeks,
    String docId,
  ) async {
    // 1. Update week pattern in doctor document
    Map<String, dynamic> weekUpdate = {};
    for (int i = 0; i < 5; i++) {
      String orig = (originalData['week_${i + 1}'] ?? "");
      String edited = editedWeeks[i];
      if (orig != edited) {
        weekUpdate['week_${i + 1}'] = edited;
      }
    }

    // 2. Get scheduled times for this doctor
    final times = scheduledTimes[docId] ?? {};
    
    // 3. Update doctor document with week pattern (if changed)
    final doctorRef = FirebaseFirestore.instance
        .collection('flowDB')
        .doc('users')
        .collection(emailKey)
        .doc('doctors')
        .collection('doctors')
        .doc(docId);
    
    if (weekUpdate.isNotEmpty) {
      await doctorRef.update(weekUpdate);
    }

    // 4. Sync scheduled visits with new week pattern AND times
    await _syncVisitsWithTmlScheduleAndTimes(docId, originalData, editedWeeks, times);
  }

  DateTime? getDateForWeekdayOfMonth(
    int year,
    int month,
    int week,
    String day,
  ) {
    final weekdayMap = {
      "Su": DateTime.sunday,
      "M": DateTime.monday,
      "T": DateTime.tuesday,
      "W": DateTime.wednesday,
      "Th": DateTime.thursday,
      "F": DateTime.friday,
      "Sa": DateTime.saturday
    };
    int weekday = weekdayMap[day] ?? DateTime.monday;
    DateTime dt = DateTime(year, month, 1);
    while (dt.weekday != weekday) {
      dt = dt.add(const Duration(days: 1));
    }
    dt = dt.add(Duration(days: (week - 1) * 7));
    if (dt.month != month) return null;
    return dt;
  }

  /// Reverse: from yyyy-MM-dd -> Su/M/T/W/Th/F/Sa (for current month only)
  String _getDayFromDateString(String dateStr, int year, int month) {
    try {
      final date = DateFormat("yyyy-MM-dd").parse(dateStr);
      if (date.year != year || date.month != month) return "";

      final weekdayMapReverse = {
        DateTime.sunday: "Su",
        DateTime.monday: "M",
        DateTime.tuesday: "T",
        DateTime.wednesday: "W",
        DateTime.thursday: "Th",
        DateTime.friday: "F",
        DateTime.saturday: "Sa",
      };
      return weekdayMapReverse[date.weekday] ?? "";
    } catch (_) {
      return "";
    }
  }

  /// UPDATED: Now also saves scheduled times from the dialog
  /// FIXED: Only delete EMPTY dates (preserve dates with scheduledTime)
  Future<void> _syncVisitsWithTmlScheduleAndTimes(
    String docId,
    Map<String, dynamic> doctorData,
    List<String> weeks,
    Map<int, String> scheduledTimesMap,
  ) async {
    final visitsRootRef = FirebaseFirestore.instance
        .collection('flowDB')
        .doc('users')
        .collection(emailKey)
        .doc('doctors')
        .collection('doctors')
        .doc(docId)
        .collection('scheduledVisits');

    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final monthId = DateFormat('yyyy-MM').format(now);

    final monthDatesRef = visitsRootRef
        .doc('months')
        .collection('months')
        .doc(monthId)
        .collection('dates');

    // 1) Build current week pattern
    final currentWeekDays = <int, String>{}; // weekIndex -> dayCode
    for (int w = 0; w < weeks.length; w++) {
      if (weeks[w].isNotEmpty) {
        currentWeekDays[w] = weeks[w];
      }
    }

    // 2) Load ALL existing dates
    final allDatesSnap = await monthDatesRef.get();

    // 3) FIXED: ONLY delete dates that are:
    //    - NOT in current week pattern AND
    //    - scheduledTime is EMPTY
    for (final docSnap in allDatesSnap.docs) {
      final data = docSnap.data();
      final dateId = docSnap.id; // "yyyy-MM-dd"
      final dayCode = _getDayFromDateString(dateId, year, month);
      
      // Find which week this date belongs to
      bool isInCurrentPattern = false;
      for (int w = 0; w < 5; w++) {
        final expectedDate = getDateForWeekdayOfMonth(year, month, w + 1, dayCode);
        if (expectedDate != null && 
            DateFormat("yyyy-MM-dd").format(expectedDate) == dateId &&
            currentWeekDays.containsKey(w)) {
          isInCurrentPattern = true;
          break;
        }
      }

      // CRITICAL: Only delete if NOT in pattern AND no scheduled time
      final hasScheduledTime = (data['scheduledTime']?.toString().trim().isNotEmpty ?? false);
      
      if (!isInCurrentPattern && !hasScheduledTime) {
        await docSnap.reference.delete();
      }
    }

    // 4) Create/Update dates FOR CURRENT PATTERN ONLY with their scheduled times
    for (int w = 0; w < weeks.length; w++) {
      final dayCode = weeks[w];
      if (dayCode.isEmpty) continue;

      final dt = getDateForWeekdayOfMonth(year, month, w + 1, dayCode);
      if (dt == null || dt.month != month) continue;

      final dateStr = DateFormat("yyyy-MM-dd").format(dt);
      final scheduledTime = scheduledTimesMap[w] ?? "";
      
      await monthDatesRef.doc(dateStr).set({
        "scheduledDate": dateStr,
        "scheduledTime": scheduledTime, // Use scheduled time or empty
        "submitted": false,
        "surprise": false,
      }, SetOptions(merge: true)); // merge preserves existing data
    }
  }

  /// Find week indices where the pattern went from no visit -> visit.
  List<int> _getNewVisitWeekIndices(
    List<String> oldWeeks,
    List<String> newWeeks,
  ) {
    final List<int> indices = [];
    for (int i = 0; i < 5; i++) {
      final String oldVal = oldWeeks[i];
      final String newVal = newWeeks[i];
      if (oldVal.isEmpty && newVal.isNotEmpty) {
        indices.add(i); // 0-based week index (0..4)
      }
    }
    return indices;
  }

  /// Auto-assign scheduledTime for a given doctor, weekIndex (0-based), and dayCode,
  Future<void> _autoSetScheduledTimeForVisit({
    required String docId,
    required String dayCode,  // "M", "Th", etc.
    required int weekIndex,   // 0..4  -> week_1..week_5
  }) async {
    final now = DateTime.now();
    final int year = now.year;
    final int month = now.month;

    final visitDate =
        getDateForWeekdayOfMonth(year, month, weekIndex + 1, dayCode);
    if (visitDate == null) return;

    final String dateStr = DateFormat("yyyy-MM-dd").format(visitDate);
    final String monthId = DateFormat('yyyy-MM').format(visitDate);

    final visitsRootRef = FirebaseFirestore.instance
        .collection('flowDB')
        .doc('users')
        .collection(emailKey)
        .doc('doctors')
        .collection('doctors')
        .doc(docId)
        .collection('scheduledVisits');

    final monthDatesRef = visitsRootRef
        .doc('months')
        .collection('months')
        .doc(monthId)
        .collection('dates');

    final dateDocRef = monthDatesRef.doc(dateStr);
    final snap = await dateDocRef.get();

    String existingTime = "";
    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>;
      existingTime = (data['scheduledTime'] ?? "").toString().trim();
    }

    final String finalTime = existingTime.isNotEmpty ? existingTime : "09:00";

    await dateDocRef.set(
      {
        "scheduledDate": dateStr,
        "scheduledTime": finalTime,
        "submitted": false,
        "surprise": false,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _autoSetTimesForNewVisits({
    required String docId,
    required Map<String, dynamic> originalData,
    required List<String> newWeeks,
  }) async {
    final List<String> oldWeeks = [
      for (int i = 1; i <= 5; i++) (originalData['week_$i'] ?? "").toString(),
    ];

    final newVisitIndices = _getNewVisitWeekIndices(oldWeeks, newWeeks);

    for (final weekIndex in newVisitIndices) {
      final String dayCode = newWeeks[weekIndex];
      if (dayCode.isEmpty) continue;
      await _autoSetScheduledTimeForVisit(
        docId: docId,
        dayCode: dayCode,
        weekIndex: weekIndex,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getAllScheduledVisits(
    CollectionReference visitsRootRef,
  ) async {
    final monthsSnap = await visitsRootRef
        .doc('months')
        .collection('months')
        .orderBy('label')
        .get();

    List<Map<String, dynamic>> visits = [];
    for (final monthDoc in monthsSnap.docs) {
      final datesSnap = await monthDoc.reference
          .collection('dates')
          .orderBy('scheduledDate')
          .get();
      for (final d in datesSnap.docs) {
        visits.add(d.data() as Map<String, dynamic>);
      }
    }
    return visits;
  }

  /// UPDATED: Now captures the scheduled time and stores it in scheduledTimes map
  Future<void> _showHourSlotsDialog({
    required String docId,
    required Map<String, dynamic> doctorData,
    required DateTime visitDate,
    required String dayLabel,
    required int weekIndex, // NEW: Pass week index to know which week this is
  }) async {
    final String headerDate = DateFormat('MMMM d, yyyy').format(visitDate);

    final visitsRootRef = FirebaseFirestore.instance
        .collection('flowDB')
        .doc('users')
        .collection(emailKey)
        .doc('doctors')
        .collection('doctors')
        .doc(docId)
        .collection('scheduledVisits');

    final String monthId = DateFormat('yyyy-MM').format(visitDate);

    final monthDatesRef = visitsRootRef
        .doc('months')
        .collection('months')
        .doc(monthId)
        .collection('dates');

    Future<void> saveHour(int hour) async {
      final String dateStr = DateFormat("yyyy-MM-dd").format(visitDate);
      final String timeStr = hour.toString().padLeft(2, '0') + ":00";

      // 1. Update Firestore immediately
      await monthDatesRef.doc(dateStr).set({
        "scheduledDate": dateStr,
        "scheduledTime": timeStr,
        "submitted": false,
        "surprise": false,
      }, SetOptions(merge: true));

      // 2. Store in local state for "Done" button
      setState(() {
        if (!scheduledTimes.containsKey(docId)) {
          scheduledTimes[docId] = {};
        }
        scheduledTimes[docId]![weekIndex] = timeStr;
      });
    }

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF7030f8),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${hour.toString().padLeft(2, '0')}:00",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      "Available",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () async {
                                    await saveHour(hour);
                                    Navigator.of(context).pop();

                                    if (mounted) {
                                      await _showScheduledTimesDialog(
                                        docId: docId,
                                        doctorData: doctorData,
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: const LinearGradient(
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
                                      children: const [
                                        Icon(
                                          Icons.add,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          "Schedule",
                                          style: TextStyle(
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
    final now = DateTime.now();
    final int year = now.year;
    final int month = now.month;

    final visitDate =
        getDateForWeekdayOfMonth(year, month, weekIndex + 1, dayCode);
    if (visitDate == null) {
      return;
    }

    final weekdayNames = {
      "Su": "Sunday",
      "M": "Monday",
      "T": "Tuesday",
      "W": "Wednesday",
      "Th": "Thursday",
      "F": "Friday",
      "Sa": "Saturday",
    };
    final String dayLabel = weekdayNames[dayCode] ?? dayCode;

    await _showHourSlotsDialog(
      docId: docId,
      doctorData: doctorData,
      visitDate: visitDate,
      dayLabel: dayLabel,
      weekIndex: weekIndex, // PASS WEEK INDEX
    );
  }

  Future<void> _showScheduledTimesDialog({
    required String docId,
    required Map<String, dynamic> doctorData,
  }) async {
    final visitsRootRef = FirebaseFirestore.instance
        .collection('flowDB')
        .doc('users')
        .collection(emailKey)
        .doc('doctors')
        .collection('doctors')
        .doc(docId)
        .collection('scheduledVisits');

    final String doctorName =
        "${doctorData['lastName'] ?? ''}, ${doctorData['firstName'] ?? ''}";

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Scheduled Times\n$doctorName"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getAllScheduledVisits(visitsRootRef),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final visits = snapshot.data!;
                    return visits.isEmpty
                        ? const Text("No scheduled times yet.")
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: visits.length,
                            itemBuilder: (context, index) {
                              final v = visits[index];
                              final dateStr =
                                  (v['scheduledDate'] ?? '').toString();
                              final timeStr =
                                  (v['scheduledTime'] ?? '').toString();
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.schedule,
                                  color: timeStr.isNotEmpty
                                      ? Colors.green
                                      : Colors.orange,
                                  size: 20,
                                ),
                                title: Text(dateStr),
                                subtitle: Text(
                                  timeStr.isEmpty ? "No time set" : timeStr,
                                  style: TextStyle(
                                    fontWeight: timeStr.isNotEmpty
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: timeStr.isNotEmpty
                                        ? Colors.green[700]
                                        : null,
                                  ),
                                ),
                                trailing: timeStr.isNotEmpty
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 20,
                                      )
                                    : null,
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
      },
    );
  }

  List<List<DateTime?>> _buildMonthGrid(int year, int month) {
    final firstOfMonth = DateTime(year, month, 1);
    final firstWeekday = firstOfMonth.weekday;
    final daysBackToSunday = firstWeekday % 7;
    final gridStart = firstOfMonth.subtract(Duration(days: daysBackToSunday));

    final lastOfMonth = DateTime(year, month + 1, 0);
    final totalDaysSpan =
        lastOfMonth.difference(gridStart).inDays + 1;
    final totalWeeks = (totalDaysSpan / 7.0).ceil();

    List<List<DateTime?>> weeks = [];
    DateTime cursor = gridStart;
    for (int w = 0; w < totalWeeks; w++) {
      List<DateTime?> row = [];
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final double mdNameColWidth = minMdNameColWidth;
    final double availableWidth = screenWidth - mdNameColWidth;
    final double weekColWidth =
        (availableWidth / 5 > minWeekColWidth)
            ? availableWidth / 5
            : minWeekColWidth;
    final double tableWidth = weekColWidth * 5 + 4;

    final DateTime now = DateTime.now();
    final String monthYearLabel = DateFormat('MMMM yyyy').format(now);
    final int year = now.year;
    final int month = now.month;

    final List<List<DateTime?>> monthGrid = _buildMonthGrid(year, month);

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
                        fontSize: 16),
                  ),
                  onPressed: () async {
                    if (isSaving) return;

                    setState(() {
                      isSaving = true;
                    });

                    if (weekSelections.isNotEmpty || scheduledTimes.isNotEmpty) {
                      // 1) Load original data for ALL doctors once
                      final doctorsSnap = await FirebaseFirestore.instance
                          .collection('flowDB')
                          .doc('users')
                          .collection(emailKey)
                          .doc('doctors')
                          .collection('doctors')
                          .get();

                      final Map<String, Map<String, dynamic>> originalById = {
                        for (final d in doctorsSnap.docs)
                          d.id: (d.data() as Map<String, dynamic>)
                      };

                      // 2) Process each doctor that had edits
                      for (final entry in weekSelections.entries) {
                        final docId = entry.key;
                        final List<String> newWeeks = entry.value;

                        final Map<String, dynamic> originalData =
                            originalById[docId] ?? {};

                        // NEW: Save BOTH week pattern AND scheduled times
                        final times = scheduledTimes[docId] ?? {};
                        await _saveEditedWeeksWithTimes(
                          originalData,
                          newWeeks,
                          docId,
                        );
                      }
                    }

                    setState(() {
                      selectedDoctorIdx = null;
                      selectedDoctorRowData = null;
                      selectedDoctorId = null;
                      editMode = false;
                      isSaving = false;
                      weekSelections.clear();
                      scheduledTimes.clear();
                    });
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
                        duration: Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
            ],
          ),
          body: emailKey.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('flowDB')
                      .doc('users')
                      .collection(emailKey)
                      .doc('doctors')
                      .collection('doctors')
                      .snapshots(),
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
                              // LEFT: Doctor/Details + rows
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
                                            color: Colors.grey.shade400,
                                          ),
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
                                          final data = doc.data()
                                              as Map<String, dynamic>;
                                          final selList =
                                              weekSelections[docId] ??
                                              [
                                                for (int w = 1; w <= 5; w++)
                                                  (data['week_$w'] ?? "")
                                              ];
                                          final freqField = (data['freq'] ??
                                              data['frequency']);
                                          final freq = int.tryParse(
                                                  freqField
                                                          ?.toString()
                                                          .replaceAll(
                                                              RegExp(r'\D'), '')
                                                      ??
                                                      "1") ??
                                              1;
                                          final overFreq = _isExceededFreq(
                                              selList, freq);

                                          final bool isSelectedRow =
                                              selectedDoctorIdx == rowIdx;
                                          final Color? nameRowColor = overFreq
                                              ? Colors.red.shade200
                                              : (editMode && isSelectedRow
                                                  ? Colors.purple.shade100
                                                      .withOpacity(0.9)
                                                  : (isSelectedRow
                                                      ? Colors.purple.shade50
                                                          .withOpacity(0.8)
                                                      : null));

                                          return GestureDetector(
                                            onTap: () {
                                              if (editMode) {
                                                _selectDoctorForEdit(
                                                    data, rowIdx, docId);
                                              } else {
                                                _selectDoctorForDetail(
                                                    data, rowIdx, docId);
                                              }
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
                                                    color: Colors.grey.shade400,
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

                              // RIGHT: Month header, weeks, etc.
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
                                                  alignment: Alignment.center,
                                                  child: const Text(
                                                    "WEEK ",
                                                    style: TextStyle(
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
                                                  alignment: Alignment.center,
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: List.generate(
                                                      7,
                                                      (d) {
                                                        final date =
                                                            monthGrid[w][d];
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
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                if (w < 4)
                                                  Container(
                                                    width: 1,
                                                    height: 36,
                                                    color: Colors.grey[400],
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: ListView.builder(
                                            controller: _rightController,
                                            itemCount: doctors.length,
                                            itemBuilder: (context, rowIdx) {
                                              final doc = doctors[rowIdx];
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
                                                                  RegExp(r'\D'),
                                                                  '') ??
                                                          "1") ??
                                                  1;
                                              final selList =
                                                  weekSelections[docId] ??
                                                      [
                                                        for (int w = 1;
                                                            w <= 5;
                                                            w++)
                                                          (data['week_$w'] ??
                                                              "")
                                                      ];
                                              final overFreq =
                                                  _isExceededFreq(selList, freq);
                                              final bool isSelectedRow =
                                                  selectedDoctorIdx == rowIdx;
                                              final bool isEditable =
                                                  editMode &&
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
                                                            .withOpacity(0.9)
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
                                                        width: weekColWidth,
                                                        height: rowHeight,
                                                        decoration:
                                                            const BoxDecoration(
                                                          border: Border(
                                                            bottom: BorderSide(
                                                              color:
                                                                  Color(0xFFDDDDDD),
                                                            ),
                                                          ),
                                                        ),
                                                        child: _weekInteractiveBoxes(
                                                          weekIndex: w,
                                                          currentValue:
                                                              selList[w],
                                                          isEnabled: isEditable,
                                                          onChanged: (newVal) async {
                                                            if (!isEditable) {
                                                              return;
                                                            }
                                                            if (newVal
                                                                .isEmpty) {
                                                              _handleWeekBoxTap(
                                                                rowIdx,
                                                                docId,
                                                                w,
                                                                "",
                                                                freq,
                                                              );
                                                              return;
                                                            }
                                                            _handleWeekBoxTap(
                                                              rowIdx,
                                                              docId,
                                                              w,
                                                              newVal,
                                                              freq,
                                                            );
                                                            await _selectTimeForVisit(
                                                              docId: docId,
                                                              doctorData: data,
                                                              weekIndex: w,
                                                              dayCode: newVal,
                                                            );
                                                          },
                                                          boxWidth: boxSize,
                                                        ),
                                                      ),
                                                      if (w < 4)
                                                        Container(
                                                          width: 1,
                                                          height: rowHeight,
                                                          color:
                                                              Colors.grey[400],
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 4,
                                  children: [
                                    _labelValue(
                                      "MD ID:",
                                      selectedDoctorRowData?['doc_id'] ?? '',
                                    ),
                                    _labelValue(
                                      "LASTNAME:",
                                      selectedDoctorRowData?['lastName'] ?? '',
                                    ),
                                    _labelValue(
                                      "FIRSTNAME:",
                                      selectedDoctorRowData?['firstName'] ?? '',
                                    ),
                                    _labelValue(
                                      "SPECIALTY:",
                                      selectedDoctorRowData?['specialty'] ?? '',
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
                                      selectedDoctorRowData?['hospital'] ?? '',
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
      ],
    );
  }

  Widget _headerCell(String text, double width) => Container(
        width: width,
        height: 36,
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
      );

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
                    color: selected
                        ? Colors.green.shade400
                        : Colors.white,
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
                color: Colors.blue),
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
