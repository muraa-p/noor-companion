import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/static_content.dart';
import '../models/models.dart';
import '../providers/recitation_provider.dart';
import '../theme/colors.dart';

/// Bottom sheet for choosing a reciter. Shows a small offline badge ("N surahs")
/// next to reciters that already have audio downloaded.
class ReciterPickerSheet extends StatefulWidget {
  final Reciter initialReciter;
  final ScrollController? scrollController;
  final ValueChanged<Reciter> onSelected;

  const ReciterPickerSheet({
    super.key,
    required this.initialReciter,
    required this.onSelected,
    this.scrollController,
  });

  @override
  State<ReciterPickerSheet> createState() => _ReciterPickerSheetState();
}

class _ReciterPickerSheetState extends State<ReciterPickerSheet> {
  Map<String, int> _offlineCounts = {};

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final rec = context.read<RecitationProvider>();
    final counts = <String, int>{};
    for (final r in kReciters) {
      counts[r.identifier] = await rec.downloadedCountFor(r);
    }
    if (mounted) setState(() => _offlineCounts = counts);
  }

  @override
  Widget build(BuildContext context) {
    final rec = context.watch<RecitationProvider>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Choose a reciter',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: const PageStorageKey('reciter'),
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: kReciters.length,
            itemBuilder: (context, i) {
              final r = kReciters[i];
              final selected = r.identifier == rec.reciter.identifier;
              final offline = _offlineCounts[r.identifier] ?? 0;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: selected
                      ? AppColors.emeraldSoft
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text(
                    r.arabicName.substring(0, 1),
                    style: const TextStyle(
                      fontFamily: 'Amiri',
                      color: AppColors.emeraldDeep,
                    ),
                  ),
                ),
                title: Text(r.englishName),
                subtitle: Text(r.arabicName),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: AppColors.emerald)
                    : offline > 0
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.offline_pin,
                                size: 16,
                                color: AppColors.gold,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$offline offline',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
                          )
                        : null,
                selected: selected,
                onTap: () => widget.onSelected(r),
              );
            },
          ),
        ),
      ],
    );
  }
}