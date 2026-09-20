import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Bouton compact (icône animée) qui ouvre un ActionSheet iOS
/// pour choisir entre Light, Dark et Système.
class ThemeToggleButton extends StatelessWidget {
  final Color? iconColor;
  const ThemeToggleButton({super.key, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, mode, _) {
        final icon = _iconFor(mode);
        return GestureDetector(
          onTap: () => _showThemePicker(context),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve:  Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim, child: child,
            ),
            child: Icon(
              icon,
              key: ValueKey(mode),
              size: 22,
              color: iconColor ?? Theme.of(context).appBarTheme.foregroundColor,
            ),
          ),
        );
      },
    );
  }

  IconData _iconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:   return CupertinoIcons.moon_fill;
      case ThemeMode.light:  return CupertinoIcons.sun_max_fill;
      case ThemeMode.system: return CupertinoIcons.circle_lefthalf_fill;
    }
  }

  void _showThemePicker(BuildContext context) {
    final current = AppTheme.themeModeNotifier.value;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text(
          'Apparence de l\'application',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        message: const Text(
          'Polyclinique Arij Djerba',
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          _buildAction(
            ctx,
            icon:    CupertinoIcons.sun_max_fill,
            label:   'Mode Clair',
            mode:    ThemeMode.light,
            current: current,
          ),
          _buildAction(
            ctx,
            icon:    CupertinoIcons.moon_fill,
            label:   'Mode Sombre',
            mode:    ThemeMode.dark,
            current: current,
          ),
          _buildAction(
            ctx,
            icon:    CupertinoIcons.circle_lefthalf_fill,
            label:   'Suivre le système',
            mode:    ThemeMode.system,
            current: current,
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Annuler'),
        ),
      ),
    );
  }

  CupertinoActionSheetAction _buildAction(
    BuildContext ctx, {
    required IconData  icon,
    required String    label,
    required ThemeMode mode,
    required ThemeMode current,
  }) {
    final isSelected = current == mode;
    return CupertinoActionSheetAction(
      isDefaultAction: isSelected,
      onPressed: () async {
        Navigator.of(ctx).pop();
        await AppTheme.setThemeMode(mode);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: isSelected ? AppTheme.turquoise : null),
          const SizedBox(width: 10),
          Text(label),
          if (isSelected) ...[
            const SizedBox(width: 8),
            const Icon(CupertinoIcons.checkmark, size: 14, color: AppTheme.turquoise),
          ],
        ],
      ),
    );
  }
}

/// Version intégrée pour les listes de paramètres (settings)
class ThemeSettingsRow extends StatelessWidget {
  const ThemeSettingsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDarkMode(context);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, mode, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.paintbrush_fill,
                    size: 16,
                    color: AppTheme.subtextColor(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Apparence',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.subtextColor(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.borderColor(context),
                ),
              ),
              child: Column(
                children: [
                  _buildOption(
                    context,
                    icon:    CupertinoIcons.sun_max_fill,
                    color:   AppTheme.warning,
                    label:   'Mode Clair',
                    subtitle: 'Fond lumineux Arij',
                    mode:    ThemeMode.light,
                    current: mode,
                    dark:    dark,
                  ),
                  Divider(
                    height: 1,
                    color: AppTheme.borderColor(context),
                    indent: 52,
                  ),
                  _buildOption(
                    context,
                    icon:    CupertinoIcons.moon_fill,
                    color:   AppTheme.accent,
                    label:   'Mode Sombre',
                    subtitle: 'Bleu pétrole profond',
                    mode:    ThemeMode.dark,
                    current: mode,
                    dark:    dark,
                  ),
                  Divider(
                    height: 1,
                    color: AppTheme.borderColor(context),
                    indent: 52,
                  ),
                  _buildOption(
                    context,
                    icon:    CupertinoIcons.circle_lefthalf_fill,
                    color:   AppTheme.turquoise,
                    label:   'Système',
                    subtitle: 'Suit les préférences iOS / Android',
                    mode:    ThemeMode.system,
                    current: mode,
                    dark:    dark,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData  icon,
    required Color     color,
    required String    label,
    required String    subtitle,
    required ThemeMode mode,
    required ThemeMode current,
    required bool      dark,
  }) {
    final isSelected = current == mode;
    return InkWell(
      onTap: () => AppTheme.setThemeMode(mode),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:        color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.subtextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width:  22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.turquoise : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.turquoise
                      : AppTheme.borderColor(context),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      CupertinoIcons.checkmark,
                      size: 12,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
