import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

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
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  Color _selectedColor = Colors.blue;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['name'] ?? '');
    _emailController = TextEditingController(text: widget.userData['email'] ?? '');
    _passwordController = TextEditingController();
    _selectedColor = Color(widget.userData['themeColor'] ?? Colors.blue.value);
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final updateData = {
        'name': _nameController.text,
        'email': _emailController.text,
        'themeColor': _selectedColor.value,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_passwordController.text.isNotEmpty) {
        updateData['password'] = _hashPassword(_passwordController.text);
      }

      await _firestore.collection('users').doc(widget.docId).update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }
    setState(() => _isLoading = false);
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
                            child: Text(
                              _nameController.text.isNotEmpty 
                                ? _nameController.text[0].toUpperCase()
                                : '?',
                              style: TextStyle(fontSize: 36, color: _selectedColor),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              backgroundColor: _selectedColor,
                              radius: 18,
                              child: IconButton(
                                icon: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                onPressed: () {
                                  // TODO: Implement image picker
                                },
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

                    // Theme Color Picker
                    Text('App Theme Color', 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Colors.blue,
                        Colors.green,
                        Colors.purple,
                        Colors.red,
                        Colors.orange,
                        Colors.teal,
                      ].map((color) => InkWell(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          width: 40,
                          height: 40,
                          margin: EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColor == color 
                                ? Colors.white 
                                : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              if (_selectedColor == color)
                                BoxShadow(
                                  color: color.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
