import 'package:cred_vault/core/password/password_strength.dart';
import 'package:cred_vault/core/validators.dart';
import 'package:cred_vault/models/credential_category.dart';
import 'package:cred_vault/models/credential_model.dart';
import 'package:cred_vault/models/platform_catalog.dart';
import 'package:cred_vault/providers/vault_provider.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/widgets/custom_button.dart';
import 'package:cred_vault/widgets/custom_text_field.dart';
import 'package:cred_vault/widgets/generator_panel.dart';
import 'package:cred_vault/widgets/glass_container.dart';
import 'package:cred_vault/widgets/platform_data.dart';
import 'package:cred_vault/widgets/snackbar_helper.dart';
import 'package:cred_vault/widgets/strength_meter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Add a new credential, or edit [credential].
class AddCredentialScreen extends StatefulWidget {
  final Credential? credential;

  /// Pre-fills the password (e.g. from the generator tab).
  final String? initialPassword;

  const AddCredentialScreen({super.key, this.credential, this.initialPassword});

  @override
  State<AddCredentialScreen> createState() => _AddCredentialScreenState();
}

class _AddCredentialScreenState extends State<AddCredentialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _url = TextEditingController();
  final _notes = TextEditingController();

  String _platform = 'GitHub';
  CredentialCategory _category = CredentialCategory.development;
  bool _favorite = false;
  bool _obscure = true;
  bool _saving = false;

  bool get _editing => widget.credential != null;

  @override
  void initState() {
    super.initState();
    final c = widget.credential;
    if (c != null) {
      _platform = PlatformCatalog.normalise(c.platform);
      _title.text = c.title;
      _username.text = c.username;
      _password.text = c.password;
      _url.text = c.url;
      _notes.text = c.notes;
      _category = c.category;
      _favorite = c.favorite;
    } else if (widget.initialPassword != null) {
      _password.text = widget.initialPassword!;
      _obscure = false;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _url.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickPlatform() async {
    final picked = await showPlatformPicker(context, selected: _platform);
    if (picked == null) return;
    setState(() {
      _platform = picked;
      // Sensible defaults, without overwriting anything the user typed.
      if (!_editing) _category = PlatformCatalog.of(picked).category;
    });
  }

  Future<void> _generate() async {
    final password = await showGeneratorSheet(context);
    if (password == null) return;
    setState(() {
      _password.text = password;
      _obscure = false;
    });
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final vault = context.read<VaultProvider>();
    final navigator = Navigator.of(context);
    final now = vault.now;
    try {
      final base = widget.credential;
      final credential = Credential(
        id: base?.id ?? '',
        platform: _platform,
        title: _title.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        url: _url.text.trim(),
        notes: _notes.text.trim(),
        category: _category,
        favorite: _favorite,
        createdAt: base?.createdAt ?? now,
        updatedAt: now,
        passwordChangedAt: base?.passwordChangedAt ?? now,
      );
      final saved = _editing
          ? await vault.update(credential)
          : await vault.add(credential);
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        _editing ? 'Changes saved' : '${saved.displayName} saved to your vault',
      );
      navigator.pop(saved);
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, "Couldn't save. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = PlatformCatalog.of(_platform);
    final strength = PasswordStrengthEstimator.evaluate(_password.text);
    final isOther = _platform == PlatformCatalog.other;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit credential' : 'New credential'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GlassContainer(
                        onTap: _pickPlatform,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            PlatformAvatar(platform: _platform, size: 54),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Service',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  Text(
                                    info.name,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.unfold_more_rounded,
                              color: AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassContainer(
                        child: Column(
                          children: [
                            CustomTextField(
                              controller: _title,
                              label: isOther ? 'Name' : 'Name (optional)',
                              hint: isOther
                                  ? 'e.g. Electricity portal'
                                  : info.name,
                              prefixIcon: Icons.label_outline_rounded,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              validator: isOther
                                  ? (v) => Validators.required(
                                      v,
                                      'Give this login a name',
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            CustomTextField(
                              controller: _username,
                              label: 'Username or email',
                              prefixIcon: Icons.person_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              validator: (v) => Validators.required(
                                v,
                                'Enter the username or email',
                              ),
                            ),
                            const SizedBox(height: 14),
                            CustomTextField(
                              controller: _password,
                              label: 'Password',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: _obscure,
                              monospace: true,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Enter the password'
                                  : null,
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: _obscure
                                        ? 'Show password'
                                        : 'Hide password',
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                  IconButton(
                                    tooltip: 'Generate a password',
                                    icon: const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: AppTheme.gold,
                                    ),
                                    onPressed: _generate,
                                  ),
                                ],
                              ),
                            ),
                            if (_password.text.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              StrengthMeter(strength: strength),
                            ],
                            const SizedBox(height: 14),
                            CustomTextField(
                              controller: _url,
                              label: 'Website (optional)',
                              hint: info.site ?? 'example.com',
                              prefixIcon: Icons.link_rounded,
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                              validator: Validators.url,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Category',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final c in CredentialCategory.values)
                                  ChoiceChip(
                                    avatar: Icon(
                                      c.icon,
                                      size: 17,
                                      color: _category == c
                                          ? AppTheme.background
                                          : c.color,
                                    ),
                                    label: Text(c.label),
                                    selected: _category == c,
                                    showCheckmark: false,
                                    selectedColor: c.color,
                                    backgroundColor: AppTheme.surfaceHigh,
                                    side: BorderSide.none,
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: _category == c
                                          ? AppTheme.background
                                          : AppTheme.textPrimary,
                                    ),
                                    onSelected: (_) =>
                                        setState(() => _category = c),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _favorite,
                              onChanged: (v) => setState(() => _favorite = v),
                              title: const Text(
                                'Favorite',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: const Text(
                                'Pin to the top of your vault',
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassContainer(
                        child: CustomTextField(
                          controller: _notes,
                          label: 'Notes (optional)',
                          prefixIcon: Icons.notes_rounded,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: _editing ? 'Save changes' : 'Save to vault',
                        icon: Icons.lock_rounded,
                        isLoading: _saving,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
