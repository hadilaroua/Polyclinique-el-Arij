import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../screens/staff_messenger_screen.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import 'avatar_widget.dart';
import 'theme_toggle_button.dart';

class AppDrawer extends StatelessWidget {
  final Function(int) onSelectTab;
  final VoidCallback onOpenProfile;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.onSelectTab,
    required this.onOpenProfile,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final api = ApiService();
    final user = api.currentUser;
    final profile = api.currentProfile;
    final role = user?['role'] ?? 'STAFF';

    final firstName = user?['firstName'] ?? '';
    final lastName = user?['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final cin = user?['cin'] ?? '—';
    final avatarUrl = user?['avatarUrl'];
    final roleColor = AppTheme.getRoleColor(role);

    // Extraction du service ou spécialité selon le profil
    String serviceText = 'Polyclinique Arij Djerba';
    if (profile != null) {
      serviceText = profile['specialty'] ??
          profile['service'] ??
          profile['department'] ??
          profile['technicalDepartment'] ??
          'Polyclinique Arij';
    }

    return Drawer(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      child: Column(
        children: [
          // En-tête professionnel avec photo de profil
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 20,
              20,
              20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  roleColor,
                  isDark ? const Color(0xFF090D16) : AppTheme.primaryDark,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo & Marque Polyclinique Arij
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/logo-polyclinique-arij.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(CupertinoIcons.plus_square_fill, size: 18, color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Polyclinique Arij Djerba',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    AvatarWidget(
                      avatarUrl: avatarUrl,
                      name: fullName,
                      role: role,
                      radius: 30,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName.isNotEmpty ? fullName : 'Soignant Arij',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              AppTheme.getRoleLabel(role),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CIN: $cin',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          serviceText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu de navigation selon le métier
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerItem(
                  context,
                  icon: CupertinoIcons.square_grid_2x2_fill,
                  title: 'Tableau de bord',
                  subtitle: 'Aperçu général de la journée',
                  onTap: () {
                    Navigator.pop(context);
                    onSelectTab(0);
                  },
                ),

                if (role == 'DOCTOR') ...[
                  _drawerItem(
                    context,
                    icon: CupertinoIcons.plus_square_fill,
                    title: 'Mes Consultations',
                    subtitle: 'Dossiers & diagnostics',
                    onTap: () {
                      Navigator.pop(context);
                      onSelectTab(1);
                    },
                  ),
                  _drawerItem(
                    context,
                    icon: CupertinoIcons.lab_flask,
                    title: 'Examens & Bilans',
                    subtitle: 'Prescriptions & résultats labo/radio',
                    onTap: () {
                      Navigator.pop(context);
                      onSelectTab(2);
                    },
                  ),
                ],

                if (role == 'NURSE') ...[
                  _drawerItem(
                    context,
                    icon: CupertinoIcons.heart_fill,
                    title: 'Constantes Vitales',
                    subtitle: 'Prise de TA, Pouls, T°, SpO2',
                    onTap: () {
                      Navigator.pop(context);
                      onSelectTab(1);
                    },
                  ),
                  _drawerItem(
                    context,
                    icon: CupertinoIcons.bed_double_fill,
                    title: 'Chambres & Lits',
                    subtitle: 'Gestion des lits hospitalisés',
                    onTap: () {
                      Navigator.pop(context);
                      onSelectTab(2);
                    },
                  ),
                ],

                if (role == 'MIDWIFE') ...[
                  _drawerItem(
                    context,
                    icon: CupertinoIcons.person_2_fill,
                    title: 'Suivi Obstétrical',
                    subtitle: 'Consultations & soins prénatals',
                    onTap: () {
                      Navigator.pop(context);
                      onSelectTab(1);
                    },
                  ),
                  _drawerItem(
                    context,
                    icon: CupertinoIcons.heart_fill,
                    title: 'Constantes Maternité',
                    subtitle: 'Surveillance mère et bébé',
                    onTap: () {
                      Navigator.pop(context);
                      onSelectTab(2);
                    },
                  ),
                ],

                if (role == 'TECHNICIAN') ...[
                  _drawerItem(
                    context,
                    icon: CupertinoIcons.lab_flask,
                    title: 'Worklist Plateau',
                    subtitle: 'Examens à réaliser',
                    onTap: () {
                      Navigator.pop(context);
                      onSelectTab(1);
                    },
                  ),
                ],

                Divider(height: 24, thickness: 1, color: isDark ? AppTheme.darkBorder : AppTheme.border),

                // Sélecteur 3 modes : Clair / Sombre / Système
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: const ThemeSettingsRow(),
                ),

                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.chat_bubble_2_fill, color: Colors.white, size: 20),
                  ),
                  title: Row(
                    children: [
                      Text(
                        'Messagerie & Appels',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? AppTheme.darkAccent : AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        CupertinoIcons.chat_bubble_fill,
                        color: isDark ? AppTheme.darkAccent : AppTheme.accent,
                        size: 14,
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Chat direct, groupes & appels HD staff',
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextMuted : Colors.black54),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => StaffMessengerScreen(onLogout: onLogout)),
                    );
                  },
                ),

                _drawerItem(
                  context,
                  icon: CupertinoIcons.person_fill,
                  title: 'Mon Profil Professionnel',
                  subtitle: 'Changer photo, coordonnées',
                  onTap: () {
                    Navigator.pop(context);
                    onOpenProfile();
                  },
                ),

                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
                    ),
                    child: Image.asset(
                      'assets/logo-polyclinique-arij.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(CupertinoIcons.plus_square, color: AppTheme.primary, size: 20),
                    ),
                  ),
                  title: Text(
                    'Polyclinique Arij Djerba',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextMain : AppTheme.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Midoun, Djerba — Tél: 75 730 001',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  trailing: Icon(CupertinoIcons.chevron_right, size: 18, color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted),
                  onTap: () {
                    Navigator.pop(context);
                    showAboutDialog(
                      context: context,
                      applicationName: 'Polyclinique Arij Djerba',
                      applicationVersion: 'Version 2.0.0 (Clinique Staff)',
                      applicationIcon: Image.asset(
                        'assets/logo-polyclinique-arij.png',
                        width: 48,
                        height: 48,
                      ),
                      applicationLegalese: 'Système d’Information Médical Intégré',
                    );
                  },
                ),
              ],
            ),
          ),

          // Pied de menu Déconnexion
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.border)),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.arrow_right_square_fill, color: AppTheme.danger, size: 20),
              ),
              title: const Text(
                'Déconnexion',
                style: TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                onLogout();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDarkMode(context);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: isDark ? AppTheme.darkPrimary : AppTheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? AppTheme.darkTextMain : AppTheme.textMain,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
          fontSize: 11,
        ),
      ),
      trailing: Icon(CupertinoIcons.chevron_right, size: 18, color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted),
      onTap: onTap,
    );
  }
}
