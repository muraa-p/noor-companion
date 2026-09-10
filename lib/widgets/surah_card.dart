import 'package:flutter/material.dart';

import '../models/models.dart';
import '../providers/quran_provider.dart';
import '../theme/colors.dart';

/// A decorative mushaf-style ayah-number medallion.
class AyahNumber extends StatelessWidget {
  final int number;
  final double size;
  final Color? color;

  const AyahNumber(this.number, {super.key, this.size = 26, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Text(
        QurNum.arabicDigits(number),
        style: TextStyle(
          color: c,
          fontFamily: 'Amiri',
          fontSize: size * 0.55,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A card for a single surah in the index.
class SurahCard extends StatelessWidget {
  final Surah surah;
  final VoidCallback? onTap;
  final bool downloaded;
  final double? downloadProgress;
  final bool isDownloading;

  const SurahCard({
    super.key,
    required this.surah,
    this.onTap,
    this.downloaded = false,
    this.downloadProgress,
    this.isDownloading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sub = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _NumberBadge(number: surah.number),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            surah.transliteration,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· ${surah.revelationType}',
                          style: sub?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${surah.ayahCount} verses',
                      style: sub?.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _recitationTrait(context, isDownloading: isDownloading, downloaded: downloaded),
              const SizedBox(width: 4),
              Text(
                surah.shortArabicName,
                textAlign: TextAlign.left,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: 'Amiri',
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recitationTrait(
    BuildContext context, {
    required bool isDownloading,
    required bool downloaded,
  }) {
    if (isDownloading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: downloadProgress,
          color: AppColors.gold,
        ),
      );
    }
    if (downloaded) {
      return Icon(Icons.download_done, size: 18, color: Ui.gold(context));
    }
    return const SizedBox(width: 20);
  }
}

class _NumberBadge extends StatelessWidget {
  final int number;
  const _NumberBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        QurNum.arabicDigits(number),
        style: TextStyle(
          fontFamily: 'Amiri',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}