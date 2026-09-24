export 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';

class IosBottomNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const IosBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
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
    final primaryActive = activeColor ?? AppTheme.tropicalTeal;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 6,
          bottom: 12,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 64),
            child: Container(
              height: 64,
            decoration: BoxDecoration(
              // Capsule sombre moderne en charbon / graphite
              color: isDark ? const Color(0xFF1B202A) : const Color(0xFF26282E),
              borderRadius: BorderRadius.circular(38),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.28),
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
                double targetLeft = (safeSelectedIndex * slotWidth) + (slotWidth - circleDiameter) / 2;
                if (targetLeft.isNaN || !targetLeft.isFinite) {
                  targetLeft = 4.0;
                }
                final maxLeft = (totalWidth - circleDiameter - 4.0);
                final safeLeft = maxLeft > 4.0 ? targetLeft.clamp(4.0, maxLeft) : 4.0;

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // ── Disque circulaire blanc animé (glisse sous l'icône active) ──
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutBack,
                      left: safeLeft,
                      top: circleTop,
                      width: circleDiameter,
                      height: circleDiameter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
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
                                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                                        child: Icon(
                                          isSelected ? item.selectedIcon : item.icon,
                                          key: ValueKey('${item.label}_$isSelected'),
                                          size: isSelected ? 24 : 22,
                                          color: isSelected
                                              ? primaryActive
                                              : Colors.white.withValues(alpha: 0.88),
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
