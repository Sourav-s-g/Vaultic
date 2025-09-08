import 'package:cents/VaulticLogin.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Auth_Service.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'dart:async';
import 'HomePage.dart';
import 'screens/app_setup_screen.dart';
import 'services/local_storage.dart';

// Make sure Profile_Page exists in your project, or replace accordingly.
import 'screens/transaction_history_screen.dart';

class OTPVerification extends StatefulWidget {
  final String email; // Accepts email as a named parameter

  const OTPVerification({super.key, required this.email});

  @override
  State<OTPVerification> createState() => _OTPVerificationState();
}

class _OTPVerificationState extends State<OTPVerification> {
  final authservice = AuthService();
  TextEditingController otpController = TextEditingController();

  int _secondsRemaining = 60;
  bool _canResend = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void logout() async {
    try {
      await authservice.signOut();
      // After sign out, navigate to login page and clear stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => Vaulticlogin()),
        // Replace with your login page class
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed.')));
    }
  }

  void startTimer() {
    _secondsRemaining = 60;
    _canResend = false;

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void resendOTP() async {
    try {
      await Supabase.instance.client.auth.signInWithOtp(email: widget.email);
      startTimer();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('OTP resent to ${widget.email}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error resending OTP: $e')));
    }
  }

  /// Check if user has completed local app setup (categories exist locally)
  Future<bool> _hasLocalAppSetup() async {
    try {
      final categories = await LocalStorageService.getCategories();
      return categories.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Color(0xFF032221)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            // Allows scrolling if keyboard appears
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // Important: shrink Wrap Column vertically
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: logout, // Calls your logout function
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                    Text(
                      "Enter OTP",
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 38,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 60),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 1),
                  child: PinCodeTextField(
                    textStyle: TextStyle(
                      color: Colors.white, // Set your desired color here
                      fontSize: 20,
                    ),
                    appContext: context,
                    length: 6,
                    controller: otpController,
                    obscureText: false,
                    animationType: AnimationType.fade,
                    keyboardType: TextInputType.number,
                    pinTheme: PinTheme(
                      fieldOuterPadding: EdgeInsets.symmetric(horizontal: 5),
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(5),
                      fieldHeight: 50,
                      fieldWidth: 40,
                      activeColor: Color(0xFF032221),
                      selectedColor: Colors.white,
                      inactiveColor: Colors.white,
                      errorBorderColor: Colors.red,
                    ),
                    animationDuration: const Duration(milliseconds: 300),
                    onCompleted: (String enteredOtp) async {
                      final email = widget.email; // Use the passed email

                      try {
                        final response = await Supabase.instance.client.auth
                            .verifyOTP(
                              type: OtpType.email,
                              token: enteredOtp,
                              email: email,
                            );

                        if (response.session != null) {
                          // OTP verified successfully
                          print(
                            "OTP Verified, Checking bank connection status",
                          );

                          // Decide next based on local app setup
                          final hasAppSetup = await _hasLocalAppSetup();
                          if (hasAppSetup) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => Homepage()),
                            );
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AppSetupScreen(userEmail: widget.email),
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Invalid OTP. Please try again.'),
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ Error verifying OTP: $e')),
                        );
                      }
                    },
                  ),
                ),
                SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _canResend
                        ? TextButton(
                          onPressed: resendOTP,
                          child: Text(
                            'Resend OTP?',
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        )
                        : Text(
                          'Resend in $_secondsRemaining seconds',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                  ],
                ),
                SizedBox(height: 30),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.08),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Thank you for registering with us!",
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 10,),
                      Text(
                        "DO NOT SHARE THIS WITH ANYONE ELSE",
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
