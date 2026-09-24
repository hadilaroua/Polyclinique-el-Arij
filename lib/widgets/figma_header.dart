import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'avatar_widget.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final iconColor = isDark ? Colors.white : AppTheme.primary;
    final surfaceBg = isDark ? const Color(0xFF121E2E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: surfaceBg.withValues(alpha: isDark ? 0.85 : 0.92),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor(context).withValues(alpha: isDark ? 0.4 : 0.7),
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // ── Menu Button ──────────────────────────────────────────
          GestureDetector(
            onTap: onMenuPressed,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B293C) : AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.menu_rounded, size: 22, color: iconColor),
            ),
          ),

          const SizedBox(width: 10),

          // ── Center Brand & Role/Service ─────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Polyclinique El Arij',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor(context),
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: roleColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        (subtitle != null && subtitle!.isNotEmpty) ? subtitle! : roleName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkSecondary : AppTheme.secondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Right: Theme Toggle Circle + Bell + Avatar ───────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Circular iOS Dark / Light Toggle Switch ──
              if (onThemeToggle != null) ...[
                GestureDetector(
                  onTap: onThemeToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.12),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
                        size: 15,
                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0B2545),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Notification bell with pulse badge
              GestureDetector(
                onTap: onNotificationsPressed,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B293C) : AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        unreadNotifications > 0
                            ? CupertinoIcons.bell_fill
                            : CupertinoIcons.bell,
                        size: 19,
                        color: unreadNotifications > 0
                            ? AppTheme.vitalEmergency
                            : iconColor,
                      ),
                      if (unreadNotifications > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.vitalEmergency,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: surfaceBg,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Avatar with live presence badge ("De garde")
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: roleColor.withValues(alpha: 0.6),
                        width: 1.8,
                      ),
                    ),
                    child: AvatarWidget(
                      avatarUrl: profileImageUrl,
                      name: userName ?? 'User',
                      radius: 16,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppTheme.vitalDischarged,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: surfaceBg,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

