import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/theme_toggle_button.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController(text: 'dr.karima@arij.tn');
  final passwordController = TextEditingController(text: 'Doctor123!');
  bool isLoading = false;
  bool obscurePassword = true;
  String? errorMessage;
  String? loggingInRole;

  final List<Map<String, String>> _staffProfiles = [
    {
      'name': 'Dr. Karima Ben Ali',
      'roleTitle': 'Cardiologue Référente',
      'email': 'dr.karima@arij.tn',
      'pass': 'Doctor123!',
      'badge': 'Médecin',
      'color': '0xFF0284C7', // Clinical Blue
    },
    {
      'name': 'Sami Trabelsi',
      'roleTitle': 'Tech. Radiologie / Scanner',
      'email': 'sami.technicien@arij.tn',
      'pass': 'Tech123!',
      'badge': 'Technicien',
      'color': '0xFF8B5CF6', // Purple
    },
    {
      'name': 'Sonia Abid',
      'roleTitle': 'Infirmière Major Urgences',
      'email': 'sonia.infirmiere@arij.tn',
      'pass': 'Nurse123!',
      'badge': 'Infirmière',
      'color': '0xFF10B981', // Mint Green
    },
    {
      'name': 'Fatma Zahra',
      'roleTitle': 'Sage-Femme Maternité',
      'email': 'fatma.sagefemme@arij.tn',
      'pass': 'Midwife123!',
      'badge': 'Sage-Femme',
      'color': '0xFFEC4899', // Rose Pink
    },
    {
      'name': 'Dr. Youssef Ben Amor',
      'roleTitle': 'Médecin Urgentiste',
      'email': 'dr.youssef@polyclinique-arij.tn',
      'pass': 'Doctor123!',
      'badge': 'Médecin',
      'color': '0xFF0284C7', // Clinical Blue
    },
  ];

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin({String? email, String? password, String? staffName}) async {
    final targetEmail = email ?? emailController.text.trim();
    final targetPass = password ?? passwordController.text;

    setState(() {
      isLoading = true;
      errorMessage = null;
      loggingInRole = staffName;
    });

    final api = ApiService();
    final res = await api.login(targetEmail, targetPass);

    if (!mounted) return;
    setState(() {
      isLoading = false;
      loggingInRole = null;
    });

    if (res['success'] == true) {
      final role = api.currentUser?['role'];
      if (role == 'ADMIN') {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Portail Web Admin'),
            content: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'En tant qu’Administrateur, votre tableau de bord et les outils de gestion de la clinique sont hébergés sur le portail Web Safari.\n\nCette application mobile est optimisée pour le personnel soignant en mobilité.',
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onLoginSuccess();
                },
                child: const Text('Accéder quand même'),
              ),
            ],
          ),
        );
      } else {
        widget.onLoginSuccess();
      }
    } else {
      setState(() {
        errorMessage = res['message'] ?? 'Email ou mot de passe incorrect';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bouton Switch Dark / Light Mode en haut à droite
              Align(
                alignment: Alignment.topRight,
                child: const ThemeToggleButton(),
              ),
              const SizedBox(height: 6),

              // Header iOS Brand Logo
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(color: AppTheme.pearlAqua, width: 2.5),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo-polyclinique-arij.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.local_hospital_rounded,
                            size: 44,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Polyclinique Arij',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.darkTextMain : AppTheme.chocolatePlum,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.pearlAqua.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Système Hospitalier Intégré — Djerba',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.burntRose,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // SECTION 1: PROFIL DIRECT STAFF (1-TAP QUICK LOGIN)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.burntRose.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.person_crop_circle_fill_badge_checkmark, size: 18, color: AppTheme.burntRose),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Accès Direct Staff (1-Tap)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.darkTextMain : AppTheme.chocolatePlum,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Profils en service',
                    style: TextStyle(fontSize: 12, color: AppTheme.taupeGrey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Staff Horizontal Scroll Cards
              SizedBox(
                height: 128,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _staffProfiles.length,
                  itemBuilder: (context, index) {
                    final staff = _staffProfiles[index];
                    final isLoggingInThis = loggingInRole == staff['name'];
                    final cardColor = Color(int.parse(staff['color']!));

                    return GestureDetector(
                      onTap: isLoading ? null : () => _handleLogin(
                        email: staff['email'],
                        password: staff['pass'],
                        staffName: staff['name'],
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 146,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: cardColor.withValues(alpha: 0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: isLoggingInThis ? cardColor : (isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.06)),
                            width: isLoggingInThis ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                AvatarWidget(
                                  name: staff['name']!,
                                  radius: 21,
                                ),
                                if (isLoggingInThis)
                                  const CupertinoActivityIndicator(radius: 12),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              staff['name']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTheme.darkTextMain : AppTheme.chocolatePlum,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              staff['badge']!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cardColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 28),

              // Divider with 'ou connexion manuelle'
              Row(
                children: [
                  Expanded(child: Container(height: 1, color: Colors.grey.withValues(alpha: 0.2))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'ou identifiants manuels',
                      style: TextStyle(fontSize: 12, color: AppTheme.taupeGrey, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(child: Container(height: 1, color: Colors.grey.withValues(alpha: 0.2))),
                ],
              ),

              const SizedBox(height: 20),

              // Error banner if any
              if (errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.burntRose.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: AppTheme.burntRose, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: AppTheme.burntRose, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Standard Form Inputs (iOS Style Cards)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(fontSize: 15, color: isDark ? AppTheme.darkTextMain : AppTheme.chocolatePlum),
                      decoration: const InputDecoration(
                        hintText: 'Adresse Email professionnelle',
                        prefixIcon: Icon(CupertinoIcons.mail, size: 20, color: AppTheme.taupeGrey),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    Divider(height: 1, thickness: 0.6, color: isDark ? AppTheme.darkBorder : Colors.grey.withValues(alpha: 0.18)),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      style: TextStyle(fontSize: 15, color: isDark ? AppTheme.darkTextMain : AppTheme.chocolatePlum),
                      decoration: InputDecoration(
                        hintText: 'Mot de passe',
                        prefixIcon: const Icon(CupertinoIcons.lock, size: 20, color: AppTheme.taupeGrey),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                            size: 20,
                            color: AppTheme.taupeGrey,
                          ),
                          onPressed: () => setState(() => obscurePassword = !obscurePassword),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // iOS Styled Login Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  color: AppTheme.burntRose,
                  borderRadius: BorderRadius.circular(16),
                  onPressed: isLoading ? null : () => _handleLogin(),
                  child: isLoading && loggingInRole == null
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Se connecter',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(CupertinoIcons.arrow_right_circle_fill, size: 20, color: Colors.white),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Account registration link
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => RegisterScreen(
                          onRegistered: widget.onLoginSuccess,
                        ),
                      ),
                    );
                  },
                  child: const Text.rich(
                    TextSpan(
                      text: 'Nouveau soignant ? ',
                      style: TextStyle(color: AppTheme.taupeGrey, fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Activer mon compte',
                          style: TextStyle(
                            color: AppTheme.burntRose,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
