import 'package:cloud_firestore/cloud_firestore.dart';

class FeedItem {
  final String id;
  String title;
  String description;
  final String userName;
  final String? photoUrl;
  Map<String, String> reactions; // Made reactions non-final
  int likesCount;
  int dopeCount;
  int scissorCount;
  bool isEditing;

  FeedItem({
    required this.id,
    required this.title,
    required this.description,
    required this.userName,
    this.photoUrl,
    required this.reactions,
    required this.likesCount,
    required this.dopeCount,
    required this.scissorCount,
    this.isEditing = false,
  });

  factory FeedItem.fromSnapshot(DocumentSnapshot snapshot, String userName) {
    final data = snapshot.data() as Map<String, dynamic>;

    final reactions = Map<String, String>.from(data['reactions'] ?? {});
    final likesCount =
        reactions.values.where((reaction) => reaction == 'like').length;
    final dopeCount =
        reactions.values.where((reaction) => reaction == 'dope').length;
    final scissorCount =
        reactions.values.where((reaction) => reaction == 'scissor').length;

    return FeedItem(
      id: snapshot.id,
      title: data['title'] ?? 'No Title',
      description: data['description'] ?? 'No Description',
      userName: userName,
      photoUrl: data['photoUrl'],
      reactions: reactions,
      likesCount: likesCount,
      dopeCount: dopeCount,
      scissorCount: scissorCount,
    );
  }
}
