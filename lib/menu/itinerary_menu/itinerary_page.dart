import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../doctor_menu/call_detail_page.dart';
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
  Map<String, String> _offFieldReasons = {};

  String emailKey = '';
  String _userClientType = '';
  String _userId = ''; // MR id that matches Daloy path

  int _selectedViewIndex = 2;

  bool _isOffline = false;

  final ScrollController _doctorsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUserPrefs();
  }

  @override
  void dispose() {
    _doctorsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    final clientType = prefs.getString('userClientType') ?? 'pharma';
    final userId = prefs.getString('userId') ?? ''; // MR001 etc.

    setState(() {
      emailKey = userEmail.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
      _userClientType = clientType;
      _userId = userId;
    });

    if (_userId.isNotEmpty && _userClientType.isNotEmpty) {
      await _fetchScheduledCallsCount(_focusedDay);
      if (mounted) setState(() {});
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _monthId(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// Doctors under new Daloy structure:
  /// /DaloyClients/IVA/Users/{_userId}/Doctor
  CollectionReference<Map<String, dynamic>> _doctorsCollectionRef() {
    return FirebaseFirestore.instance
        .collection('DaloyClients')
        .doc('IVA')
        .collection('Users')
        .doc(_userId.isEmpty ? '_DUMMY' : _userId)
        .collection('Doctor');
  }

  /// Itinerary for a given day:
  /// /DaloyClients/IVA/Users/{_userId}/Calendar/{yyyy-MM}/Days/{d}/Itinerary
  CollectionReference<Map<String, dynamic>> _calendarItineraryCollectionForDay(
    DateTime day,
  ) {
    final monthId = _monthId(day); // yyyy-MM
    final dayId = day.day.toString(); // "6", etc.

    return FirebaseFirestore.instance
        .collection('DaloyClients')
        .doc('IVA')
        .collection('Users')
        .doc(_userId.isEmpty ? '_DUMMY' : _userId)
        .collection('Calendar')
        .doc(monthId)
        .collection('Days')
        .doc(dayId)
        .collection('Itinerary');
  }

  Future<void> _fetchScheduledCallsCount(DateTime focusedDay) async {
    if (_userId.isEmpty || _userClientType.isEmpty) return;

    // Look at a small window of months around the focused month
    final first = DateTime.utc(focusedDay.year, focusedDay.month - 1, 20);
    final last = DateTime.utc(focusedDay.year, focusedDay.month + 2, 10);

    Map<String, int> counts = {};
    Map<String, Map<String, int>> colorCounts = {};
    Map<String, String> offFieldReasons = {};

    try {
      // Iterate months in window
      DateTime cursor = DateTime(first.year, first.month, 1);
      while (!cursor.isAfter(last)) {
        final monthId = _monthId(cursor);
        // Iterate days in that month
        final monthStart = DateTime(cursor.year, cursor.month, 1);
        final monthEnd = DateTime(cursor.year, cursor.month + 1, 0);

        for (int day = 1; day <= monthEnd.day; day++) {
          final currentDate = DateTime(cursor.year, cursor.month, day);
          if (currentDate.isBefore(first) || currentDate.isAfter(last)) {
            continue;
          }

          final itineraryCol =
              _calendarItineraryCollectionForDay(currentDate);

          final daySnap = await itineraryCol.get();
          if (daySnap.docs.isEmpty) continue;

          final dateString = _dateKey(currentDate);
          int dayCount = 0;
          colorCounts[dateString] ??= {
            "red": 0,
            "yellow": 0,
            "green": 0,
            "white": 0,
          };

          for (final doc in daySnap.docs) {
            final data = doc.data();
            dayCount++;

            final isSubmitted = data['submitted'] == true;
            final isSurprise = data['surprise'] == true;
            String colorKey = "white";

            if (isSurprise) {
              colorKey = "yellow";
            } else if (isSubmitted) {
              colorKey = "green";
            } else {
              // For past, not-submitted visits, mark red
              final nowCut = DateTime.now();
              if (DateTime(nowCut.year, nowCut.month, nowCut.day)
                  .isAfter(currentDate)) {
                colorKey = "red";
              }
            }

            colorCounts[dateString]![colorKey] =
                (colorCounts[dateString]![colorKey] ?? 0) + 1;

            final offFieldValue = data['offField'];
            if (offFieldValue != null &&
                offFieldValue.toString().trim().isNotEmpty) {
              offFieldReasons.putIfAbsent(
                dateString,
                () => offFieldValue.toString().trim(),
              );
            }
          }

          counts[dateString] = (counts[dateString] ?? 0) + dayCount;
        }

        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
    } catch (e) {
      debugPrint('Error in _fetchScheduledCallsCount (Itinerary): $e');
    }

    if (!mounted) return;
    setState(() {
      _scheduledCallsCount = counts;
      _barColorCounts = colorCounts;
      _offFieldReasons = offFieldReasons;
    });
  }

  /// Reads itinerary docs for the selected day and joins them with doctor data.
  ///
  /// Each itinerary doc is expected to have:
  /// - doctorId
  /// - scheduledDate (yyyyMMdd or yyyy-MM-dd)
  /// - scheduledTime
  /// - Reference: DocumentReference to this itinerary doc (already known, optional)
  ///
  /// We map to the same structure used by the cards in _buildScheduledDoctorsRow.
  Future<List<Map<String, dynamic>>> getAllScheduledVisitsForSelectedDay(
    List<QueryDocumentSnapshot> doctorDocs,
    DateTime selectedDay,
  ) async {
    if (_userId.isEmpty || _userClientType.isEmpty) return [];

    final List<Map<String, dynamic>> allVisits = [];

    final itineraryCol =
        _calendarItineraryCollectionForDay(selectedDay);
    final daySnap = await itineraryCol.get();

    if (daySnap.docs.isEmpty) return [];

    // Build a map of doctorId -> doctorData for quick lookup
    final Map<String, Map<String, dynamic>> doctorById = {};
    for (final d in doctorDocs) {
      final data = d.data() as Map<String, dynamic>;
      final doctorId = data['doc_id']?.toString() ?? d.id;
      doctorById[doctorId] = data;
    }

    for (final doc in daySnap.docs) {
      final data = doc.data();
      final doctorId = data['doctorId']?.toString() ?? '';
      if (doctorId.isEmpty) continue;

      final doctorData = doctorById[doctorId];
      if (doctorData == null) {
        // Optionally, you could fetch doctor directly via ref if stored
        continue;
      }

      final doctorName =
          "${doctorData['lastName'] ?? ''}, ${doctorData['firstName'] ?? ''}";
      final scheduledTime = data['scheduledTime']?.toString() ?? '';
      final hospital = doctorData['hospital']?.toString() ?? '';

      allVisits.add({
        'doctorName': doctorName,
        'scheduledTime': scheduledTime,
        'hospital': hospital,
        'specialty': doctorData['specialty'] ?? '',
        'doctor': doctorData,
        'doctorId': doctorId,
        'visitId': doc.id,
        'visitData': data,
      });
    }

    allVisits.sort((a, b) =>
        (a['scheduledTime'] ?? '').compareTo(b['scheduledTime'] ?? ''));

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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

  DateTime _startOfWeek(DateTime date) {
    final int weekday = date.weekday;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: weekday - 1));
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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

  Widget _buildDayHeader() {
    final DateTime day = _selectedDay ?? _focusedDay;
    final String formatted =
        "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  _weekdayName(day.weekday),
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

  Widget _buildDayTimeSlots() {
    final List<int> hours = List.generate(16, (index) => 6 + index);

    return SizedBox(
      height: 600,
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

  String _doctorInitials(String fullName) {
    if (fullName.trim().isEmpty) return "DR";
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) +
            parts[1].substring(0, 1))
        .toUpperCase();
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
      body: _userId.isEmpty || _userClientType.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 12),
                      child: TableCalendar(
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
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
                            int count =
                                _scheduledCallsCount[key] ?? 0;
                            final hasOffField =
                                _offFieldReasons.containsKey(key);
                            final bool isToday =
                                isSameDay(date, DateTime.now());
                            final bool isSelected = _selectedDay != null &&
                                isSameDay(date, _selectedDay!);
                            if (isToday && isSelected) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDay = date;
                                    _focusedDay = date;
                                  });
                                },
                                child: _buildTodaySelectedCell(
                                  context,
                                  date,
                                  count,
                                  hasOffField: hasOffField,
                                ),
                              );
                            } else if (isToday) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDay = date;
                                    _focusedDay = date;
                                  });
                                },
                                child: _buildTodayCell(
                                  context,
                                  date,
                                  count,
                                  hasOffField: hasOffField,
                                ),
                              );
                            } else if (isSelected) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDay = date;
                                    _focusedDay = date;
                                  });
                                },
                                child: _buildSelectedDayCell(
                                  context,
                                  date,
                                  count,
                                  hasOffField: hasOffField,
                                ),
                              );
                            }
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDay = date;
                                  _focusedDay = date;
                                });
                              },
                              child: _buildDayCell(
                                context,
                                date,
                                count,
                                maxCalls,
                                hasOffField: hasOffField,
                              ),
                            );
                          },
                          todayBuilder: (context, date, focusedDay) {
                            final key = _dateKey(date);
                            int count =
                                _scheduledCallsCount[key] ?? 0;
                            final hasOffField =
                                _offFieldReasons.containsKey(key);
                            final bool isSelected = _selectedDay != null &&
                                isSameDay(date, _selectedDay!);
                            if (isSelected) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDay = date;
                                    _focusedDay = date;
                                  });
                                },
                                child: _buildTodaySelectedCell(
                                  context,
                                  date,
                                  count,
                                  hasOffField: hasOffField,
                                ),
                              );
                            }
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDay = date;
                                  _focusedDay = date;
                                });
                              },
                              child: _buildTodayCell(
                                context,
                                date,
                                count,
                                hasOffField: hasOffField,
                              ),
                            );
                          },
                          selectedBuilder:
                              (context, date, focusedDay) {
                            final key = _dateKey(date);
                            int count =
                                _scheduledCallsCount[key] ?? 0;
                            final hasOffField =
                                _offFieldReasons.containsKey(key);
                            final bool isToday =
                                isSameDay(date, DateTime.now());
                            if (isToday) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDay = date;
                                    _focusedDay = date;
                                  });
                                },
                                child: _buildTodaySelectedCell(
                                  context,
                                  date,
                                  count,
                                  hasOffField: hasOffField,
                                ),
                              );
                            }
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDay = date;
                                  _focusedDay = date;
                                });
                              },
                              child: _buildSelectedDayCell(
                                context,
                                date,
                                count,
                                hasOffField: hasOffField,
                              ),
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
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
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
                                          fontWeight:
                                              FontWeight.bold,
                                          color:
                                              Colors.red.shade800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        selectedOffFieldReason,
                                        style: TextStyle(
                                          color:
                                              Colors.red.shade900,
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
                      child: _scheduledCallsColumn(context),
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
          padding:
              EdgeInsets.only(left: 6, bottom: 8, top: 8),
          child: Center(
            child: Text(
              "Scheduled Visits",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5958b2),
              ),
            ),
          ),
        ),
        if (_userId.isEmpty || _userClientType.isEmpty)
          SizedBox(
            height: 160,
            child: const Center(child: CircularProgressIndicator()),
          )
        else
          FutureBuilder<QuerySnapshot>(
            future: _doctorsCollectionRef()
                .get()
                .timeout(
                  const Duration(seconds: 10),
                  onTimeout: () {
                    throw TimeoutException(
                        'Failed to load doctors data');
                  },
                ),
            builder: (context, doctorSnapshot) {
              if (doctorSnapshot.hasError) {
                debugPrint(
                    'Error loading doctors: ${doctorSnapshot.error}');
                return SizedBox(
                  height: 160,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'Error loading doctors\n${doctorSnapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 12),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (doctorSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return SizedBox(
                  height: 160,
                  child: const Center(
                      child: CircularProgressIndicator()),
                );
              }

              if (!doctorSnapshot.hasData ||
                  doctorSnapshot.data!.docs.isEmpty) {
                return SizedBox(
                  height: 160,
                  child: Center(
                    child: Text(
                      _isOffline
                          ? 'Offline: showing last available data from cache.'
                          : 'No doctors found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }

              final doctorDocs = doctorSnapshot.data!.docs;
              final selectedDayForVisits =
                  _selectedDay ?? DateTime.now();

              return FutureBuilder<List<Map<String, dynamic>>>(
                future: getAllScheduledVisitsForSelectedDay(
                  doctorDocs,
                  selectedDayForVisits,
                ).timeout(
                  const Duration(seconds: 10),
                  onTimeout: () {
                    debugPrint(
                        'Timeout loading scheduled visits for selected day');
                    return <Map<String, dynamic>>[];
                  },
                ),
                builder: (context, visitsSnapshot) {
                  if (visitsSnapshot.hasError) {
                    debugPrint(
                        'Error loading visits: ${visitsSnapshot.error}');
                    return SizedBox(
                      height: 160,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            'Error loading visits\n${visitsSnapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {});
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (visitsSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      !visitsSnapshot.hasData) {
                    return SizedBox(
                      height: 160,
                      child: const Center(
                          child: CircularProgressIndicator()),
                    );
                  }

                  if (!visitsSnapshot.hasData ||
                      visitsSnapshot.data!.isEmpty) {
                    return SizedBox(
                      height: 160,
                      child: Center(
                        child: Text(
                          _isOffline
                              ? 'Offline: showing cached schedule (none cached for this day).'
                              : 'No scheduled visits for this date.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final visitsForDay = visitsSnapshot.data!;
                  return _buildScheduledDoctorsRow(visitsForDay);
                },
              );
            },
          ),
      ],
    );
  }

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

    final colorKeys = colorCounts.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList();

    List<Widget> barSegments = [];
    for (int i = 0; i < colorKeys.length; i++) {
      final color = colorKeys[i];
      final value = colorCounts[color]!;
      barSegments.add(
        Expanded(
          flex: value,
          child: Container(
            height: 8,
            margin:
                const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: segmentColors[color],
              borderRadius: BorderRadius.horizontal(
                left: i == 0
                    ? const Radius.circular(4)
                    : Radius.zero,
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
          border: Border.all(
              color: Colors.grey.shade300, width: 1),
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
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 10),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.center,
                          children: barSegments,
                        ),
                      ),
                    ),
                  if (total > 0)
                    const SizedBox(height: 4),
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

    final colorKeys = colorCounts.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList();

    List<Widget> barSegments = [];
    for (int i = 0; i < colorKeys.length; i++) {
      final color = colorKeys[i];
      final value = colorCounts[color]!;
      barSegments.add(
        Expanded(
          flex: value,
          child: Container(
            height: 8,
            margin:
                const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: segmentColors[color],
              borderRadius: BorderRadius.horizontal(
                left: i == 0
                    ? const Radius.circular(4)
                    : Radius.zero,
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
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 10),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.center,
                          children: barSegments,
                        ),
                      ),
                    ),
                  if (total > 0)
                    const SizedBox(height: 4),
                  if (total > 0)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withOpacity(0.25),
                        borderRadius:
                            BorderRadius.circular(10),
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

    final colorKeys = colorCounts.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList();

    List<Widget> barSegments = [];
    for (int i = 0; i < colorKeys.length; i++) {
      final color = colorKeys[i];
      final value = colorCounts[color]!;
      barSegments.add(
        Expanded(
          flex: value,
          child: Container(
            height: 8,
            margin:
                const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: segmentColors[color],
              borderRadius: BorderRadius.horizontal(
                left: i == 0
                    ? const Radius.circular(4)
                    : Radius.zero,
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF8a00ff),
              Color(0xFFb000ff),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.all(Radius.circular(14)),
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
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 10),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.center,
                          children: barSegments,
                        ),
                      ),
                    ),
                  if (total > 0)
                    const SizedBox(height: 4),
                  if (total > 0)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withOpacity(0.25),
                        borderRadius:
                            BorderRadius.circular(10),
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

    final colorKeys = colorCounts.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList();

    List<Widget> barSegments = [];
    for (int i = 0; i < colorKeys.length; i++) {
      final color = colorKeys[i];
      final value = colorCounts[color]!;
      barSegments.add(
        Expanded(
          flex: value,
          child: Container(
            height: 8,
            margin:
                const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: segmentColors[color],
              borderRadius: BorderRadius.horizontal(
                left: i == 0
                    ? const Radius.circular(4)
                    : Radius.zero,
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF00c853),
              Color(0xFF8a00ff),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.all(Radius.circular(14)),
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
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 10),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.center,
                          children: barSegments,
                        ),
                      ),
                    ),
                  if (total > 0)
                    const SizedBox(height: 4),
                  if (total > 0)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withOpacity(0.25),
                        borderRadius:
                            BorderRadius.circular(10),
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

  Widget _buildScheduledDoctorsRow(
      List<Map<String, dynamic>> visitsForDay) {
    const double badgeOverflow = 10.0;
    const double shadowPadding = 12.0;
    const double minCardWidth = 280.0;
    const double maxCardWidth = 380.0;
    const double charsPerLine = 18.0;
    const double extraWidthPerChar = 7.0;
    const double cardHeight = 180.0;

    final String longestName = visitsForDay
        .map((v) => (v['doctorName'] as String? ?? ''))
        .reduce((a, b) => a.length > b.length ? a : b);

    final double cardWidth = longestName.length > charsPerLine
        ? (minCardWidth +
                (longestName.length - charsPerLine) *
                    extraWidthPerChar)
            .clamp(minCardWidth, maxCardWidth)
        : minCardWidth;

    return SizedBox(
      height: cardHeight + badgeOverflow + shadowPadding,
      child: ListView.builder(
        controller: _doctorsScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(
            left: 5,
            top: badgeOverflow,
            bottom: shadowPadding),
        itemCount: visitsForDay.length,
        itemBuilder: (context, idx) {
          final visit = visitsForDay[idx];
          final visitData = visit['visitData'] as Map<String, dynamic>;
          final String scheduledTime =
              visit['scheduledTime'] as String? ?? '';
          final String doctorName =
              visit['doctorName'] as String? ?? '-';
          final String hospital =
              visit['hospital'] as String? ?? '';
          final bool isUnplanned = visitData['unplanned'] == true;
          final String visitTypeLabel =
              isUnplanned ? '(Unplanned)' : '(Planned)';

          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: cardWidth + badgeOverflow,
                height: cardHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: badgeOverflow,
                      top: 0,
                      child: Container(
                        width: cardWidth,
                        height: cardHeight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: 0.07),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CallDetailPage(
                                  doctor: visit['doctor']
                                      as Map<String, dynamic>,
                                  scheduledVisitId:
                                      visit['visitId'] as String,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(
                                    12, 14, 12, 12),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration:
                                          BoxDecoration(
                                        color:
                                            const Color(0xFFF0F0F2),
                                        borderRadius:
                                            BorderRadius
                                                .circular(8),
                                      ),
                                      child: const Icon(
                                        Icons
                                            .assignment_outlined,
                                        size: 26,
                                        color:
                                            Color(0xFF5A5A7A),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        mainAxisSize:
                                            MainAxisSize.min,
                                        children: [
                                          const Text(
                                            "Doctor's Visit",
                                            style: TextStyle(
                                              fontFamily:
                                                  'OpenSauce',
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                              fontSize: 12,
                                              color: Colors
                                                  .black87,
                                            ),
                                          ),
                                          Text(
                                            visitTypeLabel,
                                            style: TextStyle(
                                              fontFamily:
                                                  'OpenSauce',
                                              fontWeight:
                                                  FontWeight
                                                      .w500,
                                              fontSize: 10,
                                              color: Colors
                                                  .grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  doctorName,
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'OpenSauce',
                                    fontWeight:
                                        FontWeight.w700,
                                    fontSize: 16,
                                    color: Colors.black87,
                                    height: 1.2,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black
                                            .withValues(
                                                alpha: 0.15),
                                        blurRadius: 0,
                                        offset:
                                            const Offset(0.4, 0),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  scheduledTime,
                                  style: TextStyle(
                                    fontFamily: 'OpenSauce',
                                    fontWeight:
                                        FontWeight.w400,
                                    fontSize: 14,
                                    color:
                                        Colors.grey.shade700,
                                  ),
                                ),
                                if (hospital.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    hospital,
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily:
                                          'OpenSauce',
                                      fontWeight:
                                          FontWeight.w400,
                                      fontSize: 12,
                                      color: Colors
                                          .grey.shade600,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}