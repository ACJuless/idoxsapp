import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_editor_page.dart';

// Palette
const Color kDeepPurple  = Color(0xFF4a2371);
const Color kMidPurple   = Color(0xFF5958b2);
const Color kSkyBlue     = Color(0xFF67c6ed);

class ProfileViewPage extends StatefulWidget {
  final String userName;
  final String userEmail;

  const ProfileViewPage({
    Key? key,
    required this.userName,
    required this.userEmail,
  }) : super(key: key);

  @override
  _ProfileViewPageState createState() => _ProfileViewPageState();
}

class _ProfileViewPageState extends State<ProfileViewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _userName;
  String? _userEmail;
  String? _photoUrl;
  String? _clientType;
  String? _password;
  bool _isActive = false;
  bool _isLoading = true;
  String? _errorMessage;
  bool _passwordVisible = false;

  late final String _emailKey;

  @override
  void initState() {
    super.initState();
    _emailKey = widget.userEmail.replaceAll('.', ',');
    _loadUserData();
  }

  DocumentReference<Map<String, dynamic>> _profileDocRef() {
    return _firestore
        .collection('flowDB')
        .doc('users')
        .collection(_emailKey)
        .doc('_emailKey');
  }

  Future<void> _loadUserData() async {
    try {
      final docRef = _profileDocRef();
      final docSnapshot = await docRef.get();
      if (!mounted) return;

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        setState(() {
          _userName  = data['name']  ?? _extractUserName(widget.userName, widget.userEmail);
          _userEmail = data['email'] ?? widget.userEmail;
          _isActive  = data['isActive'] ?? false;
          _photoUrl  = data['photoUrl'];
        });
      } else {
        final String initialName = _extractUserName(widget.userName, widget.userEmail);
        await docRef.set({
          'name':      initialName,
          'email':     widget.userEmail,
          'isActive':  true,
          'photoUrl':  null,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        setState(() {
          _userName  = initialName;
          _userEmail = widget.userEmail;
          _isActive  = true;
          _photoUrl  = null;
        });
      }

      final usersQuery = await _firestore
          .collectionGroup('Users')
          .where('email', isEqualTo: widget.userEmail)
          .limit(1)
          .get();

      if (!mounted) return;

      if (usersQuery.docs.isNotEmpty) {
        final userData = usersQuery.docs.first.data();
        setState(() {
          _clientType = userData['clientType'];
          _password   = userData['password'];
        });
      }

      setState(() {
        _isLoading    = false;
        _errorMessage = null;
      });

    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading    = false;
        _errorMessage = e.message ?? e.code;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading    = false;
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

  String _extractUserName(String widgetUserName, String widgetUserEmail) {
    if (widgetUserName.isNotEmpty) return widgetUserName;
    if (widgetUserEmail.contains('@')) return widgetUserEmail.split('@')[0];
    return 'Unknown User';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Gradient AppBar using all three palette colors
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kDeepPurple, kMidPurple, kSkyBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              try {
                final userDoc = await _profileDocRef().get();
                if (!mounted) return;

                if (userDoc.exists) {
                  final userData = userDoc.data() ?? {};
                  final String docId = userDoc.id;

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileEditorPage(
                        docId: docId,
                        userData: userData,
                        clientType: _clientType,
                      ),
                    ),
                  );

                  await _loadUserData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User profile not found')),
                  );
                }
              } on FirebaseException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to open editor: ${e.message ?? e.code}')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to open editor: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kMidPurple))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _errorMessage!.contains('permission-denied')
                          ? 'You do not have permission to view this profile.\nPlease check your Firestore security rules.'
                          : _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kDeepPurple, fontSize: 14),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header banner
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [kDeepPurple, kMidPurple, kSkyBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.only(top: 28, bottom: 36),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 48,
                                  backgroundColor: kSkyBlue.withOpacity(0.3),
                                  backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty)
                                      ? NetworkImage(_photoUrl!)
                                      : null,
                                  child: (_photoUrl == null || _photoUrl!.isEmpty)
                                      ? Text(
                                          (_userName != null && _userName!.isNotEmpty)
                                              ? _userName![0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                                if (_isActive)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check,
                                          color: Colors.white, size: 14),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _userName ?? 'Unknown User',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userEmail ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Info cards
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                        child: Column(
                          children: [
                            _buildInfoCard(
                              icon: Icons.person,
                              title: 'Username',
                              value: _userName ?? 'Unknown User',
                            ),
                            _buildInfoCard(
                              icon: Icons.email,
                              title: 'Email',
                              value: _userEmail ?? '—',
                            ),
                            _buildInfoCard(
                              icon: Icons.badge,
                              title: 'Client Type',
                              value: _clientType != null
                                  ? _clientType![0].toUpperCase() + _clientType!.substring(1)
                                  : '—',
                            ),
                            // _buildPasswordCard(),    // uncomment to show password field
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: kMidPurple),
        title: Text(title,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ),
    );
  }

  // uncomment to show password field
  // Widget _buildPasswordCard() {
  //   final String display = (_password != null && _password!.isNotEmpty)
  //       ? (_passwordVisible ? _password! : '•' * _password!.length)
  //       : '—';

  //   return Card(
  //     margin: const EdgeInsets.symmetric(vertical: 4),
  //     child: ListTile(
  //       leading: const Icon(Icons.lock, color: kMidPurple),
  //       title: const Text('Password',
  //           style: TextStyle(fontSize: 12, color: Colors.grey)),
  //       subtitle: Text(
  //         display,
  //         style: const TextStyle(
  //             fontSize: 15,
  //             fontWeight: FontWeight.w500,
  //             letterSpacing: 2),
  //       ),
  //       trailing: (_password != null && _password!.isNotEmpty)
  //           ? IconButton(
  //               icon: Icon(
  //                 _passwordVisible ? Icons.visibility_off : Icons.visibility,
  //                 color: kSkyBlue,
  //               ),
  //               onPressed: () =>
  //                   setState(() => _passwordVisible = !_passwordVisible),
  //             )
  //           : null,
  //     ),
  //   );
  // }
}