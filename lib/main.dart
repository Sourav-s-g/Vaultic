import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'VaulticLogin.dart';
import 'Auth_Gate.dart';
import 'services/hybrid_storage_service.dart';
import 'services/credential_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize secure credential service
    await CredentialService.initialize();
    
    // Validate credentials
    if (!CredentialService.validateCredentials()) {
      throw Exception(CredentialService.getValidationError());
    }

    // Initialize Supabase with secure credentials
    await Supabase.initialize(
      url: CredentialService.supabaseUrl!,
      anonKey: CredentialService.supabaseAnonKey!,
    );

    runApp(const VaulticApp());
  } catch (e) {
    // Handle credential initialization errors
    print('Failed to initialize app: $e');
    
    // Show error screen instead of crashing
    runApp(ErrorApp(error: e.toString()));
  }
}

/// Error app shown when credential initialization fails
class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vaultic - Configuration Error',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF032221),
        fontFamily: GoogleFonts.openSans().fontFamily,
      ),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  'Configuration Error',
                  style: GoogleFonts.openSans(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  style: GoogleFonts.openSans(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    main();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VaulticApp extends StatelessWidget {
  const VaulticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vaultic',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF032221),
        textTheme: GoogleFonts.openSansTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const Vaultic(), 
      debugShowCheckedModeBanner: false,
    );
  }
}

class Vaultic extends StatefulWidget {
  const Vaultic({super.key});

  @override
  State<Vaultic> createState() => _VaulticState();
}

class _VaulticState extends State<Vaultic> {
  bool _isLoading = true;
  String _loadingMessage = 'Initializing...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final startTime = DateTime.now();
    
    try {
      setState(() {
        _loadingMessage = 'Loading data...';
        _progress = 0.2;
      });

      // Load all backend data
      await _loadBackendData();
      
      // Process monthly rollover on app startup
      try {
        await HybridStorageService.processMonthlyRollover();
      } catch (e) {
        print('Monthly rollover processing failed: $e');
      }
      
      // Check and perform auto-backup if enabled
      try {
        await HybridStorageService.checkAndPerformAutoBackup();
      } catch (e) {
        print('Auto-backup check failed: $e');
      }
      
      // Process sync queue on app startup
      try {
        await HybridStorageService.processSyncQueue();
      } catch (e) {
        print('Sync queue processing failed: $e');
      }

      setState(() {
        _progress = 0.8;
        _loadingMessage = 'Almost ready...';
      });

      // Calculate minimum time (3 seconds)
      final elapsed = DateTime.now().difference(startTime);
      final remainingTime = const Duration(seconds: 3) - elapsed;
      
      if (remainingTime.inMilliseconds > 0) {
        // Animate progress bar to completion during remaining time
        const progressSteps = 20;
        final stepDuration = remainingTime.inMilliseconds ~/ progressSteps;
        
        for (int i = 0; i < progressSteps; i++) {
          await Future.delayed(Duration(milliseconds: stepDuration));
          if (mounted) {
            setState(() {
              _progress = 0.8 + (0.2 * (i + 1) / progressSteps);
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Navigate to AuthGate
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthGate()),
        );
      }
    } catch (e) {
      print('Error during app initialization: $e');
      // Even if there's an error, ensure minimum time and proceed
      final elapsed = DateTime.now().difference(startTime);
      final remainingTime = const Duration(seconds: 3) - elapsed;
      
      if (remainingTime.inMilliseconds > 0) {
        setState(() {
          _progress = 0.8;
          _loadingMessage = 'Preparing app...';
        });
        
        // Animate progress bar to completion during remaining time
        const progressSteps = 20;
        final stepDuration = remainingTime.inMilliseconds ~/ progressSteps;
        
        for (int i = 0; i < progressSteps; i++) {
          await Future.delayed(Duration(milliseconds: stepDuration));
          if (mounted) {
            setState(() {
              _progress = 0.8 + (0.2 * (i + 1) / progressSteps);
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthGate()),
        );
      }
    }
  }

  Future<void> _loadBackendData() async {
    try {
      // Check if user is authenticated
      final session = Supabase.instance.client.auth.currentSession;
      final user = session?.user;
      
      if (user != null) {
        setState(() {
          _loadingMessage = 'Syncing data...';
          _progress = 0.4;
        });
        
        // Sync data from backend
        await HybridStorageService.syncOnLogin();
      } else {
        setState(() {
          _loadingMessage = 'Preparing app...';
          _progress = 0.4;
        });
        
        // Load local data for offline mode
        await Future.wait([
          HybridStorageService.getCategories(),
          HybridStorageService.getTransactions(),
          HybridStorageService.getBudgets(),
          HybridStorageService.getOwoEntries(),
        ]);
      }
      
      setState(() {
        _loadingMessage = 'Ready!';
        _progress = 0.8;
      });
    } catch (e) {
      print('Error loading backend data: $e');
      // Continue with local data if backend fails
      setState(() {
        _loadingMessage = 'Loading offline data...';
        _progress = 0.4;
      });
      
      await Future.wait([
        HybridStorageService.getCategories(),
        HybridStorageService.getTransactions(),
        HybridStorageService.getBudgets(),
        HybridStorageService.getOwoEntries(),
      ]);
      
      setState(() {
        _progress = 0.8;
      });
    }
  }

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
            // Brand centered on screen
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
            
            // Progress bar at bottom
            if (_isLoading)
              Positioned(
                bottom: MediaQuery.of(context).size.height * 0.1,
                left: 40,
                right: 40,
                child: Column(
                  children: [
                    // Progress bar
                    Container(
                      width: double.infinity,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: (MediaQuery.of(context).size.width - 80) * _progress,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _loadingMessage,
                      style: GoogleFonts.openSans(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
