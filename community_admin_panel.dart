import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommunityAdminPanel extends StatefulWidget {
  final String communityId;
  final String communityName;

  const CommunityAdminPanel({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  State<CommunityAdminPanel> createState() => _CommunityAdminPanelState();
}

class _CommunityAdminPanelState extends State<CommunityAdminPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isOwner = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkOwnership();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkOwnership() async {
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
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isOwner) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: Colors.orange,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('You are not the owner of this community.'),
              SizedBox(height: 8),
              Text('Only community owners can access this panel.'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage ${widget.communityName}'),
        backgroundColor: Colors.orange,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Members', icon: Icon(Icons.people)),
            Tab(text: 'Banned', icon: Icon(Icons.block)),
            Tab(text: 'Transfer', icon: Icon(Icons.swap_horiz)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MembersManagement(communityId: widget.communityId, communityName: widget.communityName),
          _BannedUsersManagement(communityId: widget.communityId, communityName: widget.communityName),
          _TransferOwnershipManagement(communityId: widget.communityId, communityName: widget.communityName),
        ],
      ),
    );
  }
}

class _MembersManagement extends StatefulWidget {
  final String communityId;
  final String communityName;

  const _MembersManagement({required this.communityId, required this.communityName});

  @override
  State<_MembersManagement> createState() => _MembersManagementState();
}

class _MembersManagementState extends State<_MembersManagement> {
  Future<void> _banUser(BuildContext context, String userId, String userName) async {
    final reasonController = TextEditingController();
    String? selectedReason;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ban User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you banning this user?'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedReason,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select a reason',
              ),
              items: const [
                DropdownMenuItem(value: 'Spam', child: Text('Spam')),
                DropdownMenuItem(value: 'Harassment', child: Text('Harassment')),
                DropdownMenuItem(value: 'Inappropriate content', child: Text('Inappropriate content')),
                DropdownMenuItem(value: 'Hate speech', child: Text('Hate speech')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) {
                selectedReason = value;
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Additional details (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Ban'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        String finalReason = selectedReason ?? 'Violation of community guidelines';
        if (reasonController.text.trim().isNotEmpty) {
          finalReason = '$finalReason: ${reasonController.text.trim()}';
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

        final communityDoc = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .get();
        final data = communityDoc.data() as Map<String, dynamic>;
        final bannedUsersDetails = List<Map<String, dynamic>>.from(data['bannedUsersDetails'] ?? []);

        bannedUsersDetails.add({
          'userId': userId,
          'userName': userName,
          'reason': finalReason,
          'bannedAt': currentTimestamp,
          'bannedBy': currentUser?.uid ?? 'unknown',
        });

        await FirebaseFirestore.instance.collection('communities').doc(widget.communityId).update({
          'bannedUsers': FieldValue.arrayUnion([userId]),
          'bannedUsersDetails': bannedUsersDetails,
          'members': FieldValue.arrayRemove([userId]),
        });

        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': userId,
          'type': 'banned',
          'communityId': widget.communityId,
          'communityName': widget.communityName,
          'reason': finalReason,
          'timestamp': currentTimestamp,
          'read': false,
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$userName has been banned from ${widget.communityName}')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('communities').doc(widget.communityId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final members = List<String>.from(data['members'] ?? []);

        if (members.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No members yet'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final memberId = members[index];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return const SizedBox.shrink();

                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                final userName = userData['username'] ?? 'User';
                final email = userData['email'] ?? '';
                final profileImage = userData['profileImage'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
                      backgroundColor: Colors.orange.shade100,
                      child: profileImage == null
                          ? Text(userName[0].toUpperCase(), style: const TextStyle(color: Colors.orange))
                          : null,
                    ),
                    title: Text(userName),
                    subtitle: Text(email),
                    trailing: memberId != currentUserId
                        ? ElevatedButton.icon(
                            onPressed: () => _banUser(context, memberId, userName),
                            icon: const Icon(Icons.block, size: 16),
                            label: const Text('Ban'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _BannedUsersManagement extends StatelessWidget {
  final String communityId;
  final String communityName;

  const _BannedUsersManagement({required this.communityId, required this.communityName});

  Future<void> _unbanUser(BuildContext context, String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unban User'),
        content: Text('Are you sure you want to unban $userName from "$communityName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Unban'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final communityDoc = await FirebaseFirestore.instance
            .collection('communities')
            .doc(communityId)
            .get();
        final data = communityDoc.data() as Map<String, dynamic>;
        final bannedUsersDetails = List<Map<String, dynamic>>.from(data['bannedUsersDetails'] ?? []);
        final updatedBannedDetails = bannedUsersDetails.where((ban) => ban['userId'] != userId).toList();

        await FirebaseFirestore.instance.collection('communities').doc(communityId).update({
          'bannedUsers': FieldValue.arrayRemove([userId]),
          'bannedUsersDetails': updatedBannedDetails,
        });

        final currentAdmin = FirebaseAuth.instance.currentUser;
        String adminName = 'An admin';
        if (currentAdmin != null) {
          final adminDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentAdmin.uid)
              .get();
          if (adminDoc.exists) {
            adminName = (adminDoc.data() as Map<String, dynamic>)['username'] ?? 'An admin';
          }
        }

        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': userId,
          'type': 'unbanned',
          'actorId': currentAdmin?.uid,
          'actorName': adminName,
          'communityId': communityId,
          'communityName': communityName,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'read': false,
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$userName has been unbanned from $communityName')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('communities').doc(communityId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final bannedUsersDetails = List<Map<String, dynamic>>.from(data['bannedUsersDetails'] ?? []);

        if (bannedUsersDetails.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No banned users'),
                SizedBox(height: 8),
                Text(
                  'Banned users will appear here',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bannedUsersDetails.length,
          itemBuilder: (context, index) {
            final ban = bannedUsersDetails[index];
            final userName = ban['userName'] ?? 'User';
            final reason = ban['reason'] ?? 'No reason';
            final bannedAt = ban['bannedAt'] != null
                ? DateTime.fromMillisecondsSinceEpoch(ban['bannedAt'] as int)
                : null;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade100,
                  child: Text(userName[0].toUpperCase(), style: const TextStyle(color: Colors.red)),
                ),
                title: Text(userName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reason: $reason'),
                    if (bannedAt != null)
                      Text(
                        'Banned on: ${bannedAt.day}/${bannedAt.month}/${bannedAt.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                trailing: ElevatedButton.icon(
                  onPressed: () => _unbanUser(context, ban['userId'], userName),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Unban'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TransferOwnershipManagement extends StatefulWidget {
  final String communityId;
  final String communityName;

  const _TransferOwnershipManagement({required this.communityId, required this.communityName});

  @override
  State<_TransferOwnershipManagement> createState() => _TransferOwnershipManagementState();
}

class _TransferOwnershipManagementState extends State<_TransferOwnershipManagement> {
  bool _isTransferring = false;

  Future<void> _transferOwnership(BuildContext context, String newOwnerId, String newOwnerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Ownership'),
        content: Text('Are you sure you want to transfer ownership of "${widget.communityName}" to $newOwnerName?\n\nYou will lose owner privileges.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isTransferring = true);

      try {
        final currentAdmin = FirebaseAuth.instance.currentUser;
        final adminDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentAdmin?.uid)
            .get();
        final adminName = (adminDoc.data() as Map<String, dynamic>?)?['username'] ?? 'An admin';
        final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

        final communityDoc = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .get();
        final currentOwnerId = (communityDoc.data() as Map<String, dynamic>)['creatorId'];
        
        String? currentOwnerName;
        if (currentOwnerId != null) {
          final ownerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentOwnerId)
              .get();
          if (ownerDoc.exists) {
            currentOwnerName = (ownerDoc.data() as Map<String, dynamic>)['username'] ?? 'Unknown';
          }
        }

        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .update({
          'creatorId': newOwnerId,
        });

        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': newOwnerId,
          'type': 'became_owner',
          'actorId': currentAdmin?.uid,
          'actorName': adminName,
          'communityId': widget.communityId,
          'communityName': widget.communityName,
          'timestamp': currentTimestamp,
          'read': false,
        });

        if (currentOwnerId != null && currentOwnerId != currentAdmin?.uid) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': currentOwnerId,
            'type': 'ownership_transferred_away',
            'actorId': currentAdmin?.uid,
            'actorName': adminName,
            'newOwnerId': newOwnerId,
            'newOwnerName': newOwnerName,
            'communityId': widget.communityId,
            'communityName': widget.communityName,
            'timestamp': currentTimestamp,
            'read': false,
          });
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ownership transferred to $newOwnerName')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isTransferring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('communities').doc(widget.communityId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final members = List<String>.from(data['members'] ?? []);
        final currentOwnerId = data['creatorId'];

        final eligibleMembers = members.where((id) => id != currentOwnerId).toList();

        if (eligibleMembers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No other members to transfer ownership to'),
                SizedBox(height: 8),
                Text(
                  'Invite more members to transfer ownership',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: eligibleMembers.length,
          itemBuilder: (context, index) {
            final memberId = eligibleMembers[index];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return const SizedBox.shrink();

                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                final userName = userData['username'] ?? 'User';
                final email = userData['email'] ?? '';
                final profileImage = userData['profileImage'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
                      backgroundColor: Colors.orange.shade100,
                      child: profileImage == null
                          ? Text(userName[0].toUpperCase(), style: const TextStyle(color: Colors.orange))
                          : null,
                    ),
                    title: Text(userName),
                    subtitle: Text(email),
                    trailing: _isTransferring
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _transferOwnership(context, memberId, userName),
                            icon: const Icon(Icons.swap_horiz, size: 16),
                            label: const Text('Transfer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}