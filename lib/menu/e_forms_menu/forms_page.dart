import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'attendance_form_transactions_page.dart';
import 'scp_form_transactions_page.dart';
import 'abr_form_transactions_page.dart';
import 'in_field_coaching_form_transactions_page.dart';
import 'sales_order_form_page.dart';
import 'incidental_coverage_form_page.dart';

class FormsPage extends StatefulWidget {
  const FormsPage({Key? key}) : super(key: key);

  @override
  State<FormsPage> createState() => _FormsPageState();
}

class _FormsPageState extends State<FormsPage> {
  // 0 = Attendance, 1 = SCP, 2 = ABR, 3 = In-Field Coaching, 4 = Incidental Coverage, 5 = Sales Order, 6 = WebView Form
  int _selectedIndex = -1;

  // userKey for Firestore path (shared by Attendance, SCP, ABR, etc.)
  String _userKey = '';

  @override
  void initState() {
    super.initState();
    _loadEmailKey();
  }

  Future<void> _loadEmailKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    setState(() {
      // IMPORTANT: keep this exactly the same pattern as when you WRITE to Firestore
      _userKey = userEmail.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_');
    });
  }

  Widget _buildSelectableFormChip({
    required String title,
    required int index,
  }) {
    final bool isSelected = _selectedIndex == index;
    final Color selectedColor = const Color(0xFF5e1398);
    final Color unselectedColor = Colors.grey.shade400;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
          child: Ink(
            decoration: BoxDecoration(
              color: isSelected ? selectedColor : unselectedColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              alignment: Alignment.center,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
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

  // =========================
  // ATTENDANCE HISTORY BODY
  // =========================
  Widget _buildAttendanceHistorySection(BuildContext context) {
    if (_userKey.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final double cardWidth = (MediaQuery.of(context).size.width - 48) / 2;
    final double cardHeight = 170.0;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(_userKey)
          .doc('attendance_forms')
          .collection('attendance_forms')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "No attendance forms yet. Tap + in the Attendance page to create a new.",
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: GridView.builder(
            itemCount: docs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cardWidth / cardHeight,
            ),
            itemBuilder: (context, idx) {
              final doc = docs[idx];
              final data = doc.data() as Map<String, dynamic>;
              final String eventName = data["eventName"] ?? "";
              final String date = data["date"] ?? "-";

              // Descending transaction number (first cell = highest)
              final transactionNumber = docs.length - idx;
              final transactionLabel = "Event #$transactionNumber";

              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AttendanceFormReadonlyPage(
                            formData: data,
                            docId: doc.id,
                            userKey: _userKey,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF54479d),
                            Color(0xFF826ca4),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.event_note,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    transactionLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    eventName.isNotEmpty
                                        ? eventName
                                        : "Unnamed Event",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Date: $date",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
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
                ),
              );
            },
          ),
        );
      },
    );
  }

  // =========================
  // SCP HISTORY BODY
  // =========================
  Widget _buildScpHistorySection(BuildContext context) {
    if (_userKey.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final double cardWidth = (MediaQuery.of(context).size.width - 48) / 2;
    final double cardHeight = 170.0;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(_userKey)
          .doc('scp_forms')
          .collection('scp_forms')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No SCP forms yet. Tap + in the SCP page to create a new.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: GridView.builder(
            itemCount: docs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cardWidth / cardHeight,
            ),
            itemBuilder: (context, idx) {
              final doc = docs[idx];
              final data = doc.data() as Map<String, dynamic>;

              final String farmerName =
                  data['farmerName'] ?? 'Unnamed Farmer';
              final String dateOfEvent = data['dateOfEvent'] ?? '-';
              final String cropsPlanted = data['cropsPlanted'] ?? '';

              // Descending transaction number (first cell = highest)
              final transactionNumber = docs.length - idx;
              final transactionLabel = 'SCP #$transactionNumber';

              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScpFormReadonlyPage(
                            formData: data,
                            docId: doc.id,
                            userKey: _userKey,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF54479d),
                            Color(0xFF826ca4),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.description_outlined,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    transactionLabel,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    farmerName,
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (cropsPlanted.isNotEmpty)
                                    Text(
                                      'Crop: $cropsPlanted',
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  Text(
                                    'Date: $dateOfEvent',
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
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
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Helper to mirror _formatTimestamp from AbrFormTransactionsPage
  String _formatAbrTimestamp(dynamic ts, String fallback) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
    return fallback;
  }

  // =========================
  // ABR HISTORY BODY
  // =========================
  Widget _buildAbrHistorySection(BuildContext context) {
    if (_userKey.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final double cardWidth = (MediaQuery.of(context).size.width - 48) / 2;
    final double cardHeight = 170.0;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(_userKey)
          .doc('abr_forms')
          .collection('abr_forms')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No ABR forms yet. Tap + in the ABR page to create a new.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: GridView.builder(
            itemCount: docs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cardWidth / cardHeight,
            ),
            itemBuilder: (context, idx) {
              final doc = docs[idx];
              final data = doc.data() as Map<String, dynamic>;

              final String activityName =
                  (data['agronomist'] as String?) ?? 'No agronomist';

              final dynamic ts = data['timestamp'];
              final String plannedDate =
                  (data['plannedDate'] as String?) ??
                      (data['plannedActivityDate'] as String?) ??
                      '';
              final String date = _formatAbrTimestamp(
                ts,
                plannedDate.isEmpty ? '-' : plannedDate,
              );

              final String location =
                  (data['plannedLocation'] as String?) ??
                      (data['plannedActivityLocation'] as String?) ??
                      (data['location'] as String?) ??
                      '';

              final transactionNumber = docs.length - idx;
              final transactionLabel = 'ABR #$transactionNumber';

              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AbrFormReadonlyPage(
                            formData: data,
                            docId: doc.id,
                            userKey: _userKey,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF54479d),
                            Color(0xFF826ca4),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.request_page_outlined,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    transactionLabel,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activityName,
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (location.isNotEmpty)
                                    Text(
                                      'Location: $location',
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  Text(
                                    'Date: $date',
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
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
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ================================
  // IN-FIELD COACHING HISTORY BODY
  // ================================
  Widget _buildInFieldCoachingHistorySection(BuildContext context) {
    if (_userKey.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final double cardWidth = (MediaQuery.of(context).size.width - 48) / 2;
    final double cardHeight = 170.0;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(_userKey)
          .doc('coaching_forms')
          .collection('coaching_forms')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "No coaching forms yet. Tap '+' in the In-Field Coaching page to create a new.",
              style: TextStyle(
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: GridView.builder(
            itemCount: docs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cardWidth / cardHeight,
            ),
            itemBuilder: (context, idx) {
              final QueryDocumentSnapshot doc = docs[idx];
              final Map<String, dynamic> dat =
                  doc.data() as Map<String, dynamic>;

              final String evaluator = dat['evaluator'] ?? '';
              final String position = dat['position'] ?? '';
              final String date = dat['date'] ?? '';

              final String title = '$evaluator - $position';

              // Descending transaction number (first cell = highest)
              final transactionNumber = docs.length - idx;
              final transactionLabel = 'Coaching #$transactionNumber';

              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              InFieldCoachingFormReadonlyPage(
                            formData: dat,
                            // if your readonly page later needs docId/userKey,
                            // you can add them here to match other sections
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF54479d),
                            Color(0xFF826ca4),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.school_outlined,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    transactionLabel,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    date,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
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
                ),
              );
            },
          ),
        );
      },
    );
  }

  // =======================================
  // INCIDENTAL COVERAGE HISTORY BODY
  // (inline version without AppBar)
  // =======================================
  Widget _buildIncidentalCoverageHistorySection(BuildContext context) {
    if (_userKey.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final double cardWidth = (MediaQuery.of(context).size.width - 48) / 2;
    final double cardHeight = 170.0;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(_userKey)
          .doc('inc_cov_forms')
          .collection('inc_cov_forms')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "No coverage forms yet. Tap + in the Incidental Coverage page to create a new one.",
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: GridView.builder(
            itemCount: docs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cardWidth / cardHeight,
            ),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title =
                  "${data['lastName'] ?? ''} ${data['firstName'] ?? ''}"
                      .trim();
              final date = data['dateOfCover'] ?? "-";

              // Descending transaction number: first cell is highest
              final transactionNumber = docs.length - index;
              final transactionLabel =
                  "Transaction #$transactionNumber";

              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              IncidentalCoverageFormPage(
                            formData: data,
                            readonly: true,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF54479d),
                            Color(0xFF826ca4),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.assignment,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    transactionLabel,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title.isNotEmpty
                                        ? title
                                        : "Unnamed Coverage",
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    date,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
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
                ),
              );
            },
          ),
        );
      },
    );
  }

  // =======================================
  // SALES ORDER HISTORY BODY (inline, no AppBar)
  // =======================================
  Widget _buildSalesOrderHistorySection(BuildContext context) {
    if (_userKey.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final double cardWidth = (MediaQuery.of(context).size.width - 48) / 2;
    final double cardHeight = 170.0;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(_userKey)
          .doc('sales_orders')
          .collection('sales_orders')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "No sales order forms yet. Tap + in the Sales Order page to create a new.",
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: GridView.builder(
            itemCount: docs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cardWidth / cardHeight,
            ),
            itemBuilder: (context, idx) {
              final data = docs[idx].data() as Map<String, dynamic>;
              final mrName = data["mrName"] ?? "";
              final soldTo = data["soldTo"] ?? "";
              final dateOfOrder = data["dateOfOrder"] ?? "-";

              // Descending transaction number (first cell = highest)
              final transactionNumber = docs.length - idx;
              final transactionLabel = "Transaction #$transactionNumber";

              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SalesOrderFormPage(
                            formData: data,
                            readonly: true,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF54479d),
                            Color(0xFF826ca4),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.receipt_long,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    transactionLabel,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mrName.isNotEmpty
                                        ? mrName
                                        : "Unnamed Sales Order",
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Sold to: $soldTo",
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Date: $dateOfOrder",
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
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
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Electronic Forms'),
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
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'E-Forms',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Manage and view your form submissions',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _buildSelectableFormChip(
                    title: 'Attendance Form',
                    index: 0,
                  ),
                  _buildSelectableFormChip(
                    title: 'Sample Crop Prescription',
                    index: 1,
                  ),
                  _buildSelectableFormChip(
                    title: 'Activity Budget Request',
                    index: 2,
                  ),
                  _buildSelectableFormChip(
                    title: 'In-Field Coaching Form',
                    index: 3,
                  ),
                  _buildSelectableFormChip(
                    title: 'Incidental Coverage Form',
                    index: 4,
                  ),
                  _buildSelectableFormChip(
                    title: 'Sales Order Form',
                    index: 5,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          if (_selectedIndex == 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Attendance Form History',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.9,
              child: _buildAttendanceHistorySection(context),
            ),
          ],

          if (_selectedIndex == 1) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Sample Crop Prescription History',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.9,
              child: _buildScpHistorySection(context),
            ),
          ],

          if (_selectedIndex == 2) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Activity Budget Request History',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.9,
              child: _buildAbrHistorySection(context),
            ),
          ],

          if (_selectedIndex == 3) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'In-Field Coaching Form History',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.9,
              // Use history section so the main app bar remains.
              child: _buildInFieldCoachingHistorySection(context),
            ),
          ],

          if (_selectedIndex == 4) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Incidental Coverage Form History',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.9,
              // Inline history (no AppBar) similar to others
              child: _buildIncidentalCoverageHistorySection(context),
            ),
          ],

          if (_selectedIndex == 5) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Sales Order Form History',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.9,
              // Inline history (no AppBar) for Sales Order
              child: _buildSalesOrderHistorySection(context),
            ),
          ],
        ],
      ),
    );
  }
}
