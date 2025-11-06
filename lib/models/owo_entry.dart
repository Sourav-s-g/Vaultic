class OweEntry {
  final String id; // uuid or timestamp-based
  final String counterparty;
  final String direction; // 'owe' or 'owned'
  final double amount;
  final String note;
  final DateTime createdAt;
  final DateTime? dueDate;
  final bool settled;

  OweEntry({
    required this.id,
    required this.counterparty,
    required this.direction,
    required this.amount,
    required this.note,
    required this.createdAt,
    this.dueDate,
    this.settled = false,
  });

  factory OweEntry.fromMap(Map<String, dynamic> m) {
    return OweEntry(
      id: (m['id'] ?? '').toString(),
      counterparty: (m['counterparty'] ?? '').toString(),
      direction: (m['direction'] ?? 'owe').toString(),
      amount: (m['amount'] is num) ? (m['amount'] as num).toDouble() : double.tryParse((m['amount'] ?? '0').toString()) ?? 0.0,
      note: (m['note'] ?? '').toString(),
      createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString()) ?? DateTime.now(),
      dueDate: (m['dueDate'] != null && (m['dueDate'] as String).isNotEmpty) ? DateTime.tryParse((m['dueDate']).toString()) : null,
      settled: (m['settled'] ?? false) == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'counterparty': counterparty,
      'direction': direction,
      'amount': amount,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'settled': settled,
    };
  }
}


