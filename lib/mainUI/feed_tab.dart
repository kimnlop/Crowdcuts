// ignore_for_file: avoid_print, use_key_in_widget_constructors, library_private_types_in_public_api, prefer_final_fields, use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:Crowdcuts/mainUI/feed_item.dart';
import 'comment_section.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color.fromRGBO(1, 67, 115, 1),
        buttonTheme: const ButtonThemeData(
          buttonColor: Color.fromRGBO(230, 72, 111, 1),
          textTheme: ButtonTextTheme.primary,
        ),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color.fromRGBO(254, 173, 86, 1),
        ),
      ),
      home: FeedTab(),
    );
  }
}

class FeedTab extends StatefulWidget {
  @override
  _FeedTabState createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _photoController = TextEditingController();

  late StreamSubscription<QuerySnapshot> _feedSubscription;
  final Map<String, ImageProvider> _imageCache = {};
  List<FeedItem> _feedItems = [];
  bool _isPosting = false;
  bool _isPostingInProgress = false;
  bool _isLoading = true;
  String _photoName = '';

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

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Scaffold(
            body: RefreshIndicator(
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
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _isPosting ? null : _showPostDialog,
              label: const Text('Create Post',
                  style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
              icon: const Icon(Icons.add,
                  size: 24, color: Color.fromARGB(255, 0, 255, 17)),
              backgroundColor: const Color(0xFF50727B),
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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (feedItem.photoUrl != null)
              _buildCachedImage(feedItem.photoUrl!),
            Text(
              feedItem.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            const SizedBox(height: 8),
            Container(
              width: double.infinity, // Match parent width
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey
                      .withOpacity(0.5), // Adjust border color as needed
                  width: 1.0, // Adjust border width as needed
                ),
                borderRadius: BorderRadius.circular(
                    8.0), // Adjust corner radius as needed
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 8.0, vertical: 4.0), // Adjust padding here
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildReactionButton(feedItem, 'like', Icons.favorite,
                      Icons.favorite_border, Colors.red),
                  _buildReactionButton(feedItem, 'dope', Icons.whatshot,
                      Icons.whatshot_outlined, Colors.orange),
                  _buildReactionButton(feedItem, 'scissor', Icons.cut,
                      Icons.cut_outlined, Colors.blue),
                  GestureDetector(
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
                        const Icon(Icons.comment),
                        FutureBuilder<int>(
                          future: _getCommentCount(feedItem.id),
                          builder: (context, snapshot) {
                            final commentCount = snapshot.data ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Text('$commentCount'),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionButton(FeedItem feedItem, String reactionType,
      IconData activeIcon, IconData inactiveIcon, Color activeColor) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final userId = currentUser.uid;
    final isActive = feedItem.reactions[userId] == reactionType;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 100),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: GestureDetector(
        key: ValueKey(isActive), // Key for AnimatedSwitcher
        onTap: () => _putReaction(feedItem, reactionType),
        child: Row(
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? activeColor : null,
              size: 24,
            ),
            const SizedBox(width: 4), // Adjust spacing between icon and count
            Text(
              '${_getReactionCount(feedItem, reactionType)}',
              key: ValueKey(
                  '${reactionType}_${feedItem.id}'), // Unique key for Text
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  int _getReactionCount(FeedItem feedItem, String reactionType) {
    switch (reactionType) {
      case 'like':
        return feedItem.likesCount;
      case 'dope':
        return feedItem.dopeCount;
      case 'scissor':
        return feedItem.scissorCount;
      default:
        return 0;
    }
  }

  void _putReaction(FeedItem feedItem, String reactionType) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

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

  Future<ImageProvider> _loadImage(String photoUrl) async {
    final response = await http.get(Uri.parse(photoUrl));
    if (response.statusCode == 200) {
      return MemoryImage(response.bodyBytes);
    } else {
      throw Exception('Failed to load image');
    }
  }

  void _showPostDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('New Post',
                  style: TextStyle(color: Colors.deepPurple)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      maxLength: 20, // Limit title to 20 characters
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Stack(
                      children: [
                        TextField(
                          controller: _descriptionController,
                          maxLength: 200,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          right: 8,
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () =>
                                    _pickImage(ImageSource.gallery, setState),
                                icon: const Icon(Icons.photo_library),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _pickImage(ImageSource.camera, setState),
                                icon: const Icon(Icons.camera_alt),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _photoController.text.isNotEmpty
                        ? Text(
                            _photoName,
                            style: const TextStyle(color: Colors.green),
                          )
                        : const SizedBox(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color.fromARGB(255, 142, 33, 25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed:
                      _isPosting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isPosting ? null : () => _post(setState),
                  child: _isPosting
                      ? const CircularProgressIndicator()
                      : const Text('Post'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _pickImage(ImageSource source, StateSetter setState) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _photoController.text = pickedFile.path;
        _photoName = pickedFile.name;
      });
    }
  }

  void _post(StateSetter setState) async {
    if (_isPostingInProgress) {
      return;
    }

    setState(() {
      _isPostingInProgress = true;
      _isPosting = true;
    });

    var user = _auth.currentUser;
    if (user != null) {
      if (_titleController.text.trim().isEmpty) {
        _enablePosting(setState);
        _clearPostingInProgress();
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Error'),
              content: const Text('Title cannot be empty.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      }

      String? photoUrl = await _uploadPhoto(_photoController.text);
      await _firestore.collection('feedItems').add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'userId': user.uid,
        'photoUrl': photoUrl,
        'uploadDate': FieldValue.serverTimestamp(), // Set upload date
      });
      _clearControllers();
      Navigator.of(context).pop();
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
    _enablePosting(setState);
    // Clear the flag
    _clearPostingInProgress();
  }

  Future<String?> _uploadPhoto(String photoUrl) async {
    if (photoUrl.isNotEmpty) {
      try {
        Uint8List imageData;
        if (kIsWeb) {
          http.Response response = await http.get(Uri.parse(photoUrl));
          imageData = response.bodyBytes;
        } else {
          String imagePath = '';
          if (Platform.isAndroid) {
            imagePath = await _resolveAndroidContentUri(photoUrl);
          } else if (Platform.isIOS) {
            imagePath = await _resolveIOSFilePath(photoUrl);
          }
          imageData = await File(imagePath).readAsBytes();
        }
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        TaskSnapshot snapshot =
            await _storage.ref().child('photos/$fileName').putData(imageData);
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        print('Error uploading photo: $e');
        return null;
      }
    }
    return null;
  }

  Future<String> _resolveAndroidContentUri(String uriString) async {
    final uri = Uri.parse(uriString);
    final filePath = uri.path;
    return filePath;
  }

  Future<String> _resolveIOSFilePath(String uriString) async {
    final uri = Uri.parse(uriString);
    final filePath = uri.path;
    return filePath;
  }

  void _clearControllers() {
    _titleController.clear();
    _descriptionController.clear();
    _photoController.clear();
    _photoName = '';
  }

  void _enablePosting(StateSetter setState) {
    setState(() {
      _isPosting = false;
    });
  }

  void _clearPostingInProgress() {
    _isPostingInProgress = false;
  }
}

Future<int> _getCommentCount(String id) async {
  var querySnapshot = await FirebaseFirestore.instance
      .collection('comments')
      .where('feedItemId', isEqualTo: id)
      .get();
  return querySnapshot.size;
}
