import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:idoxsapp/menu/e_forms_menu/incidental_coverage_form_transactions_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fattendance_form_page.zip?alt=media&token=094e7010-e56c-4e90-b30f-e06629578114';

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
    final Color selectedColor = const Color(0xFF4A2371);
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A2371).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.fileText,
                      size: 40,
                      color: Color(0xFF4A2371),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No attendance forms yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'OpenSauce',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E)
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tap + in the Attendance page to create a new form.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'OpenSauce',
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final doc = docs[idx];
            final data = doc.data() as Map<String, dynamic>;
            final String eventName = data["eventName"] ?? "Unnamed Event";
            final String date = _formatReadableDate(data["date"]);

            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    color: Colors.white,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A2371).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.fileText,
                          color: Color(0xFF4A2371),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              eventName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontFamily: 'OpenSauce',
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'OpenSauce',
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
        child: CircularProgressIndicator()
      );
    }

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
            child: CircularProgressIndicator()
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),              
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A2371).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.fileText,
                      size: 40,
                      color: Color(0xFF4A2371),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No SCP forms yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'OpenSauce',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap + in the SCP page to create a new form.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13, 
                      fontFamily: 'OpenSauce',
                      color: Colors.grey
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final doc = docs[idx];
            final data = doc.data() as Map<String, dynamic>;
            final String farmerName = data['farmerName'] ?? 'Unnamed Farmer';
            final String dateOfEvent = _formatReadableDate(data['dateOfEvent']);
            final String cropsPlanted = data['cropsPlanted'] ?? '';

            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
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
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    color: Colors.white,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A2371).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.fileText,
                          color: Color(0xFF4A2371),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              farmerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontFamily: 'OpenSauce',
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (cropsPlanted.isNotEmpty)
                              Text(
                                cropsPlanted,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'OpenSauce',
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF4A2371).withValues(alpha: 0.8),
                                ),
                              ),
                            Text(
                              dateOfEvent,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'OpenSauce',
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            );
          }
        );
      },
    );
  }

  // =========================
  // ABR HISTORY BODY
  // =========================
  Widget _buildAbrHistorySection(BuildContext context) {
    if (_userKey.isEmpty) {
      return const Center(
        child: CircularProgressIndicator()
      );
    }

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
            child: CircularProgressIndicator()
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A2371).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.fileText,
                      size: 40,
                      color: Color(0xFF4A2371),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No ABR forms yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'OpenSauce',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap + in the ABR page to create a new form.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13, 
                      fontFamily: 'OpenSauce',
                      color: Colors.grey
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final doc = docs[idx];
            final data = doc.data() as Map<String, dynamic>;
            final String activityName = (data['agronomist'] as String?) ?? 'No agronomist';            
            final String location = (data['plannedLocation'] as String?) ?? (data['plannedActivityLocation'] as String?) ?? (data['location'] as String?) ?? '';
            final String plannedDate = (data['plannedDate'] as String?) ?? (data['plannedActivityDate'] as String?) ?? '';
            final String date = _formatReadableDate(
              data['timestamp'],
              fallback: plannedDate.isNotEmpty ? _formatReadableDate(plannedDate) : '-',
            );

            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
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
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2)
                      ),
                    ],
                    color: Colors.white
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A2371).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: const Icon(
                          LucideIcons.fileText,
                          color: Color(0xFF4A2371),
                          size: 22
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              activityName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontFamily: 'OpenSauce',
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (location.isNotEmpty)
                              Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'OpenSauce',
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF4A2371).withValues(alpha: 0.8),
                                ),
                              ),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'OpenSauce',
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A2371).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.fileText,
                      size: 40,
                      color: Color(0xFF4A2371),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No coaching forms yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'OpenSauce',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Tap + in the In-Field Coaching page to create a new form.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'OpenSauce',
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final doc = docs[idx];
            final data = doc.data() as Map<String, dynamic>;
            final String evaluator = data['evaluator'] ?? '';
            final String position = data['position'] ?? '';
            final String date = _formatReadableDate(data['date']);
            final String title = evaluator.isNotEmpty ? evaluator : 'Unnamed Evaluator';

            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InFieldCoachingFormReadonlyPage(
                        formData: data,
                        docId: doc.id,
                        userKey: _userKey,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey.shade200, 
                      width: 1
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    color: Colors.white,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon badge
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A2371).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.fileText,
                          color: Color(0xFF4A2371),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontFamily: 'OpenSauce',
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (position.isNotEmpty)
                              Text(
                                position,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'OpenSauce',
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF4A2371).withValues(alpha: 0.8),
                                ),
                              ),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'OpenSauce',
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
        child: CircularProgressIndicator()
      );
    }

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
            child: CircularProgressIndicator()
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A2371).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.fileText,
                      size: 40,
                      color: Color(0xFF4A2371),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No coverage forms yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'OpenSauce',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap + in the Incidental Coverage page to create a new form.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'OpenSauce',
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final String lastName = data['lastName'] ?? '';
            final String firstName = data['firstName'] ?? '';
            final String fullName = '$lastName $firstName'.trim();
            final String title = fullName.isNotEmpty ? fullName : 'Unnamed Coverage';
            final String date = _formatReadableDate(data['dateOfCover']);

            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => IncidentalCoverageFormPage(                      
                        formData: data,
                        // readonly: true,
                        docId:    doc.id,
                        userKey:  _userKey,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey.shade200, 
                      width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    color: Colors.white,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon badge
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A2371).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.fileText,
                          color: Color(0xFF4A2371),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontFamily: 'OpenSauce',
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'OpenSauce',
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
            child: CircularProgressIndicator()
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A2371).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.fileText,
                      size: 40,
                      color: Color(0xFF4A2371),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No sales order forms yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'OpenSauce',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap + in the Sales Order page to create a new form.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'OpenSauce',
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final doc = docs[idx];
            final data = doc.data() as Map<String, dynamic>;
            final String mrName = data['mrName'] ?? 'Unnamed Sales Order';
            final String soldTo = data['soldTo'] ?? '';
            final String dateOfOrder = _formatReadableDate(data['dateOfOrder']);

            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SalesOrderFormPage(
                        formData: data,
                        readonly: true,
                        docId: doc.id,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey.shade200, 
                      width: 1
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    color: Colors.white,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon badge
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A2371).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.fileText,
                          color: Color(0xFF4A2371),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              mrName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontFamily: 'OpenSauce',
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (soldTo.isNotEmpty)
                              Text(
                                soldTo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'OpenSauce',
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF4A2371).withValues(alpha: 0.8),
                                ),
                              ),
                            Text(
                              dateOfOrder,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'OpenSauce',
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
        throw Exception('Failed to download file (status ${response.statusCode})');
      }

      final downloadsDir = await _getDownloadsDirectory();
      final filePath = '${downloadsDir.path}/attendance_form_page.zip';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes); // [web:70]

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance E-Form saved to: $filePath'
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error downloading Attendance E-Form: $e'
          ),
        ),
      );
    }
  }

  Future<void> _downloadScpZip() async {
    try {
      final uri = Uri.parse(_scpZipUrl);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to download file (status ${response.statusCode})');
      }

      final downloadsDir = await _getDownloadsDirectory();
      final filePath = '${downloadsDir.path}/scp_form_page.zip';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes); // [web:70]

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
        throw Exception('Failed to download file (status ${response.statusCode})');
      }

      final downloadsDir = await _getDownloadsDirectory();
      final filePath = '${downloadsDir.path}/abr_form_page.zip';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes); // [web:70]

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
          'Failed to download file (status ${response.statusCode})'
        );
      }

      final downloadsDir = await _getDownloadsDirectory();
      final filePath = '${downloadsDir.path}/in_field_coaching_form_page.zip';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes); // [web:70]

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'In-Field Coaching E-Form saved to: $filePath'
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error downloading In-Field Coaching E-Form: $e'
          ),
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
          'Failed to download file (status ${response.statusCode})'
        );
      }

      final downloadsDir = await _getDownloadsDirectory();
      final filePath = '${downloadsDir.path}/incidental_coverage_form_page.zip';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes); // [web:70]

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Incidental Coverage E-Form saved to: $filePath'
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error downloading Incidental Coverage E-Form: $e'
          ),
        ),
      );
    }
  }

  Future<void> _downloadSalesOrderZip() async {
    try {
      final uri = Uri.parse(_salesOrderZipUrl);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to download file (status ${response.statusCode})');
      }

      final downloadsDir = await _getDownloadsDirectory();
      final filePath = '${downloadsDir.path}/sales_order_form_page.zip';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes); // [web:70]

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sales Order E-Form saved to: $filePath'
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error downloading Sales Order E-Form: $e'
          ),
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
          'Download for $formType not yet implemented.'
        ),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),                
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

          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildSelectableFormChip(title: 'Attendance Form', index: 0),
                _buildSelectableFormChip(title: 'Sample Crop Prescription', index: 1),
                _buildSelectableFormChip(title: 'Activity Budget Request', index: 2),
                _buildSelectableFormChip(title: 'In-Field Coaching Form', index: 3),
                _buildSelectableFormChip(title: 'Incidental Coverage Form', index: 4),
                _buildSelectableFormChip(title: 'Sales Order Form', index: 5),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_selectedIndex >= 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _getSectionTitle(_selectedIndex),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _onDownloadPressed(_getFormKey(_selectedIndex)),
                    icon: const Icon(Icons.download),
                    label: const Text('Download E-Form'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4A2371),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
                  
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (_selectedIndex == 0)
                  _buildAttendanceHistorySection(context),
                if (_selectedIndex == 1)
                  _buildScpHistorySection(context),
                if (_selectedIndex == 2)
                  _buildAbrHistorySection(context),
                if (_selectedIndex == 3)
                  _buildInFieldCoachingHistorySection(context),
                if (_selectedIndex == 4)
                  _buildIncidentalCoverageHistorySection(context),
                if (_selectedIndex == 5)
                  _buildSalesOrderHistorySection(context),
              ],
            ),
          )
        ],
      ),
    );
  }
}

String _getSectionTitle(int index) {
  const titles = [
    'Attendance Form History',
    'Sample Crop Prescription History',
    'Activity Budget Request History',
    'In-Field Coaching Form History',
    'Incidental Coverage Form History',
    'Sales Order Form History',
  ];
  return index >= 0 && index < titles.length ? titles[index] : '';
}

String _getFormKey(int index) {
  const keys = [
    'attendance',
    'scp',
    'abr',
    'coaching',
    'inc_cov',
    'sales_order',    
  ];
  return index >= 0 && index < keys.length ? keys[index] : '';
}

String _formatReadableDate(dynamic value, {String fallback = '-'}) {
  const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
 
  DateTime? dt;
 
  // Null checks
  if (value is Timestamp) {
    dt = value.toDate();
  } else if (value is String && value.isNotEmpty) {
    dt = DateTime.tryParse(value);
    if (dt == null) {
      final parts = value.split(RegExp(r'[/\-]'));
      if (parts.length == 3) {
        final a = int.tryParse(parts[0]);
        final b = int.tryParse(parts[1]);
        final c = int.tryParse(parts[2]);
        if (a != null && b != null && c != null) {
          if (c > 31) {
            dt = DateTime.tryParse('$c-${a.toString().padLeft(2,'0')}-${b.toString().padLeft(2,'0')}');
          } else {
            dt = DateTime.tryParse('${a.toString().padLeft(4,'0')}-${b.toString().padLeft(2,'0')}-${c.toString().padLeft(2,'0')}');
          }
        }
      }
    }
  }
 
  if (dt == null) return fallback.isNotEmpty ? fallback : '-';
  return '${monthNames[dt.month - 1]} ${dt.day}, ${dt.year}';
}