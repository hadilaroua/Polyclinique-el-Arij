export 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/theme.dart';

class IosBottomNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const IosBottomNavItem({required this.icon, required this.selectedIcon, required this.label});
}

/// Barre de navigation flottante en capsule / pilule inspirée d'iOS
/// - Capsule sombre flottante avec bordures douces et ombre portée
/// - Indicateur circulaire blanc surélevé glissant de manière animée (easeOutBack)
/// - Icône active teintée avec la couleur primaire de la charte (Tropical Teal)
/// - Icônes inactives en blanc pur
/// - Pas de texte pour un design minimaliste et ultra-moderne (labels en tooltip)
class IosBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<IosBottomNavItem> items;
  final Color? activeColor;

  const IosBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final isDark = AppTheme.isDarkMode(context);
    final primaryActive = isDark ? AppTheme.darkPrimary : (activeColor ?? AppTheme.evergreen);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 6, bottom: 12),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 64),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.evergreen,
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppTheme.darkSurface, AppTheme.darkSurfaceSecondary]
                      : [AppTheme.evergreen, AppTheme.darkTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(38),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.darkTeal.withValues(alpha: 0.6),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? AppTheme.darkPrimary : AppTheme.evergreen).withValues(
                      alpha: 0.24,
                    ),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final itemCount = items.length;
                  if (itemCount == 0 || totalWidth <= 0 || !totalWidth.isFinite) {
                    return const SizedBox.shrink();
                  }
                  final slotWidth = totalWidth / itemCount;
                  const circleDiameter = 48.0;
                  final circleTop = (64 - circleDiameter) / 2;
                  final safeSelectedIndex = selectedIndex.clamp(0, itemCount - 1);
                  double targetLeft =
                      (safeSelectedIndex * slotWidth) + (slotWidth - circleDiameter) / 2;
                  if (targetLeft.isNaN || !targetLeft.isFinite) {
                    targetLeft = 4.0;
                  }
                  final maxLeft = (totalWidth - circleDiameter - 4.0);
                  final safeLeft = maxLeft > 4.0 ? targetLeft.clamp(4.0, maxLeft) : 4.0;

                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // ── Disque circulaire animé (glisse sous l'icône active) ──
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutBack,
                        left: safeLeft,
                        top: circleTop,
                        width: circleDiameter,
                        height: circleDiameter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkSurfaceActive : Colors.white,
                            shape: BoxShape.circle,
                            border: isDark
                                ? Border.all(color: AppTheme.darkBorder, width: 1)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.22),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Rangée d'icônes ──
                      Row(
                        children: List.generate(items.length, (index) {
                          final item = items[index];
                          final isSelected = selectedIndex == index;

                          return Expanded(
                            child: Tooltip(
                              message: item.label,
                              waitDuration: const Duration(milliseconds: 500),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    onItemSelected(index);
                                  },
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  borderRadius: BorderRadius.circular(38),
                                  child: SizedBox(
                                    height: 64,
                                    child: Center(
                                      child: AnimatedScale(
                                        scale: isSelected ? 1.06 : 1.0,
                                        duration: const Duration(milliseconds: 200),
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 200),
                                          transitionBuilder: (child, anim) =>
                                              ScaleTransition(scale: anim, child: child),
                                          child: Icon(
                                            isSelected ? item.selectedIcon : item.icon,
                                            key: ValueKey('${item.label}_$isSelected'),
                                            size: isSelected ? 24 : 22,
                                            color: isSelected
                                                ? primaryActive
                                                : (isDark
                                                      ? AppTheme.darkTextTertiary
                                                      : Colors.white.withValues(alpha: 0.88)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
