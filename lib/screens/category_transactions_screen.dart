import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction_history_model.dart';
import '../services/hybrid_storage_service.dart';
class CategoryTransactionsScreen extends StatefulWidget {
  final String category;
  final bool allDebit; // if true, show all debit regardless of category

  const CategoryTransactionsScreen({super.key, required this.category, this.allDebit = false});

  @override
  State<CategoryTransactionsScreen> createState() => _CategoryTransactionsScreenState();
}

class _CategoryTransactionsScreenState extends State<CategoryTransactionsScreen> {
  List<Transaction> _txns = [];
  String _query = '';
  double? _budget;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; });
    final raw = await HybridStorageService.getTransactions();
    final cat = widget.category;
    final list = raw
        .map(_transactionFromMap)
        .where((t) {
          if (widget.allDebit) return t.type == 'Debit';
          return t.type == 'Debit' && (t.category == cat);
        })
        .toList()
      ..sort((a,b)=> b.date.compareTo(a.date));

    final budgets = await HybridStorageService.getBudgets();
    setState(() {
      _txns = list;
      _budget = budgets[widget.allDebit ? 'ALL_DEBIT' : widget.category];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              widget.allDebit ? 'This Month Spent' : widget.category,
              style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                onPressed: _showSetBudgetDialog,
                icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white),
                tooltip: 'Set budget',
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
        child: _loading
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.green)))
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final filtered = _query.isEmpty
        ? _txns
        : _txns.where((t) => t.description.toLowerCase().contains(_query.toLowerCase())).toList();

    final avgPerDay = _computeAvgPerDay(_txns);
    final daysInMonth = DateUtils.getDaysInMonth(DateTime.now().year, DateTime.now().month);
    final today = DateTime.now().day;
    final daysLeft = (daysInMonth - today).clamp(0, daysInMonth);
    final spent = _txns.fold(0.0, (s,t)=> s + t.amount);
    final projection = spent + (avgPerDay * daysLeft);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statRow(avgPerDay, spent),
        const SizedBox(height: 12),
        _predictionCard(spent, projection),
        const SizedBox(height: 12),
        _buildSearchField(),
        const SizedBox(height: 12),
        if (filtered.isEmpty) _emptyWidget() else ..._buildGroupedByDate(filtered),
      ],
    );
  }

  Widget _txTile(Transaction t) {
    final isCredit = t.type == 'Credit';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: isCredit ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
          child: Icon(_getTransactionIcon(t.category), color: isCredit ? Colors.green : Colors.red, size: 20),
        ),
        title: Text(
          t.description,
          style: GoogleFonts.nunito(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _formatDateTime(t.date) + (t.category.isNotEmpty ? ' • ${t.category}' : ''),
          style: GoogleFonts.nunito(color: Colors.grey[400], fontSize: 12),
        ),
        trailing: Text(
          '${isCredit ? '+' : '-'}₹${t.amount.toStringAsFixed(0)}',
          style: GoogleFonts.nunito(color: isCredit ? Colors.green : Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onTap: () => _showTxnDetails(t),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (v){ setState(()=> _query = v.trim()); },
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search by description...',
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.green),
        ),
      ),
    );
  }

  Widget _statRow(double avgPerDay, double spent) {
    final hasBudget = _budget != null && _budget! > 0;
    return Row(
      children: [
        Expanded(child: _avgCard(avgPerDay)),
        const SizedBox(width: 12),
        if (hasBudget) Expanded(child: _budgetPie(spent, _budget!)),
      ],
    );
  }

  Widget _avgCard(double avgPerDay) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Avg spent per day', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text('₹${avgPerDay.toStringAsFixed(0)}', style: GoogleFonts.nunito(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _budgetPie(double spent, double budget) {
    final used = spent.clamp(0, budget).toDouble();
    final remaining = (budget - used).clamp(0, budget).toDouble();
    final percent = budget == 0 ? 0.0 : (used / budget);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: PieChart(
              PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                pieTouchData: PieTouchData(enabled: false),
                sections: [
                  PieChartSectionData(color: Colors.green, value: used, title: ''),
                  PieChartSectionData(color: Colors.white24, value: remaining, title: ''),
                ],
              ),
              swapAnimationDuration: const Duration(milliseconds: 900),
              swapAnimationCurve: Curves.easeOut,
            ),
          ),
          const SizedBox(height: 20),
          Text('Budget: ₹${budget.toStringAsFixed(0)}  •  Used: ${(percent*100).toStringAsFixed(0)}%', style: GoogleFonts.nunito(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  double _computeAvgPerDay(List<Transaction> txns) {
    if (txns.isEmpty) return 0;
    final days = txns.map((t)=> DateTime(t.date.year, t.date.month, t.date.day)).toSet().length;
    if (days == 0) return 0;
    final total = txns.fold(0.0, (s,t)=> s + t.amount);
    return total / days;
  }

  Future<void> _showSetBudgetDialog() async {
    final controller = TextEditingController(text: _budget?.toStringAsFixed(0) ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx)=> AlertDialog(
        title: const Text('Set Budget'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Enter budget amount'),
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      final value = double.tryParse(controller.text.trim());
      if (value != null && value > 0) {
        await HybridStorageService.setBudget(widget.allDebit ? 'ALL_DEBIT' : widget.category, value);
        setState((){ _budget = value; });
      }
    }
  }

  Future<void> _showTxnDetails(Transaction t) async {
    final res = await showDialog<String>(
      context: context,
      builder: (ctx)=> AlertDialog(
        backgroundColor: const Color(0xFF0E1F1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Transaction', style: GoogleFonts.nunito(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Amount', '₹${t.amount.toStringAsFixed(2)}'),
            _detailRow('Type', t.type),
            _detailRow('Category', t.category),
            _detailRow('Date', _formatDateTime(t.date)),
            _detailRow('Description', t.description),
          ],
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx, 'close'), child: const Text('Close')),
          TextButton(onPressed: ()=> Navigator.pop(ctx, 'edit'), child: const Text('Edit')),
          TextButton(onPressed: ()=> Navigator.pop(ctx, 'delete'), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (res == 'delete') {
      await HybridStorageService.deleteTransactionById(t.transactionId);
      await _load();
    } else if (res == 'edit') {
      await _showEditDialog(t);
      await _load();
    }
  }

  Future<void> _showEditDialog(Transaction t) async {
    final amountC = TextEditingController(text: t.amount.toStringAsFixed(0));
    final descC = TextEditingController(text: t.description);
    String type = t.type;
    String category = t.category;
    DateTime date = t.date;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx)=> StatefulBuilder(builder: (ctx, setSb){
        return AlertDialog(
          title: const Text('Edit Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: amountC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount')),
                TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 8),
                DropdownButton<String>(value: type, items: const [DropdownMenuItem(value: 'Credit', child: Text('Credit')), DropdownMenuItem(value: 'Debit', child: Text('Debit'))], onChanged: (v){ setSb(()=> type = v ?? 'Debit'); }),
                if (type == 'Debit') TextField(controller: TextEditingController(text: category), onChanged: (v)=> category=v, decoration: const InputDecoration(labelText: 'Category')),
                const SizedBox(height: 8),
                Row(children: [
                  Text('Date: ${_formatDateTime(date)}'),
                  const Spacer(),
                  TextButton(onPressed: () async { final d = await showDatePicker(context: ctx, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: date); if (d!=null) setSb(()=> date=d); }, child: const Text('Pick date')),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        );
      }),
    );
    if (ok == true) {
      final amt = double.tryParse(amountC.text.trim()) ?? t.amount;
      await HybridStorageService.updateTransactionById(t.transactionId, {
        'amount': amt,
        'description': descC.text.trim(),
        'type': type,
        'category': type=='Credit' ? '' : category,
        'date': date.toIso8601String(),
      });
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

  Widget _predictionCard(double spent, double projection) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Projected by month end', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 6),
            Text('₹${projection.toStringAsFixed(0)}', style: GoogleFonts.nunito(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Spent so far', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12)),
            Text('₹${spent.toStringAsFixed(0)}', style: GoogleFonts.nunito(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: GoogleFonts.nunito(color: Colors.white70))),
          Text(value, style: GoogleFonts.nunito(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _emptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No transactions', style: GoogleFonts.nunito(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Transactions will appear here', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedByDate(List<Transaction> txns) {
    final grouped = <String, List<Transaction>>{};
    for (final t in txns) {
      final key = '${t.date.year}-${t.date.month}-${t.date.day}';
      grouped.putIfAbsent(key, ()=> []).add(t);
    }
    DateTime parseKey(String k){ final p=k.split('-'); return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2])); }
    final keys = grouped.keys.toList()..sort((a,b)=> parseKey(b).compareTo(parseKey(a)));
    final widgets = <Widget>[];
    for (final k in keys) {
      final dt = parseKey(k);
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(_formatDateTime(dt), style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
      ));
      widgets.addAll(grouped[k]!.map(_txTile));
    }
    return widgets;
  }

  Transaction _transactionFromMap(Map<String, dynamic> m) {
    return Transaction(
      transactionId: (m["transactionId"] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      amount: (m['amount'] is num) ? (m['amount'] as num).toDouble() : double.tryParse((m['amount'] ?? '0').toString()) ?? 0.0,
      type: (m['type'] ?? '').toString(),
      date: DateTime.tryParse((m['date'] ?? '').toString()) ?? DateTime.now(),
      category: (m['category'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
    );
  }

  String _formatDateTime(DateTime dt) {
    final d = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    final t = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    return '$d • $t';
  }
}

