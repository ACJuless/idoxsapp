import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// Palette
const Color kDeepPurple = Color(0xFF4a2371);
const Color kMidPurple  = Color(0xFF5958b2);
const Color kSkyBlue    = Color(0xFF67c6ed);

const LinearGradient kHeaderGradient = LinearGradient(
  colors: [kDeepPurple, kMidPurple, kSkyBlue],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const List<String> specialtyOptions = [
  "Pediatricians",
  "OB-GYNs",
  "Family Doctors",
  "Neurologists",
  "Oncologists",
  "Cardiologists",
];

class AddDoctorPage extends StatefulWidget {
  @override
  State<AddDoctorPage> createState() => _AddDoctorPageState();
}

class _AddDoctorPageState extends State<AddDoctorPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController mdIdController         = TextEditingController();
  final TextEditingController prcNoController        = TextEditingController();
  final TextEditingController lastNameController     = TextEditingController();
  final TextEditingController firstNameController    = TextEditingController();
  final TextEditingController middleNameController   = TextEditingController();
  final TextEditingController addressController      = TextEditingController();
  final TextEditingController cityController         = TextEditingController();
  final TextEditingController birthDateController    = TextEditingController();
  final TextEditingController mobileNumberController = TextEditingController();
  final TextEditingController emailController        = TextEditingController();

  String? _selectedSpecialty;
  String  _selectedFrequency = "1X";
  final List<String> frequencyOptions = ["1X", "2X", "3X", "4X"];

  bool _isSaving        = false;
  bool _isGeneratingId  = false;

  int _currentStrokeId = 0;
  final GlobalKey _signaturePadKey = GlobalKey();

  String _userEmail      = '';
  String _userClientType = '';
  String _userId         = '';

  @override
  void initState() {
    super.initState();
    _loadUserContextAndInit();
  }

  Future<void> _loadUserContextAndInit() async {
    final prefs      = await SharedPreferences.getInstance();
    final email      = prefs.getString('userEmail')      ?? '';
    final clientType = prefs.getString('userClientType') ?? 'both';
    final userId     = prefs.getString('userId')         ?? '';

    setState(() {
      _userEmail      = email;
      _userClientType = clientType;
      _userId         = userId;
    });

    if (_userId.isNotEmpty && _userEmail.isNotEmpty) {
      await _generateNextDoctorId();
    }
  }

  String _getClientSegment() {
    if (_userClientType == 'farmers') return 'INDOFIL';
    if (_userClientType == 'pharma') {
      final lower = _userEmail.toLowerCase();
      if (lower.endsWith('@wert.com')) return 'WERT';
      return 'IVA';
    }
    final lower = _userEmail.toLowerCase();
    if (lower.endsWith('@indofil.com')) return 'INDOFIL';
    if (lower.endsWith('@wert.com'))    return 'WERT';
    if (lower.endsWith('@iva.com'))     return 'IVA';
    return 'GENERAL';
  }

  Future<CollectionReference<Map<String, dynamic>>> _getDoctorsCollectionRef() async {
    if (_userId.isEmpty || _userEmail.isEmpty || _userClientType.isEmpty) {
      throw Exception('User context (userId/email/clientType) missing');
    }
    final segment = _getClientSegment();
    return FirebaseFirestore.instance
        .collection('DaloyClients')
        .doc(segment)
        .collection('Users')
        .doc(_userId)
        .collection('Doctor');
  }

  Future<void> _generateNextDoctorId() async {
    setState(() => _isGeneratingId = true);
    try {
      final col      = await _getDoctorsCollectionRef();
      final snapshot = await col.get();
      final next     = snapshot.size + 1;
      mdIdController.text = 'MD-${next.toString().padLeft(5, '0')}';
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Failed to generate ID automatically. You may input it manually."),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isGeneratingId = false);
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return "Email is required";
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
      return "Please enter a valid email address";
    }
    return null;
  }

  String? _validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) return "Mobile Number is required";
    if (value.trim().length != 11)             return "Mobile Number must be exactly 11 digits";
    if (!RegExp(r'^\d{11}$').hasMatch(value.trim())) return "Mobile Number must contain digits only";
    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return "$fieldName is required";
    return null;
  }

  Future<void> _selectBirthDate() async {
    FocusScope.of(context).unfocus();
    final now  = DateTime.now();
    DateTime initialDate = now;
    if (birthDateController.text.isNotEmpty) {
      try { initialDate = DateFormat('yyyy-MM-dd').parse(birthDateController.text); }
      catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kMidPurple,
            onPrimary: Colors.white,
            onSurface: kDeepPurple,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      birthDateController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _saveDoctor() async {
    if (_userId.isEmpty || _userEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("User context missing. Please log in again."),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final docId = mdIdController.text.trim();
    if (docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Doctor ID is required and must be unique"),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final col = await _getDoctorsCollectionRef();
      await col.doc(docId).set({
        'doc_id':          docId,
        'lastName':        lastNameController.text.trim(),
        'firstName':       firstNameController.text.trim(),
        'middleName':      middleNameController.text.trim(),
        'specialty':       _selectedSpecialty ?? "",
        'freq':            _selectedFrequency,
        'hospital':        addressController.text.trim(),
        'city':            cityController.text.trim(),
        'bday':            birthDateController.text.trim(),
        'mob_no':          mobileNumberController.text.trim(),
        'email':           emailController.text.trim(),
        'prc_no':          prcNoController.text.trim(),
        'signaturePoints': _serializeSignature(),
        'createdAt':       FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Doctor saved successfully"),
        backgroundColor: Colors.green,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error saving doctor: $e"),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  final _signatureNotifier = ValueNotifier<List<_SignaturePoint>>([]);

  void _onSignaturePanStart(DragStartDetails d) {
    final rb = _signaturePadKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final size = rb.size;
    final local = rb.globalToLocal(d.globalPosition);
    final clamped = Offset(
      local.dx.clamp(0.0, size.width),
      local.dy.clamp(0.0, size.height),
    );
    _currentStrokeId++;
    final updated = List<_SignaturePoint>.from(_signatureNotifier.value)
      ..add(_SignaturePoint(position: clamped, strokeId: _currentStrokeId));
    _signatureNotifier.value = updated;
  }

  void _onSignaturePanUpdate(DragUpdateDetails d) {
    final rb = _signaturePadKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final size = rb.size;
    final local = rb.globalToLocal(d.globalPosition);
    final clamped = Offset(
      local.dx.clamp(0.0, size.width),
      local.dy.clamp(0.0, size.height),
    );
    final updated = List<_SignaturePoint>.from(_signatureNotifier.value)
      ..add(_SignaturePoint(position: clamped, strokeId: _currentStrokeId));
    _signatureNotifier.value = updated;
  }

  void _clearSignature() {
    _signatureNotifier.value = [];
    _currentStrokeId = 0;
  }

  List<Map<String, dynamic>> _serializeSignature() => _signatureNotifier.value
      .map((p) => {'x': p.position.dx, 'y': p.position.dy, 'strokeId': p.strokeId})
      .toList();

  @override
  void dispose() {
    mdIdController.dispose();
    prcNoController.dispose();
    lastNameController.dispose();
    firstNameController.dispose();
    middleNameController.dispose();
    addressController.dispose();
    cityController.dispose();
    birthDateController.dispose();
    mobileNumberController.dispose();
    emailController.dispose();
    _signatureNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kHeaderGradient),
        ),
        backgroundColor: Colors.transparent,
        title: const Text('Add Doctor'),
        actions: const [],
      ),

      // Body
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header banner (matches profile header style)
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(gradient: kHeaderGradient),
                padding: const EdgeInsets.only(top: 28, bottom: 36),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: kSkyBlue.withOpacity(0.3),
                      child: const Icon(Icons.person_add,
                          size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'New Doctor',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fill in the details below',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),

              // Form cards
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ID
                    _sectionLabel('Identification'),
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.centerRight,
                              children: [
                                _buildFormField(
                                  label: 'Doctor ID',
                                  icon: Icons.badge,
                                  controller: mdIdController,
                                  validator: (v) => _validateRequired(v, 'ID'),
                                ),
                                if (_isGeneratingId)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: kMidPurple,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _buildFormField(
                              label: 'PRC No.',
                              icon: Icons.card_membership,
                              controller: prcNoController,
                              validator: (v) => _validateRequired(v, 'PRC No.'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Full Name
                    _sectionLabel('Full Name'),
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Column(
                          children: [
                            _buildFormField(
                              label: 'Last Name',
                              icon: Icons.person,
                              controller: lastNameController,
                              validator: (v) => _validateRequired(v, 'Last Name'),
                            ),
                            const SizedBox(height: 6),
                            _buildFormField(
                              label: 'First Name',
                              icon: Icons.person_outline,
                              controller: firstNameController,
                              validator: (v) => _validateRequired(v, 'First Name'),
                            ),
                            const SizedBox(height: 6),
                            _buildFormField(
                              label: 'Middle Name',
                              icon: Icons.person_outline,
                              controller: middleNameController,
                              validator: (v) => _validateRequired(v, 'Middle Name'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Other Information
                    _sectionLabel('Other Information'),
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Column(
                          children: [
                            // Birth date
                            TextFormField(
                              controller: birthDateController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Birth Date',
                                labelStyle: TextStyle(
                                    fontSize: 12, color: Colors.grey),
                                prefixIcon: Icon(Icons.cake,
                                    color: kMidPurple),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 6),
                              ),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w500),
                              onTap: _selectBirthDate,
                              validator: (v) =>
                                  _validateRequired(v, 'Birth Date'),
                            ),
                            const SizedBox(height: 6),
                            _buildFormField(
                              label: 'Email',
                              icon: Icons.email,
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 6),
                            // Mobile number
                            TextFormField(
                              controller: mobileNumberController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(11),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Mobile Number',
                                labelStyle: TextStyle(
                                    fontSize: 12, color: Colors.grey),
                                prefixIcon:
                                    Icon(Icons.phone, color: kMidPurple),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 6),
                              ),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w500),
                              validator: _validateMobile,
                            ),
                            const SizedBox(height: 6),
                            _buildFormField(
                              label: 'Address',
                              icon: Icons.location_on,
                              controller: addressController,
                              validator: (v) => _validateRequired(v, 'Address'),
                            ),
                            const SizedBox(height: 6),
                            _buildFormField(
                              label: 'City',
                              icon: Icons.location_city,
                              controller: cityController,
                              validator: (v) =>
                                  _validateRequired(v, 'City'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Category
                    _sectionLabel('Category'),
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: specialtyOptions.map((s) {
                            final selected = _selectedSpecialty == s;
                            return SizedBox(
                              height: 40,
                              child: RadioListTile<String>(
                                value: s,
                                groupValue: _selectedSpecialty,
                                dense: true,
                                title: Text(
                                  s,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: selected ? kMidPurple : null,
                                  ),
                                ),
                                activeColor: kMidPurple,
                                onChanged: (v) =>
                                    setState(() => _selectedSpecialty = v),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // Frequency
                    _sectionLabel('Frequency of Visits'),
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          children: frequencyOptions.map((freq) {
                            final selected = _selectedFrequency == freq;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedFrequency = freq),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: selected ? kHeaderGradient : null,
                                    color: selected ? null : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      freq,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: selected
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // Signature
                    _sectionLabel('Signature'),
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              key: _signaturePadKey,
                              height: 180,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: GestureDetector(
                                  onPanStart: _onSignaturePanStart,
                                  onPanUpdate: _onSignaturePanUpdate,
                                  onPanEnd: (_) {},
                                  child: RepaintBoundary(
                                    child: ValueListenableBuilder<List<_SignaturePoint>>(
                                      valueListenable: _signatureNotifier,
                                      builder: (_, pts, __) => CustomPaint(
                                        painter: _SignaturePainter(points: pts),
                                        size: Size.infinite,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _clearSignature,
                                icon: const Icon(Icons.clear, color: kMidPurple),
                                label: const Text(
                                  'Clear Signature',
                                  style: TextStyle(color: kMidPurple),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Buttons
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          child: OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.of(context).pop(false),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kDeepPurple,
                              side: const BorderSide(color: kDeepPurple),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 140,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () async {
                                    if (_formKey.currentState?.validate() != true) return;
                                    if (_selectedSpecialty == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Please select a category"),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    await _saveDoctor();
                                  },
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.check, size: 18),
                            label: const Text('Save'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kMidPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 64),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helpers
  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4, left: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kDeepPurple,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _buildFormField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        prefixIcon: Icon(icon, color: kMidPurple),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      validator: validator ?? (v) => _validateRequired(v, label),
    );
  }
}

// Signature helpers
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
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = kDeepPurple
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final Map<int, List<Offset>> strokes = {};
    for (final p in points) {
      strokes.putIfAbsent(p.strokeId, () => []).add(p.position);
    }

    for (final pts in strokes.values) {
      if (pts.isEmpty) continue;

      if (pts.length == 1) {
        canvas.drawCircle(pts[0], 1.0, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }

      if (pts.length == 2) {
        canvas.drawLine(pts[0], pts[1], paint);
        continue;
      }

      final smoothed = _chaikin(pts, iterations: 2);
      final path = Path()..moveTo(smoothed[0].dx, smoothed[0].dy);
      for (int i = 1; i < smoothed.length; i++) {
        path.lineTo(smoothed[i].dx, smoothed[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  List<Offset> _chaikin(List<Offset> pts, {int iterations = 2}) {
    var result = pts;
    for (int iter = 0; iter < iterations; iter++) {
      final next = <Offset>[result.first];
      for (int i = 0; i < result.length - 1; i++) {
        final p0 = result[i];
        final p1 = result[i + 1];
        next.add(Offset(0.75 * p0.dx + 0.25 * p1.dx, 0.75 * p0.dy + 0.25 * p1.dy));
        next.add(Offset(0.25 * p0.dx + 0.75 * p1.dx, 0.25 * p0.dy + 0.75 * p1.dy));
      }
      next.add(result.last);
      result = next;
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) =>
      !identical(old.points, points);
}