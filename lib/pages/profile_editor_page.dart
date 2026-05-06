import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Palette
const Color _kDeepPurple = Color(0xFF4a2371);
const Color _kMidPurple  = Color(0xFF5958b2);
const Color _kSkyBlue    = Color(0xFF67c6ed);

const LinearGradient _kAppBarGradient = LinearGradient(
  colors: [_kDeepPurple, _kMidPurple, _kSkyBlue],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class ProfileEditorPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> userData;
  final String? clientType;

  const ProfileEditorPage({
    super.key,
    required this.docId,
    required this.userData,
    this.clientType,
  });

  @override
  State<ProfileEditorPage> createState() => _ProfileEditorPageState();
}

class _ProfileEditorPageState extends State<ProfileEditorPage> {
  final _formKey   = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _storage   = FirebaseStorage.instance;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  bool _isLoading       = false;
  bool _passwordVisible = false;

  File?   _profileImageFile;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _nameController     = TextEditingController(text: widget.userData['name']  ?? '');
    _emailController    = TextEditingController(text: widget.userData['email'] ?? '');
    _passwordController = TextEditingController();
    _photoUrl = widget.userData['photoUrl']        ??
                widget.userData['profileImageUrl'] ??
                widget.userData['profilePicture'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _resetForm() {
    setState(() {
      _nameController.text     = widget.userData['name']  ?? '';
      _emailController.text    = widget.userData['email'] ?? '';
      _passwordController.text = '';
      _passwordVisible         = false;
      _profileImageFile        = null;
      _photoUrl = widget.userData['photoUrl']        ??
                  widget.userData['profileImageUrl'] ??
                  widget.userData['profilePicture'];
    });
  }

  Future<void> _pickImage() async {
    try {
      final picker     = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() => _profileImageFile = File(pickedFile.path));
      }
    } catch (e) {
      _toast('Error picking image: $e');
    }
  }

  Future<String?> _uploadProfileImage(String userId) async {
    if (_profileImageFile == null) return _photoUrl;
    try {
      final path        = _profileImageFile!.path.toLowerCase();
      final isPng       = path.endsWith('.png');
      final contentType = isPng ? 'image/png' : 'image/jpeg';
      final ref         = _storage
          .ref()
          .child('profile_pics')
          .child('$userId${isPng ? '.png' : '.jpg'}');
      final snapshot = await ref
          .putFile(_profileImageFile!, SettableMetadata(contentType: contentType))
          .whenComplete(() {});
      if (snapshot.state == TaskState.success) {
        return await ref.getDownloadURL();
      }
      return _photoUrl;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      return _photoUrl;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final uploadedUrl = await _uploadProfileImage(widget.docId);
      final updateData = <String, dynamic>{
        'name':      _nameController.text.trim(),
        'email':     _emailController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        updateData['photoUrl'] = uploadedUrl;
      }
      if (_passwordController.text.isNotEmpty) {
        updateData['password'] = _hashPassword(_passwordController.text);
      }
      await _firestore
          .collection('users')
          .doc(widget.docId)
          .update(updateData);
      if (!mounted) return;
      setState(() {
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          _photoUrl = uploadedUrl;
        }
      });
      _toast('Profile updated successfully');
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error updating profile: $e');
      _toast('Error updating profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _kAppBarGradient),
        ),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kMidPurple))
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Gradient header banner
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(gradient: _kAppBarGradient),
                      padding: const EdgeInsets.only(top: 28, bottom: 36),
                      child: Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: _kSkyBlue.withValues(alpha: 0.3),
                              backgroundImage: _profileImageFile != null
                                  ? FileImage(_profileImageFile!)
                                  : (_photoUrl != null && _photoUrl!.isNotEmpty
                                      ? NetworkImage(_photoUrl!) as ImageProvider
                                      : null),
                              child: (_profileImageFile == null &&
                                      (_photoUrl == null || _photoUrl!.isEmpty))
                                  ? Text(
                                      _nameController.text.isNotEmpty
                                          ? _nameController.text[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_kMidPurple, _kSkyBlue],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Form fields
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      child: Column(
                        children: [
                          _buildFieldCard(
                            icon: Icons.person,
                            child: TextFormField(
                              controller: _nameController,
                              decoration: _fieldDecoration('Username'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Username is required'
                                  : null,
                            ),
                          ),
                          _buildFieldCard(
                            icon: Icons.email,
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _fieldDecoration('Email'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Email is required'
                                  : null,
                            ),
                          ),
                          _buildFieldCard(
                            icon: Icons.badge,
                            child: TextFormField(
                              initialValue: () {
                                final ct = widget.clientType
                                    ?? widget.userData['clientType'] as String?;
                                if (ct == null || ct.isEmpty) return '—';
                                return ct[0].toUpperCase() + ct.substring(1);
                              }(),
                              decoration: _fieldDecoration('Client Type'),
                              readOnly: true,
                              enabled: false,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          _buildFieldCard(
                            icon: Icons.lock,
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: !_passwordVisible,
                              decoration: _fieldDecoration(
                                'New Password (optional)',
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _passwordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: _kSkyBlue,
                                  ),
                                  onPressed: () => setState(
                                    () => _passwordVisible = !_passwordVisible,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 50),

                          // Reset + Save buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 150,
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: _resetForm,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: _kMidPurple, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'RESET',
                                    style: TextStyle(
                                      color: _kMidPurple,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 150,
                                height: 44,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_kDeepPurple, _kMidPurple, _kSkyBlue],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _saveProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      minimumSize: Size.zero,
                                      padding: EdgeInsets.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'SAVE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Widget helpers
  Widget _buildFieldCard({
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 12, top: 4, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: _kMidPurple),
            const SizedBox(width: 16),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
      border: InputBorder.none,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}