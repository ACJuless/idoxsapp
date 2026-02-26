import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_editor_page.dart';

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
  bool _isActive = false;
  bool _isLoading = true;
  String? _errorMessage;

  // emailKey = paolotest@gmail,com (if you keep the replaceAll)
  late final String _emailKey;

  @override
  void initState() {
    super.initState();
    _emailKey = widget.userEmail.replaceAll('.', ',');
    _loadUserData();
  }

  /// Returns the DocumentReference for your structure:
  /// flowDB (collection) / users (doc) / <emailKey> (collection) / Paolo Jules (doc)
  DocumentReference<Map<String, dynamic>> _profileDocRef() {
    return _firestore
        .collection('flowDB')
        .doc('users')
        .collection(_emailKey)
        .doc('Paolo Jules');
  }

  Future<void> _loadUserData() async {
    try {
      final docRef = _profileDocRef();
      final docSnapshot = await docRef.get();

      if (!mounted) return;

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        setState(() {
          // Firestore fields: "name", "email", "isActive", "photoUrl"
          _userName = data?['name'] ??
              _extractUserName(widget.userName, widget.userEmail);
          _userEmail = data?['email'] ?? widget.userEmail;
          _isActive = data?['isActive'] ?? false;
          _photoUrl = data?['photoUrl'];
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        // If doc does not exist, create it with initial values.
        final String initialName =
            _extractUserName(widget.userName, widget.userEmail);

        await docRef.set({
          'name': initialName,
          'email': widget.userEmail,
          'isActive': true,
          'photoUrl': null,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        setState(() {
          _userName = initialName;
          _userEmail = widget.userEmail;
          _isActive = true;
          _photoUrl = null;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? e.code;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

  /// Returns widgetUserName if not empty; otherwise derives from userEmail (before "@")
  String _extractUserName(String widgetUserName, String widgetUserEmail) {
    if (widgetUserName.isNotEmpty) return widgetUserName;
    if (widgetUserEmail.contains('@')) {
      return widgetUserEmail.split('@')[0];
    }
    return 'Unknown User';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              try {
                final userDoc = await _profileDocRef().get();

                if (!mounted) return;

                if (userDoc.exists) {
                  final userData = userDoc.data() ?? {};
                  // docId here is "Paolo Jules" given your structure
                  final String docId = userDoc.id;

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileEditorPage(
                        docId: docId,
                        userData: userData,
                        // If ProfileEditorPage needs the path, you can pass emailKey too.
                        // emailKey: _emailKey,
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
                  SnackBar(
                    content: Text(
                      'Failed to open editor: ${e.message ?? e.code}',
                    ),
                  ),
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
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _errorMessage!.contains('permission-denied')
                          ? 'You do not have permission to view this profile.\nPlease check your Firestore security rules for:\nflowDB / users / <emailKey> / Paolo Jules'
                          : _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.blue.shade100,
                            backgroundImage: (_photoUrl != null &&
                                    _photoUrl!.isNotEmpty)
                                ? NetworkImage(_photoUrl!)
                                : null,
                            child: (_photoUrl == null ||
                                    _photoUrl!.isEmpty)
                                ? Text(
                                    (_userName != null &&
                                            _userName!.isNotEmpty)
                                        ? _userName![0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
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
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildInfoTile(
                                icon: Icons.person,
                                title: 'Username',
                                value: _userName ?? 'Unknown User',
                              ),
                              const Divider(height: 24),
                              _buildInfoTile(
                                icon: Icons.email,
                                title: 'Email',
                                value: _userEmail ?? '',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue.shade700),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
