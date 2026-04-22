import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommentPage extends StatefulWidget {
  final String postId;
  final String postTitle;

  const CommentPage({
    super.key,
    required this.postId,
    required this.postTitle,
  });

  @override
  State<CommentPage> createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> {
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;
  String? _currentUserName;
  String? _currentUserId;
  String? _currentUserRole;
  String? _communityId;
  String? _communityName;
  String? _postAuthorId;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadPostInfo();
  }

  Future<void> _loadCurrentUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _currentUserId = currentUser.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        _currentUserName = data['username'] ?? currentUser.email?.split('@').first ?? 'User';
        _currentUserRole = data['role'] ?? 'user';
      } else {
        _currentUserName = currentUser.email?.split('@').first ?? 'User';
        _currentUserRole = 'user';
      }
      setState(() {});
    }
  }

  Future<void> _loadPostInfo() async {
    final postDoc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .get();
    
    if (postDoc.exists) {
      final data = postDoc.data() as Map<String, dynamic>;
      _communityId = data['communityId'];
      _postAuthorId = data['authorId'];
      
      if (_communityId != null) {
        final communityDoc = await FirebaseFirestore.instance
            .collection('communities')
            .doc(_communityId)
            .get();
        
        if (communityDoc.exists) {
          final communityData = communityDoc.data() as Map<String, dynamic>;
          _communityName = communityData['name'];
        }
      }
    }
  }

  Future<void> _addCommentActivity() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    try {
      await FirebaseFirestore.instance.collection('activities').add({
        'userId': currentUser.uid,
        'type': 'commented',
        'postId': widget.postId,
        'postTitle': widget.postTitle,
        'communityId': _communityId,
        'communityName': _communityName,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('✅ Added to activities');
    } catch (e) {
      print('Error adding activity: $e');
    }
  }

  Future<void> _sendCommentNotification() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    // Don't send notification if commenting on your own post
    if (currentUser == null || _postAuthorId == currentUser.uid) {
      print('Not sending notification - same user or no user');
      return;
    }
    
    try {
      final notificationData = {
        'userId': _postAuthorId,
        'type': 'commented',
        'actorId': currentUser.uid,
        'actorName': _currentUserName ?? 'Someone',
        'postId': widget.postId,
        'postTitle': widget.postTitle,
        'communityId': _communityId,
        'communityName': _communityName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'read': false,
      };
      
      await FirebaseFirestore.instance.collection('notifications').add(notificationData);
      print('✅ Comment notification sent to post author: $_postAuthorId');
    } catch (e) {
      print('Error sending comment notification: $e');
    }
  }

  Future<void> _deleteComment(String commentId, String commentUserId) async {
    final canDelete = _currentUserId == commentUserId || 
                      _currentUserRole == 'admin' || 
                      _currentUserRole == 'superadmin';
    
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to delete this comment')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() => _isLoading = true);
      
      try {
        await FirebaseFirestore.instance
            .collection('comments')
            .doc(commentId)
            .delete();
        
        final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
        await postRef.update({
          'commentCount': FieldValue.increment(-1),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comment deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Comments',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.orange.shade800,
      ),
      body: Column(
        children: [
          // Post Title Header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.article, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.postTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          // Comments List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('comments')
                  .where('postId', isEqualTo: widget.postId)
                  .orderBy('createdAt', descending: true)
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
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final comments = snapshot.data?.docs ?? [];

                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to comment!',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final data = comment.data() as Map<String, dynamic>;
                    final commentUserId = data['userId'] as String? ?? '';
                    final isAuthor = _currentUserId == commentUserId;
                    final isAdminOrSuper = _currentUserRole == 'admin' || _currentUserRole == 'superadmin';
                    final canDelete = isAuthor || isAdminOrSuper;
                    
                    return _CommentCard(
                      commentId: comment.id,
                      data: data,
                      canDelete: canDelete,
                      onDelete: () => _deleteComment(comment.id, commentUserId),
                      currentUserId: _currentUserId,
                      currentUserRole: _currentUserRole,
                    );
                  },
                );
              },
            ),
          ),
          
          // Comment Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.orange.shade100,
                  child: Text(
                    (_currentUserName ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      onSubmitted: (_) => _postComment(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isLoading ? null : _postComment,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Please log in to comment');

      final commentData = {
        'postId': widget.postId,
        'userId': currentUser.uid,
        'userName': _currentUserName ?? 'User',
        'content': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
      };

      await FirebaseFirestore.instance.collection('comments').add(commentData);

      final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      await postRef.update({
        'commentCount': FieldValue.increment(1),
      });

      // Add to activities (what the user did)
      await _addCommentActivity();
      
      // Send notification to post author (what others did)
      await _sendCommentNotification();

      _commentController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class _CommentCard extends StatelessWidget {
  final String commentId;
  final Map<String, dynamic> data;
  final bool canDelete;
  final VoidCallback onDelete;
  final String? currentUserId;
  final String? currentUserRole;

  const _CommentCard({
    required this.commentId,
    required this.data,
    required this.canDelete,
    required this.onDelete,
    this.currentUserId,
    this.currentUserRole,
  });

  @override
  Widget build(BuildContext context) {
    final userName = data['userName'] as String? ?? 'User';
    final content = data['content'] as String? ?? '';
    final userId = data['userId'] as String? ?? '';
    final timestamp = data['createdAt'] as Timestamp?;
    final isAuthor = currentUserId == userId;
    final isAdminOrSuper = currentUserRole == 'admin' || currentUserRole == 'superadmin';
    
    String timeAgo = 'Just now';
    if (timestamp != null) {
      final now = DateTime.now();
      final diff = now.difference(timestamp.toDate());
      if (diff.inDays > 0) {
        timeAgo = '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        timeAgo = '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        timeAgo = '${diff.inMinutes}m ago';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.orange.shade100,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isAuthor)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Author',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (isAdminOrSuper && !isAuthor)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Admin',
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    content,
                    style: const TextStyle(fontSize: 14, height: 1.3),
                  ),
                ],
              ),
            ),
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}