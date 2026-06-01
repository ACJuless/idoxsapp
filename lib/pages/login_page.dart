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
  bool _isAutoLoginChecked = false;

  final List<String> _territoryOptions = ["PH-L", "PH-V", "PH-M"];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRememberedLogin();
    });
  }

  Future<void> _checkRememberedLogin() async {
    if (_isAutoLoginChecked) return;
    _isAutoLoginChecked = true;

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!isLoggedIn) return;

    final userEmail = prefs.getString('userEmail');
    final userId = prefs.getString('userId');
    final territoryId = prefs.getString('territoryId');
    final userName = prefs.getString('userName') ?? '';
    final userClientType = prefs.getString('userClientType') ?? 'both';

    if (userEmail == null ||
        userEmail.isEmpty ||
        userId == null ||
        userId.isEmpty ||
        territoryId == null ||
        territoryId.isEmpty) {
      await prefs.setBool('isLoggedIn', false);
      return;
    }

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
      arguments: {
        'userEmail': userEmail,
        'userId': userId,
        'territoryId': territoryId,
        'userName': userName,
        'userClientType': userClientType,
      },
    );
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserInClientTree(
    String email,
  ) async {
    final lower = email.toLowerCase();

    if (lower.endsWith('@indofil.com')) {
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

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserDoc(
    String email,
  ) async {
    return await _findUserInClientTree(email);
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_selectedTerritory == null || _selectedTerritory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a territory')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim().toLowerCase();
      final hashedPassword = _hashPassword(_passwordController.text.trim());

      final userDocSnap = await _findUserDoc(email);

      if (userDocSnap == null || !userDocSnap.exists) {
        throw Exception('Invalid email, password, or territory');
      }

      final userData = userDocSnap.data() as Map<String, dynamic>? ?? {};

      final firestoreTerritory = (userData['territoryId'] ?? '').toString();
      if (firestoreTerritory != _selectedTerritory) {
        throw Exception('Invalid email, password, or territory');
      }

      final firestorePassword = (userData['password'] ?? '').toString();
      if (firestorePassword != hashedPassword) {
        throw Exception('Invalid password');
      }

      final clientType = (userData['clientType'] ?? 'both').toString();
      final userName = (userData['name'] ?? '').toString();

      await userDocSnap.reference.update({
        'isActive': true,
        'lastLogin': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('loginTimestamp', DateTime.now().toIso8601String());
      await prefs.setString('userEmail', email);
      await prefs.setString('userId', userDocSnap.id);
      await prefs.setString('territoryId', _selectedTerritory ?? '');
      await prefs.setString('userName', userName);
      await prefs.setString('userClientType', clientType);
      await prefs.setBool('rememberMe', _rememberMe);

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
        arguments: {
          'userEmail': email,
          'userId': userDocSnap.id,
          'territoryId': _selectedTerritory,
          'userName': userName,
          'userClientType': clientType,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                                    'Daloy',
                                    style: TextStyle(
                                      fontSize: 100,
                                      fontWeight: FontWeight.bold,
                                      color: Color.fromRGBO(248, 242, 254, 1),
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
                                        borderRadius: BorderRadius.circular(30),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(30),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(30),
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
                                            _obscurePassword = !_obscurePassword;
                                          });
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
                                    dropdownColor: Color.fromRGBO(69, 56, 98, 0.6),
                                    decoration: InputDecoration(
                                      fillColor: Color(0xFF3d3876),
                                      filled: true,
                                      labelStyle: TextStyle(color: Colors.white),
                                      labelText: 'Territory ID',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(36),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(36),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(36),
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
                                        value == null ? 'Please select a territory' : null,
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
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        activeColor: Colors.deepPurpleAccent,
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
                                    padding: EdgeInsets.symmetric(horizontal: 50),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _signIn,
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
                                            text: "Don't have an account? ",
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