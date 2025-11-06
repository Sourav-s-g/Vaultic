class TransactionHistoryRequest {
  final String merchantId;
  final String goalId;
  final String fedId;
  final String mobileNumber;
  final String otherData;

  TransactionHistoryRequest({
    required this.merchantId,
    required this.goalId,
    required this.fedId,
    required this.mobileNumber,
    required this.otherData,
  });

  Map<String, dynamic> toJson() {
    return {
      'MerchantId': merchantId,
      'goalId': goalId,
      'MobileNumber': mobileNumber,
      'fedId': fedId,
      'OtherData': otherData,
    };
  }

  factory TransactionHistoryRequest.fromJson(Map<String, dynamic> json) {
    return TransactionHistoryRequest(
      merchantId: json['MerchantId'] ?? '',
      goalId: json['goalId'] ?? '',
      fedId: json['fedId'] ?? '',
      mobileNumber: json['MobileNumber'] ?? '',
      otherData: json['OtherData'] ?? '',
    );
  }
}

class TransactionHistoryResponse {
  final bool success;
  final String message;
  final List<Transaction>? transactions;
  final String? errorCode;

  TransactionHistoryResponse({
    required this.success,
    required this.message,
    this.transactions,
    this.errorCode,
  });

  factory TransactionHistoryResponse.fromJson(Map<String, dynamic> json) {
    return TransactionHistoryResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      transactions: json['transactions'] != null
          ? List<Transaction>.from(
              json['transactions'].map((x) => Transaction.fromJson(x)))
          : null,
      errorCode: json['errorCode'],
    );
  }
}

class Transaction {
  final String transactionId;
  final String description;
  final double amount;
  final String type; // Credit/Debit
  final DateTime date;
  final String category;
  final String status;

  Transaction({
    required this.transactionId,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
    required this.category,
    required this.status,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      transactionId: json['transactionId'] ?? '',
      description: json['description'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      type: json['type'] ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      category: json['category'] ?? '',
      status: json['status'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'description': description,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
      'category': category,
      'status': status,
    };
  }
}

