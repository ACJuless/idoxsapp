import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedTerritory;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  final List<String> _territoryOptions = ["PH-L", "PH-V", "PH-M"];

  @override
  void initState() {
    super.initState();
    _checkRememberedLogin();
  }

  // Check if user is already logged in
  Future<void> _checkRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (isLoggedIn) {
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {
          'userEmail': prefs.getString('userEmail'),
          'userId': prefs.getString('userId'),
          'territoryId': prefs.getString('territoryId'),
          'userName': prefs.getString('userName'),
          'userClientType': prefs.getString('userClientType'),
        },
      );
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Helper: find user in the new client structure used by signup, using email field:
  /// - /DaloyClients/INDOFIL/Users   (query by email)
  /// - /DaloyClients/IVA/Users       (query by email)
  /// - /DaloyClients/WERT/Users      (query by email)
  /// - /flowDB/client/GENERAL/users/users (query by email)
  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserInClientTree(
    String email,
  ) async {
    final lower = email.toLowerCase();

    if (lower.endsWith('@indofil.com')) {
      // /DaloyClients/INDOFIL/Users  (ID is MRxxxxx, so query by email field)
      final usersRef = FirebaseFirestore.instance
          .collection('DaloyClients')
          .doc('INDOFIL')
          .collection('Users');
      final query = await usersRef
          .where('email', isEqualTo: lower)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return query.docs.first;
    } else if (lower.endsWith('@iva.com')) {
      // /DaloyClients/IVA/Users
      final usersRef = FirebaseFirestore.instance
          .collection('DaloyClients')
          .doc('IVA')
          .collection('Users');
      final query = await usersRef
          .where('email', isEqualTo: lower)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return query.docs.first;
    } else if (lower.endsWith('@wert.com')) {
      // /DaloyClients/WERT/Users
      final usersRef = FirebaseFirestore.instance
          .collection('DaloyClients')
          .doc('WERT')
          .collection('Users');
      final query = await usersRef
          .where('email', isEqualTo: lower)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return query.docs.first;
    } else {
      // /flowDB/client/GENERAL/users/users
      final usersRef = FirebaseFirestore.instance
          .collection('flowDB')
          .doc('client')
          .collection('GENERAL')
          .doc('users')
          .collection('users');
      final query = await usersRef
          .where('email', isEqualTo: lower)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return query.docs.first;
    }

    return null;
  }

  /// Only use new structure; lookups driven purely by email, not emailKey
  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserDoc(
    String email,
  ) async {
    return await _findUserInClientTree(email);
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final email = _emailController.text.trim();
        final hashedPassword = _hashPassword(_passwordController.text);

        if (_selectedTerritory == null || _selectedTerritory!.isEmpty) {
          throw Exception('Please select a territory');
        }

        // Use only the new client structure, querying by email
        final userDocSnap = await _findUserDoc(email);

        if (userDocSnap == null || !userDocSnap.exists) {
          throw Exception('Invalid email, password, or territory');
        }

        final userData = userDocSnap.data() as Map<String, dynamic>? ?? {};

        // Check territory
        if (userData['territoryId'] != _selectedTerritory) {
          throw Exception('Invalid email, password, or territory');
        }

        // Check password
        if (userData['password'] != hashedPassword) {
          throw Exception('Invalid password');
        }

        // Get clientType from user document (set during signup)
        final clientType = userData['clientType'] ?? 'both';

        // Mark user active and update last login
        await userDocSnap.reference.update({
          'isActive': true,
          'lastLogin': FieldValue.serverTimestamp(),
        });

        // Store login timestamp
        final prefs = await SharedPreferences.getInstance();
        final loginTime = DateTime.now().toIso8601String();
        await prefs.setString('loginTimestamp', loginTime);

        // Store clientType always
        await prefs.setString('userClientType', clientType);

        // If "Remember Me" is checked, store values for auto-login next time
        if (_rememberMe) {
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userEmail', email);
          await prefs.setString('userId', userDocSnap.id);
          await prefs.setString('territoryId', _selectedTerritory ?? '');
          await prefs.setString('userName', userData['name'] ?? '');
          await prefs.setString('userClientType', clientType);
        } else {
          // Still store basic info even if not remembering
          await prefs.setString('userEmail', email);
          await prefs.setString('userId', userDocSnap.id);
          await prefs.setString('territoryId', _selectedTerritory ?? '');
          await prefs.setString('userName', userData['name'] ?? '');
          await prefs.setString('userClientType', clientType);
        }

        // Pass needed data to home
        Navigator.pushReplacementNamed(
          context,
          '/home',
          arguments: {
            'userEmail': email,
            'userId': userDocSnap.id,
            'territoryId': _selectedTerritory,
            'userName': userData['name'] ?? '',
            'userClientType': clientType,
          },
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
            ),
          ),
        );
      }

      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = [
      Color(0xFF4b2874),
      Color(0xFF4b2874),
      Color(0xFF4b2874),
      Color(0xFF4b2874),
      Color(0xFF4b2874),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Container(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 3),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF4b2874),
                              Color(0xFF4a2371),
                              Color(0xFF4b2978),
                              Color(0xFF513a8e),
                              Color(0xFF523f93),
                              Color(0xFF534196),
                              Color(0xFF54469c),
                              Color(0xFF555aa1),
                              Color(0xFF5050aa),
                              Color(0xFF5750a9),
                              Color(0xFF5050aa),
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(50.0),
                            bottomRight: Radius.circular(50.0),
                          ),
                        ),
                        margin: EdgeInsets.zero,
                        child: Card(
                          color: Colors.transparent,
                          elevation: 100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(50.0),
                              bottomLeft: Radius.circular(50.0),
                            ),
                          ),
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(height: 16),
                                  Text(
                                    'iDoXs',
                                    style: TextStyle(
                                      fontSize: 100,
                                      fontWeight: FontWeight.bold,
                                      color: Color.fromRGBO(
                                        248,
                                        242,
                                        254,
                                        1,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Smarter sales. Stronger connections. Streamlined workflow.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFFf9ae01),
                                    ),
                                  ),
                                  SizedBox(height: 32),
                                  TextFormField(
                                    controller: _emailController,
                                    style: TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      fillColor: Color(0xFF3d3876),
                                      filled: true,
                                      labelStyle: TextStyle(color: Colors.white),
                                      labelText: 'Email',
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(30),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(30),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(30),
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
                                      fillColor: Color(0xFF3d3876),
                                      filled: true,
                                      labelStyle: TextStyle(color: Colors.white),
                                      labelText: 'Password',
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: Colors.white,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    obscureText: _obscurePassword,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      if (value.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    value: _selectedTerritory,
                                    items: _territoryOptions
                                        .map((territory) {
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
                                    dropdownColor: Color.fromRGBO(
                                        69, 56, 98, 0.6),
                                    decoration: InputDecoration(
                                      fillColor: Color(0xFF3d3876),
                                      filled: true,
                                      labelStyle: TextStyle(color: Colors.white),
                                      labelText: 'Territory ID',
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(36),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(36),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(36),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    icon: Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedTerritory = value;
                                      });
                                    },
                                    validator: (value) =>
                                        value == null
                                            ? 'Please select a territory'
                                            : null,
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) {
                                          setState(() {
                                            _rememberMe = value ?? false;
                                          });
                                        },
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                        activeColor:
                                            Colors.deepPurpleAccent,
                                      ),
                                      Text(
                                        'Remember Me',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 50),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed:
                                            _isLoading ? null : _signIn,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFFa95dee),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(30),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                        child: _isLoading
                                            ? SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  color:
                                                      Colors.deepPurpleAccent,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Text(
                                                'Log In',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  // SIGNUP BUTTON
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => SignupPage(),
                                        ),
                                      );
                                    },
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
                                            text:
                                                "Don't have an account? ",
                                          ),
                                          TextSpan(
                                            text: "Sign up",
                                            style: TextStyle(
                                              color: Color(0xFFf7ad01),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    Center(
                      child: Text(
                        'by',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF000000),
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.black),
                          children: <TextSpan>[
                            TextSpan(
                              text: 'RAGING',
                              style: TextStyle(
                                fontSize: 24,
                                color: Color(0xFFf7ad01),
                              ),
                            ),
                            TextSpan(
                              text: 'RIVER',
                              style: TextStyle(
                                fontSize: 24,
                                color: Color(0xFF70309e),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}