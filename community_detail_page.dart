import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hobbee_app/pages/create_post_page.dart';
import 'package:hobbee_app/pages/report_page.dart';
import 'package:hobbee_app/pages/comment_page.dart';
import 'package:hobbee_app/pages/search_posts_in_community_page.dart';
import 'package:hobbee_app/pages/banned_notice_page.dart';
import 'package:hobbee_app/pages/community_admin_panel.dart';

class CommunityDetailPage extends StatefulWidget {
  final String communityId;
  final String communityName;

  const CommunityDetailPage({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  State<CommunityDetailPage> createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends State<CommunityDetailPage> {
  bool _isMember = false;
  bool _isLoading = false;
  String? _currentUserRole;
  bool _isBanned = false;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserRole();
    _checkIfBanned();
    _checkIfOwner();
    _checkMembership();
  }

  Future<void> _loadCurrentUserRole() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentUserRole = data['role'] ?? 'user';
        });
      }
    }
  }

  Future<void> _checkIfOwner() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final communityDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .get();

    if (communityDoc.exists) {
      final data = communityDoc.data() as Map<String, dynamic>;
      setState(() {
        _isOwner = data['creatorId'] == currentUser.uid;
      });
    }
  }

  Future<void> _checkMembership() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final communityDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .get();

    if (communityDoc.exists) {
      final data = communityDoc.data() as Map<String, dynamic>;
      final members = List<String>.from(data['members'] ?? []);
      setState(() {
        _isMember = members.contains(currentUser.uid);
      });
    }
  }

  Future<void> _checkIfBanned() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final communityDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .get();

    if (communityDoc.exists) {
      final data = communityDoc.data() as Map<String, dynamic>;
      final bannedUsers = List<String>.from(data['bannedUsers'] ?? []);
      setState(() {
        _isBanned = bannedUsers.contains(currentUser.uid);
      });
    }
  }

  void _showSearchDialog(BuildContext context) {
    final TextEditingController searchController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Search Posts'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Search by title, content, or tags...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SearchPostsInCommunityPage(
                  communityId: widget.communityId,
                  communityName: widget.communityName,
                  initialQuery: value,
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchPostsInCommunityPage(
                    communityId: widget.communityId,
                    communityName: widget.communityName,
                    initialQuery: searchController.text,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isBanned) {
      return BannedNoticePage(
        communityId: widget.communityId,
        communityName: widget.communityName,
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.communityName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.orange.shade800,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.orange.shade800),
            onPressed: () => _showSearchDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.post_add, color: Colors.orange.shade800),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatePostPage(communityId: widget.communityId),
                ),
              ).then((_) => setState(() {}));
            },
          ),
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.orange),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityAdminPanel(
                      communityId: widget.communityId,
                      communityName: widget.communityName,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Community Header
          SliverToBoxAdapter(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('communities')
                  .doc(widget.communityId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final members = List<String>.from(data['members'] ?? []);
                final isMember = members.contains(FirebaseAuth.instance.currentUser?.uid);
                final creatorId = data['creatorId'] ?? '';
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                final isAdmin = creatorId == currentUserId;
                final memberCount = members.length;
                final communityImage = data['communityImage'];
                
                return Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade100,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.deepOrange],
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Center(
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.white,
                            backgroundImage: communityImage != null
                                ? NetworkImage(communityImage)
                                : null,
                            child: communityImage == null
                                ? Icon(Icons.group, size: 45, color: Colors.orange.shade700)
                                : null,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              widget.communityName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data['description'] ?? 'No description',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people, size: 16, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  '$memberCount members',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : () => _toggleJoin(isMember),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isMember ? Colors.grey : Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(_getButtonText(isMember)),
                                  ),
                                ),
                                if (isAdmin) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _deleteCommunity,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // Show warning for owners
                            if (_isOwner && isMember)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'You are the owner. Transfer ownership to another member before leaving.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Posts Section Header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                'Posts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Posts List
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('communityId', isEqualTo: widget.communityId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              }
              
              final posts = snapshot.data?.docs ?? [];
              
              if (posts.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.post_add, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No posts yet. Be the first to post!'),
                      ],
                    ),
                  ),
                );
              }
              
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = posts[index];
                    final data = post.data() as Map<String, dynamic>;
                    return _PostCard(
                      postId: post.id,
                      data: data,
                      communityName: widget.communityName,
                      communityId: widget.communityId,
                      currentUserRole: _currentUserRole,
                      isCommunityOwner: _isOwner,
                      onPostDeleted: () => setState(() {}),
                    );
                  },
                  childCount: posts.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  String _getButtonText(bool isMember) {
    if (_isOwner && isMember) {
      return 'Leave (Transfer ownership first)';
    }
    return isMember ? 'Leave Community' : 'Join Community';
  }
  
  Future<void> _toggleJoin(bool isMember) async {
    // Prevent owner from leaving
    if (_isOwner && isMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot leave your own community. Transfer ownership to another member first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final communityRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId);
      
      final communityDoc = await communityRef.get();
      final communityData = communityDoc.data() as Map<String, dynamic>;
      final creatorId = communityData['creatorId'];
      final communityName = communityData['name'] ?? widget.communityName;
      
      if (isMember) {
        // Leave community
        await communityRef.update({
          'members': FieldValue.arrayRemove([userId]),
        });
        
        await FirebaseFirestore.instance.collection('activities').add({
          'userId': userId,
          'type': 'left_community',
          'communityId': widget.communityId,
          'communityName': communityName,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Left community')),
          );
        }
      } else {
        // Join community
        await communityRef.update({
          'members': FieldValue.arrayUnion([userId]),
        });
        
        await FirebaseFirestore.instance.collection('activities').add({
          'userId': userId,
          'type': 'joined_community',
          'communityId': widget.communityId,
          'communityName': communityName,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        if (creatorId != null && creatorId != userId) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          final userName = (userDoc.data() as Map<String, dynamic>?)?['username'] ?? 'Someone';
          
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': creatorId,
            'type': 'joined_community',
            'actorId': userId,
            'actorName': userName,
            'communityId': widget.communityId,
            'communityName': communityName,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'read': false,
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Joined community!')),
          );
        }
      }
      
      // Update membership status
      setState(() {
        _isMember = !isMember;
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _deleteCommunity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Community'),
        content: const Text('Are you sure you want to delete this community? This action cannot be undone.'),
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
        final posts = await FirebaseFirestore.instance
            .collection('posts')
            .where('communityId', isEqualTo: widget.communityId)
            .get();
        
        for (var post in posts.docs) {
          final comments = await FirebaseFirestore.instance
              .collection('comments')
              .where('postId', isEqualTo: post.id)
              .get();
          
          for (var comment in comments.docs) {
            await comment.reference.delete();
          }
          
          await post.reference.delete();
        }
        
        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Community deleted')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}

class _PostCard extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;
  final String communityName;
  final String communityId;
  final String? currentUserRole;
  final bool isCommunityOwner;
  final VoidCallback onPostDeleted;

  const _PostCard({
    required this.postId,
    required this.data,
    required this.communityName,
    required this.communityId,
    this.currentUserRole,
    required this.isCommunityOwner,
    required this.onPostDeleted,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _isLiked = false;
  bool _isDisliked = false;
  int _likeCount = 0;
  int _dislikeCount = 0;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    final likes = List<String>.from(widget.data['likes'] ?? []);
    final dislikes = List<String>.from(widget.data['dislikes'] ?? []);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    _likeCount = likes.length;
    _dislikeCount = dislikes.length;
    _isLiked = likes.contains(currentUserId);
    _isDisliked = dislikes.contains(currentUserId);
  }

  Future<void> _addActivity(String type) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    try {
      await FirebaseFirestore.instance.collection('activities').add({
        'userId': currentUser.uid,
        'type': type,
        'postId': widget.postId,
        'postTitle': widget.data['title'],
        'communityId': widget.data['communityId'],
        'communityName': widget.communityName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding activity: $e');
    }
  }

  Future<void> _sendLikeNotification() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final postAuthorId = widget.data['authorId'];
    final postTitle = widget.data['title'] ?? 'a post';
    final communityId = widget.data['communityId'];
    final communityName = widget.communityName;
    
    if (currentUser == null || postAuthorId == currentUser.uid) return;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userName = (userDoc.data() as Map<String, dynamic>?)?['username'] ?? 'Someone';
      
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': postAuthorId,
        'type': 'liked_post',
        'actorId': currentUser.uid,
        'actorName': userName,
        'postId': widget.postId,
        'postTitle': postTitle,
        'communityId': communityId,
        'communityName': communityName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'read': false,
      });
      print('✅ Like notification sent');
    } catch (e) {
      print('Error sending like notification: $e');
    }
  }

  Future<void> _sendDislikeNotification() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final postAuthorId = widget.data['authorId'];
    final postTitle = widget.data['title'] ?? 'a post';
    final communityId = widget.data['communityId'];
    final communityName = widget.communityName;
    
    if (currentUser == null || postAuthorId == currentUser.uid) return;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userName = (userDoc.data() as Map<String, dynamic>?)?['username'] ?? 'Someone';
      
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': postAuthorId,
        'type': 'disliked_post',
        'actorId': currentUser.uid,
        'actorName': userName,
        'postId': widget.postId,
        'postTitle': postTitle,
        'communityId': communityId,
        'communityName': communityName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'read': false,
      });
      print('✅ Dislike notification sent');
    } catch (e) {
      print('Error sending dislike notification: $e');
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
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
      setState(() => _isDeleting = true);
      
      try {
        final comments = await FirebaseFirestore.instance
            .collection('comments')
            .where('postId', isEqualTo: widget.postId)
            .get();
        
        for (var comment in comments.docs) {
          await comment.reference.delete();
        }
        
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted')),
          );
          widget.onPostDeleted();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isDeleting = false);
        }
      }
    }
  }

  bool get _canDelete {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isAuthor = widget.data['authorId'] == currentUserId;
    final isAdminOrSuper = widget.currentUserRole == 'admin' || widget.currentUserRole == 'superadmin';
    return isAuthor || isAdminOrSuper || widget.isCommunityOwner;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.data['imageUrl'];
    final hasImage = imageUrl != null && imageUrl.toString().isNotEmpty;
    
    List<String> tags = [];
    if (widget.data['tags'] != null) {
      tags = List<String>.from(widget.data['tags']);
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.orange.shade100,
                  child: Text(
                    (widget.data['authorName'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.data['authorName'] ?? 'User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _formatTime((widget.data['createdAt'] as Timestamp).toDate()),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.flag_outlined, size: 20),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportPage(
                          postId: widget.postId,
                          postTitle: widget.data['title'] ?? '',
                        ),
                      ),
                    );
                  },
                ),
                if (_canDelete && !_isDeleting)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    onPressed: _deletePost,
                  ),
                if (_isDeleting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          
          // Post Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.data['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.data['content'] ?? '',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Tags
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )).toList(),
                  ),
                
                if (tags.isNotEmpty) const SizedBox(height: 12),
                
                // Image
                if (hasImage) ...[
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InteractiveViewer(
                                child: Image.network(imageUrl),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          
          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                    color: _isLiked ? Colors.blue : Colors.grey,
                    size: 22,
                  ),
                  onPressed: _toggleLike,
                ),
                Text('$_likeCount'),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _isDisliked ? Icons.thumb_down : Icons.thumb_down_alt_outlined,
                    color: _isDisliked ? Colors.red : Colors.grey,
                    size: 22,
                  ),
                  onPressed: _toggleDislike,
                ),
                Text('$_dislikeCount'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.comment, size: 22),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommentPage(
                          postId: widget.postId,
                          postTitle: widget.data['title'] ?? 'Post',
                        ),
                      ),
                    );
                  },
                ),
                Text('${widget.data['commentCount'] ?? 0}'),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  Future<void> _toggleLike() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final wasLiked = _isLiked;
    final wasDisliked = _isDisliked;
    
    setState(() {
      if (wasLiked) {
        _isLiked = false;
        _likeCount--;
      } else {
        _isLiked = true;
        _likeCount++;
        if (wasDisliked) {
          _isDisliked = false;
          _dislikeCount--;
        }
      }
    });
    
    try {
      if (!wasLiked) {
        await postRef.update({
          'likes': FieldValue.arrayUnion([userId]),
          'dislikes': FieldValue.arrayRemove([userId]),
        });
        await _addActivity('liked_post');
        await _sendLikeNotification();
      } else {
        await postRef.update({
          'likes': FieldValue.arrayRemove([userId]),
        });
      }
    } catch (e) {
      setState(() {
        _isLiked = wasLiked;
        _likeCount = wasLiked ? _likeCount + 1 : _likeCount - 1;
        if (wasDisliked) {
          _isDisliked = true;
          _dislikeCount++;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  Future<void> _toggleDislike() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final wasDisliked = _isDisliked;
    final wasLiked = _isLiked;
    
    setState(() {
      if (wasDisliked) {
        _isDisliked = false;
        _dislikeCount--;
      } else {
        _isDisliked = true;
        _dislikeCount++;
        if (wasLiked) {
          _isLiked = false;
          _likeCount--;
        }
      }
    });
    
    try {
      if (!wasDisliked) {
        await postRef.update({
          'dislikes': FieldValue.arrayUnion([userId]),
          'likes': FieldValue.arrayRemove([userId]),
        });
        await _addActivity('disliked_post');
        await _sendDislikeNotification();
      } else {
        await postRef.update({
          'dislikes': FieldValue.arrayRemove([userId]),
        });
      }
    } catch (e) {
      setState(() {
        _isDisliked = wasDisliked;
        _dislikeCount = wasDisliked ? _dislikeCount + 1 : _dislikeCount - 1;
        if (wasLiked) {
          _isLiked = true;
          _likeCount++;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}