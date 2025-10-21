import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> _uploadFile(File file, String storagePath) async {
    try {
      final ref = _storage.ref(storagePath);
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (e) {
      String errorMessage = "Failed to upload file. Please try again.";
      switch (e.code) {
        case 'app-check-failed':
          errorMessage = "Upload failed: App Check verification failed.";
          break;
        case 'unauthorized':
          errorMessage = "Permission denied. You are not authorized to upload this file.";
          break;
        case 'object-not-found':
          errorMessage = "Upload failed because the file path is invalid.";
          break;
        case 'canceled':
          errorMessage = "Upload was cancelled.";
          break;
        default:
          errorMessage = e.message ?? errorMessage;
          break;
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('An unexpected error occurred during file upload.');
    }
  }

  Future<String> uploadComplaintImage(XFile imageFile, String userId) async {
    final fileExtension = p.extension(imageFile.path);
    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = '${safeUserId}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
    final storagePath = 'complaint_images/$fileName';

    return _uploadFile(File(imageFile.path), storagePath);
  }

  Future<String> uploadResidentialProof(File file, String userId) async {
    final fileExtension = p.extension(file.path);
    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = 'proof_${safeUserId}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
    final storagePath = 'residential_proofs/$fileName';

    return _uploadFile(file, storagePath);
  }

  Future<String> uploadConnectionImage(XFile imageFile, String userId) async {
    final fileExtension = p.extension(imageFile.path);
    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = 'conn_${safeUserId}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
    final storagePath = 'connection_images/supervisors/$fileName';

    return _uploadFile(File(imageFile.path), storagePath);
  }

  // ✅ NEW FUNCTION: To upload user profile pictures.
  Future<String> uploadProfilePicture(XFile imageFile, String userId) async {
    final fileExtension = p.extension(imageFile.path);
    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = 'pfp_${safeUserId}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
    final storagePath = 'profile_pictures/$fileName';

    return _uploadFile(File(imageFile.path), storagePath);
  }
}