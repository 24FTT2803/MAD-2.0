import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hobbee_app/pages/home_page.dart';

class OnboardingHobbiesPage extends StatefulWidget {
  const OnboardingHobbiesPage({super.key});

  @override
  State<OnboardingHobbiesPage> createState() => _OnboardingHobbiesPageState();
}

class _OnboardingHobbiesPageState extends State<OnboardingHobbiesPage> {
  final List<String> _allHobbies = [
    'Gaming', 'Anime', 'Movies', 'Science', 'Technology',
    'Music', 'Art', 'Sports', 'Cooking', 'Photography',
    'Reading', 'Travel'
  ];
  
  final Set<String> _selectedHobbies = {};
  List<String> _recommendedCommunities = [];
  Map<String, bool> selectedCommunities = {};
  bool _isLoading = false;
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Custom AppBar with Progress
          Container(
            padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.orange, Colors.deepOrange],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Welcome!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${_selectedHobbies.length}/3',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select your interests to personalize your experience',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                // Progress Indicator
                LinearProgressIndicator(
                  value: _selectedHobbies.length / 3,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  minHeight: 8,
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Your Hobbies',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose at least 3 hobbies to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Hobbies Grid
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _allHobbies.map((hobby) {
                      final isSelected = _selectedHobbies.contains(hobby);
                      return FilterChip(
                        label: Text(hobby),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected && _selectedHobbies.length < 6) {
                              _selectedHobbies.add(hobby);
                            } else if (!selected) {
                              _selectedHobbies.remove(hobby);
                            }
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: Colors.orange.shade100,
                        checkmarkColor: Colors.orange,
                        side: BorderSide(
                          color: isSelected ? Colors.orange : Colors.grey.shade300,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  
                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedHobbies.length >= 3 ? _continueToCommunities : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _continueToCommunities() async {
    setState(() => _isLoading = true);
    
    try {
      // Save user's hobbies
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'hobbies': _selectedHobbies.toList(),
      });
      
      // Get recommended communities based on selected hobbies
      final communities = await FirebaseFirestore.instance
          .collection('communities')
          .where('hobby', whereIn: _selectedHobbies.toList())
          .limit(10)
          .get();
      
      setState(() {
        _recommendedCommunities = communities.docs.map((doc) => doc.id).toList();
      });
      
      if (mounted) {
        selectedCommunities = {};
        for(String id in _recommendedCommunities) {
          selectedCommunities[id] = true;
        }
        _showRecommendedCommunitiesDialog();
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

  void _showRecommendedCommunitiesDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, StateSetter setStateDialog) {
          return Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Recommended Communities',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Based on your interests, you might like these communities',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: _recommendedCommunities.length,
                    itemBuilder: (context, index) {
                      final communityId = _recommendedCommunities[index];
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('communities')
                            .doc(communityId)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          final data = snapshot.data!.data() as Map<String, dynamic>;
                          final communityName = data['name'] ?? 'Community';
                          final hobby = data['hobby'] ?? 'General';
                          final members = List<String>.from(data['members'] ?? []);
                          final communityImage = data['communityImage'];
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade100),
                            ),
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
                                          communityName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
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
                                                hobby,
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
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Checkbox(
                                    value: selectedCommunities[communityId],
                                    onChanged: (value) {
                                      setStateDialog(() {
                                        selectedCommunities[communityId] = value ?? false;
                                      });
                                    },
                                    activeColor: Colors.orange,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context, 
                            MaterialPageRoute(builder: (_) => const HomePage()), 
                            (Route<dynamic> route) => false
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.orange),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final userId = FirebaseAuth.instance.currentUser!.uid;
                          for (var entry in selectedCommunities.entries) {
                            if (entry.value) {
                              await FirebaseFirestore.instance
                                  .collection('communities')
                                  .doc(entry.key)
                                  .update({
                                'members': FieldValue.arrayUnion([userId]),
                              });
                            }
                          }
                          if (mounted) {
                            Navigator.pushAndRemoveUntil(
                              context, 
                              MaterialPageRoute(builder: (_) => const HomePage()), 
                              (Route<dynamic> route) => false
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Join Selected'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}