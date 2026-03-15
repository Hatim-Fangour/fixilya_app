import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// ChatController
/// Manages chat rooms, message sending, and read receipts for the current user.
class ChatController extends GetxController {
  // ─── Services ────────────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── State ───────────────────────────────────────────────────────────────
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  // ─── Computed ────────────────────────────────────────────────────────────
  String? get _currentUid => _auth.currentUser?.uid;

  /// Stream of chat rooms for the currently authenticated user,
  /// ordered by last message timestamp descending.
  Stream<QuerySnapshot<Map<String, dynamic>>> getChatRooms() {
    final uid = _currentUid;
    if (uid == null) {
      // Return an empty stream if not authenticated
      return const Stream.empty();
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  /// Stream of messages for a specific chat room, ordered by creation time.
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Send a text message to a chat room.
  ///
  /// Creates the message document and updates the chat metadata atomically
  /// via a batched write.
  Future<void> sendMessage({
    required String chatId,
    required String otherUserId,
    required String text,
  }) async {
    final uid = _currentUid;
    if (uid == null) return;

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    try {
      final batch = _firestore.batch();

      // 1. Create message document
      final msgRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();
      batch.set(msgRef, {
        'senderId': uid,
        'text': trimmedText,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 2. Update chat metadata + increment other user's unread counter
      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.set(
        chatRef,
        {
          'lastMessage': trimmedText,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'participants': [uid, otherUserId],
          'unread_$otherUserId': FieldValue.increment(1),
          'unread_$uid': 0,
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e) {
      if (kDebugMode) debugPrint('ChatController: sendMessage error: $e');
      Get.snackbar(
        'Error',
        'Failed to send message. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  /// Reset the unread counter for the current user in a chat room.
  Future<void> markAsRead(String chatId) async {
    final uid = _currentUid;
    if (uid == null) return;

    try {
      await _firestore.collection('chats').doc(chatId).set(
        {'unread_$uid': 0},
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ChatController: markAsRead error: $e');
    }
  }

  /// Total unread count across all chat rooms for badge display.
  Stream<int> totalUnreadStream() {
    final uid = _currentUid;
    if (uid == null) return Stream.value(0);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        total += (data['unread_$uid'] as int?) ?? 0;
      }
      return total;
    });
  }
}
