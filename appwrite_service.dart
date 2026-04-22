import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppwriteService extends ChangeNotifier {
  static final AppwriteService _instance = AppwriteService._internal();
  factory AppwriteService() => _instance;
  AppwriteService._internal();

  // ==============================================
  // REPLACE THESE WITH YOUR ACTUAL VALUES:
  // ==============================================
  
  // Your Project ID (from URL: project-sgp-69d62e4300304fe2e669)
  static const String _projectId = '69d62e4300304fe2e669';
  
  // Your Bucket ID (from Storage -> Your Bucket -> Settings)
  static const String _bucketId = '69d62e9f003cf1f96e9b'; // Replace this!
  
  // Your API Key (click the eye icon to reveal, then copy)
  static const String _apiKey = 'standard_1dda0af01ed48c366ea4517a7abe62ff6976be0c34b7925397614fc08de14b2d7c6fb087036c874685b77b6c1bc250fd08bc0f74cac629540d811745f9db7298074ce0dfdd5c77bed7f9f27debc9fd3ed201583fd1ff12984e8d32a78de294a6801449219263a2208b5432aad0c62de55da279f32e91c530b2cef67e21a41ace'; // Replace this!
  
  // ==============================================
  
  static const String _endpoint = 'https://sgp.cloud.appwrite.io/v1';
  
  bool _isInitialized = false;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    print('Appwrite initialized');
  }
  
  // For mobile: upload from File
  Future<String> uploadPostImage(File imageFile) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final fileName = 'post_${DateTime.now().millisecondsSinceEpoch}_$userId.jpg';
      
      // Read file bytes
      final bytes = await imageFile.readAsBytes();
      
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_endpoint/storage/buckets/$_bucketId/files'),
      );
      
      // Add headers with API key for authentication
      request.headers.addAll({
        'X-Appwrite-Project': _projectId,
        'X-Appwrite-Key': _apiKey,
      });
      
      // Add file
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ));
      
      // Add fileId - use unique() for auto-generation
      request.fields['fileId'] = 'unique()';
      
      print('Uploading to Appwrite...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        final data = json.decode(responseBody);
        final fileId = data['\$id'];
        final imageUrl = '$_endpoint/storage/buckets/$_bucketId/files/$fileId/view?project=$_projectId';
        print('Image uploaded successfully');
        return imageUrl;
      } else {
        print('Upload failed: $responseBody');
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Upload error: $e');
      throw Exception('Failed to upload image: $e');
    }
  }
  
  // For web: upload from bytes
  Future<String> uploadPostImageBytes(Uint8List imageBytes) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final fileName = 'post_${DateTime.now().millisecondsSinceEpoch}_$userId.jpg';
      
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_endpoint/storage/buckets/$_bucketId/files'),
      );
      
      // Add headers with API key for authentication
      request.headers.addAll({
        'X-Appwrite-Project': _projectId,
        'X-Appwrite-Key': _apiKey,
      });
      
      // Add file from bytes
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
      ));
      
      // Add fileId - use unique() for auto-generation
      request.fields['fileId'] = 'unique()';
      
      print('Uploading to Appwrite...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        final data = json.decode(responseBody);
        final fileId = data['\$id'];
        final imageUrl = '$_endpoint/storage/buckets/$_bucketId/files/$fileId/view?project=$_projectId';
        print('Image uploaded successfully');
        return imageUrl;
      } else {
        print('Upload failed: $responseBody');
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Upload error: $e');
      throw Exception('Failed to upload image: $e');
    }
  }
  
  Future<void> deletePostImage(String imageUrl) async {
    try {
      final fileId = _extractFileIdFromUrl(imageUrl);
      if (fileId.isNotEmpty) {
        final response = await http.delete(
          Uri.parse('$_endpoint/storage/buckets/$_bucketId/files/$fileId'),
          headers: {
            'X-Appwrite-Project': _projectId,
            'X-Appwrite-Key': _apiKey,
          },
        );
        
        if (response.statusCode == 204) {
          print('Image deleted successfully');
        }
      }
    } catch (e) {
      print('Delete error: $e');
    }
  }
  
  String _extractFileIdFromUrl(String url) {
    try {
      final parts = url.split('/files/');
      if (parts.length > 1) {
        final filePart = parts[1].split('/view')[0];
        return filePart;
      }
    } catch (e) {
      print('Error extracting file ID: $e');
    }
    return '';
  }
  
  bool get isInitialized => _isInitialized;
}