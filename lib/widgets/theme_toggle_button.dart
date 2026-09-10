import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

/// Top-right theme switch. Follows the *effective* brightness (so it respects
/// the system's light/dark mode too): shows the sun when the app is dark and
/// the moon when it is light, and toggles to the opposite explicit mode.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final effectiveDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton.outlined(
      tooltip: effectiveDark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () {
        context
            .read<SettingsProvider>()
            .setTheme(effectiveDark ? ThemeMode.light : ThemeMode.dark);
      },
      icon: Icon(
        effectiveDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        size: 20,
      ),
    );
  }
}