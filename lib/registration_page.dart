// ignore_for_file: sort_child_properties_last, use_build_context_synchronously, use_key_in_widget_constructors, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'success_page.dart';

class RegistrationPage extends StatefulWidget {
  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String _emailError = '';
  String _nameError = '';
  String _passwordError = '';
  String _confirmPasswordError = '';

  bool get _isFormValid {
    return _emailError.isEmpty &&
        _nameError.isEmpty &&
        _passwordError.isEmpty &&
        _confirmPasswordError.isEmpty &&
        emailController.text.isNotEmpty &&
        userNameController.text.isNotEmpty &&
        passwordController.text.isNotEmpty &&
        confirmPasswordController.text.isNotEmpty &&
        passwordController.text == confirmPasswordController.text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 400),
                  _buildTextField(
                    emailController,
                    'Email',
                    TextInputType.emailAddress,
                    _emailError,
                    RegExp(r'^[\w.-]+@[a-zA-Z]+\.[a-zA-Z]+$'),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    userNameController,
                    'Username',
                    TextInputType.text,
                    _nameError,
                    RegExp(r'^[a-zA-Z0-9]{2,15}$'), // No spaces, 2-15 chars
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    passwordController,
                    'Password',
                    TextInputType.visiblePassword,
                    _passwordError,
                    null,
                    isPassword: true,
                    isPasswordVisible: _passwordVisible,
                    togglePasswordVisibility: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    confirmPasswordController,
                    'Confirm Password',
                    TextInputType.visiblePassword,
                    _confirmPasswordError,
                    null,
                    isPassword: true,
                    isPasswordVisible: _confirmPasswordVisible,
                    togglePasswordVisibility: () => setState(() =>
                        _confirmPasswordVisible = !_confirmPasswordVisible),
                  ),
                  const SizedBox(height: 30),
                  _buildRegisterButton(),
                  const SizedBox(height: 20),
                  _buildBackToLoginButton(),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/crowdcutsbg.png"),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    TextInputType keyboardType,
    String errorText,
    RegExp? regExp, {
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? togglePasswordVisibility,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword && !isPasswordVisible,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        filled: true,
        fillColor: Colors.white.withOpacity(0.5),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(10.0),
        ),
        errorText: errorText.isNotEmpty ? errorText : null,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(isPasswordVisible
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: togglePasswordVisibility,
              )
            : null,
      ),
      onChanged: (value) => _validateField(label, value),
    );
  }

  void _validateField(String label, String value) {
    setState(() {
      switch (label) {
        case 'Email':
          _emailError =
              RegExp(r'^[\w.-]+@[a-zA-Z]+\.[a-zA-Z]+$').hasMatch(value)
                  ? ''
                  : 'Invalid email format';
          break;
        case 'Username':
          _nameError = RegExp(r'^[a-zA-Z0-9]{2,15}$').hasMatch(value)
              ? ''
              : 'Username must be 2-15 characters long with no spaces and \nspecial characters';
          break;
        case 'Password':
          _passwordError =
              RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$')
                          .hasMatch(value) &&
                      value.replaceAll(RegExp(r'[^@$!%*?&]'), '').length == 1
                  ? ''
                  : 'Password must be at least 8 characters long, include a number, and \nexactly one special character';
          break;
      }
      _checkPasswordsMatch();
    });
  }

  void _checkPasswordsMatch() {
    _confirmPasswordError =
        passwordController.text == confirmPasswordController.text
            ? ''
            : 'Passwords do not match';
  }

  Widget _buildRegisterButton() {
    return ElevatedButton(
      onPressed: (!_isFormValid || _isLoading) ? null : _register,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 9.0),
        child: Text(
          'Register',
          style: TextStyle(fontSize: 15),
        ),
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF50727B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildBackToLoginButton() {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text(
        "Back to Login",
        style: TextStyle(fontSize: 16, color: Colors.white),
      ),
    );
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final email = emailController.text.trim();
      final username = userNameController.text.trim().toLowerCase();

      final isEmailTaken = await AuthService().checkUserExists(email);
      if (isEmailTaken) {
        throw 'Email is already taken';
      }

      final isUsernameTaken = await DatabaseService().isUsernameTaken(username);
      if (isUsernameTaken) {
        throw 'Username already taken';
      }

      final userCredential = await AuthService().signUp(
        email,
        passwordController.text.trim(),
      );
      await DatabaseService().addUser(userCredential.user!.uid, {
        'email': email,
        'userName': username,
        'role': 0,
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => SuccessPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Error"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}
