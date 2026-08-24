import 'dart:async';

import 'package:cents/Auth_Service.dart';
import 'package:cents/HomePage.dart';
import 'package:cents/SignUpPage.dart';
import 'package:cents/screens/app_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Vaulticlogin extends StatefulWidget {
  const Vaulticlogin({super.key});

  @override
  State<Vaulticlogin> createState() => _VaulticloginState();
}

class _VaulticloginState extends State<Vaulticlogin> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Rotating quote state for the header (Login page quotes)
  static const List<String> _quotes = [
    "Vaultic helps you know how you got broke.",
    "Checking if your wallet survived the weekend.",
    "Back for more financial accountability, are we?",
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
    _quoteTimer?.cancel();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email and password.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _authService.loginWithEmail(email, password);
      if (!mounted) return;
      final needsSetup = await _authService.needsAppSetup();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder:
              (_) =>
          needsSetup
              ? AppSetupScreen(userEmail: response.user?.email ?? email)
              : const Homepage(),
        ),
            (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.messageForError(error))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email address first.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists, a password-reset email has been sent.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.messageForError(error))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
      filled: true,
      fillColor: Colors.black.withOpacity(0.3),
      prefixIcon: Icon(icon, color: Colors.white, size: 16),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF032221),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF032221), Color(0xFF08413E), Color(0xFF032221)],
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
                  'Login',
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: _decoration(
                    label: 'Email address',
                    icon: Icons.person,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _isLoading ? null : _login(),
                  decoration: _decoration(
                    label: 'Password',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      onPressed:
                          () => setState(
                            () => _obscurePassword = !_obscurePassword,
                      ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _sendPasswordReset,
                    child: const Text('Forgot password?', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                    _isLoading
                        ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      'Log in',
                      style: GoogleFonts.openSans(
                        fontSize: 14,
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
                      "Don't have an account?",
                      style: GoogleFonts.openSans(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap:
                          () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignUpPage(),
                        ),
                      ),
                      child: Text(
                        'Sign up',
                        style: GoogleFonts.openSans(
                          fontSize: 12,
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