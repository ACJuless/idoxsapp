import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart'; // NEW: for Storage [web:74]
import 'add_note_input_for_calldetail_page.dart';
import 'call_loc_page.dart';
import 'call_signature_page.dart';
// We will not use the old local-files CallToolsPage; instead, we implement a tools tab here.
// import 'call_tools_page.dart';

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

class _CallDetailPageState extends State<CallDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 4 tabs: Pre-Call, Location, Tools, Signature
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doctorName =
        "${widget.doctor['lastName'] ?? ''}, ${widget.doctor['firstName'] ?? ''}";
    final doctorId = widget.doctor['doc_id'] ?? '';
    final hospital = widget.doctor['hospital'] ?? '';
    final specialty = widget.doctor['specialty'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$doctorName ($doctorId)",
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              hospital,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
            Text(
              specialty,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF5958b2),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white,
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
        controller: _tabController,
        children: [
          PreCallTab(
            doctorId: doctorId,
            scheduledVisitId: widget.scheduledVisitId,
          ),
          CallLocPage(
            doctorId: doctorId,
            scheduledVisitId: widget.scheduledVisitId,
          ),
          // New tools implementation that reads from Firebase Storage
          ToolsTabStorage(
            doctorId: doctorId,
            scheduledVisitId: widget.scheduledVisitId,
          ),
          CallSignaturePage(
            doctorId: doctorId,
            scheduledVisitId: widget.scheduledVisitId,
          ),
        ],
      ),
      // FAB varies by tab:
      // index 0 -> Pre-Call FAB (existing behavior)
      // index 1 -> Location FAB (no functionality yet)
      // others -> no FAB
      floatingActionButton: () {
        final index = _tabController.index;
        if (index == 0) {
          // Pre-Call FAB (existing)
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
        } else if (index == 1) {
          // Location FAB (placeholder, no functionality yet)
          return FloatingActionButton(
            onPressed: () {
              // TODO: add functionality later
            },
            child: const Icon(Icons.add_location_alt),
          );
        } else {
          return null;
        }
      }(),
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

  const DeductionListUserScoped({
    required this.doctorId,
    required this.scheduledVisitId,
  });

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

  const _PreCallNotesListUserScoped({
    required this.doctorId,
    required this.scheduledVisitId,
  });

  @override
  State<_PreCallNotesListUserScoped> createState() =>
      _PreCallNotesListUserScopedState();
}

class _PreCallNotesListUserScopedState
    extends State<_PreCallNotesListUserScoped> {
  String? _userId; // MR id like MR00001
  String _userClientType = '';

  @override
  void initState() {
    super.initState();
    _loadUserPrefs();
  }

  Future<void> _loadUserPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    final clientType = prefs.getString('userClientType') ?? 'both';
    setState(() {
      _userId = userId.isEmpty ? null : userId;
      _userClientType = clientType;
    });
  }

  /// Root:
  /// /DaloyClients/IVA/Users/{_userId}/Doctor/{doctorId}/Visits/{scheduledVisitId}/callNotes
  CollectionReference<Map<String, dynamic>> _callNotesCollection() {
    if (_userId == null || _userId!.isEmpty) {
      return FirebaseFirestore.instance
          .collection('DaloyClients')
          .doc('IVA')
          .collection('Users')
          .doc('_DUMMY')
          .collection('Doctor')
          .doc('DUMMY_DOCTOR')
          .collection('Visits')
          .doc('DUMMY_VISIT')
          .collection('callNotes');
    }

    return FirebaseFirestore.instance
        .collection('DaloyClients')
        .doc('IVA')
        .collection('Users')
        .doc(_userId)
        .collection('Doctor')
        .doc(widget.doctorId)
        .collection('Visits')
        .doc(widget.scheduledVisitId)
        .collection('callNotes');
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null || _userId!.isEmpty || _userClientType.isEmpty) {
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
            stream: _callNotesCollection()
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
                  final data = docs[idx].data() as Map<String, dynamic>;
                  final ts = data['timestamp'] as Timestamp?;
                  final dt = ts != null ? ts.toDate() : DateTime.now();
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 5),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['note'] ?? "Pre-Call Plan",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
                              "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
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

/// Tools tab that loads doctor-specific files from Firebase Storage instead of local files. [web:74]
class ToolsTabStorage extends StatefulWidget {
  final String doctorId;
  final String scheduledVisitId;

  const ToolsTabStorage({
    Key? key,
    required this.doctorId,
    required this.scheduledVisitId,
  }) : super(key: key);

  @override
  State<ToolsTabStorage> createState() => _ToolsTabStorageState();
}

class _ToolsTabStorageState extends State<ToolsTabStorage> {
  late Future<List<Reference>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _filesFuture = _loadDoctorFiles();
  }

  /// Adjust this path to match your bucket structure, e.g.:
  /// tools/{doctorId}/... or tools/{doctorId}/{scheduledVisitId}/...
  Future<List<Reference>> _loadDoctorFiles() async {
    final storage = FirebaseStorage.instance;
    // Example: all files under "tools/{doctorId}"
    final doctorFolderRef =
        storage.ref().child('tools/${widget.doctorId}');

    final listResult = await doctorFolderRef.listAll(); // small dir only [web:74]
    return listResult.items;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Reference>>(
      future: _filesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading tools: ${snapshot.error}'),
          );
        }
        final files = snapshot.data ?? [];
        if (files.isEmpty) {
          return const Center(
            child: Text('No tools available for this doctor.'),
          );
        }

        return ListView.builder(
          itemCount: files.length,
          itemBuilder: (context, index) {
            final fileRef = files[index];
            final name = fileRef.name;

            return ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: Text(name),
              subtitle: Text(fileRef.fullPath),
              onTap: () async {
                // You can later implement:
                // final url = await fileRef.getDownloadURL();
                // then open it in a PDF/image viewer or browser.
              },
            );
          },
        );
      },
    );
  }
}