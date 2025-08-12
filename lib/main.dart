import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';
import 'onboardingscreen.dart';
import 'login.dart';
import 'signup.dart';
import 'home_page.dart';
import 'edit_profile.dart';
import 'account.dart';
import 'package:easy_localization/easy_localization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: [Locale('en'), Locale('hi')],
      path: 'assets/translations',
      fallbackLocale: Locale('en'),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dotly',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        primaryColor: const Color(0xFF8D1CDF), // Primary 100
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8D1CDF),
          primary: const Color(0xFF8D1CDF),
          secondary: const Color(0xFFEEE2F4), // Accent Colour
          tertiary: const Color(0xFFFFF6E7), // Accent Colour
          surface: const Color(0xFFE4F5DB), // Accent Color
          background: const Color(0xFFFCE7F3), // Accent Color
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Poppins', // Set Poppins as the global font
        textTheme: TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Poppins'),
          bodyMedium: TextStyle(fontFamily: 'Poppins'),
          bodySmall: TextStyle(fontFamily: 'Poppins'),
          displayLarge: TextStyle(fontFamily: 'Poppins'),
          displayMedium: TextStyle(fontFamily: 'Poppins'),
          displaySmall: TextStyle(fontFamily: 'Poppins'),
          headlineLarge: TextStyle(fontFamily: 'Poppins'),
          headlineMedium: TextStyle(fontFamily: 'Poppins'),
          headlineSmall: TextStyle(fontFamily: 'Poppins'),
          titleLarge: TextStyle(fontFamily: 'Poppins'),
          titleMedium: TextStyle(fontFamily: 'Poppins'),
          titleSmall: TextStyle(fontFamily: 'Poppins'),
        ),
      ),
      home: SplashScreen(),
      routes: {
        '/onboarding': (context) => PlantApp(),
        '/home': (context) => HomePage(),
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/account': (context) => AccountPage(),
        '/editProfile': (context) => EditProfileScreen(),
      },
    );
  }
}

class AuthFlow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SplashScreen();
        }
        if (snapshot.hasData) {
          return HomePage();
        }
        return PlantApp();
      },
    );
  }
}
