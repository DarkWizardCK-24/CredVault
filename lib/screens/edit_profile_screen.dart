import 'package:cred_vault/core/validators.dart';
import 'package:cred_vault/providers/vault_provider.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/widgets/custom_button.dart';
import 'package:cred_vault/widgets/custom_text_field.dart';
import 'package:cred_vault/widgets/glass_container.dart';
import 'package:cred_vault/widgets/snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Change the display name.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: context.read<VaultProvider>().profile?.name ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final vault = context.read<VaultProvider>();
    final navigator = Navigator.of(context);
    try {
      await vault.updateName(_name.text);
      if (!mounted) return;
      SnackBarHelper.showSuccess(context, 'Name updated');
      navigator.pop();
    } catch (_) {
      if (mounted) {
        SnackBarHelper.showError(context, "Couldn't update your name.");
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.text.trim().isEmpty
        ? '?'
        : _name.text.trim()[0].toUpperCase();
    return Scaffold(
      appBar: AppBar(title: const Text('Edit name')),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 96,
                          height: 96,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.goldGradient,
                          ),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.background,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      GlassContainer(
                        child: CustomTextField(
                          controller: _name,
                          label: 'Full name',
                          prefixIcon: Icons.badge_outlined,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() {}),
                          validator: (v) =>
                              Validators.required(v, 'Please enter your name'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: 'Save',
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
