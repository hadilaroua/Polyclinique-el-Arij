import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/theme.dart';

/// Premium iOS-style app header — matches Mediterranean Clinical Precision design
class FigmaHeader extends StatelessWidget {
  final String roleName;
  final Color roleColor;
  final VoidCallback onMenuPressed;
  final VoidCallback? onThemeToggle;
  final VoidCallback onNotificationsPressed;
  final int unreadNotifications;
  final String? profileImageUrl;
  final String? userName;
  final String? subtitle;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onCalendarPressed;

  const FigmaHeader({
    super.key,
    required this.roleName,
    required this.roleColor,
    required this.onMenuPressed,
    this.onThemeToggle,
    required this.onNotificationsPressed,
    this.unreadNotifications = 0,
    this.profileImageUrl,
    this.userName,
    this.subtitle,
    this.onProfilePressed,
    this.onCalendarPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final surfaceBg = isDark ? AppTheme.darkTopBar : AppTheme.evergreen;
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceBg,
          gradient: LinearGradient(
            colors: isDark
                ? [AppTheme.darkTopBar, AppTheme.darkTopBar]
                : [AppTheme.evergreen, AppTheme.darkTeal],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppTheme.darkBorder : AppTheme.evergreen.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(16, topPadding > 0 ? topPadding + 4 : 10, 16, 10),
        child: Row(
          children: [
            // ── Clinic Logo (Clic pour ouvrir le Menu) ──────────────────────
            GestureDetector(
              onTap: onMenuPressed,
              child: Container(
                width: 42,
                height: 42,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    'assets/logo-polyclinique-arij.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.local_hospital_rounded,
                      color: AppTheme.evergreen,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ── Center Brand & Role/Service ─────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'El ArijFlow',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppTheme.vitalDischarged,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          (subtitle != null && subtitle!.isNotEmpty) ? subtitle! : roleName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Right: Calendar & Notification icons ───────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Bouton Changement de Thème Dark / Light ───────────────
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: AppTheme.themeModeNotifier,
                  builder: (context, themeMode, _) {
                    final isDarkActive = AppTheme.isDarkMode(context);
                    return GestureDetector(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        if (onThemeToggle != null) {
                          onThemeToggle!();
                        } else {
                          await AppTheme.toggleTheme();
                        }
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isDarkActive
                              ? CupertinoIcons.sun_max_fill
                              : CupertinoIcons.moon_stars_fill,
                          size: 19,
                          color: isDarkActive ? const Color(0xFFFFD60A) : Colors.white,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),

                if (onCalendarPressed != null) ...[
                  GestureDetector(
                    onTap: onCalendarPressed,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(CupertinoIcons.calendar, size: 20, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: onNotificationsPressed,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(CupertinoIcons.bell_fill, size: 20, color: Colors.white),
                        if (unreadNotifications > 0)
                          Positioned(
                            right: 7,
                            top: 7,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppTheme.cayenneRed,
                                shape: BoxShape.circle,
                                border: Border.all(color: surfaceBg, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
