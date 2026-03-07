// lib/features/chat/presentation/screens/chat_room_screen.dart
//
// Real-time 1-on-1 chat between a client and a handyman.
// Messages are stored in Firestore under /chats/{chatId}/messages.
//
// Firestore structure:
//   /chats/{chatId}
//     participants: [uid1, uid2]
//     lastMessage: String
//     lastMessageAt: Timestamp
//     unread_{uid}: int          ← per-user unread counter
//   /chats/{chatId}/messages/{msgId}
//     senderId: String
//     text: String
//     createdAt: Timestamp
//     read: bool

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPicture;

  const ChatRoomScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPicture,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  String get _myUid => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _firestore.collection('chats').doc(widget.chatId).collection('messages');

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Firestore helpers ───────────────────────────────────────────────────

  /// Reset unread counter for this user.
  Future<void> _markRead() async {
    try {
      await _firestore.collection('chats').doc(widget.chatId).set(
        {'unread_$_myUid': 0},
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ChatRoom: markRead error: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    final batch = _firestore.batch();

    // 1. Add message document
    final msgRef = _messagesRef.doc();
    batch.set(msgRef, {
      'senderId': _myUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    // 2. Update chat metadata + increment other user's unread counter
    final chatRef = _firestore.collection('chats').doc(widget.chatId);
    batch.set(
      chatRef,
      {
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'participants': [_myUid, widget.otherUserId],
        'unread_${widget.otherUserId}': FieldValue.increment(1),
        'unread_$_myUid': 0,
      },
      SetOptions(merge: true),
    );

    try {
      await batch.commit();
      _scrollToBottom();
    } catch (e) {
      if (kDebugMode) debugPrint('ChatRoom: send error: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(isDark)),
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  AppBar _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: AppColors.backgroundColor(context),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimaryColor(context), size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: widget.otherUserPicture != null && widget.otherUserPicture!.isNotEmpty
                ? NetworkImage(widget.otherUserPicture!)
                : null,
            backgroundColor: AppColors.primaryColor.withValues(alpha: 0.2),
            child: widget.otherUserPicture == null || widget.otherUserPicture!.isEmpty
                ? Text(
                    widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
                    style: TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Chat',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isDark) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesRef.orderBy('createdAt', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading messages', style: TextStyle(color: AppColors.error)),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 56, color: AppColors.grey400),
                const SizedBox(height: 12),
                Text(
                  'No messages yet',
                  style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start the conversation!',
                  style: TextStyle(color: AppColors.grey400, fontSize: 13),
                ),
              ],
            ),
          );
        }

        // Mark messages as read on new snapshot
        _markRead();

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final isMe = data['senderId'] == _myUid;
            final text = data['text'] as String? ?? '';
            final ts = data['createdAt'] as Timestamp?;
            final time = ts != null
                ? _formatTime(ts.toDate())
                : '';

            return _MessageBubble(
              text: text,
              isMe: isMe,
              time: time,
              isDark: isDark,
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundColor(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderColor(context)),
                ),
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 4,
                  minLines: 1,
                  style: TextStyle(
                    color: AppColors.textPrimaryColor(context),
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle: TextStyle(color: AppColors.grey400, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primaryColor, AppColors.secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─── Message bubble widget ────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;
  final bool isDark;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.time,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primaryColor : AppColors.cardColor(context),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppColors.textPrimaryColor(context),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : AppColors.grey400,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}
