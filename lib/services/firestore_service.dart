import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../models/loan_model.dart';
import '../models/saving_goal_model.dart';
import '../models/category_model.dart';
import '../models/tree_state_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ================= TRANSACTIONS MODULE =================

  // Stream of transactions for a user
  Stream<List<TransactionModel>> getTransactions(String userId) {
    return _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Add a transaction
  Future<void> addTransaction(TransactionModel transaction) {
    return _db.collection('transactions').add(transaction.toMap());
  }

  // Delete a transaction
  Future<void> deleteTransaction(String id) {
    return _db.collection('transactions').doc(id).delete();
  }

  // Get total current balance (Total Incomes - Total Expenses)
  Stream<double> getBalance(String userId) {
    return _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0.0).toDouble();
        final type = data['type'] ?? 'expense';
        if (type == 'income') {
          total += amount;
        } else {
          total -= amount;
        }
      }
      return total;
    });
  }

  // Get actual balance as a Future (for blocking validations before saving)
  Future<double> getFutureBalance(String userId) async {
    final snapshot = await _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .get();
    
    double total = 0.0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0.0).toDouble();
      final type = data['type'] ?? 'expense';
      if (type == 'income') {
        total += amount;
      } else {
        total -= amount;
      }
    }

    // Restar el total ahorrado en las metas de ahorro
    final goalsSnapshot = await _db
        .collection('goals')
        .where('userId', isEqualTo: userId)
        .get();
    
    double totalSavings = 0.0;
    for (var doc in goalsSnapshot.docs) {
      totalSavings += (doc.data()['currentAmount'] ?? 0.0).toDouble();
    }

    return total - totalSavings;
  }

  // Get daily expenses
  Stream<double> getDailyExpenses(String userId, DateTime date) {
    DateTime start = DateTime(date.year, date.month, date.day);
    DateTime end = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      double total = 0.0;
      for (var doc in snapshot.docs) {
        final tx = TransactionModel.fromMap(doc.data(), doc.id);
        if (tx.type == TransactionType.expense) {
          if ((tx.date.isAfter(start) || tx.date.isAtSameMomentAs(start)) &&
              (tx.date.isBefore(end) || tx.date.isAtSameMomentAs(end))) {
            total += tx.amount;
          }
        }
      }
      return total;
    });
  }

  // Get monthly expenses
  Stream<double> getMonthlyExpenses(String userId, DateTime date) {
    DateTime start = DateTime(date.year, date.month, 1);
    DateTime end = DateTime(date.year, date.month + 1, 0, 23, 59, 59);

    return _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      double total = 0.0;
      for (var doc in snapshot.docs) {
        final tx = TransactionModel.fromMap(doc.data(), doc.id);
        if (tx.type == TransactionType.expense) {
          if ((tx.date.isAfter(start) || tx.date.isAtSameMomentAs(start)) &&
              (tx.date.isBefore(end) || tx.date.isAtSameMomentAs(end))) {
            total += tx.amount;
          }
        }
      }
      return total;
    });
  }

  // Get monthly incomes
  Stream<double> getMonthlyIncomes(String userId, DateTime date) {
    DateTime start = DateTime(date.year, date.month, 1);
    DateTime end = DateTime(date.year, date.month + 1, 0, 23, 59, 59);

    return _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      double total = 0.0;
      for (var doc in snapshot.docs) {
        final tx = TransactionModel.fromMap(doc.data(), doc.id);
        if (tx.type == TransactionType.income) {
          if ((tx.date.isAfter(start) || tx.date.isAtSameMomentAs(start)) &&
              (tx.date.isBefore(end) || tx.date.isAtSameMomentAs(end))) {
            total += tx.amount;
          }
        }
      }
      return total;
    });
  }

  // ================= LOANS MODULE =================

  // Get stream of loans
  Stream<List<LoanModel>> getLoans(String userId) {
    return _db
        .collection('loans')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => LoanModel.fromMap(doc.data(), doc.id))
          .toList();
      // Ordenar localmente por fecha de inicio descendente (startDate)
      list.sort((a, b) => b.startDate.compareTo(a.startDate));
      return list;
    });
  }

  // Add a new loan
  Future<void> addLoan(LoanModel loan) {
    return _db.collection('loans').add(loan.toMap());
  }

  // Delete a loan
  Future<void> deleteLoan(String id) {
    return _db.collection('loans').doc(id).delete();
  }

  // Toggle paid status of a loan and create automatic balance transaction
  Future<void> toggleLoanStatus(LoanModel loan) async {
    final newStatus = !loan.isPaid;
    
    // 1. Actualizar estado en la colección 'loans'
    await _db.collection('loans').doc(loan.id).update({'isPaid': newStatus});

    // 2. Crear transacción automática de balance
    if (newStatus == true) {
      // El préstamo se ha marcado como pagado
      TransactionModel tx;
      if (loan.type == LoanType.lent) {
        // Nos devuelven el dinero que prestamos -> Ingreso (Reintegrar saldo)
        tx = TransactionModel(
          id: '',
          userId: loan.userId,
          description: 'Reintegro: ${loan.personName} pagó préstamo${loan.description.isNotEmpty ? ' (${loan.description})' : ''}',
          amount: loan.amount,
          date: DateTime.now(),
          category: 'Préstamos',
          type: TransactionType.income,
        );
      } else {
        // Pagamos el dinero que nos prestaron -> Gasto
        tx = TransactionModel(
          id: '',
          userId: loan.userId,
          description: 'Pago de préstamo de ${loan.personName}${loan.description.isNotEmpty ? ' (${loan.description})' : ''}',
          amount: loan.amount,
          date: DateTime.now(),
          category: 'Préstamos',
          type: TransactionType.expense,
        );
      }
      await addTransaction(tx);
    } else {
      // El préstamo se marcó como NO pagado (reversión)
      TransactionModel tx;
      if (loan.type == LoanType.lent) {
        // Se revierte el ingreso -> Gasto
        tx = TransactionModel(
          id: '',
          userId: loan.userId,
          description: 'Reversión: ${loan.personName} aún debe préstamo',
          amount: loan.amount,
          date: DateTime.now(),
          category: 'Préstamos',
          type: TransactionType.expense,
        );
      } else {
        // Se revierte el gasto -> Ingreso
        tx = TransactionModel(
          id: '',
          userId: loan.userId,
          description: 'Reversión: Pago no realizado a ${loan.personName}',
          amount: loan.amount,
          date: DateTime.now(),
          category: 'Préstamos',
          type: TransactionType.income,
        );
      }
      await addTransaction(tx);
    }
  }

  // ================= SAVING GOALS MODULE =================

  // Get stream of saving goals
  Stream<List<SavingGoalModel>> getSavingGoals(String userId) {
    return _db
        .collection('goals')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavingGoalModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Add a new saving goal
  Future<void> addSavingGoal(SavingGoalModel goal) {
    return _db.collection('goals').add(goal.toMap());
  }

  // Delete a saving goal
  Future<void> deleteSavingGoal(String id) {
    return _db.collection('goals').doc(id).delete();
  }

  // Update current amount saved in a goal (Aportar / Retirar) and create automatic balance transaction
  Future<void> updateSavingGoalAmount(SavingGoalModel goal, double amt, bool isContribution) async {
    final newAmount = isContribution ? (goal.currentAmount + amt) : (goal.currentAmount - amt);
    
    // 1. Actualizar el monto acumulado de la meta
    await _db.collection('goals').doc(goal.id).update({'currentAmount': newAmount});

    // 2. Crear una transacción de ajuste de balance automática
    final tx = TransactionModel(
      id: '',
      userId: goal.userId,
      description: isContribution 
          ? 'Aporte a meta: ${goal.title}' 
          : 'Retiro de meta: ${goal.title}',
      amount: amt,
      date: DateTime.now(),
      category: 'Ahorro',
      type: isContribution ? TransactionType.expense : TransactionType.income,
    );
    await addTransaction(tx);
  }

  // ================= CUSTOM CATEGORIES MODULE =================

  // Get stream of custom categories
  Stream<List<CategoryModel>> getCustomCategories(String userId) {
    return _db
        .collection('categories')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Add a custom category
  Future<void> addCustomCategory(CategoryModel category) {
    return _db.collection('categories').add(category.toMap());
  }

  // ================= GAME / TREE MODULE =================

  // Obtener flujo en tiempo real del estado del juego
  Stream<TreeStateModel?> getTreeState(String userId) {
    return _db
        .collection('game_state')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) {
            return null;
          }
          return TreeStateModel.fromMap(snapshot.data()!, userId);
        });
  }

  // Regar el árbol (resta 1 gota, añade 10 XP, actualiza nivel)
  Future<void> waterTree(String userId) async {
    final docRef = _db.collection('game_state').doc(userId);
    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) return;

    final data = snapshot.data()!;
    int droplets = data['waterDroplets'] ?? 0;
    if (droplets <= 0) return; // Sin gotas para regar

    int xp = data['xp'] ?? 0;
    int currentLevel = data['level'] ?? 1;

    droplets -= 1;
    xp += 10;

    // Calcular nivel: Cada nivel requiere 100 XP (Nivel 1 -> 0 XP, Nivel 2 -> 100 XP, etc.)
    int newLevel = (xp / 100).floor() + 1;

    await docRef.update({
      'waterDroplets': droplets,
      'xp': xp,
      'level': newLevel,
      'lastWatered': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Otorgar recompensa de gotas de agua al completar tarea diaria
  Future<void> completeDailyTask(String userId, String taskKey) async {
    final docRef = _db.collection('game_state').doc(userId);
    final snapshot = await docRef.get();
    
    // Si no existe, inicializar el estado del juego
    if (!snapshot.exists || snapshot.data() == null) {
      await checkAndResetDailyTasks(userId);
      return;
    }

    final data = snapshot.data()!;
    final completedTasks = Map<String, dynamic>.from(data['completedTasks'] ?? {});
    
    // Si la tarea ya se completó hoy, no hacer nada
    if (completedTasks[taskKey] == true) return;

    // Otorgar recompensas en gotas
    int reward = 0;
    if (taskKey == 'login') reward = 1;
    else if (taskKey == 'transaction') reward = 2;
    else if (taskKey == 'saving') reward = 3;

    int currentDroplets = data['waterDroplets'] ?? 0;
    completedTasks[taskKey] = true;

    await docRef.update({
      'waterDroplets': currentDroplets + reward,
      'completedTasks': completedTasks,
    });
  }

  // Validar cambio diario para resetear las tareas y otorgar el login droplet
  Future<void> checkAndResetDailyTasks(String userId) async {
    final docRef = _db.collection('game_state').doc(userId);
    final snapshot = await docRef.get();
    final now = DateTime.now();

    if (!snapshot.exists || snapshot.data() == null) {
      // Estado de juego inicial para el nuevo usuario
      final newState = TreeStateModel(
        userId: userId,
        level: 1,
        xp: 0,
        waterDroplets: 3 + 1, // 3 iniciales + 1 por la visita de hoy
        lastWatered: null,
        lastDailyReset: now,
        completedTasks: {
          'login': true, // Completa login automáticamente
          'transaction': false,
          'saving': false,
        },
      );
      await docRef.set(newState.toMap());
      return;
    }

    final data = snapshot.data()!;
    DateTime? lastReset;
    final rawReset = data['lastDailyReset'];
    if (rawReset is Timestamp) {
      lastReset = rawReset.toDate();
    } else if (rawReset is String) {
      lastReset = DateTime.tryParse(rawReset);
    }

    // Verificar si es un día calendario distinto
    bool needsReset = lastReset == null ||
        lastReset.year != now.year ||
        lastReset.month != now.month ||
        lastReset.day != now.day;

    if (needsReset) {
      int droplets = data['waterDroplets'] ?? 0;
      
      await docRef.update({
        'lastDailyReset': Timestamp.fromDate(now),
        'waterDroplets': droplets + 1, // Recompensa diaria por ingresar
        'completedTasks': {
          'login': true,
          'transaction': false,
          'saving': false,
        },
      });
    }
  }
}
