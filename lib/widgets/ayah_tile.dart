import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/hasanat_provider.dart';
import '../providers/quran_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import 'surah_card.dart';

/// A single ayah rendered in the reader.
class AyahTile extends StatelessWidget {
  final Ayah ayah;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPlay;
  final bool isPlaying;
  const AyahTile({
    super.key,
    required this.ayah,
    this.onTap,
    this.onLongPress,
    this.onPlay,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quran = context.watch<QuranProvider>();
    final hasanat = context.watch<HasanatProvider>();
    final settings = context.watch<SettingsProvider>();

    final letters = quran.lettersOf(ayah);
    final hasanatValue = letters * kHasanatPerAyahLetter;
    final read = hasanat.isRead(ayah.reference);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: read
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Arabic text with end-of-ayah medallion.
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Stack(
                    children: [
                      Text(
                        '${ayah.arabic} ',
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: settings.arabicFontSize,
                          height: 1.9,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        bottom: 0,
                        child: AyahNumber(ayah.numberInSurah),
                      ),
                    ],
                  ),
                ),
                if (settings.showTranslation && ayah.english.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    ayah.english,
                    style: TextStyle(
                      fontSize: settings.latinFontSize,
                      height: 1.45,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      icon: read ? Icons.check_circle : Icons.radio_button_unchecked,
                      label: read ? 'Read' : 'Mark read',
                      activeColor: read,
                      onTap: () {
                        if (!read) {
                          hasanat.addAyahRead(ayah.reference);
                          if (settings.haptics) {
                            HapticFeedback.selectionClick();
                          }
                        }
                      },
                    ),
                    _Chip(
                      icon: Icons.auto_awesome,
                      iconColor: AppColors.gold,
                      label: '+$hasanatValue',
                      onTap: null,
                    ),
                    if (onPlay != null)
                      _Chip(
                        icon: isPlaying
                            ? Icons.graphic_eq
                            : Icons.play_arrow,
                        iconColor: isPlaying ? AppColors.emerald : null,
                        label: isPlaying ? 'Playing' : 'Play',
                        accent: isPlaying,
                        onTap: onPlay,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool activeColor;
  final bool accent;
  const _Chip({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
    this.activeColor = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = accent
        ? AppColors.emeraldSoft
        : activeColor
            ? AppColors.goldSoft
            : scheme.surfaceContainerHighest;
    final iconCol = iconColor ??
        (accent
            ? AppColors.emerald
            : activeColor
                ? AppColors.gold
                : scheme.primary);
    final textCol = accent
        ? AppColors.emerald
        : activeColor
            ? AppColors.gold
            : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconCol),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textCol,
              ),
            ),
          ],
        ),
      ),
    );
  }
}