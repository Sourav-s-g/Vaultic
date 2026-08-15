import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../models/transaction_history_model.dart';
import '../services/hybrid_storage_service.dart';
import '../services/pdf_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  bool _isLoading = false;
  bool _isGeneratingPdf = false;
  TransactionHistoryResponse? _transactionResponse;
  String _errorMessage = '';
  String _filteredQuery = '';
  int _weekOffset = 0; // 0=current week, 1=previous week
  Timer? _debounceTimer;
  List<Transaction> _cachedTransactions = [];
  int _currentPage = 0;
  static const int _pageSize = 20;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _loadTransactionHistory();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTransactionHistory({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _currentPage = 0;
        _cachedTransactions.clear();
        _hasMoreData = true;
      });
    }

    try {
      final raw = await HybridStorageService.getTransactions();
      final allTxns = raw.map((m) => _transactionFromMap(m)).toList();
      allTxns.sort((a, b) => b.date.compareTo(a.date));

      final startIndex = _currentPage * _pageSize;
      final endIndex = (startIndex + _pageSize).clamp(0, allTxns.length);
      final pageTxns = allTxns.sublist(startIndex, endIndex);

      if (mounted) {
        setState(() {
          if (loadMore) {
            _cachedTransactions.addAll(pageTxns);
          } else {
            _cachedTransactions = pageTxns;
          }

          _hasMoreData = endIndex < allTxns.length;
          _currentPage++;

          _transactionResponse = TransactionHistoryResponse(
            success: true,
            message: 'ok',
            transactions: _cachedTransactions,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load transactions: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (!_isLoading && _hasMoreData) {
      await _loadTransactionHistory(loadMore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF032221),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF032221), Color(0xFF0C4340)],
            ),
          ),
          child: AppBar(
            title: Text(
              'Transaction History',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadTransactionHistory,
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                onPressed: _showPdfExportDialog,
              ),
            ],
          ),
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
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _cachedTransactions.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorWidget();
    }

    if (_transactionResponse?.transactions == null ||
        _transactionResponse!.transactions!.isEmpty) {
      return _buildEmptyWidget();
    }

    return SafeArea(child: _buildTransactionList());
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: GoogleFonts.openSans(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadTransactionHistory,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Transactions Yet',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transaction history will appear here',
            style: GoogleFonts.openSans(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _filteredQuery = value;
        });
      }
    });
  }

  Widget _buildTransactionList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
        future: HybridStorageService.getTransactions(),
        builder: (context, transactionsSnapshot) {
          if (!transactionsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          final allTxns = transactionsSnapshot.data!.map((m) => _transactionFromMap(m)).toList();
          final now = DateTime.now();

          // 1. Monthly Summary (Current Month only)
          // We exclude rollover helper entries to show ONLY "real" monthly income/spending
          final monthTxns = allTxns.where((t) =>
          t.date.year == now.year &&
              t.date.month == now.month &&
              !t.description.contains('Balance carried forward')
          ).toList();

          final monthlyIncome = monthTxns.where((t) => t.type == 'Credit').fold(0.0, (s, t) => s + t.amount);
          final monthlySpent = monthTxns.where((t) => t.type == 'Debit').fold(0.0, (s, t) => s + t.amount);

          // 2. Cumulative Total Balance (Initial + All Time Real Credits - All Time Debits)
          return FutureBuilder<double>(
              future: HybridStorageService.getInitialBalance(),
              builder: (context, initialSnapshot) {
                final initialBalance = initialSnapshot.data ?? 0.0;

                double totalCredits = initialBalance;
                double totalDebits = 0.0;

                for (var t in allTxns) {
                  // Ignore rollover helper entries to avoid double counting balances from previous months
                  if (t.description.contains('Balance carried forward')) continue;

                  if (t.type == 'Credit') {
                    totalCredits += t.amount;
                  } else {
                    totalDebits += t.amount;
                  }
                }

                final netWalletBalance = totalCredits - totalDebits;

                // Filter for display in the history list (Search/Pagination)
                // By default, we show the full history but prioritize current month logic for summary
                final displayList = _filteredQuery.isEmpty
                    ? _cachedTransactions
                    : allTxns.where((t) =>
                t.description.toLowerCase().contains(_filteredQuery.toLowerCase()) ||
                    t.category.toLowerCase().contains(_filteredQuery.toLowerCase())
                ).toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildRowSummaryAndPie(monthTxns, monthlyIncome, monthlySpent, netWalletBalance),
                    const SizedBox(height: 12),
                    _buildWeeklyBar(monthTxns),
                    const SizedBox(height: 12),
                    _buildSearchField(),
                    const SizedBox(height: 16),
                    ..._buildGroupedByDate(displayList),
                    if (_hasMoreData && !_isLoading && _filteredQuery.isEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: ElevatedButton(
                            onPressed: _loadMoreTransactions,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Load More'),
                          ),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                );
              }
          );
        }
    );
  }

  Widget _buildRowSummaryAndPie(List<Transaction> txns, double totalCredits, double totalDebits, double balance) {
    final byCategory = <String, double>{};
    for (final t in txns.where((t)=> t.type == 'Debit')) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
    }

    final colors = [
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.teal,
      Colors.amber,
      Colors.pinkAccent,
      Colors.indigo,
      Colors.lightGreen,
      Colors.blueGrey,
    ];
    int colorIdx = 0;
    final sections = <PieChartSectionData>[];
    final legendItems = <Widget>[];

    final totalDebitsForPercentage = byCategory.values.fold(0.0, (sum, amount) => sum + amount);
    final totalBase = totalDebitsForPercentage > 0 ? totalDebitsForPercentage : 1.0;

    byCategory.forEach((cat, amt) {
      final col = colors[colorIdx++ % colors.length];
      final pct = (amt / totalBase) * 100.0;
      sections.add(PieChartSectionData(
        value: amt,
        color: col,
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ));
      legendItems.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(width: 10, height: 10, color: col),
            const SizedBox(width: 6),
            Expanded(child: Text(cat, style: GoogleFonts.openSans(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1)),
            const SizedBox(width: 4),
            Text('${pct.toStringAsFixed(0)}%', style: GoogleFonts.openSans(color: Colors.white, fontSize: 11)),
          ],
        ),
      ));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 160,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 28,
                    sectionsSpace: 1,
                    startDegreeOffset: -90,
                  ),
                  swapAnimationDuration: const Duration(milliseconds: 900),
                  swapAnimationCurve: Curves.easeOut,
                ),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 3.5,
                children: legendItems,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Expanded(child: _buildSummaryItem('Monthly Income', totalCredits, Colors.white)),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryItem('Monthly Spent', totalDebits, Colors.white)),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryItem('Total Balance', balance, Colors.greenAccent)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyBar(List<Transaction> txns) {
    final now = DateTime.now();
    final baseStart = now.subtract(Duration(days: now.weekday % 7));
    final startOfWeek = baseStart.subtract(Duration(days: 7 * _weekOffset));
    final bars = List.generate(7, (i){
      final day = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i);
      final total = txns
          .where((t)=> t.type == 'Debit' && t.date.year==day.year && t.date.month==day.month && t.date.day==day.day)
          .fold(0.0, (s,t)=> s + t.amount);
      return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: total, color: Colors.orangeAccent, width: 12, borderRadius: BorderRadius.circular(4))]);
    });

    return GestureDetector(
      onHorizontalDragEnd: (details){
        final v = details.primaryVelocity ?? 0;
        if (v > 0) setState(()=> _weekOffset = _weekOffset + 1);
        if (v < 0 && _weekOffset > 0) setState(()=> _weekOffset = _weekOffset - 1);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Text(_formatWeekRange(startOfWeek), style: GoogleFonts.openSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (v)=> FlLine(color: Colors.white24, strokeWidth: 1)),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.white24)),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: const Text('Amount', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta){
                          return Text('₹${value.toInt()}', style: const TextStyle(color: Colors.white70, fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Text('Days', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta){
                          const labels = ['S','M','T','W','T','F','S'];
                          final idx = value.toInt().clamp(0, 6);
                          return Text(labels[idx], style: const TextStyle(color: Colors.white70, fontSize: 10));
                        },
                      ),
                    ),
                  ),
                  barGroups: bars,
                ),
                swapAnimationDuration: const Duration(milliseconds: 900),
                swapAnimationCurve: Curves.easeOut,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: GoogleFonts.montserrat(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.openSans(
            color: Colors.white60,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final isCredit = transaction.type == 'Credit';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isCredit ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
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
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatDate(transaction.date),
              style: GoogleFonts.openSans(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            if (transaction.category.isNotEmpty)
              Text(
                transaction.category,
                style: GoogleFonts.openSans(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<bool>(
              future: _checkIfTransactionPendingSync(transaction.transactionId),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.cloud_off,
                      size: 16,
                      color: Colors.orange.withValues(alpha: 0.7),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(0)}',
                  style: GoogleFonts.montserrat(
                    color: isCredit ? Colors.green : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: transaction.status == 'Completed'
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    transaction.status,
                    style: GoogleFonts.openSans(
                      color: transaction.status == 'Completed' ? Colors.green : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              color: const Color(0xFF0E1F1F),
              onSelected: (v){
                if (v=='edit') { _showEditDialog(transaction); }
                if (v=='delete') {
                  _deleteTransaction(transaction.transactionId);
                }
              },
              itemBuilder: (ctx)=> const [
                PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
        onTap: () => _showEditDialog(transaction),
      ),
    );
  }

  Future<void> _showEditDialog(Transaction t) async {
    final amountC = TextEditingController(text: t.amount.toStringAsFixed(0));
    final descC = TextEditingController(text: t.description);
    String type = t.type;
    String category = t.category;
    DateTime date = t.date;
    final ok = await showDialog<String>(
      context: context,
      builder: (ctx)=> StatefulBuilder(builder: (ctx, setSb){
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1F1F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Edit Transaction', style: GoogleFonts.nunito(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.nunito(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                  controller: descC,
                  style: GoogleFonts.nunito(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                DropdownButtonFormField<String>(
                    value: type,
                    style: GoogleFonts.nunito(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Type',
                      labelStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.green),
                      ),
                    ),
                    dropdownColor: const Color(0xFF0E1F1F),
                    items: const [
                      DropdownMenuItem(value: 'Credit', child: Text('Credit')),
                      DropdownMenuItem(value: 'Debit', child: Text('Debit'))
                    ],
                    onChanged: (v){ setSb(()=> type = v ?? 'Debit'); }
                ),
                if (type == 'Debit') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: TextEditingController(text: category),
                    onChanged: (v)=> category=v,
                    style: GoogleFonts.nunito(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                ],
                const SizedBox(height: 16),
                Row(children: [
                  Text('Date: ${_formatDate(date)}', style: GoogleFonts.openSans(color: Colors.white70)),
                  const Spacer(),
                  TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDate: date,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: Colors.green,
                                  onPrimary: Colors.white,
                                  surface: const Color(0xFF0E1F1F),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (d!=null) setSb(()=> date=d);
                      },
                      child: const Text('Pick date', style: TextStyle(color: Colors.green))
                  ),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: ()=> Navigator.pop(ctx, 'cancel'),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70))
            ),
            TextButton(
                onPressed: ()=> Navigator.pop(ctx, 'delete'),
                child: const Text('Delete', style: TextStyle(color: Colors.red))
            ),
            TextButton(
                onPressed: ()=> Navigator.pop(ctx, 'save'),
                child: const Text('Save', style: TextStyle(color: Colors.green))
            ),
          ],
        );
      }),
    );
    if (ok == 'save') {
      final amt = double.tryParse(amountC.text.trim()) ?? t.amount;
      await HybridStorageService.updateTransactionById(t.transactionId, {
        'amount': amt,
        'description': descC.text.trim(),
        'type': type,
        'category': type=='Credit' ? '' : category,
        'date': date.toIso8601String(),
      });
      await _loadTransactionHistory();
    } else if (ok == 'delete') {
      await _deleteTransaction(t.transactionId);
    }
  }

  Future<void> _deleteTransaction(String transactionId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await HybridStorageService.deleteTransactionById(transactionId);
      await _loadTransactionHistory();
    } catch (e) {
      await _loadTransactionHistory();
    }
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
  }

  String _formatWeekRange(DateTime start) {
    final end = DateTime(start.year, start.month, start.day + 6);
    String f(DateTime d)=> '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}';
    return '${f(start)} - ${f(end)}';
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: _onSearchChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search transactions...',
        hintStyle: const TextStyle(color: Colors.white60),
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.green),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedByDate(List<Transaction> txns) {
    final grouped = <String, List<Transaction>>{};
    for (final t in txns) {
      final key = '${t.date.year}-${t.date.month}-${t.date.day}';
      grouped.putIfAbsent(key, ()=> []).add(t);
    }
    DateTime parseKey(String k){ final p = k.split('-'); return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2])); }
    final keys = grouped.keys.toList()..sort((a,b)=> parseKey(b).compareTo(parseKey(a)));
    final widgets = <Widget>[];
    for (final k in keys) {
      final dt = parseKey(k);
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(_formatDate(dt), style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
      ));
      widgets.addAll(grouped[k]!.map((t)=> _buildTransactionCard(t)));
    }
    return widgets;
  }

  Transaction _transactionFromMap(Map<String, dynamic> m) {
    return Transaction(
      transactionId: (m['transactionId'] ?? m['transaction_id'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      amount: (m['amount'] is num) ? (m['amount'] as num).toDouble() : double.tryParse((m['amount'] ?? '0').toString()) ?? 0.0,
      type: (m['type'] ?? '').toString(),
      date: DateTime.tryParse((m['date'] ?? '').toString()) ?? DateTime.now(),
      category: (m['category'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
    );
  }

  Future<void> _showPdfExportDialog() async {
    DateTime? startDate;
    DateTime? endDate;
    bool includeCharts = true;
    bool includeSummary = true;
    final fileNameController = TextEditingController(
      text: _generateFileName(startDate, endDate),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0E1F1F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Export PDF Report',
              style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PDF File Name',
                    style: GoogleFonts.openSans(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: fileNameController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF142626),
                      suffixText: '.pdf',
                      suffixStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      hintText: 'Enter report name',
                      hintStyle: const TextStyle(color: Colors.white38),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Date Range',
                    style: GoogleFonts.openSans(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              initialDate: startDate ?? DateTime.now().subtract(const Duration(days: 30)),
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
                              setState(() {
                                startDate = date;
                                fileNameController.text = _generateFileName(startDate, endDate);
                              });
                            }
                          },
                          child: Text(
                            startDate != null ? _formatDate(startDate!) : 'Start Date',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ),
                      const Text(' to ', style: TextStyle(color: Colors.white70)),
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              firstDate: startDate ?? DateTime(2020),
                              lastDate: DateTime.now(),
                              initialDate: endDate ?? DateTime.now(),
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
                              setState(() {
                                endDate = date;
                                fileNameController.text = _generateFileName(startDate, endDate);
                              });
                            }
                          },
                          child: Text(
                            endDate != null ? _formatDate(endDate!) : 'End Date',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildQuickDateButton('Last 7 days', () {
                        setState(() {
                          endDate = DateTime.now();
                          startDate = DateTime.now().subtract(const Duration(days: 7));
                          fileNameController.text = _generateFileName(startDate, endDate);
                        });
                      }),
                      _buildQuickDateButton('Last 30 days', () {
                        setState(() {
                          endDate = DateTime.now();
                          startDate = DateTime.now().subtract(const Duration(days: 30));
                          fileNameController.text = _generateFileName(startDate, endDate);
                        });
                      }),
                      _buildQuickDateButton('All time', () {
                        setState(() {
                          startDate = null;
                          endDate = null;
                          fileNameController.text = _generateFileName(startDate, endDate);
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Export Options',
                    style: GoogleFonts.openSans(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    title: Text(
                      'Include Summary',
                      style: GoogleFonts.openSans(color: Colors.white70, fontSize: 13),
                    ),
                    value: includeSummary,
                    onChanged: (value) => setState(() => includeSummary = value ?? true),
                    activeColor: Colors.green,
                    checkColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: Text(
                      'Include Charts',
                      style: GoogleFonts.openSans(color: Colors.white70, fontSize: 13),
                    ),
                    value: includeCharts,
                    onChanged: (value) => setState(() => includeCharts = value ?? true),
                    activeColor: Colors.green,
                    checkColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Export'),
              ),
            ],
          );
        },
      ),
    );

    if (result == 'export') {
      final customName = fileNameController.text;
      fileNameController.dispose();
      await _exportPdf(
        startDate,
        endDate,
        includeCharts,
        includeSummary,
        customFileName: customName,
      );
    } else {
      fileNameController.dispose();
    }
  }

  Widget _buildQuickDateButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.withValues(alpha: 0.2),
        foregroundColor: Colors.green,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 32),
      ),
      child: Text(
        label,
        style: GoogleFonts.openSans(fontSize: 12),
      ),
    );
  }

  Future<void> _exportPdf(
    DateTime? startDate,
    DateTime? endDate,
    bool includeCharts,
    bool includeSummary, {
    String? customFileName,
  }) async {
    if (_isGeneratingPdf) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    // Sleek, compact, floating progress indicator dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1D1D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00C851).withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFF00C851),
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Generating PDF...',
                style: GoogleFonts.openSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      String fileName;
      if (customFileName != null && customFileName.trim().isNotEmpty) {
        fileName = customFileName.trim()
            .replaceAll(RegExp(r'[^\w\s\-\_]'), '_')
            .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
        if (fileName.isEmpty) {
          fileName = _generateFileName(startDate, endDate);
        }
      } else {
        fileName = _generateFileName(startDate, endDate);
      }

      final pdfBytes = await PdfService.generateTransactionReport(
        startDate: startDate,
        endDate: endDate,
        includeCharts: includeCharts,
        includeSummary: includeSummary,
      );

      final filePath = await PdfService.savePdfToDevice(pdfBytes, fileName)
          .timeout(const Duration(seconds: 15));

      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
      }

      if (filePath != null && mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0E1F1F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF00C851), size: 26),
                const SizedBox(width: 10),
                Text(
                  'PDF Ready!',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your PDF has been generated & saved successfully.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _buildFileDetails(fileName),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Printing.layoutPdf(
                    onLayout: (PdfPageFormat format) async => pdfBytes,
                    name: '$fileName.pdf',
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text('Open PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C851),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Failed to save PDF');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  Widget _buildFileDetails(String fileName) {
    String locationText;
    if (Platform.isIOS) {
      locationText = 'Files App > On My iPhone > Vaultic';
    } else if (Platform.isAndroid) {
      locationText = 'Downloads folder';
    } else {
      locationText = 'Documents folder';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF142626),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00C851).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Name: $fileName.pdf',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Location: $locationText',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _generateFileName(DateTime? startDate, DateTime? endDate) {
    final now = DateTime.now();
    if (startDate == null && endDate == null) {
      return 'Vaultic_Report_All_${now.year}_${now.month}_${now.day}';
    } else if (startDate != null && endDate != null) {
      return 'Vaultic_Report_${startDate.year}_${startDate.month}_${startDate.day}_to_${endDate.year}_${endDate.month}_${endDate.day}';
    } else if (startDate != null) {
      return 'Vaultic_Report_From_${startDate.year}_${startDate.month}_${startDate.day}';
    } else {
      return 'Vaultic_Report_To_${endDate!.year}_${endDate.month}_${endDate.day}';
    }
  }

  Future<bool> _checkIfTransactionPendingSync(String transactionId) async {
    try {
      final transactions = await HybridStorageService.getTransactions();
      final txn = transactions.firstWhere(
            (t) => (t['transactionId'] ?? '').toString() == transactionId,
        orElse: () => <String, dynamic>{},
      );
      if (txn.isEmpty) return false;
      final syncStatus = (txn['_syncStatus'] ?? 'synced').toString();
      return syncStatus == 'pending';
    } catch (e) {
      return false;
    }
  }
}