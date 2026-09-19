import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/photo_picker_dialog.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onRegistered;

  const RegisterScreen({super.key, required this.onRegistered});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final formKey = GlobalKey<FormState>();
  final cinController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();

  String selectedRole = 'DOCTOR';
  String? avatarUrl;
  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    cinController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void _choosePhoto() {
    PhotoPickerDialog.show(
      context,
      currentAvatarUrl: avatarUrl,
      onPhotoSelected: (url) {
        setState(() {
          avatarUrl = url;
        });
      },
    );
  }

  Future<void> _handleRegister() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    final api = ApiService();

    final res = await api.registerStaff(
      cin: cinController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text,
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      phone: phoneController.text.trim(),
      role: selectedRole,
      avatarUrl: avatarUrl,
    );

    setState(() => isLoading = false);

    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.success,
          content: Text('Compte soignant activé avec succès ! Bienvenue.'),
        ),
      );
      widget.onRegistered();
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppTheme.danger),
              SizedBox(width: 8),
              Text('Accès non autorisé'),
            ],
          ),
          content: Text(
            res['message'] ??
                'Votre numéro CIN n\'a pas encore été accrédité par la Direction de la Polyclinique Arij. Veuillez contacter l\'administration.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Inscription Professionnelle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Photo de profil au sommet
                Center(
                  child: Column(
                    children: [
                      AvatarWidget(
                        avatarUrl: avatarUrl,
                        name: '${firstNameController.text} ${lastNameController.text}',
                        role: selectedRole,
                        radius: 46,
                        isEditable: true,
                        onTap: _choosePhoto,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _choosePhoto,
                        icon: const Icon(Icons.camera_alt, size: 16),
                        label: Text(
                          avatarUrl != null
                              ? 'Changer la photo'
                              : 'Ajouter une photo de profil',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const Text(
                        'Elle sera visible dans votre espace et chez l’administrateur',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Note d'information CIN
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF1D4ED8), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pour sécuriser l’accès médical, votre CIN doit être pré-enregistré par la Direction de la clinique.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E40AF),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Rôle
                const Text(
                  'Votre profession de santé *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(),
                  items: const [
                    DropdownMenuItem(value: 'DOCTOR', child: Text('🩺 Médecin Spécialiste')),
                    DropdownMenuItem(value: 'NURSE', child: Text('💉 Infirmier / Infirmière')),
                    DropdownMenuItem(value: 'MIDWIFE', child: Text('🌸 Sage-femme (Maternité)')),
                    DropdownMenuItem(value: 'TECHNICIAN', child: Text('🔬 Technicien (Labo / Radio)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => selectedRole = val);
                  },
                ),

                const SizedBox(height: 16),

                // CIN
                const Text(
                  'Numéro CIN *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: cinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Ex: 09090909',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Le CIN est obligatoire' : null,
                ),

                const SizedBox(height: 16),

                // Prénom et Nom
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prénom *',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: firstNameController,
                            decoration: const InputDecoration(hintText: 'Prénom'),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Requis' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nom *',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: lastNameController,
                            decoration: const InputDecoration(hintText: 'Nom'),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Requis' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Email
                const Text(
                  'Email professionnel *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'nom.prenom@arij.tn',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  validator: (val) => val == null || !val.contains('@') ? 'Email valide requis' : null,
                ),

                const SizedBox(height: 16),

                // Téléphone
                const Text(
                  'Téléphone mobile',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '+216 98 ...',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                ),

                const SizedBox(height: 16),

                // Mot de passe
                const Text(
                  'Mot de passe *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Minimum 6 caractères',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                        color: AppTheme.textMuted,
                      ),
                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                  validator: (val) => val == null || val.length < 6 ? 'Au moins 6 caractères requis' : null,
                ),

                const SizedBox(height: 28),

                // Bouton validation
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isLoading ? null : _handleRegister,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Activer mon compte soignant',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
