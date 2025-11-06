import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/transaction_history_model.dart';
import 'credential_service.dart';

class PdfShiftService {
  /// Generate PDF using PDFShift API
  static Future<Uint8List> generateTransactionReport({
    required List<Transaction> transactions,
    required Map<String, double> summary,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    
    // Get API key from secure credential service
    final apiKey = CredentialService.pdfshiftApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('PDFShift API key not configured. Please set PDFSHIFT_API_KEY in your .env file.');
    }
    
    // Create HTML template
    final html = _createHtmlTemplate(transactions, summary, startDate, endDate);
    
    // Debug: Print HTML to console (remove in production)
    print('=== HTML TEMPLATE ===');
    print(html);
    print('=== END HTML ===');
    
    try {
      // Call PDFShift API (exactly like your Python example)
      final response = await http.post(
        Uri.parse('https://api.pdfshift.io/v3/convert/pdf'),
        headers: {
          'X-API-Key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'source': html,
          'landscape': false,
          'use_print': false,
          'format': 'A4',
          'margin': '20mm',
        }),
      );
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('PDFShift API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to generate PDF: $e');
    }
  }
  
  /// Create HTML template for the PDF
  static String _createHtmlTemplate(
    List<Transaction> transactions,
    Map<String, double> summary,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    final dateRange = _formatDateRange(startDate, endDate);
    final generatedDate = DateTime.now().toString().split(' ')[0];
    
    // Calculate category-wise statistics
    final categoryStats = _calculateCategoryStats(transactions);
    
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <style>
            body { 
                font-family: 'Arial', sans-serif; 
                margin: 0; 
                padding: 20px; 
                background: white;
                color: #333;
            }
            .header { 
                background: linear-gradient(135deg, #032221, #00C851); 
                color: white; 
                padding: 30px; 
                text-align: center; 
                border-radius: 10px;
                margin-bottom: 30px;
            }
            .header h1 { 
                margin: 0; 
                font-size: 32px; 
                font-weight: bold;
            }
            .header h2 { 
                margin: 10px 0 0 0; 
                font-size: 18px; 
                opacity: 0.9;
            }
            .header p { 
                margin: 5px 0 0 0; 
                font-size: 14px; 
                opacity: 0.8;
            }
            .summary { 
                display: flex; 
                justify-content: space-around; 
                margin: 30px 0; 
                gap: 20px;
            }
            .summary-item { 
                text-align: center; 
                padding: 20px; 
                border: 2px solid #e0e0e0; 
                border-radius: 10px;
                flex: 1;
                background: #f9f9f9;
            }
            .summary-item h3 { 
                margin: 0 0 10px 0; 
                font-size: 24px; 
                font-weight: bold;
            }
            .summary-item p { 
                margin: 0; 
                font-size: 14px; 
                color: #666;
            }
            .income { color: #00C851 !important; }
            .expense { color: #ff4444 !important; }
            .balance { color: #2196F3 !important; }
            table { 
                width: 100%; 
                border-collapse: collapse; 
                margin: 30px 0; 
                background: white;
                border-radius: 10px;
                overflow: hidden;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            }
            th, td { 
                border: 1px solid #e0e0e0; 
                padding: 12px; 
                text-align: left; 
            }
            th { 
                background: linear-gradient(135deg, #032221, #00C851); 
                color: white; 
                font-weight: bold;
                font-size: 14px;
            }
            td { 
                font-size: 13px;
            }
            tr:nth-child(even) { 
                background-color: #f9f9f9; 
            }
            tr:hover { 
                background-color: #f0f0f0; 
            }
            .footer { 
                text-align: center; 
                margin-top: 40px; 
                padding: 20px; 
                color: #666; 
                font-size: 12px;
                border-top: 1px solid #e0e0e0;
            }
            .amount-positive { color: #00C851; font-weight: bold; }
            .amount-negative { color: #ff4444; font-weight: bold; }
            .category-summary { 
                margin: 30px 0; 
                background: #f9f9f9; 
                border-radius: 10px; 
                padding: 20px;
                border: 1px solid #e0e0e0;
            }
            .category-summary h2 { 
                margin: 0 0 20px 0; 
                font-size: 20px; 
                color: #032221; 
                text-align: center;
                font-weight: bold;
            }
            .category-stats { 
                display: flex; 
                flex-direction: column; 
                gap: 12px;
            }
            .category-item { 
                display: flex; 
                justify-content: space-between; 
                align-items: center; 
                padding: 12px 16px; 
                background: white; 
                border-radius: 8px; 
                border: 1px solid #e0e0e0;
                box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            }
            .category-name { 
                font-weight: bold; 
                font-size: 14px; 
                color: #032221;
                flex: 1;
            }
            .category-amounts { 
                display: flex; 
                flex-direction: column; 
                align-items: flex-end; 
                gap: 4px;
            }
            .total-amount { 
                font-weight: bold; 
                font-size: 16px; 
                color: #00C851;
            }
            .avg-amount { 
                font-size: 12px; 
                color: #666;
            }
            .count { 
                font-size: 11px; 
                color: #999;
            }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>VAULTIC</h1>
            <h2>Transaction Report</h2>
            <p>Generated: $generatedDate | Period: $dateRange</p>
        </div>
        
        <div class="summary">
            <div class="summary-item">
                <h3 class="income">Rs ${summary['income']?.toStringAsFixed(0) ?? '0'}</h3>
                <p>Total Income</p>
            </div>
            <div class="summary-item">
                <h3 class="expense">Rs ${summary['expenses']?.toStringAsFixed(0) ?? '0'}</h3>
                <p>Total Expenses</p>
            </div>
            <div class="summary-item">
                <h3 class="balance">Rs ${summary['balance']?.toStringAsFixed(0) ?? '0'}</h3>
                <p>Balance</p>
            </div>
        </div>
        
        <div class="category-summary">
            <h2>Category Breakdown</h2>
            <div class="category-stats">
                ${categoryStats.entries.map((entry) => '''
                    <div class="category-item">
                        <div class="category-name">${_sanitizeText(entry.key)}</div>
                        <div class="category-amounts">
                            <span class="total-amount">Rs ${entry.value['total']?.toStringAsFixed(0) ?? '0'}</span>
                            <span class="avg-amount">Avg: Rs ${entry.value['average']?.toStringAsFixed(0) ?? '0'}</span>
                            <span class="count">${entry.value['count']} transactions</span>
                        </div>
                    </div>
                ''').join()}
            </div>
        </div>
        
        <table>
            <thead>
                <tr>
                    <th>Date</th>
                    <th>Description</th>
                    <th>Category</th>
                    <th>Amount</th>
                    <th>Type</th>
                </tr>
            </thead>
            <tbody>
                ${transactions.map((t) => '''
                    <tr>
                        <td>${t.date.toString().split(' ')[0]}</td>
                        <td>${_sanitizeText(t.description)}</td>
                        <td>${_sanitizeText(t.category)}</td>
                        <td class="${t.type == 'Credit' ? 'amount-positive' : 'amount-negative'}">
                            ${t.type == 'Credit' ? '+' : '-'}Rs ${t.amount.toStringAsFixed(0)}
                        </td>
                        <td>${t.type}</td>
                    </tr>
                ''').join()}
            </tbody>
        </table>
        
        <div class="footer">
            <p>Generated by Vaultic App • ${DateTime.now().year}</p>
        </div>
    </body>
    </html>
    ''';
  }
  
  /// Format date range for display
  static String _formatDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate == null && endDate == null) {
      return 'All Transactions';
    } else if (startDate == null) {
      return 'Up to ${endDate!.toString().split(' ')[0]}';
    } else if (endDate == null) {
      return 'From ${startDate.toString().split(' ')[0]}';
    } else {
      return '${startDate.toString().split(' ')[0]} - ${endDate.toString().split(' ')[0]}';
    }
  }
  
  /// Calculate category-wise statistics
  static Map<String, Map<String, dynamic>> _calculateCategoryStats(List<Transaction> transactions) {
    final Map<String, List<double>> categoryAmounts = {};
    
    // Group transactions by category
    for (final transaction in transactions) {
      final category = transaction.category.isEmpty ? 'Uncategorized' : transaction.category;
      categoryAmounts.putIfAbsent(category, () => []).add(transaction.amount);
    }
    
    // Calculate statistics for each category
    final Map<String, Map<String, dynamic>> categoryStats = {};
    for (final entry in categoryAmounts.entries) {
      final category = entry.key;
      final amounts = entry.value;
      
      final total = amounts.fold(0.0, (sum, amount) => sum + amount);
      final average = amounts.isNotEmpty ? total / amounts.length : 0.0;
      final count = amounts.length;
      
      categoryStats[category] = {
        'total': total,
        'average': average,
        'count': count,
      };
    }
    
    // Sort categories by total amount (descending)
    final sortedEntries = categoryStats.entries.toList()
      ..sort((a, b) => (b.value['total'] as double).compareTo(a.value['total'] as double));
    
    return Map.fromEntries(sortedEntries);
  }
  
  /// Sanitize text to prevent HTML issues
  static String _sanitizeText(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
