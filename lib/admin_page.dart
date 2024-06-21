// ignore_for_file: library_private_types_in_public_api, use_key_in_widget_constructors, prefer_final_fields, use_build_context_synchronously, prefer_const_literals_to_create_immutables

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  late StreamSubscription<QuerySnapshot> _feedSubscription;
  final Map<String, ImageProvider> _imageCache = {};
  List<FeedItem> _feedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _subscribeToFeed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _feedSubscription.cancel();
    super.dispose();
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _feedItems.clear();
    });
    _subscribeToFeed();
  }

  void _subscribeToFeed() {
    setState(() {
      _isLoading = true;
    });

    _feedSubscription = _firestore
        .collection('feedItems')
        .orderBy('uploadDate', descending: true)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs.reversed) {
        var userDoc =
            await _firestore.collection('users').doc(doc['userId']).get();
        String userName = userDoc['userName'];

        bool alreadyExists = _feedItems.any((item) => item.id == doc.id);

        if (!alreadyExists) {
          setState(() {
            _feedItems.insert(0, FeedItem.fromSnapshot(doc, userName));
          });
        }
      }

      setState(() {
        _isLoading = false;
      });
    });
  }

  void _deletePost(FeedItem feedItem) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Text(
                "Confirm Deletion",
                style: TextStyle(color: Color(0xFF50727B)),
              ),
            ],
          ),
          content: const Text('Are you sure you want to delete this post?'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF50727B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color.fromARGB(255, 142, 33, 25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmDelete) {
      await _firestore.collection('feedItems').doc(feedItem.id).delete();
      setState(() {
        _feedItems.remove(feedItem);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post has been deleted successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshFeed,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _feedItems.length,
                itemBuilder: (context, index) {
                  var feedItem = _feedItems[index];
                  return _buildFeedItem(feedItem);
                },
              ),
            ),
    );
  }

  Widget _buildFeedItem(FeedItem feedItem) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (feedItem.photoUrl != null) _buildCachedImage(feedItem.photoUrl!),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feedItem.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'by ${feedItem.userName}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  feedItem.description,
                  style: const TextStyle(fontSize: 16),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletePost(feedItem),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCachedImage(String photoUrl) {
    if (_imageCache.containsKey(photoUrl)) {
      return Image(image: _imageCache[photoUrl]!);
    } else {
      return FutureBuilder(
        future: _loadImage(photoUrl),
        builder: (context, AsyncSnapshot<ImageProvider> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading image'));
          } else {
            _imageCache[photoUrl] = snapshot.data!;
            return Image(image: snapshot.data!);
          }
        },
      );
    }
  }

  Future<ImageProvider> _loadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return MemoryImage(response.bodyBytes);
      } else {
        throw Exception('Failed to load image');
      }
    } catch (e) {
      throw Exception('Failed to load image: $e');
    }
  }
}

class FeedItem {
  final String id;
  final String title;
  final String description;
  final String userId;
  final String userName;
  final String? photoUrl;

  FeedItem({
    required this.id,
    required this.title,
    required this.description,
    required this.userId,
    required this.userName,
    this.photoUrl,
  });

  factory FeedItem.fromSnapshot(DocumentSnapshot snapshot, String userName) {
    return FeedItem(
      id: snapshot.id,
      title: snapshot['title'],
      description: snapshot['description'],
      userId: snapshot['userId'],
      userName: userName,
      photoUrl: snapshot['photoUrl'],
    );
  }
}
