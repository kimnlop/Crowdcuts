// ignore_for_file: library_private_types_in_public_api, use_key_in_widget_constructors, prefer_final_fields, prefer_const_constructors, prefer_const_literals_to_create_immutables, sort_child_properties_last

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'feed_tab.dart';
import 'haircut_recommender_tab.dart';
import 'my_account_tab.dart';
import 'admin_page.dart';
import 'manage_users_page.dart';
import 'auth_service.dart';
import 'login_page.dart'; // Import your login page

class SuccessPage extends StatefulWidget {
  @override
  _SuccessPageState createState() => _SuccessPageState();
}

class _SuccessPageState extends State<SuccessPage> {
  int _selectedIndex = 0;
  bool _isAdmin = false;
  AuthService _authService = AuthService();
  List<Widget> _widgetOptions = <Widget>[]; // Initialize empty

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    bool isAdmin = await _authService.isAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        if (_isAdmin) {
          _widgetOptions = <Widget>[
            AdminPage(),
            ManageUsersPage(),
          ];
        } else {
          _widgetOptions = <Widget>[
            FeedTab(),
            HaircutRecommenderTab(),
            MyAccountTab(),
          ];
        }
      });
    }
  }

  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _logout() {
    FirebaseAuth.instance.signOut().then((value) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
        (Route<dynamic> route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(211, 255, 255, 255), // Dark gray color
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Image.asset(
                'assets/cclogo3.png',
                height: 40,
              ),
            ),
            Text(
              _isAdmin ? 'Admin Dashboard' : 'Crowdcuts',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Color(0xFF50727B)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    title: Row(
                      children: [
                        Text(
                          "Confirm Logout",
                          style: TextStyle(color: Color(0xFF50727B)),
                        ),
                      ],
                    ),
                    content: Text("Are you sure you want to logout?"),
                    actions: <Widget>[
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
                        child: Text("Yes"),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor:
                              const Color.fromARGB(255, 142, 33, 25),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          _logout();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: _widgetOptions.isNotEmpty
          ? IndexedStack(
              index: _selectedIndex,
              children: _widgetOptions,
            )
          : Center(
              child: CircularProgressIndicator(),
            ), // Show loader until tabs are set
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color.fromARGB(211, 255, 255, 255),
        items: _isAdmin
            ? const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.admin_panel_settings),
                  label: 'Admin Feed',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people),
                  label: 'Manage Users',
                ),
              ]
            : const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Feed',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.cut),
                  label: 'Haircut',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_circle),
                  label: 'My Account',
                ),
              ],
        currentIndex: _selectedIndex,
        selectedItemColor: Color(0xFF50727B),
        unselectedItemColor: const Color.fromARGB(255, 106, 106, 106),
        onTap: _onItemTapped,
      ),
      backgroundColor: Color.fromARGB(211, 255, 255, 255),
    );
  }
}
