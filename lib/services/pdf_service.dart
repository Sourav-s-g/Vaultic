import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction_history_model.dart';
import '../services/hybrid_storage_service.dart';

/// Internal helper that pairs a transaction with its running balance
/// at that point in the statement (bank-statement style).
class _StatementLine {
  final Transaction transaction;
  final double runningBalance;
  _StatementLine(this.transaction, this.runningBalance);
}

class PdfService {
  static const PdfColor _primaryColor = PdfColor.fromInt(0xFF032221);
  static const PdfColor _accentColor = PdfColor.fromInt(0xFF00C851);
  static const PdfColor _textColor = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor _lightTextColor = PdfColor.fromInt(0xFF7A7A7A);
  static const PdfColor _borderColor = PdfColor.fromInt(0xFFE0E0E0);

  static const String _appName = 'VAULTIC';

  // Cache the loaded font set so repeated report generation in one
  // session doesn't refetch/re-decode fonts every time.
  static pw.ThemeData? _cachedTheme;

  static Future<pw.ThemeData> _theme() async {
    if (_cachedTheme != null) return _cachedTheme!;
    // NotoSans covers the Rupee sign (\u20B9), smart quotes, dashes, etc.
    // so we no longer need to lossily strip characters to '?'.
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    _cachedTheme = pw.ThemeData.withFont(base: base, bold: bold);
    return _cachedTheme!;
  }

  // Currency formatting now uses the real Rupee symbol since the font
  // supports it. Falls back gracefully if amount is negative.
  static String _formatCurrency(double amount, {bool showSign = false}) {
    final sign = showSign && amount > 0 ? '+' : (showSign && amount < 0 ? '-' : '');
    final value = amount.abs().toStringAsFixed(2);
    return '$sign\u20B9$value';
  }

  static String _formatStatementNumber(DateTime? start, DateTime? end) {
    final now = DateTime.now();
    final period = '${(start ?? now).year}${(start ?? now).month.toString().padLeft(2, '0')}';
    return 'STMT-$period-${now.millisecondsSinceEpoch % 100000}';
  }

  /// Generate PDF report for transactions, styled like a bank statement.
  static Future<Uint8List> generateTransactionReport({
    DateTime? startDate,
    DateTime? endDate,
    bool includeCharts = true,
    bool includeSummary = true,
  }) async {
    final rawTransactions = await HybridStorageService.getTransactions();
    final transactions = rawTransactions.map((m) => _transactionFromMap(m)).toList();

    List<Transaction> filteredTransactions = transactions;
    if (startDate != null || endDate != null) {
      filteredTransactions = transactions.where((t) {
        if (startDate != null && t.date.isBefore(startDate)) return false;
        if (endDate != null && t.date.isAfter(endDate)) return false;
        return true;
      }).toList();
    }

    // Bank statements compute running balance chronologically (oldest first),
    // then are typically displayed newest-first. We compute ascending,
    // then reverse for display so the running balance is accurate.
    filteredTransactions.sort((a, b) => a.date.compareTo(b.date));

    final initialBalance = await HybridStorageService.getInitialBalance();
    final statementLines = <_StatementLine>[];
    double runningBalance = initialBalance;
    for (final t in filteredTransactions) {
      if (t.type == 'Credit') {
        runningBalance += t.amount;
      } else {
        runningBalance -= t.amount;
      }
      statementLines.add(_StatementLine(t, runningBalance));
    }

    final openingBalance = initialBalance;
    final closingBalance = statementLines.isNotEmpty ? statementLines.last.runningBalance : initialBalance;
    final summary = _calculateSummary(filteredTransactions, openingBalance, closingBalance);

    // Display newest-first, but keep the running balance computed above.
    final displayLines = statementLines.reversed.toList();

    final theme = await _theme();
    final pdf = pw.Document(theme: theme);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : _buildContinuationHeader(context),
        footer: (context) => _buildFooter(context),
        build: (pw.Context context) {
          return [
            _buildHeader(context, startDate, endDate),
            if (includeSummary) _buildSummarySection(context, summary, openingBalance, closingBalance),
            if (includeCharts) _buildChartsSection(context, filteredTransactions),
            ..._buildTransactionsTable(context, displayLines),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Header styled like a bank statement letterhead.
  static pw.Widget _buildHeader(pw.Context context, DateTime? startDate, DateTime? endDate) {
    final now = DateTime.now();
    final dateRange = _formatDateRange(startDate, endDate);
    final statementNo = _formatStatementNumber(startDate, endDate);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _appName,
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Personal Finance',
                    style: pw.TextStyle(fontSize: 9, color: _lightTextColor),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'STATEMENT OF ACCOUNT',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _primaryColor),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text('Statement No: $statementNo', style: pw.TextStyle(fontSize: 9, color: _lightTextColor)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(height: 1.2, color: _accentColor),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderMeta('Statement Period', dateRange),
              _buildHeaderMeta('Generated On', _formatDate(now)),
              _buildHeaderMeta('Currency', 'INR'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHeaderMeta(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _lightTextColor)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
      ],
    );
  }

  static pw.Widget _buildContinuationHeader(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 0.75)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(_appName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
          pw.Text('Statement of Account (contd.)', style: pw.TextStyle(fontSize: 9, color: _lightTextColor)),
        ],
      ),
    );
  }

  /// Account summary box: opening balance, credits, debits, closing balance.
  static pw.Widget _buildSummarySection(
      pw.Context context,
      Map<String, double> summary,
      double openingBalance,
      double closingBalance,
      ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _primaryColor,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Account Summary',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _textColor),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Opening Balance', openingBalance, PdfColors.white),
              _buildSummaryItem('Total Credits', summary['credits'] ?? 0, PdfColor.fromInt(0xFF6EE7A0)),
              _buildSummaryItem('Total Debits', summary['debits'] ?? 0, PdfColor.fromInt(0xFFFF8A80)),
              _buildSummaryItem('Closing Balance', closingBalance, PdfColors.white),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String label, double amount, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _lightTextColor)),
        pw.SizedBox(height: 4),
        pw.Text(
          _formatCurrency(amount),
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }

  static pw.Widget _buildChartsSection(pw.Context context, List<Transaction> transactions) {
    final expenseTransactions = transactions.where((t) => t.type == 'Debit').toList();
    if (expenseTransactions.isEmpty) return pw.SizedBox.shrink();

    final categoryBreakdown = <String, double>{};
    for (final t in expenseTransactions) {
      categoryBreakdown[t.category] = (categoryBreakdown[t.category] ?? 0) + t.amount;
    }
    final total = categoryBreakdown.values.fold(0.0, (a, b) => a + b);
    final sortedEntries = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Spend by Category',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _primaryColor),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _borderColor, width: 0.5),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              _headerRow(['Category', 'Amount', 'Share']),
              ...sortedEntries.map((entry) {
                final percentage = total == 0 ? 0.0 : (entry.value / total) * 100;
                return pw.TableRow(
                  children: [
                    _cell(entry.key),
                    _cell(_formatCurrency(entry.value)),
                    _cell('${percentage.toStringAsFixed(1)}%'),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// Transaction ledger with running balance — the core "bank statement" feel.
  static List<pw.Widget> _buildTransactionsTable(pw.Context context, List<_StatementLine> lines) {
    return [
      pw.Text(
        'Transaction History',
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _primaryColor),
      ),
      pw.SizedBox(height: 10),
      pw.Table(
        border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _borderColor, width: 0.5),
          top: pw.BorderSide(color: _borderColor, width: 0.75),
          bottom: pw.BorderSide(color: _borderColor, width: 0.75),
        ),
        columnWidths: const {
          0: pw.FixedColumnWidth(62), // Date
          1: pw.FlexColumnWidth(3), // Description
          2: pw.FixedColumnWidth(70), // Category
          3: pw.FixedColumnWidth(68), // Debit
          4: pw.FixedColumnWidth(68), // Credit
          5: pw.FixedColumnWidth(72), // Balance
        },
        children: [
          _headerRow(['Date', 'Description', 'Category', 'Debit', 'Credit', 'Balance']),
          ...lines.map((line) {
            final t = line.transaction;
            final isCredit = t.type == 'Credit';
            return pw.TableRow(
              children: [
                _cell(_formatDate(t.date)),
                _cell(t.description, maxLines: 2),
                _cell(t.category),
                _cell(isCredit ? '-' : _formatCurrency(t.amount), color: isCredit ? _lightTextColor : PdfColors.red800),
                _cell(isCredit ? _formatCurrency(t.amount) : '-', color: isCredit ? PdfColors.green800 : _lightTextColor),
                _cell(_formatCurrency(line.runningBalance), bold: true),
              ],
            );
          }),
        ],
      ),
      if (lines.isEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 20),
          child: pw.Center(
            child: pw.Text('No transactions in this period.', style: pw.TextStyle(fontSize: 10, color: _lightTextColor)),
          ),
        ),
    ];
  }

  static pw.TableRow _headerRow(List<String> labels) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF3F3F3)),
      children: labels
          .map((l) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text(l, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
      ))
          .toList(),
    );
  }

  static pw.Widget _cell(String text, {int maxLines = 1, PdfColor? color, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          color: color ?? PdfColors.black,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        maxLines: maxLines,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  /// Footer with page numbers and a bank-style disclaimer.
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 0.75)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'This is a system-generated statement from $_appName and does not require a signature.',
            style: pw.TextStyle(fontSize: 7.5, color: _lightTextColor),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 7.5, color: _lightTextColor),
          ),
        ],
      ),
    );
  }

  static Map<String, double> _calculateSummary(
      List<Transaction> transactions,
      double openingBalance,
      double closingBalance,
      ) {
    final totalCredits = transactions.where((t) => t.type == 'Credit').fold(0.0, (sum, t) => sum + t.amount);
    final totalDebits = transactions.where((t) => t.type == 'Debit').fold(0.0, (sum, t) => sum + t.amount);
    return {
      'credits': totalCredits,
      'debits': totalDebits,
      'opening': openingBalance,
      'closing': closingBalance,
    };
  }

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

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _formatDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate == null && endDate == null) return 'All Transactions';
    if (startDate == null) return 'Up to ${_formatDate(endDate!)}';
    if (endDate == null) return 'From ${_formatDate(startDate)}';
    return '${_formatDate(startDate)} - ${_formatDate(endDate)}';
  }

  /// Save PDF to device. Debug logging is gated behind [verbose] so it
  /// doesn't spam release logs.
  /// On iOS: Uses getApplicationDocumentsDirectory() (exposed via Files app).
  /// On Android: Targets user-visible Downloads directory (/storage/emulated/0/Download or getDownloadsDirectory()).
  static Future<String?> savePdfToDevice(
      Uint8List pdfBytes,
      String fileName, {
        bool verbose = false,
      }) async {
    try {
      Directory? directory;

      if (Platform.isAndroid) {
        // Try standard Android public Downloads directory first
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          directory = downloadDir;
        } else {
          try {
            directory = await getDownloadsDirectory();
          } catch (_) {}

          if (directory == null || !await directory.exists()) {
            final docsDir = Directory('/storage/emulated/0/Documents');
            if (await docsDir.exists()) {
              directory = docsDir;
            } else {
              directory = await getExternalStorageDirectory();
            }
          }
        }
      } else if (Platform.isIOS) {
        // On iOS, getApplicationDocumentsDirectory() is rendered in Files app
        // under "On My iPhone > Vaultic" via Info.plist keys
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      directory ??= await getApplicationDocumentsDirectory();

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final filePath = '${directory.path}/$fileName.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (!await file.exists()) {
        if (verbose) print('ERROR: File does not exist after writing to $filePath');
        return null;
      }

      if (verbose) print('PDF saved: $filePath (${pdfBytes.length} bytes)');
      return file.path;
    } catch (e) {
      if (verbose) print('Error saving PDF: $e (${e.runtimeType})');
      return null;
    }
  }
}