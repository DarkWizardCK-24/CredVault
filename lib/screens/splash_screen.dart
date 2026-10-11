import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/widgets/app_logo.dart';
import 'package:cred_vault/widgets/glass_container.dart';
import 'package:flutter/material.dart';

/// Shown while the app works out whether someone is signed in.
class SplashScreen extends StatelessWidget {
  final String? message;

  const SplashScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 128, glow: AppTheme.gold),
              const SizedBox(height: 28),
              const BrandName(size: 38),
              const SizedBox(height: 8),
              Text(
                message ?? 'Your zero-knowledge password vault',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "CredVault" in a white-to-gold gradient.
class BrandName extends StatelessWidget {
  final double size;

  const BrandName({super.key, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Colors.white, AppTheme.goldLight],
      ).createShader(bounds),
      child: Text(
        'CredVault',
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
