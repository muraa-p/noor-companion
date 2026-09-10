import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/recitation_provider.dart';

/// A floating pill shown while any background download is running. Tapping it
/// jumps to the Recite tab (via [onTap]).
class DownloadBanner extends StatelessWidget {
  final VoidCallback onTap;
  const DownloadBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rec = context.watch<RecitationProvider>();
    if (!rec.anyDownloadActive) return const SizedBox.shrink();

    final label = rec.activeDownloadLabel ?? 'surah';
    final progress = rec.activeDownloadProgress;
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Material(
          key: const ValueKey('download-banner'),
          elevation: 6,
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: progress / 100,
                      backgroundColor: scheme.inverseSurface.withValues(alpha: 0.4),
                      color: scheme.onInverseSurface,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Downloading $label — $progress%',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onInverseSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}