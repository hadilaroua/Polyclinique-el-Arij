import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/avatar_widget.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final emailController = TextEditingController(text: 'dr.karima@arij.tn');
  final passwordController = TextEditingController(text: 'Doctor123!');
  bool isLoading = false;
  bool obscurePassword = true;
  String? errorMessage;
  String? loggingInRole;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  final List<Map<String, String>> _staffProfiles = [
    {
      'name': 'Dr. Karima Ben Ali',
      'roleTitle': 'Cardiologue',
      'email': 'dr.karima@arij.tn',
      'pass': 'Doctor123!',
      'badge': 'Médecin',
      'color': '0xFF247BA0',
    },
    {
      'name': 'Youssef Mansour',
      'roleTitle': 'Tech. Laboratoire',
      'email': 'sami.technicien@arij.tn',
      'pass': 'Tech123!',
      'badge': 'Technicien',
      'color': '0xFF8B5CF6',
    },
    {
      'name': 'Sonia Abid',
      'roleTitle': 'Infirmière Major',
      'email': 'sonia.infirmiere@arij.tn',
      'pass': 'Nurse123!',
      'badge': 'Infirmière',
      'color': '0xFF10B981',
    },
    {
      'name': 'Fatma Zahra',
      'roleTitle': 'Sage-Femme',
      'email': 'fatma.sagefemme@arij.tn',
      'pass': 'Midwife123!',
      'badge': 'Sage-Femme',
      'color': '0xFFEC4899',
    },
    {
      'name': 'Dr. Youssef Ben Amor',
      'roleTitle': 'Urgentiste',
      'email': 'dr.youssef@polyclinique-arij.tn',
      'pass': 'Doctor123!',
      'badge': 'Médecin',
      'color': '0xFF247BA0',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _fadeController.dispose();
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
                "En tant qu'Administrateur, votre tableau de bord est hébergé sur le portail Web.\n\nCette application est optimisée pour le personnel soignant.",
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
    final textCol = AppTheme.textColor(context);
    final subtextCol = AppTheme.subtextColor(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // ── Logo & Brand ───────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      // Logo container
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor(context),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppTheme.borderColor(context),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.purple.withValues(alpha: 0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(21),
                          child: Image.asset(
                            'assets/logo-polyclinique-arij.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.local_hospital_rounded,
                              size: 40,
                              color: AppTheme.purple,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Polyclinique Arij',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: textCol,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.purpleLightColor(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Système de Santé Intégré — Djerba',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.purpleColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // ── Quick staff profiles ───────────────────────────────────
                Row(
                  children: [
                    Text(
                      'Connexion rapide',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textCol,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Personnel en service',
                      style: TextStyle(fontSize: 12, color: subtextCol),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Staff cards horizontal scroll
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _staffProfiles.length,
                    itemBuilder: (context, index) {
                      final staff = _staffProfiles[index];
                      final isLoggingInThis = loggingInRole == staff['name'];
                      final cardColor = Color(int.parse(staff['color']!));

                      return GestureDetector(
                        onTap: isLoading
                            ? null
                            : () => _handleLogin(
                                  email: staff['email'],
                                  password: staff['pass'],
                                  staffName: staff['name'],
                                ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 130,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isLoggingInThis
                                ? cardColor.withValues(alpha: 0.08)
                                : AppTheme.surfaceColor(context),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isLoggingInThis
                                  ? cardColor
                                  : AppTheme.borderColor(context),
                              width: isLoggingInThis ? 1.5 : 1,
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
                                    radius: 20,
                                  ),
                                  if (isLoggingInThis)
                                    const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                staff['name']!.split(' ').take(2).join(' '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: textCol,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cardColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  staff['badge']!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: cardColor,
                                  ),
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

                // ── Divider ─────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: AppTheme.borderColor(context), height: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'ou identifiants manuels',
                        style: TextStyle(fontSize: 12, color: subtextCol),
                      ),
                    ),
                    Expanded(
                        child: Divider(
                            color: AppTheme.borderColor(context), height: 1)),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Error banner ─────────────────────────────────────────────
                if (errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppTheme.danger.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppTheme.danger, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(
                                color: AppTheme.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Form fields ──────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: AppTheme.borderColor(context)),
                  ),
                  child: Column(
                    children: [
                      // Email field
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(fontSize: 15, color: textCol),
                        decoration: InputDecoration(
                          hintText: 'Email professionnel',
                          hintStyle:
                              TextStyle(fontSize: 14, color: subtextCol),
                          prefixIcon: Icon(Icons.mail_outline_rounded,
                              size: 20, color: subtextCol),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                      ),
                      Divider(
                          height: 1,
                          thickness: 1,
                          color: AppTheme.borderColor(context)),
                      // Password field
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        style: TextStyle(fontSize: 15, color: textCol),
                        decoration: InputDecoration(
                          hintText: 'Mot de passe',
                          hintStyle:
                              TextStyle(fontSize: 14, color: subtextCol),
                          prefixIcon: Icon(Icons.lock_outline_rounded,
                              size: 20, color: subtextCol),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: subtextCol,
                            ),
                            onPressed: () => setState(
                                () => obscurePassword = !obscurePassword),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Login button ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () => _handleLogin(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.purpleColor(context),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isLoading && loggingInRole == null
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
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
                              Icon(Icons.arrow_forward_rounded,
                                  size: 18, color: Colors.white),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Register link ─────────────────────────────────────────────
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
                    child: Text.rich(
                      TextSpan(
                        text: 'Nouveau membre ? ',
                        style:
                            TextStyle(color: subtextCol, fontSize: 13),
                        children: [
                          TextSpan(
                            text: 'Activer mon compte',
                            style: TextStyle(
                              color: AppTheme.purpleColor(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
