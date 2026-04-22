import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hobbee_app/pages/login_page.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hobbee_app/services/auth_service.dart';
import 'package:hobbee_app/services/appwrite_service.dart';
import 'package:hobbee_app/pages/admin_panel_page.dart';
import 'package:hobbee_app/pages/community_detail_page.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  
  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final AppwriteService _appwriteService = AppwriteService();
  bool _isUploading = false;
  String? _userName;
  String? _userEmail;
  String? _userRole;
  String? _profileImage;
  List<String> _userHobbies = [];
  bool _isLoading = true;
  DateTime? _lastUsernameChange;
  bool _canChangeUsername = true;
  int _daysUntilCanChange = 0;
  bool _isOwnProfile = true;
  List<Map<String, dynamic>> _recentActivities = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _isOwnProfile = widget.userId == null;
    _tabController = TabController(length: 2, vsync: this);
    _initializeAppwrite();
    _loadUserData();
    _loadRecentActivities();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeAppwrite() async {
    await _appwriteService.initialize();
  }

  Future<void> _loadRecentActivities() async {
    final userId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final activitiesSnapshot = await FirebaseFirestore.instance
        .collection('activities')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();

    final List<Map<String, dynamic>> activities = [];
    for (var doc in activitiesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      activities.add({
        'id': doc.id,
        ...data,
      });
    }
    
    setState(() {
      _recentActivities = activities;
    });
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    try {
      final userId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        _userName = data['username'] ?? 'User';
        _userEmail = data['email'];
        _userRole = data['role'] ?? 'user';
        _profileImage = data['profileImage'];
        _userHobbies = List<String>.from(data['hobbies'] ?? []);
        _lastUsernameChange = (data['lastUsernameChange'] as Timestamp?)?.toDate();
        
        if (_isOwnProfile && _lastUsernameChange != null) {
          final daysSinceLastChange = DateTime.now().difference(_lastUsernameChange!).inDays;
          if (daysSinceLastChange < 7) {
            _canChangeUsername = false;
            _daysUntilCanChange = 7 - daysSinceLastChange;
          } else {
            _canChangeUsername = true;
          }
        }
      } else if (_isOwnProfile) {
        _userName = 'User';
        _userRole = 'user';
        _userHobbies = [];
        _canChangeUsername = true;
        
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'username': _userName,
          'email': _userEmail,
          'role': _userRole,
          'hobbies': _userHobbies,
          'profileImage': null,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUsernameChange': null,
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadUserData();
                await _loadRecentActivities();
              },
              child: CustomScrollView(
                slivers: [
                  // Custom App Bar with Gradient Background
                  SliverAppBar(
                    expandedHeight: 280,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.orange, Colors.deepOrange],
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              // Profile Image with Edit Button
                              Stack(
                                children: [
                                  GestureDetector(
                                    onTap: _isOwnProfile && !_isUploading ? () => _updateProfilePicture() : null,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 60,
                                        backgroundColor: Colors.white,
                                        backgroundImage: _profileImage != null
                                            ? NetworkImage(_profileImage!)
                                            : null,
                                        child: _profileImage == null
                                            ? const Icon(Icons.person, size: 60, color: Colors.orange)
                                            : null,
                                      ),
                                    ),
                                  ),
                                  if (_isOwnProfile)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          size: 20,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  if (_isUploading)
                                    Positioned(
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _userName ?? 'User',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _userRole?.toUpperCase() ?? 'USER',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      if (_isOwnProfile && (_userRole == 'admin' || _userRole == 'superadmin'))
                        IconButton(
                          icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminPanelPage(userRole: _userRole!),
                              ),
                            );
                          },
                        ),
                      if (_isOwnProfile)
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white),
                          onPressed: () => _showLogoutConfirmation(context, authService),
                        ),
                    ],
                  ),
                  
                  // Profile Content
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        
                        // Stats Cards Row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              _buildStatCard(
                                icon: Icons.favorite,
                                label: 'Hobbies',
                                value: '${_userHobbies.length}',
                                color: Colors.red,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                icon: Icons.history,
                                label: 'Activities',
                                value: '${_recentActivities.length}',
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                icon: Icons.email,
                                label: 'Email',
                                value: _userEmail?.split('@').first ?? '',
                                color: Colors.green,
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Tab Bar
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
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
                          child: TabBar(
                            controller: _tabController,
                            labelColor: Colors.orange,
                            unselectedLabelColor: Colors.grey,
                            indicator: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            tabs: const [
                              Tab(text: 'About', icon: Icon(Icons.person_outline)),
                              Tab(text: 'Activities', icon: Icon(Icons.history)),
                            ],
                          ),
                        ),
                        
                        // Tab Bar Views
                        SizedBox(
                          height: 500,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildAboutTab(),
                              _buildActivitiesTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Email Card
          _buildInfoCard(
            icon: Icons.email_outlined,
            title: 'Email Address',
            value: _userEmail ?? 'No email',
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          
          // Username Card
          _buildEditableCard(
            icon: Icons.person_outline,
            title: 'Username',
            value: _userName ?? 'User',
            color: Colors.orange,
            canEdit: _isOwnProfile,
            isLocked: !_canChangeUsername,
            lockMessage: 'Can change in $_daysUntilCanChange days',
            onEdit: () => _showEditUsernameDialog(),
          ),
          const SizedBox(height: 12),
          
          // Hobbies Card
          Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.favorite, color: Colors.red, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Hobbies & Interests',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _userHobbies.isEmpty
                      ? Center(
                          child: Column(
                            children: [
                              Icon(Icons.sentiment_dissatisfied, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                'No hobbies selected yet',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                              if (_isOwnProfile)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/onboarding');
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Hobbies'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _userHobbies.map((hobby) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.orange.shade400, Colors.orange.shade600],
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              hobby,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          )).toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesTab() {
    if (_recentActivities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No activities yet',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(
              'Your activities will appear here',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentActivities.length,
      itemBuilder: (context, index) {
        final activity = _recentActivities[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getActivityColor(activity['type']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getActivityIcon(activity['type']),
                color: _getActivityColor(activity['type']),
                size: 22,
              ),
            ),
            title: Text(
              _getActivityMessage(activity),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              _formatTime((activity['timestamp'] as Timestamp?)?.toDate()),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
            onTap: () {
              if (activity['communityId'] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityDetailPage(
                      communityId: activity['communityId'],
                      communityName: activity['communityName'] ?? 'Community',
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
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
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEditableCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool canEdit,
    required bool isLocked,
    required String lockMessage,
    required VoidCallback onEdit,
  }) {
    return Container(
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
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            subtitle: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: canEdit
                ? TextButton.icon(
                    onPressed: isLocked ? null : onEdit,
                    icon: Icon(Icons.edit, size: 16, color: isLocked ? Colors.grey : color),
                    label: Text(
                      isLocked ? 'Locked' : 'Edit',
                      style: TextStyle(color: isLocked ? Colors.grey : color),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                    ),
                  )
                : null,
          ),
          if (isLocked && canEdit)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 16),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    lockMessage,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
        ],
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

  Future<void> _updateProfilePicture() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (image == null || currentUser == null) return;
    
    setState(() => _isUploading = true);
    
    try {
      String? imageUrl;
      
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        imageUrl = await _appwriteService.uploadPostImageBytes(bytes);
      } else {
        imageUrl = await _appwriteService.uploadPostImage(File(image.path));
      }
      
      if (imageUrl != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
          'profileImage': imageUrl,
        }, SetOptions(merge: true));
        
        setState(() => _profileImage = imageUrl);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated!')),
          );
        }
      }
    } catch (e) {
      print('Error updating profile picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _showEditUsernameDialog() async {
    final TextEditingController controller = TextEditingController(text: _userName);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New Username',
            border: OutlineInputBorder(),
            hintText: 'Enter new username',
          ),
          autofocus: true,
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (result == true && controller.text.trim().isNotEmpty) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      setState(() => _isLoading = true);
      
      try {
        final newUsername = controller.text.trim();
        final now = DateTime.now();
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
          'username': newUsername,
          'lastUsernameChange': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        
        setState(() {
          _userName = newUsername;
          _lastUsernameChange = now;
          _canChangeUsername = false;
          _daysUntilCanChange = 7;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username updated! You can change again in 7 days.')),
          );
          await _loadUserData();
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

  void _showLogoutConfirmation(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await authService.signOut();
              Navigator.pop(context);
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (_) => const LoginPage()), 
                  (Route<dynamic> route) => false
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}