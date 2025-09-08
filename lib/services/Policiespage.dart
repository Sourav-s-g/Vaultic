import 'package:flutter/material.dart';

class PoliciesPage extends StatelessWidget {
  const PoliciesPage({Key? key}) : super(key: key);

  final String termsAndConditions = '''
Vaultic Terms and Conditions

1. Introduction
Vaultic is an expense tracking app that aggregates and syncs your bank transaction data to provide insights into your monthly spending and savings. By using Vaultic, you agree to these Terms and Conditions.

2. User Account and Security
Users must provide accurate account information and maintain the confidentiality of their login credentials. Vaultic is not responsible for unauthorized access due to user negligence.

3. Data Use and Privacy
Vaultic collects financial transaction data from linked bank accounts solely to provide expense tracking services. This data is handled according to our Privacy Policy.

4. Service Availability
While Vaultic strives for continuous service, we do not guarantee uninterrupted access and are not liable for any downtime or data loss.

5. User Responsibilities
Users agree to use Vaultic lawfully and not for fraudulent activities. Misuse may lead to suspension or termination of accounts.

6. Limitation of Liability
Vaultic is not liable for financial decisions based on app data or any third-party service interruptions affecting transaction syncing.

7. Changes to Terms
We reserve the right to update these Terms at any time. Users will be notified of major changes.
''';

  final String safetyPrivacyPolicy = '''
Vaultic Safety and Privacy Policy

1. Data Security
Vaultic uses advanced encryption to store and transmit your financial data. User authentication includes options such as biometric security (Face ID, fingerprint) and multi-factor authentication.

2. Data Collection
We collect only necessary data related to your linked bank transactions to provide our services. We do not sell or share your personal data with unauthorized third parties.

3. User Consent
By connecting your bank accounts, you consent to the retrieval and processing of transaction data.

4. Data Storage
Your data is securely stored in cloud databases with strict access controls. We retain data only as long as necessary for service provision.

5. User Controls
Users can delete their account at any time, which will remove their data from our systems, subject to legal retention requirements.

6. Compliance
Vaultic complies with relevant data protection regulations including GDPR and local financial data privacy laws.

7. Contact
For any privacy concerns, users can contact our support at support@vaultic.app.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Privacy'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms and Conditions',
              style: Theme.of(context).textTheme.headline6,
            ),
            const SizedBox(height: 8),
            Text(
              termsAndConditions,
              style: Theme.of(context).textTheme.bodyText2,
            ),
            const SizedBox(height: 24),
            Text(
              'Safety and Privacy Policy',
              style: Theme.of(context).textTheme.headline6,
            ),
            const SizedBox(height: 8),
            Text(
              safetyPrivacyPolicy,
              style: Theme.of(context).textTheme.bodyText2,
            ),
          ],
        ),
      ),
    );
  }
}
