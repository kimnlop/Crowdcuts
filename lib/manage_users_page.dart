// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, prefer_final_fields, use_build_context_synchronously, prefer_const_constructors, sort_child_properties_last, unnecessary_string_interpolations, prefer_const_literals_to_create_immutables, use_rethrow_when_possible, avoid_print, unused_element

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_feed_page.dart';

class ManageUsersPage extends StatefulWidget {
  @override
  _ManageUsersPageState createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<UserItem> _users = [];
  List<UserItem> _filteredUsers = [];
  bool _isLoading = true;
  int _currentPage = 1;
  final int _usersPerPage = 10;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
    });

    QuerySnapshot snapshot = await _firestore.collection('users').get();
    List<UserItem> users = snapshot.docs.map((doc) {
      return UserItem.fromSnapshot(doc);
    }).toList();

    users.sort((a, b) => a.userName.compareTo(b.userName));

    if (mounted) {
      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    }
  }

  void _filterUsers(String query) {
    List<UserItem> filteredList = _users.where((user) {
      return user.userName.toLowerCase().contains(query.toLowerCase()) ||
          user.email.toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() {
      _filteredUsers = filteredList;
      _currentPage = 1;
    });
  }

  Future<void> _toggleAccountStatus(UserItem user) async {
    bool newStatus = !user.isDisabled;
    await _firestore.collection('users').doc(user.id).update({
      'isDisabled': newStatus,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Account has been ${newStatus ? 'disabled' : 'enabled'} successfully')),
    );
    _fetchUsers(); // Refresh the user list after toggling account status
  }

  void _viewAccount(String userId, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserFeedPage(userId: userId, userName: userName),
      ),
    );
  }

  void _confirmToggleAccountStatus(UserItem user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            '${user.isDisabled ? 'Enable' : 'Disable'} Account',
            style:
                TextStyle(color: user.isDisabled ? Colors.green : Colors.red),
          ),
          content: Text(
              'Are you sure you want to ${user.isDisabled ? 'enable' : 'disable'} this account?'),
          actions: [
            TextButton(
              child: Text("Cancel"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Color(0xFF50727B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('${user.isDisabled ? 'Enable' : 'Disable'}'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: user.isDisabled
                    ? Colors.green
                    : const Color.fromARGB(255, 142, 33, 25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _toggleAccountStatus(user);
              },
            ),
          ],
        );
      },
    );
  }

  void _nextPage() {
    setState(() {
      if (_currentPage * _usersPerPage < _filteredUsers.length) {
        _currentPage++;
      }
    });
  }

  void _previousPage() {
    setState(() {
      if (_currentPage > 1) {
        _currentPage--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    int startIndex = (_currentPage - 1) * _usersPerPage;
    int endIndex = startIndex + _usersPerPage;
    List<UserItem> paginatedUsers = _filteredUsers.sublist(
      startIndex,
      endIndex > _filteredUsers.length ? _filteredUsers.length : endIndex,
    );
    int totalPages = (_filteredUsers.length / _usersPerPage).ceil();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filterUsers,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Username',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Email',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 48), // Space for View Account button
                SizedBox(width: 48), // Space for Disable/Enable Account button
              ],
            ),
          ),
          Divider(),
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.all(8.0),
                          itemCount: paginatedUsers.length,
                          itemBuilder: (context, index) {
                            var userItem = paginatedUsers[index];
                            return Card(
                              color: userItem.isDisabled
                                  ? Colors.red[100]
                                  : Colors.green[100],
                              margin: EdgeInsets.symmetric(vertical: 8.0),
                              elevation: 4.0,
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        userItem.userName,
                                        style: TextStyle(
                                          fontSize: 15.0,
                                          fontWeight: FontWeight.bold,
                                          color: userItem.isDisabled
                                              ? Colors.red[900]
                                              : Colors.green[900],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        userItem.email,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: userItem.isDisabled
                                              ? const Color.fromARGB(
                                                  255, 142, 33, 25)
                                              : Colors.green[900],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.remove_red_eye),
                                      onPressed: () => _viewAccount(
                                          userItem.id, userItem.userName),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                          userItem.isDisabled
                                              ? Icons.check
                                              : Icons.block,
                                          color: userItem.isDisabled
                                              ? Colors.green
                                              : const Color.fromARGB(
                                                  255, 142, 33, 25)),
                                      onPressed: () =>
                                          _confirmToggleAccountStatus(userItem),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_left),
                            onPressed: _previousPage,
                          ),
                          Text('$_currentPage / $totalPages'),
                          IconButton(
                            icon: Icon(Icons.arrow_right),
                            onPressed: _nextPage,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

class UserItem {
  final String id;
  final String userName;
  final String email;
  final bool isDisabled;

  UserItem({
    required this.id,
    required this.userName,
    required this.email,
    required this.isDisabled,
  });

  factory UserItem.fromSnapshot(DocumentSnapshot snapshot) {
    try {
      final data = snapshot.data() as Map<String, dynamic>;
      return UserItem(
        id: snapshot.id,
        userName: data['userName'] ?? '',
        email: data['email'] ?? '',
        isDisabled: data['isDisabled'] ?? false,
      );
    } catch (e) {
      print('Error creating UserItem from snapshot: ${snapshot.data()}');
      throw e;
    }
  }
}
