import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _formKey = GlobalKey<FormState>();

  // controladores de los campos de texto
  final _nameCtrl    = TextEditingController();
  final _weightCtrl  = TextEditingController();
  final _heightCtrl  = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // cargando datos locales al abrir la vista
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text   = prefs.getString('profile_name')   ?? '';
      _weightCtrl.text = prefs.getString('profile_weight') ?? '';
      _heightCtrl.text = prefs.getString('profile_height') ?? '';
    });
  }

  // guardando perfil en local
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('profile_name',   _nameCtrl.text.trim());
    await prefs.setString('profile_weight', _weightCtrl.text.trim());
    await prefs.setString('profile_height', _heightCtrl.text.trim());

    setState(() => _isSaving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Perfil guardado correctamente'),
        backgroundColor: Color(0xFF00E676),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perfil',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),

                // avatar circular centrado
                _buildAvatar(),
                const SizedBox(height: 32),

                // campos editables del atleta
                _buildSectionTitle('Datos personales'),
                const SizedBox(height: 16),
                _buildField(
                  controller: _nameCtrl,
                  label: 'Nombre',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.name,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _weightCtrl,
                  label: 'Peso (kg)',
                  icon: Icons.monitor_weight_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  // validacion de peso
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresa tu peso';
                    final n = double.tryParse(v.trim().replaceAll(',', '.'));
                    if (n == null || n <= 0 || n > 300) return 'Peso inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _heightCtrl,
                  label: 'Estatura (cm)',
                  icon: Icons.height,
                  keyboardType: TextInputType.number,
                  // validacion de estatura
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresa tu estatura';
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 50 || n > 250) return 'Estatura inválida';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // card de IMC calculado en tiempo real
                _buildImcCard(),
                const SizedBox(height: 32),

                // boton guardar
                _buildSaveButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // avatar con iniciales del nombre
  Widget _buildAvatar() {
    final name = _nameCtrl.text.trim();
    final initials = name.isNotEmpty
        ? name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return Center(
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00E676), Color(0xFF004407)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E676).withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: _nameCtrl,
            builder: (_, child) => Text(
              _nameCtrl.text.trim().isEmpty ? 'Ciclista' : _nameCtrl.text.trim(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ciclista • AccelerBike',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF00E676),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFF00E676), size: 20),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  // calculo de imc en tiempo real
  Widget _buildImcCard() {
    return ListenableBuilder(
      listenable: Listenable.merge([_weightCtrl, _heightCtrl]),
      builder: (_, child) {
        final weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
        final height = int.tryParse(_heightCtrl.text);

        if (weight == null || height == null || height == 0) {
          return const SizedBox.shrink();
        }

        final heightM = height / 100.0;
        final imc = weight / (heightM * heightM);

        String categoria;
        Color color;
        if (imc < 18.5) {
          categoria = 'Bajo peso';
          color = Colors.blue;
        } else if (imc < 25) {
          categoria = 'Peso normal';
          color = const Color(0xFF00E676);
        } else if (imc < 30) {
          categoria = 'Sobrepeso';
          color = Colors.orange;
        } else {
          categoria = 'Obesidad';
          color = Colors.red;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('IMC calculado',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    imc.toStringAsFixed(1),
                    style: TextStyle(
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  categoria,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _saveProfile,
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : const Icon(Icons.save_outlined, color: Colors.black),
        label: Text(
          _isSaving ? 'Guardando...' : 'Guardar Cambios',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF00E676),
          disabledBackgroundColor: const Color(0xFF004407),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
