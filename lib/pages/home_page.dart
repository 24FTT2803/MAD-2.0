import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hobbee_app/services/auth_service.dart';
import 'package:hobbee_app/pages/communities_page.dart';
import 'package:hobbee_app/pages/profile_page.dart';
import 'package:hobbee_app/pages/create_community_page.dart';
import 'package:hobbee_app/pages/create_post_page.dart';
import 'package:hobbee_app/pages/hobby_communities_page.dart';
import 'package:hobbee_app/pages/community_detail_page.dart';
import 'package:hobbee_app/pages/comment_page.dart';
import 'package:hobbee_app/pages/search_users_page.dart';
import 'package:hobbee_app/pages/notifications_page.dart';
import 'package:hobbee_app/widgets/hobby_chip.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeContent(),
    const SearchDiscoverPage(),
    const MyActivitiesPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search_rounded),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history_rounded),
              label: 'Activities',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  List<String> hobbies = [];
  bool _loadingHobbies = true;

  @override
  void initState() {
    super.initState();
    _loadHobbies();
  }

  Future<void> _loadHobbies() async {
    try {
      // First, try to get the hobbies document
      final hobbiesDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('hobbies')
          .get();
      
      if (hobbiesDoc.exists) {
        final data = hobbiesDoc.data() as Map<String, dynamic>;
        final hobbiesList = List<String>.from(data['list'] ?? []);
        
        if (hobbiesList.isNotEmpty) {
          setState(() {
            hobbies = hobbiesList;
            _loadingHobbies = false;
          });
          return;
        }
      }
      
      // If no hobbies found, use default list
      final defaultHobbies = const [
        'Gaming', 'Anime', 'Movies', 'Science', 'Technology',
        'Music', 'Art', 'Sports', 'Cooking', 'Photography',
        'Reading', 'Travel'
      ];
      
      setState(() {
        hobbies = defaultHobbies;
        _loadingHobbies = false;
      });
      
      // Try to save to Firestore (but don't wait for it)
      try {
        await FirebaseFirestore.instance.collection('settings').doc('hobbies').set({
          'list': defaultHobbies,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Created hobbies document with default values');
      } catch (e) {
        print('Could not save hobbies to Firestore: $e');
      }
      
    } catch (e) {
      print('Error loading hobbies: $e');
      // Always fall back to default hobbies
      setState(() {
        hobbies = const [
          'Gaming', 'Anime', 'Movies', 'Science', 'Technology',
          'Music', 'Art', 'Sports', 'Cooking', 'Photography',
          'Reading', 'Travel'
        ];
        _loadingHobbies = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while fetching hobbies
    if (_loadingHobbies) {
      return const Scaffold(
        backgroundColor: Colors.grey,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
              SizedBox(height: 16),
              Text(
                'Loading Hobbies...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Hobbee',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.orange.shade800,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.orange.shade800),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchUsersPage()),
              );
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: currentUserId)
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_outlined, color: Colors.orange.shade800),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsPage()),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Discover Communities',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find your tribe and connect through shared hobbies',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.post_add_rounded,
                        label: 'Create Post',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreatePostPage()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.group_add_rounded,
                        label: 'Create Community',
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateCommunityPage()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Popular Hobbies',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _showAllHobbiesDialog(context);
                  },
                  child: Text(
                    'See All',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: hobbies.length,
              itemBuilder: (context, index) {
                final hobby = hobbies[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: HobbyChip(
                    hobby: hobby,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HobbyCommunitiesPage(hobby: hobby),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Featured Communities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CommunitiesPage()),
                    );
                  },
                  child: Text(
                    'View All',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('communities')
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No communities yet. Create one!'),
                  );
                }
                
                final allCommunities = snapshot.data!.docs;
                final communities = allCommunities.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final bannedUsers = List<String>.from(data['bannedUsers'] ?? []);
                  return !bannedUsers.contains(currentUserId);
                }).toList();
                
                if (communities.isEmpty) {
                  return const Center(child: Text('No communities available'));
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: communities.length,
                  itemBuilder: (context, index) {
                    final doc = communities[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final members = List<String>.from(data['members'] ?? []);
                    final creatorId = data['creatorId'];
                    final isJoined = members.contains(currentUserId);
                    final communityImage = data['communityImage'];
                    
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(creatorId).get(),
                      builder: (context, creatorSnapshot) {
                        String creatorName = 'Unknown';
                        String? creatorAvatar;
                        
                        if (creatorSnapshot.hasData && creatorSnapshot.data!.exists) {
                          final creatorData = creatorSnapshot.data!.data() as Map<String, dynamic>;
                          creatorName = creatorData['username'] ?? 'Unknown';
                          creatorAvatar = creatorData['profileImage'];
                        }
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade100),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CommunityDetailPage(
                                    communityId: doc.id,
                                    communityName: data['name'] ?? 'Community',
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Community Image
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: communityImage == null
                                          ? const LinearGradient(
                                              colors: [Colors.orange, Colors.deepOrange],
                                            )
                                          : null,
                                    ),
                                    child: communityImage != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              communityImage,
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    gradient: const LinearGradient(
                                                      colors: [Colors.orange, Colors.deepOrange],
                                                    ),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: const Icon(
                                                    Icons.group,
                                                    color: Colors.white,
                                                    size: 28,
                                                  ),
                                                );
                                              },
                                            ),
                                          )
                                        : const Icon(
                                            Icons.group,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['name'] ?? 'Community',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          data['description'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 8,
                                              backgroundImage: creatorAvatar != null
                                                  ? NetworkImage(creatorAvatar)
                                                  : null,
                                              backgroundColor: Colors.orange.shade100,
                                              child: creatorAvatar == null
                                                  ? Icon(Icons.person, size: 8, color: Colors.orange.shade700)
                                                  : null,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              creatorName,
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 10,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.people_outline,
                                              size: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${members.length}',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 11,
                                              ),
                                            ),
                                            if (isJoined) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  'Joined',
                                                  style: TextStyle(
                                                    color: Colors.green.shade700,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAllHobbiesDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All Hobbies',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: hobbies.map((hobby) => FilterChip(
                label: Text(hobby),
                onSelected: (selected) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HobbyCommunitiesPage(hobby: hobby),
                    ),
                  );
                },
                backgroundColor: Colors.grey.shade100,
                selectedColor: Colors.orange.shade100,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// MyActivitiesPage remains the same as before
class MyActivitiesPage extends StatelessWidget {
  const MyActivitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'My Activities',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.orange.shade800,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('activities')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final activities = snapshot.data?.docs ?? [];
          
          if (activities.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No activities yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your activities will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              final data = activity.data() as Map<String, dynamic>;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade100),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getActivityColor(data['type']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getActivityIcon(data['type']),
                      color: _getActivityColor(data['type']),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    _getActivityMessage(data),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _formatTime((data['timestamp'] as Timestamp?)?.toDate()),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                  onTap: () {
                    if (data['communityId'] != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommunityDetailPage(
                            communityId: data['communityId'],
                            communityName: data['communityName'] ?? 'Community',
                          ),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  IconData _getActivityIcon(String? type) {
    switch (type) {
      case 'created_community':
        return Icons.group_add;
      case 'joined_community':
        return Icons.person_add;
      case 'left_community':
        return Icons.person_remove;
      case 'created_post':
        return Icons.post_add;
      case 'liked_post':
        return Icons.thumb_up;
      case 'disliked_post':
        return Icons.thumb_down;
      case 'commented':
        return Icons.comment;
      default:
        return Icons.notifications;
    }
  }
  
  Color _getActivityColor(String? type) {
    switch (type) {
      case 'created_community':
        return Colors.green;
      case 'joined_community':
        return Colors.blue;
      case 'left_community':
        return Colors.orange;
      case 'created_post':
        return Colors.orange;
      case 'liked_post':
        return Colors.blue;
      case 'disliked_post':
        return Colors.red;
      case 'commented':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
  
  String _getActivityMessage(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'created_community':
        return 'Created community "${data['communityName']}"';
      case 'joined_community':
        return 'Joined community "${data['communityName']}"';
      case 'left_community':
        return 'Left community "${data['communityName']}"';
      case 'created_post':
        return 'Posted "${data['postTitle']}" in ${data['communityName']}';
      case 'liked_post':
        return 'Liked "${data['postTitle']}" in ${data['communityName']}';
      case 'disliked_post':
        return 'Disliked "${data['postTitle']}" in ${data['communityName']}';
      case 'commented':
        return 'Commented on "${data['postTitle']}" in ${data['communityName']}';
      default:
        return 'Activity';
    }
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

// SearchDiscoverPage remains the same as before
class SearchDiscoverPage extends StatefulWidget {
  const SearchDiscoverPage({super.key});

  @override
  State<SearchDiscoverPage> createState() => _SearchDiscoverPageState();
}

class _SearchDiscoverPageState extends State<SearchDiscoverPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedHobby = 'All';
  List<String> _hobbies = ['All'];
  bool _loadingHobbies = true;

  @override
  void initState() {
    super.initState();
    _loadHobbies();
  }

  Future<void> _loadHobbies() async {
    try {
      final hobbiesDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('hobbies')
          .get();
      
      List<String> hobbyList = [];
      
      if (hobbiesDoc.exists) {
        final data = hobbiesDoc.data() as Map<String, dynamic>;
        hobbyList = List<String>.from(data['list'] ?? []);
      }
      
      if (hobbyList.isEmpty) {
        hobbyList = const [
          'Gaming', 'Anime', 'Movies', 'Science', 'Technology',
          'Music', 'Art', 'Sports', 'Cooking', 'Photography',
          'Reading', 'Travel'
        ];
      }
      
      setState(() {
        _hobbies = ['All', ...hobbyList];
        _loadingHobbies = false;
      });
    } catch (e) {
      print('Error loading hobbies for discover: $e');
      setState(() {
        _hobbies = const [
          'All', 'Gaming', 'Anime', 'Movies', 'Science', 'Technology',
          'Music', 'Art', 'Sports', 'Cooking', 'Photography', 'Reading', 'Travel'
        ];
        _loadingHobbies = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingHobbies) {
      return const Scaffold(
        backgroundColor: Colors.grey,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ),
      );
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Discover',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.orange.shade800,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search communities...',
                      prefixIcon: const Icon(Icons.search, color: Colors.orange),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _hobbies.length,
                  itemBuilder: (context, index) {
                    final hobby = _hobbies[index];
                    final isSelected = _selectedHobby == hobby;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(hobby),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedHobby = selected ? hobby : 'All';
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: Colors.orange.shade100,
                        checkmarkColor: Colors.orange,
                        side: BorderSide(
                          color: isSelected ? Colors.orange : Colors.grey.shade300,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: _buildCommunityList(currentUserId),
    );
  }

  Widget _buildCommunityList(String? currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _selectedHobby == 'All'
          ? FirebaseFirestore.instance.collection('communities').snapshots()
          : FirebaseFirestore.instance
              .collection('communities')
              .where('hobby', isEqualTo: _selectedHobby)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var allCommunities = snapshot.data?.docs ?? [];
        
        var communities = allCommunities.where((community) {
          final data = community.data() as Map<String, dynamic>;
          final bannedUsers = List<String>.from(data['bannedUsers'] ?? []);
          return !bannedUsers.contains(currentUserId);
        }).toList();

        if (_searchQuery.isNotEmpty) {
          communities = communities.where((community) {
            final data = community.data() as Map<String, dynamic>;
            final name = data['name']?.toLowerCase() ?? '';
            final description = data['description']?.toLowerCase() ?? '';
            return name.contains(_searchQuery) || description.contains(_searchQuery);
          }).toList();
        }

        if (communities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No communities found matching "$_searchQuery"'
                      : 'No communities found',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: communities.length,
          itemBuilder: (context, index) {
            final community = communities[index];
            final data = community.data() as Map<String, dynamic>;
            final members = List<String>.from(data['members'] ?? []);
            final creatorId = data['creatorId'];
            final isJoined = members.contains(currentUserId);
            final communityImage = data['communityImage'];
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(creatorId).get(),
              builder: (context, creatorSnapshot) {
                String creatorName = 'Unknown';
                String? creatorAvatar;
                
                if (creatorSnapshot.hasData && creatorSnapshot.data!.exists) {
                  final creatorData = creatorSnapshot.data!.data() as Map<String, dynamic>;
                  creatorName = creatorData['username'] ?? 'Unknown';
                  creatorAvatar = creatorData['profileImage'];
                }
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade100),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommunityDetailPage(
                            communityId: community.id,
                            communityName: data['name'] ?? 'Community',
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Community Image
                          Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: communityImage == null
                                  ? const LinearGradient(
                                      colors: [Colors.orange, Colors.deepOrange],
                                    )
                                  : null,
                            ),
                            child: communityImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      communityImage,
                                      width: 55,
                                      height: 55,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Colors.orange, Colors.deepOrange],
                                            ),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Icon(
                                            Icons.group,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : const Icon(
                                    Icons.group,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['name'] ?? 'Community',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundImage: creatorAvatar != null
                                          ? NetworkImage(creatorAvatar)
                                          : null,
                                      backgroundColor: Colors.orange.shade100,
                                      child: creatorAvatar == null
                                          ? Icon(Icons.person, size: 10, color: Colors.orange.shade700)
                                          : null,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      creatorName,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        data['hobby'] ?? 'General',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.people_outline,
                                      size: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${members.length}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (isJoined) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'Joined',
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                          ),
                        ],
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