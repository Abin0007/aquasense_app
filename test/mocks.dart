// test/mocks.dart

// Import the packages whose classes you want to mock
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mockito/annotations.dart';

// Add other Firebase classes as needed (e.g., FirebaseStorage, FirebaseFunctions)

// The @GenerateMocks annotation tells build_runner to generate mocks
// for the classes listed inside the square brackets.
@GenerateMocks([
  // Firebase Auth Mocks
  auth.FirebaseAuth,
  auth.UserCredential,
  auth.User,
  auth.UserInfo,
  auth.IdTokenResult,

  // Firestore Mocks
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  QuerySnapshot,
  QueryDocumentSnapshot,
  DocumentSnapshot,
  WriteBatch,
  // Add Query if you need to mock specific queries

  // Other Mocks
  GoogleSignIn,
  GoogleSignInAccount,
  GoogleSignInAuthentication,
  // Add FirebaseStorage, Reference, UploadTask, etc. if testing StorageService
  // Add FirebaseFunctions, HttpsCallable, HttpsCallableResult if testing MLService
])
void main() {} // The main function is required but can be empty
