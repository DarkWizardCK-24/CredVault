import 'dart:math' as math;

import 'package:cred_vault/core/password/password_strength.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:flutter/material.dart';

Color strengthColor(StrengthLevel level) {
  switch (level) {
    case StrengthLevel.veryWeak:
      return AppTheme.danger;
    case StrengthLevel.weak:
      return AppTheme.warning;
    case StrengthLevel.fair:
      return AppTheme.gold;
    case StrengthLevel.strong:
      return const Color(0xFF8FE388);
    case StrengthLevel.excellent:
      return AppTheme.success;
  }
}

/// Five-segment strength bar with a label (and, optionally, hints).
class StrengthMeter extends StatelessWidget {
  final PasswordStrength strength;
  final bool showHints;
  final bool showCrackTime;

  const StrengthMeter({
    super.key,
    required this.strength,
    this.showHints = true,
    this.showCrackTime = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = strengthColor(strength.level);
    return Semantics(
      label: 'Password strength: ${strength.level.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 5; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i <= strength.level.score
                          ? color
                          : AppTheme.surfaceHigh,
                    ),
                  ),
                ),
                if (i < 4) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                strength.level.label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (showCrackTime && strength.bits > 0) ...[
                const Spacer(),
                Text(
                  'Cracked in ${strength.crackTime}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          if (showHints && strength.hints.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final hint in strength.hints.take(2))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• $hint',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Circular score gauge (0-100) with the number in the middle.
class SecurityRing extends StatelessWidget {
  final int score;
  final double size;
  final bool showLabel;

  const SecurityRing({
    super.key,
    required this.score,
    this.size = 150,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = score / 100;
    final color = AppTheme.forScore(fraction);
    return Semantics(
      label: 'Security score',
      value: '$score out of 100',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: fraction),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => CustomPaint(
            painter: _RingPainter(value, color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: size * 0.3,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      height: 1,
                    ),
                  ),
                  if (showLabel)
                    Text(
                      'of 100',
                      style: TextStyle(
                        fontSize: size * 0.085,
                        color: AppTheme.textSecondary,
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

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;

  _RingPainter(this.fraction, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - stroke,
    );
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = AppTheme.surfaceHigh
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (fraction <= 0) return;
    final sweep = 2 * math.pi * fraction;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}
