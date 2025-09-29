import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'dart:io';
import '../constants/app_constants.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import '../menu/profile_editor_page.dart';
import '../menu/profile_view_page.dart';
import 'login_page.dart';

// final SignatureController _controller = SignatureController(
//     penStrokeWidth: 5,
//     penColor: Colors.black,
//     exportBackgroundColor: Colors.white,
// );

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Uint8List? signature;
  bool _hasSubmittedSignature = false;
  Position? _currentPosition;
  MapController? _mapController;

  // User data
  String userName = '';
  String userEmail = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Show signature dialog after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openSignatureDialog();
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      // Get active user from Firestore
      final QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('isActive', isEqualTo: true)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userDoc = userQuery.docs.first;
        final userData = userDoc.data() as Map<String, dynamic>;

        setState(() {
          userName = userData['name'] ?? 'User';
          userEmail = userData['email'] ?? 'No email';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      // Get the user document by email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        await userQuery.docs.first.reference.update({
          'isActive': false,
          'lastLogout': FieldValue.serverTimestamp(),
        });
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out. Please try again.')),
      );
    }
  }

  void _handleDrawerItemTap(String title, String route) {
    Navigator.pop(context); // Close drawer
    if (route == '/profile') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileViewPage(
            userName: userName,
            userEmail: userEmail,
          ),
        ),
      );
      return;
    }
    if (route == '/home') {
      // Already on home page, just close drawer
      return;
    }
    Navigator.pushNamed(context, route);
  }

  Future<bool> _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
    }
    return status.isGranted;
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      print('Checking location permission...');
      bool hasPermission = await _requestLocationPermission();
      if (!hasPermission) {
        print('Location permission denied');
        return null;
      }
      print('Location permission granted');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }
      print('Location services are enabled');

      print('Getting current position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('Location obtained: ${position.latitude}, ${position.longitude}');
      print('Accuracy: ${position.accuracy}m');
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Future<void> _openSignatureDialog() async {
    final SignatureController dialogController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    // Get current location when dialog opens
    Position? position = await _getCurrentLocation();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User cannot dismiss by tapping outside
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return WillPopScope(
              onWillPop: () async => false, // Prevent back button from closing dialog
              child: Dialog(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.95,
                  height: MediaQuery.of(context).size.height * 0.85,
                  padding: EdgeInsets.all(16),
                  child: SingleChildScrollView( // Add this wrapper
                    child: Column(
                      children: [
                        Text(
                          'Digital Signature Required',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please provide your signature and confirm your location.',
                          style: TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        
                        // Location Map Section
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: position != null
                                ? FlutterMap(
                                    mapController: _mapController ?? MapController(),
                                    options: MapOptions(
                                      center: LatLng(position!.latitude, position!.longitude),
                                      zoom: 16.0,
                                      interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName: 'com.example.idoxsapp',
                                        maxZoom: 19,
                                      ),
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            width: 40.0,
                                            height: 40.0,
                                            point: LatLng(position!.latitude, position!.longitude),
                                            child: Container(
                                              child: Icon(
                                                Icons.location_pin,
                                                color: Colors.red,
                                                size: 40,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      RichAttributionWidget(
                                        attributions: [
                                          TextSourceAttribution(
                                            'OpenStreetMap contributors',
                                            onTap: () {},
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : Container(
                                    color: Colors.grey.shade200,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 16),
                                          Text('Getting your location...'),
                                          SizedBox(height: 8),
                                          TextButton(
                                            onPressed: () async {
                                              Position? newPosition = await _getCurrentLocation();
                                              setDialogState(() {
                                                position = newPosition;
                                              });
                                            },
                                            child: Text('Retry'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        
                        SizedBox(height: 12),
                        
                        // Location Info
                        if (position != null)
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: FutureBuilder<String>(
                              future: _getAddressFromCoordinates(position!),
                              builder: (context, snapshot) {
                                return Row(
                                  children: [
                                    Icon(Icons.location_on, color: Colors.blue.shade700, size: 16),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        snapshot.data ?? 'Getting address...',
                                        style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        
                        SizedBox(height: 12),
                        
                        // Signature Section
                        Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Signature(
                            controller: dialogController,
                            width: double.infinity,
                            height: 150,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        
                        SizedBox(height: 12),
                        
                        // Signature Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              onPressed: () => dialogController.clear(),
                              icon: Icon(Icons.clear, size: 16),
                              label: Text('Clear', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => dialogController.undo(),
                              icon: Icon(Icons.undo, size: 16),
                              label: Text('Undo', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              // Check if signature is empty
                              if (dialogController.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Please provide your signature before submitting.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              try {
                                final points = dialogController.points;
                                final timestamp = DateTime.now().toIso8601String();
                                final position = await _getCurrentLocation();

                                // Save vector points to Firestore
                                await _saveSignatureToFirestore(points, timestamp, position);

                                setState(() {
                                  _hasSubmittedSignature = true;
                                  _currentPosition = position;
                                });

                                String locationInfo = position != null 
                                    ? '\nLocation: ${await _getAddressFromCoordinates(position)}'
                                    : '\nLocation: Not available';

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Signature saved successfully!\nTimestamp: $timestamp$locationInfo'),
                                    backgroundColor: Colors.green,
                                  ),
                                );

                                // Close dialog
                                Navigator.of(context).pop();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error saving signature. Please try again.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Submit Signature',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveSignatureToDevice(Uint8List signatureBytes, String timestamp) async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory signaturesDir = Directory('${appDocDir.path}/signatures');
      if (!await signaturesDir.exists()) {
        await signaturesDir.create(recursive: true);
      }
      
      final String fileName = 'signature_${userEmail}_$timestamp.png';
      final File file = File('${signaturesDir.path}/$fileName');
      
      await file.writeAsBytes(signatureBytes);
      print('Signature saved to: ${file.path}');
    } catch (e) {
      print('Error saving signature to device: $e');
      throw e;
    }
  }

  Future<String> _getAddressFromCoordinates(Position position) async {
    try {
      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        geocoding.Placemark place = placemarks[0];
        return '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}';
      }
      return 'Address not found';
    } catch (e) {
      print('Error getting address: $e');
      return 'Error getting address';
    }
  }

  Future<void> _saveSignatureToFirestore(List<Point> points, String timestamp, Position? position) async {
    try {
      if (userEmail != null) {
        String address = position != null ? 
            await _getAddressFromCoordinates(position) : 'Location not available';

        // Convert signature points to storable format
        final List<Map<String, dynamic>> signaturePoints = points.map((point) => {
          'x': point.x,
          'y': point.y,
          'pressure': point.pressure,
        }).toList();

        Map<String, dynamic> signatureData = {
          'userEmail': userEmail,
          'userName': userName,
          'timestamp': timestamp,
          'createdAt': FieldValue.serverTimestamp(),
          'signaturePoints': signaturePoints,
          'address': address,
        };

        if (position != null) {
          signatureData['location'] = {
            'address': address,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'altitude': position.altitude,
            'heading': position.heading,
            'speed': position.speed,
            'speedAccuracy': position.speedAccuracy,
            'timestamp': DateTime.now().toIso8601String(),
          };
          signatureData['hasLocation'] = true;
        }

        String docId = '${userEmail}_$timestamp';
        await FirebaseFirestore.instance
            .collection('signatures')
            .doc(docId)
            .set(signatureData);

        print('✓ Vector signature saved successfully');
      }
    } catch (e) {
      print('✗ Error saving signature: $e');
      throw e;
    }
  }

  void _showUserInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('User Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(Icons.person, color: Colors.blue.shade700),
              title: Text('Username'),
              subtitle: Text(userName),
            ),
            ListTile(
              leading: Icon(Icons.email, color: Colors.blue.shade700),
              title: Text('Email'),
              subtitle: Text(userEmail),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleDrawerItemTap('Profile', '/profile');
            },
            child: Text('Edit Profile'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IdoxsApp'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      // Modern Drawer
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: Column(
          children: [
            // Modern Drawer Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(AppSizes.paddingL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, // Add this
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(35),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: InkWell( // Add this wrapper
                              onTap: () => _handleDrawerItemTap('Profile', '/profile'),
                              borderRadius: BorderRadius.circular(35),
                              child: Center(
                                child: _isLoading
                                    ? CircularProgressIndicator(color: Colors.white)
                                    : Text(
                                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                        style: AppTextStyles.heading2.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          SizedBox(width: AppSizes.paddingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isLoading ? 'Loading...' : userName,
                                  style: AppTextStyles.heading3.copyWith(
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _isLoading ? 'Loading...' : userEmail,
                                  style: AppTextStyles.body2.copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Menu Items
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: AppSizes.paddingS),
                itemCount: MenuItems.drawerItems.length,
                itemBuilder: (context, index) {
                  final item = MenuItems.drawerItems[index];
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingM,
                    ),
                    leading: Container(
                      width: 40,  // Original size
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item['icon'],
                        color: AppColors.primary,
                        size: AppSizes.iconM,  // Original size
                      ),
                    ),
                    title: Text(
                      item['title'],
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textLight,
                    ),
                    onTap: () => _handleDrawerItemTap(item['title'], item['route']),
                  );
                },
              ),
            ),
            
            // Sign Out Section
            Container(
              padding: EdgeInsets.all(AppSizes.paddingM),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.textLight.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,  // Original size
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.logout,
                    color: AppColors.error,
                    size: AppSizes.iconM,  // Original size
                  ),
                ),
                title: Text(
                  'Sign Out',
                  style: AppTextStyles.body1.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _signOut();
                },
              ),
            ),
          ],
        ),
      ),

      
      body: _hasSubmittedSignature ? Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView( // Add this wrapper
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.blue.shade700,
                                child: _isLoading
                                    ? CircularProgressIndicator(color: Colors.white)
                                    : Text(
                                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _isLoading ? 'Loading...' : userName,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Divider(),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.email, color: Colors.grey.shade600),
                              SizedBox(width: 8),
                              Text(
                                _isLoading ? 'Loading...' : userEmail,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Dashboard Area

                  SizedBox(height: 32),
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  SizedBox(height: 16), // Add this
                  SizedBox( // Replace Expanded with SizedBox
                    height: MediaQuery.of(context).size.height * 0.5, // Adjust this value as needed
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        // PROFILE
                        _buildDashboardCard(
                          icon: Icons.person,
                          title: 'Profile',
                          subtitle: 'Manage your account',
                          color: Colors.purple,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Profile feature coming soon!')),
                            );
                          },
                        ),
                        // SETTINGS
                        _buildDashboardCard(
                          icon: Icons.settings,
                          title: 'Settings',
                          subtitle: 'App preferences',
                          color: Colors.orange,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Settings feature coming soon!')),
                            );
                          },
                        ),
                        // NOTIFICATIONS
                        _buildDashboardCard(
                          icon: Icons.notifications,
                          title: 'Notifications',
                          subtitle: 'Manage alerts',
                          color: Colors.red,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Notifications feature coming soon!')),
                            );
                          },
                        ),
                        // HELP
                        _buildDashboardCard(
                          icon: Icons.help,
                          title: 'Help',
                          subtitle: 'Get support',
                          color: Colors.green,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Help feature coming soon!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ) : SingleChildScrollView( // Replace Center with SingleChildScrollView
        child: Container(
          height: MediaQuery.of(context).size.height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.blue.shade700,
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Text(
                  'Please complete your signature to continue...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// DASHBOARD CARD BUILDER

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Add this
            children: [
              Container(
                padding: EdgeInsets.all(8), // Reduced from 12
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 28, // Reduced from 32
                  color: color,
                ),
              ),
              SizedBox(height: 8), // Reduced from 12
              Text(
                title,
                style: TextStyle(
                  fontSize: 14, // Reduced from 16
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2), // Reduced from 4
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11, // Reduced from 12
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}