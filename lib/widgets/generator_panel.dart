import 'package:cred_vault/core/password/password_generator.dart';
import 'package:cred_vault/core/password/password_strength.dart';
import 'package:cred_vault/services/clipboard_service.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/widgets/custom_button.dart';
import 'package:cred_vault/widgets/glass_container.dart';
import 'package:cred_vault/widgets/snackbar_helper.dart';
import 'package:cred_vault/widgets/strength_meter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Password generator controls and output. Used on the Generator tab and in
/// the "generate" sheet of the add/edit screen.
class GeneratorPanel extends StatefulWidget {
  /// When set, shows a button that hands the password to the caller.
  final ValueChanged<String>? onUse;
  final String useLabel;
  final IconData useIcon;

  /// Injectable for tests.
  final PasswordGenerator? generator;

  const GeneratorPanel({
    super.key,
    this.onUse,
    this.useLabel = 'Use this password',
    this.useIcon = Icons.check_rounded,
    this.generator,
  });

  @override
  State<GeneratorPanel> createState() => _GeneratorPanelState();
}

class _GeneratorPanelState extends State<GeneratorPanel> {
  late final PasswordGenerator _generator =
      widget.generator ?? PasswordGenerator();
  GeneratorOptions _options = const GeneratorOptions();
  late String _password = _generator.generate(_options);

  void _regenerate([GeneratorOptions? next]) {
    final options = next ?? _options;
    // Keep at least one kind of character selected.
    if (!options.hasAnyClass) return;
    setState(() {
      _options = options;
      _password = _generator.generate(options);
    });
  }

  Future<void> _copy() async {
    await context.read<ClipboardService>().copy(_password);
    if (mounted) SnackBarHelper.showSuccess(context, 'Password copied');
  }

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrengthEstimator.evaluate(_password);

    Widget toggle(
      String label,
      String example,
      bool value,
      ValueChanged<bool> onChanged,
    ) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: value,
        onChanged: onChanged,
        title: Text(
          label,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
        ),
        subtitle: Text(
          example,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: 'Generated password',
                child: SelectableText(
                  _password,
                  style: const TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.goldLight,
                    height: 1.35,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StrengthMeter(strength: strength, showHints: false),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _regenerate(),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('Regenerate'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      label: const Text('Copy'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassContainer(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Length',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_options.length}',
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _options.length.toDouble(),
                min: PasswordGenerator.minLength.toDouble(),
                max: PasswordGenerator.maxLength.toDouble(),
                divisions:
                    PasswordGenerator.maxLength - PasswordGenerator.minLength,
                label: '${_options.length}',
                onChanged: (v) =>
                    _regenerate(_options.copyWith(length: v.round())),
              ),
              toggle(
                'Lowercase',
                'a-z',
                _options.lowercase,
                (v) => _regenerate(_options.copyWith(lowercase: v)),
              ),
              toggle(
                'Uppercase',
                'A-Z',
                _options.uppercase,
                (v) => _regenerate(_options.copyWith(uppercase: v)),
              ),
              toggle(
                'Numbers',
                '0-9',
                _options.digits,
                (v) => _regenerate(_options.copyWith(digits: v)),
              ),
              toggle(
                'Symbols',
                '! @ # \$ % & *',
                _options.symbols,
                (v) => _regenerate(_options.copyWith(symbols: v)),
              ),
              toggle(
                'Avoid look-alikes',
                'Skip O, 0, l, 1 and I',
                _options.avoidAmbiguous,
                (v) => _regenerate(_options.copyWith(avoidAmbiguous: v)),
              ),
            ],
          ),
        ),
        if (widget.onUse != null) ...[
          const SizedBox(height: 20),
          CustomButton(
            text: widget.useLabel,
            icon: widget.useIcon,
            onPressed: () => widget.onUse!(_password),
          ),
        ],
      ],
    );
  }
}

/// Sheet wrapper: returns the generated password the user chose.
Future<String?> showGeneratorSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Generate a password',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            GeneratorPanel(onUse: (p) => Navigator.pop(sheetContext, p)),
          ],
        ),
      ),
    ),
  );
}
