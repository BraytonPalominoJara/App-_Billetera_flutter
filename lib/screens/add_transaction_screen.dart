import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/transaction_model.dart';
import '../models/loan_model.dart';
import '../models/category_model.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String _category = 'Comida';
  bool _isLoading = false;

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = Provider.of<User?>(context, listen: false);
    final service = Provider.of<FirestoreService>(context, listen: false);

    if (user != null) {
      final txAmount = double.parse(_amountController.text);
      final tx = TransactionModel(
        id: '', // Firestore genera el ID automáticamente
        userId: user.uid,
        description: _descriptionController.text.trim(),
        amount: txAmount,
        date: DateTime.now(),
        category: _category,
        type: _type,
      );

      try {
        // Si es un Gasto, validar si excede el saldo actual
        if (_type == TransactionType.expense) {
          final currentBalance = await service.getFutureBalance(user.uid);
          if (currentBalance - txAmount < 0) {
            // El gasto excede el saldo. Mostramos alerta de saldo negativo.
            if (mounted) {
              _showNegativeBalanceDialog(currentBalance, txAmount, user.uid, service, tx);
            }
            return;
          }
        }

        // Si no excede o es un ingreso, se guarda directamente
        await service.addTransaction(tx);
        await service.completeDailyTask(user.uid, 'transaction');
        if (mounted) Navigator.pop(context);
      } catch (e) {
        setState(() => _isLoading = false);
        _showSnackBar('Error al guardar la transacción');
      }
    }
  }

  // Alerta Interactiva de Saldo Negativo / Préstamos
  void _showNegativeBalanceDialog(
    double balance,
    double expense,
    String userId,
    FirestoreService service,
    TransactionModel tx,
  ) {
    final deficit = expense - balance;
    final personController = TextEditingController();
    final loanAmountController = TextEditingController(text: deficit.toStringAsFixed(2));
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
                  SizedBox(width: 8),
                  Text('Saldo Insuficiente', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: dialogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estás registrando un gasto de \$${expense.toStringAsFixed(2)}, pero tu saldo actual es de \$${balance.toStringAsFixed(2)}.',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Te faltan \$${deficit.toStringAsFixed(2)}. ¿De dónde proviene este dinero?',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      
                      // Campos del Préstamo (si deciden registrar préstamo)
                      TextFormField(
                        controller: personController,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
                        decoration: InputDecoration(
                          labelText: '¿Quién te prestó este dinero?',
                          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          filled: true,
                          fillColor: isDark ? Colors.black26 : Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.isEmpty ? 'Ingresa el nombre del prestamista' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: loanAmountController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
                        decoration: InputDecoration(
                          labelText: 'Monto del préstamo',
                          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          prefixIcon: const Icon(Icons.monetization_on_outlined),
                          filled: true,
                          fillColor: isDark ? Colors.black26 : Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v!.isEmpty) return 'Ingresa un monto';
                          if (double.tryParse(v) == null) return 'No es válido';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                // Botón Cancelar
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _isLoading = false);
                  },
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                
                // Botón Forzar Gasto (Otros ahorros)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context); // Cierra dialogo
                    try {
                      await service.addTransaction(tx);
                      await service.completeDailyTask(userId, 'transaction');
                      if (mounted) Navigator.pop(this.context); // Cierra pantalla
                    } catch (e) {
                      setState(() => _isLoading = false);
                      _showSnackBar('Error al registrar la transacción');
                    }
                  },
                  child: Text(
                    'Forzar Gasto',
                    style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                ),
                
                // Botón Guardar con Préstamo
                ElevatedButton(
                  onPressed: () async {
                    if (!dialogFormKey.currentState!.validate()) return;
                    
                    Navigator.pop(context); // Cierra dialogo
                    try {
                      final loanAmount = double.parse(loanAmountController.text);
                      
                      // 1. Crear el Préstamo en Firestore
                      final loan = LoanModel(
                        id: '',
                        userId: userId,
                        personName: personController.text.trim(),
                        amount: loanAmount,
                        description: 'Financiamiento automático de saldo insuficiente',
                        startDate: DateTime.now(),
                        dueDate: DateTime.now().add(const Duration(days: 30)), // 30 días sugeridos
                        isPaid: false,
                        type: LoanType.borrowed,
                      );
                      await service.addLoan(loan);

                      // 2. Registrar el Gasto
                      await service.addTransaction(tx);

                      // 3. Crear una Transacción de Ingreso adicional para cubrir el préstamo en el saldo
                      // (Esto hace que el saldo cuadre perfectamente, ingresando el préstamo a la cuenta)
                      final loanTx = TransactionModel(
                        id: '',
                        userId: userId,
                        description: 'Préstamo de ${personController.text.trim()}',
                        amount: loanAmount,
                        date: DateTime.now(),
                        category: 'General',
                        type: TransactionType.income,
                      );
                      await service.addTransaction(loanTx);
                      await service.completeDailyTask(userId, 'transaction');
                      if (mounted) Navigator.pop(this.context); // Cierra pantalla
                    } catch (e) {
                      setState(() => _isLoading = false);
                      _showSnackBar('Error al procesar el préstamo');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Es Préstamo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF6366F1); // Indigo
    final user = Provider.of<User?>(context);
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Nuevo Registro',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Selector de Gasto / Ingreso Premium (Segmented Toggle)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _type = TransactionType.expense),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _type == TransactionType.expense
                                  ? Colors.redAccent
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'Gasto',
                                style: TextStyle(
                                  color: _type == TransactionType.expense ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _type = TransactionType.income),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _type == TransactionType.income
                                  ? Colors.green
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'Ingreso',
                                style: TextStyle(
                                  color: _type == TransactionType.income ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Campo de Monto / Cantidad (Estilo Gigante Premium)
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Monto del registro',
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      IntrinsicWidth(
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: _type == TransactionType.expense ? Colors.redAccent : Colors.green,
                          ),
                          textAlign: TextAlign.center,
                          validator: (v) {
                            if (v == null || v.isEmpty) return '0.00';
                            if (double.tryParse(v) == null) return 'No es válido';
                            return null;
                          },
                          decoration: InputDecoration(
                            prefixText: '\$ ',
                            prefixStyle: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: _type == TransactionType.expense ? Colors.redAccent : Colors.green,
                            ),
                            border: InputBorder.none,
                            hintText: '0.00',
                            hintStyle: TextStyle(color: isDark ? Colors.white12 : Colors.grey[300]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Descripción
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Descripción o Concepto',
                  icon: Icons.edit_note_rounded,
                  isDark: isDark,
                  primaryColor: primaryColor,
                  validator: (v) => v!.isEmpty ? 'Ingresa una descripción' : null,
                ),
                const SizedBox(height: 28),

                // Categorías Header
                Text(
                  'Categoría',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),

                // Grid de Categorías Custom
                StreamBuilder<List<CategoryModel>>(
                  stream: service.getCustomCategories(user!.uid),
                  builder: (context, snapshot) {
                    final customCats = snapshot.data ?? [];
                    final combinedCategories = <Map<String, dynamic>>[];
                    
                    // Categorías fijas
                    combinedCategories.addAll([
                      {'name': 'Comida', 'icon': Icons.fastfood_rounded},
                      {'name': 'Transporte', 'icon': Icons.directions_car_rounded},
                      {'name': 'Hogar', 'icon': Icons.home_rounded},
                      {'name': 'Entretenimiento', 'icon': Icons.sports_esports_rounded},
                      {'name': 'Salario', 'icon': Icons.payments_rounded},
                      {'name': 'General', 'icon': Icons.dashboard_rounded},
                    ]);

                    // Añadir categorías creadas por el usuario
                    for (var cat in customCats) {
                      combinedCategories.add({
                        'name': cat.name,
                        'icon': Icons.category_rounded, // Icono genérico por defecto para personalizadas
                      });
                    }

                    // Agregar botón especial de "+ Nueva" al final de la lista
                    combinedCategories.add({
                      'name': '+ Nueva',
                      'icon': Icons.add_rounded,
                      'isAction': true,
                    });

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: combinedCategories.map((cat) {
                        final isAction = cat['isAction'] == true;
                        final isSelected = _category == cat['name'];
                        
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cat['icon'],
                                size: 16,
                                color: isSelected 
                                    ? Colors.white 
                                    : (isAction 
                                        ? primaryColor 
                                        : (isDark ? Colors.grey[400] : Colors.grey[600])),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat['name'],
                                style: TextStyle(
                                  color: isSelected 
                                      ? Colors.white 
                                      : (isAction 
                                          ? primaryColor 
                                          : (isDark ? Colors.grey[300] : Colors.grey[700])),
                                  fontWeight: (isSelected || isAction) ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: primaryColor,
                          backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100],
                          onSelected: (selected) {
                            if (isAction) {
                              _showAddCustomCategoryDialog(context, service, user.uid);
                            } else {
                              setState(() => _category = cat['name']);
                            }
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.transparent
                                  : (isAction 
                                      ? primaryColor.withOpacity(0.4) 
                                      : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!)),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }
                ),
                const SizedBox(height: 40),

                // Botón de Guardar con Gradiente
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Guardar Registro',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color primaryColor,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: TextStyle(
        fontSize: 15,
        color: isDark ? Colors.white : const Color(0xFF1E293B),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[500]),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: primaryColor.withOpacity(0.7),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  void _showAddCustomCategoryDialog(BuildContext context, FirestoreService service, String userId) {
    final catController = TextEditingController();
    final catFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nueva Categoría'),
          content: Form(
            key: catFormKey,
            child: TextFormField(
              controller: catController,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
              decoration: InputDecoration(
                labelText: 'Nombre de la categoría',
                prefixIcon: const Icon(Icons.category_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el nombre' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!catFormKey.currentState!.validate()) return;
                final catName = catController.text.trim();
                
                // Guardar en Firestore
                final category = CategoryModel(
                  id: '',
                  userId: userId,
                  name: catName,
                );
                await service.addCustomCategory(category);
                
                setState(() {
                  _category = catName; // Seleccionar automáticamente la nueva categoría
                });

                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }
}
