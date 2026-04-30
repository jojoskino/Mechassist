import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_bootstrap.dart';

class RealtimeChatService {
  static String roomId(int requestId) => 'request_$requestId';

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(int requestId) {
    final room = roomId(requestId);
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(room)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  static Future<void> sendMessage({
    required int requestId,
    required int userId,
    required String userName,
    required String role,
    required String text,
  }) async {
    await FirebaseBootstrap.init();
    if (!FirebaseBootstrap.initialized || text.trim().isEmpty) {
      return;
    }

    final room = roomId(requestId);
    await FirebaseFirestore.instance.collection('chats').doc(room).set({
      'requestId': requestId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('chats').doc(room).collection('messages').add({
      'text': text.trim(),
      'userId': userId,
      'userName': userName,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
