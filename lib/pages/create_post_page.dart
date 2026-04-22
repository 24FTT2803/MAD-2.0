import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hobbee_app/services/appwrite_service.dart';

class CreatePostPage extends StatefulWidget {
  final String? communityId;
  
  const CreatePostPage({super.key, this.communityId});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  String? _selectedCommunityId;
  String? _selectedCommunityName;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isLoading = false;
  bool _isUploading = false;
  final AppwriteService _appwriteService = AppwriteService();
  List<String> _tags = [];
  List<Map<String, dynamic>> _memberCommunities = [];

  @override
  void initState() {
    super.initState();
    _initializeAppwrite();
    _loadMemberCommunities();
  }

  Future<void> _initializeAppwrite() async {
    await _appwriteService.initialize();
  }

  Future<void> _loadMemberCommunities() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final communitiesSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .where('members', arrayContains: currentUser.uid)
        .get();

    final List<Map<String, dynamic>> communities = [];
    for (var doc in communitiesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      communities.add({
        'id': doc.id,
        'name': data['name'] ?? 'Community',
      });
    }
    
    setState(() {
      _memberCommunities = communities;
      
      // If a specific communityId was provided and user is a member, select it
      if (widget.communityId != null && 
          _memberCommunities.any((c) => c['id'] == widget.communityId)) {
        _selectedCommunityId = widget.communityId;
        _selectedCommunityName = _memberCommunities.firstWhere(
          (c) => c['id'] == widget.communityId
        )['name'];
      }
    });
  }

  void _addTag() {
    String tag = _tagsController.text.trim();
    
    if (!tag.startsWith('#')) {
      tag = '#$tag';
    }
    
    tag = tag.replaceAll(' ', '');
    
    if (tag.length >= 2 && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagsController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Create Post',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.orange.shade800,
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _memberCommunities.isEmpty && !_isLoading
          ? Center(
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
                      Icons.group_off,
                      size: 50,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No Communities Joined',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You need to join a community before creating a post',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Community Selection Card
                  Container(
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
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Select Community',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: DropdownButtonFormField<String>(
                            value: _selectedCommunityId,
                            hint: const Text('Choose a community'),
                            isExpanded: true,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            items: _memberCommunities.map<DropdownMenuItem<String>>((community) {
                              return DropdownMenuItem<String>(
                                value: community['id'] as String,
                                child: Row(
                                  children: [
                                    const Icon(Icons.group, size: 18, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Text(community['name'] as String),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCommunityId = value;
                                final selected = _memberCommunities.firstWhere(
                                  (c) => c['id'] == value
                                );
                                _selectedCommunityName = selected['name'] as String;
                              });
                            },
                            validator: (value) {
                              if (value == null) return 'Please select a community';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title Card
                  Container(
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
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Title',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              hintText: 'What\'s on your mind?',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Content Card
                  Container(
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
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Content',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextFormField(
                            controller: _contentController,
                            decoration: InputDecoration(
                              hintText: 'Write your post here...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            maxLines: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Tags Card
                  Container(
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
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Tags (Optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _tagsController,
                                      decoration: InputDecoration(
                                        hintText: 'Add tags like #anime, #gaming...',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      ),
                                      onSubmitted: (_) => _addTag(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.add, color: Colors.white),
                                      onPressed: _addTag,
                                    ),
                                  ),
                                ],
                              ),
                              if (_tags.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _tags.map((tag) => Chip(
                                      label: Text(tag),
                                      onDeleted: () => _removeTag(tag),
                                      deleteIcon: const Icon(Icons.close, size: 16),
                                      backgroundColor: Colors.orange.shade50,
                                      side: BorderSide.none,
                                    )).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Image Card
                  Container(
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
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Add Image',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey.shade50,
                              ),
                              child: _hasImage()
                                  ? Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: _getImagePreview(),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                              onPressed: () {
                                                setState(() {
                                                  _selectedImage = null;
                                                  _selectedImageBytes = null;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                                        const SizedBox(height: 8),
                                        Text('Tap to add image', style: TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Post Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _isUploading) ? null : _createPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: (_isLoading || _isUploading)
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Post',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  bool _hasImage() {
    return (kIsWeb && _selectedImageBytes != null) || (!kIsWeb && _selectedImage != null);
  }
  
  Widget _getImagePreview() {
    if (kIsWeb && _selectedImageBytes != null) {
      return Image.memory(
        _selectedImageBytes!,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
      );
    } else if (!kIsWeb && _selectedImage != null) {
      return Image.file(
        _selectedImage!,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
      );
    } else {
      return const SizedBox.shrink();
    }
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImage = null;
        });
      } else {
        setState(() {
          _selectedImage = File(image.path);
          _selectedImageBytes = null;
        });
      }
    }
  }
  
  Future<void> _createPost() async {
    if (_selectedCommunityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a community')),
      );
      return;
    }
    
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter content')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _isUploading = true;
    });
    
    String? imageUrl;
    
    try {
      if (_hasImage()) {
        if (kIsWeb && _selectedImageBytes != null) {
          imageUrl = await _appwriteService.uploadPostImageBytes(_selectedImageBytes!);
        } else if (!kIsWeb && _selectedImage != null) {
          imageUrl = await _appwriteService.uploadPostImage(_selectedImage!);
        }
      }
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      String authorName = currentUser.email?.split('@').first ?? 'User';
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        authorName = userData['username'] ?? authorName;
      }
      
      final postData = {
        'communityId': _selectedCommunityId,
        'authorId': currentUser.uid,
        'authorName': authorName,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'imageUrl': imageUrl,
        'likes': <String>[],
        'dislikes': <String>[],
        'commentCount': 0,
        'tags': _tags,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      await FirebaseFirestore.instance.collection('posts').add(postData);
      
      await FirebaseFirestore.instance.collection('activities').add({
        'userId': currentUser.uid,
        'type': 'created_post',
        'postTitle': _titleController.text.trim(),
        'communityId': _selectedCommunityId,
        'communityName': _selectedCommunityName,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }
}