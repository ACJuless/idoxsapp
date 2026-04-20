import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _selectedTerritory;
  final List<String> _territoryOptions = ["PH-L", "PH-V", "PH-M"];

  bool _isManager = false; // "Manager?" switch state

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Determine clientType based on email domain
  String _determineClientType(String email) {
    final lower = email.toLowerCase();
    if (lower.endsWith('@indofil.com')) {
      return 'farmers';
    } else if (lower.endsWith('@iva.com') || lower.endsWith('@wert.com')) {
      return 'pharma';
    } else {
      return 'both'; // Can access both pharma and farmers
    }
  }

  /// Helper: generate the next sequential ID like MR00003 or MN00003
  /// inside a given /DaloyClients/{client}/Users collection.
  /// It counts only documents whose ID starts with the given prefix.
  Future<String> _getNextClientIdWithPrefix(
    String clientDocId,
    String prefix,
  ) async {
    final usersRef = FirebaseFirestore.instance
        .collection('DaloyClients')
        .doc(clientDocId)
        .collection('Users');

    // We can't query by ID prefix directly, so we fetch IDs and filter in memory.
    final snapshot = await usersRef.get();
    int count = 0;

    for (final doc in snapshot.docs) {
      if (doc.id.startsWith(prefix)) {
        count++;
      }
    }

    final int nextNum = count + 1;
    final String numStr = nextNum.toString().padLeft(5, '0');
    return '$prefix$numStr';
  }

  /// Determine Firestore path based on email domain and Manager flag.
  ///
  /// Final paths:
  /// - @indofil.com -> /DaloyClients/INDOFIL/Users/{MR/MN0000X}
  /// - @iva.com     -> /DaloyClients/IVA/Users/{MR/MN0000X}
  /// - @wert.com    -> /DaloyClients/WERT/Users/{MR/MN0000X}
  /// - others       -> /flowDB/client/GENERAL/users/users/{emailKey}
  Future<DocumentReference<Map<String, dynamic>>> _userDocRefForEmail(
    String email,
    String emailKey,
  ) async {
    final lower = email.toLowerCase();

    if (lower.endsWith('@indofil.com')) {
      // /DaloyClients/INDOFIL/Users/{MRxxxx / MNxxxx}
      final prefix = _isManager ? 'MN' : 'MR';
      final docId = await _getNextClientIdWithPrefix('INDOFIL', prefix);
      return FirebaseFirestore.instance
          .collection('DaloyClients')
          .doc('INDOFIL')
          .collection('Users')
          .doc(docId);
    } else if (lower.endsWith('@iva.com')) {
      // /DaloyClients/IVA/Users/{MRxxxx / MNxxxx}
      final prefix = _isManager ? 'MN' : 'MR';
      final docId = await _getNextClientIdWithPrefix('IVA', prefix);
      return FirebaseFirestore.instance
          .collection('DaloyClients')
          .doc('IVA')
          .collection('Users')
          .doc(docId);
    } else if (lower.endsWith('@wert.com')) {
      // /DaloyClients/WERT/Users/{MRxxxx / MNxxxx}
      final prefix = _isManager ? 'MN' : 'MR';
      final docId = await _getNextClientIdWithPrefix('WERT', prefix);
      return FirebaseFirestore.instance
          .collection('DaloyClients')
          .doc('WERT')
          .collection('Users')
          .doc(docId);
    } else {
      // /flowDB/client/GENERAL/users/users/{emailKey}
      return FirebaseFirestore.instance
          .collection('flowDB')
          .doc('client')
          .collection('GENERAL')
          .doc('users')
          .collection('users')
          .doc(emailKey);
    }
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final String email = _emailController.text.trim();
        final String hashedPassword = _hashPassword(_passwordController.text);
        final String emailKey =
            email.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
        final String name = _nameController.text.trim();
        final String clientType = _determineClientType(email);
        final lower = email.toLowerCase();

        // Resolve the document reference based on email domain and Manager flag
        final userDocRef = await _userDocRefForEmail(email, emailKey);

        // Base user data
        final Map<String, dynamic> userData = {
          'email': email.toLowerCase(),
          'password': hashedPassword,
          'name': name,
          'territoryId': _selectedTerritory,
          'clientType': clientType,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'isActive': true,
        };

        // Role logic for @iva.com only:
        // - Manager? = true  -> /DaloyUserRoles/NSM
        // - Manager? = false -> /DaloyUserRoles/Medrep
        if (lower.endsWith('@iva.com')) {
          final String roleDocId = _isManager ? 'NSM' : 'Medrep';
          userData['Role'] = FirebaseFirestore.instance
              .collection('DaloyUserRoles')
              .doc(roleDocId);
        }

        // Create the user document; parent docs/collections are created implicitly
        await userDocRef.set(userData);

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created successfully! Please login.'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating account: ${e.toString()}'),
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = [
      Color(0xFF221045),
      Color(0xFF4E2062),
      Color(0xFF7D4DD7),
    ];

    Widget formContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 160),
        Text(
          'Join iDoXs today!',
          style: TextStyle(
            fontSize: 65,
            fontWeight: FontWeight.bold,
            color: Color.fromRGBO(248, 242, 254, 1),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Create an account to get started',
          style: TextStyle(
            fontSize: 16,
            color: Color.fromRGBO(188, 184, 196, 1),
          ),
        ),
        SizedBox(height: 32),
        TextFormField(
          controller: _nameController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            fillColor: Color.fromRGBO(22, 18, 32, 0.5),
            filled: true,
            labelText: 'Full Name',
            labelStyle: TextStyle(color: Color.fromRGBO(188, 184, 196, 1)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your full name';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            fillColor: Color.fromRGBO(22, 18, 32, 0.5),
            filled: true,
            labelText: 'Email',
            labelStyle: TextStyle(color: Color.fromRGBO(188, 184, 196, 1)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!value.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            fillColor: Color.fromRGBO(22, 18, 32, 0.5),
            filled: true,
            labelText: 'Password',
            labelStyle: TextStyle(color: Color.fromRGBO(188, 184, 196, 1)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
          obscureText: _obscurePassword,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            fillColor: Color.fromRGBO(22, 18, 32, 0.5),
            filled: true,
            labelText: 'Confirm Password',
            labelStyle: TextStyle(color: Color.fromRGBO(188, 184, 196, 1)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: Colors.white,
              ),
              onPressed: () {
                setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                );
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
          obscureText: _obscureConfirmPassword,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedTerritory,
          items: _territoryOptions.map((territory) {
            return DropdownMenuItem(
              value: territory,
              child: Text(
                territory,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            );
          }).toList(),
          dropdownColor: Color.fromRGBO(44, 17, 122, 0.96),
          decoration: InputDecoration(
            fillColor: Color.fromRGBO(22, 18, 32, 0.5),
            filled: true,
            labelText: 'Territory ID',
            labelStyle: TextStyle(color: Color.fromRGBO(188, 184, 196, 1)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: Colors.white,
            size: 32,
          ),
          onChanged: (value) {
            setState(() => _selectedTerritory = value);
          },
          validator: (value) =>
              value == null || value.isEmpty
                  ? 'Please select a territory'
                  : null,
        ),
        SizedBox(height: 8),

        // "Manager?" switch with red when off and purple when on
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Switch(
              value: _isManager,
              onChanged: (value) {
                setState(() {
                  _isManager = value;
                });
              },
              activeColor: Color(0xFFa95dee),
              inactiveThumbColor: Colors.red,
              inactiveTrackColor: Colors.red.withOpacity(0.4),
            ),
            SizedBox(width: 8),
            Text(
              'Manager?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        SizedBox(height: 24),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 50),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFa95dee),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.deepPurpleAccent,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
        SizedBox(height: 16),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed('/login'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
          ),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
              children: [
                TextSpan(
                  text: "Already have an account? ",
                ),
                TextSpan(
                  text: "Sign in",
                  style: TextStyle(
                    color: Color(0xFFf9ae01),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: Form(
                key: _formKey,
                child: formContent,
              ),
            ),
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
    _confirmPasswordController.dispose();
    super.dispose();
  }
}