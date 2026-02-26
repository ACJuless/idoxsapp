import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
// Import your theme/constants files as needed
// import 'constants/app_constants.dart';
// import 'menu/menu_items.dart';
// import 'profile/profile_view_page.dart'; // For profile tap

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String userName = '';
  String userEmail = '';
  String emailKey = '';
  bool _hasSubmittedSignature = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? '';
      userName = prefs.getString('userName') ?? '';
      emailKey = userEmail.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
      _hasSubmittedSignature = prefs.getBool('hasSubmittedSignature') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _signOut() async {
    // Your sign out logic here
  }

  void _handleDrawerItemTap(String title, String route) {
    Navigator.pop(context); // Close drawer
    // Your drawer item routing logic
  }

  Future<void> _refreshDashboard() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final String todayStr = DateFormat('EEEE, MMM d, yyyy').format(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(''),
        centerTitle: false,
        backgroundColor: Color(0xFF5958b2),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 5, bottom: 5),
            child: Center(
              child: Text(
                'Flow',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2b2b2b),
                  letterSpacing: 2,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white, // Use your AppColors.surface if any
        child: Column(
          children: [
            // Modern Drawer Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.7,
                  colors: [
                    Color.fromRGBO(20, 20, 40, 0.95),
                    Color.fromRGBO(60, 30, 100, 0.95),
                    Color.fromRGBO(100, 50, 150, 0.95),
                    Color.fromRGBO(140, 80, 200, 0.95),
                    Color.fromRGBO(200, 150, 255, 0.95),
                    Color(0xFF5958b2),
                    Color(0xFF5958b2),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Color(0xFFfda756),
                              borderRadius: BorderRadius.circular(35),
                              border: Border.all(color: Color(0xFFfda756), width: 2),
                            ),
                            child: InkWell(
                              onTap: () {}, // Add your profile tap here
                              borderRadius: BorderRadius.circular(35),
                              child: Center(
                                child: _isLoading
                                    ? CircularProgressIndicator(color: Colors.white)
                                    : Text(
                                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                        style: TextStyle(
                                          fontSize: 28,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isLoading ? 'Loading...' : userName,
                                  style: TextStyle(fontSize: 22, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _isLoading ? 'Loading...' : userEmail,
                                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
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
              child: ListView(
                children: [
                  // Place your drawer ListTile() items here or use MenuItems.drawerItems
                  // ...
                ],
              ),
            ),
            // Sign Out Section
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.logout,
                    color: Colors.red,
                  ),
                ),
                title: Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: _signOut,
              ),
            ),
          ],
        ),
      ),
      body: _hasSubmittedSignature
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFdedef0),
                    Color(0xFFdedef0),
                  ],
                ),
              ),
              child: SafeArea(
                child: RefreshIndicator(
                  onRefresh: _refreshDashboard,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User Info Card
                          Container(
                            decoration: BoxDecoration(
                              color: Color(0xFF5958b2),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(10.0),
                                bottomRight: Radius.circular(10.0),
                              ),
                            ),
                            child: Card(
                              color: Colors.transparent,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    InkWell(
                                      onTap: () {},
                                      borderRadius: BorderRadius.circular(30),
                                      child: CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.orange,
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
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _isLoading ? 'Loading...' : userName,
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            _isLoading ? 'Loading...' : userEmail,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.white70,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 62),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 32),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Today',
                                style: TextStyle(fontFamily: 'Lato', fontSize: 14, color: Colors.black),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                todayStr,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          // You may add any extra dashboard content below here—excluding the removed sections
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              child: Container(
                height: MediaQuery.of(context).size.height,
                color: Colors.blue.shade50,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.blue.shade700),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Text(
                        'Please complete your signature to continue...',
                        style: TextStyle(fontSize: 16, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
