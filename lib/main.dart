// RUN THESE IN TERMINAL Before mobile run :
//      - flutter clean
//      - flutter pub get
//      - cd android
//      - ./gradlew clean
//      - cd ..
//      - flutter run

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // for Firestore settings (offline cache)
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';

import 'constants/app_constants.dart';
import 'screens/splash_screen.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/home_page.dart';
import 'menu/itinerary_menu/itinerary_page.dart';
import 'menu/doctor_menu/doctor_page.dart';
import 'menu/reload_page.dart';
import 'pages/dashboard_page.dart';
import 'menu/outbox_page.dart';
import 'menu/map_menu/map_page.dart';
import 'menu/marketing_page.dart';
import 'menu/e_forms_menu/forms_page.dart';
import 'menu/doctor_menu/tml_view.dart';
// If you generated firebase_options.dart via FlutterFire CLI, uncomment this:
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Explicitly configure Firestore offline cache (mobile).
  // On Android/iOS persistence is on by default, but this lets you control cache size. [web:97][web:84]
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iDoXs',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: AppColors.primary.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.paddingL,
              vertical: AppSizes.paddingM,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
          ),
          color: AppColors.surface,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.cardBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            borderSide: BorderSide(color: AppColors.textLight.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),

      // First screen: SplashScreen; from there, you can navigate to AuthWrapper
      // (for example, by pushing '/auth' after your init logic in SplashScreen).
      home: SplashScreen(),

      routes: {
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignupPage(),
        '/dashboard': (context) => DashboardPage(),
        '/home': (context) => HomePage(),
        '/itinerary': (context) => ItineraryPage(),
        '/doctor': (context) => DoctorPage(),
        '/reload': (context) => ReloadPage(),
        '/outbox': (context) => OutboxPage(),
        '/map': (context) => MapPage(),
        '/marketing': (context) => MarketingPage(),
        '/forms': (context) => FormsPage(),
        '/tml': (context) => TmlViewPage(), // assuming this exists
        // Optional: route that uses the AuthWrapper below
        '/auth': (context) => AuthWrapper(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Listens to FirebaseAuth auth state changes. [web:95]
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a loading screen while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                  SizedBox(height: AppSizes.paddingL),
                  Text('Loading...', style: AppTextStyles.body1),
                ],
              ),
            ),
          );
        }

        // If the user is logged in, go to HomePage; otherwise, LoginPage
        if (snapshot.hasData) {
          return HomePage();
        } else {
          return LoginPage();
        }
      },
    );
  }
}
