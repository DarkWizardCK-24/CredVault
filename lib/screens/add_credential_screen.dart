import 'package:cred_vault/models/credential_model.dart';
import 'package:cred_vault/providers/auth_provider.dart';
import 'package:cred_vault/providers/credential_provider.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/widgets/custom_button.dart';
import 'package:cred_vault/widgets/custom_text_field.dart';
import 'package:cred_vault/widgets/glass_container.dart';
import 'package:cred_vault/widgets/platform_data.dart';
import 'package:cred_vault/widgets/snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddCredentialScreen extends StatefulWidget {
  final CredentialModel? credential;

  const AddCredentialScreen({super.key, this.credential});

  @override
  State<AddCredentialScreen> createState() => _AddCredentialScreenState();
}

class _AddCredentialScreenState extends State<AddCredentialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();

  String _selectedPlatform = 'Instagram';
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.credential != null) {
      _usernameController.text = widget.credential!.username;
      _passwordController.text = widget.credential!.password;
      _urlController.text = widget.credential!.url;
      _selectedPlatform = widget.credential!.platform;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final credProvider = Provider.of<CredentialProvider>(
      context,
      listen: false,
    );

    String? error;

    if (widget.credential == null) {
      error = await credProvider.addCredential(
        userId: authProvider.userModel!.userId,
        platform: _selectedPlatform,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        url: _urlController.text.trim(),
      );
    } else {
      error = await credProvider.updateCredential(
        credId: widget.credential!.credId,
        platform: _selectedPlatform,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        url: _urlController.text.trim(),
      );
    }

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (error == null) {
      SnackBarHelper.showSuccess(
        context,
        widget.credential == null ? 'Credential added!' : 'Credential updated!',
      );
      Navigator.of(context).pop(true);
    } else {
      SnackBarHelper.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.credential == null ? 'Add Credential' : 'Edit Credential',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundColor,
              AppTheme.surfaceColor,
              AppTheme.primaryColor.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Platform',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedPlatform,
                              isExpanded: true,
                              dropdownColor: AppTheme.surfaceColor,
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              items: PlatformHelper.getPlatformNames().map((
                                String platform,
                              ) {
                                final platformData =
                                    PlatformHelper.getPlatformData(platform);
                                return DropdownMenuItem<String>(
                                  value: platform,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: platformData.color.withOpacity(
                                            0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          platformData.icon,
                                          color: platformData.color,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(platform),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedPlatform = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassContainer(
                    child: Column(
                      children: [
                        CustomTextField(
                          controller: _usernameController,
                          label: 'Username / Email',
                          prefixIcon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter username or email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _passwordController,
                          label: 'Password',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _urlController,
                          label: 'URL (Optional)',
                          prefixIcon: Icons.link,
                          keyboardType: TextInputType.url,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    text: widget.credential == null
                        ? 'Add Credential'
                        : 'Update Credential',
                    onPressed: _isLoading ? null : _handleSave,
                    isLoading: _isLoading,
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
