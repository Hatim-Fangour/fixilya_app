// lib/features/chat/presentation/screens/chat_list_screen.dart
//
// Shows all chats for the current user, ordered by last message time.
// Tapping a conversation opens ChatRoomScreen.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/chat/presentation/screens/chat_room_screen.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor(context),
        elevation: 0,
        title: Text(
          'Messages',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: uid)
            .orderBy('lastMessageAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('Failed to load chats',
                      style: TextStyle(color: AppColors.textSecondaryColor(context))),
                ],
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 80,
              color: AppColors.dividerColor(context),
            ),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final chatId = docs[i].id;
              final participants = List<String>.from(data['participants'] ?? []);
              final otherUid = participants.firstWhere((p) => p != uid, orElse: () => '');
              final lastMessage = data['lastMessage'] as String? ?? '';
              final lastAt = data['lastMessageAt'] as Timestamp?;
              final unread = (data['unread_$uid'] as int?) ?? 0;

              return _ChatTile(
                chatId: chatId,
                otherUid: otherUid,
                lastMessage: lastMessage,
                lastAt: lastAt?.toDate(),
                unread: unread,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 72, color: AppColors.grey400),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Book a service to start chatting',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondaryColor(context)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  final String chatId;
  final String otherUid;
  final String lastMessage;
  final DateTime? lastAt;
  final int unread;

  const _ChatTile({
    required this.chatId,
    required this.otherUid,
    required this.lastMessage,
    this.lastAt,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) {
    // Load other user's profile from Firestore in real-time
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(otherUid).get(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data();
        final name = userData?['fullName'] as String? ?? 'User';
        final picture = userData?['profilePicture'] as String?;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatRoomScreen(
                chatId: chatId,
                otherUserId: otherUid,
                otherUserName: name,
                otherUserPicture: picture,
              ),
            ));
          },
          leading: CircleAvatar(
            radius: 26,
            backgroundImage: picture != null && picture.isNotEmpty
                ? NetworkImage(picture)
                : null,
            backgroundColor: AppColors.primaryColor.withValues(alpha: 0.15),
            child: picture == null || picture.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimaryColor(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (lastAt != null)
                Text(
                  timeago.format(lastAt!, allowFromNow: true),
                  style: TextStyle(
                    fontSize: 12,
                    color: unread > 0 ? AppColors.primaryColor : AppColors.grey400,
                  ),
                ),
            ],
          ),
          subtitle: Row(
            children: [
              Expanded(
                child: Text(
                  lastMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: unread > 0
                        ? AppColors.textPrimaryColor(context)
                        : AppColors.textSecondaryColor(context),
                    fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
