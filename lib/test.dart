import 'package:flutter/material.dart';

void main() {
  runApp(test());
}

class test extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vaultic',
      debugShowCheckedModeBanner: false,
      home: VaulticSixBoxPage(),
    );
  }
}

class VaulticSixBoxPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Test Page',
          style: TextStyle(color: Colors.white, fontSize: 25),
        ),
        backgroundColor: Colors.black,
      ),
      // solid green background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF032221),
              Colors.black,
              Color(0xFF032221), // Olive Green hex code
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0), // page padding
          child: GridView.count(
            crossAxisCount: 2, // 2 columns, 3 rows
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            children: List.generate(6, (index) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05), // transparent
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    // subtle border for clarity
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Box ${index + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
