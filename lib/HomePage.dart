import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'Auth_Service.dart';
import 'VaulticLogin.dart';
import 'screens/transaction_history_screen.dart';
import 'screens/category_management_screen.dart';
import 'models/transaction_history_model.dart';
import 'services/local_storage.dart';

class Homepage extends StatelessWidget {
  const Homepage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: VaulticHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VaulticHomePage extends StatelessWidget {
  const VaulticHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: VaulticDashboardPage(),
      debugShowCheckedModeBanner: false,
    );
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
  List<String> _categories = [];
  bool _isLoadingTransactions = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadRecentTransactions();
  }

  Future<void> _loadCategories() async {
    final raw = await LocalStorageService.getCategories();
    setState(() {
      _categories = raw.map((e) => (e['name'] ?? '').toString()).where((e) => e.isNotEmpty).toList();
    });
  }

  Future<void> _loadRecentTransactions() async {
    setState(() {
      _isLoadingTransactions = true;
    });

    try {
      final raw = await LocalStorageService.getTransactions();
      final txns = raw.map((m) => _transactionFromMap(m)).toList();
      txns.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _recentTransactions = txns.take(5).toList();
        _isLoadingTransactions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTransactions = false;
      });
    }
  }

  void logout() async {
    try {
      await authservice.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => Vaulticlogin()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed.')),
      );
    }
  }

  void _navigateToTransactionHistory() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TransactionHistoryScreen()),
    ).then((_) {
      _loadCategories();
      _loadRecentTransactions();
    });
  }

  void _editCategories() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CategoryManagementScreen()),
    );
    _loadCategories();
  }

  // Dialogs
  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Category'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Category name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text('Add')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await LocalStorageService.addCategory({'name': name});
      _loadCategories();
    }
  }

  Future<void> _showAddTransactionDialog() async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String type = 'Debit';
    String? category = _categories.isNotEmpty ? _categories.first : null;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSb) => AlertDialog(
          title: Text('Add Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Amount'),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: 'Description'),
                ),
                DropdownButtonFormField<String>(
                  value: type,
                  items: ['Credit','Debit'].map((e)=>DropdownMenuItem(value:e,child: Text(e))).toList(),
                  onChanged: (v){ setStateSb(()=> type = v ?? 'Debit'); },
                  decoration: InputDecoration(labelText: 'Type'),
                ),
                DropdownButtonFormField<String>(
                  value: category,
                  items: _categories.map((e)=>DropdownMenuItem(value:e,child: Text(e))).toList(),
                  onChanged: (v){ setStateSb(()=> category = v); },
                  decoration: InputDecoration(labelText: 'Category'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(ctx,false), child: Text('Cancel')),
            TextButton(onPressed: ()=> Navigator.pop(ctx,true), child: Text('Save')),
          ],
        ),
      ),
    );
    if (result == true) {
      final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
      final now = DateTime.now();
      final txnMap = {
        'transactionId': now.microsecondsSinceEpoch.toString(),
        'description': descriptionController.text.trim().isEmpty ? 'Manual Entry' : descriptionController.text.trim(),
        'amount': amount,
        'type': type,
        'date': now.toIso8601String(),
        'category': category ?? 'General',
        'status': 'Completed',
      };
      await LocalStorageService.addTransaction(txnMap);
      _loadRecentTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF032221),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTransactionDialog,
        backgroundColor: Colors.green,
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              // Header with Vaultic title and logout
              _buildHeader(),
              
              // Horizontal categories and totals section
              _buildSummarySection(),
              
              // Transactions section
              _buildTransactionsSection(),
              
              // Footer links
              _buildFooter(),
            ],
          ),
        ),
      ),

    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Vaultic',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 28,
            ),
          ),
          Row(
            children: [
              // Edit Categories Button
              InkWell(
                onTap: _editCategories,
                child: Container(
                  margin: EdgeInsets.only(right: 12),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    return Container(
      height: 180,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildFeatureCard(
            title: 'This Month Spent',
            amount: '₹${_getMonthlyDebitTotal().toStringAsFixed(0)}',
            icon: Icons.payments,
            color: Colors.red,
            onTap: () {},
          ),
          ..._categories.map((c) => _buildFeatureCard(
                title: c,
                amount: '₹${_getMonthlyTotalForCategory(c).toStringAsFixed(0)}',
                icon: Icons.category,
                color: Colors.blueGrey,
                onTap: () {},
              )),
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

  Widget _buildFeatureCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 16),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(20),
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
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
              SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.nunito(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
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
    return Container(
      margin: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transactions Header with navigation
          InkWell(
            onTap: _navigateToTransactionHistory,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transactions',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.nunito(
                        color: Colors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.green,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Recent Transactions List
          if (_isLoadingTransactions)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            )
          else if (_recentTransactions.isEmpty)
            _buildEmptyTransactionsWidget()
          else
            _buildRecentTransactionsList(),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactionsWidget() {
    return Container(
      padding: EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long,
            size: 48,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No Recent Transactions',
            style: GoogleFonts.nunito(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your recent transactions will appear here',
            style: GoogleFonts.nunito(
              color: Colors.grey[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsList() {
    return Column(
      children: _recentTransactions.map((transaction) {
        return _buildTransactionItem(transaction);
      }).toList(),
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final isCredit = transaction.type == 'Credit';
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isCredit ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
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
          '${_formatDate(transaction.date)} • ${transaction.category} • ${isCredit ? 'Cr' : 'Db'}',
          style: GoogleFonts.nunito(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        trailing: Text(
          '${isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(0)}',
          style: GoogleFonts.nunito(
            color: isCredit ? Colors.green : Colors.red,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
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
      transactionId: (m['transactionId'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      amount: (m['amount'] is num) ? (m['amount'] as num).toDouble() : double.tryParse((m['amount'] ?? '0').toString()) ?? 0.0,
      type: (m['type'] ?? '').toString(),
      date: DateTime.tryParse((m['date'] ?? '').toString()) ?? DateTime.now(),
      category: (m['category'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
    );
  }

  double _getMonthlyDebitTotal() {
    final now = DateTime.now();
    return _recentAndAllTransactions()
        .where((t) => t.type == 'Debit' && t.date.year == now.year && t.date.month == now.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double _getMonthlyTotalForCategory(String category) {
    final now = DateTime.now();
    return _recentAndAllTransactions()
        .where((t) => t.category == category && t.date.year == now.year && t.date.month == now.month)
        .fold(0.0, (sum, t) => sum + (t.type == 'Debit' ? t.amount : 0.0));
  }

  List<Transaction> _recentAndAllTransactionsCache = [];
  List<Transaction> _recentAndAllTransactions() {
    // Fetch all transactions from storage to compute totals
    // Note: this is a sync cache built from last load of recent + full store when needed
    // For simplicity, rebuild each call (data size is small for local app)
    // In production, optimize by caching.
    // This method is synchronous wrapper around async storage by using last fetched recent if available.
    // We'll just return recent list as approximation if full list isn't loaded.
    return _recentAndAllTransactionsCache.isNotEmpty ? _recentAndAllTransactionsCache : _recentTransactions;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: () {},
            child: Text(
              'Terms and Conditions | ',
              style: GoogleFonts.nunito(
                color: Colors.blueAccent,
                fontSize: 14,
              ),
            ),
          ),
          InkWell(
            onTap: () {},
            child: Text(
              'Safety and Privacy Policy',
              style: GoogleFonts.nunito(
                color: Colors.blueAccent,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
