// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../auth_service.dart';
import 'registration_page.dart';
import 'success_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;
  String _emailError = '';
  late AnimationController _animationController;

  bool _isResetPasswordCooldown = false;
  Timer? _resetPasswordCooldownTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    _resetPasswordCooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/crowdcutsbg.png"),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(height: 435),
                      _buildTextField(
                        emailController,
                        'Email',
                        TextInputType.emailAddress,
                        _emailError,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        passwordController,
                        'Password',
                        TextInputType.visiblePassword,
                        '',
                        isPassword: true,
                        isPasswordVisible: _passwordVisible,
                        togglePasswordVisibility: _togglePasswordVisibility,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 9.0),
                          child: Text('Login', style: TextStyle(fontSize: 15)),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF50727B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RegistrationPage(),
                            ),
                          );
                        },
                        child: const Text(
                          "Register",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          _resetPassword(emailController.text.trim());
                        },
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    TextInputType keyboardType,
    String errorText, {
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? togglePasswordVisibility,
  }) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword && !isPasswordVisible,
        style: const TextStyle(fontSize: 16.0),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white),
          filled: true,
          fillColor: Colors.white.withOpacity(0.4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white),
            borderRadius: BorderRadius.circular(10.0),
          ),
          errorText: errorText.isNotEmpty ? errorText : null,
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: togglePasswordVisibility,
                )
              : null,
        ),
        onChanged: (value) {
          if (label == 'Email') {
            setState(() {
              _emailError = '';
            });
          }
        },
      ),
    );
  }

  void _togglePasswordVisibility() {
    setState(() {
      _passwordVisible = !_passwordVisible;
    });
  }

  void _login() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _emailError = 'Email is required';
      });
      return;
    }

    if (password.isEmpty) {
      return;
    }

    setState(() {
      _emailError = '';
      _isLoading = true;
    });

    try {
      await AuthService().signIn(email, password);
      // Ensure the widget is still mounted before navigating
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SuccessPage()),
      );
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('Account is disabled')) {
        _showErrorDialog(
          "Your account has been disabled. Please contact support for assistance.",
          titleColor: const Color.fromARGB(255, 142, 33, 25),
          backgroundColor: Colors.red.shade100,
          icon: Icons.block,
        );
      } else if (errorMessage.contains('Too many attempts. Please wait')) {
        _showErrorDialog(
          "Too many attempts. Try again in 30 seconds.",
          titleColor: Colors.orange,
          backgroundColor: Colors.orange.shade100,
          icon: Icons.warning,
        );
      } else {
        _showErrorDialog(
          "Failed to login. Please check your credentials and try again.",
          titleColor: const Color.fromARGB(255, 142, 33, 25),
          backgroundColor: Colors.red.shade100,
          icon: Icons.error,
        );
      }
    } finally {
      // Ensure the widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetPassword(String email) async {
    if (_isResetPasswordCooldown) {
      _showErrorDialog(
        "Too many attempts. Please try again in 60 seconds.",
        titleColor: Colors.orange,
        backgroundColor: Colors.orange.shade100,
        icon: Icons.warning,
      );
      return;
    }

    // Show dialog to get email input
    String? resetEmail = await _showResetPasswordDialog();
    if (resetEmail == null || resetEmail.isEmpty) {
      return; // Cancelled or empty email
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: resetEmail);
      _showErrorDialog(
        "Password reset email sent. Please check your email inbox.",
        titleColor: Colors.green,
        backgroundColor: Colors.green.shade100,
        icon: Icons.check_circle,
      );

      // Start cooldown timer
      _startResetPasswordCooldown();
    } catch (e) {
      _showErrorDialog(
        "Failed to send password reset email. Please check your email address.",
        titleColor: const Color.fromARGB(255, 142, 33, 25),
        backgroundColor: Colors.red.shade100,
        icon: Icons.error,
      );
    }
  }

  Future<String?> _showResetPasswordDialog() async {
    String email = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false, // Dialog cannot be dismissed
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Forgot Password',
              style: TextStyle(color: Colors.black)),
          content: TextFormField(
            decoration: InputDecoration(
              hintText: 'Enter your email',
              fillColor: Colors.white.withOpacity(0.4),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: const BorderSide(color: Colors.white),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white),
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            onChanged: (value) {
              email = value;
            },
          ),
          actions: <Widget>[
            _buildAlertDialogButton(
              label: 'Cancel',
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              backgroundColor: Colors.grey,
            ),
            _buildAlertDialogButton(
              label: 'Send',
              onPressed: () {
                Navigator.of(context)
                    .pop(email); // Return email and close dialog
              },
              backgroundColor: Colors.blue,
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: Colors.white.withOpacity(0.9),
        );
      },
    );
  }

  void _startResetPasswordCooldown() {
    setState(() {
      _isResetPasswordCooldown = true;
    });

    _resetPasswordCooldownTimer = Timer(const Duration(seconds: 60), () {
      setState(() {
        _isResetPasswordCooldown = false;
      });
    });
  }

  void _showErrorDialog(
    String message, {
    required Color titleColor,
    required Color backgroundColor,
    required IconData icon,
  }) {
    _animationController.reset();
    _animationController.forward();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
          child: AlertDialog(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Icon(
              icon,
              color: titleColor,
              size: 50, // Reduced size of the icon
            ),
            content: Text(
              message,
              style: const TextStyle(
                fontSize: 16,
              ), // Reduced font size of the message
            ),
            backgroundColor: backgroundColor,
            actions: <Widget>[
              _buildAlertDialogButton(
                label: 'OK',
                onPressed: () {
                  Navigator.of(context).pop(); // Dismiss alert dialog
                },
                backgroundColor: titleColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertDialogButton({
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return TextButton(
      child: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: onPressed,
    );
  }
}
