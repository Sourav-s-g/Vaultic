import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../models/trip.dart';
import '../models/transaction_history_model.dart';
import '../services/trip_storage_service.dart';

class TripPage extends StatefulWidget {
  final Trip trip;

  const TripPage({super.key, required this.trip});

  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  int _currentPage = 0;
  static const int _pageSize = 20;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _transactions.clear();
        _hasMoreData = true;
      });
    }

    try {
      final raw = await TripStorageService.getTripTransactions(widget.trip.tripId);
      final allTxns = raw.map((m) => _transactionFromMap(m)).toList();
      allTxns.sort((a, b) => b.date.compareTo(a.date));

      final startIndex = _currentPage * _pageSize;
      final endIndex = (startIndex + _pageSize).clamp(0, allTxns.length);
      final pageTxns = allTxns.sublist(startIndex, endIndex);

      if (mounted) {
        setState(() {
          if (loadMore) {
            _transactions.addAll(pageTxns);
          } else {
            _transactions = pageTxns;
          }
          _hasMoreData = endIndex < allTxns.length;
          _currentPage++;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (!_isLoading && _hasMoreData) {
      await _loadTransactions(loadMore: true);
    }
  }

  Transaction _transactionFromMap(Map<String, dynamic> m) {
    return Transaction(
      transactionId: (m['transactionId'] ?? m['transaction_id'] ?? '').toString(),
      description: m['description'] ?? '',
      amount: (m['amount'] ?? 0.0).toDouble(),
      type: m['type'] ?? 'Debit',
      date: DateTime.parse(m['date'] ?? DateTime.now().toIso8601String()),
      category: m['category'] ?? '',
      status: m['status'] ?? 'Completed',
    );
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
            colors: [Color(0xFF032221), Color(0xFF0C4340), Color(0xFF032221)],
          ),
        ),
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                widget.trip.name,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () => _showTripOptions(),
                ),
              ],
            ),
            _buildCategoriesSection(),
            Expanded(
              child: SafeArea(
                top: false,
                child: _buildTransactionsSection(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTransactionDialog,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildCategoryCard(
            title: 'Total Spent',
            amount: '₹${_getTotalSpent().toStringAsFixed(0)}',
            icon: Icons.payments,
            color: Colors.red,
            onTap: () => _showTripAnalytics(),
            budget: widget.trip.budget,
            spent: _getTotalSpent(),
          ),
          ...widget.trip.categories.map((category) {
            final amount = _getCategoryTotal(category);
            final categoryBudget = widget.trip.categoryBudgets?[category];
            return _buildCategoryCard(
              title: category,
              amount: '₹${amount.toStringAsFixed(0)}',
              icon: Icons.category,
              color: _getCategoryColor(category),
              onTap: () => _showCategoryTransactions(category),
              budget: categoryBudget,
              spent: amount,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double? budget,
    double? spent,
  }) {
    final hasBudget = budget != null && budget > 0;
    final progress = hasBudget ? (spent ?? 0) / budget : 0.0;
    final isOverBudget = progress > 1.0;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverBudget ? Colors.red.withOpacity(0.5) : Colors.white.withOpacity(0.1),
            width: isOverBudget ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: GoogleFonts.nunito(
                color: isOverBudget ? Colors.red : color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (hasBudget) ...[
              const SizedBox(height: 4),
              Text(
                '₹${budget.toStringAsFixed(0)} budget',
                style: GoogleFonts.nunito(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isOverBudget ? Colors.red : Colors.green,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transactions',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading && _transactions.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  )
                : _transactions.isEmpty
                    ? _buildEmptyTransactionsWidget()
                    : _buildTransactionList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _transactions.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _transactions.length) {
          return _buildTransactionItem(_transactions[index]);
        } else if (index == _transactions.length && _hasMoreData) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.green)
                : ElevatedButton(
                    onPressed: _loadMoreTransactions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Load More'),
                  ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    return Container(
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getCategoryColor(transaction.category).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.category,
              color: _getCategoryColor(transaction.category),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${transaction.category} • ${_formatDate(transaction.date)}',
                  style: GoogleFonts.nunito(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${transaction.amount.toStringAsFixed(0)}',
            style: GoogleFonts.nunito(
              color: Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF0E1F1F),
            onSelected: (value) async {
              if (value == 'edit') {
                _showEditTransactionDialog(transaction);
              } else if (value == 'delete') {
                _showDeleteTransactionConfirmation(transaction);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Edit', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactionsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            color: Colors.white.withOpacity(0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: GoogleFonts.nunito(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first transaction for this trip',
            style: GoogleFonts.nunito(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog() {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = widget.trip.categories.first;
    String selectedType = 'Debit';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            'Add Transaction',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  style: GoogleFonts.nunito(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  style: GoogleFonts.nunito(color: Colors.white),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Colors.green,
                              onPrimary: Colors.white,
                              surface: Color(0xFF1A1A1A),
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setState(() {
                        selectedDate = date;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                  ),
                  items: widget.trip.categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Type',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                  ),
                  items: ['Debit', 'Credit'].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                final amountText = amountController.text.trim();
                final desc = descriptionController.text.trim();
                if (desc.isEmpty || amountText.isEmpty) {
                  return;
                }
                
                final amount = double.tryParse(amountText);
                if (amount == null || amount <= 0) {
                  return;
                }
                
                final transaction = {
                  'transactionId': const Uuid().v4(),
                  'description': desc,
                  'amount': amount,
                  'type': selectedType,
                  'date': selectedDate.toIso8601String(),
                  'category': selectedCategory,
                  'status': 'Completed',
                  'isSplit': false,
                  'splitCount': 1,
                };
                
                await TripStorageService.addTripTransaction(widget.trip.tripId, transaction);
                if (!mounted) return;
                Navigator.of(context).pop();
                await _loadTransactions();
              },
              child: const Text('Add', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTransactionDialog(Transaction transaction) {
    final descriptionController = TextEditingController(text: transaction.description);
    final amountController = TextEditingController(text: transaction.amount.toString());
    String selectedCategory = transaction.category;
    String selectedType = transaction.type;
    DateTime selectedDate = transaction.date;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            'Edit Transaction',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  style: GoogleFonts.nunito(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  style: GoogleFonts.nunito(color: Colors.white),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Colors.green,
                              onPrimary: Colors.white,
                              surface: Color(0xFF1A1A1A),
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setState(() {
                        selectedDate = date;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                  ),
                  items: widget.trip.categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Type',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                  ),
                  items: ['Debit', 'Credit'].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                final amountText = amountController.text.trim();
                final desc = descriptionController.text.trim();
                if (desc.isEmpty || amountText.isEmpty) return;
                
                final amount = double.tryParse(amountText);
                if (amount == null || amount <= 0) return;
                
                final updatedTransaction = {
                  'transactionId': transaction.transactionId,
                  'description': desc,
                  'amount': amount,
                  'type': selectedType,
                  'date': selectedDate.toIso8601String(),
                  'category': selectedCategory,
                  'status': 'Completed',
                  'isSplit': false,
                  'splitCount': 1,
                };
                
                await TripStorageService.deleteTripTransaction(widget.trip.tripId, transaction.transactionId);
                await TripStorageService.addTripTransaction(widget.trip.tripId, updatedTransaction);
                if (!mounted) return;
                Navigator.of(context).pop();
                await _loadTransactions();
              },
              child: const Text('Update', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTransactionConfirmation(Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'Delete Transaction',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${transaction.description}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              await TripStorageService.deleteTripTransaction(widget.trip.tripId, transaction.transactionId);
              if (!mounted) return;
              Navigator.of(context).pop();
              await _loadTransactions();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCategoryTransactions(String category) {
    final categoryTransactions = _transactions.where((t) => t.category == category && t.type == 'Debit').toList();
    
    if (categoryTransactions.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text('No transactions found for this category.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close', style: TextStyle(color: Colors.green))),
          ],
        ),
      );
      return;
    }
    
    final totalSpent = categoryTransactions.fold(0.0, (sum, t) => sum + t.amount);
    final daysUsed = categoryTransactions.map((t) => t.date.day).toSet().length;
    final avgPerDay = daysUsed > 0 ? totalSpent / daysUsed : 0.0;
    final categoryBudget = widget.trip.categoryBudgets?[category];
    final isOverBudget = categoryBudget != null && totalSpent > categoryBudget;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _analyticsCard('Total Spent', '₹${totalSpent.toStringAsFixed(0)}', Colors.red),
              const SizedBox(height: 12),
              _analyticsCard('Average Per Day', '₹${avgPerDay.toStringAsFixed(0)}', Colors.green),
              const SizedBox(height: 12),
              _analyticsCard('Days Used', '$daysUsed days', Colors.blue),
              if (categoryBudget != null) ...[
                const SizedBox(height: 12),
                _budgetCard(totalSpent, categoryBudget, isOverBudget),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close', style: TextStyle(color: Colors.green))),
        ],
      ),
    );
  }

  Widget _analyticsCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _budgetCard(double spent, double budget, bool isOver) {
    final progress = (spent / budget).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Budget', style: TextStyle(color: Colors.white, fontSize: 14)),
              Text('${(progress * 100).toStringAsFixed(1)}%', style: TextStyle(color: isOver ? Colors.red : Colors.orange, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress, backgroundColor: Colors.white12, color: isOver ? Colors.red : Colors.orange),
          const SizedBox(height: 4),
          Text('₹${spent.toStringAsFixed(0)} / ₹${budget.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  void _showTripAnalytics() {
    final totalSpent = _getTotalSpent();
    final categoryData = <String, Map<String, dynamic>>{};
    
    for (final t in _transactions) {
      if (t.type != 'Debit') continue;
      if (!categoryData.containsKey(t.category)) {
        categoryData[t.category] = {'total': 0.0, 'days': <int>{}};
      }
      categoryData[t.category]!['total'] += t.amount;
      categoryData[t.category]!['days'].add(t.date.day);
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('${widget.trip.name} Analytics', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _analyticsCard('Total Trip Spent', '₹${totalSpent.toStringAsFixed(0)}', Colors.red),
              if (widget.trip.budget != null && widget.trip.budget! > 0) ...[
                const SizedBox(height: 12),
                _budgetCard(totalSpent, widget.trip.budget!, totalSpent > widget.trip.budget!),
              ],
              const SizedBox(height: 20),
              const Text('Category Breakdown', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...categoryData.entries.map((e) {
                final total = e.value['total'] as double;
                final budget = widget.trip.categoryBudgets?[e.key];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: const TextStyle(color: Colors.white)),
                      Text('₹${total.toStringAsFixed(0)}', style: TextStyle(color: (budget != null && total > budget) ? Colors.red : Colors.white70)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close', style: TextStyle(color: Colors.green))),
        ],
      ),
    );
  }

  void _showTripOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('Edit Trip', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Trip', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteTripConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTripConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Trip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${widget.trip.name}"? This action cannot be undone.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
          TextButton(
            onPressed: () async {
              await TripStorageService.deleteTrip(widget.trip.tripId);
              if (!mounted) return;
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  double _getTotalSpent() {
    return _transactions.where((t) => t.type == 'Debit').fold(0.0, (sum, t) => sum + t.amount);
  }

  double _getCategoryTotal(String category) {
    return _transactions.where((t) => t.category == category && t.type == 'Debit').fold(0.0, (sum, t) => sum + t.amount);
  }

  Color _getCategoryColor(String category) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.indigo, Colors.amber];
    final index = category.hashCode % colors.length;
    return colors[index];
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
