// ignore_for_file: prefer_const_constructors_in_immutables, use_key_in_widget_constructors, library_private_types_in_public_api, use_build_context_synchronously, unused_element

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

  Future<void> _editComment(String commentId, String newComment) async {
    await FirebaseFirestore.instance
        .collection('comments')
        .doc(commentId)
        .update({'comment': newComment});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comment edited successfully')),
    );
  }

  Future<void> _deleteComment(String commentId) async {
    // Fetch all comments with the parentId equal to commentId
    final snapshot = await FirebaseFirestore.instance
        .collection('comments')
        .where('parentId', isEqualTo: commentId)
        .get();

    // Recursively delete child comments
    for (final doc in snapshot.docs) {
      await _deleteComment(doc.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment deleted successfully')),
      );
    }

    // Delete the parent comment
    await FirebaseFirestore.instance
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  Map<String, List<DocumentSnapshot>> _organizeComments(
      List<DocumentSnapshot> comments) {
    final commentsMap = <String, DocumentSnapshot>{};
    final repliesMap = <String, List<DocumentSnapshot>>{};

    for (var comment in comments) {
      if (comment['parentId'] == null) {
        commentsMap[comment.id] = comment;
      } else {
        repliesMap.putIfAbsent(comment['parentId'], () => []).add(comment);
      }
    }

    return repliesMap;
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
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final comments = snapshot.data?.docs ?? [];
          final repliesMap = _organizeComments(comments);

          return Column(
            children: [
              Expanded(
                child: CommentList(
                  comments: comments,
                  repliesMap: repliesMap,
                  addReply: _addReply,
                  deleteComment: _deleteComment,
                  editComment: _editComment,
                ),
              ),
              CommentInputField(
                controller: _commentController,
                addComment: _addComment,
              ),
            ],
          );
        },
      ),
    );
  }
}

class CommentList extends StatelessWidget {
  final List<DocumentSnapshot> comments;
  final Map<String, List<DocumentSnapshot>> repliesMap;
  final Future<void> Function(String parentId, String commentText) addReply;
  final Future<void> Function(String commentId) deleteComment;
  final Future<void> Function(String commentId, String newComment) editComment;

  const CommentList({
    required this.comments,
    required this.repliesMap,
    required this.addReply,
    required this.deleteComment,
    required this.editComment,
  });

  @override
  Widget build(BuildContext context) {
    final rootComments =
        comments.where((comment) => comment['parentId'] == null).toList();
    return ListView.builder(
      itemCount: rootComments.length,
      itemBuilder: (context, index) {
        final comment = rootComments[index];
        return CommentItem(
          comment: comment,
          repliesMap: repliesMap,
          level: 0,
          maxLevel: 5,
          addReply: addReply,
          deleteComment: deleteComment,
          editComment: editComment,
        );
      },
    );
  }
}

class CommentInputField extends StatelessWidget {
  final TextEditingController controller;
  final Future<void> Function() addComment;

  const CommentInputField({
    required this.controller,
    required this.addComment,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Write a comment...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.send),
            onPressed: addComment,
          ),
        ),
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
  final Future<void> Function(String commentId) deleteComment;
  final Future<void> Function(String commentId, String newComment) editComment;

  const CommentItem({
    required this.comment,
    required this.repliesMap,
    required this.level,
    required this.addReply,
    required this.maxLevel,
    required this.deleteComment,
    required this.editComment,
  });

  @override
  _CommentItemState createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  final TextEditingController _replyController = TextEditingController();
  bool isExpanded = false;
  bool isEditing = false;
  late String editedCommentText;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    editedCommentText = widget.comment['comment'];
    _checkAdminRole();
  }

  Future<void> _checkAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          isAdmin = userDoc['role'] == 1;
        });
      }
    }
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
    await widget.editComment(widget.comment.id, editedCommentText);
    setState(() {
      isEditing = false;
    });
  }

  Future<void> _showDeleteConfirmationDialog(String commentId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Comment'),
          content: const Text('Are you sure you want to delete this comment?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                await widget.deleteComment(commentId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showRepliesModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final replies = widget.repliesMap[widget.comment.id] ?? [];
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            void refreshReplies() {
              setState(() {
                // Refresh the replies list
                widget.repliesMap[widget.comment.id] =
                    widget.repliesMap[widget.comment.id] ?? [];
              });
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: replies.length,
                    itemBuilder: (context, index) {
                      final reply = replies[index];
                      return CommentItem(
                        comment: reply,
                        repliesMap: widget.repliesMap,
                        level: 0, // Resetting the level for the modal
                        addReply: (parentId, commentText) async {
                          await widget.addReply(parentId, commentText);
                          refreshReplies();
                        },
                        maxLevel: widget.maxLevel,
                        deleteComment: (commentId) async {
                          await widget.deleteComment(commentId);
                          refreshReplies();
                        },
                        editComment: (commentId, newComment) async {
                          await widget.editComment(commentId, newComment);
                          refreshReplies();
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          decoration: const InputDecoration(
                            hintText: 'Write a reply...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () async {
                          await widget.addReply(
                              widget.comment.id, _replyController.text);
                          _replyController.clear();
                          refreshReplies();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _replyToModal(String parentId, String commentText) async {
    await widget.addReply(parentId, commentText);
    setState(() {
      // Refresh the replies list for this comment item
      widget.repliesMap[widget.comment.id] =
          widget.repliesMap[widget.comment.id] ?? [];
    });
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
                                widget.comment['userId'] ||
                            isAdmin)
                          PopupMenuButton(
                            itemBuilder: (context) {
                              List<PopupMenuEntry<String>> menuItems = [];
                              if (FirebaseAuth.instance.currentUser?.uid ==
                                  widget.comment['userId']) {
                                menuItems.add(
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                );
                                menuItems.add(
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                );
                              } else if (isAdmin) {
                                menuItems.add(
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                );
                              }
                              return menuItems;
                            },
                            onSelected: (String value) {
                              if (value == 'edit') {
                                _toggleEditing();
                              } else if (value == 'delete') {
                                _showDeleteConfirmationDialog(commentId);
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
                          onPressed: widget.level < widget.maxLevel
                              ? _toggleReplies
                              : _showRepliesModal,
                          child: Text('Show Replies (${replies.length})'),
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
                                          // Refresh the replies list
                                          widget.repliesMap[widget.comment.id] =
                                              widget.repliesMap[
                                                      widget.comment.id] ??
                                                  [];
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
                  deleteComment: widget.deleteComment,
                  editComment: widget.editComment,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

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
