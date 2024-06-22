// ignore_for_file: library_private_types_in_public_api, avoid_print, use_key_in_widget_constructors, prefer_const_constructors_in_immutables

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CommentSection extends StatefulWidget {
  final String feedItemId;

  CommentSection({required this.feedItemId});

  @override
  _CommentSectionState createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _commentController.text.trim().isNotEmpty) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userName = userDoc['userName'] ?? 'Anonymous';

      await FirebaseFirestore.instance.collection('comments').add({
        'feedItemId': widget.feedItemId,
        'userId': user.uid,
        'userName': userName,
        'comment': _commentController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'parentId': null,
      });
      _commentController.clear();
    }
  }

  Future<void> _addReply(String parentId, String commentText) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && commentText.trim().isNotEmpty) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userName = userDoc['userName'] ?? 'Anonymous';

      await FirebaseFirestore.instance.collection('comments').add({
        'feedItemId': widget.feedItemId,
        'userId': user.uid,
        'userName': userName,
        'comment': commentText,
        'timestamp': FieldValue.serverTimestamp(),
        'parentId': parentId,
      });
    }
  }

  Widget _buildCommentItem(DocumentSnapshot comment,
      Map<String, List<DocumentSnapshot>> repliesMap, int level) {
    return CommentItem(
      comment: comment,
      repliesMap: repliesMap,
      level: level,
      addReply: _addReply,
      maxLevel: 5, // Set the max level for nesting
      onDelete: () {
        _deleteComment(comment.id);
      },
      onEdit: (newComment) {
        _editComment(comment.id, newComment);
      },
    );
  }

  Future<void> _editComment(String commentId, String newComment) async {
    try {
      await FirebaseFirestore.instance
          .collection('comments')
          .doc(commentId)
          .update({'comment': newComment});

      setState(() {
        // Update the comment in the UI
        // This assumes you have a way to update the comment locally or reload data
      });

      // Optionally, handle success feedback or UI updates
    } catch (e) {
      // Handle errors or show error feedback
      print('Error updating comment: $e');
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('comments')
          .doc(commentId)
          .delete();

      setState(() {
        // Remove the comment from the UI
        // This assumes you have a way to update the UI locally or reload data
      });

      // Optionally, handle success feedback or UI updates
    } catch (e) {
      // Handle errors or show error feedback
      print('Error deleting comment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('comments')
            .where('feedItemId', isEqualTo: widget.feedItemId)
            .orderBy('timestamp', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print("Error fetching comments: ${snapshot.error}");
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final comments = snapshot.data?.docs ?? [];
          final commentsMap = <String, DocumentSnapshot>{};
          final repliesMap = <String, List<DocumentSnapshot>>{};

          for (var comment in comments) {
            if (comment['parentId'] == null) {
              commentsMap[comment.id] = comment;
            } else {
              repliesMap
                  .putIfAbsent(comment['parentId'], () => [])
                  .add(comment);
            }
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: commentsMap.length,
                  itemBuilder: (context, index) {
                    final comment = commentsMap.values.elementAt(index);
                    return _buildCommentItem(comment, repliesMap, 0);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _addComment,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CommentItem extends StatefulWidget {
  final DocumentSnapshot comment;
  final Map<String, List<DocumentSnapshot>> repliesMap;
  final int level;
  final int maxLevel;
  final Future<void> Function(String parentId, String commentText) addReply;
  final VoidCallback onDelete;
  final void Function(String newComment) onEdit;

  const CommentItem({
    required this.comment,
    required this.repliesMap,
    required this.level,
    required this.addReply,
    required this.maxLevel,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  _CommentItemState createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  final TextEditingController _replyController = TextEditingController();
  bool isExpanded = false;
  bool isEditing = false;
  late String editedCommentText;

  @override
  void initState() {
    super.initState();
    editedCommentText = widget.comment['comment'];
  }

  void _toggleReplies() {
    setState(() {
      isExpanded = !isExpanded;
    });
  }

  void _toggleEditing() {
    setState(() {
      isEditing = !isEditing;
      editedCommentText = widget.comment['comment'];
    });
  }

  Future<void> _saveEditedComment() async {
    // Perform the update in Firestore
    await FirebaseFirestore.instance
        .collection('comments')
        .doc(widget.comment.id)
        .update({'comment': editedCommentText});

    setState(() {
      isEditing = false;
      // Update the comment in the UI
      widget.onEdit(editedCommentText);
    });
  }

  Future<void> _deleteReply(String id) async {
    try {
      await FirebaseFirestore.instance.collection('comments').doc(id).delete();

      // Notify the parent widget of deletion
      widget.onDelete();

      // Optionally, handle success feedback or UI updates
    } catch (e) {
      // Handle errors or show error feedback
      print('Error deleting reply: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.comment['userName'];
    final commentText = widget.comment['comment'];
    final timestamp = (widget.comment['timestamp'] as Timestamp?)?.toDate();
    final formattedTime = timestamp != null
        ? DateFormat('yyyy-MM-dd – kk:mm').format(timestamp)
        : '';
    final commentId = widget.comment.id;
    final replies = widget.repliesMap[commentId] ?? [];

    return Padding(
      key: ValueKey(commentId),
      padding: EdgeInsets.only(
          left: widget.level * 6.0, top: 8.0, right: 8.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.level > 0) ...[
            CustomPaint(
              painter: LinePainter(),
              child: Container(
                margin: const EdgeInsets.only(left: 8.0, top: 8.0),
                height: 24.0,
                width: 2.0,
              ),
            ),
            const SizedBox(height: 8.0),
          ],
          GestureDetector(
            onTap: _toggleReplies,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.0),
              child: Container(
                color: const Color.fromARGB(255, 240, 242, 252),
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              userName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '• $formattedTime',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                        if (FirebaseAuth.instance.currentUser?.uid ==
                            widget.comment['userId'])
                          PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                            onSelected: (String value) {
                              if (value == 'edit') {
                                _toggleEditing();
                              } else if (value == 'delete') {
                                _deleteReply(commentId);
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (isEditing) ...[
                      TextField(
                        controller:
                            TextEditingController(text: editedCommentText),
                        onChanged: (value) {
                          editedCommentText = value;
                        },
                        decoration: InputDecoration(
                          hintText: 'Edit your comment...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _saveEditedComment,
                            child: const Text('Save'),
                          ),
                          TextButton(
                            onPressed: _toggleEditing,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(commentText),
                      const SizedBox(height: 8),
                      if (replies.isNotEmpty)
                        TextButton(
                          onPressed: _toggleReplies,
                          child: Text(isExpanded
                              ? 'Hide Replies (${replies.length})'
                              : 'Show Replies (${replies.length})'),
                        ),
                      if (_replyController.text.isNotEmpty || isExpanded)
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _replyController,
                                  maxLines: null,
                                  decoration: InputDecoration(
                                    hintText: 'Reply to $userName...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20.0),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.send),
                                      onPressed: () async {
                                        await widget.addReply(
                                            commentId, _replyController.text);
                                        _replyController.clear();
                                        setState(() {
                                          isExpanded = true;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded && widget.level < widget.maxLevel)
            Column(
              children: replies.map((reply) {
                return CommentItem(
                  comment: reply,
                  repliesMap: widget.repliesMap,
                  level: widget.level + 1,
                  addReply: widget.addReply,
                  maxLevel: widget.maxLevel,
                  onDelete: () {
                    _deleteComment(reply.id);
                  },
                  onEdit: (newComment) {
                    _editComment(reply.id, newComment);
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

void _deleteComment(String id) {}

void _editComment(String id, String newComment) {}

class LinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0;

    canvas.drawLine(
      const Offset(0, 0),
      Offset(0, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
