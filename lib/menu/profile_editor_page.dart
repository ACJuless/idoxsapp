// profile_editor_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileEditorPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> userData;

  const ProfileEditorPage({
    Key? key,
    required this.docId,
    required this.userData,
  }) : super(key: key);

  @override
  _ProfileEditorPageState createState() => _ProfileEditorPageState();
}

class _ProfileEditorPageState extends State<ProfileEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  Color _selectedColor = Colors.blue;
  bool _isLoading = false;

  File? _profileImageFile;
  String? _photoUrl; // store current profile picture (download URL)

  @override
  void initState() {
    super.initState();

    // Initialize controllers with passed userData
    _nameController = TextEditingController(text: widget.userData['name'] ?? '');
    _emailController = TextEditingController(text: widget.userData['email'] ?? '');
    _passwordController = TextEditingController();
    _selectedColor = Color(widget.userData['themeColor'] ?? Colors.blue.value);

    // Try to support different possible field names that might be in other parts
    _photoUrl = widget.userData['photoUrl'] ??
        widget.userData['profileImageUrl'] ??
        widget.userData['profilePicture'] ??
        null;
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Let the user pick from gallery (imageQuality reduces file size).
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

      if (pickedFile != null) {
        setState(() {
          _profileImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      // Show simple feedback if picker fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  /// Upload profile image to Firebase Storage and return download URL.
  /// If no new file selected, returns existing _photoUrl.
  Future<String?> _uploadProfileImage(String userId) async {
    if (_profileImageFile == null) return _photoUrl; // nothing to upload

    try {
      // Determine content type by file extension (basic approach)
      final path = _profileImageFile!.path.toLowerCase();
      final isPng = path.endsWith('.png');
      final contentType = isPng ? 'image/png' : 'image/jpeg';

      final ref = _storage.ref().child('profile_pics').child('$userId${isPng ? '.png' : '.jpg'}');

      final metadata = SettableMetadata(contentType: contentType);

      final uploadTask = ref.putFile(_profileImageFile!, metadata);

      // Optionally show upload progress by listening to snapshot events (not shown in UI here)
      final snapshot = await uploadTask.whenComplete(() {});
      if (snapshot.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        return downloadUrl;
      } else {
        // Fallback to old URL if for some reason upload didn't succeed
        print('Upload completed but state=${snapshot.state}');
        return _photoUrl;
      }
    } catch (e) {
      print('Error uploading profile image: $e');
      // Do not throw to avoid breaking the whole save process; caller will handle null/old url
      return _photoUrl;
    }
  }

  /// Save profile: upload image first (if any), then update Firestore doc.
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // upload image (if selected)
      final uploadedUrl = await _uploadProfileImage(widget.docId);

      final updateData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'themeColor': _selectedColor.value,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // include photo url if available
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        updateData['photoUrl'] = uploadedUrl;
      }

      if (_passwordController.text.isNotEmpty) {
        updateData['password'] = _hashPassword(_passwordController.text);
      }

      // Update the Firestore user document (merge/update)
      await _firestore.collection('users').doc(widget.docId).update(updateData);

      // update local state so UI reflects saved image immediately
      setState(() {
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) _photoUrl = uploadedUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );

      // Close editor and return to previous screen
      Navigator.pop(context);
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        backgroundColor: _selectedColor,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Picture Section
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: _selectedColor.withOpacity(0.2),
                            backgroundImage: _profileImageFile != null
                                ? FileImage(_profileImageFile!)
                                : (_photoUrl != null && _photoUrl!.isNotEmpty
                                    ? NetworkImage(_photoUrl!) as ImageProvider
                                    : null),
                            child: (_profileImageFile == null && (_photoUrl == null || _photoUrl!.isEmpty))
                                ? Text(
                                    _nameController.text.isNotEmpty
                                        ? _nameController.text[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(fontSize: 36, color: _selectedColor),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              backgroundColor: _selectedColor,
                              radius: 18,
                              child: IconButton(
                                icon: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    // Username Field
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Username is required' : null,
                    ),
                    SizedBox(height: 16),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Email is required' : null,
                    ),
                    SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'New Password (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    SizedBox(height: 24),
                    SizedBox(height: 8),
                    // Wrap(
                    //   spacing: 8,
                    //   children: [
                    //     Colors.blue,
                    //     Colors.green,
                    //     Colors.purple,
                    //     Colors.red,
                    //     Colors.orange,
                    //     Colors.teal,
                    //   ].map((color) => InkWell(
                    //         onTap: () => setState(() => _selectedColor = color),
                    //         child: Container(
                    //           width: 40,
                    //           height: 40,
                    //           margin: EdgeInsets.only(bottom: 8),
                    //           decoration: BoxDecoration(
                    //             color: color,
                    //             shape: BoxShape.circle,
                    //             border: Border.all(
                    //               color: _selectedColor == color
                    //                   ? Colors.white
                    //                   : Colors.transparent,
                    //               width: 2,
                    //             ),
                    //             boxShadow: [
                    //               if (_selectedColor == color)
                    //                 BoxShadow(
                    //                   color: color.withOpacity(0.4),
                    //                   blurRadius: 8,
                    //                   spreadRadius: 2,
                    //                 ),
                    //             ],
                    //           ),
                    //         ),
                    //       ))
                    //       .toList(),
                    // ),
                    SizedBox(height: 24),

                    // Save Button
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedColor,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
