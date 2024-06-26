// ignore_for_file: use_key_in_widget_constructors, avoid_print, unnecessary_string_interpolations

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'comment_section.dart'; // Ensure you import the comment section
import 'package:Crowdcuts/mainUI/feed_item.dart';

class MyAccountTab extends StatelessWidget {
  final Map<String, ImageProvider> _imageCache = {};

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('No user logged in'),
        ),
      );
    }

    final String userId = currentUser.uid;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Error loading user data')),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final String userName = userData['userName'] ?? 'Unknown User';

        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '$userName',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('feedItems')
                      .where('userId', isEqualTo: userId)
                      .orderBy('uploadDate', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text('Error loading feed items'));
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

                        return FutureBuilder<String>(
                          future: _fetchUserName(feedItemData['userId']),
                          builder: (context, userNameSnapshot) {
                            if (userNameSnapshot.hasError) {
                              return ListTile(
                                title:
                                    Text(feedItemData['title'] ?? 'No Title'),
                                subtitle: Text(feedItemData['description'] ??
                                    'No Content'),
                                trailing:
                                    const Icon(Icons.error, color: Colors.red),
                              );
                            }

                            if (!userNameSnapshot.hasData) {
                              return ListTile(
                                title:
                                    Text(feedItemData['title'] ?? 'No Title'),
                                subtitle: Text(feedItemData['description'] ??
                                    'No Content'),
                                trailing: const CircularProgressIndicator(),
                              );
                            }

                            var feedItem = FeedItem.fromSnapshot(
                              feedItems[index],
                              userNameSnapshot.data!,
                            );

                            return _buildFeedItem(feedItem, context);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String> _fetchUserName(String userId) async {
    var userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc['userName'] ?? 'Unknown';
  }

  Widget _buildFeedItem(FeedItem feedItem, BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        final ValueNotifier<bool> isEditing = ValueNotifier(feedItem.isEditing);
        final TextEditingController titleController =
            TextEditingController(text: feedItem.title);
        final TextEditingController descriptionController =
            TextEditingController(text: feedItem.description);

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
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (feedItem.photoUrl != null)
                  _buildCachedImage(feedItem.photoUrl!),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: isEditing,
                        builder: (context, editing, child) {
                          if (editing) {
                            return TextField(
                              controller: titleController,
                              maxLength: 20,
                              maxLines: 1,
                              decoration: InputDecoration(
                                labelText: 'Title',
                                errorText: titleController.text.trim().isEmpty
                                    ? 'Title cannot be empty'
                                    : null,
                              ),
                            );
                          } else {
                            return Text(
                              feedItem.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          isEditing.value = true;
                        } else if (value == 'save') {
                          if (titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Title cannot be empty or spaces only. Please provide a valid title.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            _saveFeedItem(
                              context,
                              feedItem,
                              titleController.text,
                              descriptionController.text,
                            );
                            isEditing.value = false;
                            setState(() {
                              feedItem.title = titleController.text;
                              feedItem.description = descriptionController.text;
                            });
                          }
                        } else if (value == 'delete') {
                          _deletePost(context, feedItem);
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        return [
                          if (!isEditing.value)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                          if (isEditing.value)
                            const PopupMenuItem(
                              value: 'save',
                              child: Text('Save'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: isEditing,
                  builder: (context, editing, child) {
                    if (editing) {
                      return TextField(
                        controller: descriptionController,
                        maxLength: 200,
                        maxLines: null,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'by ${feedItem.userName}',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                          Text(
                            feedItem.description,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8.0),
                          _buildReactionAndCommentRow(
                              feedItem, context, setState),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReactionAndCommentRow(
      FeedItem feedItem, BuildContext context, StateSetter setState) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      margin:
          const EdgeInsets.symmetric(vertical: 4.0), // Adjust vertical margin
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0), // Adjusted to smaller radius
        border: Border.all(
          color:
              Colors.grey.withOpacity(0.5), // Add border to match other design
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 8.0,
            vertical: 4.0), // Adjust padding inside the container
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _putReaction(feedItem, 'like', setState),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 100),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Icon(
                      feedItem.reactions[userId] == 'like'
                          ? Icons.favorite
                          : Icons.favorite_border,
                      key: ValueKey(feedItem.reactions[userId] == 'like'),
                      color: feedItem.reactions[userId] == 'like'
                          ? Colors.red
                          : null,
                      size: 24, // Reduced size
                    ),
                  ),
                ),
                const SizedBox(width: 4), // Add space between icon and count
                Text('${feedItem.likesCount}'),
              ],
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _putReaction(feedItem, 'dope', setState),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 100),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Icon(
                      feedItem.reactions[userId] == 'dope'
                          ? Icons.whatshot
                          : Icons.whatshot_outlined,
                      key: ValueKey(feedItem.reactions[userId] == 'dope'),
                      color: feedItem.reactions[userId] == 'dope'
                          ? Colors.orange
                          : null,
                      size: 24, // Reduced size
                    ),
                  ),
                ),
                const SizedBox(width: 4), // Add space between icon and count
                Text('${feedItem.dopeCount}'),
              ],
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _putReaction(feedItem, 'scissor', setState),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 100),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Icon(
                      feedItem.reactions[userId] == 'scissor'
                          ? Icons.cut
                          : Icons.cut_outlined,
                      key: ValueKey(feedItem.reactions[userId] == 'scissor'),
                      color: feedItem.reactions[userId] == 'scissor'
                          ? Colors.blue
                          : null,
                      size: 24, // Reduced size
                    ),
                  ),
                ),
                const SizedBox(width: 4), // Add space between icon and count
                Text('${feedItem.scissorCount}'),
              ],
            ),
            FutureBuilder<int>(
              future: _getCommentCount(feedItem.id),
              builder: (context, snapshot) {
                final commentCount = snapshot.data ?? 0;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CommentSection(feedItemId: feedItem.id),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.comment, size: 24), // Reduced size
                      const SizedBox(
                          width: 4), // Add space between icon and count
                      Text('$commentCount'),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
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
            return const Center(child: Icon(Icons.error));
          } else {
            _imageCache[photoUrl] = snapshot.data!;
            return Image(image: snapshot.data!);
          }
        },
      );
    }
  }

  // Load the image from the photoURL
  Future<ImageProvider> _loadImage(String imageUrl) async {
    var response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      return MemoryImage(response.bodyBytes);
    } else {
      throw Exception('Failed to load image');
    }
  }

  void _putReaction(
      FeedItem feedItem, String reactionType, StateSetter setState) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    final userId = currentUser.uid;

    FirebaseFirestore.instance.runTransaction((transaction) async {
      final feedItemRef =
          FirebaseFirestore.instance.collection('feedItems').doc(feedItem.id);
      final feedItemSnapshot = await transaction.get(feedItemRef);

      if (!feedItemSnapshot.exists) {
        throw Exception('Feed item does not exist');
      }

      final currentReactions =
          Map<String, String>.from(feedItemSnapshot.data()!['reactions'] ?? {});

      if (currentReactions[userId] == reactionType) {
        currentReactions.remove(userId);
      } else {
        currentReactions[userId] = reactionType;
      }
      transaction.update(feedItemRef, {'reactions': currentReactions});
    }).then((_) {
      // Haptic feedback after successful transaction
      HapticFeedback.mediumImpact();

      setState(() {
        if (feedItem.reactions[userId] == reactionType) {
          feedItem.reactions.remove(userId);
        } else {
          feedItem.reactions[userId] = reactionType;
        }

        feedItem.likesCount = feedItem.reactions.values
            .where((reaction) => reaction == 'like')
            .length;
        feedItem.dopeCount = feedItem.reactions.values
            .where((reaction) => reaction == 'dope')
            .length;
        feedItem.scissorCount = feedItem.reactions.values
            .where((reaction) => reaction == 'scissor')
            .length;
      });
    }).catchError((error, stackTrace) {
      print('Failed to update reaction: $error');
      print('Stack trace: $stackTrace');

      if (error is FirebaseException) {
        print('FirebaseException code: ${error.code}');
        print('FirebaseException message: ${error.message}');
      } else if (error is PlatformException) {
        print('PlatformException code: ${error.code}');
        print('PlatformException message: ${error.message}');
      } else {
        print('Unexpected error: $error');
      }
    });
  }

  void _saveFeedItem(BuildContext context, FeedItem feedItem, String newTitle,
      String newDescription) {
    FirebaseFirestore.instance.collection('feedItems').doc(feedItem.id).update({
      'title': newTitle,
      'description': newDescription,
    }).then((_) {
      print('Post updated successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post updated successfully'),
          backgroundColor: Colors.green, // Changed to green color
        ),
      );
    }).catchError((error) {
      print('Failed to update feed item: $error');
    });
  }

  void _deletePost(BuildContext context, FeedItem feedItem) async {
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
      // Delete associated comments first
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('comments')
          .where('feedItemId', isEqualTo: feedItem.id)
          .get();

      for (var comment in commentsSnapshot.docs) {
        await comment.reference.delete();
      }

      // Delete the feed item
      FirebaseFirestore.instance
          .collection('feedItems')
          .doc(feedItem.id)
          .delete()
          .then((_) {
        print('Your post has been deleted successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feed item deleted successfully'),
            backgroundColor: Colors.red,
          ),
        );
      }).catchError((error) {
        print('Failed to delete feed item: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete feed item'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }

  Future<int> _getCommentCount(String id) async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('comments')
        .where('feedItemId', isEqualTo: id)
        .get();
    return querySnapshot.size;
  }
}
