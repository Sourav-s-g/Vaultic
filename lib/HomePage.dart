import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Auth_Service.dart';
import 'VaulticLogin.dart';
import 'screens/transaction_history_screen.dart';
import 'screens/category_management_screen.dart';
import 'models/transaction_history_model.dart';
import 'services/hybrid_storage_service.dart';
import 'screens/category_transactions_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/owo_screen.dart';
import 'models/trip.dart';
import 'services/trip_storage_service.dart';
import 'screens/trip_page.dart';
import 'models/parsed_transaction.dart';
import 'services/smart_input_parser.dart';

class Homepage extends StatelessWidget {
  const Homepage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VaulticDashboardPage();
  }
}

class VaulticDashboardPage extends StatefulWidget {
  const VaulticDashboardPage({super.key});

  @override
  State<VaulticDashboardPage> createState() => _VaulticDashboardPageState();
}

class _VaulticDashboardPageState extends State<VaulticDashboardPage> {
  final authservice = AuthService();
  List<Transaction> _recentTransactions = [];
  List<Map<String, dynamic>> _recentTransactionsRaw = []; // Store raw maps for sync status
  List<String> _categories = [];
  bool _isLoadingTransactions = false;
  

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadAllTransactions();
    // Check for offline mode after initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOfflineMode();
    });
  }

  void _checkOfflineMode() async {
    // Wait a bit for data to load
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    // Check if user is not authenticated (offline mode)
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final user = session?.user;
      
      if (user == null) {
        // User is in offline mode - show snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_off, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You are offline. Data is available locally. You may need to re-login to sync with cloud.',
                    style: GoogleFonts.nunito(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.withOpacity(0.9),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      // If there's an error checking session, assume offline
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_off, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You are offline. Data is available locally. You may need to re-login to sync with cloud.',
                    style: GoogleFonts.nunito(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.withOpacity(0.9),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadCategories() async {
    final raw = await HybridStorageService.getCategories();
    if (mounted) {
      setState(() {
        _categories =
            raw
                .map((e) => (e['name'] ?? '').toString())
                .where((e) => e.isNotEmpty)
                .toList();
      });
    }
  }


  void logout() async {
    try {
      await authservice.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Vaulticlogin()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logout failed.')));
    }
  }

  void _navigateToTransactionHistory() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransactionHistoryScreen()),
    ).then((_) {
      _loadCategories();
      _loadAllTransactions();
    });
  }

  void _editCategories() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CategoryManagementScreen()),
    );
    _loadCategories();
  }

  // Dialogs
  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0E1F1F),
            title: const Text('Add Category', style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Category name',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Add', style: TextStyle(color: Colors.green)),
              ),
            ],
          ),
    );
    if (name != null && name.isNotEmpty) {
      await HybridStorageService.addCategory({'name': name});
      _loadCategories();
    }
  }

  Future<void> _showAddTransactionDialog({ParsedTransaction? parsedTransaction}) async {
    final nlpController = TextEditingController();
    final amountController = TextEditingController(
      text: parsedTransaction?.amount?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: parsedTransaction?.description ?? '',
    );
    String type = parsedTransaction?.type ?? 'Debit';
    String? category = parsedTransaction?.category ?? 
        (_categories.isNotEmpty ? _categories.first : null);
    DateTime selectedDate = parsedTransaction?.date ?? DateTime.now();
    ParsedTransaction? currentParsed;
    
    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setStateSb) {
                  // Parse NLP input when text changes
                  void parseNlpInput(String text) {
                    if (text.trim().isEmpty) {
                      setStateSb(() {
                        currentParsed = null;
                      });
                      return;
                    }
                    final parsed = SmartInputParser.parseInput(text, _categories);
                    setStateSb(() {
                      currentParsed = parsed;
                      // Update amount if parsed
                      if (parsed.amount != null) {
                        amountController.text = parsed.amount.toString();
                      }
                      // Update description if parsed
                      if (parsed.description.isNotEmpty && parsed.description != 'Transaction') {
                        descriptionController.text = parsed.description;
                      }
                      // Update type if parsed
                      if (parsed.type != null) {
                        type = parsed.type!;
                        // If type changes to Credit, clear category
                        if (type == 'Credit') {
                          category = null;
                        }
                      }
                      // Update category if parsed and type is Debit
                      if (parsed.category != null && parsed.type != 'Credit') {
                        // Only set category if it exists in available categories
                        if (_categories.contains(parsed.category)) {
                          category = parsed.category;
                        } else if (_categories.isNotEmpty) {
                          // Fallback to first category if parsed category not found
                          category = _categories.first;
                        }
                      }
                      // Update date if parsed
                      if (parsed.date != null) {
                        selectedDate = parsed.date!;
                      }
                    });
                  }
                  
                  return AlertDialog(
                    backgroundColor: const Color(0xFF0E1F1F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text('New Transaction', style: GoogleFonts.nunito(color: Colors.white)),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // NLP Input Field
                          TextField(
                            controller: nlpController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Quick Add (e.g., "Lunch 250 Food")',
                              labelStyle: const TextStyle(color: Colors.white70),
                              hintText: 'Type: "Lunch 250" or "Got ₹500 salary"',
                              hintStyle: const TextStyle(color: Colors.white38),
                              prefixIcon: const Icon(Icons.edit_note, color: Colors.white70),
                              suffixIcon: currentParsed != null && currentParsed!.hasAmount
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            currentParsed!.type == 'Credit' ? Icons.arrow_downward : Icons.arrow_upward,
                                            size: 14,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '₹${currentParsed!.amount!.toStringAsFixed(0)}',
                                            style: GoogleFonts.nunito(
                                              color: Colors.green,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (currentParsed!.hasCategory) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              '• ${currentParsed!.category}',
                                              style: GoogleFonts.nunito(
                                                color: Colors.green.withOpacity(0.8),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    )
                                  : null,
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.white24),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.green),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (text) => parseNlpInput(text),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: amountController,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Amount',
                                    labelStyle: const TextStyle(color: Colors.white70),
                                    prefixIcon: const Icon(Icons.currency_rupee, color: Colors.white70),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.white24),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.green),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: descriptionController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Description',
                                    labelStyle: const TextStyle(color: Colors.white70),
                                    prefixIcon: const Icon(Icons.edit_note, color: Colors.white70),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.white24),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.green),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: Colors.green,
                                      onPrimary: Colors.white,
                                      surface: Color(0xFF0E1F1F),
                                      onSurface: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (date != null) {
                              setStateSb(() => selectedDate = date);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.white70),
                                const SizedBox(width: 12),
                                Text(
                                  'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_drop_down, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: type,
                                items: ['Credit', 'Debit']
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e, style: const TextStyle(color: Colors.white)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  setStateSb(() {
                                    type = v ?? 'Debit';
                                    if (type == 'Credit') {
                                      category = null;
                                    } else if (type == 'Debit' && category == null && _categories.isNotEmpty) {
                                      category = _categories.first;
                                    }
                                  });
                                },
                                decoration: InputDecoration(
                                  labelText: 'Type',
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  prefixIcon: const Icon(Icons.swap_vert, color: Colors.white70),
                                  isDense: true,
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Colors.white24),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Colors.green),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                dropdownColor: const Color(0xFF0E1F1F),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (type == 'Debit')
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: category ?? (_categories.isNotEmpty ? _categories.first : null),
                                  items: _categories
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e, style: const TextStyle(color: Colors.white)),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    setStateSb(() => category = v);
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Category',
                                    labelStyle: const TextStyle(color: Colors.white70),
                                    prefixIcon: const Icon(Icons.category, color: Colors.white70),
                                    isDense: true,
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.white24),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.green),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  dropdownColor: const Color(0xFF0E1F1F),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Save', style: TextStyle(color: Colors.green)),
                    ),
                  ],
                );
                },
          ),
    );
    if (result == true) {
      final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
      final txnMap = {
        'transactionId': const Uuid().v4(),
        'description':
            descriptionController.text.trim().isEmpty
                ? 'Manual Entry'
                : descriptionController.text.trim(),
        'amount': amount,
        'type': type,
        'date': selectedDate.toIso8601String(),
        'category': type == 'Credit' ? '' : (category ?? 'General'),
        'status': 'Completed',
        'isSplit': false,
        'splitCount': 1,
      };
      await HybridStorageService.addTransaction(txnMap);
      _loadAllTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF032221),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              heroTag: 'settings_fab_parallel',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              backgroundColor: Colors.green,
              child: const Icon(Icons.settings, color: Colors.white),
            ),
            FloatingActionButton(
              heroTag: 'add_txn_fab',
              onPressed: () => _showAddTransactionDialog(),
              backgroundColor: Colors.green,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF032221), Color(0xFF0C4340), Color(0xFF032221)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              children: [
                _buildHeader(),
                _buildSummarySection(),
                _buildTransactionsSection(),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Vaultic',
            style: GoogleFonts.nunito(color: Colors.white, fontSize: 28),
          ),
          Row(
            children: [
              // Edit Categories Button
              InkWell(
                onTap: _editCategories,
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Text(
                    'Edit Categories',
                    style: GoogleFonts.nunito(
                      color: Colors.orange,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // Logout Button
              InkWell(
                onTap: logout,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Text(
                    'Logout',
                    style: GoogleFonts.nunito(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    // Sort categories by amount (highest first) and create cards
    final categoryCards = _categories.map((c) {
      final amount = _getMonthlyTotalForCategory(c);
      return MapEntry(c, amount);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      height: 180,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildFeatureCard(
            title: 'This Month Spent',
            amount: '₹${_getMonthlyDebitTotal().toStringAsFixed(0)}',
            icon: Icons.payments,
            color: Colors.red,
            onTap: _navigateToTransactionHistory,
          ),
          ...categoryCards.map(
            (entry) => _buildFeatureCard(
              title: entry.key,
              amount: '₹${entry.value.toStringAsFixed(0)}',
              icon: Icons.category,
              color: _getCategoryColor(entry.key),
              onTap: () {
                _openCategoryTransactions(entry.key);
              },
            ),
          ),
          _buildFeatureCard(
            title: 'Add Category',
            amount: '+',
            icon: Icons.add,
            color: Colors.green,
            onTap: _showAddCategoryDialog,
          ),
        ],
      ),
    );
  }

  void _openCategoryTransactions(String category) {
    const allDebit = false;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => CategoryTransactionsScreen(
              category: allDebit ? 'This Month Spent' : category,
              allDebit: allDebit,
            ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.nunito(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                amount,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsSection() {
    return DefaultTabController(
      length: 4,
      child: Container(
        margin: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TabBar(
              isScrollable: true,
              labelColor: Colors.green,
              unselectedLabelColor: Colors.white,
              indicatorColor: Colors.green,
              tabs: [
                Tab(text: 'Transactions'),
                Tab(text: 'OWO'),
                Tab(text: 'Monthly'),
                Tab(text: 'My Trips'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: TabBarView(
                children: [
                  _buildTabTransactions(),
                  const OwesOwnsScreen(contentOnly: true),
                  _buildTabMonthly(),
                  _buildTabMyTrips(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabTransactions() {
    if (_isLoadingTransactions) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      );
    }
    if (_recentTransactions.isEmpty) return _buildEmptyTransactionsWidget();

    final items = _recentTransactions.take(4).toList();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        ..._buildGroupedByDate(items),
        InkWell(
          onTap: _navigateToTransactionHistory,
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('View all', style: GoogleFonts.nunito(color: Colors.green, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_ios, color: Colors.green, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabMonthly() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: HybridStorageService.getTransactions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          );
        }
        final txns = snapshot.data!.map((m) => _transactionFromMap(m)).toList();
        final now = DateTime.now();
        final byMonth = <String, double>{};
        for (final t in txns) {
          if (t.date.year == now.year && t.date.month == now.month) continue;
          final key =
              '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
          final amount = t.type == 'Credit' ? t.amount : -t.amount;
          byMonth[key] = (byMonth[key] ?? 0) + amount;
        }
        if (byMonth.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.calendar_month, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No Previous Month Data',
                  style: GoogleFonts.nunito(
                    color: Colors.grey[400],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your previous months transactions will appear here',
                  style: GoogleFonts.nunito(color: Colors.grey[500], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        final entries =
            byMonth.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
        return ListView(
          children:
              entries.map((e) {
                final isPositive = e.value >= 0;
                return GestureDetector(
                  onTap: () => _showMonthDetailsDialog(e.key, txns),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatMonthLabel(e.key),
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${isPositive ? "+" : "-"}₹${e.value.abs().toStringAsFixed(0)}',
                          style: GoogleFonts.nunito(
                            color: isPositive ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildEmptyTransactionsWidget() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Recent Transactions',
            style: GoogleFonts.nunito(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recent transactions will appear here',
            style: GoogleFonts.nunito(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final isCredit = transaction.type == 'Credit';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color:
                isCredit
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getTransactionIcon(transaction.category),
            color: isCredit ? Colors.green : Colors.red,
            size: 24,
          ),
        ),
        title: Text(
          transaction.description,
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${_formatDate(transaction.date)} • ${transaction.category} • ${isCredit ? "Cr" : "Db"}',
          style: GoogleFonts.nunito(color: Colors.grey[400], fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show cloud-off icon if transaction is pending sync
            Builder(
              builder: (context) {
                final txnRaw = _recentTransactionsRaw.firstWhere(
                  (t) => (t['transactionId'] ?? '').toString() == transaction.transactionId,
                  orElse: () => <String, dynamic>{},
                );
                final isPending = txnRaw.isNotEmpty && 
                    (txnRaw['_syncStatus'] ?? 'synced').toString() == 'pending';
                
                return isPending
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.cloud_off,
                          size: 16,
                          color: Colors.orange.withOpacity(0.7),
                        ),
                      )
                    : const SizedBox.shrink();
              },
            ),
            Text(
              '${isCredit ? "+" : "-"}₹${transaction.amount.toStringAsFixed(0)}',
              style: GoogleFonts.nunito(
                color: isCredit ? Colors.green : Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTransactionIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'education':
        return Icons.school;
      case 'income':
        return Icons.account_balance_wallet;
      case 'transport':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      default:
        return Icons.receipt;
    }
  }

  // Helpers
  Transaction _transactionFromMap(Map<String, dynamic> m) {
    return Transaction(
      transactionId: (m['transactionId'] ?? m['transaction_id'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      amount:
          (m['amount'] is num)
              ? (m['amount'] as num).toDouble()
              : double.tryParse((m['amount'] ?? '0').toString()) ?? 0.0,
      type: (m['type'] ?? '').toString(),
      date: DateTime.tryParse((m['date'] ?? '').toString()) ?? DateTime.now(),
      category: (m['category'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
    );
  }

  double _getMonthlyDebitTotal() {
    final now = DateTime.now();
    return _recentAndAllTransactions()
        .where(
          (t) =>
              t.type == 'Debit' &&
              t.date.year == now.year &&
              t.date.month == now.month,
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double _getMonthlyTotalForCategory(String category) {
    final now = DateTime.now();
    return _recentAndAllTransactions()
        .where(
          (t) =>
              t.category == category &&
              t.date.year == now.year &&
              t.date.month == now.month,
        )
        .fold(0.0, (sum, t) => sum + (t.type == 'Debit' ? t.amount : 0.0));
  }

  Color _getCategoryColor(String category) {
    // Generate consistent colors for categories
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
      Colors.deepOrange,
      Colors.lightBlue,
    ];
    final index = category.hashCode % colors.length;
    return colors[index];
  }

  List<Transaction> _recentAndAllTransactionsCache = [];

  List<Transaction> _recentAndAllTransactions() {
    // Return cached transactions if available, otherwise return recent transactions as fallback
    return _recentAndAllTransactionsCache.isNotEmpty
        ? _recentAndAllTransactionsCache
        : _recentTransactions;
  }

  Future<void> _loadAllTransactions() async {
    try {
      final raw = await HybridStorageService.getTransactions();
      final txns = raw.map((m) => _transactionFromMap(m)).toList();
      txns.sort((a, b) => b.date.compareTo(a.date));
      if (mounted) {
        setState(() {
          _recentAndAllTransactionsCache = txns;
          _recentTransactions = txns.take(5).toList();
          _recentTransactionsRaw = raw.take(5).toList(); // Store raw maps
          _isLoadingTransactions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
        });
      }
    }
  }

  String _formatMonthLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    final year = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 1;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final mName = months[(month - 1).clamp(0, 11)];
    return "$mName $year";
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}";
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyScreen()),
              );
            },
            child: Text(
              'Safety & Privacy Policy',
              style: GoogleFonts.nunito(color: Colors.blueAccent, fontSize: 14),
            ),
          ),
          const SizedBox(height: 30,),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedByDate(List<Transaction> txns) {
    final grouped = <String, List<Transaction>>{};
    for (final t in txns) {
      final key = "${t.date.year}-${t.date.month}-${t.date.day}";
      grouped.putIfAbsent(key, ()=> []).add(t);
    }
    DateTime parseKey(String k){ final p=k.split('-'); return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2])); }
    final keys = grouped.keys.toList()..sort((a,b)=> parseKey(b).compareTo(parseKey(a)));
    final widgets = <Widget>[];
    for (final k in keys) {
      final dt = parseKey(k);
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(_formatDate(dt), style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
      ));
      widgets.addAll(grouped[k]!.map(_buildTransactionItem));
    }
    return widgets;
  }

  Widget _buildTabMyTrips() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Add Trips Container
          GestureDetector(
            onTap: _showCreateTripDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Trips',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.add,
                    color: Colors.green,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Trips List
          Expanded(
            child: FutureBuilder<List<Trip>>(
              future: TripStorageService.getTrips(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  );
                }
                
                final trips = snapshot.data!;
                if (trips.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.flight_takeoff,
                          color: Colors.white.withOpacity(0.3),
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No trips yet',
                          style: GoogleFonts.nunito(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first trip to get started',
                          style: GoogleFonts.nunito(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    return _buildTripCard(trip);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showMonthDetailsDialog(String monthKey, List<Transaction> allTransactions) {
    // Parse month key (format: "2024-09")
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    
    // Filter transactions for this month
    final monthTransactions = allTransactions.where((t) {
      return t.date.year == year && t.date.month == month;
    }).toList();
    
    // Calculate total income and expense
    final totalIncome = monthTransactions.where((t) => t.type == 'Credit').fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = monthTransactions.where((t) => t.type == 'Debit').fold(0.0, (sum, t) => sum + t.amount);
    final netSavings = totalIncome - totalExpense;
    
    // Group by category and calculate daily averages
    final categoryData = <String, Map<String, dynamic>>{};
    
    for (final t in monthTransactions) {
      if (t.type != 'Debit') continue;
      if (!categoryData.containsKey(t.category)) {
        categoryData[t.category] = {
          'total': 0.0,
          'days': <int>{},
        };
      }
      categoryData[t.category]!['total'] += t.amount;
      categoryData[t.category]!['days'].add(t.date.day);
    }
    
    // Calculate average per day for each category
    final categoryExpenses = <String, Map<String, double>>{};
    for (final entry in categoryData.entries) {
      final category = entry.key;
      final total = entry.value['total'] as double;
      final daysUsed = (entry.value['days'] as Set<int>).length;
      final avgPerDay = daysUsed > 0 ? total / daysUsed : 0.0;
      
      categoryExpenses[category] = {
        'total': total,
        'avgPerDay': avgPerDay,
        'daysUsed': daysUsed.toDouble(),
      };
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          _formatMonthLabel(monthKey),
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Income & Expense Summary
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Text('Income', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12)),
                            Text('₹${totalIncome.toStringAsFixed(0)}', style: GoogleFonts.nunito(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Text('Expense', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12)),
                            Text('₹${totalExpense.toStringAsFixed(0)}', style: GoogleFonts.nunito(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Net Savings
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (netSavings >= 0 ? Colors.green : Colors.red).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(netSavings >= 0 ? 'Net Savings' : 'Overspent', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text('${netSavings >= 0 ? "+" : "-"}₹${netSavings.abs().toStringAsFixed(0)}', style: GoogleFonts.nunito(color: netSavings >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                if (categoryExpenses.isNotEmpty) ...[
                  Text(
                    'Expense Breakdown',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Category List
                  ...categoryExpenses.entries.map((entry) {
                    final categoryData = entry.value;
                    final total = categoryData['total']!;
                    final avgPerDay = categoryData['avgPerDay']!;
                    final daysUsed = categoryData['daysUsed']!.toInt();
                    final percentage = totalExpense > 0 ? (total / totalExpense * 100) : 0;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '₹${total.toStringAsFixed(0)} (${percentage.toStringAsFixed(1)}%)',
                                style: GoogleFonts.nunito(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Avg/day: ₹${avgPerDay.toStringAsFixed(0)}',
                                style: GoogleFonts.nunito(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Used $daysUsed days',
                                style: GoogleFonts.nunito(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
        ),
        actions: [
          // Add Transaction button
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showAddTransactionDialogForMonth(year, month);
            },
            icon: const Icon(Icons.add, color: Colors.green),
            label: Text(
              'Add Transaction',
              style: GoogleFonts.nunito(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.nunito(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show add transaction dialog with month/year pre-filled
  Future<void> _showAddTransactionDialogForMonth(int year, int month) async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String type = 'Debit';
    String? category = _categories.isNotEmpty ? _categories.first : null;
    // Pre-fill with middle of the selected month
    DateTime selectedDate = DateTime(year, month, 15);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSb) => AlertDialog(
          backgroundColor: const Color(0xFF0E1F1F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Add Transaction - ${_formatMonthLabel("$year-${month.toString().padLeft(2, '0')}")}',
            style: GoogleFonts.nunito(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.currency_rupee, color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.green),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.edit_note, color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.green),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(year, month, 1),
                      lastDate: DateTime(year, month + 1, 0),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Colors.green,
                              onPrimary: Colors.white,
                              surface: Color(0xFF0E1F1F),
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setStateSb(() => selectedDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white70),
                        const SizedBox(width: 12),
                        Text(
                          'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  items: ['Credit', 'Debit']
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e, style: const TextStyle(color: Colors.white)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setStateSb(() => type = v ?? 'Debit');
                  },
                  decoration: InputDecoration(
                    labelText: 'Type',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.swap_vert, color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.green),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  dropdownColor: const Color(0xFF0E1F1F),
                ),
                if (type == 'Debit') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    items: _categories
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e, style: const TextStyle(color: Colors.white)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setStateSb(() => category = v);
                    },
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.category, color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.green),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    dropdownColor: const Color(0xFF0E1F1F),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      ),
    );
    
    if (result == true) {
      final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
      final txnMap = {
        'transactionId': const Uuid().v4(),
        'description':
            descriptionController.text.trim().isEmpty
                ? 'Manual Entry'
                : descriptionController.text.trim(),
        'amount': amount,
        'type': type,
        'date': selectedDate.toIso8601String(),
        'category': type == 'Credit' ? '' : (category ?? 'General'),
        'status': 'Completed',
        'isSplit': false,
        'splitCount': 1,
      };
      await HybridStorageService.addTransaction(txnMap);
      _loadAllTransactions();
    }
  }

  void _showCreateTripDialog() {
    final tripNameController = TextEditingController();
    final selectedCategories = <String>{};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            'Create New Trip',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trip Name Input
                Text(
                  'Trip Name',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: tripNameController,
                  style: GoogleFonts.nunito(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter trip name...',
                    hintStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Category Selection
                Text(
                  'Select Categories',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Category Checkboxes
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = selectedCategories.contains(category);
                      
                      return CheckboxListTile(
                        title: Text(
                          category,
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              selectedCategories.add(category);
                            } else {
                              selectedCategories.remove(category);
                            }
                          });
                        },
                        activeColor: Colors.green,
                        checkColor: Colors.white,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (tripNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a trip name')),
                  );
                  return;
                }
                
                if (selectedCategories.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select at least one category')),
                  );
                  return;
                }
                
                Navigator.of(context).pop();
                
                // Show budget setup dialog
                _showBudgetSetupDialog(tripNameController.text.trim(), selectedCategories.toList());
              },
              child: const Text(
                'Next',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBudgetSetupDialog(String tripName, List<String> categories) {
    final budgetController = TextEditingController();
    final categoryBudgetControllers = <String, TextEditingController>{};
    
    // Initialize controllers for each category
    for (final category in categories) {
      categoryBudgetControllers[category] = TextEditingController();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            'Set Budget (Optional)',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You can set a total budget and/or individual category budgets for this trip.',
                  style: GoogleFonts.nunito(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Total Budget
                Text(
                  'Total Budget (Optional)',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: budgetController,
                  style: GoogleFonts.nunito(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter total budget...',
                    hintStyle: const TextStyle(color: Colors.white70),
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Category Budgets
                Text(
                  'Category Budgets (Optional)',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final controller = categoryBudgetControllers[category]!;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: controller,
                          style: GoogleFonts.nunito(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: category,
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixText: '₹ ',
                            prefixStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.green),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Create trip without budget
                final trip = Trip(
                  tripId: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: tripName,
                  categories: categories,
                  createdAt: DateTime.now(),
                );
                
                await TripStorageService.addTrip(trip);
                if (!mounted) return;
                Navigator.of(context).pop();
                
                // Navigate to trip page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TripPage(trip: trip),
                  ),
                );
              },
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                // Parse budgets
                double? totalBudget;
                Map<String, double>? categoryBudgets;
                
                if (budgetController.text.trim().isNotEmpty) {
                  totalBudget = double.tryParse(budgetController.text.trim());
                }
                
                final categoryBudgetMap = <String, double>{};
                for (final entry in categoryBudgetControllers.entries) {
                  if (entry.value.text.trim().isNotEmpty) {
                    final amount = double.tryParse(entry.value.text.trim());
                    if (amount != null && amount > 0) {
                      categoryBudgetMap[entry.key] = amount;
                    }
                  }
                }
                
                if (categoryBudgetMap.isNotEmpty) {
                  categoryBudgets = categoryBudgetMap;
                }
                
                // Create trip with budget
                final trip = Trip(
                  tripId: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: tripName,
                  categories: categories,
                  createdAt: DateTime.now(),
                  budget: totalBudget,
                  categoryBudgets: categoryBudgets,
                );
                
                await TripStorageService.addTrip(trip);
                if (!mounted) return;
                Navigator.of(context).pop();
                
                // Navigate to trip page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TripPage(trip: trip),
                  ),
                );
              },
              child: const Text(
                'Create',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TripPage(trip: trip),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.flight_takeoff,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.name,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${trip.categories.length} categories • ${_formatDate(trip.createdAt)}',
                    style: GoogleFonts.nunito(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
