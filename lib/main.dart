import 'package:cents/VaulticLogin.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ckgiscyxxpvkpbsmppht.supabase.co',

    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNrZ2lzY3l4eHB2a3Bic21wcGh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUwMDIxNjUsImV4cCI6MjA3MDU3ODE2NX0.weCZHPNOjYpqhNMAEQB5orlcgY-mu9EjHTe5Vu713CY',
  );

  runApp(VaulticApp());
}

class VaulticApp extends StatelessWidget {
  const VaulticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Vaultic(), debugShowCheckedModeBanner: false);
  }
}

class Vaultic extends StatefulWidget {
  const Vaultic({super.key});

  @override
  State<Vaultic> createState() => _VaulticState();
}

class _VaulticState extends State<Vaultic> {
  @override
  void initState() {
    super.initState();

    // Delay for 2 seconds, then navigate
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Vaulticlogin()),
      );
    });
  }

  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          //image: DecorationImage(
          //  image: AssetImage('assets/img.png'),
          //  fit: BoxFit.cover,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Color(0xFF032221),
              Color(0xFF032221),
              Colors.black, // Olive Green hex code
            ],
          ),
        ),
        child: Center(
          child: Container(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Vaultic',
                  style: GoogleFonts.montserrat(
                    letterSpacing: 4,
                    color: Colors.white,
                    fontSize: 70,
                  ),
                ),
                Text(
                  'Your Smart Vault',
                  style: GoogleFonts.openSans(
                    color: Colors.white,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
