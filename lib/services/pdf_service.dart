import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/transaction_history_model.dart';
import '../services/hybrid_storage_service.dart';

class PdfService {
  static const PdfColor _primaryColor = PdfColor.fromInt(0xFF032221);
  static const PdfColor _accentColor = PdfColor.fromInt(0xFF00C851);
  static const PdfColor _textColor = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor _lightTextColor = PdfColor.fromInt(0xFFB0B0B0);

  // Helper method to format currency without Unicode symbols
  static String _formatCurrency(double amount) {
    return 'Rs ${amount.toStringAsFixed(0)}';
  }

  // Helper method to sanitize text for PDF rendering
  static String _sanitizeText(String text) {
    return text
        .replaceAll('\u2019', "'")  // Replace smart quotes
        .replaceAll('\u201c', '"')  // Replace smart double quotes
        .replaceAll('\u201d', '"')  // Replace smart double quotes
        .replaceAll('\u2013', '-')  // Replace en dash
        .replaceAll('\u2014', '-')  // Replace em dash
        .replaceAll('\u2026', '...') // Replace ellipsis
        .replaceAll('\u20b9', 'Rs')  // Replace rupee symbol
        .replaceAll('\u2022', '-')   // Replace bullet
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '?'); // Replace any other non-ASCII characters
  }

  /// Generate PDF report for transactions
  static Future<Uint8List> generateTransactionReport({
    DateTime? startDate,
    DateTime? endDate,
    bool includeCharts = true,
    bool includeSummary = true,
  }) async {
    // Get transactions from storage
    final rawTransactions = await HybridStorageService.getTransactions();
    final transactions = rawTransactions.map((m) => _transactionFromMap(m)).toList();
    
    // Filter by date range if provided
    List<Transaction> filteredTransactions = transactions;
    if (startDate != null || endDate != null) {
      filteredTransactions = transactions.where((t) {
        if (startDate != null && t.date.isBefore(startDate)) return false;
        if (endDate != null && t.date.isAfter(endDate)) return false;
        return true;
      }).toList();
    }
    
    // Sort by date (newest first)
    filteredTransactions.sort((a, b) => b.date.compareTo(a.date));
    
    // Calculate summary data
    final summary = await _calculateSummary(filteredTransactions);
    
    // Create PDF document
    final pdf = pw.Document();
    
    // Add pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(context, startDate, endDate),
            if (includeSummary) _buildSummarySection(context, summary),
            if (includeCharts) _buildChartsSection(context, filteredTransactions),
            _buildTransactionsTable(context, filteredTransactions),
            _buildFooter(context),
          ];
        },
      ),
    );
    
    return pdf.save();
  }

  /// Build PDF header
  static pw.Widget _buildHeader(pw.Context context, DateTime? startDate, DateTime? endDate) {
    final now = DateTime.now();
    final dateRange = _formatDateRange(startDate, endDate);
    
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 24),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'VAULTIC',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              pw.Text(
                'Transaction Report',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated: ${_formatDate(now)}',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: _lightTextColor,
                ),
              ),
              pw.Text(
                dateRange,
                style: pw.TextStyle(
                  fontSize: 12,
                  color: _lightTextColor,
                ),
              ),
            ],
          ),
          pw.Divider(color: _accentColor, thickness: 2),
        ],
      ),
    );
  }

  /// Build summary section
  static pw.Widget _buildSummarySection(pw.Context context, Map<String, double> summary) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 24),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _primaryColor,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Financial Summary',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _textColor,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Total Credits', summary['credits'] ?? 0, PdfColors.green),
              _buildSummaryItem('Total Debits', summary['debits'] ?? 0, PdfColors.red),
              _buildSummaryItem('Balance', summary['balance'] ?? 0, PdfColors.blue),
            ],
          ),
        ],
      ),
    );
  }

  /// Build summary item widget
  static pw.Widget _buildSummaryItem(String label, double amount, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          _formatCurrency(amount),
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 12,
            color: _textColor,
          ),
        ),
      ],
    );
  }

  /// Build charts section
  static pw.Widget _buildChartsSection(pw.Context context, List<Transaction> transactions) {
    final expenseTransactions = transactions.where((t) => t.type == 'Debit').toList();
    if (expenseTransactions.isEmpty) {
      return pw.SizedBox.shrink();
    }

    // Calculate category breakdown
    final categoryBreakdown = <String, double>{};
    for (final t in expenseTransactions) {
      categoryBreakdown[t.category] = (categoryBreakdown[t.category] ?? 0) + t.amount;
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 24),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Expense Breakdown by Category',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Percentage', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              ...categoryBreakdown.entries.map((entry) {
                final percentage = (entry.value / (categoryBreakdown.values.fold(0.0, (a, b) => a + b))) * 100;
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(entry.key),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(_formatCurrency(entry.value)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('${percentage.toStringAsFixed(1)}%'),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  /// Build transactions table
  static pw.Widget _buildTransactionsTable(pw.Context context, List<Transaction> transactions) {
    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Transaction Details',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FixedColumnWidth(80),  // Date
              1: const pw.FlexColumnWidth(3),   // Description
              2: const pw.FixedColumnWidth(80), // Category
              3: const pw.FixedColumnWidth(80), // Amount
              4: const pw.FixedColumnWidth(60), // Type
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              ...transactions.map((transaction) {
                final isCredit = transaction.type == 'Credit';
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        _formatDate(transaction.date),
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        _sanitizeText(transaction.description),
                        style: pw.TextStyle(fontSize: 10),
                        maxLines: 2,
                        overflow: pw.TextOverflow.clip,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        _sanitizeText(transaction.category),
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        _formatCurrency(transaction.amount),
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: isCredit ? PdfColors.green : PdfColors.red,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        transaction.type,
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: isCredit ? PdfColors.green : PdfColors.red,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  /// Build footer
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 24),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'Generated by Vaultic App - ${DateTime.now().year}',
            style: pw.TextStyle(
              fontSize: 10,
              color: _lightTextColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate summary statistics
  static Future<Map<String, double>> _calculateSummary(List<Transaction> transactions) async {
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

  /// Convert map to Transaction object
  static Transaction _transactionFromMap(Map<String, dynamic> m) {
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

  /// Format date for display
  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Format date range for display
  static String _formatDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate == null && endDate == null) {
      return 'All Transactions';
    } else if (startDate == null) {
      return 'Up to ${_formatDate(endDate!)}';
    } else if (endDate == null) {
      return 'From ${_formatDate(startDate)}';
    } else {
      return '${_formatDate(startDate)} - ${_formatDate(endDate)}';
    }
  }


  /// Save PDF to device
  static Future<String?> savePdfToDevice(Uint8List pdfBytes, String fileName) async {
    try {
      print('=== PDF SAVE DEBUG START ===');
      print('PDF bytes length: ${pdfBytes.length}');
      print('File name: $fileName');
      
      // For iOS Simulator, always use documents directory
      final directory = await getApplicationDocumentsDirectory();
      print('Documents directory: ${directory.path}');
      
      if (directory == null) {
        print('ERROR: No suitable directory available');
        throw Exception('No suitable directory available');
      }

      // Create the directory if it doesn't exist
      if (!await directory.exists()) {
        print('Directory does not exist, creating...');
        await directory.create(recursive: true);
        print('Directory created successfully');
      } else {
        print('Directory already exists');
      }

      // Create file
      final filePath = '${directory.path}/$fileName.pdf';
      print('Full file path: $filePath');
      
      final file = File(filePath);
      print('File object created, writing bytes...');
      
      await file.writeAsBytes(pdfBytes);
      print('File written successfully');
      
      // Verify file exists
      if (await file.exists()) {
        final fileSize = await file.length();
        print('File exists, size: $fileSize bytes');
      } else {
        print('ERROR: File does not exist after writing');
        return null;
      }
      
      print('=== PDF SAVE DEBUG END ===');
      return file.path;
    } catch (e) {
      print('=== PDF SAVE ERROR ===');
      print('Error saving PDF: $e');
      print('Error type: ${e.runtimeType}');
      print('=== END ERROR ===');
      return null;
    }
  }

}
