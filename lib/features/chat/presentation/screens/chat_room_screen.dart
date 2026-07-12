// lib/features/chat/presentation/screens/chat_room_screen.dart
//
// Real-time 1-on-1 chat between a client and a handyman.
// Messages are stored in Firestore under /chats/{chatId}/messages.
//
// Pagination strategy:
//   - The live stream fetches only the most recent _pageSize messages.
//   - Older messages are loaded on demand via cursor-based .get() calls
//     using startAfterDocument() so Firestore never scans more than needed.
//   - Scroll position is preserved when older messages are prepended.
//
// Firestore structure:
//   /chats/{chatId}
//     participants: [uid1, uid2]
//     lastMessage: String
//     lastMessageAt: Timestamp
//     unread_{uid}: int          -- per-user unread counter
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

  // ── Pagination state ────────────────────────────────────────────────────
  // Older messages loaded on demand (in chronological order, oldest first).
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _olderDocs = [];

  // Cursor pointing to the chronologically oldest document loaded so far.
  // Used as the startAfterDocument() anchor for the next older-page fetch.
  QueryDocumentSnapshot<Map<String, dynamic>>? _pageCursor;

  bool _isLoadingMore = false;

  // True once we know there are messages older than the live stream window.
  bool _hasMoreMessages = false;

  // Number of messages fetched per page (live stream + each older page).
  static const int _pageSize = 50;

  // ── Read-tracking ────────────────────────────────────────────────────────
  // Avoid calling _markRead() on every StreamBuilder rebuild.
  bool _hasMarkedRead = false;

  // Track previous live-stream count to detect genuinely new messages.
  int _previousLiveCount = 0;

  // ── Auth helpers ─────────────────────────────────────────────────────────
  String? get _myUid => _auth.currentUser?.uid;

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

  // ── Firestore helpers ────────────────────────────────────────────────────

  Future<void> _markRead() async {
    final uid = _myUid;
    if (uid == null) return;
    try {
      await _firestore.collection('chats').doc(widget.chatId).set(
        {'unread_$uid': 0},
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ChatRoom: markRead error: $e');
    }
  }

  Future<void> _sendMessage() async {
    final uid = _myUid;
    if (uid == null) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    final batch = _firestore.batch();

    final msgRef = _messagesRef.doc();
    batch.set(msgRef, {
      'senderId': uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    final chatRef = _firestore.collection('chats').doc(widget.chatId);
    batch.set(
      chatRef,
      {
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'participants': [uid, widget.otherUserId],
        'unread_${widget.otherUserId}': FieldValue.increment(1),
        'unread_$uid': 0,
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

  /// Load the next page of older messages using cursor-based pagination.
  ///
  /// Uses startAfterDocument() so Firestore reads exactly _pageSize docs —
  /// no offset scanning, no wasted reads.
  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _pageCursor == null) return;

    // Capture the scroll offset from the bottom before prepending.
    // We'll restore it after the new items render so the view doesn't jump.
    final offsetFromBottom = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent -
            _scrollController.offset
        : 0.0;

    setState(() => _isLoadingMore = true);

    try {
      final snap = await _messagesRef
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_pageCursor!)
          .limit(_pageSize)
          .get();

      if (!mounted) return;

      if (snap.docs.isEmpty) {
        setState(() {
          _hasMoreMessages = false;
          _isLoadingMore = false;
        });
        return;
      }

      // Docs arrive newest-first (descending). Reverse to chronological order
      // before prepending to _olderDocs, which is always oldest-first.
      final fetchedChronological = snap.docs.reversed.toList();

      // Move cursor to the oldest document in this page (last in descending).
      final newCursor = snap.docs.last;

      setState(() {
        _olderDocs.insertAll(0, fetchedChronological);
        _pageCursor = newCursor;
        _hasMoreMessages = snap.docs.length >= _pageSize;
        _isLoadingMore = false;
      });

      // Restore scroll position after the new items are rendered.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final newMax = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(
            (newMax - offsetFromBottom).clamp(0.0, newMax),
          );
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('ChatRoom: loadOlderMessages error: $e');
      if (mounted) setState(() => _isLoadingMore = false);
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = _myUid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor(context),
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor(context),
          elevation: 0,
          title: Text(
            'Chat',
            style: TextStyle(color: AppColors.textPrimaryColor(context)),
          ),
        ),
        body: const Center(child: Text('Not logged in')),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(isDark, uid)),
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
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: AppColors.textPrimaryColor(context),
          size: 20,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage:
                widget.otherUserPicture != null &&
                    widget.otherUserPicture!.isNotEmpty
                ? NetworkImage(widget.otherUserPicture!)
                : null,
            backgroundColor: AppColors.primaryColor.withValues(alpha: 0.2),
            child:
                widget.otherUserPicture == null ||
                    widget.otherUserPicture!.isEmpty
                ? Text(
                    widget.otherUserName.isNotEmpty
                        ? widget.otherUserName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
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

  Widget _buildMessageList(bool isDark, String myUid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // Live stream: the most recent _pageSize messages only.
      // Ordered descending so Firestore returns the newest first,
      // then we reverse for chronological display.
      stream: _messagesRef
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _olderDocs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  'Error loading messages',
                  style: TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Stream docs arrive newest-first. Reverse to chronological order.
        final liveDocs = (snapshot.data?.docs ?? []).reversed.toList();

        // On the first snapshot with data, set up the pagination cursor.
        // The oldest doc in the stream is the starting point for loading history.
        if (_pageCursor == null && (snapshot.data?.docs ?? []).isNotEmpty) {
          // docs.last in a descending query = chronologically oldest
          final oldestInStream = snapshot.data!.docs.last;
          // Only show "load older" if the stream is already full (_pageSize docs),
          // which means there are likely more messages before it.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _pageCursor = oldestInStream;
                _hasMoreMessages =
                    (snapshot.data!.docs.length >= _pageSize);
              });
            }
          });
        }

        // Combine: _olderDocs (history) + liveDocs (recent stream)
        final allDocs = [..._olderDocs, ...liveDocs];

        if (allDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 56,
                  color: AppColors.grey400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No messages yet',
                  style: TextStyle(
                    color: AppColors.textSecondaryColor(context),
                    fontSize: 16,
                  ),
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

        // Mark as read once on initial load.
        if (!_hasMarkedRead) {
          _hasMarkedRead = true;
          _markRead();
        }

        // Auto-scroll to bottom only when new live messages arrive.
        final currentLiveCount = liveDocs.length;
        if (currentLiveCount > _previousLiveCount) {
          _previousLiveCount = currentLiveCount;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        }

        // +1 for the "load older" header slot at index 0.
        final itemCount = allDocs.length + 1;

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: itemCount,
          itemBuilder: (context, i) {
            // Index 0 is always the load-more header at the top of the list.
            if (i == 0) {
              return _buildLoadMoreHeader();
            }

            final doc = allDocs[i - 1];
            final data = doc.data();
            final isMe = data['senderId'] == myUid;
            final text = data['text'] as String? ?? '';
            final ts = data['createdAt'] as Timestamp?;
            final time = ts != null ? _formatTime(ts.toDate()) : '';

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

  /// The header shown at the very top of the message list.
  /// Shows a loading spinner, "Load older messages" button, or nothing.
  Widget _buildLoadMoreHeader() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_hasMoreMessages) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Center(
          child: TextButton.icon(
            onPressed: _loadOlderMessages,
            icon: Icon(
              Icons.history,
              size: 16,
              color: AppColors.primaryColor,
            ),
            label: Text(
              'Load older messages',
              style: TextStyle(
                color: AppColors.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppColors.primaryColor.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // No more messages to load — show a subtle beginning-of-chat label.
    if (_olderDocs.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            '— Beginning of conversation —',
            style: TextStyle(
              color: AppColors.grey400,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    // Haven't loaded any older messages yet — show nothing.
    return const SizedBox.shrink();
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
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: AppColors.grey400, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
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
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
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

// ── Message bubble widget ────────────────────────────────────────────────────

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
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) const SizedBox(width: 4),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isMe
                        ? AppColors.primaryColor
                        : AppColors.cardColor(context),
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
                      color:
                          isMe
                              ? Colors.white
                              : AppColors.textPrimaryColor(context),
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
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}
