import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'deduction_input_for_calldetail_page.dart';
import 'add_note_input_for_calldetail_page.dart';
import 'call_loc_page.dart';
import '../call_postcall_page.dart';
import 'call_signature_page.dart';
import 'call_tools_page.dart';

class CallDetailPage extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final String scheduledVisitId;
  const CallDetailPage({
    Key? key,
    required this.doctor,
    required this.scheduledVisitId,
  }) : super(key: key);

  @override
  State<CallDetailPage> createState() => _CallDetailPageState();
}

class _CallDetailPageState extends State<CallDetailPage> {
  @override
  Widget build(BuildContext context) {
    final doctorName =
        "${widget.doctor['lastName'] ?? ''}, ${widget.doctor['firstName'] ?? ''}";
    final doctorId = widget.doctor['doc_id'] ?? '';
    final hospital = widget.doctor['hospital'] ?? '';
    final specialty = widget.doctor['specialty'] ?? '';

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$doctorName ($doctorId)", style: const TextStyle(fontSize: 18)),
              Text(
                hospital,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
              ),
              Text(
                specialty,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF5958b2),
          bottom: const TabBar(
            isScrollable: false,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white,
            indicatorColor: Colors.amber,
            tabs: [
              Tab(text: "Pre-Call"),
              Tab(text: "Location"),
              Tab(text: "Tools"),
              Tab(text: "Signature"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            PreCallTab(
              doctorId: doctorId,
              scheduledVisitId: widget.scheduledVisitId,
            ),
            CallLocPage(
              doctorId: doctorId,
              scheduledVisitId: widget.scheduledVisitId,
            ),
            const CallToolsPage(),
            CallSignaturePage(
              doctorId: doctorId,
              scheduledVisitId: widget.scheduledVisitId,
            ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return StreamBuilder<Object>(
              stream: null,
              builder: (context, snapshot) {
                return FloatingActionButton(
                  onPressed: () async {
                    final doctorId = widget.doctor['doc_id'] ?? '';
                    final scheduledVisitId = widget.scheduledVisitId;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddNoteInputForCallDetailPage(
                          doctorId: doctorId,
                          scheduledVisitId: scheduledVisitId,
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.add),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class PreCallTab extends StatelessWidget {
  final String doctorId;
  final String scheduledVisitId;
  const PreCallTab({
    Key? key,
    required this.doctorId,
    required this.scheduledVisitId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double space = MediaQuery.of(context).size.width < 800 ? 10 : 24;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding:
              EdgeInsets.symmetric(horizontal: space / 2, vertical: space / 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: _PreCallNotesListUserScoped(
                      doctorId: doctorId,
                      scheduledVisitId: scheduledVisitId,
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
}

class DeductionListUserScoped extends StatefulWidget {
  final String doctorId;
  final String scheduledVisitId;
  const DeductionListUserScoped(
      {required this.doctorId, required this.scheduledVisitId});

  @override
  State<DeductionListUserScoped> createState() =>
      _DeductionListUserScopedState();
}

class _DeductionListUserScopedState extends State<DeductionListUserScoped> {
  String? emailKey;

  @override
  void initState() {
    super.initState();
    _loadEmailKey();
  }

  Future<void> _loadEmailKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    setState(() {
      emailKey = userEmail.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (emailKey == null || emailKey!.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        // Target deductions UI commented out
      ],
    );
  }
}

class _PreCallNotesListUserScoped extends StatefulWidget {
  final String doctorId;
  final String scheduledVisitId;
  const _PreCallNotesListUserScoped(
      {required this.doctorId, required this.scheduledVisitId});

  @override
  State<_PreCallNotesListUserScoped> createState() =>
      _PreCallNotesListUserScopedState();
}

class _PreCallNotesListUserScopedState
    extends State<_PreCallNotesListUserScoped> {
  String? emailKey;
  String _userClientType = '';

  @override
  void initState() {
    super.initState();
    _loadUserPrefs();
  }

  Future<void> _loadUserPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    final clientType = prefs.getString('userClientType') ?? 'both';
    setState(() {
      emailKey = userEmail.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
      _userClientType = clientType;
    });
  }

  /// Base doctors collection for this user, matching other updated pages:
  /// - pharma  -> /flowDB/users/RR/{emailKey}/doctors/doctors
  /// - farmers -> /flowDB/users/INDOFIL/{emailKey}/doctors/doctors
  /// - both    -> /flowDB/users/{emailKey}/doctors/doctors
  CollectionReference<Map<String, dynamic>> _doctorsCollectionRef() {
    final root =
        FirebaseFirestore.instance.collection('flowDB').doc('users');

    if (_userClientType == 'pharma') {
      return root
          .collection('RR')
          .doc(emailKey)
          .collection('doctors')
          .doc('doctors')
          .collection('doctors');
    } else if (_userClientType == 'farmers') {
      return root
          .collection('INDOFIL')
          .doc(emailKey)
          .collection('doctors')
          .doc('doctors')
          .collection('doctors');
    } else {
      return root
          .collection(emailKey!)
          .doc('doctors')
          .collection('doctors');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (emailKey == null || emailKey!.isEmpty || _userClientType.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        const Text(
          "Pre-Call Plans",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _doctorsCollectionRef()
                .doc(widget.doctorId)
                .collection('scheduledVisits')
                .doc(widget.scheduledVisitId)
                .collection('callNotes')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text("No Pre-Call Plans..."));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, idx) {
                  final data =
                      docs[idx].data() as Map<String, dynamic>;
                  final ts = data['timestamp'] as Timestamp?;
                  final dt =
                      ts != null ? ts.toDate() : DateTime.now();
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['note'] ?? "Pre-Call Plan",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 4),
                            child: Text(
                              "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
                              "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}