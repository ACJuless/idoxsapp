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

const LinearGradient _kGradient = LinearGradient(
  colors: [_kDeepPurple, _kMidPurple, _kSkyBlue],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class ProfileEditorPage extends StatefulWidget {
  final String docId;
  final String collectionPath;
  final Map<String, dynamic> userData;
  final String? clientType;

  const ProfileEditorPage({
    super.key,
    required this.docId,
    required this.collectionPath,
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

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmNewPasswordController;

  // UI state
  bool _isSaving               = false;
  bool _currentPasswordVisible = false;
  bool _newPasswordVisible     = false;
  bool _confirmPasswordVisible = false;
  bool _showPasswordSection    = false;
  bool _plainPasswordVisible   = false;
  final FocusNode _plainPasswordFocusNode = FocusNode(canRequestFocus: false);

  // Image state
  File?   _profileImageFile;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _nameController               = TextEditingController(text: widget.userData['name']  ?? '');
    _emailController              = TextEditingController(text: widget.userData['email'] ?? '');
    _currentPasswordController    = TextEditingController();
    _newPasswordController        = TextEditingController();
    _confirmNewPasswordController = TextEditingController();

    _photoUrl = widget.userData['photoUrl']        ??
                widget.userData['profileImageUrl'] ??
                widget.userData['profilePicture'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    _plainPasswordFocusNode.dispose();
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
      _nameController.text               = widget.userData['name']  ?? '';
      _emailController.text              = widget.userData['email'] ?? '';
      _currentPasswordController.text    = '';
      _newPasswordController.text        = '';
      _confirmNewPasswordController.text = '';
      _currentPasswordVisible            = false;
      _newPasswordVisible                = false;
      _confirmPasswordVisible            = false;
      _showPasswordSection               = false;
      _profileImageFile                  = null;
      _photoUrl = widget.userData['photoUrl']        ??
                  widget.userData['profileImageUrl'] ??
                  widget.userData['profilePicture'];
    });
  }

  // Image picker & upload
  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
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

  /// Upload profile image to Firebase Storage and return download URL.
  /// If no new file selected, returns existing _photoUrl.
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
      // Fallback to old URL if for some reason upload didn't succeed
      return _photoUrl;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      // Do not throw to avoid breaking the whole save process; caller will handle null/old url
      return _photoUrl;
    }
  }

  // Password verification
  Future<bool> _verifyCurrentPassword(String typedPassword) async {
    try {
      final doc = await _firestore
          .collection(widget.collectionPath)
          .doc(widget.docId)
          .get();

      if (!doc.exists) return false;

      final storedHash = doc.data()?['password'] as String?;
      if (storedHash == null || storedHash.isEmpty) return false;

      return _hashPassword(typedPassword) == storedHash;
    } catch (e) {
      debugPrint('Error verifying password: $e');
      return false;
    }
  }

  // Save
  Future<void> _saveProfile() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Password change verification
      if (_showPasswordSection && _newPasswordController.text.isNotEmpty) {
        final isCorrect =
            await _verifyCurrentPassword(_currentPasswordController.text);
        if (!isCorrect) {
          _toast('Current password is incorrect.');
          return;
        }
      }

      // Upload image
      final uploadedUrl = await _uploadProfileImage(widget.docId);

      // Build update payload
      final updateData = <String, dynamic>{
        'name':      _nameController.text.trim(),
        'email':     _emailController.text.trim().toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        updateData['photoUrl'] = uploadedUrl;
      }

      if (_showPasswordSection && _newPasswordController.text.isNotEmpty) {
        updateData['password']      = _hashPassword(_newPasswordController.text);
        updateData['plainPassword'] = _newPasswordController.text;
      }

      // Write to Firestore
      await _firestore
          .collection(widget.collectionPath)
          .doc(widget.docId)
          .update(updateData);

      if (!mounted) return;

      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        setState(() => _photoUrl = uploadedUrl);
      }

      _toast('Profile updated successfully.');
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error updating profile: $e');
      _toast('Error updating profile: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _kGradient),
        ),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Profile'),
      ),
      bottomNavigationBar: _buildFooter(),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: _kMidPurple))
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAvatarHeader(),
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
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
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
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Email is required'
                                      : null,
                            ),
                          ),
                          _buildFieldCard(
                            icon: Icons.badge,
                            child: TextFormField(
                              initialValue: () {
                                final ct = widget.clientType ??
                                    widget.userData['clientType'] as String?;
                                if (ct == null || ct.isEmpty) return '—';
                                return ct[0].toUpperCase() + ct.substring(1);
                              }(),
                              decoration: _fieldDecoration('Client Type').copyWith(
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              readOnly: true,
                              enabled: false,
                            ),
                          ),
                          // _buildFieldCard(
                          //   icon: Icons.lock,
                          //   child: TextFormField(
                          //     initialValue: widget.userData['plainPassword'] ?? '—',
                          //     decoration: _fieldDecoration('Password').copyWith(
                          //       disabledBorder: OutlineInputBorder(
                          //         borderRadius: BorderRadius.circular(8),
                          //         borderSide: BorderSide(color: Colors.grey.shade300),
                          //       ),
                          //     ),
                          //     readOnly: true,
                          //     enabled: false,
                          //   ),
                          // ),
                          _buildFieldCard(
                            icon: Icons.lock,
                            child: TextFormField(
                              initialValue: widget.userData['plainPassword'] ?? '—',
                              obscureText: !_plainPasswordVisible,
                              focusNode: _plainPasswordFocusNode,
                              enableInteractiveSelection: false,
                              decoration: _fieldDecoration('Password').copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _plainPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                    color: _kSkyBlue,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _plainPasswordVisible = !_plainPasswordVisible),
                                ),
                              ),
                              readOnly: true,
                              enabled: true,
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Change Password toggle
                          _buildChangePasswordToggle(),

                          // Password fields
                          if (_showPasswordSection) ...[
                            const SizedBox(height: 4),
                            _buildPasswordField(
                              controller: _currentPasswordController,
                              label: 'Current Password',
                              isVisible: _currentPasswordVisible,
                              onToggle: () => setState(() =>
                                  _currentPasswordVisible =
                                      !_currentPasswordVisible),
                              validator: (v) =>
                                  (v == null || v.isEmpty)
                                      ? 'Enter your current password'
                                      : null,
                            ),
                            _buildPasswordField(
                              controller: _newPasswordController,
                              label: 'New Password',
                              isVisible: _newPasswordVisible,
                              onToggle: () => setState(
                                  () => _newPasswordVisible = !_newPasswordVisible),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Enter a new password';
                                }
                                if (v.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            _buildPasswordField(
                              controller: _confirmNewPasswordController,
                              label: 'Confirm New Password',
                              isVisible: _confirmPasswordVisible,
                              onToggle: () => setState(() =>
                                  _confirmPasswordVisible =
                                      !_confirmPasswordVisible),
                              validator: (v) =>
                                  v != _newPasswordController.text
                                      ? 'Passwords do not match'
                                      : null,
                            ),
                          ],

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFooter() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : _resetForm,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: _kMidPurple, width: 1.5),
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
            Expanded(child: _gradBtn('SAVE', _isSaving ? null : _saveProfile)),
          ],
        ),
      ),
    );
  }

  Widget _gradBtn(String label, VoidCallback? onPressed) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed != null ? _kGradient : null,
        color:    onPressed == null ? Colors.grey.shade300 : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor:     Colors.transparent,
          minimumSize:     const Size(double.infinity, 48),
          padding:         EdgeInsets.zero,
          tapTargetSize:   MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:        onPressed != null ? Colors.white : Colors.grey,
            fontWeight:   FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: _kGradient),
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
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangePasswordToggle() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            setState(() => _showPasswordSection = !_showPasswordSection),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: _kMidPurple),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Change Password',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kMidPurple,
                  ),
                ),
              ),
              Icon(
                _showPasswordSection
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: _kMidPurple,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return _buildFieldCard(
      icon: Icons.lock,
      child: TextFormField(
        controller: controller,
        obscureText: !isVisible,
        decoration: _fieldDecoration(label).copyWith(
          suffixIcon: IconButton(
            icon: Icon(
              isVisible ? Icons.visibility_off : Icons.visibility,
              color: _kSkyBlue,
            ),
            onPressed: onToggle,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildFieldCard({
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding:
            const EdgeInsets.only(left: 24, right: 12, top: 4, bottom: 4),
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
      border:         InputBorder.none,
      disabledBorder: InputBorder.none,   // ← add this
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}