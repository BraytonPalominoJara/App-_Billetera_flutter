import 'package:cloud_firestore/cloud_firestore.dart';

enum LoanType { borrowed, lent } // borrowed = nos prestan, lent = prestamos

class LoanModel {
  final String id;
  final String userId;
  final String personName;
  final double amount;
  final String description; // Nueva descripción del préstamo
  final DateTime startDate;
  final DateTime dueDate;
  final bool isPaid;
  final LoanType type;

  LoanModel({
    required this.id,
    required this.userId,
    required this.personName,
    required this.amount,
    required this.description,
    required this.startDate,
    required this.dueDate,
    required this.isPaid,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'personName': personName,
      'amount': amount,
      'description': description,
      'startDate': Timestamp.fromDate(startDate),
      'dueDate': Timestamp.fromDate(dueDate),
      'isPaid': isPaid,
      'type': type.name,
    };
  }

  factory LoanModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedStart;
    final startVal = map['startDate'];
    if (startVal is Timestamp) {
      parsedStart = startVal.toDate();
    } else if (startVal is String) {
      parsedStart = DateTime.tryParse(startVal) ?? DateTime.now();
    } else {
      parsedStart = DateTime.now();
    }

    DateTime parsedDue;
    final dueVal = map['dueDate'];
    if (dueVal is Timestamp) {
      parsedDue = dueVal.toDate();
    } else if (dueVal is String) {
      parsedDue = DateTime.tryParse(dueVal) ?? DateTime.now();
    } else {
      parsedDue = DateTime.now();
    }

    return LoanModel(
      id: id,
      userId: map['userId'] ?? '',
      personName: map['personName'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      startDate: parsedStart,
      dueDate: parsedDue,
      isPaid: map['isPaid'] ?? false,
      type: map['type'] == 'lent' ? LoanType.lent : LoanType.borrowed,
    );
  }
}
