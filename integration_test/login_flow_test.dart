// integration_test/login_flow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// *** FIX 1: Correct import path ***
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Import Storage

// Import your app's main entry point AND the emulator config function
import 'package:aquasense/main.dart' as app;
import 'package:aquasense/firebase_options.dart'; // Import options
// Import screens/widgets needed
import 'package:aquasense/screens/auth/login_screen.dart';
import 'package:aquasense/screens/dashboard/citizen_dashboard.dart'; // Or RoleRouter

// Define configureFirebaseEmulators function *within* the test file
// or ensure it's properly exported and imported if defined elsewhere accessible to tests.
// *** ADDED: Definition directly or import if refactored ***
// Example definition (adjust host/ports as needed, matching main.dart):
const String emulatorHost = '192.168.1.4'; // Or 'localhost' if testing on emulator
Future<void> configureFirebaseEmulatorsForTest() async {
  print('Configuring Firebase Emulators for Test with host: $emulatorHost');
  try {
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    print('Firestore emulator configured for test.');
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    print('Auth emulator configured for test.');
    await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
    print('Storage emulator configured for test.');
  } catch (e) {
    print('Error configuring emulators for test: $e');
  }
}


void main() {
  // *** FIX 2: Use the correctly imported class ***
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // --- Test Setup Variables ---
  late FirebaseAuth auth;
  late FirebaseFirestore firestore;

  // Define test user credentials
  final testEmail = 'test-${DateTime.now().millisecondsSinceEpoch}@test.com';
  final testPassword = 'password123!';
  final testName = 'Integration Tester';
  final testWard = 'TestWardA'; // Make sure this ward exists or adjust setup
  final testPhone = '+9999999999';

  setUpAll(() async {
    // *** Initialize Firebase Core within the test setup ***
    WidgetsFlutterBinding.ensureInitialized(); // Ensure binding
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase Initialized in setUpAll.");

    // *** Configure Emulators AFTER Firebase.initializeApp ***
    // *** FIX 3: Call the correctly scoped function ***
    await configureFirebaseEmulatorsForTest(); // Call the function defined/imported for test
    print("Firebase Emulators Configured in setUpAll.");

    // Now get instances
    auth = FirebaseAuth.instance;
    firestore = FirebaseFirestore.instance;
    print("Auth and Firestore instances obtained.");

    // --- Pre-populate Emulator Data ---
    try {
      print("Attempting to create user: $testEmail");
      await auth.createUserWithEmailAndPassword(email: testEmail, password: testPassword);
      final user = auth.currentUser;
      if (user != null) {
        print("User created: ${user.uid}. Adding Firestore data...");
        // Add corresponding user data
        await firestore.collection('users').doc(user.uid).set({
          'name': testName,
          'email': testEmail,
          'role': 'citizen',
          'wardId': testWard,
          'phoneNumber': testPhone,
          'isPhoneVerified': true, // Assume verified for login test simplicity
          'createdAt': FieldValue.serverTimestamp(),
          'hasActiveConnection': false,
          'profileImageUrl': null,
        });
        print("Firestore data added. Signing out...");
        await auth.signOut();
      } else { print("Failed to get user after creation."); }
    } catch (e) { print("Error during test user setup: $e. Might already exist if emulators weren't cleared."); if (auth.currentUser != null) { await auth.signOut(); } } // Handle potential existing user
  });

  tearDown(() async {
    await auth.signOut();
    print("Signed out after test.");
  });

  testWidgets('Login Flow Test', (WidgetTester tester) async {
    // --- Start the App ---
    print("Starting app...");
    // Build the root widget. Firebase is already initialized.
    await tester.pumpWidget(const app.MyApp()); // Assuming MyApp is your root widget

    // --- Wait for Splash/Initial Load ---
    print("Waiting for initial load (Splash Screen)...");
    // Wait long enough for splash screen and navigation to LoginScreen
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // --- Login Screen Interactions ---
    print("Finding Login Screen elements...");
    expect(find.byType(LoginScreen), findsOneWidget, reason: "Should be on LoginScreen after splash");
    expect(find.text('Welcome Back'), findsOneWidget);

    // Use specific finders (consider adding Keys in your app code for robustness)
    final emailFieldFinder = find.widgetWithIcon(TextFormField, Icons.email_outlined);
    final passwordFieldFinder = find.widgetWithIcon(TextFormField, Icons.lock_outline);
    final loginButtonFinder = find.widgetWithText(ElevatedButton, 'Login');

    expect(emailFieldFinder, findsOneWidget, reason: "Email field not found");
    expect(passwordFieldFinder, findsOneWidget, reason: "Password field not found");
    expect(loginButtonFinder, findsOneWidget, reason: "Login button not found");

    print("Entering credentials...");
    await tester.enterText(emailFieldFinder, testEmail);
    await tester.enterText(passwordFieldFinder, testPassword);
    await tester.pumpAndSettle(); // Allow UI to update if needed

    print("Tapping login button...");
    await tester.tap(loginButtonFinder);

    // --- Wait for Login & Navigation ---
    print("Waiting for login and navigation...");
    // Give ample time for Firebase auth, Firestore read (RoleRouter), and navigation
    await tester.pumpAndSettle(const Duration(seconds: 8));

    // --- Verification ---
    print("Verifying navigation to dashboard...");
    expect(find.byType(LoginScreen), findsNothing, reason: "LoginScreen should no longer be visible");
    // Check for a widget unique to the citizen dashboard
    expect(find.byType(CitizenDashboard), findsOneWidget, reason: "CitizenDashboard not found after login");
    // Verify user name is displayed (adjust finder if needed)
    expect(find.textContaining(testName, findRichText: true), findsWidgets, reason: "Username '$testName' not found on dashboard");

    print("Login Flow Test finished successfully.");
  });

  // Add more testWidgets for other flows...
}