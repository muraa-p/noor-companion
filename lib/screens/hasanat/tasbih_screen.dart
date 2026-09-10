import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/hasanat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';

/// A visual tasbih (bead) counter. Each tap feeds the daily hasanat dhikr
/// tally. Default mode counts to 33; can switch to 100.
class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  static const _phrases = [
    ('سُبْحَانَ اللَّه', 'Subhan Allah'),
    ('الْحَمْدُ لِلَّه', 'Alhamdulillah'),
    ('اللَّهُ أَكْبَر', 'Allahu Akbar'),
    ('لَا إِلَهَ إِلَّا اللَّه', 'La ilaha illallah'),
    ('أَسْتَغْفِرُ الله', 'Astaghfirullah'),
  ];

  int _phraseIndex = 0;
  int _count = 0;
  int _target = 33;
  int _completedRounds = 0;

  String get _arabic => _phrases[_phraseIndex].$1;
  String get _translit => _phrases[_phraseIndex].$2;

  void _countUp() {
    final hasanat = context.read<HasanatProvider>();
    final settings = context.read<SettingsProvider>();
    setState(() {
      _count++;
      if (_count >= _target) {
        _count = 0;
        _completedRounds++;
        if (settings.haptics) {
          HapticFeedback.mediumImpact();
        }
      } else if (settings.haptics) {
        HapticFeedback.selectionClick();
      }
    });
    hasanat.increaseDhikr(_arabic);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasanat = context.watch<HasanatProvider>();
    final todayCount =
        hasanat.todayRecord.dhikrCounts[_arabic] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasbih'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () =>
                    setState(() => _phraseIndex = (_phraseIndex + 1) % _phrases.length),
                child: Chip(
                  avatar: const Icon(Icons.swap_horiz, size: 16),
                  label: Text(_translit),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _arabic,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Ui.emerald(context),
                ),
              ),
              const Spacer(),
              // Bead counter.
              Material(
                shape: const CircleBorder(),
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _countUp,
                  onLongPress: () {
                    setState(() {
                      _count = 0;
                      _completedRounds = 0;
                    });
                  },
                  child: Container(
                    width: 250,
                    height: 250,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.emerald, AppColors.teal],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emerald.withValues(alpha: 0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_count',
                          style: const TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 72,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'of $_target',
                          style: const TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundDisplay(label: 'Rounds', value: '$_completedRounds'),
                  _RoundDisplay(label: 'Today this dhikr', value: '$todayCount'),
                  _RoundDisplay(
                    label: 'Hasanat today',
                    value: '${hasanat.todayHasanat}',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 33, label: Text('33')),
                  ButtonSegment(value: 100, label: Text('100')),
                ],
                selected: {_target},
                onSelectionChanged: (selection) =>
                    setState(() {
                      _target = selection.first;
                      _count = 0;
                    }),
              ),
              const SizedBox(height: 12),
              Text(
                'Long-press the beads to reset.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundDisplay extends StatelessWidget {
  final String label;
  final String value;
  const _RoundDisplay({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Ui.emerald(context),
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}