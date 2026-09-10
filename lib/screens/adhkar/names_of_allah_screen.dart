import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/static_content.dart';
import '../../models/models.dart';
import '../../providers/hasanat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';

class NamesOfAllahScreen extends StatelessWidget {
  const NamesOfAllahScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('99 Beautiful Names'),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: kNamesOfAllah.length,
          itemBuilder: (context, i) {
            final name = kNamesOfAllah[i];
            return _NameCard(name: name);
          },
        ),
      ),
    );
  }
}

class _NameCard extends StatelessWidget {
  final NameOfAllah name;
  const _NameCard({required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasanat = context.watch<HasanatProvider>();
    final todayCount = hasanat.todayRecord.dhikrCounts[name.arabic] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.read<HasanatProvider>().increaseDhikr(name.arabic);
            if (context.read<SettingsProvider>().haptics) {
              HapticFeedback.selectionClick();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.emeraldSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${name.number}',
                    style: const TextStyle(
                      color: AppColors.emeraldDeep,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.transliteration,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        name.meaning,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  name.arabic,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 22,
                    color: Ui.bismillah(context),
                  ),
                ),
                const SizedBox(width: 10),
                if (todayCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.goldSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$todayCount',
                      style: const TextStyle(
                        color: AppColors.goldDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}