class OweEntry {
  final String id; // This will store our stable identifier (owo_id)
  final String counterparty;
  final String direction; // 'owe' or 'owned'
  final double amount;
  final String note;
  final DateTime createdAt;
  final DateTime? dueDate;
  final bool settled;
  final String syncStatus; // 'synced' or 'pending'

  OweEntry({
    required this.id,
    required this.counterparty,
    required this.direction,
    required this.amount,
    required this.note,
    required this.createdAt,
    this.dueDate,
    this.settled = false,
    this.syncStatus = 'synced',
  });

  factory OweEntry.fromMap(Map<String, dynamic> m) {
    // PREFER owo_id (stable ID) over id (Supabase internal PK)
    final stableId = (m['owo_id'] ?? m['owoId'] ?? m['id'] ?? '').toString();
    
    return OweEntry(
      id: stableId,
      counterparty: (m['counterparty'] ?? '').toString(),
      direction: (m['direction'] ?? 'owe').toString(),
      amount: (m['amount'] is num)
          ? (m['amount'] as num).toDouble()
          : double.tryParse((m['amount'] ?? '0').toString()) ?? 0.0,
      note: (m['note'] ?? '').toString(),
      createdAt: DateTime.tryParse((m['createdAt'] ?? m['created_at'] ?? '').toString()) ?? DateTime.now(),
      dueDate: (m['dueDate'] != null || m['due_date'] != null)
          ? DateTime.tryParse((m['dueDate'] ?? m['due_date']).toString())
          : null,
      settled: (m['settled'] ?? false) == true,
      syncStatus: (m['_syncStatus'] ?? 'synced').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id, // This is our stable owo_id
      'counterparty': counterparty,
      'direction': direction,
      'amount': amount,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'settled': settled,
      '_syncStatus': syncStatus,
    };
  }
}
