import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/transaction_history_model.dart';

// Example: Adobe PDF Services Integration
class AdobePdfService {
  static Future<Uint8List> generateTransactionReport({
    required List<Transaction> transactions,
    required Map<String, double> summary,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    
    // Prepare data for Adobe PDF Services
    final templateData = {
      'reportTitle': 'Transaction Report',
      'generatedDate': DateTime.now().toString(),
      'dateRange': _formatDateRange(startDate, endDate),
      'summary': {
        'totalCredits': summary['credits'] ?? 0,
        'totalDebits': summary['debits'] ?? 0,
        'balance': summary['balance'] ?? 0,
      },
      'transactions': transactions.map((t) => {
        'date': t.date.toString().split(' ')[0],
        'description': t.description,
        'category': t.category,
        'amount': t.amount,
        'type': t.type,
        'formattedAmount': '${t.type == 'Credit' ? '+' : '-'}Rs ${t.amount.toStringAsFixed(0)}',
      }).toList(),
    };
    
    // Call Adobe PDF Services API
    final response = await http.post(
      Uri.parse('https://pdf-services.adobe.io/operation/documentgeneration'),
      headers: {
        'Authorization': 'Bearer YOUR_ADOBE_TOKEN',
        'Content-Type': 'application/json',
        'x-api-key': 'YOUR_API_KEY',
      },
      body: jsonEncode({
        'template': {
          'name': 'transaction_report_template',
        },
        'data': templateData,
        'output': {
          'format': 'pdf',
        },
      }),
    );
    
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Adobe PDF Services error: ${response.statusCode}');
    }
  }
  
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
}
