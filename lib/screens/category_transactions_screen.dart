import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_history_model.dart';
import '../services/local_storage.dart';

class CategoryTransactionsScreen extends StatelessWidget {
  final String category;
  final bool allDebit; // if true, show all debit regardless of category

  const CategoryTransactionsScreen({super.key, required this.category, this.allDebit = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF032221),
      appBar: AppBar(
        title: Text(
          allDebit ? 'This Month Spent' : category,
          style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: LocalStorageService.getTransactions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.green)));
          }
          final now = DateTime.now();
          final txns = snapshot.data!
              .map(_transactionFromMap)
              .where((t) {
                final inMonth = t.date.year == now.year && t.date.month == now.month;
                if (!inMonth) return false;
                if (allDebit) return t.type == 'Debit';
                return t.type == 'Debit' && (t.category == category);
              })
              .toList()
            ..sort((a,b)=> b.date.compareTo(a.date));

          if (txns.isEmpty) {
            return _emptyWidget();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: txns.length,
            itemBuilder: (context, index) => _txTile(txns[index]),
          );
        },
      ),
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

  String _formatDateTime(DateTime dt) {
    final d = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    final t = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    return '$d • $t';
  }
}


