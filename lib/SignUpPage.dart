import 'package:cents/Auth_Service.dart';
import 'package:cents/HomePage.dart';
import 'package:cents/VaulticLogin.dart';
import 'package:cents/screens/app_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter your email and password.');
      return;
    }
    if (password.length < 8) {
      _showMessage('Your password must be at least 8 characters.');
      return;
    }
    if (password != _confirmPasswordController.text) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _authService.signUpWithEmail(email, password);
      if (!mounted) return;
      if (response.user?.identities?.isEmpty ?? false) {
        _showMessage(
          'An account with this email already exists. Please log in.',
        );
        return;
      }
      if (response.session == null) {
        _showMessage(
          'Account created. Check your email to confirm it, then log in.',
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Vaulticlogin()),
        );
      } else {
        final needsSetup = await _authService.needsAppSetup();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) =>
                    needsSetup
                        ? AppSetupScreen(
                          userEmail: response.user?.email ?? email,
                        )
                        : const Homepage(),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(AuthService.messageForError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _decoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white),
    filled: true,
    fillColor: Colors.black.withOpacity(0.3),
    prefixIcon: Icon(icon, color: Colors.white),
    suffixIcon: suffixIcon,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _passwordField(
    TextEditingController controller,
    String label, {
    TextInputAction action = TextInputAction.next,
  }) => TextField(
    controller: controller,
    style: const TextStyle(color: Colors.white),
    obscureText: _obscurePassword,
    textInputAction: action,
    onSubmitted: (_) => action == TextInputAction.done ? _signUp() : null,
    decoration: _decoration(
      label,
      Icons.lock_outline,
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        icon: Icon(
          _obscurePassword ? Icons.visibility : Icons.visibility_off,
          color: Colors.white,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF032221),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF032221), Color(0xFF0C4340), Color(0xFF032221)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed:
                            () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const Vaulticlogin(),
                              ),
                            ),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'SIGN UP',
                        style: GoogleFonts.nunito(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.newUsername],
                    decoration: _decoration('Email address', Icons.person),
                  ),
                  const SizedBox(height: 16),
                  _passwordField(_passwordController, 'Password'),
                  const SizedBox(height: 16),
                  _passwordField(
                    _confirmPasswordController,
                    'Confirm password',
                    action: TextInputAction.done,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use at least 8 characters.',
                    style: GoogleFonts.openSans(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(
                              'Create account',
                              style: GoogleFonts.openSans(
                                fontSize: 22,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
