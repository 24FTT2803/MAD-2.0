import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/community_model.dart';
import '../models/post_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _users => _firestore.collection('users');
  CollectionReference get _communities => _firestore.collection('communities');
  CollectionReference get _posts => _firestore.collection('posts');
  CollectionReference get _activities => _firestore.collection('activities');

  Future<void> createUser(AppUser user) async {
    await _users.doc(user.id).set(user.toJson());
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return AppUser.fromJson(data);
    }
    return null;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).update(data);
  }

  Future<String> createCommunity(CommunityModel community) async {
    final docRef = _communities.doc();
    final newCommunity = community.copyWith(id: docRef.id);
    await docRef.set(newCommunity.toMap());
    
    await _addActivity(
      userId: _auth.currentUser!.uid,
      type: 'created_community',
      communityId: docRef.id,
      communityName: community.name,
    );
    
    return docRef.id;
  }

  Stream<List<CommunityModel>> getCommunities() {
    return _communities.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return CommunityModel.fromMap(doc.id, data);
      }).toList();
    });
  }

  Stream<List<CommunityModel>> getCommunitiesByHobby(String hobby) {
    return _communities.where('hobby', isEqualTo: hobby).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return CommunityModel.fromMap(doc.id, data);
      }).toList();
    });
  }

  Future<CommunityModel?> getCommunity(String communityId) async {
    final doc = await _communities.doc(communityId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return CommunityModel.fromMap(communityId, data);
    }
    return null;
  }

  Future<void> joinCommunity(String communityId) async {
    final userId = _auth.currentUser!.uid;
    await _communities.doc(communityId).update({
      'members': FieldValue.arrayUnion([userId])
    });
    
    final community = await getCommunity(communityId);
    await _addActivity(
      userId: userId,
      type: 'joined_community',
      communityId: communityId,
      communityName: community?.name ?? '',
    );
  }

  Future<void> leaveCommunity(String communityId) async {
    final userId = _auth.currentUser!.uid;
    await _communities.doc(communityId).update({
      'members': FieldValue.arrayRemove([userId])
    });
  }

  Future<void> banUser(String communityId, String userId, String reason) async {
    await _communities.doc(communityId).update({
      'bannedUsers': FieldValue.arrayUnion([userId])
    });
    await _communities.doc(communityId).update({
      'members': FieldValue.arrayRemove([userId])
    });
  }

  Future<void> transferOwnership(String communityId, String newOwnerId) async {
    await _communities.doc(communityId).update({
      'creatorId': newOwnerId
    });
  }

  Future<void> deleteCommunity(String communityId) async {
    final posts = await _posts.where('communityId', isEqualTo: communityId).get();
    for (var post in posts.docs) {
      await post.reference.delete();
    }
    await _communities.doc(communityId).delete();
  }

  Future<void> createPost(PostModel post) async {
    final docRef = _posts.doc();
    final newPost = post.copyWith(id: docRef.id);
    await docRef.set(newPost.toMap());
    
    await _addActivity(
      userId: _auth.currentUser!.uid,
      type: 'created_post',
      communityId: post.communityId,
      postId: docRef.id,
      postTitle: post.title,
    );
  }

  Stream<List<PostModel>> getPostsByCommunity(String communityId) {
    return _posts
        .where('communityId', isEqualTo: communityId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return PostModel.fromMap(doc.id, data);
      }).toList();
    });
  }

  Future<void> likePost(String postId) async {
    final userId = _auth.currentUser!.uid;
    await _posts.doc(postId).update({
      'likes': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> unlikePost(String postId) async {
    final userId = _auth.currentUser!.uid;
    await _posts.doc(postId).update({
      'likes': FieldValue.arrayRemove([userId])
    });
  }

  Future<void> _addActivity({
    required String userId,
    required String type,
    String? communityId,
    String? communityName,
    String? postId,
    String? postTitle,
  }) async {
    await _activities.add({
      'userId': userId,
      'type': type,
      'communityId': communityId,
      'communityName': communityName,
      'postId': postId,
      'postTitle': postTitle,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getUserActivities(String userId) {
    return _activities
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'type': data['type'] as String? ?? '',
          'communityName': data['communityName'] as String? ?? '',
          'postTitle': data['postTitle'] as String? ?? '',
          'timestamp': data['timestamp'],
        };
      }).toList();
    });
  }

  List<String> getAvailableHobbies() {
    return [
      'Gaming', 'Anime', 'Movies', 'Science', 'Technology',
      'Music', 'Art', 'Sports', 'Cooking', 'Photography',
      'Reading', 'Travel'
    ];
  }
}