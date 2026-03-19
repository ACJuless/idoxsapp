import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as imgpkg;
import 'dart:convert';
import 'dart:io';
import 'add_note_input_for_calldetail_page.dart';
import 'add_visit_page.dart';
import 'call_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DoctorDetailPage extends StatefulWidget {
  final Map<String, dynamic>? doctor;
  final String doc_id;
  final bool startInEditMode;

  const DoctorDetailPage({
    Key? key,
    required this.doctor,
    required this.doc_id,
    this.startInEditMode = false,
  }) : super(key: key);

  @override
  State<DoctorDetailPage> createState() => _DoctorDetailPageState();
}

class _DoctorDetailPageState extends State<DoctorDetailPage>
    with SingleTickerProviderStateMixin {
  String? _profileImageBase64;
  bool _isUpdatingImage = false;
  String? emailKey;

  bool _isEditing = false;
  bool _isUpdatingDoctor = false;

  late TextEditingController _lastNameController;
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _birthDateController;
  late TextEditingController _mobileNumberController;
  late TextEditingController _specialtyController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _profileImageBase64 = widget.doctor?['profileImage'] as String?;
    _initControllersFromDoctor();
    _loadEmailKey();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _isEditing = widget.startInEditMode;
  }

  void _initControllersFromDoctor() {
    final d = widget.doctor ?? {};
    _lastNameController =
        TextEditingController(text: (d['lastName'] ?? '').toString());
    _firstNameController =
        TextEditingController(text: (d['firstName'] ?? '').toString());
    _middleNameController =
        TextEditingController(text: (d['middleName'] ?? '').toString());
    _birthDateController =
        TextEditingController(text: (d['bday'] ?? '').toString());
    _mobileNumberController =
        TextEditingController(text: (d['mob_no'] ?? '').toString());
    _specialtyController =
        TextEditingController(text: (d['specialty'] ?? '').toString());
    _addressController =
        TextEditingController(text: (d['hospital'] ?? '').toString());
    _emailController =
        TextEditingController(text: (d['email'] ?? '').toString());
  }

  Future<void> _loadEmailKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    setState(() {
      emailKey = userEmail.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
    });
  }

  String fullName() {
    final first = widget.doctor?['firstName'] ?? '';
    final middle = widget.doctor?['middleName'] ?? '';
    final last = widget.doctor?['lastName'] ?? '';
    return [last, first, middle]
        .where((s) => s.toString().trim().isNotEmpty)
        .join(', ');
  }

  String _doctorInitials() {
    final last = (widget.doctor?['lastName'] ?? '').toString();
    final first = (widget.doctor?['firstName'] ?? '').toString();
    return (last.isNotEmpty ? last[0].toUpperCase() : '') +
        (first.isNotEmpty ? first[0].toUpperCase() : '');
  }

  Widget infoRow(String label, String? value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$label:",
              style: const TextStyle(fontSize: 16, color: Color(0xFF555f6f)),
            ),
            const SizedBox(height: 2),
            Text(
              _formatPlannedInfo(label, value),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );

  String _formatPlannedInfo(String label, String? value) {
    if (value == null || value.isEmpty) return "---";

    if (label == 'Frequency of Planned Visits') {
      final freqPattern = RegExp(r'^(\d+)X$');
      final match = freqPattern.firstMatch(value);
      if (match != null) {
        final times = match.group(1);
        return "$times times a month";
      }
    }

    if (label.startsWith('Week ')) {
      final weekMap = {
        'M': 'Monday',
        'T': 'Tuesday',
        'W': 'Wednesday',
        'Th': 'Thursday',
        'F': 'Friday',
      };
      if (value == 'Th') return weekMap['Th']!;
      return weekMap[value] ?? value;
    }

    return value;
  }

  Widget sectionTitle(
    IconData icon,
    String title, {
    Color iconColor = const Color(0xFF2f9d36),
    Color iconBgColor = const Color(0xFFD3F7D9),
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 30.0, bottom: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      );

  Future<void> _pickAndUploadProfileImage() async {
    setState(() {
      _isUpdatingImage = true;
    });
    var status = await Permission.photos.request();
    if (!status.isGranted) {
      setState(() {
        _isUpdatingImage = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gallery access denied.')));
      return;
    }
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? imageFile =
          await picker.pickImage(source: ImageSource.gallery);
      if (imageFile == null) {
        setState(() {
          _isUpdatingImage = false;
        });
        return;
      }
      final imageBytes = await File(imageFile.path).readAsBytes();
      imgpkg.Image? decodedImage = imgpkg.decodeImage(imageBytes);
      if (decodedImage == null) throw Exception('Corrupt image file');
      imgpkg.Image resizedImage =
          imgpkg.copyResize(decodedImage, width: 220, height: 220);
      final compressedBytes = imgpkg.encodeJpg(resizedImage, quality: 80);
      final base64Img = base64Encode(compressedBytes);

      setState(() {
        _profileImageBase64 = base64Img;
        _isUpdatingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated.')),
      );
    } catch (e) {
      setState(() {
        _isUpdatingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload image.')),
      );
    }
  }

  void _enterEditMode() {
    setState(() {
      _isEditing = true;
      _initControllersFromDoctor();
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _initControllersFromDoctor();
    });
  }

  Future<void> _updateDoctor() async {
    if (emailKey == null || emailKey!.isEmpty) return;

    setState(() {
      _isUpdatingDoctor = true;
    });

    try {
      final Map<String, dynamic> updateData = {
        'lastName': _lastNameController.text.trim(),
        'firstName': _firstNameController.text.trim(),
        'middleName': _middleNameController.text.trim(),
        'bday': _birthDateController.text.trim(),
        'mob_no': _mobileNumberController.text.trim(),
        'specialty': _specialtyController.text.trim(),
        'hospital': _addressController.text.trim(),
        'email': _emailController.text.trim(),
      };

      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(emailKey!)
          .doc('doctors')
          .collection('doctors')
          .doc(widget.doc_id)
          .update(updateData);

      widget.doctor?.addAll(updateData);

      setState(() {
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Doctor information updated successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to update doctor: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingDoctor = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _lastNameController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _birthDateController.dispose();
    _mobileNumberController.dispose();
    _specialtyController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  List<_SignaturePoint> _buildSignaturePointsFromDoctor() {
    final raw = widget.doctor?['signaturePoints'];
    if (raw == null || raw is! List) return [];
    final List<_SignaturePoint> points = [];
    for (final item in raw) {
      if (item is Map) {
        final x = item['x'];
        final y = item['y'];
        final strokeId = item['strokeId'];
        if (x is num && y is num && strokeId is num) {
          points.add(
            _SignaturePoint(
              position: Offset(x.toDouble(), y.toDouble()),
              strokeId: strokeId.toInt(),
            ),
          );
        }
      }
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    if (emailKey == null || emailKey!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Doctor')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final int currentTabIndex = _tabController.index;
    final signaturePoints = _buildSignaturePointsFromDoctor();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${widget.doctor?['lastName'] ?? ''}, ${widget.doctor?['firstName'] ?? ''}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'ID: ${widget.doctor?['doc_id'] ?? ''}',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF5958b2),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: "Info"),
            Tab(text: "Call Notes"),
            Tab(text: "Visits"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // INFO TAB
          ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0, right: 80),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3EDFA),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Color(0xFF8269a1),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Personal Information",
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: FloatingActionButton(
                      heroTag: "info_edit_fab",
                      mini: true,
                      backgroundColor: const Color(0xFF5958b2),
                      foregroundColor: Colors.white,
                      onPressed: _isUpdatingDoctor
                          ? null
                          : () {
                              if (_isEditing) {
                                _cancelEdit();
                              } else {
                                _enterEditMode();
                              }
                            },
                      child: Icon(
                        _isEditing ? Icons.close : Icons.edit,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              Center(
                child: GestureDetector(
                  onTap: _isUpdatingImage ? null : _pickAndUploadProfileImage,
                  child: CircleAvatar(
                    radius: 95,
                    backgroundColor: const Color(0xFF8269a1),
                    child: _isUpdatingImage
                        ? const CircularProgressIndicator(color: Colors.white)
                        : (_profileImageBase64 != null &&
                                _profileImageBase64!.isNotEmpty)
                            ? ClipOval(
                                child: Image.memory(
                                  base64Decode(_profileImageBase64!),
                                  width: 180,
                                  height: 180,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Text(
                                _doctorInitials().isNotEmpty
                                    ? _doctorInitials()
                                    : "DR",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 68,
                                  color: Colors.white,
                                ),
                              ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Card(
                elevation: 40,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _isEditing
                                ? _editableTextField(
                                    label: "Last Name",
                                    controller: _lastNameController,
                                  )
                                : infoRow(
                                    "Last Name",
                                    widget.doctor?['lastName']?.toString(),
                                  ),
                            _isEditing
                                ? _editableTextField(
                                    label: "First Name",
                                    controller: _firstNameController,
                                  )
                                : infoRow(
                                    "First Name",
                                    widget.doctor?['firstName']?.toString(),
                                  ),
                            _isEditing
                                ? _editableTextField(
                                    label: "Middle Name",
                                    controller: _middleNameController,
                                  )
                                : infoRow(
                                    "Middle Name",
                                    widget.doctor?['middleName']?.toString(),
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _isEditing
                                ? _editableTextField(
                                    label: "Birth Date (yyyy-MM-dd)",
                                    controller: _birthDateController,
                                  )
                                : infoRow(
                                    "Birth Date",
                                    widget.doctor?['bday']?.toString(),
                                  ),
                            _isEditing
                                ? _editableTextField(
                                    label: "Mobile Number",
                                    controller: _mobileNumberController,
                                    keyboardType: TextInputType.number,
                                  )
                                : infoRow(
                                    "Mobile Number",
                                    widget.doctor?['mob_no']?.toString(),
                                  ),
                            _isEditing
                                ? _editableTextField(
                                    label: "Specialty",
                                    controller: _specialtyController,
                                  )
                                : infoRow(
                                    "Specialty",
                                    widget.doctor?['specialty']?.toString(),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              sectionTitle(Icons.calendar_today, "Call Plan"),
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      infoRow('Frequency of Planned Visits',
                          widget.doctor?['freq']?.toString()),
                    ],
                  ),
                ),
              ),
              sectionTitle(Icons.home, "Address",
                  iconColor: const Color(0xFF2b6cb0),
                  iconBgColor: const Color(0xFFE3EFFF)),
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _isEditing
                          ? _editableTextField(
                              label: "Address",
                              controller: _addressController,
                            )
                          : infoRow(
                              'Address',
                              widget.doctor?['hospital']?.toString(),
                            ),
                    ],
                  ),
                ),
              ),
              sectionTitle(Icons.people, "Profile",
                  iconColor: const Color(0xFF8269a1),
                  iconBgColor: const Color(0xFFF3EDFA)),
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      infoRow('PRC No.', widget.doctor?['prc_no']?.toString()),
                      _isEditing
                          ? _editableTextField(
                              label: "Email", controller: _emailController)
                          : infoRow(
                              'Email',
                              widget.doctor?['email']?.toString(),
                            ),
                    ],
                  ),
                ),
              ),
              sectionTitle(Icons.call, "Specimen Signature"),
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Container(
                  height: 180,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(12),
                  child: signaturePoints.isEmpty
                      ? Text(
                          "No specimen signature.",
                          style:
                              TextStyle(fontSize: 15, color: Colors.grey[700]),
                        )
                      : CustomPaint(
                          painter: _SignaturePainter(points: signaturePoints),
                          size: Size.infinite,
                        ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),

          // CALL NOTES TAB
          CallNotesTab(docId: widget.doc_id, emailKey: emailKey!),

          // VISITS TAB
          VisitsTab(
            docId: widget.doc_id,
            doctor: widget.doctor,
            emailKey: emailKey!,
            monthId: null, // null = current month
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: currentTabIndex == 0
          ? (_isEditing
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: "edit_cancel",
                      backgroundColor: Colors.grey,
                      onPressed: _isUpdatingDoctor ? null : _cancelEdit,
                      label: const Text("Cancel"),
                    ),
                    const SizedBox(width: 20),
                    FloatingActionButton.extended(
                      heroTag: "edit_update",
                      backgroundColor: Colors.green,
                      onPressed: _isUpdatingDoctor ? null : _updateDoctor,
                      label: _isUpdatingDoctor
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Update"),
                    ),
                  ],
                )
              : null)
          : (currentTabIndex == 2
              ? FloatingActionButton(
                  heroTag: "visits_plus",
                  backgroundColor: const Color(0xFF5958b2),
                  foregroundColor: Colors.white,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddVisitPage(docId: widget.doc_id),
                      ),
                    );
                  },
                  child: const Icon(Icons.add),
                )
              : null),
    );
  }

  Widget _editableTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

class CallNotesTab extends StatelessWidget {
  final String docId;
  final String emailKey;

  const CallNotesTab({Key? key, required this.docId, required this.emailKey})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('flowDB')
            .doc('users')
            .collection(emailKey)
            .doc('doctors')
            .collection('doctors')
            .doc(docId)
            .collection('callNotes')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notes = snapshot.data!.docs;
          if (notes.isEmpty) {
            return const Center(child: Text("No call notes yet."));
          }
          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, idx) {
              final note = notes[idx].data() as Map<String, dynamic>?;
              final ts = note?['timestamp'] as Timestamp?;
              final dt = ts != null ? ts.toDate() : DateTime.now();
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: ListTile(
                  title: Text(
                    note?['text'] ?? '',
                    style: const TextStyle(fontSize: 17),
                  ),
                  subtitle: Text(
                    "${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} "
                    "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}",
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class VisitsTab extends StatelessWidget {
  final String docId;
  final Map<String, dynamic>? doctor;
  final String emailKey;

  final String? monthId;

  const VisitsTab({
    Key? key,
    required this.docId,
    required this.doctor,
    required this.emailKey,
    this.monthId,
  }) : super(key: key);

  String _currentMonthId() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM').format(now);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final effectiveMonthId = monthId ?? _currentMonthId();

    final monthDocRef = FirebaseFirestore.instance
        .collection('flowDB')
        .doc('users')
        .collection(emailKey)
        .doc('doctors')
        .collection('doctors')
        .doc(docId)
        .collection('scheduledVisits')
        .doc('months')
        .collection('months')
        .doc(effectiveMonthId);

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: monthDocRef
            .collection('dates')
            .orderBy('scheduledDate')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final visits = snapshot.data!.docs;
          if (visits.isEmpty) {
            return const Center(child: Text("No scheduled visits yet."));
          }
          return ListView.builder(
            itemCount: visits.length,
            itemBuilder: (context, idx) {
              final visitDoc = visits[idx];
              final visit = visitDoc.data() as Map<String, dynamic>?;
              final scheduledDateStr = visit?['scheduledDate'] ?? '';
              final scheduledTime = visit?['scheduledTime'] ?? '';
              final visitId = visitDoc.id;

              final bool isSubmitted = visit?['submitted'] == true;
              final bool isSurprise = visit?['surprise'] == true;

              DateTime? visitDate;
              try {
                visitDate =
                    DateFormat('yyyy-MM-dd').parse(scheduledDateStr);
              } catch (_) {
                visitDate = null;
              }

              Color cardColor = Colors.white;
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
                margin:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: ListTile(
                  title: Text(
                    scheduledDateStr,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("$scheduledTime"),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallDetailPage(
                            doctor: doctor ?? {},
                            scheduledVisitId: visitId,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Visit Now"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SignaturePoint {
  final Offset position;
  final int strokeId;
  _SignaturePoint({required this.position, required this.strokeId});
}

class _SignaturePainter extends CustomPainter {
  final List<_SignaturePoint> points;

  _SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      if (p1.strokeId == p2.strokeId) {
        canvas.drawLine(p1.position, p2.position, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
