import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../deduction_input_page.dart';
import '../doctor_menu/call_detail_page.dart';
import 'dart:math';
import '../itinerary_menu/call_off_field.dart';

class ItineraryPage extends StatefulWidget {
  const ItineraryPage({Key? key}) : super(key: key);

  @override
  _ItineraryPageState createState() => _ItineraryPageState();
}

class _ItineraryPageState extends State<ItineraryPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  Map<String, int> _scheduledCallsCount = {};
  Map<String, Map<String, int>> _barColorCounts = {};

  // map of dateKey -> offField reason (first non‑empty reason found for that date)
  Map<String, String> _offFieldReasons = {};

  String emailKey = '';

  // 0 = Day, 1 = Week, 2 = Month (default)
  int _selectedViewIndex = 2;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    setState(() {
      emailKey = userEmail.replaceAll(RegExp(r'[.#$\[\\]/]'), '_');
      _fetchScheduledCallsCount(_focusedDay);
    });
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _goToDeductionInput(BuildContext context, DateTime selectedDay) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeductionInputPage(selectedDate: selectedDay),
      ),
    );
    setState(() {});
  }

  Future<void> _fetchScheduledCallsCount(DateTime focusedDay) async {
    if (emailKey.isEmpty) return;

    final first = DateTime.utc(focusedDay.year, focusedDay.month - 1, 20);
    final last = DateTime.utc(focusedDay.year, focusedDay.month + 2, 10);

    Map<String, int> counts = {};
    Map<String, Map<String, int>> colorCounts = {};
    Map<String, String> offFieldReasons = {};

    final doctorsSnap = await FirebaseFirestore.instance
        .collection('flowDB')
        .doc('users')
        .collection(emailKey)
        .doc('doctors')
        .collection('doctors')
        .get();

    for (var doc in doctorsSnap.docs) {
      var scheduledVisitsSnap =
          await doc.reference.collection('scheduledVisits').get();

      for (var v in scheduledVisitsSnap.docs) {
        final visitData = v.data();
        final visitDateString = visitData['scheduledDate'];

        if (visitDateString != null && visitDateString.length == 10) {
          final dt = DateTime.tryParse(visitDateString);
          if (dt != null && !dt.isBefore(first) && !dt.isAfter(last)) {
            counts[visitDateString] = (counts[visitDateString] ?? 0) + 1;

            String colorKey = "white";
            final bool isSubmitted = visitData['submitted'] == true;
            final bool isSurprise = visitData['surprise'] == true;
            DateTime nowCut = DateTime.now();
            DateTime? visitDate;

            try {
              visitDate = DateTime.parse(visitDateString);
            } catch (_) {
              visitDate = null;
            }

            if (isSurprise) {
              colorKey = "yellow";
            } else if (isSubmitted) {
              colorKey = "green";
            } else if (visitDate != null &&
                DateTime(nowCut.year, nowCut.month, nowCut.day)
                    .isAfter(visitDate)) {
              colorKey = "red";
            }

            colorCounts[visitDateString] ??= {
              "red": 0,
              "yellow": 0,
              "green": 0,
              "white": 0
            };
            colorCounts[visitDateString]![colorKey] =
                colorCounts[visitDateString]![colorKey]! + 1;

            final offFieldValue = visitData['offField'];
            if (offFieldValue != null &&
                offFieldValue.toString().trim().isNotEmpty) {
              offFieldReasons.putIfAbsent(
                  visitDateString, () => offFieldValue.toString().trim());
            }
          }
        }
      }
    }

    setState(() {
      _scheduledCallsCount = counts;
      _barColorCounts = colorCounts;
      _offFieldReasons = offFieldReasons;
    });
  }

  Future<List<Map<String, dynamic>>> _getAllTargetDeductionsForDay(
      DateTime selectedDay) async {
    if (emailKey.isEmpty) return [];
    final String targetDateKey = _dateKey(selectedDay);

    final doctorsSnap = await FirebaseFirestore.instance
        .collection('flowDB')
        .doc('users')
        .collection(emailKey)
        .doc('doctors')
        .collection('doctors')
        .get();

    List<Map<String, dynamic>> allDeducts = [];
    for (var doc in doctorsSnap.docs) {
      final doctorId = doc.data()['doc_id'] ?? doc.id;
      final scheduledDocRef =
          doc.reference.collection('scheduledVisits').doc(targetDateKey);

      final targetDeductionsSnap =
          await scheduledDocRef.collection('targetDeductions').get();

      for (var d in targetDeductionsSnap.docs) {
        allDeducts.add({
          'doctorName':
              "${doc.data()['lastName'] ?? ''}, ${doc.data()['firstName'] ?? ''}",
          'doctorId': doctorId,
          'deductionId': d.id,
          'deduction': d.data(),
        });
      }
    }
    return allDeducts;
  }

  Future<List<Map<String, dynamic>>> _getAllScheduledVisitsForSelectedDay(
      List<QueryDocumentSnapshot> doctorDocs, DateTime selectedDay) async {
    if (emailKey.isEmpty) return [];
    final List<Map<String, dynamic>> allVisits = [];
    final targetDateKey = _dateKey(selectedDay);

    for (var doc in doctorDocs) {
      final docData = doc.data() as Map<String, dynamic>;
      final doctorId = docData['doc_id'] ?? doc.id;
      final doctorName =
          "${docData['lastName'] ?? ''}, ${docData['firstName'] ?? ''}";

      var scheduledVisitsSnap =
          await doc.reference.collection('scheduledVisits').get();

      for (var v in scheduledVisitsSnap.docs) {
        final visitData = v.data();
        final visitDateString = visitData['scheduledDate'] ?? '';
        if (visitDateString == targetDateKey) {
          allVisits.add({
            'doctorName': doctorName,
            'scheduledTime': visitData['scheduledTime'] ?? '',
            'hospital': docData['hospital'] ?? '',
            'specialty': docData['specialty'] ?? '',
            'doctor': docData,
            'doctorId': doctorId,
            'visitId': v.id,
            'visitData': visitData,
          });
        }
      }
    }

    allVisits.sort(
        (a, b) => (a['scheduledTime'] ?? '').compareTo(b['scheduledTime'] ?? ''));
    return allVisits;
  }

  Widget _buildViewSelectorChip({
    required String label,
    required int index,
  }) {
    final bool isSelected = _selectedViewIndex == index;
    final Color selectedColor = const Color(0xFF5e1398);
    final Color unselectedColor = Colors.grey.shade300;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _selectedViewIndex = index;
            });
          },
          child: Ink(
            decoration: BoxDecoration(
              color: isSelected ? selectedColor : unselectedColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Compute the Monday of the week that contains [date]
  DateTime _startOfWeek(DateTime date) {
    // DateTime.weekday: Monday = 1 ... Sunday = 7
    final int weekday = date.weekday;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: weekday - 1));
  }

  // Build the 7‑day row for Day view
  Widget _buildDayWeekStrip() {
    final DateTime baseDay = _selectedDay ?? _focusedDay;
    final DateTime start = _startOfWeek(baseDay);
    final DateTime today = DateTime.now();

    final List<DateTime> weekDays =
        List.generate(7, (i) => start.add(Duration(days: i)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          // Top row: left arrow, center = 7 day cells, right arrow
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  final DateTime newBase = baseDay.subtract(const Duration(days: 7));
                  setState(() {
                    _selectedDay = newBase;
                    _focusedDay = newBase;
                    _fetchScheduledCallsCount(_focusedDay);
                  });
                },
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: weekDays.map((d) {
                    final bool isSelected =
                        _selectedDay != null && _isSameDate(d, _selectedDay!);
                    final bool isToday = _isSameDate(d, today);

                    Color bgColor;
                    Color textColor;

                    if (isSelected && isToday) {
                      bgColor = const Color(0xFF8a00ff);
                      textColor = Colors.white;
                    } else if (isSelected) {
                      bgColor = const Color(0xFF4e2f80);
                      textColor = Colors.white;
                    } else if (isToday) {
                      bgColor = Colors.green.shade500;
                      textColor = Colors.white;
                    } else {
                      bgColor = Colors.grey.shade200;
                      textColor = Colors.black87;
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDay = d;
                            _focusedDay = d;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _weekdayLetter(d.weekday),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${d.day}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  final DateTime newBase = baseDay.add(const Duration(days: 7));
                  setState(() {
                    _selectedDay = newBase;
                    _focusedDay = newBase;
                    _fetchScheduledCallsCount(_focusedDay);
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatWeekLabel(DateTime start, DateTime end) {
    // Simple numeric label, you can customize with intl if you want
    String _monthName(int m) {
      const names = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return names[m];
    }

    final String startLabel =
        "${_monthName(start.month)} ${start.day.toString().padLeft(2, '0')}";
    final String endLabel =
        "${_monthName(end.month)} ${end.day.toString().padLeft(2, '0')}";
    return "$startLabel - $endLabel, ${start.year}";
  }

  String _weekdayLetter(int weekday) {
    switch (weekday) {
      case DateTime.sunday:
        return "Su";
      case DateTime.monday:
        return "M";
      case DateTime.tuesday:
        return "T";
      case DateTime.wednesday:
        return "W";
      case DateTime.thursday:
        return "Th";
      case DateTime.friday:
        return "F";
      case DateTime.saturday:
        return "Sa";      
      default:
        return "";
    }
  }

  // Optional day header (not used for day cells anymore, kept if needed)
  Widget _buildDayHeader() {
    final DateTime day = _selectedDay ?? _focusedDay;
    final String formatted =
        "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final newDay = day.subtract(const Duration(days: 1));
              setState(() {
                _selectedDay = newDay;
                _focusedDay = newDay;
                _fetchScheduledCallsCount(_focusedDay);
              });
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  formatted,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_weekdayName(day.weekday)}",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final newDay = day.add(const Duration(days: 1));
              setState(() {
                _selectedDay = newDay;
                _focusedDay = newDay;
                _fetchScheduledCallsCount(_focusedDay);
              });
            },
          ),
        ],
      ),
    );
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.sunday:
        return "Sunday";
      case DateTime.monday:
        return "Monday";
      case DateTime.tuesday:
        return "Tuesday";
      case DateTime.wednesday:
        return "Wednesday";
      case DateTime.thursday:
        return "Thursday";
      case DateTime.friday:
        return "Friday";
      case DateTime.saturday:
        return "Saturday";
      default:
        return "";
    }
  }

  /// TIME SLOT AREA FOR DAY VIEW (6 AM - 10 PM)
  Widget _buildDayTimeSlots() {
    // 6 AM to 10 PM = 16 hours (6,7,...,22)
    final List<int> hours = List.generate(16, (index) => 6 + index);

    return SizedBox(
      height: 600, // you can tweak this for your screen
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        itemCount: hours.length,
        itemBuilder: (context, index) {
          final hour = hours[index];
          final timeOfDay = TimeOfDay(hour: hour, minute: 0);
          final formattedLabel =
              "${timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod}:00 ${timeOfDay.period == DayPeriod.am ? 'AM' : 'PM'}";

          return SizedBox(
            height: 60,
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      formattedLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 1,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Container(
                          // This is where you could later overlay events for that hour.
                          color: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int maxCalls = _scheduledCallsCount.isNotEmpty
        ? _scheduledCallsCount.values.reduce(max)
        : 1;

    final String? selectedDateKey =
        _selectedDay != null ? _dateKey(_selectedDay!) : null;
    final String? selectedOffFieldReason = (selectedDateKey != null)
        ? _offFieldReasons[selectedDateKey]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Itinerary'),
        centerTitle: true,
        elevation: 4,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF4e2f80),
                Color(0xFF60448d),
                Color(0xFF715999),
                Color(0xFF836da6),
                Color(0xFF9582b3),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'call_off_field') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CallOffFieldPage(emailKey: emailKey),
                  ),
                ).then((_) {
                  _fetchScheduledCallsCount(_focusedDay);
                });
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'call_off_field',
                child: Text('Call Off Field'),
              ),
            ],
          ),
        ],
      ),
      body: emailKey.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // VIEW SELECTOR ROW (Day / Week / Month)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          _buildViewSelectorChip(label: 'Day', index: 0),
                          _buildViewSelectorChip(label: 'Week', index: 1),
                          _buildViewSelectorChip(label: 'Month', index: 2),
                        ],
                      ),
                    ),

                    // CALENDAR / DAY HEADER AREA
                    if (_selectedViewIndex == 0) ...[
                      // DAY VIEW: 7‑day week strip with arrows
                      _buildDayWeekStrip(),
                      // TIME SLOTS UNDER THE DAY STRIP
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: _buildDayTimeSlots(),
                      ),
                    ] else
                      // WEEK / MONTH: keep TableCalendar (month view for now)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 12),
                        child: TableCalendar(
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          rowHeight: 105,
                          daysOfWeekHeight: 40,
                          firstDay: DateTime.utc(2010, 1, 1),
                          lastDay: DateTime.utc(2050, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(day, _selectedDay) ||
                              (isSameDay(day, DateTime.now()) &&
                                  _selectedDay == null),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            setState(() {
                              _focusedDay = focusedDay;
                            });
                            _fetchScheduledCallsCount(focusedDay);
                          },
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, date, focusedDay) {
                              final key = _dateKey(date);
                              int count = _scheduledCallsCount[key] ?? 0;
                              final hasOffField =
                                  _offFieldReasons.containsKey(key);
                              final bool isToday =
                                  isSameDay(date, DateTime.now());
                              final bool isSelected = _selectedDay != null &&
                                  isSameDay(date, _selectedDay!);
                              if (isToday && isSelected) {
                                // today + selected
                                return _buildTodaySelectedCell(
                                  context,
                                  date,
                                  count,
                                  hasOffField: hasOffField,
                                );
                              } else if (isToday) {
                                // today only
                                return _buildTodayCell(
                                  context,
                                  date,
                                  count,
                                  hasOffField: hasOffField,
                                );
                              } else if (isSelected) {
                                // selected but not today
                                return _buildSelectedDayCell(
                                  context,
                                  date,
                                  count,
                                  hasOffField: hasOffField,
                                );
                              }
                              return _buildDayCell(
                                context,
                                date,
                                count,
                                maxCalls,
                                hasOffField: hasOffField,
                              );
                            },
                            todayBuilder: (context, date, focusedDay) {
                              final key = _dateKey(date);
                              int count = _scheduledCallsCount[key] ?? 0;
                              final hasOffField =
                                  _offFieldReasons.containsKey(key);
                              final bool isSelected = _selectedDay != null &&
                                  isSameDay(date, _selectedDay!);
                              if (isSelected) {
                                return _buildTodaySelectedCell(
                                  context,
                                  date,
                                  count,
                                  hasOffField: hasOffField,
                                );
                              }
                              return _buildTodayCell(
                                context,
                                date,
                                count,
                                hasOffField: hasOffField,
                              );
                            },
                            selectedBuilder: (context, date, focusedDay) {
                              final key = _dateKey(date);
                              int count = _scheduledCallsCount[key] ?? 0;
                              final hasOffField =
                                  _offFieldReasons.containsKey(key);
                              final bool isToday =
                                  isSameDay(date, DateTime.now());
                              if (isToday) {
                                return _buildTodaySelectedCell(
                                  context,
                                  date,
                                  count,
                                  hasOffField: hasOffField,
                                );
                              }
                              return _buildSelectedDayCell(
                                context,
                                date,
                                count,
                                hasOffField: hasOffField,
                              );
                            },
                          ),
                          calendarStyle: const CalendarStyle(
                            todayDecoration: BoxDecoration(),
                            selectedDecoration: BoxDecoration(),
                            defaultDecoration: BoxDecoration(),
                            weekendDecoration: BoxDecoration(),
                            outsideDecoration: BoxDecoration(),
                            cellMargin: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),

                    if (_selectedDay != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                        child: Row(
                          children: const [],
                        ),
                      ),
                    if (selectedOffFieldReason != null &&
                        selectedOffFieldReason.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Card(
                          color: Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Off Field",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        selectedOffFieldReason,
                                        style: TextStyle(
                                          color: Colors.red.shade900,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return _scheduledCallsColumn(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _scheduledCallsColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 6, bottom: 8, top: 8),
          child: Center(
            child: Text(
              "Upcoming Visits",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5958b2),
              ),
            ),
          ),
        ),
        (emailKey.isEmpty)
            ? SizedBox(
                height: 140,
                child: const Center(child: CircularProgressIndicator()),
              )
            : FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('flowDB')
                    .doc('users')
                    .collection(emailKey)
                    .doc('doctors')
                    .collection('doctors')
                    .get(),
                builder: (context, doctorSnapshot) {
                  if (!doctorSnapshot.hasData) {
                    return SizedBox(
                      height: 140,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  final doctorDocs = doctorSnapshot.data!.docs;
                  if (doctorDocs.isEmpty) {
                    return SizedBox(
                      height: 140,
                      child: const Center(child: Text("No farmers found")),
                    );
                  }
                  // Use _selectedDay (or today as fallback) for both Month and Day view.
                  final dayForList = _selectedDay ?? DateTime.now();
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getAllScheduledVisitsForSelectedDay(
                        doctorDocs, dayForList),
                    builder: (context, visitsSnapshot) {
                      if (!visitsSnapshot.hasData) {
                        return SizedBox(
                          height: 140,
                          child: const Center(
                              child: CircularProgressIndicator()),
                        );
                      }
                      final visitsForDay = visitsSnapshot.data!;
                      if (visitsForDay.isEmpty) {
                        return SizedBox(
                          height: 140,
                          child: const Center(
                              child: Text("No scheduled calls for this date")),
                        );
                      }

                      final now = DateTime.now();
                      return ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: visitsForDay.length,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        itemBuilder: (context, idx) {
                          final visit = visitsForDay[idx];
                          final visitData = visit['visitData'];
                          final scheduledDateStr =
                              visitData['scheduledDate'] ?? '';
                          final bool isSubmitted =
                              visitData['submitted'] == true;
                          final bool isSurprise =
                              visitData['surprise'] == true;

                          DateTime? visitDate;
                          try {
                            visitDate = DateTime.parse(scheduledDateStr);
                          } catch (_) {
                            visitDate = null;
                          }

                          Color cardColor = Colors.grey.shade200;
                          if (isSurprise) {
                            cardColor = Colors.yellow.shade300;
                          } else if (isSubmitted) {
                            cardColor = Colors.green.shade200;
                          } else if (visitDate != null &&
                              DateTime(now.year, now.month, now.day)
                                  .isAfter(visitDate)) {
                            cardColor = Colors.red.shade200;
                          }

                          return Card(
                            color: cardColor,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 27,
                                backgroundColor: Colors.transparent,
                                child: Text(
                                  (() {
                                    final fullName =
                                        (visit['doctorName'] ?? "") as String;
                                    if (fullName.trim().isEmpty) return "DR";
                                    final parts = fullName
                                        .trim()
                                        .split(RegExp(r'\s+'));
                                    if (parts.length == 1) {
                                      return parts[0].isNotEmpty
                                          ? parts[0]
                                              .substring(0, 1)
                                              .toUpperCase()
                                          : "DR";
                                    }
                                    return (parts[0].substring(0, 1) +
                                            parts[1].substring(0, 1))
                                        .toUpperCase();
                                  })(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              title: Text(
                                visit['doctorName'] ?? '-',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (visit['hospital'] != null &&
                                      visit['hospital'] != '')
                                    Text("${visit['hospital']}"),
                                  Text("${visit['specialty']}"),
                                  const SizedBox(height: 10),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CallDetailPage(
                                      doctor: visit['doctor'],
                                      scheduledVisitId: visit['visitId'],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
      ],
    );
  }

  // Normal day cell (non‑today, non‑selected)
  Widget _buildDayCell(
    BuildContext context,
    DateTime date,
    int count,
    int maxCount, {
    bool hasOffField = false,
  }) {
    final key = _dateKey(date);
    final colorCounts = _barColorCounts[key] ??
        {"red": 0, "yellow": 0, "green": 0, "white": 0};
    final total = colorCounts.values.fold(0, (a, b) => a + b);

    final segmentColors = {
      "red": Colors.redAccent.shade200,
      "yellow": Colors.yellowAccent.shade200,
      "green": Colors.lightGreenAccent.shade200,
      "white": Colors.white,
    };

    final colorKeys =
        colorCounts.entries.where((e) => e.value > 0).map((e) => e.key).toList();

    List<Widget> barSegments = [];
    for (int i = 0; i < colorKeys.length; i++) {
      final color = colorKeys[i];
      final value = colorCounts[color]!;
      barSegments.add(
        Expanded(
          flex: value,
          child: Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: segmentColors[color],
              borderRadius: BorderRadius.horizontal(
                left: i == 0 ? const Radius.circular(4) : Radius.zero,
                right: i == colorKeys.length - 1
                    ? const Radius.circular(4)
                    : Radius.zero,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 105,
      width: 80,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Stack(
          children: [
            if (hasOffField)
              const Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.circle,
                  size: 8,
                  color: Colors.red,
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${date.day}',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (total > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: barSegments,
                        ),
                      ),
                    ),
                  if (total > 0) const SizedBox(height: 4),
                  if (total > 0)
                    Text(
                      '$total',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.purple.shade400,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Today but NOT selected – solid green cell
  Widget _buildTodayCell(
    BuildContext context,
    DateTime date,
    int count, {
    bool hasOffField = false,
  }) {
    final key = _dateKey(date);
    final colorCounts = _barColorCounts[key] ??
        {"red": 0, "yellow": 0, "green": 0, "white": 0};
    final total = colorCounts.values.fold(0, (a, b) => a + b);

    final segmentColors = {
      "red": Colors.redAccent.shade100,
      "yellow": Colors.yellowAccent.shade100,
      "green": Colors.lightGreenAccent.shade100,
      "white": Colors.white,
    };

    final colorKeys =
        colorCounts.entries.where((e) => e.value > 0).map((e) => e.key).toList();

    List<Widget> barSegments = [];
    for (int i = 0; i < colorKeys.length; i++) {
      final color = colorKeys[i];
      final value = colorCounts[color]!;
      barSegments.add(
        Expanded(
          flex: value,
          child: Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: segmentColors[color],
              borderRadius: BorderRadius.horizontal(
                left: i == 0 ? const Radius.circular(4) : Radius.zero,
                right: i == colorKeys.length - 1
                    ? const Radius.circular(4)
                    : Radius.zero,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 105,
      width: 80,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green.shade500,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            if (hasOffField)
              const Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.circle,
                  size: 8,
                  color: Colors.white,
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${date.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (total > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: barSegments,
                        ),
                      ),
                    ),
                  if (total > 0) const SizedBox(height: 4),
                  if (total > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$total',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Selected but NOT today – purple gradient cell
  Widget _buildSelectedDayCell(
    BuildContext context,
    DateTime date,
    int count, {
    bool hasOffField = false,
  }) {
    final key = _dateKey(date);
    final colorCounts = _barColorCounts[key] ??
        {"red": 0, "yellow": 0, "green": 0, "white": 0};
    final total = colorCounts.values.fold(0, (a, b) => a + b);

    final segmentColors = {
      "red": Colors.redAccent.shade100,
      "yellow": Colors.yellowAccent.shade100,
      "green": Colors.lightGreenAccent.shade100,
      "white": Colors.white.withOpacity(0.4),
    };

    final colorKeys =
        colorCounts.entries.where((e) => e.value > 0).map((e) => e.key).toList();

    List<Widget> barSegments = [];
    for (int i = 0; i < colorKeys.length; i++) {
      final color = colorKeys[i];
      final value = colorCounts[color]!;
      barSegments.add(
        Expanded(
          flex: value,
          child: Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: segmentColors[color],
              borderRadius: BorderRadius.horizontal(
                left: i == 0 ? const Radius.circular(4) : Radius.zero,
                right: i == colorKeys.length - 1
                    ? const Radius.circular(4)
                    : Radius.zero,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 105,
      width: 80,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF8a00ff),
              Color(0xFFb000ff),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            if (hasOffField)
              const Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.circle,
                  size: 8,
                  color: Colors.white,
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${date.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (total > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: barSegments,
                        ),
                      ),
                    ),
                  if (total > 0) const SizedBox(height: 4),
                  if (total > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$total',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Today + selected – combined green + purple gradient
  Widget _buildTodaySelectedCell(
    BuildContext context,
    DateTime date,
    int count, {
    bool hasOffField = false,
  }) {
    final key = _dateKey(date);
    final colorCounts = _barColorCounts[key] ??
        {"red": 0, "yellow": 0, "green": 0, "white": 0};
    final total = colorCounts.values.fold(0, (a, b) => a + b);

    final segmentColors = {
      "red": Colors.redAccent.shade100,
      "yellow": Colors.yellowAccent.shade100,
      "green": Colors.lightGreenAccent.shade100,
      "white": Colors.white.withOpacity(0.4),
    };

    final colorKeys =
        colorCounts.entries.where((e) => e.value > 0).map((e) => e.key).toList();

    List<Widget> barSegments = [];
    for (int i = 0; i < colorKeys.length; i++) {
      final color = colorKeys[i];
      final value = colorCounts[color]!;
      barSegments.add(
        Expanded(
          flex: value,
          child: Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: segmentColors[color],
              borderRadius: BorderRadius.horizontal(
                left: i == 0 ? const Radius.circular(4) : Radius.zero,
                right: i == colorKeys.length - 1
                    ? const Radius.circular(4)
                    : Radius.zero,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 105,
      width: 80,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF00c853), // green
              Color(0xFF8a00ff), // purple
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            if (hasOffField)
              const Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.circle,
                  size: 8,
                  color: Colors.white,
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${date.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (total > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: barSegments,
                        ),
                      ),
                    ),
                  if (total > 0) const SizedBox(height: 4),
                  if (total > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$total',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
