import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hobbee_app/services/auth_service.dart';
import 'package:hobbee_app/services/appwrite_service.dart';
import 'package:hobbee_app/pages/splash_page.dart';
import 'package:hobbee_app/pages/login_page.dart';
import 'package:hobbee_app/pages/home_page.dart';
import 'package:hobbee_app/pages/onboarding_hobbies_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Error initializing Firebase: $e');
  }
  
  try {
    await AppwriteService().initialize();
    print('Appwrite initialized successfully');
  } catch (e) {
    print('Error initializing Appwrite: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => AppwriteService()),
      ],
      child: MaterialApp(
        title: 'Hobbee',
        theme: ThemeData(
          primarySwatch: Colors.orange,
          useMaterial3: true,
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show splash screen while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashPage();
        }
        
        // If there's an error, show error screen
        if (snapshot.hasError) {
          print('Auth error: ${snapshot.error}');
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthWrapper()),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Get the user
        final user = snapshot.data;
        
        // If no user, show login page
        if (user == null) {
          print('No user found, showing login page');
          return const LoginPage();
        }
        
        // User is logged in, check onboarding status
        print('User found: ${user.email}, checking onboarding...');
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashPage();
            }
            
            // Check if user document exists and has hobbies
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData = userSnapshot.data!.data() as Map<String, dynamic>;
              final hobbies = userData['hobbies'] as List? ?? [];
              
              print('User document exists, hobbies: $hobbies');
              
              if (hobbies.isEmpty) {
                print('No hobbies, going to onboarding');
                return const OnboardingHobbiesPage();
              }
              
              print('Has hobbies, going to home page');
              return const HomePage();
            }
            
            // User document doesn't exist, create it
            print('User document not found, creating...');
            final role = _getRoleFromEmail(user.email);
            
            FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'username': user.email?.split('@').first ?? 'User',
              'email': user.email,
              'role': role,
              'hobbies': [],
              'profileImage': null,
              'createdAt': FieldValue.serverTimestamp(),
              'lastUsernameChange': null,
            }).then((_) {
              print('User document created, going to onboarding');
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const OnboardingHobbiesPage()),
                );
              }
            });
            
            return const SplashPage();
          },
        );
      },
    );
  }
  
  String _getRoleFromEmail(String? email) {
    if (email == null) return 'user';
    if (email == 'admin@example.com') return 'admin';
    if (email == 'super@example.com') return 'superadmin';
    return 'user';
  }
}