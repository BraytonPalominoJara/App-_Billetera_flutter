import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { expense, income }

class TransactionModel {
  final String id;
  final String userId;
  final String description;
  final double amount;
  final DateTime date;
  final String category;
  final TransactionType type;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'description': description,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'category': category,
      'type': type.name,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedDate;
    final dateVal = map['date'];
    if (dateVal is Timestamp) {
      parsedDate = dateVal.toDate();
    } else if (dateVal is String) {
      parsedDate = DateTime.tryParse(dateVal) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return TransactionModel(
      id: id,
      userId: map['userId'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: parsedDate,
      category: map['category'] ?? 'General',
      type: map['type'] == 'expense' ? TransactionType.expense : TransactionType.income,
    );
  }
}
