import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hobbee_app/pages/create_community_page.dart';
import 'package:hobbee_app/pages/community_detail_page.dart';
import '../models/community_model.dart';
import '../widgets/community_card.dart';

class CommunitiesPage extends StatelessWidget {
  const CommunitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Communities',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.orange.shade800,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateCommunityPage()),
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('communities').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allCommunities = snapshot.data?.docs ?? [];
          final communities = allCommunities.where((community) {
            final data = community.data() as Map<String, dynamic>;
            final bannedUsers = List<String>.from(data['bannedUsers'] ?? []);
            return !bannedUsers.contains(currentUserId);
          }).toList();

          if (communities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No communities yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Be the first to create a community!',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateCommunityPage()),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Community'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: communities.length,
            itemBuilder: (context, index) {
              final doc = communities[index];
              final data = doc.data() as Map<String, dynamic>;
              final community = CommunityModel(
                id: doc.id,
                name: data['name'] ?? 'Community',
                description: data['description'] ?? '',
                hobby: data['hobby'] ?? 'General',
                creatorId: data['creatorId'] ?? '',
                members: List<String>.from(data['members'] ?? []),
                bannedUsers: List<String>.from(data['bannedUsers'] ?? []),
                memberCount: (data['members'] as List?)?.length ?? 0,
                createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              );
              return CommunityCard(community: community);
            },
          );
        },
      ),
    );
  }
}