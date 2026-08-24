import 'dart:async';

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

  // Rotating quote state for the header (Sign Up page quotes)
  static const List<String> _quotes = [
    "Track every detail, save more... hopefully.",
    "Step one: Facing the reality of your transaction history.",
    "Where your money learns to behave itself.",
  ];
  int _quoteIndex = 0;
  Timer? _quoteTimer;

  @override
  void initState() {
    super.initState();
    _quoteTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() => _quoteIndex = (_quoteIndex + 1) % _quotes.length);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _quoteTimer?.cancel();
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
    labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
    filled: true,
    fillColor: Colors.black.withOpacity(0.3),
    prefixIcon: Icon(icon, color: Colors.white, size: 18),
    suffixIcon: suffixIcon,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _passwordField(
      TextEditingController controller,
      String label, {
        TextInputAction action = TextInputAction.next,
      }) => TextField(
    controller: controller,
    style: const TextStyle(color: Colors.white, fontSize: 13),
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
          size: 18,
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
        // Single flowing column, like LocoBite's login step: header block
        // (name + rotating caption) directly above the form, no separate
        // floating card and no independent centering.
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Line 1 — brand name, static (mirrors LocoBite's app name)
                Text(
                  'Vaultic',
                  style: GoogleFonts.nunito(
                    fontSize: 32,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),

                // Line 2 — rotating quote, in place of LocoBite's static
                // tagline
                SizedBox(
                  height: 20,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) {
                      final offsetAnimation = Tween<Offset>(
                        begin: const Offset(0, 0.25),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      _quotes[_quoteIndex],
                      key: ValueKey<int>(_quoteIndex),
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Page heading, above the fields (same as before)
                Text(
                  'Sign Up',
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
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
                  style: GoogleFonts.openSans(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                    _isLoading
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      'Create account',
                      style: GoogleFonts.openSans(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Have an account?",
                      style: GoogleFonts.openSans(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap:
                          () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const Vaulticlogin(),
                        ),
                      ),
                      child: Text(
                        'Sign in',
                        style: GoogleFonts.openSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}