import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadLogo(String examId, Uint8List bytes, String extension) async {
    final ref = _storage.ref('logos/$examId/logo.$extension');
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/$extension'),
    );
    return await ref.getDownloadURL();
  }
}
