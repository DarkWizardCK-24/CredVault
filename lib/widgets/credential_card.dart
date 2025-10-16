import 'package:cred_vault/models/credential_model.dart';
import 'package:cred_vault/providers/credential_provider.dart';
import 'package:cred_vault/screens/add_credential_screen.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/widgets/platform_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'glass_container.dart';
import 'snackbar_helper.dart';

class CredentialCard extends StatefulWidget {
  final CredentialModel credential;
  final VoidCallback onRefresh;

  const CredentialCard({
    super.key,
    required this.credential,
    required this.onRefresh,
  });

  @override
  State<CredentialCard> createState() => _CredentialCardState();
}

class _CredentialCardState extends State<CredentialCard> with SingleTickerProviderStateMixin {
  bool _showPassword = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    SnackBarHelper.showSuccess(context, '$label copied to clipboard');
    _controller.forward().then((_) => _controller.reverse());
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Credential',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete this credential for ${widget.credential.platform}?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final credProvider = Provider.of<CredentialProvider>(
                  context,
                  listen: false,
                );
                final error = await credProvider.deleteCredential(
                  widget.credential.credId,
                );
                if (context.mounted) {
                  if (error == null) {
                    SnackBarHelper.showSuccess(
                      context,
                      'Credential deleted successfully',
                    );
                    widget.onRefresh();
                  } else {
                    SnackBarHelper.showError(context, error);
                  }
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: AppTheme.accentColor),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.edit, color: AppTheme.primaryColor),
                title: const Text(
                  'Edit Credential',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AddCredentialScreen(
                        credential: widget.credential,
                      ),
                    ),
                  );
                  if (result == true) {
                    widget.onRefresh();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: AppTheme.accentColor),
                title: const Text(
                  'Delete Credential',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: PlatformHelper.getColor(widget.credential.platform).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: PlatformHelper.getColor(widget.credential.platform).withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: FaIcon(
                        PlatformHelper.getIcon(widget.credential.platform),
                        color: PlatformHelper.getColor(widget.credential.platform),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.credential.platform,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.credential.credId,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: _showOptionsBottomSheet,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.person_outline,
                label: 'Username',
                value: widget.credential.username,
              ),
              const SizedBox(height: 12),
              _buildPasswordRow(),
              if (widget.credential.url.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildUrlRow(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          color: AppTheme.primaryColor,
          onPressed: () => _copyToClipboard(value, label),
        ),
      ],
    );
  }

  Widget _buildPasswordRow() {
    return Row(
      children: [
        Icon(Icons.lock_outline, color: Colors.white.withOpacity(0.7), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Password',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _showPassword
                    ? widget.credential.password
                    : '•' * widget.credential.password.length,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            _showPassword ? Icons.visibility_off : Icons.visibility,
            size: 18,
          ),
          color: AppTheme.secondaryColor,
          onPressed: () {
            setState(() {
              _showPassword = !_showPassword;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          color: AppTheme.primaryColor,
          onPressed: () => _copyToClipboard(
            widget.credential.password,
            'Password',
          ),
        ),
      ],
    );
  }

  Widget _buildUrlRow() {
    return Row(
      children: [
        Icon(Icons.link, color: Colors.white.withOpacity(0.7), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'URL',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.credential.url,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          color: AppTheme.primaryColor,
          onPressed: () => _copyToClipboard(widget.credential.url, 'URL'),
        ),
      ],
    );
  }
}