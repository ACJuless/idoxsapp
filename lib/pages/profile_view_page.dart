import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_editor_page.dart';

// Palette
const Color kDeepPurple = Color(0xFF4a2371);
const Color kMidPurple  = Color(0xFF5958b2);
const Color kSkyBlue    = Color(0xFF67c6ed);

const LinearGradient _kGradient = LinearGradient(
  colors: [kDeepPurple, kMidPurple, kSkyBlue],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

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
  bool    _isActive  = false;
  bool    _isLoading = true;
  String? _errorMessage;
  bool _passwordVisible = false;

  DocumentReference<Map<String, dynamic>>? _userDocRef;

  Map<String, dynamic>? _daloyUserData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      final usersQuery = await _firestore
          .collectionGroup('Users')
          .where('email', isEqualTo: widget.userEmail.toLowerCase())
          .limit(1)
          .get();

      if (!mounted) return;

      if (usersQuery.docs.isNotEmpty) {
        final doc  = usersQuery.docs.first;
        final data = doc.data();

        setState(() {
          _userDocRef    = doc.reference;
          _daloyUserData = data;
          _userName   = data['name']       ?? _extractUserName();
          _userEmail  = data['email']      ?? widget.userEmail;
          _isActive   = data['isActive']   ?? false;
          _photoUrl   = data['photoUrl']   ??
                        data['profileImageUrl'] ??
                        data['profilePicture'];
          _clientType = data['clientType'];
        });
      } else {
        setState(() {
          _userName  = _extractUserName();
          _userEmail = widget.userEmail;
        });
      }

      setState(() => _isLoading = false);

    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading    = false;
        _errorMessage = e.message ?? e.code;
      });
      _toast('Failed to load profile: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading    = false;
        _errorMessage = e.toString();
      });
      _toast('Failed to load profile: $e');
    }
  }

  /// Returns widgetUserName if not empty; otherwise derives from userEmail (before "@")
  String _extractUserName() {
    if (widget.userName.isNotEmpty) return widget.userName;
    if (widget.userEmail.contains('@')) return widget.userEmail.split('@')[0];
    return 'Unknown User';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEditor() async {
    if (_userDocRef == null || _daloyUserData == null) {
      _toast('User profile not found. Cannot open editor.');
      return;
    }

    final String collectionPath = _userDocRef!.parent.path;
    final String docId          = _userDocRef!.id;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditorPage(
          docId:          docId,
          collectionPath: collectionPath, 
          userData:       _daloyUserData!,
          clientType:     _clientType,
        ),
      ),
    );

    await _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _kGradient),
        ),
        backgroundColor: Colors.transparent,
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _isLoading ? null : _openEditor,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kMidPurple))
          : _errorMessage != null
              ? _buildErrorView()
              : _buildProfileBody(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _errorMessage!.contains('permission-denied')
              ? 'You do not have permission to view this profile.\n'
                'Please check your Firestore security rules.'
              : _errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: kDeepPurple, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildProfileBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildAvatarHeader(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
                  value: _clientType != null && _clientType!.isNotEmpty
                      ? _clientType![0].toUpperCase() + _clientType!.substring(1)
                      : '—',
                ),

                _buildPasswordInfoCard(
                  value: _daloyUserData?['plainPassword'] ?? '—',
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: _kGradient),
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
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildPasswordInfoCard({required String value}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.lock, color: kMidPurple),
        title: const Text('Password',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(
          _passwordVisible ? value : '•' * value.length.clamp(6, 20),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        trailing: IconButton(
          icon: Icon(
            _passwordVisible ? Icons.visibility_off : Icons.visibility,
            color: kMidPurple,
            size: 20,
          ),
          onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
        ),
      ),
    );
  }
}