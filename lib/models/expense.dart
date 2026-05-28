import 'package:uuid/uuid.dart';

class Expense {
  final String id;
  final String rawInput;
  final String category;
  final int amount;
  final DateTime createdAt;
  final String? memo;

  Expense({
    String? id,
    required this.rawInput,
    required this.category,
    required this.amount,
    DateTime? createdAt,
    this.memo,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rawInput': rawInput,
      'category': category,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'memo': memo,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      rawInput: json['rawInput'] as String,
      category: json['category'] as String,
      amount: json['amount'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      memo: json['memo'] as String?,
    );
  }
}
