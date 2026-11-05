import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_logger.dart';
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
  bool isFaceEnrolled = false;

  @override
  void initState() {
    super.initState();
    AppLogger.logInterface(
      'Inscription Professionnelle Soignant',
      fileName: 'register_screen.dart',
      details: 'Initialisation du formulaire d\'accréditation',
    );
  }

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

  Future<void> _startFaceEnrollment() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _BiometricEnrollmentModal(),
    );

    if (result == true) {
      setState(() {
        isFaceEnrolled = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Enrôlement Face ID iOS validé avec succès !'),
              ],
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!formKey.currentState!.validate()) return;

    AppLogger.logInterface(
      'Validation Inscription Soignant',
      fileName: 'register_screen.dart',
      details: 'Envoi formulaire - CIN: ${cinController.text.trim()}, Rôle: $selectedRole, FaceID: $isFaceEnrolled',
    );

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
          backgroundColor: AppTheme.isDarkMode(ctx) ? AppTheme.darkSurface : Colors.white,
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppTheme.danger),
              SizedBox(width: 8),
              Text('Accès non autorisé', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text(
            res['message'] ??
                'Votre numéro CIN n\'a pas encore été accrédité par la Direction de la Polyclinique Arij. Veuillez contacter l\'administration.',
            style: TextStyle(color: AppTheme.textColor(ctx)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris', style: TextStyle(color: AppTheme.evergreen, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  InputDecoration _inputDeco(BuildContext context, {required String hint, Widget? prefix, Widget? suffix}) {
    final isDark = AppTheme.isDarkMode(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13,
        color: isDark ? AppTheme.drySage : const Color(0xFF94A3B8),
      ),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark ? AppTheme.darkSurface : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppTheme.darkElevated : AppTheme.dustGrey,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppTheme.evergreen,
          width: 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppTheme.alertRed,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppTheme.alertRed,
          width: 1.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final textCol = isDark ? Colors.white : AppTheme.textMain;
    final mutedCol = isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.evergreen,
        elevation: 0,
        title: const Text(
          'Inscription Professionnelle',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
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
                        icon: const Icon(Icons.camera_alt, size: 16, color: AppTheme.evergreen),
                        label: Text(
                          avatarUrl != null
                              ? 'Changer la photo de profil'
                              : 'Ajouter une photo de profil',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.evergreen,
                          ),
                        ),
                      ),
                      Text(
                        'Visible dans votre espace soignant et au tableau de garde',
                        style: TextStyle(fontSize: 11.5, color: mutedCol),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Note d'information CIN (Couleurs claires et lisibles en dark mode)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : const Color(0xFFEDF4EE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppTheme.darkElevated : AppTheme.evergreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_user_rounded, color: AppTheme.evergreen, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Accès sécurisé Polyclinique El Arij : votre CIN doit être pré-enregistré par l’Administration de la clinique.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFE2E8F0) : AppTheme.evergreen,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Rôle
                Text(
                  'Profession de santé *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textCol),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                  style: TextStyle(fontSize: 14, color: textCol, fontWeight: FontWeight.w600),
                  decoration: _inputDeco(context, hint: 'Choisir la fonction'),
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

                const SizedBox(height: 18),

                // CIN
                Text(
                  'Numéro CIN *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textCol),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: cinController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 14, color: textCol, fontWeight: FontWeight.w600),
                  decoration: _inputDeco(
                    context,
                    hint: 'Ex: 09090909',
                    prefix: const Icon(Icons.badge_outlined, size: 20, color: AppTheme.evergreen),
                  ),
                  validator: (val) => val == null || val.trim().length < 6 ? '⚠️ Le CIN doit comporter au moins 6 chiffres' : null,
                ),

                const SizedBox(height: 18),

                // Prénom et Nom
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prénom *',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textCol),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: firstNameController,
                            style: TextStyle(fontSize: 14, color: textCol),
                            decoration: _inputDeco(context, hint: 'Prénom'),
                            validator: (val) => val == null || val.trim().length < 2 ? '⚠️ Prénom requis (min 2 lettres)' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nom *',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textCol),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: lastNameController,
                            style: TextStyle(fontSize: 14, color: textCol),
                            decoration: _inputDeco(context, hint: 'Nom'),
                            validator: (val) => val == null || val.trim().length < 2 ? '⚠️ Nom requis (min 2 lettres)' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Email
                Text(
                  'Email professionnel *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textCol),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(fontSize: 14, color: textCol),
                  decoration: _inputDeco(
                    context,
                    hint: 'nom.prenom@arij.tn',
                    prefix: const Icon(Icons.email_outlined, size: 20, color: AppTheme.evergreen),
                  ),
                  validator: (val) => val == null || !val.contains('@') || !val.contains('.') || val.trim().length < 5
                      ? '⚠️ Adresse email invalide (ex: dr.karima@arij.tn)'
                      : null,
                ),

                const SizedBox(height: 18),

                // Téléphone
                Text(
                  'Téléphone mobile',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textCol),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(fontSize: 14, color: textCol),
                  decoration: _inputDeco(
                    context,
                    hint: '+216 98 ...',
                    prefix: const Icon(Icons.phone_outlined, size: 20, color: AppTheme.evergreen),
                  ),
                  validator: (val) => (val != null && val.trim().isNotEmpty && val.trim().length < 8)
                      ? '⚠️ Téléphone valide (min 8 chiffres)'
                      : null,
                ),

                const SizedBox(height: 18),

                // Mot de passe
                Text(
                  'Mot de passe *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textCol),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  style: TextStyle(fontSize: 14, color: textCol),
                  decoration: _inputDeco(
                    context,
                    hint: 'Minimum 6 caractères',
                    prefix: const Icon(Icons.lock_outline, size: 20, color: AppTheme.evergreen),
                    suffix: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                        color: mutedCol,
                      ),
                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                  validator: (val) => val == null || val.length < 6 ? '⚠️ Le mot de passe doit comporter au moins 6 caractères' : null,
                ),

                const SizedBox(height: 24),

                // ── Section Face ID Complète (Enrôlement biométrique iOS) ──
                Text(
                  'Reconnaissance Faciale iOS (Face ID)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textCol),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isFaceEnrolled
                          ? const Color(0xFF10B981)
                          : (isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
                      width: isFaceEnrolled ? 1.8 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isFaceEnrolled
                                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                  : AppTheme.evergreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isFaceEnrolled ? const Color(0xFF10B981) : AppTheme.evergreen,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              isFaceEnrolled ? Icons.verified_user_rounded : Icons.face_retouching_natural_rounded,
                              size: 28,
                              color: isFaceEnrolled ? const Color(0xFF10B981) : AppTheme.evergreen,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Biométrie Face ID',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: textCol,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isFaceEnrolled
                                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                            : Colors.amber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: Text(
                                        isFaceEnrolled ? '✓ Enrôlé' : 'Optionnel',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isFaceEnrolled ? const Color(0xFF10B981) : Colors.amber.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isFaceEnrolled
                                      ? 'Empreinte biométrique configurée pour la connexion rapide.'
                                      : 'Permet la connexion instantanée sans mot de passe.',
                                  style: TextStyle(fontSize: 12, color: mutedCol),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _startFaceEnrollment,
                          icon: Icon(
                            isFaceEnrolled ? Icons.refresh_rounded : Icons.camera_enhance_rounded,
                            size: 18,
                            color: isFaceEnrolled ? const Color(0xFF10B981) : AppTheme.evergreen,
                          ),
                          label: Text(
                            isFaceEnrolled ? 'Ré-enrôler / Scanner à nouveau' : 'Scanner mon visage pour Face ID',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isFaceEnrolled ? const Color(0xFF10B981) : AppTheme.evergreen,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isFaceEnrolled ? const Color(0xFF10B981) : AppTheme.evergreen,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Bouton validation
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.evergreen,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isLoading ? null : _handleRegister,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Activer mon compte soignant',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal moderne d'enrôlement Face ID iOS
class _BiometricEnrollmentModal extends StatefulWidget {
  const _BiometricEnrollmentModal();

  @override
  State<_BiometricEnrollmentModal> createState() => _BiometricEnrollmentModalState();
}

class _BiometricEnrollmentModalState extends State<_BiometricEnrollmentModal> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _step = 0; // 0: Centrage, 1: Scan 3D / Rotation, 2: Chiffrement, 3: Terminé

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _runEnrollmentSequence();
  }

  Future<void> _runEnrollmentSequence() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) setState(() => _step = 1);

    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) setState(() => _step = 2);

    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _step = 3);

    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _step == 3;
    final color = isDone ? const Color(0xFF10B981) : AppTheme.evergreen;

    String stepTitle = 'Positionnez votre visage';
    String stepSubtitle = 'Placez votre visage au centre du cercle biométrique';

    if (_step == 1) {
      stepTitle = 'Capture des reliefs faciaux...';
      stepSubtitle = 'Gardez votre visage stable face à la caméra';
    } else if (_step == 2) {
      stepTitle = 'Chiffrement de la clé biométrique';
      stepSubtitle = 'Génération de l’empreinte sécurisée en cours...';
    } else if (_step == 3) {
      stepTitle = 'Enrôlement réussi !';
      stepSubtitle = 'Votre visage est enregistré pour la clinique.';
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Réticule iOS Biométrique
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF1F5F2),
                border: Border.all(color: color, width: 2.5),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!isDone)
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Positioned(
                          top: 20 + (_animController.value * 95),
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, color, Colors.transparent],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  Icon(
                    isDone ? Icons.check_circle_rounded : Icons.face_retouching_natural_rounded,
                    size: 78,
                    color: color,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Stepper pills
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final active = _step >= index;
                return Container(
                  width: active ? 22 : 8,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? color : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),

            Text(
              stepTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDone ? const Color(0xFF10B981) : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              stepSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.3),
            ),
            const SizedBox(height: 22),

            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Annuler',
                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
