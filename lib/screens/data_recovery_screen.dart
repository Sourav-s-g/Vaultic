import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data_recovery_utility.dart';
import '../services/hybrid_storage_service.dart';

class DataRecoveryScreen extends StatefulWidget {
  const DataRecoveryScreen({super.key});

  @override
  State<DataRecoveryScreen> createState() => _DataRecoveryScreenState();
}

class _DataRecoveryScreenState extends State<DataRecoveryScreen> {
  Map<String, dynamic>? _dataSources;
  bool _isLoading = false;
  bool _isRecovering = false;

  @override
  void initState() {
    super.initState();
    _checkDataSources();
  }

  Future<void> _checkDataSources() async {
    setState(() => _isLoading = true);
    try {
      final sources = await DataRecoveryUtility.checkAllDataSources();
      setState(() {
        _dataSources = sources;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking data sources: $e')),
        );
      }
    }
  }

  Future<void> _attemptRecovery() async {
    setState(() => _isRecovering = true);
    try {
      final success = await DataRecoveryUtility.attemptRecovery();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Data recovered successfully!' : 'Recovery failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) {
          _checkDataSources(); // Refresh the data
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recovery error: $e')),
        );
      }
    } finally {
      setState(() => _isRecovering = false);
    }
  }

  Future<void> _createBackup() async {
    try {
      final backup = await DataRecoveryUtility.createEmergencyBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emergency backup created: ${backup['name']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF032221), Colors.black],
            ),
          ),
          child: AppBar(
            title: Text(
              'Data Recovery',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF032221), Colors.black, Color(0xFF032221)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    if (_dataSources != null) ...[
                      _buildDataSourceCard('Local Data', _dataSources!['local_data']),
                      const SizedBox(height: 16),
                      _buildDataSourceCard('Cloud Data', _dataSources!['cloud_data']),
                      const SizedBox(height: 16),
                      _buildDataSourceCard('Backup Data', _dataSources!['backup_data']),
                      const SizedBox(height: 16),
                      _buildDataSourceCard('Migration Status', _dataSources!['migration_status']),
                      const SizedBox(height: 30),
                      _buildActionButtons(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Recovery Center',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This tool helps you check all possible sources for your lost transaction data and attempt recovery.',
            style: GoogleFonts.nunito(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSourceCard(String title, dynamic data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDataSource(data),
            style: GoogleFonts.nunito(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDataSource(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('status')) {
        switch (data['status']) {
          case 'not_authenticated':
            return 'Not logged in to cloud';
          case 'authenticated':
            return 'Found ${data['transactions_count']} transactions, ${data['categories_count']} categories';
          case 'error':
            return 'Error: ${data['error']}';
          case 'no_backup':
            return 'No backup found';
          case 'backup_found':
            return 'Backup from ${data['timestamp']} with ${data['transactions_count']} transactions';
          case 'backup_corrupted':
            return 'Backup corrupted: ${data['error']}';
          default:
            return data.toString();
        }
      } else if (data.isNotEmpty) {
        return 'Found ${data.length} data entries';
      } else {
        return 'No data found';
      }
    }
    return data.toString();
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isRecovering ? null : _attemptRecovery,
            icon: _isRecovering
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download),
            label: Text(_isRecovering ? 'Recovering...' : 'Attempt Recovery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _createBackup,
            icon: const Icon(Icons.backup),
            label: const Text('Create Emergency Backup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _checkDataSources,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Data Sources'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
