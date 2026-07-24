import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Load session from storage
    final auth = context.read<AuthProvider>();
    await auth.loadFromStorage();

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    if (auth.isAuthenticated) {
      context.go(auth.user!.isFarmer ? '/farmer' : '/supplier');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: FarmColors.primaryGradient),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo Icon ────────────────────────────────────────────────
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Image.asset(
                      'images/logo.png',
                      width: 70,
                      height: 70,
                      errorBuilder: (_, __, ___) => const Icon(Icons.agriculture, color: Colors.white, size: 54),
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms).scale(
                    begin: const Offset(0.7, 0.7),
                    duration: 700.ms,
                    curve: Curves.easeOutBack),

                const SizedBox(height: 28),

                // ── App Name ─────────────────────────────────────────────────
                Text(
                  AppConstants.appName,
                  style: FarmTextStyles.displayLarge.copyWith(
                    color: FarmColors.white,
                    fontSize: 40,
                    letterSpacing: 1.5,
                  ),
                ).animate(delay: 300.ms).fadeIn(duration: 600.ms).slideY(
                    begin: 0.3,
                    end: 0,
                    duration: 600.ms,
                    curve: Curves.easeOut),

                const SizedBox(height: 10),

                // ── Tagline ───────────────────────────────────────────────────
                Text(
                  AppConstants.appTagline,
                  style: FarmTextStyles.bodyLarge.copyWith(
                    color: FarmColors.sageLight,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ).animate(delay: 500.ms).fadeIn(duration: 600.ms),

                const SizedBox(height: 80),

                // ── Loading Dots ──────────────────────────────────────────────
                _LoadingDots().animate(delay: 700.ms).fadeIn(duration: 500.ms),

              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.33;
            final value = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity =
                (value < 0.5 ? value * 2 : (1 - value) * 2).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: FarmColors.accentLime.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
