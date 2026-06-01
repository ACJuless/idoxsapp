import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tml_view.dart';
import 'doctor_detail_page.dart';

class DoctorPage extends StatefulWidget {
  @override
  _DoctorPageState createState() => _DoctorPageState();
}

class _DoctorPageState extends State<DoctorPage> {
  String _search = '';
  String userEmail = '';
  String emailKey = '';
  String _userClientType = ''; // client type from SharedPreferences
  String _userId = ''; // MR ID (e.g. MR00001) from SharedPreferences

  @override
  void initState() {
    super.initState();
    _loadUserPrefs();
  }

  // Load emailKey, clientType, and MR userId from SharedPreferences
  Future<void> _loadUserPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString('userEmail') ?? '';
    final clientType = prefs.getString('userClientType') ?? 'both';
    final userId = prefs.getString('userId') ?? ''; // MR00001, etc.

    setState(() {
      emailKey = userEmail.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
      _userClientType = clientType;
      _userId = userId;
    });
  }

  void _navigateToTmlView(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TmlViewPage()),
    );
  }

  void _navigateToDoctorDetail(
    BuildContext context,
    Map<String, dynamic> doctor,
    String docId, {
    bool startInEditMode = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorDetailPage(
          doctor: doctor,
          doc_id: docId,
          startInEditMode: startInEditMode,
        ),
      ),
    );
  }

  // Entity helpers based on client type
  String _entitySingular() {
    if (_userClientType == 'pharma') return 'Doctor';
    if (_userClientType == 'farmers') return 'Farmer';
    return 'Contact';
  }

  String _entityPlural() {
    if (_userClientType == 'pharma') return 'Doctors';
    if (_userClientType == 'farmers') return 'Farmers';
    return 'Contacts';
  }

  // Logical name (for labels only)
  String _collectionName() {
    if (_userClientType == 'pharma') return 'doctors';
    if (_userClientType == 'farmers') return 'farmers';
    return 'doctors';
  }

  /// Resolve Daloy client segment from userClientType + userEmail
  String _getClientSegment() {
    if (_userClientType == 'farmers') {
      return 'INDOFIL';
    }

    if (_userClientType == 'pharma') {
      final lower = userEmail.toLowerCase();
      if (lower.endsWith('@wert.com')) return 'WERT';
      return 'IVA';
    }

    // fallback for 'both' or others
    final lower = userEmail.toLowerCase();
    if (lower.endsWith('@indofil.com')) return 'INDOFIL';
    if (lower.endsWith('@wert.com')) return 'WERT';
    if (lower.endsWith('@iva.com')) return 'IVA';
    return 'GENERAL';
  }

  /// Get the doctors collection reference for the logged-in MR:
  /// /DaloyClients/{SEGMENT}/Users/{_userId}/Doctor
  CollectionReference<Map<String, dynamic>> _doctorsCollectionRef() {
    // While prefs are still loading, don't point to a shared/dummy path.
    if (_userId.isEmpty || userEmail.isEmpty || _userClientType.isEmpty) {
      return FirebaseFirestore.instance
          .collection('DaloyClients')
          .doc('___loading___')
          .collection('Users')
          .doc('___loading___')
          .collection('Doctor');
    }

    final segment = _getClientSegment();

    return FirebaseFirestore.instance
        .collection('DaloyClients')
        .doc(segment)
        .collection('Users')
        .doc(_userId)
        .collection('Doctor');
  }

  Map<String, List<Map<String, dynamic>>> getGroupedDoctors(
    List<Map<String, dynamic>> doctors,
  ) {
    doctors.sort(
      (a, b) => (a['lastName'] as String).compareTo(b['lastName'] as String),
    );
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var doc in doctors) {
      String lastName = doc['lastName'] ?? '';
      String initial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
      if (!grouped.containsKey(initial)) grouped[initial] = [];
      grouped[initial]!.add(doc);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _entityPlural();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(titleText),
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
            TextButton(
              onPressed: () => _navigateToTmlView(context),
              child: const Text(
                'Planner',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        // FAB COMPLETELY REMOVED – add happens from HomePage now
        floatingActionButton: null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16,
              ),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Search $titleText',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF5958b2),
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _search = value;
                  });
                },
              ),
            ),
            Expanded(
              // Wait for prefs/user context before attaching to a real path
              child: _userId.isEmpty ||
                      _userClientType.isEmpty ||
                      userEmail.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<QuerySnapshot>(
                      stream: _doctorsCollectionRef().snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final allDoctorsWithId =
                            snapshot.data!.docs.map((docSnap) {
                          final data =
                              docSnap.data() as Map<String, dynamic>;
                          return {
                            ...data,
                            "_id": docSnap.id,
                          };
                        }).toList();

                        final filteredDoctorsWithId =
                            allDoctorsWithId.where((doc) {
                          final displayName =
                              "${doc['lastName']}, ${doc['firstName']}";
                          final specialty = (doc['specialty'] ?? '')
                              .toString()
                              .toLowerCase();
                          final city = (doc['city'] ?? '')
                              .toString()
                              .toLowerCase();
                          final searchLower = _search.toLowerCase();
                          return displayName
                                  .toLowerCase()
                                  .contains(searchLower) ||
                              specialty.contains(searchLower) ||
                              city.contains(searchLower);
                        }).toList();

                        if (filteredDoctorsWithId.isEmpty) {
                          return Center(
                            child: Text(
                              "No ${_entityPlural().toLowerCase()} found",
                            ),
                          );
                        }

                        final groupedDoctors =
                            getGroupedDoctors(filteredDoctorsWithId);
                        final sortedInitials =
                            groupedDoctors.keys.toList()..sort();

                        return ListView.builder(
                          itemCount: sortedInitials.length,
                          itemBuilder: (context, idx) {
                            String initial = sortedInitials[idx];
                            var doctorsForLetter =
                                groupedDoctors[initial]!;
                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color.fromRGBO(
                                        152, 16, 250, 1),
                                    borderRadius:
                                        BorderRadius.circular(18),
                                  ),
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: Color(0xFFFFFFFF),
                                    ),
                                  ),
                                ),
                                ...doctorsForLetter.map(
                                  (doc) => ListTile(
                                    leading: const Icon(
                                      Icons.person,
                                      color: Color(0xFF5958b2),
                                    ),
                                    title: Text(
                                      "${doc["lastName"]}, ${doc["firstName"]}",
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 2),
                                        Text(doc["specialty"] ?? ''),
                                        Text(
                                          doc["city"] ?? '',
                                          style: TextStyle(
                                            color:
                                                Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      _navigateToDoctorDetail(
                                        context,
                                        doc,
                                        doc["_id"],
                                        startInEditMode: false,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}