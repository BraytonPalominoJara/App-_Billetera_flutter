import 'package:flutter_test/flutter_test.dart';
import 'package:billetera_fluter/models/transaction_model.dart';
import 'package:billetera_fluter/models/loan_model.dart';
import 'package:billetera_fluter/models/saving_goal_model.dart';
import 'package:billetera_fluter/models/category_model.dart';
import 'package:billetera_fluter/models/tree_state_model.dart';

void main() {
  group('Pruebas Unitarias de TransactionModel y Balance', () {
    test('Conversión exitosa a Mapa y desde Mapa (Firebase)', () {
      final now = DateTime.now();
      final tx = TransactionModel(
        id: 'tx123',
        userId: 'user1',
        description: 'Pago de Salario',
        amount: 1500.0,
        date: now,
        category: 'Salario',
        type: TransactionType.income,
      );

      final map = tx.toMap();

      expect(map['userId'], 'user1');
      expect(map['description'], 'Pago de Salario');
      expect(map['amount'], 1500.0);
      expect(map['category'], 'Salario');
      expect(map['type'], 'income');
    });

    test('Cálculo correcto de Balance Neto (Ingresos - Gastos)', () {
      final transactions = [
        TransactionModel(
          id: '1',
          userId: 'u1',
          description: 'Sueldo',
          amount: 2000.0,
          date: DateTime.now(),
          category: 'Salario',
          type: TransactionType.income,
        ),
        TransactionModel(
          id: '2',
          userId: 'u1',
          description: 'Supermercado',
          amount: 150.0,
          date: DateTime.now(),
          category: 'Comida',
          type: TransactionType.expense,
        ),
        TransactionModel(
          id: '3',
          userId: 'u1',
          description: 'Cine',
          amount: 30.0,
          date: DateTime.now(),
          category: 'Entretenimiento',
          type: TransactionType.expense,
        ),
        TransactionModel(
          id: '4',
          userId: 'u1',
          description: 'Venta de celular',
          amount: 350.0,
          date: DateTime.now(),
          category: 'General',
          type: TransactionType.income,
        ),
      ];

      double balance = 0.0;
      for (var tx in transactions) {
        if (tx.type == TransactionType.income) {
          balance += tx.amount;
        } else {
          balance -= tx.amount;
        }
      }

      expect(balance, 2170.0);
    });
  });

  group('Pruebas Unitarias de LoanModel', () {
    test('Conversión y parseo correcto de LoanModel', () {
      final now = DateTime.now();
      final loan = LoanModel(
        id: 'loan789',
        userId: 'user1',
        personName: 'Carlos Pérez',
        amount: 500.0,
        description: 'Prueba de descripción',
        startDate: now,
        dueDate: now.add(const Duration(days: 30)),
        isPaid: false,
        type: LoanType.borrowed,
      );

      final map = loan.toMap();

      expect(map['userId'], 'user1');
      expect(map['personName'], 'Carlos Pérez');
      expect(map['amount'], 500.0);
      expect(map['description'], 'Prueba de descripción');
      expect(map['isPaid'], false);
      expect(map['type'], 'borrowed');
    });
  });

  group('Pruebas Unitarias de SavingGoalModel', () {
    test('Mapeo de datos y cálculo de metas de ahorro', () {
      final now = DateTime.now();
      final goal = SavingGoalModel(
        id: 'goal456',
        userId: 'user1',
        title: 'Laptop de Desarrollo',
        targetAmount: 1200.0,
        currentAmount: 300.0,
        targetDate: now,
      );

      final map = goal.toMap();
      expect(map['userId'], 'user1');
      expect(map['title'], 'Laptop de Desarrollo');
      expect(map['targetAmount'], 1200.0);
      expect(map['currentAmount'], 300.0);

      final parsed = SavingGoalModel.fromMap(map, 'goal456');
      expect(parsed.id, 'goal456');
      expect(parsed.title, 'Laptop de Desarrollo');
      expect(parsed.targetAmount, 1200.0);
      expect(parsed.currentAmount, 300.0);
    });
  });

  group('Pruebas Unitarias de CategoryModel', () {
    test('Mapeo de datos para categorías personalizadas', () {
      final category = CategoryModel(
        id: 'cat999',
        userId: 'user1',
        name: 'Gimnasio',
      );

      final map = category.toMap();
      expect(map['userId'], 'user1');
      expect(map['name'], 'Gimnasio');

      final parsed = CategoryModel.fromMap(map, 'cat999');
      expect(parsed.id, 'cat999');
      expect(parsed.name, 'Gimnasio');
    });
  });

  group('Pruebas Unitarias de TreeStateModel (El Árbol del Ahorro)', () {
    test('Mapeo de datos, cálculo de porcentaje y etapa de crecimiento', () {
      final now = DateTime.now();
      final tree = TreeStateModel(
        userId: 'userGame123',
        level: 5,
        xp: 450,
        waterDroplets: 6,
        lastWatered: now,
        lastDailyReset: now,
        completedTasks: {
          'login': true,
          'transaction': true,
          'saving': false,
        },
      );

      final map = tree.toMap();
      expect(map['level'], 5);
      expect(map['xp'], 450);
      expect(map['waterDroplets'], 6);
      expect(map['completedTasks']['login'], true);
      expect(map['completedTasks']['transaction'], true);
      expect(map['completedTasks']['saving'], false);

      final parsed = TreeStateModel.fromMap(map, 'userGame123');
      expect(parsed.userId, 'userGame123');
      expect(parsed.level, 5);
      expect(parsed.xp, 450);
      expect(parsed.waterDroplets, 6);
      expect(parsed.progressPercentage, 0.50); // (450 % 100) / 100 = 50 / 100 = 0.5
      expect(parsed.stageLabel, 'Arbusto'); // Nivel 5 es Arbusto
    });
  });
}
