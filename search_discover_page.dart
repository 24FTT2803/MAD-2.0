import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../widgets/community_card.dart';

class SearchDiscoverPage extends StatefulWidget {
  const SearchDiscoverPage({super.key});

  @override
  State<SearchDiscoverPage> createState() => _SearchDiscoverPageState();
}

class _SearchDiscoverPageState extends State<SearchDiscoverPage> {
  String _selectedHobby = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final hobbies = firestoreService.getAvailableHobbies();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search communities, hobbies...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: hobbies.length + 1,
              itemBuilder: (context, index) {
                final hobby = index == 0 ? 'All' : hobbies[index - 1];
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
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: Colors.orange.shade100,
                    checkmarkColor: Colors.orange,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder(
              stream: _selectedHobby == 'All'
                  ? firestoreService.getCommunities()
                  : firestoreService.getCommunitiesByHobby(_selectedHobby),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No communities found for ${_selectedHobby == 'All' ? '' : _selectedHobby}',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                final communities = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: communities.length,
                  itemBuilder: (context, index) => CommunityCard(community: communities[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}