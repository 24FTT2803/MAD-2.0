import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hobbee_app/services/appwrite_service.dart';

class CreateCommunityPage extends StatefulWidget {
  const CreateCommunityPage({super.key});

  @override
  State<CreateCommunityPage> createState() => _CreateCommunityPageState();
}

class _CreateCommunityPageState extends State<CreateCommunityPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedHobby;
  bool _isLoading = false;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isUploading = false;
  final AppwriteService _appwriteService = AppwriteService();
  List<String> _hobbies = [];

  @override
  void initState() {
    super.initState();
    _initializeAppwrite();
    _loadHobbies();
  }

  Future<void> _initializeAppwrite() async {
    await _appwriteService.initialize();
  }

  Future<void> _loadHobbies() async {
    try {
      final hobbiesDoc = await FirebaseFirestore.instance.collection('settings').doc('hobbies').get();
      if (hobbiesDoc.exists) {
        final data = hobbiesDoc.data() as Map<String, dynamic>;
        _hobbies = List<String>.from(data['list'] ?? []);
      } else {
        // Default hobbies
        _hobbies = [
          'Gaming', 'Anime', 'Movies', 'Science', 'Technology',
          'Music', 'Art', 'Sports', 'Cooking', 'Photography',
          'Reading', 'Travel'
        ];
      }
      setState(() {});
    } catch (e) {
      print('Error loading hobbies: $e');
      // Fallback to default hobbies
      _hobbies = [
        'Gaming', 'Anime', 'Movies', 'Science', 'Technology',
        'Music', 'Art', 'Sports', 'Cooking', 'Photography',
        'Reading', 'Travel'
      ];
      setState(() {});
    }
  }

  bool _hasImage() {
    return (kIsWeb && _selectedImageBytes != null) || (!kIsWeb && _selectedImage != null);
  }

  Widget _getImagePreview() {
    if (kIsWeb && _selectedImageBytes != null) {
      return Image.memory(
        _selectedImageBytes!,
        width: double.infinity,
        height: 150,
        fit: BoxFit.cover,
      );
    } else if (!kIsWeb && _selectedImage != null) {
      return Image.file(
        _selectedImage!,
        width: double.infinity,
        height: 150,
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

  Future<void> _createCommunity() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          String? imageUrl;
          
          if (_hasImage()) {
            setState(() => _isUploading = true);
            if (kIsWeb && _selectedImageBytes != null) {
              imageUrl = await _appwriteService.uploadPostImageBytes(_selectedImageBytes!);
            } else if (!kIsWeb && _selectedImage != null) {
              imageUrl = await _appwriteService.uploadPostImage(_selectedImage!);
            }
          }
          
          final communityRef = await FirebaseFirestore.instance.collection('communities').add({
            'name': _nameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'hobby': _selectedHobby,
            'members': [user.uid],
            'bannedUsers': [],
            'bannedUsersDetails': [],
            'creatorId': user.uid,
            'memberCount': 1,
            'communityImage': imageUrl,
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          await FirebaseFirestore.instance.collection('activities').add({
            'userId': user.uid,
            'type': 'created_community',
            'communityId': communityRef.id,
            'communityName': _nameController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Community created successfully!')),
            );
            Navigator.pop(context);
          }
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Create Community',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Community Image Card
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
                        'Community Image',
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
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.grey.shade50,
                          ),
                          child: _hasImage()
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
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
                                    Icon(
                                      Icons.add_photo_alternate,
                                      size: 40,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to add community image',
                                      style: TextStyle(color: Colors.grey.shade500),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Recommended: Square image, 500x500px',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Community Name Card
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
                        'Community Name',
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
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Enter community name',
                          prefixIcon: Icon(Icons.group, color: Colors.orange.shade700),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a community name';
                          }
                          if (value.length < 3) {
                            return 'Name must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Hobby Selection Card
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
                        'Hobby Category',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _hobbies.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<String>(
                              value: _selectedHobby,
                              decoration: InputDecoration(
                                hintText: 'Select a hobby',
                                prefixIcon: Icon(Icons.favorite, color: Colors.orange.shade700),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              items: _hobbies.map((hobby) {
                                return DropdownMenuItem(
                                  value: hobby,
                                  child: Row(
                                    children: [
                                      Icon(Icons.favorite, size: 16, color: Colors.orange.shade400),
                                      const SizedBox(width: 8),
                                      Text(hobby),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedHobby = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a hobby/category';
                                }
                                return null;
                              },
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Description Card
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
                        'Description',
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
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: 'Describe your community...',
                          prefixIcon: Icon(Icons.description, color: Colors.orange.shade700),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          helperText: 'Tell members what this community is about',
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          if (value.length < 10) {
                            return 'Description must be at least 10 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Create Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || _isUploading) ? null : _createCommunity,
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
                          'Create Community',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}