import 'package:flutter/material.dart';

import '../utils/theme.dart';

class DarkAmbientBackground extends StatelessWidget {
  final Widget child;

  const DarkAmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(color: AppTheme.backgroundColor(context), child: child);
  }
}
