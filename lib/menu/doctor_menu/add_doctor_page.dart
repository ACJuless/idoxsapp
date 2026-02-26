import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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

  final TextEditingController mdIdController = TextEditingController();
  final TextEditingController prcNoController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();
  final TextEditingController mobileNumberController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  String? _selectedSpecialty;
  String _selectedFrequency = "1X";
  final List<String> frequencyOptions = ["1X", "2X", "3X", "4X"];

  bool _isSaving = false;
  bool _isGeneratingId = false;

  // Signature: flat list of points with stroke ids
  final List<_SignaturePoint> _signaturePoints = [];
  int _currentStrokeId = 0;

  // Key to get the RenderBox of the signature area
  final GlobalKey _signaturePadKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _generateNextDoctorId();
  }

  Future<String> _getEmailKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    return userEmail.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
  }

  /// Generates the next doctor ID (e.g., RR-00003) based on the number of
  /// existing doctor documents in Firestore.
  Future<void> _generateNextDoctorId() async {
    setState(() {
      _isGeneratingId = true;
    });

    try {
      final emailKey = await _getEmailKey();

      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(emailKey)
          .doc('doctors')
          .collection('doctors')
          .get();

      final int currentCount = snapshot.size;
      final int nextNumber = currentCount + 1;

      final String formattedNumber = nextNumber.toString().padLeft(5, '0');
      final String generatedId = 'RR-$formattedNumber';

      mdIdController.text = generatedId;
    } catch (e) {
      // If ID generation fails, leave the field empty and let user input manually.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to generate ID automatically. You may input it manually."),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingId = false;
        });
      }
    }
  }

  /// Email validator: requires '@' and a basic domain (e.g. gmail.com, outlook.com).
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Email is required";
    }
    final email = value.trim();
    final RegExp emailRegex =
        RegExp(r'^[^@]+@[^@]+\.[^@]+'); // good enough for your use case
    if (!emailRegex.hasMatch(email)) {
      return "Please enter a valid email address";
    }
    return null;
  }

  /// Mobile validator: digits only, length exactly 11.
  String? _validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Mobile Number is required";
    }
    final mobile = value.trim();
    if (mobile.length != 11) {
      return "Mobile Number must be exactly 11 digits";
    }
    if (!RegExp(r'^\d{11}$').hasMatch(mobile)) {
      return "Mobile Number must contain digits only";
    }
    return null;
  }

  /// Generic required-field validator.
  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return "$fieldName is required";
    }
    return null;
  }

  Future<void> _selectBirthDate() async {
    FocusScope.of(context).unfocus(); // close keyboard if any
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(1900);
    final DateTime lastDate = now;

    DateTime initialDate = now;
    // If already has a value, try to parse and use as initial date.
    if (birthDateController.text.isNotEmpty) {
      try {
        initialDate = DateFormat('yyyy-MM-dd').parse(birthDateController.text);
      } catch (_) {
        initialDate = now;
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      birthDateController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  /// Convert signature points into a Firestore-friendly structure:
  /// List<Map<String, dynamic>>
  List<Map<String, dynamic>> _serializeSignature() {
    return _signaturePoints
        .map((p) => {
              'x': p.position.dx,
              'y': p.position.dy,
              'strokeId': p.strokeId,
            })
        .toList();
  }

  Future<void> _saveDoctor() async {
    final docId = mdIdController.text.trim();
    if (docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Doctor ID is required and must be unique"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final infoData = {
        'doc_id': docId,
        'lastName': lastNameController.text.trim(),
        'firstName': firstNameController.text.trim(),
        'middleName': middleNameController.text.trim(),
        'specialty': _selectedSpecialty ?? "",
        'freq': _selectedFrequency,
        'hospital': addressController.text.trim(),
        'city': cityController.text.trim(),
        // keep key names consistent with doctor_detail_page expectations
        'bday': birthDateController.text.trim(),
        'mob_no': mobileNumberController.text.trim(),
        'email': emailController.text.trim(),
        'prc_no': prcNoController.text.trim(),
        'signaturePoints': _serializeSignature(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      final emailKey = await _getEmailKey();

      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(emailKey)
          .doc('doctors')
          .collection('doctors')
          .doc(docId)
          .set(infoData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Doctor saved successfully"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving doctor: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Radio button color resolver
  MaterialStateProperty<Color> _radioColor() {
    return MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return Colors.white;
      }
      return Colors.black;
    });
  }

  void _onSignaturePanStart(DragStartDetails details) {
    final renderBox =
        _signaturePadKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    setState(() {
      _currentStrokeId++;
      _signaturePoints.add(
        _SignaturePoint(position: localPosition, strokeId: _currentStrokeId),
      );
    });
  }

  void _onSignaturePanUpdate(DragUpdateDetails details) {
    final renderBox =
        _signaturePadKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    setState(() {
      _signaturePoints.add(
        _SignaturePoint(position: localPosition, strokeId: _currentStrokeId),
      );
    });
  }

  void _onSignaturePanEnd(DragEndDetails details) {
    // Nothing special needed; strokeId already advanced on next start.
  }

  void _clearSignature() {
    setState(() {
      _signaturePoints.clear();
      _currentStrokeId = 0;
    });
  }

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Doctor"),
        backgroundColor: Color(0xFF5958b2),
      ),
      backgroundColor: Color(0xFF5958b2),

      /// Floating Buttons
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.extended(
            heroTag: "cancelBtn",
            backgroundColor: Colors.grey,
            label: Text("Cancel"),
            onPressed:
                _isSaving ? null : () => Navigator.of(context).pop(false),
          ),
          SizedBox(width: 20),
          FloatingActionButton.extended(
            heroTag: "saveBtn",
            backgroundColor: Colors.green,
            label: _isSaving
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text("Save"),
            onPressed: _isSaving
                ? null
                : () async {
                    if (_formKey.currentState?.validate() != true) return;

                    if (_selectedSpecialty == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Please select a category"),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    await _saveDoctor();
                  },
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _sectionTitle("ID"),
              Stack(
                alignment: Alignment.centerRight,
                children: [
                  _buildInput(
                    "Input ID",
                    mdIdController,
                    readOnly: true,
                    validator: (v) => _validateRequired(v, "ID"),
                  ),
                  if (_isGeneratingId)
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                ],
              ),
              _buildInput(
                "PRC No.",
                prcNoController,
                keyboardType: TextInputType.text,
                validator: (v) => _validateRequired(v, "PRC No."),
              ),

              _sectionTitle("Full Name"),
              _buildInput(
                "Last Name",
                lastNameController,
                validator: (v) => _validateRequired(v, "Last Name"),
              ),
              _buildInput(
                "First Name",
                firstNameController,
                validator: (v) => _validateRequired(v, "First Name"),
              ),
              _buildInput(
                "Middle Name",
                middleNameController,
                validator: (v) => _validateRequired(v, "Middle Name"),
              ),

              _sectionTitle("Other Information"),
              // Birth Date as date picker
              TextFormField(
                controller: birthDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Birth Date",
                  filled: true,
                  fillColor: Colors.white,
                ),
                onTap: _selectBirthDate,
                validator: (v) => _validateRequired(v, "Birth Date"),
              ),
              _buildInput(
                "Email",
                emailController,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
              TextFormField(
                controller: mobileNumberController,
                decoration: InputDecoration(
                  labelText: "Mobile Number",
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                validator: _validateMobile,
              ),
              _buildInput(
                "Address",
                addressController,
                validator: (v) => _validateRequired(v, "Address"),
              ),
              _buildInput(
                "City",
                cityController,
                validator: (v) => _validateRequired(v, "City"),
              ),

              _sectionTitle("Category"),
              Container(
                height: 190,
                child: Scrollbar(
                  child: ListView.builder(
                    itemCount: specialtyOptions.length,
                    itemBuilder: (context, index) {
                      return RadioListTile<String>(
                        value: specialtyOptions[index],
                        groupValue: _selectedSpecialty,
                        title: Text(
                          specialtyOptions[index],
                          style: TextStyle(color: Colors.white),
                        ),
                        fillColor: _radioColor(),
                        onChanged: (v) =>
                            setState(() => _selectedSpecialty = v),
                      );
                    },
                  ),
                ),
              ),

              _sectionTitle("Frequency of Visits"),
              Row(
                children: frequencyOptions.map((freq) {
                  return Expanded(
                    child: RadioListTile<String>(
                      value: freq,
                      groupValue: _selectedFrequency,
                      title: Text(freq, style: TextStyle(color: Colors.white)),
                      fillColor: _radioColor(),
                      onChanged: (v) =>
                          setState(() => _selectedFrequency = v!),
                    ),
                  );
                }).toList(),
              ),

              // Signature input area
              _sectionTitle("Signature"),
              Container(
                key: _signaturePadKey,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black54),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: GestureDetector(
                  onPanStart: _onSignaturePanStart,
                  onPanUpdate: _onSignaturePanUpdate,
                  onPanEnd: _onSignaturePanEnd,
                  child: CustomPaint(
                    painter: _SignaturePainter(
                      points: _signaturePoints,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _clearSignature,
                  icon: Icon(Icons.clear, color: Colors.white),
                  label: Text(
                    "Clear Signature",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),

              SizedBox(height: 100), // spacing for floating buttons
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 25,
              color: Colors.white,
            ),
          ),
        ),
      );

  Widget _buildInput(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
        ),
        validator: validator ?? (v) => _validateRequired(v, label),
      );
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

      // Only connect consecutive points from the same stroke
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
