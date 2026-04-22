import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPanelPage extends StatefulWidget {
  final String userRole;

  const AdminPanelPage({super.key, required this.userRole});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    int tabCount = 3;
    if (widget.userRole == 'superadmin') {
      tabCount = 4;
    }
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userRole != 'admin' && widget.userRole != 'superadmin') {
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
              Text('You do not have permission to access this page.'),
            ],
          ),
        ),
      );
    }

    final List<Widget> tabs = [
      const Tab(text: 'Communities'),
      const Tab(text: 'Users'),
      const Tab(text: 'Reports'),
    ];
    
    final List<Widget> tabViews = [
      const _CommunitiesManagement(),
      const _UsersManagement(),
      const _ReportsManagement(),
    ];

    if (widget.userRole == 'superadmin') {
      tabs.insert(1, const Tab(text: 'Hobbies'));
      tabViews.insert(1, const _HobbiesManagement());
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.userRole.toUpperCase()} Panel'),
          backgroundColor: Colors.orange,
          bottom: TabBar(
            controller: _tabController,
            tabs: tabs,
            isScrollable: true,
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: tabViews,
        ),
      ),
    );
  }
}

// Communities Management with Transfer Ownership
class _CommunitiesManagement extends StatelessWidget {
  const _CommunitiesManagement();

  Future<void> _deleteCommunity(BuildContext context, String communityId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Community'),
        content: const Text('Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final posts = await FirebaseFirestore.instance.collection('posts').where('communityId', isEqualTo: communityId).get();
        for (var post in posts.docs) {
          final comments = await FirebaseFirestore.instance.collection('comments').where('postId', isEqualTo: post.id).get();
          for (var comment in comments.docs) await comment.reference.delete();
          await post.reference.delete();
        }
        await FirebaseFirestore.instance.collection('communities').doc(communityId).delete();
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Community deleted')));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _transferOwnership(BuildContext context, String communityId, String communityName) async {
    final TextEditingController emailController = TextEditingController();
    String? selectedUserId;
    String? selectedUserName;
    List<Map<String, dynamic>> members = [];

    final communityDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(communityId)
        .get();
    final data = communityDoc.data() as Map<String, dynamic>;
    final memberIds = List<String>.from(data['members'] ?? []);
    final currentOwnerId = data['creatorId'];
    final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
    
    String? currentOwnerName;
    final currentOwnerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentOwnerId)
        .get();
    if (currentOwnerDoc.exists) {
      final ownerData = currentOwnerDoc.data() as Map<String, dynamic>;
      currentOwnerName = ownerData['username'] ?? 'Unknown';
    }
    
    for (String id in memberIds) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        members.add({
          'id': id,
          'username': userData['username'] ?? 'User',
          'email': userData['email'] ?? '',
        });
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Transfer Ownership: $communityName'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select new owner from community members:'),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: selectedUserId,
                      hint: const Text('Select a member'),
                      isExpanded: true,
                      items: members.map((member) {
                        return DropdownMenuItem<String>(
                          value: member['id'],
                          child: Text('${member['username']} (${member['email']})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedUserId = value;
                          final selected = members.firstWhere((m) => m['id'] == value);
                          selectedUserName = selected['username'];
                        });
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Or enter email address:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      hintText: 'Enter user email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Transfer'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      String? newOwnerId = selectedUserId;
      String? newOwnerName = selectedUserName;

      if (emailController.text.trim().isNotEmpty) {
        final email = emailController.text.trim();
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        
        if (usersSnapshot.docs.isNotEmpty) {
          newOwnerId = usersSnapshot.docs.first.id;
          final userData = usersSnapshot.docs.first.data() as Map<String, dynamic>;
          newOwnerName = userData['username'] ?? 'User';
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User not found with that email'), backgroundColor: Colors.red),
            );
          }
          return;
        }
      }

      if (newOwnerId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a user'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (newOwnerId == currentOwnerId) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User is already the owner'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      try {
        final adminDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentAdminId)
            .get();
        final adminName = (adminDoc.data() as Map<String, dynamic>?)?['username'] ?? 'An admin';
        final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

        await FirebaseFirestore.instance
            .collection('communities')
            .doc(communityId)
            .update({
          'creatorId': newOwnerId,
        });
        
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': newOwnerId,
          'type': 'became_owner',
          'actorId': currentAdminId,
          'actorName': adminName,
          'communityId': communityId,
          'communityName': communityName,
          'timestamp': currentTimestamp,
          'read': false,
        });
        
        if (currentOwnerId != currentAdminId) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': currentOwnerId,
            'type': 'ownership_transferred_away',
            'actorId': currentAdminId,
            'actorName': adminName,
            'newOwnerId': newOwnerId,
            'newOwnerName': newOwnerName,
            'communityId': communityId,
            'communityName': communityName,
            'timestamp': currentTimestamp,
            'read': false,
          });
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ownership transferred from $currentOwnerName to $newOwnerName')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('communities').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        
        final communities = snapshot.data?.docs ?? [];
        if (communities.isEmpty) return const Center(child: Text('No communities found'));
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: communities.length,
          itemBuilder: (context, index) {
            final community = communities[index];
            final data = community.data() as Map<String, dynamic>;
            final members = List<String>.from(data['members'] ?? []);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                leading: const Icon(Icons.group, color: Colors.orange),
                title: Text(data['name'] ?? 'Community', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Members: ${members.length}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _transferOwnership(context, community.id, data['name'] ?? 'Community'),
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('Transfer Ownership'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _deleteCommunity(context, community.id),
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete Community'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        if (data['bannedUsers'] != null && (data['bannedUsers'] as List).isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text('Banned Users:', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ...(data['bannedUsers'] as List).map((bannedUserId) => 
                                FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance.collection('users').doc(bannedUserId).get(),
                                  builder: (context, userSnapshot) {
                                    if (!userSnapshot.hasData) return const SizedBox.shrink();
                                    final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                    final bannedDetails = (data['bannedUsersDetails'] as List?)?.firstWhere(
                                      (b) => b['userId'] == bannedUserId,
                                      orElse: () => {},
                                    );
                                    return ListTile(
                                      leading: const Icon(Icons.block, color: Colors.red),
                                      title: Text(userData['username'] ?? 'User'),
                                      subtitle: Text(bannedDetails?['reason'] ?? 'No reason provided'),
                                      dense: true,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Users Management (Ban and Unban)
class _UsersManagement extends StatefulWidget {
  const _UsersManagement();

  @override
  State<_UsersManagement> createState() => _UsersManagementState();
}

class _UsersManagementState extends State<_UsersManagement> {
  String _selectedTab = 'members';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'members', label: Text('Community Members')),
                    ButtonSegment(value: 'banned', label: Text('Banned Users')),
                  ],
                  selected: {_selectedTab},
                  onSelectionChanged: (Set<String> selection) {
                    setState(() {
                      _selectedTab = selection.first;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _selectedTab == 'members' 
              ? const _CommunityMembersList()
              : const _BannedUsersList(),
        ),
      ],
    );
  }
}

class _CommunityMembersList extends StatelessWidget {
  const _CommunityMembersList();

  Future<void> _banUser(BuildContext context, String userId, String userName, String communityId, String communityName) async {
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
            .doc(communityId)
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
        
        await FirebaseFirestore.instance.collection('communities').doc(communityId).update({
          'bannedUsers': FieldValue.arrayUnion([userId]),
          'bannedUsersDetails': bannedUsersDetails,
          'members': FieldValue.arrayRemove([userId]),
        });
        
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': userId,
          'type': 'banned',
          'communityId': communityId,
          'communityName': communityName,
          'reason': finalReason,
          'timestamp': currentTimestamp,
          'read': false,
        });
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$userName has been banned from $communityName')),
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('communities').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        
        final communities = snapshot.data?.docs ?? [];
        if (communities.isEmpty) return const Center(child: Text('No communities found'));
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: communities.length,
          itemBuilder: (context, index) {
            final community = communities[index];
            final data = community.data() as Map<String, dynamic>;
            final members = List<String>.from(data['members'] ?? []);
            final communityName = data['name'] ?? 'Community';
            
            return ExpansionTile(
              leading: const Icon(Icons.group, color: Colors.orange),
              title: Text(communityName),
              subtitle: Text('${members.length} members'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getUsersData(members),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) return const CircularProgressIndicator();
                      final users = userSnapshot.data!;
                      if (users.isEmpty) return const Text('No members found');
                      return Column(
                        children: users.map((user) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.shade100,
                              child: Text(user['username'][0].toUpperCase(), style: const TextStyle(color: Colors.orange)),
                            ),
                            title: Text(user['username']),
                            subtitle: Text(user['email']),
                            trailing: ElevatedButton.icon(
                              onPressed: () => _banUser(context, user['id'], user['username'], community.id, communityName),
                              icon: const Icon(Icons.block, size: 16),
                              label: const Text('Ban'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        )).toList(),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getUsersData(List<String> userIds) async {
    List<Map<String, dynamic>> users = [];
    for (String id in userIds) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        users.add({'id': id, 'username': data['username'] ?? 'User', 'email': data['email'] ?? ''});
      }
    }
    return users;
  }
}

class _BannedUsersList extends StatelessWidget {
  const _BannedUsersList();

  Future<void> _unbanUser(BuildContext context, String userId, String userName, String communityId, String communityName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unban User'),
        content: Text('Are you sure you want to unban $userName from "$communityName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
        print('✅ Unban notification sent to $userName');
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$userName has been unbanned from $communityName')),
          );
        }
      } catch (e) {
        print('Error unbanning: $e');
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('communities').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        
        final communities = snapshot.data?.docs ?? [];
        
        final communitiesWithBanned = communities.where((community) {
          final data = community.data() as Map<String, dynamic>;
          final bannedUsers = List<String>.from(data['bannedUsers'] ?? []);
          return bannedUsers.isNotEmpty;
        }).toList();
        
        if (communitiesWithBanned.isEmpty) return const Center(child: Text('No banned users found'));
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: communitiesWithBanned.length,
          itemBuilder: (context, index) {
            final community = communitiesWithBanned[index];
            final data = community.data() as Map<String, dynamic>;
            final bannedUsers = List<String>.from(data['bannedUsers'] ?? []);
            final communityName = data['name'] ?? 'Community';
            
            return ExpansionTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: Text(communityName),
              subtitle: Text('${bannedUsers.length} banned users'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getUsersData(bannedUsers),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) return const CircularProgressIndicator();
                      final users = userSnapshot.data!;
                      if (users.isEmpty) return const Text('No banned users found');
                      return Column(
                        children: users.map((user) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.shade100,
                              child: Text(user['username'][0].toUpperCase(), style: const TextStyle(color: Colors.red)),
                            ),
                            title: Text(user['username']),
                            subtitle: Text(user['email']),
                            trailing: ElevatedButton.icon(
                              onPressed: () => _unbanUser(context, user['id'], user['username'], community.id, communityName),
                              icon: const Icon(Icons.check_circle, size: 16),
                              label: const Text('Unban'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        )).toList(),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getUsersData(List<String> userIds) async {
    List<Map<String, dynamic>> users = [];
    for (String id in userIds) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        users.add({'id': id, 'username': data['username'] ?? 'User', 'email': data['email'] ?? ''});
      }
    }
    return users;
  }
}

// Hobbies Management (Super Admin only)
class _HobbiesManagement extends StatefulWidget {
  const _HobbiesManagement();

  @override
  State<_HobbiesManagement> createState() => _HobbiesManagementState();
}

class _HobbiesManagementState extends State<_HobbiesManagement> {
  List<String> _hobbies = [];
  final TextEditingController _newHobbyController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHobbies();
  }

  Future<void> _loadHobbies() async {
    setState(() => _isLoading = true);
    try {
      final hobbiesDoc = await FirebaseFirestore.instance.collection('settings').doc('hobbies').get();
      if (hobbiesDoc.exists) {
        final data = hobbiesDoc.data() as Map<String, dynamic>;
        _hobbies = List<String>.from(data['list'] ?? []);
      } else {
        _hobbies = const [
          'Gaming', 'Anime', 'Movies', 'Science', 'Technology',
          'Music', 'Art', 'Sports', 'Cooking', 'Photography',
          'Reading', 'Travel'
        ];
        await _saveHobbies();
      }
    } catch (e) {
      print('Error loading hobbies: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveHobbies() async {
    await FirebaseFirestore.instance.collection('settings').doc('hobbies').set({
      'list': _hobbies,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _addHobby() {
    final newHobby = _newHobbyController.text.trim();
    if (newHobby.isNotEmpty && !_hobbies.contains(newHobby)) {
      setState(() {
        _hobbies.add(newHobby);
        _newHobbyController.clear();
      });
      _saveHobbies();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hobby "$newHobby" added')));
    } else if (newHobby.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a hobby name')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hobby "$newHobby" already exists')),
      );
    }
  }

  Future<void> _deleteHobby(String hobby) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Hobby'),
        content: Text('Deleting "$hobby" will also delete all communities with this hobby. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final communities = await FirebaseFirestore.instance.collection('communities').where('hobby', isEqualTo: hobby).get();
        for (var community in communities.docs) {
          final posts = await FirebaseFirestore.instance.collection('posts').where('communityId', isEqualTo: community.id).get();
          for (var post in posts.docs) await post.reference.delete();
          await community.reference.delete();
        }
        setState(() => _hobbies.remove(hobby));
        await _saveHobbies();
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hobby "$hobby" deleted')));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newHobbyController,
                  decoration: const InputDecoration(
                    hintText: 'Enter new hobby',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.add),
                  ),
                  onSubmitted: (_) => _addHobby(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addHobby,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _hobbies.length,
            itemBuilder: (context, index) {
              final hobby = _hobbies[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.favorite, color: Colors.orange),
                  title: Text(hobby),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteHobby(hobby),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Reports Management - UPDATED with post author info and delete confirmation
class _ReportsManagement extends StatelessWidget {
  const _ReportsManagement();

  Future<void> _deletePost(BuildContext context, String postId, String reportId, String postAuthorId, String postTitle) async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this post?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Post Details:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text('Title: $postTitle', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
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

    if (confirmed != true) return;

    try {
      // Send notification to post author before deleting
      try {
        final adminUser = FirebaseAuth.instance.currentUser;
        String adminName = 'A super admin';
        if (adminUser != null) {
          final adminDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(adminUser.uid)
              .get();
          if (adminDoc.exists) {
            adminName = (adminDoc.data() as Map<String, dynamic>)['username'] ?? 'A super admin';
          }
        }

        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': postAuthorId,
          'type': 'post_deleted_by_admin',
          'actorId': adminUser?.uid,
          'actorName': adminName,
          'postTitle': postTitle,
          'reason': 'Violation of community guidelines',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'read': false,
        });
        print('✅ Deletion notification sent to post author');
      } catch (e) {
        print('Error sending deletion notification: $e');
      }

      // Delete the post
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      
      // Update report status
      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted and author notified')),
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

  Future<void> _dismissReport(BuildContext context, String reportId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Dismiss Report'),
        content: const Text('Are you sure you want to dismiss this report? The post will remain.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
          'status': 'dismissed',
          'resolvedAt': FieldValue.serverTimestamp(),
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report dismissed')),
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final reports = snapshot.data?.docs ?? [];
        if (reports.isEmpty) {
          return const Center(child: Text('No pending reports'));
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            final data = report.data() as Map<String, dynamic>;
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(data['postId'])
                  .get(),
              builder: (context, postSnapshot) {
                String authorName = 'Unknown';
                String authorId = '';
                
                if (postSnapshot.hasData && postSnapshot.data!.exists) {
                  final postData = postSnapshot.data!.data() as Map<String, dynamic>;
                  authorId = postData['authorId'] ?? '';
                  authorName = postData['authorName'] ?? 'Unknown';
                }
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Report header with icon
                        Row(
                          children: [
                            const Icon(Icons.flag, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data['postTitle'] ?? 'Post',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Post Author Info
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text(
                                'Posted by: ',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              Text(
                                authorName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Reporter Info
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text('Reported by: ${data['reporterName'] ?? 'User'}'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        // Reason
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning, size: 14, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Reason: ${data['reason'] ?? 'No reason'}'),
                            ),
                          ],
                        ),
                        
                        // Timestamp
                        if (data['timestamp'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _formatTime((data['timestamp'] as Timestamp).toDate()),
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                            ),
                          ),
                        
                        const SizedBox(height: 16),
                        
                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _deletePost(
                                  context, 
                                  data['postId'], 
                                  report.id,
                                  authorId,
                                  data['postTitle'] ?? 'Post'
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Delete Post'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _dismissReport(context, report.id),
                                child: const Text('Dismiss'),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minutes ago';
    return 'Just now';
  }
}