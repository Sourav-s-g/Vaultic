class ParsedTransaction {
  final double? amount;
  final String? category;
  final String? type; // 'Credit' or 'Debit'
  final String description;
  final DateTime? date;
  final double confidence; // 0.0 to 1.0
  final String rawInput;

  ParsedTransaction({
    this.amount,
    this.category,
    this.type,
    required this.description,
    this.date,
    this.confidence = 0.0,
    required this.rawInput,
  });

  bool get hasAmount => amount != null && amount! > 0;
  bool get hasCategory => category != null && category!.isNotEmpty;
  bool get hasType => type != null && type!.isNotEmpty;
  bool get isHighConfidence => confidence >= 0.7;
}

