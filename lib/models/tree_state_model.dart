import 'package:cloud_firestore/cloud_firestore.dart';

class TreeStateModel {
  final String userId;
  final int level;
  final int xp;
  final int waterDroplets;
  final DateTime? lastWatered;
  final DateTime? lastDailyReset;
  final Map<String, bool> completedTasks;

  TreeStateModel({
    required this.userId,
    required this.level,
    required this.xp,
    required this.waterDroplets,
    this.lastWatered,
    this.lastDailyReset,
    required this.completedTasks,
  });

  factory TreeStateModel.fromMap(Map<String, dynamic> map, String userId) {
    final rawTasks = map['completedTasks'] ?? {};
    final completedTasks = <String, bool>{
      'login': rawTasks['login'] == true,
      'transaction': rawTasks['transaction'] == true,
      'saving': rawTasks['saving'] == true,
    };

    DateTime? toDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return TreeStateModel(
      userId: userId,
      level: map['level'] ?? 1,
      xp: map['xp'] ?? 0,
      waterDroplets: map['waterDroplets'] ?? 3,
      lastWatered: toDateTime(map['lastWatered']),
      lastDailyReset: toDateTime(map['lastDailyReset']),
      completedTasks: completedTasks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'xp': xp,
      'waterDroplets': waterDroplets,
      'lastWatered': lastWatered != null ? Timestamp.fromDate(lastWatered!) : null,
      'lastDailyReset': lastDailyReset != null ? Timestamp.fromDate(lastDailyReset!) : null,
      'completedTasks': completedTasks,
    };
  }

  // Porcentaje de progreso dentro del nivel actual (0.0 a 1.0)
  double get progressPercentage {
    return (xp % 100) / 100.0;
  }

  // Nombre de la etapa de crecimiento actual
  String get stageLabel {
    if (level <= 2) return 'Semilla / Brote';
    if (level <= 4) return 'Planta Joven';
    if (level <= 6) return 'Arbusto';
    if (level <= 8) return 'Árbol Maduro';
    return 'Árbol Dorado de la Fortuna 🌟';
  }
}
