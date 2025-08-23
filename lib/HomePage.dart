import 'package:cents/VaulticLogin.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'Auth_Service.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Homepage extends StatelessWidget {
  const Homepage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: VaulticHomePage(),debugShowCheckedModeBanner: false,
    );
  }
}

class VaulticHomePage extends StatelessWidget {
  const VaulticHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Vaultichomepage(), debugShowCheckedModeBanner: false,);
  }
}

class Vaultichomepage extends StatefulWidget {
  const Vaultichomepage({super.key});

  @override
  State<Vaultichomepage> createState() => _VaultichomepageState();
}

class _VaultichomepageState extends State<Vaultichomepage> {
  final authservice = AuthService();

  Future<String> getFastLinkConfigName() async {
    // placeholder until Yodlee sends your real config name
    return 'PLACEHOLDER_CONFIG_NAME';
  }


  Future<String> getFastLinkTokenFromBackend() async {
    // TODO: Implement your network call to get token from backend
    return 'your_real_fastlink_token';
  }

  void _launchFastLink() async {
    try {
      // 1. Get the FastLink access token from your backend (make sure your backend calls Yodlee sandbox API https://sandbox.api.yodlee.com/ysl)
      final token = await getFastLinkTokenFromBackend();

      // 2. Config name from Yodlee Configuration Tool (replace with your actual config name)
      final configName = await getFastLinkConfigName();

      // 3. FastLink 4.0 sandbox URL from Yodlee developer portal for sandbox environment
      final fastLinkURL = 'https://fl4.sandbox.yodlee.com/authenticate/restserver/fastlink';

      // 4. Compose extra parameters with your config name, flow type, and deep linking intent URL for your app
      final extraParams =
          'configName=$configName&flow=add&intentUrl=myapp://fastlink-callback';

      // Navigate to FastLinkView and pass the token, URL, and extra params
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FastLinkView(
            fastLinkToken: token,
            fastLinkURL: fastLinkURL,
            extraParams: extraParams,
          ),
        ),
      );
    } catch (e) {
      print('Error launching FastLink: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to launch FastLink.')),
      );
    }
  }



  void logout() async {
    try {
      await authservice.signOut();
      // After sign out, navigate to login page and clear stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => Vaulticlogin()), // Replace with your login page class
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed.')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            opacity: 1,
            image: AssetImage('assets/Vaultabove.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          Icons.arrow_back_ios_new,
                          size: 20,
                          color: Colors.red,
                        ),
                        SizedBox(width: 10,),
                        InkWell(
                          onTap: logout,
                          child: Text(
                            'Logout',
                            style: GoogleFonts.nunito(
                              color: Colors.red,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 10),
                  ],
                ),
              ),
              SizedBox(height: 10),
              InkWell(
                onTap: _launchFastLink,
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: 15),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    // Transparent backgroundName
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.account_balance, // Bank icon
                        color: Colors.white, // Matching icon color
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Connect your bank',
                        style: GoogleFonts.nunito(
                          letterSpacing: 1,
                          color: Colors.white, // Change text color as needed
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () {},
                    child: Text(
                      'Terms and Conditions | ',
                      style: GoogleFonts.nunito(
                        color: Colors.blueAccent,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {},
                    child: Text(
                      'Safety and Privacy Policy',
                      style: GoogleFonts.nunito(
                        color: Colors.blueAccent,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
