import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/note.dart';
import 'storage_service.dart';

class FirestoreService {
  FirestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    StorageService? storageService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storageService = storageService ?? StorageService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final StorageService _storageService;

  CollectionReference<Map<String, dynamic>> _notesCollection(User user) {
    return _firestore.collection('users').doc(user.uid).collection('notes');
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User is not authenticated.');
    }
    return user;
  }

  Future<String> createNote(
    String title,
    String content, {
    String? imageUrl,
    String? storagePath,
  }) async {
    final user = _requireUser();
    final doc = await _notesCollection(user).add({
      'title': title.trim(),
      'content': content.trim(),
      'userId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (storagePath != null) 'storagePath': storagePath,
    });
    return doc.id;
  }

  Stream<List<Note>> getNotes() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<List<Note>>.value(const []);
    }

    return _notesCollection(user)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Note.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> updateNote(
    String noteId,
    String title,
    String content, {
    String? imageUrl,
    String? storagePath,
    bool removeImage = false,
  }) async {
    final user = _requireUser();
    final data = <String, dynamic>{
      'title': title.trim(),
      'content': content.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (removeImage) {
      data['imageUrl'] = FieldValue.delete();
      data['storagePath'] = FieldValue.delete();
    } else {
      if (imageUrl != null) {
        data['imageUrl'] = imageUrl;
      }
      if (storagePath != null) {
        data['storagePath'] = storagePath;
      }
    }

    await _notesCollection(user).doc(noteId).update(data);
  }

  Future<void> updateNoteImage(
    String noteId,
    String imageUrl, {
    String? storagePath,
  }) async {
    final user = _requireUser();
    await _notesCollection(user).doc(noteId).update({
      'imageUrl': imageUrl,
      if (storagePath != null) 'storagePath': storagePath,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNote(Note note) async {
    final user = _requireUser();
    try {
      final storagePath = note.storagePath;
      final imageUrl = note.imageUrl;
      if (storagePath != null && storagePath.isNotEmpty) {
        await _storageService.deleteNoteImageByPath(storagePath);
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        await _storageService.deleteNoteImage(imageUrl);
      }
    } catch (error) {
      debugPrint('Failed to delete note image from Storage: $error');
    }

    await _notesCollection(user).doc(note.id).delete();
  }
}
