import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tml_view.dart';
import 'doctor_detail_page.dart';
import 'add_doctor_page.dart';

class DoctorPage extends StatefulWidget {
  @override
  _DoctorPageState createState() => _DoctorPageState();
}

class _DoctorPageState extends State<DoctorPage>
    with SingleTickerProviderStateMixin {
  String _search = '';
  String userEmail = '';
  String emailKey = '';
  String _userClientType = ''; // client type from SharedPreferences
  String _userId = ''; // MR ID (e.g. MR00001) from SharedPreferences

  late AnimationController _fabController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _translateEditAnimation;
  late Animation<double> _translateDeleteAnimation;
  bool _isFabOpen = false;

  // Modes
  bool _isDeleteMode = false;
  bool _isEditMode = false;

  static const double _fabBaseOffset = 16.0;
  static const double _fabSpacing = 80.0;

  @override
  void initState() {
    super.initState();
    _loadUserPrefs();

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOut,
    );

    _translateEditAnimation = Tween<double>(
      begin: 0.0,
      end: _fabSpacing,
    ).animate(
      CurvedAnimation(
        parent: _fabController,
        curve: Curves.easeOutBack,
      ),
    );

    _translateDeleteAnimation = Tween<double>(
      begin: 0.0,
      end: _fabSpacing * 2,
    ).animate(
      CurvedAnimation(
        parent: _fabController,
        curve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
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
    _closeFabMenuIfOpen();
    _exitDeleteMode();
    _exitEditMode();
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
    _closeFabMenuIfOpen();
    _exitDeleteMode();
    _exitEditMode();
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

  void _navigateToAddDoctor(BuildContext context) async {
    _closeFabMenuIfOpen();
    _exitDeleteMode();
    _exitEditMode();
    final added = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddDoctorPage()),
    );
    if (added == true) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${_entitySingular()} added!")),
      );
    }
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

  void _onEditPressed() {
    setState(() {
      _isEditMode = true;
      _isDeleteMode = false;
    });
    _closeFabMenuIfOpen();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tap a yellow pencil to edit a ${_entitySingular().toLowerCase()}, or X to cancel.',
        ),
      ),
    );
  }

  void _onDeletePressed() {
    setState(() {
      _isDeleteMode = true;
      _isEditMode = false;
    });
    _closeFabMenuIfOpen();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tap the red "-" icons to delete ${_entityPlural().toLowerCase()}, or X to cancel.',
        ),
      ),
    );
  }

  void _toggleFabMenu() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  void _closeFabMenuIfOpen() {
    if (_isFabOpen) {
      setState(() {
        _isFabOpen = false;
        _fabController.reverse();
      });
    }
  }

  void _exitDeleteMode() {
    if (_isDeleteMode) {
      setState(() {
        _isDeleteMode = false;
      });
    }
  }

  void _exitEditMode() {
    if (_isEditMode) {
      setState(() {
        _isEditMode = false;
      });
    }
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

  Future<void> _deleteDoctor(String docId) async {
    try {
      final doctorsCollection = _doctorsCollectionRef();
      await doctorsCollection.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_entitySingular()} deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  Future<bool> _showDeleteConfirmDialog(String entityName) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Confirm Deletion',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "$entityName"?',
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop(false);
              },
              icon: const Icon(Icons.close, color: Colors.red),
              label: const Text(
                'Cancel',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop(true);
              },
              icon: const Icon(Icons.check_circle, color: Colors.green),
              label: const Text(
                'Confirm',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        );
      },
    );
    return result == true;
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

  Widget _buildAnimatedFabMenu() {
    final bool isMainInDeleteMode = _isDeleteMode;
    final bool isMainInEditMode = _isEditMode;
    final bool isMainInNeutral = !isMainInDeleteMode && !isMainInEditMode;

    return SizedBox(
      width: 280,
      height: 260,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          AnimatedBuilder(
            animation: _fabController,
            builder: (context, child) {
              final double bottomPos =
                  _fabBaseOffset + _translateDeleteAnimation.value;
              return Positioned(
                bottom: bottomPos,
                right: _fabBaseOffset,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizeTransition(
                        sizeFactor: _fadeAnimation,
                        axis: Axis.horizontal,
                        axisAlignment: -1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.80),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Delete ${_entityPlural()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      FloatingActionButton(
                        heroTag: 'delete_entity_fab',
                        onPressed: _onDeletePressed,
                        backgroundColor: Colors.redAccent,
                        child: const Icon(
                          Icons.delete_forever,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _fabController,
            builder: (context, child) {
              final double bottomPos =
                  _fabBaseOffset + _translateEditAnimation.value;
              return Positioned(
                bottom: bottomPos,
                right: _fabBaseOffset,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizeTransition(
                        sizeFactor: _fadeAnimation,
                        axis: Axis.horizontal,
                        axisAlignment: -1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.80),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Edit ${_entitySingular()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      FloatingActionButton(
                        heroTag: 'edit_entity_fab',
                        onPressed: _onEditPressed,
                        backgroundColor: const Color(0xFFFFB300),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: _fabBaseOffset,
            right: _fabBaseOffset,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizeTransition(
                  sizeFactor: _fadeAnimation,
                  axis: Axis.horizontal,
                  axisAlignment: -1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.80),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isMainInDeleteMode
                          ? 'Cancel Delete'
                          : (isMainInEditMode
                              ? 'Cancel Edit'
                              : 'Add ${_entityPlural()}'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                FloatingActionButton(
                  heroTag: "add_doctor_btn",
                  onPressed: () {
                    if (isMainInDeleteMode) {
                      _exitDeleteMode();
                    } else if (isMainInEditMode) {
                      _exitEditMode();
                    } else {
                      if (!_isFabOpen) {
                        _toggleFabMenu();
                      } else {
                        _navigateToAddDoctor(context);
                      }
                    }
                  },
                  backgroundColor: isMainInDeleteMode
                      ? Colors.redAccent
                      : (isMainInEditMode
                          ? const Color(0xFFFFB300)
                          : const Color(0xFF5958b2)),
                  child: Icon(
                    isMainInDeleteMode
                        ? Icons.close
                        : (isMainInEditMode ? Icons.close : Icons.add),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteLeading(Map<String, dynamic> doc) {
    return GestureDetector(
      onTap: () async {
        final name = "${doc["lastName"]}, ${doc["firstName"]}";
        final confirmed = await _showDeleteConfirmDialog(name);
        if (confirmed) {
          await _deleteDoctor(doc["_id"]);
        }
      },
      child: const CircleAvatar(
        radius: 14,
        backgroundColor: Colors.red,
        child: Icon(
          Icons.remove,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEditLeading(Map<String, dynamic> doc) {
    return InkWell(
      onTap: () {
        _navigateToDoctorDetail(
          context,
          doc,
          doc["_id"],
          startInEditMode: true,
        );
      },
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFFFB300),
            width: 2,
          ),
          color: Colors.transparent,
        ),
        child: const CircleAvatar(
          backgroundColor: Color(0xFFFFF3CD),
          child: Icon(
            Icons.edit,
            size: 18,
            color: Color(0xFFFFB300),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _entityPlural();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).unfocus();
        _closeFabMenuIfOpen();
        _exitDeleteMode();
        _exitEditMode();
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
        floatingActionButton: _buildAnimatedFabMenu(),
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
                                    leading: _isDeleteMode
                                        ? _buildDeleteLeading(doc)
                                        : (_isEditMode
                                            ? _buildEditLeading(doc)
                                            : const Icon(
                                                Icons.person,
                                                color: Color(0xFF5958b2),
                                              )),
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
                                      if (_isDeleteMode ||
                                          _isEditMode) {
                                        return;
                                      }
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