import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  String _query = '';
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
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load transactions: $e';
        _isLoading = false;
      });
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
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
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
              'Transaction History',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.picture_as_pdf, color: Colors.white),
                onPressed: _showPdfExportDialog,
                tooltip: 'Export PDF',
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadTransactionHistory,
              ),
            ],
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
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
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

    return _buildTransactionList();
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
          SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _errorMessage,
            style: GoogleFonts.openSans(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadTransactionHistory,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Try Again'),
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
          SizedBox(height: 16),
          Text(
            'No Transactions Yet',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
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
    _query = value;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 300), () {
      setState(() {
        _filteredQuery = value;
      });
    });
  }

  Widget _buildTransactionList() {
    final all = _cachedTransactions.isNotEmpty ? _cachedTransactions : _transactionResponse?.transactions ?? [];
    final txns = _filteredQuery.isEmpty
        ? all
        : all.where((t) =>
            t.description.toLowerCase().contains(_filteredQuery.toLowerCase()) ||
            t.category.toLowerCase().contains(_filteredQuery.toLowerCase())
          ).toList();
    
    // Restrict calculations to current month
    final now = DateTime.now();
    final monthTxns = txns.where((t) => t.date.year == now.year && t.date.month == now.month).toList();
    
    // Calculate totals for current month: Credits add to balance, Debits subtract from balance
    final totalCredits = monthTxns.where((t)=> t.type == 'Credit').fold(0.0, (s,t)=> s + t.amount);
    final totalDebits = monthTxns.where((t)=> t.type == 'Debit').fold(0.0, (s,t)=> s + t.amount);

    return FutureBuilder<double>(
      future: HybridStorageService.getInitialBalance(),
      builder: (context, snapshot) {
        // Get initial balance (starting balance when app was first used)
        final initialBalance = snapshot.data ?? 0.0;
        
        // Balance = Initial Balance + Credits - Debits
        // This ensures balance reflects your actual available money
        final balance = initialBalance + totalCredits - totalDebits;

        return ListView(
          padding: EdgeInsets.all(16),
          children: [
            _buildRowSummaryAndPie(monthTxns, totalCredits, totalDebits, balance),
        SizedBox(height: 12),
        _buildWeeklyBar(monthTxns),
        SizedBox(height: 12),
        _buildSearchField(),
        SizedBox(height: 16),
        ..._buildGroupedByDate(txns),
        if (_hasMoreData && !_isLoading)
          Container(
            margin: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: ElevatedButton(
                onPressed: _loadMoreTransactions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text('Load More'),
              ),
            ),
          ),
        if (_isLoading && _cachedTransactions.isNotEmpty)
          Container(
            margin: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          ),
      ],
        );
      },
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
    
    // Calculate percentages based on total debits (expenses)
    final totalDebitsForPercentage = byCategory.values.fold(0.0, (sum, amount) => sum + amount);
    final totalBase = totalDebitsForPercentage > 0 ? totalDebitsForPercentage : 1.0; // Avoid division by zero
    
    byCategory.forEach((cat, amt) {
      final col = colors[colorIdx++ % colors.length];
      final pct = (amt / totalBase) * 100.0; // Calculate percentage of total debits
      sections.add(PieChartSectionData(
        value: amt,
        color: col,
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
    
    // Only show savings section if there's actual savings (positive balance)
    if (balance > 0) {
      final savingsPercentage = (balance / totalCredits) * 100.0; // Percentage of credits saved
      sections.add(PieChartSectionData(
        value: balance, 
        color: Colors.green, 
        title: '${savingsPercentage.toStringAsFixed(0)}%', 
        titleStyle: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
      ));
      legendItems.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(children: [
          Container(width: 10, height: 10, color: Colors.green),
          const SizedBox(width: 6),
          Expanded(child: Text('Balance', style: GoogleFonts.openSans(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1)),
          const SizedBox(width: 4),
          Text('${savingsPercentage.toStringAsFixed(0)}%', style: GoogleFonts.openSans(color: Colors.white, fontSize: 11)),
        ]),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
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
              SizedBox(height: 8),
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
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Expanded(child: _buildSummaryItem('Credits', totalCredits, Colors.white)),
              SizedBox(width: 12),
              Expanded(child: _buildSummaryItem('Debits', totalDebits, Colors.white)),
              SizedBox(width: 12),
              Expanded(child: _buildSummaryItem('Balance', balance, Colors.white)),
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
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                axisNameWidget: Text('Amount', style: TextStyle(color: Colors.white70, fontSize: 10)),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta){
                    return Text('₹${value.toInt()}', style: TextStyle(color: Colors.white70, fontSize: 10));
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                axisNameWidget: Text('Days', style: TextStyle(color: Colors.white70, fontSize: 10)),
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta){
                    const labels = ['S','M','T','W','T','F','S'];
                    final idx = value.toInt().clamp(0, 6);
                    return Text(labels[idx], style: TextStyle(color: Colors.white70, fontSize: 10));
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.openSans(
            color: color.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
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
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              _formatDate(transaction.date),
              style: GoogleFonts.openSans(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
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
            // Show cloud-off icon if transaction is pending sync
            FutureBuilder<bool>(
              future: _checkIfTransactionPendingSync(transaction.transactionId),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.cloud_off,
                      size: 16,
                      color: Colors.orange.withOpacity(0.7),
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
                SizedBox(height: 2),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: transaction.status == 'Completed' 
                        ? Colors.green.withOpacity(0.2) 
                        : Colors.orange.withOpacity(0.2),
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
            SizedBox(width: 4),
            PopupMenuButton<String>(
              onSelected: (v){
                if (v=='edit') { _showEditDialog(transaction); }
                if (v=='delete') { 
                  _deleteTransaction(transaction.transactionId);
                }
              },
              itemBuilder: (ctx)=> const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
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
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descC, 
                  style: GoogleFonts.nunito(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  style: GoogleFonts.nunito(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Type',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.green),
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
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.green),
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
      // Still refresh UI in case deletion partially succeeded
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
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
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

  /// Show PDF export options dialog
  Future<void> _showPdfExportDialog() async {
    DateTime? startDate;
    DateTime? endDate;
    bool includeCharts = true;
    bool includeSummary = true;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0E1F1F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(
              'Export PDF Report',
              style: GoogleFonts.montserrat(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date range selection
                  Text(
                    'Date Range',
                    style: GoogleFonts.openSans(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              initialDate: startDate ?? DateTime.now().subtract(Duration(days: 30)),
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
                            if (date != null) {
                              setState(() => startDate = date);
                            }
                          },
                          child: Text(
                            startDate != null ? _formatDate(startDate!) : 'Start Date',
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
                      ),
                      Text(' to ', style: TextStyle(color: Colors.white70)),
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
                            if (date != null) {
                              setState(() => endDate = date);
                            }
                          },
                          child: Text(
                            endDate != null ? _formatDate(endDate!) : 'End Date',
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  // Quick date range buttons
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildQuickDateButton('Last 7 days', () {
                        setState(() {
                          endDate = DateTime.now();
                          startDate = DateTime.now().subtract(Duration(days: 7));
                        });
                      }),
                      _buildQuickDateButton('Last 30 days', () {
                        setState(() {
                          endDate = DateTime.now();
                          startDate = DateTime.now().subtract(Duration(days: 30));
                        });
                      }),
                      _buildQuickDateButton('All time', () {
                        setState(() {
                          startDate = null;
                          endDate = null;
                        });
                      }),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  // Export options
                  Text(
                    'Export Options',
                    style: GoogleFonts.openSans(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  CheckboxListTile(
                    title: Text(
                      'Include Summary',
                      style: GoogleFonts.openSans(color: Colors.white70),
                    ),
                    value: includeSummary,
                    onChanged: (value) => setState(() => includeSummary = value ?? true),
                    activeColor: Colors.green,
                    checkColor: Colors.white,
                  ),
                  CheckboxListTile(
                    title: Text(
                      'Include Charts',
                      style: GoogleFonts.openSans(color: Colors.white70),
                    ),
                    value: includeCharts,
                    onChanged: (value) => setState(() => includeCharts = value ?? true),
                    activeColor: Colors.green,
                    checkColor: Colors.white,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'preview'),
                child: Text('Preview', style: TextStyle(color: Colors.blue)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'export'),
                child: Text('Export', style: TextStyle(color: Colors.green)),
              ),
            ],
          );
        },
      ),
    );

    if (result == 'preview') {
      await _previewPdf(startDate, endDate, includeCharts, includeSummary);
    } else if (result == 'export') {
      await _exportPdf(startDate, endDate, includeCharts, includeSummary);
    }
  }

  /// Build quick date range button
  Widget _buildQuickDateButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.withOpacity(0.2),
        foregroundColor: Colors.green,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size(0, 32),
      ),
      child: Text(
        label,
        style: GoogleFonts.openSans(fontSize: 12),
      ),
    );
  }

  /// Preview PDF
  Future<void> _previewPdf(DateTime? startDate, DateTime? endDate, bool includeCharts, bool includeSummary) async {
    if (_isGeneratingPdf) return; // Prevent multiple generations
    
    if (mounted) {
      setState(() {
        _isGeneratingPdf = true;
      });
    }
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF0E1F1F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'Generating PDF...',
                  style: GoogleFonts.openSans(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );

      // Filter transactions based on date range
      List<Transaction> filteredTransactions = _cachedTransactions;
      if (startDate != null || endDate != null) {
        filteredTransactions = _cachedTransactions.where((transaction) {
          if (startDate != null && transaction.date.isBefore(startDate)) {
            return false;
          }
          if (endDate != null && transaction.date.isAfter(endDate)) {
            return false;
          }
          return true;
        }).toList();
      }

      // Generate PDF using free pdf package
      print('=== PDF GENERATION START ===');
      print('Start date: $startDate, End date: $endDate');
      print('Filtered transactions count: ${filteredTransactions.length}');
      
      final pdfBytes = await PdfService.generateTransactionReport(
        startDate: startDate,
        endDate: endDate,
        includeCharts: true,
        includeSummary: true,
      );
      
      print('PDF generation completed, bytes length: ${pdfBytes.length}');
      print('=== PDF GENERATION END ===');

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show export options dialog
      await _showExportOptionsDialog(pdfBytes, startDate, endDate);
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
        
        // Show error
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

  /// Export PDF
  Future<void> _exportPdf(DateTime? startDate, DateTime? endDate, bool includeCharts, bool includeSummary) async {
    if (_isGeneratingPdf) return; // Prevent multiple generations
    
    if (mounted) {
      setState(() {
        _isGeneratingPdf = true;
      });
    }
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF0E1F1F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'Generating PDF...',
                  style: GoogleFonts.openSans(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );

      // Filter transactions based on date range
      List<Transaction> filteredTransactions = _cachedTransactions;
      if (startDate != null || endDate != null) {
        filteredTransactions = _cachedTransactions.where((transaction) {
          if (startDate != null && transaction.date.isBefore(startDate)) {
            return false;
          }
          if (endDate != null && transaction.date.isAfter(endDate)) {
            return false;
          }
          return true;
        }).toList();
      }

      // Generate PDF using free pdf package
      print('=== PDF GENERATION START ===');
      print('Start date: $startDate, End date: $endDate');
      print('Filtered transactions count: ${filteredTransactions.length}');
      
      final pdfBytes = await PdfService.generateTransactionReport(
        startDate: startDate,
        endDate: endDate,
        includeCharts: true,
        includeSummary: true,
      );
      
      print('PDF generation completed, bytes length: ${pdfBytes.length}');
      print('=== PDF GENERATION END ===');

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show export options
      await _showExportOptionsDialog(pdfBytes, startDate, endDate);
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
        
        // Show error
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

  /// Save PDF directly to device with confirmation
  Future<void> _showExportOptionsDialog(Uint8List pdfBytes, DateTime? startDate, DateTime? endDate) async {
    final fileName = _generateFileName(startDate, endDate);
    
    // Show loading dialog while saving
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Color(0xFF0E1F1F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 16),
              Text(
                'Saving PDF to device...',
                style: GoogleFonts.openSans(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      print('=== PDF SAVE PROCESS START ===');
      // Save PDF to device
      final filePath = await PdfService.savePdfToDevice(pdfBytes, fileName)
          .timeout(Duration(seconds: 15));
      print('PDF save completed, filePath: $filePath');
      
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
        print('Loading dialog closed');
      }
      
      if (filePath != null && mounted) {
        // Show success confirmation
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0E1F1F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text(
                  'PDF Saved!',
                  style: GoogleFonts.montserrat(color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your PDF has been saved successfully to your device.',
                  style: GoogleFonts.openSans(color: Colors.white70),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF1A2A2A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File Details:',
                        style: GoogleFonts.openSans(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Name: $fileName.pdf',
                        style: GoogleFonts.openSans(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        'Location: Documents folder',
                        style: GoogleFonts.openSans(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK', style: TextStyle(color: Colors.green)),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Failed to save PDF - no file path returned');
      }
    } catch (e) {
      print('=== PDF SAVE PROCESS ERROR ===');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
        print('Loading dialog closed due to error');
        
        // Show error dialog
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0E1F1F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text(
                  'Save Failed',
                  style: GoogleFonts.montserrat(color: Colors.white),
                ),
              ],
            ),
            content: Text(
              'Failed to save PDF: ${e.toString().split(':').last.trim()}',
              style: GoogleFonts.openSans(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      }
    }
  }


  /// Generate filename based on date range
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

  /// Check if transaction is pending sync
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

  /// Calculate summary statistics
  Future<Map<String, double>> _calculateSummary(List<Transaction> transactions) async {
    final totalCredits = transactions
        .where((t) => t.type == 'Credit')
        .fold(0.0, (sum, t) => sum + t.amount);
    
    final totalDebits = transactions
        .where((t) => t.type == 'Debit')
        .fold(0.0, (sum, t) => sum + t.amount);
    
    // Get initial balance and calculate actual balance
    final initialBalance = await HybridStorageService.getInitialBalance();
    final balance = initialBalance + totalCredits - totalDebits;
    
    return {
      'credits': totalCredits,
      'debits': totalDebits,
      'balance': balance,
    };
  }

}

