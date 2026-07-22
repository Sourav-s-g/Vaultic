import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BrandedBackground extends StatelessWidget {
  final Widget? bottomContent;

  const BrandedBackground({super.key, this.bottomContent});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF032221),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF032221),
              Color(0xFF0D635F),
              Color(0xFF032221),
            ],
          ),
        ),
        child: Stack(
          children: [
            Center(
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
            if (bottomContent != null)
              Positioned(
                bottom: MediaQuery.of(context).size.height * 0.1,
                left: 40,
                right: 40,
                child: bottomContent!,
              ),
          ],
        ),
      ),
    );
  }
}