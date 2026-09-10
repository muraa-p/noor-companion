import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../providers/settings_provider.dart';
import '../theme/colors.dart';

/// Pushes a first-run [TutorialOverlay] for [seenId] — a per-screen id that
/// guarantees each spot- light sequence runs at most once. The overlay is
/// full-screen (above AppBars, bottom bars and the navigation rail), so the
/// spotlighted widget can live anywhere in the app.
void showTutorialOnce(
  BuildContext context, {
  required String seenId,
  required SettingsProvider settings,
  required List<TutorialStep> steps,
}) {
  if (steps.isEmpty || settings.tutorialSeen(seenId)) return;
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => TutorialOverlay(
        steps: steps,
        onFinished: () => settings.setTutorialSeen(seenId),
      ),
    ),
  );
}

/// A single coach-mark step: the widget to spotlight (via [targetKey]) plus
/// the title/body text shown in the tooltip bubble.
class TutorialStep {
  TutorialStep({
    required this.targetKey,
    required this.title,
    required this.body,
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
}

/// Full-screen spotlight tutorial. Drops a dim barrier over the whole app,
/// cuts a glowing hole around the current [TutorialStep] target and shows a
/// tooltip bubble with an arrow. Tapping anywhere advances; the last step
/// finishes by calling [onFinished].
///
/// Designed to be pushed as a transparent route so it sits above AppBars and
/// bottom bars; GlobalKeys owned by the page beneath it keep working.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onFinished,
  });

  final List<TutorialStep> steps;
  final VoidCallback onFinished;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  int _index = 0;
  bool _finished = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Global position of the current step's target, converted into this
  /// overlay's own coordinate space (so it is correct even if the overlay
  /// route is offset by a system inset or the page's own transforms).
  Rect _targetRect(BuildContext context) {
    final targetCtx = widget.steps[_index].targetKey.currentContext;
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (targetCtx == null || overlayBox == null) return Rect.zero;
    final targetBox = targetCtx.findRenderObject() as RenderBox?;
    if (targetBox == null || !targetBox.attached) return Rect.zero;
    final origin = overlayBox.localToGlobal(Offset.zero);
    final topLeft = targetBox.localToGlobal(Offset.zero) - origin;
    return topLeft & targetBox.size;
  }

  void _advance() {
    if (_index < widget.steps.length - 1) {
      setState(() => _index++);
    } else {
      _finish();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    Navigator.of(context).pop();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final titleStyle = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: Ui.emerald(context),
    );
    final bodyStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface,
    );

    final size = MediaQuery.of(context).size;
    const maxWidth = 360.0;
    const bubbleHPad = 16.0;

    final titlePainter = TextPainter(
      text: TextSpan(text: step.title, style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth - bubbleHPad * 2);
    final bodyPainter = TextPainter(
      text: TextSpan(text: step.body, style: bodyStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth - bubbleHPad * 2);

    final bubbleWidth =
        (math.max(titlePainter.width, bodyPainter.width) + bubbleHPad * 2)
            .clamp(200.0, maxWidth);
    final bubbleHeight = 12 + titlePainter.height + 4 +
        bodyPainter.height + 10 + 20 + 12;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _finish();
      },
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final target = _targetRect(context);

            // Place the bubble below the target, or above it when there is
            // not enough room underneath.
            const gap = 14.0;
            const outerPad = 16.0;
            var bubbleTop = target.bottom + gap;
            var arrowUp = true;
            if (target == Rect.zero ||
                bubbleTop + bubbleHeight > size.height - outerPad) {
              bubbleTop = target == Rect.zero
                  ? (size.height - bubbleHeight) / 2
                  : target.top - gap - bubbleHeight;
              arrowUp = false;
            }
            final bubbleLeft = target == Rect.zero
                ? (size.width - bubbleWidth) / 2
                : (target.center.dx - bubbleWidth / 2)
                    .clamp(outerPad, size.width - bubbleWidth - outerPad);

            final bubbleColor = scheme.surfaceContainer;
            final arrowLeft = target == Rect.zero
                ? bubbleLeft + bubbleWidth / 2
                : (target.center.dx - bubbleLeft).clamp(30.0, bubbleWidth - 30.0);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _advance,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _SpotlightPainter(
                      target: target.inflate(
                        target == Rect.zero ? 0 : 10,
                      ),
                      pulse: _pulse.value,
                    ),
                  ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                        ),
                        child: const Text('Skip'),
                      ),
                    ),
                  ),
                  if (target != Rect.zero)
                    Positioned(
                      left: bubbleLeft + arrowLeft - 10,
                      top: arrowUp ? bubbleTop - 9 : bubbleTop + bubbleHeight - 4,
                      child: Icon(
                        arrowUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        size: 22,
                        color: bubbleColor,
                      ),
                    ),
                  Positioned(
                    left: bubbleLeft,
                    top: bubbleTop,
                    width: bubbleWidth,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(
                        bubbleHPad,
                        12,
                        bubbleHPad,
                        12,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Ui.isDark(context)
                              ? AppColors.goldLight
                              : AppColors.gold,
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step.title, style: titleStyle),
                          const SizedBox(height: 4),
                          Text(step.body, style: bodyStyle),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              for (var i = 0; i < widget.steps.length; i++)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i == _index
                                        ? Ui.gold(context)
                                        : scheme.outline,
                                  ),
                                ),
                              const Spacer(),
                              Text(
                                _index == widget.steps.length - 1
                                    ? 'Got it'
                                    : 'Next',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Ui.gold(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.target,
    required this.pulse,
  });

  final Rect target;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (target == Rect.zero) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: 0.72),
      );
      return;
    }

    final rrect =
        RRect.fromRectAndRadius(target, const Radius.circular(18));
    final hole = Path()..addRRect(rrect);
    final cover = Path()..addRect(Offset.zero & size);
    final dim = Path.combine(PathOperation.difference, cover, hole);
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.80));

    // Pulsing soft glow behind the crisp gold edge.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.45 + 0.30 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20.0 - 7.0 * pulse),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = AppColors.goldLight.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.target != target || oldDelegate.pulse != pulse;
}