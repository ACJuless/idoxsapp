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
              Text("$doctorName ($doctorId)", style: TextStyle(fontSize: 18)),
              Text(hospital,
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
              Text(specialty,
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
            ],
          ),
          backgroundColor: Color(0xFF5958b2),
          bottom: TabBar(
            isScrollable: false,
            // Selected tab label color (gold)
            labelColor: Colors.amber,
            // Unselected tab label color (white)
            unselectedLabelColor: Colors.white,
            // Keep indicator white or change to gold if you prefer
            indicatorColor: Colors.amber,
            tabs: const [
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
            CallToolsPage(),
            CallSignaturePage(
              doctorId: doctorId,
              scheduledVisitId: widget.scheduledVisitId,
            ),
            // CallPostCallPage(
            //   doctorId: doctorId,
            //   scheduledVisitId: widget.scheduledVisitId,
            // ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            // Only show FAB when on PreCallTab (first tab)
            final tabController = DefaultTabController.of(context);
            return StreamBuilder<Object>(
              stream: null,
              builder: (context, snapshot) {
                // You can customize to check if current tab index == 0 to conditionally show FAB
                // For now, always show FAB as per original layout
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
                  child: Icon(Icons.add),
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
                children: [
                  // Removed the "Add Pre-Call Note" ElevatedButton here as per request
                  // SizedBox(width: 30),
                ],
              ),
              SizedBox(height: 18),
              // Row removed so Pre-Call Plans can be centered
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 600),
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
      return Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text("Target Deductions", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.black)),
        // SizedBox(height: 6),
        // Expanded(
        //   child: StreamBuilder<QuerySnapshot>(
        //     stream: FirebaseFirestore.instance
        //         .collection('flowDB')
        //         .doc('users')
        //         .collection(emailKey!)
        //         .doc('doctors')
        //         .collection('doctors')
        //         .doc(widget.doctorId)
        //         .collection('scheduledVisits')
        //         .doc(widget.scheduledVisitId)
        //         .collection('targetDeductions')
        //         .orderBy('timestamp', descending: true)
        //         .snapshots(),
        //     builder: (context, snapshot) {
        //       if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        //       final docs = snapshot.data!.docs;
        //       if (docs.isEmpty) return Center(child: Text("No Target Deductions..."));
        //       return ListView.builder(
        //         itemCount: docs.length,
        //         itemBuilder: (context, idx) {
        //             final data = docs[idx].data() as Map<String, dynamic>;
        //             final ts = data['timestamp'] as Timestamp?;
        //             final dt = ts != null ? ts.toDate() : DateTime.now();
        //             return Card(
        //               margin: EdgeInsets.symmetric(vertical: 6, horizontal: 5),
        //               elevation: 2,
        //               child: Padding(
        //                 padding: const EdgeInsets.all(12.0),
        //                 child: Column(
        //                   crossAxisAlignment: CrossAxisAlignment.start,
        //                   children: [
        //                     Text(data['option'] ?? "Target Deduction", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        //                     Padding(
        //                       padding: const EdgeInsets.only(top: 3),
        //                       child: Text(
        //                         "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
        //                         "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}",
        //                         style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
        //                       ),
        //                     ),
        //                     Padding(
        //                       padding: EdgeInsets.only(top: 3),
        //                       child: Text("Half-Day: ${data['halfDay'] == true ? 'Yes' : 'No'}", style: TextStyle(fontSize: 13)),
        //                     )
        //                   ],
        //                 ),
        //               ),
        //             );
        //         },
        //       );
        //     },
        //   ),
        // ),
      ],
    );
  }
}

/// User-aware "Call Notes" list for Pre-Call Plans
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
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Text(
          "Pre-Call Plans",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
        SizedBox(height: 6),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('flowDB')
                .doc('users')
                .collection(emailKey!)
                .doc('doctors')
                .collection('doctors')
                .doc(widget.doctorId)
                .collection('scheduledVisits')
                .doc(widget.scheduledVisitId)
                .collection('callNotes')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty)
                return Center(child: Text("No Pre-Call Plans..."));
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
                        EdgeInsets.symmetric(vertical: 6, horizontal: 5),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['note'] ?? "Pre-Call Plan",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 4),
                            child: Text(
                              "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
                              "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}",
                              style: TextStyle(
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
