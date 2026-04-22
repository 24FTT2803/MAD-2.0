import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hobbee_app/pages/banned_notice_page.dart';
import 'package:hobbee_app/pages/community_detail_page.dart';
import 'package:hobbee_app/pages/comment_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.orange.shade800,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.mark_as_unread, size: 20),
              onPressed: () async {
                final notifications = await FirebaseFirestore.instance
                    .collection('notifications')
                    .where('userId', isEqualTo: userId)
                    .where('read', isEqualTo: false)
                    .get();
                
                for (var doc in notifications.docs) {
                  await doc.reference.update({'read': true});
                }
                setState(() {});
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
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
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading notifications',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
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
          
          final notifications = snapshot.data?.docs ?? [];
          
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_off,
                      size: 50,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When someone likes your post, joins your community,\nor ownership changes, it will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final data = notification.data() as Map<String, dynamic>;
              final isRead = data['read'] == true;
              
              DateTime? timestamp;
              if (data['timestamp'] is Timestamp) {
                timestamp = (data['timestamp'] as Timestamp).toDate();
              } else if (data['timestamp'] is int) {
                timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
              }
              
              // POST DELETED BY ADMIN NOTIFICATION
              if (data['type'] == 'post_deleted_by_admin') {
                final actorName = data['actorName'] ?? 'A super admin';
                final postTitle = data['postTitle'] ?? 'your post';
                final reason = data['reason'] ?? 'Violation of community guidelines';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isRead ? Colors.white : Colors.red.shade50,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(Icons.delete_forever, color: Colors.red, size: 24),
                    ),
                    title: const Text(
                      'Your post was deleted',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('"$postTitle" was removed by $actorName'),
                        const SizedBox(height: 4),
                        Text(
                          'Reason: $reason',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.error_outline, size: 20, color: Colors.red),
                  ),
                );
              }
              
              // BANNED NOTIFICATION
              if (data['type'] == 'banned') {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isRead ? Colors.white : Colors.red.shade50,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(Icons.block, color: Colors.red, size: 24),
                    ),
                    title: const Text('You have been banned', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Community: ${data['communityName'] ?? 'Unknown'}'),
                        const SizedBox(height: 4),
                        Text('Reason: ${data['reason'] ?? 'No reason'}', style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                    onTap: () async {
                      await notification.reference.update({'read': true});
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BannedNoticePage(
                              communityId: data['communityId'] ?? '',
                              communityName: data['communityName'] ?? 'Community',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              }
              
              // UNBAN NOTIFICATION
              if (data['type'] == 'unbanned') {
                final actorName = data['actorName'] ?? 'An admin';
                final communityName = data['communityName'] ?? 'Community';
                final communityId = data['communityId'];
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isRead ? Colors.white : Colors.green.shade50,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
                    ),
                    title: Text(
                      '$actorName unbanned you',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Community: $communityName'),
                        const SizedBox(height: 4),
                        Text(
                          'You can now rejoin this community',
                          style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.green),
                    onTap: () async {
                      await notification.reference.update({'read': true});
                      if (context.mounted && communityId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommunityDetailPage(
                              communityId: communityId,
                              communityName: communityName,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              }
              
              // LIKE NOTIFICATION
              if (data['type'] == 'liked_post') {
                final actorName = data['actorName'] ?? 'Someone';
                final postTitle = data['postTitle'] ?? 'a post';
                final communityName = data['communityName'] ?? 'Community';
                final communityId = data['communityId'];
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isRead ? Colors.white : Colors.blue.shade50,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(Icons.thumb_up, color: Colors.blue, size: 24),
                    ),
                    title: Text(
                      '$actorName liked your post',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('"$postTitle" in $communityName'),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
                    onTap: () async {
                      await notification.reference.update({'read': true});
                      if (context.mounted && communityId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommunityDetailPage(
                              communityId: communityId,
                              communityName: communityName,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              }
              
              // DISLIKE NOTIFICATION
              if (data['type'] == 'disliked_post') {
                final actorName = data['actorName'] ?? 'Someone';
                final postTitle = data['postTitle'] ?? 'a post';
                final communityName = data['communityName'] ?? 'Community';
                final communityId = data['communityId'];
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isRead ? Colors.white : Colors.red.shade50,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(Icons.thumb_down, color: Colors.red, size: 24),
                    ),
                    title: Text(
                      '$actorName disliked your post',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('"$postTitle" in $communityName'),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                    onTap: () async {
                      await notification.reference.update({'read': true});
                      if (context.mounted && communityId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommunityDetailPage(
                              communityId: communityId,
                              communityName: communityName,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              }
              
              // COMMENT NOTIFICATION
              if (data['type'] == 'commented') {
                final actorName = data['actorName'] ?? 'Someone';
                final postTitle = data['postTitle'] ?? 'a post';
                final communityName = data['communityName'] ?? 'Community';
                final postId = data['postId'];
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isRead ? Colors.white : Colors.purple.shade50,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(Icons.comment, color: Colors.purple, size: 24),
                    ),
                    title: Text(
                      '$actorName commented on your post',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('"$postTitle" in $communityName'),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.purple),
                    onTap: () async {
                      await notification.reference.update({'read': true});
                      if (context.mounted && postId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommentPage(
                              postId: postId,
                              postTitle: postTitle,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              }
              
              // JOIN NOTIFICATION
              if (data['type'] == 'joined_community') {
                final actorName = data['actorName'] ?? 'Someone';
                final communityName = data['communityName'] ?? 'Community';
                final communityId = data['communityId'];
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isRead ? Colors.white : Colors.green.shade50,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(Icons.person_add, color: Colors.green, size: 24),
                    ),
                    title: Text(
                      '$actorName joined your community',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Community: $communityName'),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.green),
                    onTap: () async {
                      await notification.reference.update({'read': true});
                      if (context.mounted && communityId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommunityDetailPage(
                              communityId: communityId,
                              communityName: communityName,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              }
              
              // BECAME OWNER NOTIFICATION
              if (data['type'] == 'became_owner') {
                final actorName = data['actorName'] ?? 'An admin';
                final communityName = data['communityName'] ?? 'Community';
                final communityId = data['communityId'];
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isRead ? Colors.white : Colors.purple.shade50,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(Icons.workspace_premium, color: Colors.purple, size: 24),
                    ),
                    title: Text(
                      '$actorName transferred ownership to you',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Community: $communityName'),
                        const SizedBox(height: 4),
                        Text(
                          'You are now the owner of this community',
                          style: TextStyle(color: Colors.purple.shade700, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.purple),
                    onTap: () async {
                      await notification.reference.update({'read': true});
                      if (context.mounted && communityId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommunityDetailPage(
                              communityId: communityId,
                              communityName: communityName,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              }
              
              // OWNERSHIP TRANSFERRED AWAY NOTIFICATION
              if (data['type'] == 'ownership_transferred_away') {
                final actorName = data['actorName'] ?? 'An admin';
                final newOwnerName = data['newOwnerName'] ?? 'another user';
                final communityName = data['communityName'] ?? 'Community';
                final communityId = data['communityId'];
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isRead ? Colors.white : Colors.orange.shade50,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(Icons.swap_horiz, color: Colors.orange, size: 24),
                    ),
                    title: const Text(
                      'Your community ownership was transferred',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Community: $communityName'),
                        const SizedBox(height: 4),
                        Text(
                          '$actorName transferred ownership to $newOwnerName',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You are no longer the owner of this community',
                          style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange),
                    onTap: () async {
                      await notification.reference.update({'read': true});
                      if (context.mounted && communityId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommunityDetailPage(
                              communityId: communityId,
                              communityName: communityName,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              }
              
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}