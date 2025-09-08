import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'Auth_Service.dart';
import 'VaulticLogin.dart';
import 'screens/transaction_history_screen.dart';
import 'screens/category_management_screen.dart';
import 'models/transaction_history_model.dart';
import 'services/local_storage.dart';
import 'screens/category_transactions_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/settings_screen.dart';

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
    _loadAllTransactions();
  }

  Future<void> _loadCategories() async {
    final raw = await LocalStorageService.getCategories();
    setState(() {
      _categories =
          raw
              .map((e) => (e['name'] ?? '').toString())
              .where((e) => e.isNotEmpty)
              .toList();
    });
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed.')));
    }
  }

  void _navigateToTransactionHistory() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TransactionHistoryScreen()),
    ).then((_) {
      _loadCategories();
      _loadAllTransactions();
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
      builder:
          (ctx) => AlertDialog(
            title: Text('Add Category'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(hintText: 'Category name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: Text('Add'),
              ),
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
    bool isSplit = false;
    int splitCount = 2;
    DateTime selectedDate = DateTime.now();
    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setStateSb) => AlertDialog(
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
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            labelStyle: TextStyle(color: Colors.white70),
                            prefixIcon: Icon(Icons.currency_rupee, color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.green),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Description',
                            labelStyle: TextStyle(color: Colors.white70),
                            prefixIcon: Icon(Icons.edit_note, color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.green),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(Duration(days: 365)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.dark(
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
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: Colors.white70),
                                SizedBox(width: 12),
                                Text(
                                  'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                  style: TextStyle(color: Colors.white),
                                ),
                                Spacer(),
                                Icon(Icons.arrow_drop_down, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: type,
                          items:
                              ['Credit', 'Debit']
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e, style: TextStyle(color: Colors.white)),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            setStateSb(() => type = v ?? 'Debit');
                          },
                          decoration: InputDecoration(
                            labelText: 'Type',
                            labelStyle: TextStyle(color: Colors.white70),
                            prefixIcon: Icon(Icons.swap_vert, color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.green),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          dropdownColor: const Color(0xFF0E1F1F),
                        ),
                        if (type == 'Debit') ...[
                          SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: category,
                            items:
                                _categories
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e, style: TextStyle(color: Colors.white)),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) {
                              setStateSb(() => category = v);
                            },
                            decoration: InputDecoration(
                              labelText: 'Category',
                              labelStyle: TextStyle(color: Colors.white70),
                              prefixIcon: Icon(Icons.category, color: Colors.white70),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white24),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.green),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            dropdownColor: const Color(0xFF0E1F1F),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: Text('Split this amount?')),
                              Switch(
                                value: isSplit,
                                onChanged: (v) {
                                  setStateSb(() => isSplit = v);
                                },
                              ),
                            ],
                          ),
                          if (isSplit) ...[
                            SizedBox(height: 6),
                            Text(
                              'Number of splits',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 8),
                            SizedBox(
                              height: 56,
                              child: PageView.builder(
                                controller: PageController(
                                  viewportFraction: 0.22,
                                  initialPage: splitCount - 1,
                                ),
                                onPageChanged: (i) {
                                  setStateSb(() => splitCount = i + 1);
                                },
                                itemCount: 50,
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (context, index) {
                                  final isSelected = (index + 1) == splitCount;
                                  return Center(
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 150),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? Colors.green.withOpacity(0.2)
                                                : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: isSelected ? 20 : 16,
                                          fontWeight:
                                              isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                          color:
                                              isSelected
                                                  ? Colors.green
                                                  : Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Save'),
                    ),
                  ],
                ),
          ),
    );
    if (result == true) {
      final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
      final txnMap = {
        'transactionId': selectedDate.microsecondsSinceEpoch.toString(),
        'description':
            descriptionController.text.trim().isEmpty
                ? 'Manual Entry'
                : descriptionController.text.trim(),
        'amount': amount,
        'type': type,
        'date': selectedDate.toIso8601String(),
        'category': type == 'Credit' ? '' : (category ?? 'General'),
        'status': 'Completed',
        'isSplit': type == 'Debit' ? isSplit : false,
        'splitCount': type == 'Debit' && isSplit ? splitCount : 1,
      };
      await LocalStorageService.addTransaction(txnMap);
      _loadAllTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0), // margin on left button
            child: FloatingActionButton(
              heroTag: 'settings_fab_parallel',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SettingsScreen()),
                );
              },
              backgroundColor: Colors.green,
              child: Icon(Icons.settings, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            // margin on right button
            child: FloatingActionButton(
              heroTag: 'add_txn_fab',
              onPressed: _showAddTransactionDialog,
              backgroundColor: Colors.green,
              child: Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF032221), Colors.black, Color(0xFF032221)],
          ),
        ),
        child: SafeArea(
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
            style: GoogleFonts.nunito(color: Colors.white, fontSize: 28),
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
    // Sort categories by amount (highest first) and create cards
    final categoryCards = _categories.map((c) {
      final amount = _getMonthlyTotalForCategory(c);
      return MapEntry(c, amount);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
            onTap: () {
              _openCategoryTransactions('ALL_DEBIT');
            },
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
    final allDebit = category == 'ALL_DEBIT';
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
              Icon(icon, color: Colors.white, size: 32),
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
    return DefaultTabController(
      length: 4,
      child: Container(
        margin: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              isScrollable: false,
              labelColor: Colors.green,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.green,
              tabs: [
                Tab(text: 'Transactions'),
                Tab(text: 'Splits'),
                Tab(text: 'Credits'),
                Tab(text: 'Monthly'),
              ],
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: TabBarView(
                children: [
                  _buildTabTransactions(),
                  _buildTabSplits(),
                  _buildTabCredits(),
                  _buildTabPrevious(),
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
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      );
    }
    if (_recentTransactions.isEmpty) return _buildEmptyTransactionsWidget();

    final items = _recentTransactions.take(4).toList();
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        ...items.map(_buildTransactionItem).toList(),
        InkWell(
          onTap: _navigateToTransactionHistory,
          child: Container(
            margin: EdgeInsets.only(top: 8),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('View all', style: GoogleFonts.nunito(color: Colors.green, fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_ios, color: Colors.green, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabSplits() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LocalStorageService.getTransactions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          );
        }
        final txns =
            snapshot.data!
                .where((m) => (m['isSplit'] ?? false) == true)
                .map((m) => _transactionFromMap(m))
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));
        if (txns.isEmpty) return _buildEmptyTransactionsWidget();
        return ListView(children: txns.map(_buildTransactionItem).toList());
      },
    );
  }

  Widget _buildTabCredits() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LocalStorageService.getTransactions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          );
        }
        final txns =
            snapshot.data!
                .map((m) => _transactionFromMap(m))
                .where((t) => t.type == 'Credit')
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));
        if (txns.isEmpty) return _buildEmptyTransactionsWidget();
        return ListView(children: txns.map(_buildTransactionItem).toList());
      },
    );
  }

  Widget _buildTabPrevious() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LocalStorageService.getTransactions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          );
        }
        final txns = snapshot.data!.map((m) => _transactionFromMap(m)).toList();
        final now = DateTime.now();
        final byMonth = <String, double>{};
        for (final t in txns) {
          if (t.type != 'Debit') continue;
          if (t.date.year == now.year && t.date.month == now.month) continue;
          final key =
              '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
          byMonth[key] = (byMonth[key] ?? 0) + t.amount;
        }
        if (byMonth.isEmpty) {
          return _buildEmptyTransactionsWidget();
        }
        final entries =
            byMonth.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
        return ListView(
          children:
              entries.map((e) {
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
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
                        '₹${e.value.toStringAsFixed(0)}',
                        style: GoogleFonts.nunito(
                          color: Colors.redAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildEmptyTransactionsWidget() {
    return Container(
      padding: EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
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
            style: GoogleFonts.nunito(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsList() {
    return Column(
      children:
          _recentTransactions.map((transaction) {
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
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          '${_formatDate(transaction.date)} • ${transaction.category} • ${isCredit ? 'Cr' : 'Db'}',
          style: GoogleFonts.nunito(color: Colors.grey[400], fontSize: 12),
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
      final raw = await LocalStorageService.getTransactions();
      final txns = raw.map((m) => _transactionFromMap(m)).toList();
      txns.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _recentAndAllTransactionsCache = txns;
        _recentTransactions = txns.take(5).toList();
        _isLoadingTransactions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTransactions = false;
      });
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
    return '$mName $year';
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PrivacyScreen()),
              );
            },
            child: Text(
              'Safety & Privacy Policy',
              style: GoogleFonts.nunito(color: Colors.blueAccent, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
