import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/saving_goal_model.dart';

class AddGoalScreen extends StatefulWidget {
  const AddGoalScreen({super.key});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  
  DateTime _targetDate = DateTime.now().add(const Duration(days: 90)); // 3 meses por defecto
  bool _isLoading = false;

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = Provider.of<User?>(context, listen: false);
    final service = Provider.of<FirestoreService>(context, listen: false);

    if (user != null) {
      final goal = SavingGoalModel(
        id: '', // Firestore genera ID automáticamente
        userId: user.uid,
        title: _titleController.text.trim(),
        targetAmount: double.parse(_amountController.text),
        currentAmount: 0.0, // Inicia en 0 de ahorro
        targetDate: _targetDate,
      );

      try {
        await service.addSavingGoal(goal);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al crear la meta de ahorro')),
        );
      }
    }
  }

  Future<void> _selectTargetDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)), // 10 años
    );
    if (picked != null && picked != _targetDate) {
      setState(() {
        _targetDate = picked;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF6366F1); // Indigo

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Nueva Meta de Ahorro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                const SizedBox(height: 10),
                // Icono ilustrativo de meta de ahorro
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.track_changes_rounded, color: primaryColor, size: 40),
                  ),
                ),
                const SizedBox(height: 32),

                // Nombre de la Meta
                _buildTextField(
                  controller: _titleController,
                  label: '¿Qué quieres lograr? (ej. Viaje, Laptop...)',
                  icon: Icons.emoji_flags_rounded,
                  isDark: isDark,
                  primaryColor: primaryColor,
                  validator: (v) => v!.isEmpty ? 'Ingresa el título de tu meta' : null,
                ),
                const SizedBox(height: 16),

                // Monto Objetivo
                _buildTextField(
                  controller: _amountController,
                  label: 'Monto Objetivo a Ahorrar',
                  icon: Icons.monetization_on_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  isDark: isDark,
                  primaryColor: primaryColor,
                  validator: (v) {
                    if (v!.isEmpty) return 'Ingresa el monto objetivo';
                    if (double.tryParse(v) == null) return 'No es un número válido';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Selector de Fecha Objetivo
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
                            'Fecha Objetivo',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd MMMM, yyyy', 'es').format(_targetDate),
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
                        onPressed: () => _selectTargetDate(context),
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
                      colors: [primaryColor, const Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
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
                            'Crear Meta de Ahorro',
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
