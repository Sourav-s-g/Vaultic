class Trip {
  final String tripId;
  final String name;
  final List<String> categories;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? description;
  final double? budget;
  final Map<String, double>? categoryBudgets;

  Trip({
    required this.tripId,
    required this.name,
    required this.categories,
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.description,
    this.budget,
    this.categoryBudgets,
  });

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'name': name,
      'categories': categories,
      'createdAt': createdAt.toIso8601String(),
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'description': description,
      'budget': budget,
      'categoryBudgets': categoryBudgets,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      tripId: map['tripId'] ?? '',
      name: map['name'] ?? '',
      categories: List<String>.from(map['categories'] ?? []),
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : null,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      description: map['description'],
      budget: map['budget']?.toDouble(),
      categoryBudgets: map['categoryBudgets'] != null 
          ? Map<String, double>.from(map['categoryBudgets'])
          : null,
    );
  }
}
