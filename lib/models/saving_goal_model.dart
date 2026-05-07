import 'package:cloud_firestore/cloud_firestore.dart';

class SavingGoalModel {
  final String id;
  final String userId;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;

  SavingGoalModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': Timestamp.fromDate(targetDate),
    };
  }

  factory SavingGoalModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedDate;
    final dateVal = map['targetDate'];
    if (dateVal is Timestamp) {
      parsedDate = dateVal.toDate();
    } else if (dateVal is String) {
      parsedDate = DateTime.tryParse(dateVal) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return SavingGoalModel(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      targetAmount: (map['targetAmount'] ?? 0.0).toDouble(),
      currentAmount: (map['currentAmount'] ?? 0.0).toDouble(),
      targetDate: parsedDate,
    );
  }
}
