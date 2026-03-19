import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

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
  // 0 = Attendance, 1 = SCP, 2 = ABR, 3 = In-Field Coaching, 4 = Incidental Coverage, 5 = Sales Order
  int _selectedIndex = -1;

  // userKey for Firestore path (shared by all forms)
  String _userKey = '';

  /// Direct Firebase Storage URLs for the ZIP E-Forms.
  static const String _attendanceZipUrl =
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fattendance_form_page.zip?alt=media&token=532871f5-2390-402f-b92d-55b2dec6678a';

  static const String _scpZipUrl =
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fscp_form_page.zip?alt=media&token=0b06e88b-3d7c-4b09-afb1-2c5143459a2f';

  static const String _abrZipUrl =
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fabr_form_page.zip?alt=media&token=33bc30fc-ef29-4689-a5bf-5f2e9cd9b8fe';

  static const String _inFieldZipUrl =
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fin_field_coaching_form_page.zip?alt=media&token=6008a747-70e8-48fb-9938-c1d752c6fda7';

  static const String _incidentalZipUrl =
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fincidental_coverage_form_page.zip?alt=media&token=19525e5f-8c10-4927-beeb-5e15e3aca52c';

  static const String _salesOrderZipUrl =
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fsales_order_form_page.zip?alt=media&token=38447df2-d34f-4377-84a7-0a9227aca89e';

  @override
  void initState() {
    super.initState();
    _loadEmailKey();
  }

  Future<void> _loadEmailKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    setState(() {
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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

    final double cardWidth =
        (MediaQuery.of(context).size.width - 48) / 2;
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
        if (snapshot.connectionState ==
                ConnectionState.waiting ||
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
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 12),
          child: GridView.builder(
            itemCount: docs.length,
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cardWidth / cardHeight,
            ),
            itemBuilder: (context, idx) {
              final doc = docs[idx];
              final data =
                  doc.data() as Map<String, dynamic>;
              final String eventName =
                  data["eventName"] ?? "";
              final String date = data["date"] ?? "-";

              final transactionNumber = docs.length - idx;
              final transactionLabel =
                  "Event #$transactionNumber";

              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AttendanceFormReadonlyPage(
                            formData: data,
                            docId: doc.id,
                            userKey: _userKey,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration:
                          const BoxDecoration(
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
                        padding:
                            const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
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
                                    eventName.isNotEmpty
                                        ? eventName
                                        : "Unnamed Event",
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Date: $date",
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(
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
      return const Center(
          child: CircularProgressIndicator());
    }

    final double cardWidth =
        (MediaQuery.of(context).size.width - 48) / 2;
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
        if (snapshot.connectionState ==
                ConnectionState.waiting ||
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator());
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
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 12),
          child: GridView.builder(
            itemCount: docs.length,
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cardWidth / cardHeight,
            ),
            itemBuilder: (context, idx) {
              final doc = docs[idx];
              final data =
                  doc.data() as Map<String, dynamic>;

              final String farmerName =
                  data['farmerName'] ??
                      'Unnamed Farmer';
              final String dateOfEvent =
                  data['dateOfEvent'] ?? '-';
              final String cropsPlanted =
                  data['cropsPlanted'] ?? '';

              final transactionNumber = docs.length - idx;
              final transactionLabel =
                  'SCP #$transactionNumber';

              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ScpFormReadonlyPage(
                            formData: data,
                            docId: doc.id,
                            userKey: _userKey,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration:
                          const BoxDecoration(
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
                        padding:
                            const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons
                                      .description_outlined,
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
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (cropsPlanted
                                      .isNotEmpty)
                                    Text(
                                      'Crop: $cropsPlanted',
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  Text(
                                    'Date: $dateOfEvent',
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(
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

  String _formatAbrTimestamp(
      dynamic ts, String fallback) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final y =
          dt.year.toString().padLeft(4, '0');
      final m =
          dt.month.toString().padLeft(2, '0');
      final d =
          dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
    return fallback;
  }

  // =========================
  // ABR HISTORY BODY
  // =========================
  Widget _buildAbrHistorySection(
      BuildContext context) {
    if (_userKey.isEmpty) {
      return const Center(
          child: CircularProgressIndicator());
    }

    final double cardWidth =
        (MediaQuery.of(context).size.width - 48) / 2;
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
        if (snapshot.connectionState ==
                ConnectionState.waiting ||
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator());
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
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 12),
          child: GridView.builder(
            itemCount: docs.length,
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cardWidth / cardHeight,
            ),
            itemBuilder: (context, idx) {
              final doc = docs[idx];
              final data =
                  doc.data() as Map<String, dynamic>;

              final String activityName =
                  (data['agronomist']
                          as String?) ??
                      'No agronomist';

              final dynamic ts =
                  data['timestamp'];
              final String plannedDate =
                  (data['plannedDate']
                          as String?) ??
                      (data['plannedActivityDate']
                              as String?) ??
                      '';
              final String date =
                  _formatAbrTimestamp(
                ts,
                plannedDate.isEmpty
                    ? '-'
                    : plannedDate,
              );

              final String location =
                  (data['plannedLocation']
                          as String?) ??
                      (data['plannedActivityLocation']
                              as String?) ??
                      (data['location']
                              as String?) ??
                      '';

              final transactionNumber =
                  docs.length - idx;
              final transactionLabel =
                  'ABR #$transactionNumber';

              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AbrFormReadonlyPage(
                            formData: data,
                            docId: doc.id,
                            userKey: _userKey,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration:
                          const BoxDecoration(
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
                        padding:
                            const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons
                                      .request_page_outlined,
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
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (location
                                      .isNotEmpty)
                                    Text(
                                      'Location: $location',
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  Text(
                                    'Date: $date',
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(
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
  Widget _buildInFieldCoachingHistorySection(
      BuildContext context) {
    if (_userKey.isEmpty) {
      return const Center(
          child: CircularProgressIndicator());
    }

    final double cardWidth =
        (MediaQuery.of(context).size.width - 48) / 2;
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
        if (snapshot.connectionState ==
                ConnectionState.waiting ||
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator());
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
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 12),
          child: GridView.builder(
            itemCount: docs.length,
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cardWidth / cardHeight,
            ),
            itemBuilder: (context, idx) {
              final QueryDocumentSnapshot doc =
                  docs[idx];
              final Map<String, dynamic> dat =
                  doc.data() as Map<String, dynamic>;

              final String evaluator =
                  dat['evaluator'] ?? '';
              final String position =
                  dat['position'] ?? '';
              final String date = dat['date'] ?? '';

              final String title =
                  '$evaluator - $position';

              final transactionNumber =
                  docs.length - idx;
              final transactionLabel =
                  'Coaching #$transactionNumber';

              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
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
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration:
                          const BoxDecoration(
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
                        padding:
                            const EdgeInsets.all(8.0),
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
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
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
                                    style:
                                        const TextStyle(
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
  // =======================================
  Widget _buildIncidentalCoverageHistorySection(
      BuildContext context) {
    if (_userKey.isEmpty) {
      return const Center(
          child: CircularProgressIndicator());
    }

    final double cardWidth =
        (MediaQuery.of(context).size.width - 48) / 2;
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
            snapshot.connectionState ==
                ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator());
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
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 12),
          child: GridView.builder(
            itemCount: docs.length,
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cardWidth / cardHeight,
            ),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data =
                  doc.data() as Map<String, dynamic>;
              final title =
                  "${data['lastName'] ?? ''} ${data['firstName'] ?? ''}"
                      .trim();
              final date =
                  data['dateOfCover'] ?? "-";

              final transactionNumber =
                  docs.length - index;
              final transactionLabel =
                  "Transaction #$transactionNumber";

              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
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
                      decoration:
                          const BoxDecoration(
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
                        padding:
                            const EdgeInsets.all(8.0),
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
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
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
                                    style:
                                        const TextStyle(
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
  // SALES ORDER HISTORY BODY
  // =======================================
  Widget _buildSalesOrderHistorySection(
      BuildContext context) {
    if (_userKey.isEmpty) {
      return const Center(
          child: CircularProgressIndicator());
    }

    final double cardWidth =
        (MediaQuery.of(context).size.width - 48) / 2;
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
            snapshot.connectionState ==
                ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator());
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
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 12),
          child: GridView.builder(
            itemCount: docs.length,
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cardWidth / cardHeight,
            ),
            itemBuilder: (context, idx) {
              final data =
                  docs[idx].data() as Map<String, dynamic>;
              final mrName = data["mrName"] ?? "";
              final soldTo = data["soldTo"] ?? "";
              final dateOfOrder =
                  data["dateOfOrder"] ?? "-";

              final transactionNumber =
                  docs.length - idx;
              final transactionLabel =
                  "Transaction #$transactionNumber";

              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
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
                      decoration:
                          const BoxDecoration(
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
                        padding:
                            const EdgeInsets.all(8.0),
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
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
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
                                    style:
                                        const TextStyle(
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
                                    style:
                                        const TextStyle(
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

  // ================
  // DOWNLOAD HELPERS
  // ================
  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // Use the public Downloads folder on Android. [web:48][web:46]
      final dir =
          Directory('/storage/emulated/0/Download');
      if (await dir.exists()) {
        return dir;
      }
      // Fallback to app documents directory. [web:36]
      return await getApplicationDocumentsDirectory();
    } else {
      // iOS/others: only app documents directory. [web:36]
      return await getApplicationDocumentsDirectory();
    }
  }

  Future<void> _downloadAttendanceZip() async {
    try {
      final uri = Uri.parse(_attendanceZipUrl);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to download file (status ${response.statusCode})');
      }

      final downloadsDir =
          await _getDownloadsDirectory();
      final filePath =
          '${downloadsDir.path}/attendance_form_page.zip';
      final file = File(filePath);
      await file.writeAsBytes(
          response.bodyBytes); // [web:70]

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Attendance E-Form saved to: $filePath'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error downloading Attendance E-Form: $e'),
        ),
      );
    }
  }

  Future<void> _downloadScpZip() async {
    try {
      final uri = Uri.parse(_scpZipUrl);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to download file (status ${response.statusCode})');
      }

      final downloadsDir =
          await _getDownloadsDirectory();
      final filePath =
          '${downloadsDir.path}/scp_form_page.zip';
      final file = File(filePath);
      await file.writeAsBytes(
          response.bodyBytes); // [web:70]

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('SCP E-Form saved to: $filePath'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error downloading SCP E-Form: $e'),
        ),
      );
    }
  }

  Future<void> _downloadAbrZip() async {
    try {
      final uri = Uri.parse(_abrZipUrl);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to download file (status ${response.statusCode})');
      }

      final downloadsDir =
          await _getDownloadsDirectory();
      final filePath =
          '${downloadsDir.path}/abr_form_page.zip';
      final file = File(filePath);
      await file.writeAsBytes(
          response.bodyBytes); // [web:70]

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('ABR E-Form saved to: $filePath'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error downloading ABR E-Form: $e'),
        ),
      );
    }
  }

  Future<void> _downloadInFieldZip() async {
    try {
      final uri = Uri.parse(_inFieldZipUrl);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to download file (status ${response.statusCode})');
      }

      final downloadsDir =
          await _getDownloadsDirectory();
      final filePath =
          '${downloadsDir.path}/in_field_coaching_form_page.zip';
      final file = File(filePath);
      await file.writeAsBytes(
          response.bodyBytes); // [web:70]

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'In-Field Coaching E-Form saved to: $filePath'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error downloading In-Field Coaching E-Form: $e'),
        ),
      );
    }
  }

  Future<void> _downloadIncidentalZip() async {
    try {
      final uri = Uri.parse(_incidentalZipUrl);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to download file (status ${response.statusCode})');
      }

      final downloadsDir =
          await _getDownloadsDirectory();
      final filePath =
          '${downloadsDir.path}/incidental_coverage_form_page.zip';
      final file = File(filePath);
      await file.writeAsBytes(
          response.bodyBytes); // [web:70]

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Incidental Coverage E-Form saved to: $filePath'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error downloading Incidental Coverage E-Form: $e'),
        ),
      );
    }
  }

  Future<void> _downloadSalesOrderZip() async {
    try {
      final uri = Uri.parse(_salesOrderZipUrl);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to download file (status ${response.statusCode})');
      }

      final downloadsDir =
          await _getDownloadsDirectory();
      final filePath =
          '${downloadsDir.path}/sales_order_form_page.zip';
      final file = File(filePath);
      await file.writeAsBytes(
          response.bodyBytes); // [web:70]

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Sales Order E-Form saved to: $filePath'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error downloading Sales Order E-Form: $e'),
        ),
      );
    }
  }

  void _onDownloadPressed(String formType) {
    if (formType == 'attendance') {
      _downloadAttendanceZip();
      return;
    }
    if (formType == 'scp') {
      _downloadScpZip();
      return;
    }
    if (formType == 'abr') {
      _downloadAbrZip();
      return;
    }
    if (formType == 'coaching') {
      _downloadInFieldZip();
      return;
    }
    if (formType == 'inc_cov') {
      _downloadIncidentalZip();
      return;
    }
    if (formType == 'sales_order') {
      _downloadSalesOrderZip();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Download for $formType not yet implemented.'),
      ),
    );
  }

  // ============
  // MAIN BUILD
  // ============
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
                Color(0xFF4E3385),
                Color(0xFF503282),
                Color(0xFF523584),
                Color(0xFF543887),
                Color(0xFF563B89),
                Color(0xFF593F8C),
                Color(0xFF5C438F),
                Color(0xFF5F4892),
                Color(0xFF634D96),
                Color(0xFF68529A),
                Color(0xFF6E589E),
                Color(0xFF7560A4),
                Color(0xFF8170AB),
                Color(0xFF9582B3),
              ],
              stops: [0.0, 0.07, 0.14, 0.22, 0.30, 0.38, 0.46, 0.54, 0.62, 0.70, 0.77, 0.84, 0.92, 1.0],
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
        padding:
            const EdgeInsets.symmetric(vertical: 16),
        children: [
          const Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 16),
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
            padding:
                EdgeInsets.symmetric(horizontal: 16),
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
                const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
            child: SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(
                        horizontal: 8),
                children: [
                  _buildSelectableFormChip(
                    title: 'Attendance Form',
                    index: 0,
                  ),
                  _buildSelectableFormChip(
                    title:
                        'Sample Crop Prescription',
                    index: 1,
                  ),
                  _buildSelectableFormChip(
                    title:
                        'Activity Budget Request',
                    index: 2,
                  ),
                  _buildSelectableFormChip(
                    title:
                        'In-Field Coaching Form',
                    index: 3,
                  ),
                  _buildSelectableFormChip(
                    title:
                        'Incidental Coverage Form',
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
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                      horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Attendance Form History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _onDownloadPressed(
                            'attendance'),
                    icon: const Icon(
                        Icons.download),
                    label: const Text(
                        'Download E-Form'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          const Color(0xFF4e2f80),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height:
                  MediaQuery.of(context)
                          .size
                          .height *
                      0.9,
              child: _buildAttendanceHistorySection(
                  context),
            ),
          ],

          if (_selectedIndex == 1) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                      horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sample Crop Prescription History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _onDownloadPressed('scp'),
                    icon: const Icon(
                        Icons.download),
                    label: const Text(
                        'Download E-Form'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          const Color(0xFF4e2f80),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height:
                  MediaQuery.of(context)
                          .size
                          .height *
                      0.9,
              child: _buildScpHistorySection(
                  context),
            ),
          ],

          if (_selectedIndex == 2) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                      horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Activity Budget Request History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _onDownloadPressed('abr'),
                    icon: const Icon(
                        Icons.download),
                    label: const Text(
                        'Download E-Form'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          const Color(0xFF4e2f80),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height:
                  MediaQuery.of(context)
                          .size
                          .height *
                      0.9,
              child: _buildAbrHistorySection(
                  context),
            ),
          ],

          if (_selectedIndex == 3) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                      horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'In-Field Coaching Form History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _onDownloadPressed(
                            'coaching'),
                    icon: const Icon(
                        Icons.download),
                    label: const Text(
                        'Download E-Form'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          const Color(0xFF4e2f80),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height:
                  MediaQuery.of(context)
                          .size
                          .height *
                      0.9,
              child:
                  _buildInFieldCoachingHistorySection(
                      context),
            ),
          ],

          if (_selectedIndex == 4) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                      horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Incidental Coverage Form History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _onDownloadPressed(
                            'inc_cov'),
                    icon: const Icon(
                        Icons.download),
                    label: const Text(
                        'Download E-Form'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          const Color(0xFF4e2f80),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height:
                  MediaQuery.of(context)
                          .size
                          .height *
                      0.9,
              child:
                  _buildIncidentalCoverageHistorySection(
                      context),
            ),
          ],

          if (_selectedIndex == 5) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                      horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sales Order Form History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _onDownloadPressed(
                            'sales_order'),
                    icon: const Icon(
                        Icons.download),
                    label: const Text(
                        'Download E-Form'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          const Color(0xFF4e2f80),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height:
                  MediaQuery.of(context)
                          .size
                          .height *
                      0.9,
              child:
                  _buildSalesOrderHistorySection(
                      context),
            ),
          ],
        ],
      ),
    );
  }
}
