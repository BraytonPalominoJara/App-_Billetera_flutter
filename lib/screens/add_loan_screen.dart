import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/loan_model.dart';
import '../models/transaction_model.dart';

class AddLoanScreen extends StatefulWidget {
  const AddLoanScreen({super.key});

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _personController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController(); // Nueva descripción
  
  LoanType _type = LoanType.borrowed; // borrowed = recibido, lent = otorgado
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _isLoading = false;

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = Provider.of<User?>(context, listen: false);
    final service = Provider.of<FirestoreService>(context, listen: false);

    if (user != null) {
      final loan = LoanModel(
        id: '', // Firestore genera ID automáticamente
        userId: user.uid,
        personName: _personController.text.trim(),
        amount: double.parse(_amountController.text),
        description: _descriptionController.text.trim(),
        startDate: DateTime.now(),
        dueDate: _dueDate,
        isPaid: false,
        type: _type,
      );

      try {
        await service.addLoan(loan);

        // Crear transacción automática inicial
        final tx = TransactionModel(
          id: '',
          userId: user.uid,
          description: loan.type == LoanType.lent 
              ? 'Préstamo otorgado a ${loan.personName}${loan.description.isNotEmpty ? ' (${loan.description})' : ''}' 
              : 'Préstamo recibido de ${loan.personName}${loan.description.isNotEmpty ? ' (${loan.description})' : ''}',
          amount: loan.amount,
          date: DateTime.now(),
          category: 'Préstamos',
          type: loan.type == LoanType.lent ? TransactionType.expense : TransactionType.income,
        );
        await service.addTransaction(tx);

        if (mounted) Navigator.pop(context);
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar el préstamo')),
        );
      }
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)), // 5 años
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF6366F1); // Indigo

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Nuevo Préstamo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                // Selector de Tipo de Préstamo (Segmented Toggle)
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
                          onTap: () => setState(() => _type = LoanType.borrowed),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _type == LoanType.borrowed
                                  ? const Color(0xFF6366F1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'Recibido',
                                style: TextStyle(
                                  color: _type == LoanType.borrowed ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _type = LoanType.lent),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _type == LoanType.lent
                                  ? const Color(0xFFF59E0B) // Ambar
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'Otorgado',
                                style: TextStyle(
                                  color: _type == LoanType.lent ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
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

                // Campo de Nombre de Persona
                _buildTextField(
                  controller: _personController,
                  label: _type == LoanType.borrowed ? '¿Quién te prestó dinero?' : '¿A quién le prestas dinero?',
                  icon: Icons.person_outline_rounded,
                  isDark: isDark,
                  primaryColor: primaryColor,
                  validator: (v) => v!.isEmpty ? 'Ingresa el nombre de la persona' : null,
                ),
                const SizedBox(height: 16),

                // Campo de Monto
                _buildTextField(
                  controller: _amountController,
                  label: 'Monto del Préstamo',
                  icon: Icons.monetization_on_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  isDark: isDark,
                  primaryColor: primaryColor,
                  validator: (v) {
                    if (v!.isEmpty) return 'Ingresa el monto';
                    if (double.tryParse(v) == null) return 'No es un número válido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo de Descripción o Motivo
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Descripción o Motivo (Opcional)',
                  icon: Icons.description_outlined,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 20),

                // Selector de Fecha de Pago (Vencimiento)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fecha de Pago pactada',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd MMMM, yyyy', 'es').format(_dueDate),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.calendar_month_rounded, color: primaryColor),
                        onPressed: () => _selectDueDate(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Botón Guardar con Gradiente
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _type == LoanType.borrowed
                          ? [const Color(0xFF6366F1), const Color(0xFF4F46E5)]
                          : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_type == LoanType.borrowed ? const Color(0xFF6366F1) : const Color(0xFFF59E0B)).withOpacity(0.3),
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
                            'Registrar Préstamo',
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
    TextInputType keyboardType = TextInputType.text,
    required bool isDark,
    required Color primaryColor,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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
}
