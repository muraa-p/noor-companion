import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/static_content.dart';
import '../../models/models.dart';
import '../../providers/hasanat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';
import '../../widgets/tutorial_overlay.dart';

class AdhkarScreen extends StatefulWidget {
  final ValueNotifier<int> selectedTab;
  final int tabIndex;

  const AdhkarScreen({
    super.key,
    required this.selectedTab,
    required this.tabIndex,
  });

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  bool _showMorning = true;
  final GlobalKey _segmentKey = GlobalKey();
  final GlobalKey _addKey = GlobalKey();
  bool _tutorialQueued = false;

  @override
  void initState() {
    super.initState();
    widget.selectedTab.addListener(_maybeShowTutorial);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  @override
  void dispose() {
    widget.selectedTab.removeListener(_maybeShowTutorial);
    super.dispose();
  }

  void _maybeShowTutorial() {
    if (_tutorialQueued) return;
    if (widget.selectedTab.value != widget.tabIndex) return;
    if (!mounted) return;
    _tutorialQueued = true;
    final settings = context.read<SettingsProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showTutorialOnce(
        context,
        seenId: 'adhkar',
        settings: settings,
        steps: [
          TutorialStep(
            targetKey: _segmentKey,
            title: 'Morning & evening',
            body: 'Switch between the morning and evening adhkar — the '
                'remembrances of the day and of the night.',
          ),
          TutorialStep(
            targetKey: _addKey,
            title: 'Add your own dhikr',
            body: 'Make any dhikr your own: add the phrase and how many '
                'times you want to repeat it. It counts toward today\'s '
                'hasanat like the built-in ones.',
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = _showMorning ? kMorningAdhkar : kEveningAdhkar;
    final custom = context.watch<SettingsProvider>().customDhikrs;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adhkar',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Morning & evening remembrances. Completing a dhikr adds '
                    '10 hasanat to today\'s tally.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      KeyedSubtree(
                        key: _segmentKey,
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: true, label: Text('Morning')),
                            ButtonSegment(value: false, label: Text('Evening')),
                          ],
                          selected: {_showMorning},
                          onSelectionChanged: (s) =>
                              setState(() => _showMorning = s.first),
                        ),
                      ),
                      const Spacer(),
                      KeyedSubtree(
                        key: _addKey,
                        child: Tooltip(
                          message: 'Add your own dhikr',
                          child: IconButton.filledTonal(
                            onPressed: _showAddDhikrDialog,
                            icon: const Icon(Icons.add),
                            tooltip: 'Add your own dhikr',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                children: [
                  if (custom.isNotEmpty) ...[
                    _CustomSectionTitle(
                      text: 'My dhikr',
                      trailing: '${custom.length} custom',
                    ),
                    for (final c in custom)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CustomDhikrCard(
                          key: ValueKey('custom-${c.arabic}'),
                          dhikr: c,
                          onDelete: () => _deleteCustomDhikr(c.arabic),
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                  _CustomSectionTitle(
                    text: _showMorning ? 'Morning adhkar' : 'Evening adhkar',
                  ),
                  for (final dhikr in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _DhikrCard(
                        key: ValueKey('$_showMorning-${list.indexOf(dhikr)}'),
                        dhikr: dhikr,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDhikrDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AddDhikrDialog(
        onSave: (dhikr) {
          context.read<SettingsProvider>().addCustomDhikr(dhikr);
        },
      ),
    );
  }

  Future<void> _deleteCustomDhikr(String arabic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this dhikr?'),
        content: const Text(
          'It will be removed from your list. Today\'s counted hasanat '
          'for it are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<SettingsProvider>().removeCustomDhikr(arabic);
    }
  }
}

class _CustomSectionTitle extends StatelessWidget {
  final String text;
  final String? trailing;
  const _CustomSectionTitle({required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _AddDhikrDialog extends StatefulWidget {
  final ValueChanged<CustomDhikr> onSave;
  const _AddDhikrDialog({required this.onSave});

  @override
  State<_AddDhikrDialog> createState() => _AddDhikrDialogState();
}

class _AddDhikrDialogState extends State<_AddDhikrDialog> {
  final TextEditingController _text = TextEditingController();
  int _repeat = 33;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add your own dhikr'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _text,
              autofocus: true,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'Dhikr text',
                hintText: 'e.g. سُبْحَانَ اللهِ وَبِحَمْدِهِ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Repeats', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.outlined(
                  onPressed: _repeat > 1
                      ? () => setState(() => _repeat = _repeat - 1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_repeat',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton.outlined(
                  onPressed: () => setState(() => _repeat = _repeat + 1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = _text.text.trim();
            if (text.isEmpty) return;
            widget.onSave(CustomDhikr(arabic: text, repeat: _repeat));
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dhikr added — it counts toward today\'s hasanat.'),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _CustomDhikrCard extends StatefulWidget {
  final CustomDhikr dhikr;
  final VoidCallback onDelete;
  const _CustomDhikrCard({
    super.key,
    required this.dhikr,
    required this.onDelete,
  });

  @override
  State<_CustomDhikrCard> createState() => _CustomDhikrCardState();
}

class _CustomDhikrCardState extends State<_CustomDhikrCard> {
  DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasanat = context.watch<HasanatProvider>();
    final todayCount =
        hasanat.todayRecord.dhikrCounts[widget.dhikr.arabic] ?? 0;
    final repeat = widget.dhikr.repeat;
    final doneToday = todayCount >= repeat;
    final progress = todayCount / repeat;

    return Material(
      color: doneToday
          ? AppColors.emeraldSoft.withValues(alpha: 0.5)
          : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _tap(hasanat),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.dhikr.arabic,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 22,
                        height: 1.9,
                        color: Ui.bismillah(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _RoundBadge(
                    doneToday: doneToday,
                    label: doneToday ? 'DAILY ✓' : '$todayCount/$repeat',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: AppColors.emerald,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'My dhikr',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Remove',
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _tap(HasanatProvider hasanat) async {
    final now = DateTime.now();
    if (now.difference(_lastTick).inMilliseconds < 180) return;
    _lastTick = now;
    final prior =
        hasanat.todayRecord.dhikrCounts[widget.dhikr.arabic] ?? 0;
    await hasanat.increaseDhikr(widget.dhikr.arabic);
    if (mounted && prior + 1 == widget.dhikr.repeat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dhikr completed — +10 hasanat'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _DhikrCard extends StatefulWidget {
  final Dhikr dhikr;
  const _DhikrCard({super.key, required this.dhikr});

  @override
  State<_DhikrCard> createState() => _DhikrCardState();
}

class _DhikrCardState extends State<_DhikrCard> {
  bool _showTranslation = false;

  int get _repeat => widget.dhikr.repeat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasanat = context.watch<HasanatProvider>();
    final settings = context.watch<SettingsProvider>();
    final todayCount = hasanat.todayRecord.dhikrCounts[widget.dhikr.arabic] ?? 0;
    final doneToday = _repeat == 0 ? false : todayCount >= _repeat;
    final progress = todayCount / _repeat;

    return Material(
      color: doneToday ? AppColors.emeraldSoft.withValues(alpha: 0.5) : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _tapAdhikr(hasanat, settings),
        onLongPress: () => setState(() {
          _showTranslation = !_showTranslation;
        }),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.dhikr.arabic,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 22,
                        height: 1.9,
                        color: Ui.bismillah(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _RoundBadge(
                    doneToday: doneToday,
                    label: doneToday ? 'DAILY ✓' : '$todayCount/$_repeat',
                  ),
                ],
              ),
              if (_showTranslation) ...[
                const SizedBox(height: 6),
                Text(
                  widget.dhikr.translation,
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: AppColors.emerald,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.dhikr.source,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _tapAdhikr(HasanatProvider hasanat, SettingsProvider settings) async {
    final now = DateTime.now();
    // Debounce accidental double taps.
    if (now.difference(_lastTick).inMilliseconds < 180) return;
    _lastTick = now;
    final prior = hasanat.todayRecord.dhikrCounts[widget.dhikr.arabic] ?? 0;
    await hasanat.increaseDhikr(widget.dhikr.arabic);
    if (settings.haptics) HapticFeedback.selectionClick();
    if (mounted && prior + 1 == _repeat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dhikr completed — +10 hasanat'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _RoundBadge extends StatelessWidget {
  final bool doneToday;
  final String label;
  const _RoundBadge({required this.doneToday, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: doneToday ? AppColors.emerald : AppColors.goldSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: doneToday ? Colors.white : AppColors.goldDark,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}