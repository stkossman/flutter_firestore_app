import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/note.dart';

class FirestoreService {
  FirestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

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

  Future<void> createNote(String title, String content) async {
    final user = _requireUser();
    await _notesCollection(user).add({
      'title': title.trim(),
      'content': content.trim(),
      'userId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  Future<void> updateNote(String noteId, String title, String content) async {
    final user = _requireUser();
    await _notesCollection(user).doc(noteId).update({
      'title': title.trim(),
      'content': content.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNote(String noteId) async {
    final user = _requireUser();
    await _notesCollection(user).doc(noteId).delete();
  }
}
