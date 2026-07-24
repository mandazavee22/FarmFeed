import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/api_client.dart';
import '../../models/user.dart';
import '../../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resp = await ApiClient.instance.login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      if (resp['success'] == true) {
        final token = resp['data']['token'] as String;
        final user = UserModel.fromJson(resp['data']['user']);
        if (!mounted) return;
        await context.read<AuthProvider>().setSession(token, user);
        if (!mounted) return;
        context.go(user.isFarmer ? '/farmer' : '/supplier');
      } else {
        setState(() => _errorMessage = resp['message'] ?? 'Login failed.');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          'Could not connect to server. Check your network.';
      setState(() => _errorMessage = msg);
    } catch (e) {
      setState(() => _errorMessage = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Curved Green Header ───────────────────────────────────────────
          _GreenHeader(),

          // ── Scrollable Form ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),

                  Text('Sign in to FarmFeed',
                          style: FarmTextStyles.headlineLarge)
                      .animate(delay: 80.ms)
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: -0.1),

                  const SizedBox(height: 28),

                  // Error Banner
                  if (_errorMessage != null) ...[
                    _ErrorBanner(message: _errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'your@email.com',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Email is required.';
                            if (!v.contains('@')) return 'Enter a valid email.';
                            return null;
                          },
                        )
                            .animate(delay: 150.ms)
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.1),

                        const SizedBox(height: 16),

                        // Password
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: FarmColors.mediumGreen,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Password is required.';
                            return null;
                          },
                        )
                            .animate(delay: 220.ms)
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.1),

                        const SizedBox(height: 28),

                        // Login Button
                        _isLoading
                            ? _LoadingButton()
                            : ElevatedButton(
                                onPressed: _login,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(double.infinity, 52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: FarmColors.cardGradient,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    height: 52,
                                    child: Text('Sign In',
                                        style: FarmTextStyles.buttonText),
                                  ),
                                ),
                              )
                                .animate(delay: 300.ms)
                                .fadeIn(duration: 400.ms)
                                .slideY(begin: 0.1),

                        const SizedBox(height: 20),

                        // Divider
                        Row(children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: FarmTextStyles.bodySmall),
                          ),
                          const Expanded(child: Divider()),
                        ]).animate(delay: 380.ms).fadeIn(),

                        const SizedBox(height: 20),

                        // Register link
                        OutlinedButton(
                          onPressed: () => context.go('/register'),
                          child: Text(
                            'Create a FarmFeed Account',
                            style: FarmTextStyles.buttonText
                                .copyWith(color: FarmColors.primaryGreen),
                          ),
                        ).animate(delay: 420.ms).fadeIn(duration: 400.ms),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Curved Green Header Widget ─────────────────────────────────────────────────
class _GreenHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _BottomCurveClipper(),
      child: Container(
        height: 210,
        decoration: const BoxDecoration(gradient: FarmColors.primaryGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Image.asset(
                      'images/logo.png',
                      height: 38,
                      width: 38,
                      errorBuilder: (_, __, ___) => const Icon(Icons.agriculture, color: Colors.white, size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: FarmTextStyles.headlineLarge.copyWith(
                        color: FarmColors.white,
                        fontSize: 24,
                      ),
                    ),
                    Text(
                      AppConstants.appTagline,
                      style: FarmTextStyles.bodySmall.copyWith(
                        color: FarmColors.sageLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
        size.width / 2, size.height + 20, size.width, size.height - 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_) => false;
}

// ── Error Banner ───────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FarmColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FarmColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: FarmColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: FarmTextStyles.bodySmall
                    .copyWith(color: FarmColors.error, fontSize: 13)),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .shake(hz: 2, offset: const Offset(4, 0));
  }
}

// ── Loading Button ─────────────────────────────────────────────────────────────
class _LoadingButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: FarmColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}
