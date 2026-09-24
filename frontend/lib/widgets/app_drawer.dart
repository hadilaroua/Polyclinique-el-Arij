import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../screens/daily_briefing_screen.dart';
import '../screens/staff_messenger_screen.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import 'avatar_widget.dart';
import 'dark_ambient_background.dart';
import 'rooms_and_beds_view.dart';

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
    String serviceText = 'Polyclinique El Arij';
    if (profile != null) {
      serviceText = profile['specialty'] ??
          profile['service'] ??
          profile['department'] ??
          profile['technicalDepartment'] ??
          'Polyclinique El Arij';
    }

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0D141F) : Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── En-tête professionnel iOS avec dégradé et profil soignant ──
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 16,
                20,
                20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    roleColor.withValues(alpha: isDark ? 0.9 : 1.0),
                    isDark ? const Color(0xFF090E17) : AppTheme.primaryDark,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo & Titre Clinique
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
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo-polyclinique-arij.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(CupertinoIcons.plus_square_fill, size: 18, color: AppTheme.primary),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Polyclinique El Arij',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Profil & Badge
                  Row(
                    children: [
                      AvatarWidget(
                        avatarUrl: avatarUrl,
                        name: fullName,
                        role: role,
                        radius: 28,
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
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
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
                  // Cartouche info CIN & Service bien aérée avec séparateur
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'CIN: $cin',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            serviceText,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Menu d'outils cliniques essentiels sans répétition ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                children: [
                  _sectionHeader(context, 'OUTILS CLINIQUES & ACTIONS'),
                  const SizedBox(height: 8),

                  _drawerCardItem(
                    context,
                    icon: CupertinoIcons.sparkles,
                    iconColor: const Color(0xFF00A896),
                    iconBg: const Color(0xFF00A896).withValues(alpha: 0.14),
                    title: 'Briefing IA du Jour',
                    subtitle: 'Synthèse intelligente & priorités de garde',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DailyBriefingScreen(onLogout: onLogout),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  _drawerCardItem(
                    context,
                    icon: CupertinoIcons.bed_double_fill,
                    iconColor: const Color(0xFF007EA7),
                    iconBg: const Color(0xFF007EA7).withValues(alpha: 0.14),
                    title: 'Chambres & Lits',
                    subtitle: 'Plan d’occupation & lits disponibles',
                    onTap: () {
                      Navigator.pop(context);
                      if (role == 'NURSE') {
                        onSelectTab(3);
                      } else if (role == 'MIDWIFE') {
                        onSelectTab(1);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: const Text('Occupation Chambres & Lits', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                backgroundColor: AppTheme.surfaceColor(context),
                                elevation: 0,
                                iconTheme: IconThemeData(color: AppTheme.textColor(context)),
                              ),
                              body: const DarkAmbientBackground(
                                child: RoomsAndBedsView(),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  _drawerCardItem(
                    context,
                    icon: CupertinoIcons.chat_bubble_2_fill,
                    iconColor: const Color(0xFF38BDF8),
                    iconBg: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                    title: 'Messagerie & Appels',
                    subtitle: 'Canaux d’urgences, staff & appels HD',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => StaffMessengerScreen(onLogout: onLogout)),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  _drawerCardItem(
                    context,
                    icon: CupertinoIcons.person_crop_circle_fill,
                    iconColor: const Color(0xFF818CF8),
                    iconBg: const Color(0xFF818CF8).withValues(alpha: 0.14),
                    title: 'Mon Profil & Garde',
                    subtitle: 'Coordonnées, statut & disponibilité',
                    onTap: () {
                      Navigator.pop(context);
                      onOpenProfile();
                    },
                  ),
                ],
              ),
            ),

            // ── Pied de tiroir : Bouton Déconnexion iOS ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : AppTheme.border,
                    width: 0.8,
                  ),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.pop(context);
                  onLogout();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(CupertinoIcons.square_arrow_right, color: AppTheme.danger, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Déconnexion',
                        style: TextStyle(
                          color: AppTheme.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: AppTheme.danger.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8E9BAE),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _drawerCardItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDarkMode(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161F2E) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF243042) : Colors.grey.shade200,
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.textMain,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF8E9BAE) : AppTheme.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                CupertinoIcons.chevron_right,
                size: 15,
                color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
