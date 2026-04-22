import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hobbee_app/pages/comment_page.dart';

class SearchPostsInCommunityPage extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String initialQuery;

  const SearchPostsInCommunityPage({
    super.key,
    required this.communityId,
    required this.communityName,
    this.initialQuery = '',
  });

  @override
  State<SearchPostsInCommunityPage> createState() => _SearchPostsInCommunityPageState();
}

class _SearchPostsInCommunityPageState extends State<SearchPostsInCommunityPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialQuery.toLowerCase();
    _searchController.text = widget.initialQuery;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search in ${widget.communityName}'),
        backgroundColor: Colors.orange,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by title, content, or tags...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              onSubmitted: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: _buildSearchResults(),
    );
  }

  Widget _buildSearchResults() {
    if (_searchQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search for posts by title, content, or tags',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Example: anime, gaming, #anime',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('communityId', isEqualTo: widget.communityId)
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
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final allPosts = snapshot.data?.docs ?? [];
        
        // Handle search with or without # symbol
        String searchTerm = _searchQuery;
        if (searchTerm.startsWith('#')) {
          searchTerm = searchTerm.substring(1);
        }
        
        final filteredPosts = allPosts.where((post) {
          final data = post.data() as Map<String, dynamic>;
          final title = data['title']?.toLowerCase() ?? '';
          final content = data['content']?.toLowerCase() ?? '';
          final tags = List<String>.from(data['tags'] ?? []);
          final tagsMatch = tags.any((tag) => tag.toLowerCase().contains(searchTerm));
          return title.contains(searchTerm) || content.contains(searchTerm) || tagsMatch;
        }).toList();

        if (filteredPosts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No posts found matching "$_searchQuery"',
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredPosts.length,
          itemBuilder: (context, index) {
            final post = filteredPosts[index];
            final data = post.data() as Map<String, dynamic>;
            return _SearchResultCard(
              postId: post.id,
              data: data,
            );
          },
        );
      },
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> data;

  const _SearchResultCard({required this.postId, required this.data});

  @override
  Widget build(BuildContext context) {
    final likes = List<String>.from(data['likes'] ?? []);
    final dislikes = List<String>.from(data['dislikes'] ?? []);
    final tags = List<String>.from(data['tags'] ?? []);
    final imageUrl = data['imageUrl'];
    final hasImage = imageUrl != null && imageUrl.toString().isNotEmpty;
    final commentCount = data['commentCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showFullPostDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author Row
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.orange.shade100,
                    child: Text(
                      (data['authorName'] ?? 'U')[0].toUpperCase(),
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['authorName'] ?? 'User',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    _formatTime((data['createdAt'] as Timestamp?)?.toDate()),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Title
              Text(
                data['title'] ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // Content (preview)
              Text(
                data['content'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              
              // TAGS - Display as chips with # symbol
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.shade200,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),
              
              if (tags.isNotEmpty) const SizedBox(height: 8),
              
              // Image Preview
              if (hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              
              // Stats Row
              Row(
                children: [
                  Icon(Icons.thumb_up_alt_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 2),
                  Text('${likes.length}'),
                  const SizedBox(width: 12),
                  Icon(Icons.thumb_down_alt_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 2),
                  Text('${dislikes.length}'),
                  const SizedBox(width: 12),
                  Icon(Icons.comment, size: 14, color: Colors.grey),
                  const SizedBox(width: 2),
                  Text('$commentCount'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullPostDialog(BuildContext context) {
    final likes = List<String>.from(data['likes'] ?? []);
    final dislikes = List<String>.from(data['dislikes'] ?? []);
    final tags = List<String>.from(data['tags'] ?? []);
    final imageUrl = data['imageUrl'];
    final hasImage = imageUrl != null && imageUrl.toString().isNotEmpty;
    final commentCount = data['commentCount'] ?? 0;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.orange.shade100,
                      child: Text(
                        (data['authorName'] ?? 'U')[0].toUpperCase(),
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data['authorName'] ?? 'User',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Title
                Text(
                  data['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Content
                Text(data['content'] ?? ''),
                const SizedBox(height: 12),
                
                // TAGS - Full display
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )).toList(),
                  ),
                
                if (tags.isNotEmpty) const SizedBox(height: 12),
                
                // Full Image
                if (hasImage) ...[
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenImagePage(imageUrl: imageUrl),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Stats Row
                Row(
                  children: [
                    Icon(Icons.thumb_up_alt_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${likes.length}'),
                    const SizedBox(width: 16),
                    Icon(Icons.thumb_down_alt_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${dislikes.length}'),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.comment, size: 20),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommentPage(
                              postId: postId,
                              postTitle: data['title'] ?? 'Post',
                            ),
                          ),
                        );
                      },
                    ),
                    Text('$commentCount'),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Timestamp
                if (data['createdAt'] != null)
                  Text(
                    _formatTime((data['createdAt'] as Timestamp).toDate()),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'Recently';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// Full screen image viewer
class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImagePage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}