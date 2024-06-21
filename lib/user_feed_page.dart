// ignore_for_file: use_key_in_widget_constructors, prefer_const_constructors_in_immutables, use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserFeedPage extends StatelessWidget {
  final String userId;
  final String userName;

  UserFeedPage({required this.userId, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$userName\'s Feed'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('feedItems')
            .where('userId', isEqualTo: userId)
            .orderBy('uploadDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading feed items'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final feedItems = snapshot.data!.docs;

          if (feedItems.isEmpty) {
            return const Center(child: Text('No feed items found'));
          }

          return ListView.builder(
            itemCount: feedItems.length,
            itemBuilder: (context, index) {
              var feedItemData =
                  feedItems[index].data() as Map<String, dynamic>;

              var feedItem = FeedItem(
                id: feedItems[index].id,
                title: feedItemData['title'],
                description: feedItemData['description'],
                userId: feedItemData['userId'],
                userName: userName,
                photoUrl: feedItemData['photoUrl'],
              );

              return _buildFeedItem(feedItem, context);
            },
          );
        },
      ),
    );
  }

  void _deletePost(BuildContext context, FeedItem feedItem) async {
    try {
      await FirebaseFirestore.instance
          .collection('feedItems')
          .doc(feedItem.id)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post has been deleted successfully')),
      );
    } catch (e) {
      print('Failed to delete post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete post')),
      );
    }
  }

  Widget _buildFeedItem(FeedItem feedItem, BuildContext context) {
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
          if (feedItem.photoUrl != null) Image.network(feedItem.photoUrl!),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      feedItem.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteDialog(context, feedItem);
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        return [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ];
                      },
                    ),
                  ],
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, FeedItem feedItem) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
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
              onPressed: () => Navigator.of(dialogContext).pop(),
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
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deletePost(context, feedItem);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
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
}
