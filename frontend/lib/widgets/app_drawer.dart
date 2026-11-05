import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../screens/daily_briefing_screen.dart';
import '../screens/staff_messenger_screen.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import 'avatar_widget.dart';
import 'dark_ambient_background.dart';
import '../main.dart';
import '../screens/doctor_home_screen.dart';
import '../screens/technician_home_screen.dart';
import '../screens/nurse_home_screen.dart';
import '../screens/midwife_home_screen.dart';
import '../screens/calendar/clinical_calendar_screen.dart';
import 'floating_messenger_head.dart';
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
      serviceText =
          profile['specialty'] ??
          profile['service'] ??
          profile['department'] ??
          profile['technicalDepartment'] ??
          'Polyclinique El Arij';
    }

    return Drawer(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── En-tête professionnel iOS avec dégradé et profil soignant ──
            Container(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [AppTheme.darkTopBar, AppTheme.darkSurfaceSecondary]
                      : [AppTheme.evergreen, AppTheme.darkTeal],
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
                            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo-polyclinique-arij.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            CupertinoIcons.plus_square_fill,
                            size: 18,
                            color: AppTheme.evergreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'El ArijFlow',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Profil & Badge (Cliquable pour ouvrir le profil connecté)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(context);
                      onOpenProfile();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Container(
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      CupertinoIcons.pencil_circle_fill,
                                      color: Colors.white.withValues(alpha: 0.8),
                                      size: 15,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_right,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Cartouche info CIN & Service bien aérée avec séparateur
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.8),
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
                    icon: CupertinoIcons.calendar,
                    iconColor: isDark ? AppTheme.darkPrimary : AppTheme.evergreen,
                    iconBg: (isDark ? AppTheme.darkPrimary : AppTheme.evergreen).withValues(
                      alpha: 0.12,
                    ),
                    title: 'Calendrier Clinique',
                    subtitle: 'Planning interventions, blocs & gardes',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => ClinicalCalendarScreen(onLogout: onLogout),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  _drawerCardItem(
                    context,
                    icon: CupertinoIcons.sparkles,
                    iconColor: isDark ? AppTheme.darkPrimary : AppTheme.evergreen,
                    iconBg: (isDark ? AppTheme.darkPrimary : AppTheme.evergreen).withValues(
                      alpha: 0.12,
                    ),
                    title: 'Briefing IA du Jour',
                    subtitle: 'Synthèse intelligente & priorités de garde',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DailyBriefingScreen(onLogout: onLogout)),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  _drawerCardItem(
                    context,
                    icon: CupertinoIcons.bed_double_fill,
                    iconColor: isDark ? AppTheme.darkPrimary : AppTheme.evergreen,
                    iconBg: (isDark ? AppTheme.darkPrimary : AppTheme.evergreen).withValues(
                      alpha: 0.12,
                    ),
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
                                title: const Text(
                                  'Occupation Chambres & Lits',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: isDark ? AppTheme.darkTopBar : AppTheme.evergreen,
                                elevation: 0,
                                iconTheme: const IconThemeData(color: Colors.white),
                                flexibleSpace: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isDark
                                          ? [AppTheme.darkTopBar, AppTheme.darkTopBar]
                                          : [AppTheme.evergreen, AppTheme.darkTeal],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),
                                ),
                              ),
                              body: const DarkAmbientBackground(child: RoomsAndBedsView()),
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
                    iconColor: isDark ? AppTheme.darkPrimary : AppTheme.evergreen,
                    iconBg: (isDark ? AppTheme.darkPrimary : AppTheme.evergreen).withValues(
                      alpha: 0.12,
                    ),
                    title: 'Messagerie & Appels',
                    subtitle: 'Canaux d’urgences, staff & appels HD',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => StaffMessengerScreen(onLogout: onLogout),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  _drawerCardItem(
                    context,
                    icon: CupertinoIcons.person_crop_circle_fill,
                    iconColor: isDark ? AppTheme.darkPrimary : AppTheme.evergreen,
                    iconBg: (isDark ? AppTheme.darkPrimary : AppTheme.evergreen).withValues(
                      alpha: 0.12,
                    ),
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

            // ── Pied de tiroir : Bouton Déconnexion Moderne ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppTheme.darkSurface : AppTheme.border,
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Session soignante',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextTertiary : AppTheme.evergreen,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.pop(context);
                      onLogout();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.alertRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.alertRed.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.power, color: AppTheme.alertRed, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Déconnexion',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.alertRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE5ECE8),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: isDark ? 0.15 : 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: iconColor.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.textMain,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF9EACA3) : const Color(0xFF6B7E72),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    size: 13,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.evergreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
