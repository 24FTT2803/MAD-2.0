import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BannedNoticePage extends StatefulWidget {
  final String communityId;
  final String communityName;

  const BannedNoticePage({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  State<BannedNoticePage> createState() => _BannedNoticePageState();
}

class _BannedNoticePageState extends State<BannedNoticePage> {
  String? _bannedReason;
  DateTime? _bannedDate;
  String? _bannedBy;
  String? _bannedByName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBanInfo();
  }

  Future<void> _loadBanInfo() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final communityDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .get();

    if (communityDoc.exists) {
      final data = communityDoc.data() as Map<String, dynamic>;
      final bannedUsersDetails = List<Map<String, dynamic>>.from(data['bannedUsersDetails'] ?? []);
      final banInfo = bannedUsersDetails.firstWhere(
        (ban) => ban['userId'] == currentUser.uid,
        orElse: () => {},
      );
      
      DateTime? banDate;
      if (banInfo['bannedAt'] is Timestamp) {
        banDate = (banInfo['bannedAt'] as Timestamp).toDate();
      } else if (banInfo['bannedAt'] is int) {
        banDate = DateTime.fromMillisecondsSinceEpoch(banInfo['bannedAt'] as int);
      }
      
      // Get banned by user name
      if (banInfo['bannedBy'] != null) {
        final bannedByDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(banInfo['bannedBy'])
            .get();
        if (bannedByDoc.exists) {
          final bannedByData = bannedByDoc.data() as Map<String, dynamic>;
          _bannedByName = bannedByData['username'] ?? 'An admin';
        } else {
          _bannedByName = 'An admin';
        }
      }
      
      setState(() {
        _bannedReason = banInfo['reason'] ?? 'Violation of community guidelines';
        _bannedDate = banDate;
        _bannedBy = banInfo['bannedBy'];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Icon
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.block,
                          size: 70,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Title
                    const Text(
                      'You Have Been Banned',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // Community Name
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.communityName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Ban Details Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade100,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, size: 20, color: Colors.grey),
                              SizedBox(width: 8),
                              Text(
                                'Ban Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          
                          // Reason
                          const Row(
                            children: [
                              Icon(Icons.warning, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Reason:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _bannedReason ?? 'Violation of community guidelines',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.red,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Banned by
                          if (_bannedByName != null) ...[
                            const Row(
                              children: [
                                Icon(Icons.person, size: 18, color: Colors.grey),
                                SizedBox(width: 8),
                                Text(
                                  'Banned by:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _bannedByName!,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // Date
                          if (_bannedDate != null) ...[
                            const Row(
                              children: [
                                Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                SizedBox(width: 8),
                                Text(
                                  'Banned on:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_bannedDate!.day}/${_bannedDate!.month}/${_bannedDate!.year}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Message
                    const Text(
                      'You cannot view, post, or interact with this community.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'If you believe this was a mistake, please contact the community admin.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Go Back Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text(
                          'Go Back',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}