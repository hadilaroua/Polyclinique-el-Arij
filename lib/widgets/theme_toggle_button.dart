import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Bouton 1-clic direct pour basculer entre Dark Mode et White/Light Mode
/// Design circulaire style iOS Control Center avec micro-animation fluide
class ThemeToggleButton extends StatelessWidget {
  final double size;

  const ThemeToggleButton({
    super.key,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return Tooltip(
          message: isDark ? 'Passer au mode clair' : 'Passer au mode sombre',
          child: GestureDetector(
            onTap: AppTheme.toggleTheme,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.12),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
                    key: ValueKey(isDark),
                    size: size * 0.48,
                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0B2545),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Carte de paramètres avec un unique bouton switch direct entre Dark et White mode
class ThemeSettingsRow extends StatelessWidget {
  const ThemeSettingsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderColor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: AppTheme.toggleTheme,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.tropicalTeal.withValues(alpha: 0.18)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
                        size: 20,
                        color: isDark ? AppTheme.tropicalTeal : const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDark ? 'Mode Sombre' : 'Mode Clair (Blanc)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textColor(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDark ? 'Thème sombre actif' : 'Thème clair actif',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.subtextColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoSwitch(
                      value: isDark,
                      activeTrackColor: AppTheme.tropicalTeal,
                      onChanged: (_) => AppTheme.toggleTheme(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
