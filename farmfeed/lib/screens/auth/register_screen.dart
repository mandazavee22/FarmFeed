import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/api_client.dart';
import '../../models/user.dart';
import '../../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();

  // Personal
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  // Role-specific
  final _farmNameCtrl = TextEditingController();
  final _farmSizeCtrl = TextEditingController();
  final _herdSizeCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  final _businessRegCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  // Location
  final _cityCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _locationDescCtrl = TextEditingController();

  String _selectedRole = AppConstants.roleFarmer;
  String? _selectedProvince;
  String? _selectedProductionGoal;
  List<String> _selectedLivestockTypes = [];
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _farmNameCtrl.dispose();
    _farmSizeCtrl.dispose();
    _herdSizeCtrl.dispose();
    _companyNameCtrl.dispose();
    _businessRegCtrl.dispose();
    _descriptionCtrl.dispose();
    _cityCtrl.dispose();
    _streetCtrl.dispose();
    _locationDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      _scrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      return;
    }
    // location and role-specific validations removed to simplify registration

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final body = <String, dynamic>{
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'confirm_password': _confirmPasswordCtrl.text,
      'role': _selectedRole,
    };
    // role-specific data removed. Users complete this inside the app after login.

    try {
      final resp = await ApiClient.instance.register(body);
      if (resp['success'] == true) {
        if (!mounted) return;
        _showSuccessSnack('Account created! Please sign in to continue.');
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
        context.go('/login');
      } else {
        setState(
            () => _errorMessage = resp['message'] ?? 'Registration failed.');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          'Could not connect. Check your network.';
      setState(() => _errorMessage = msg);
    } catch (_) {
      setState(() =>
          _errorMessage = 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: FarmColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmColors.offWhite,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          _RegisterHeader(onBack: () => context.go('/login')),

          // ── Form ──────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Error Banner
                    if (_errorMessage != null) ...[
                      _ErrorBanner(message: _errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    // ── Role Toggle ──────────────────────────────────────────
                    _SectionLabel(
                        icon: Icons.people_alt_outlined, label: 'I am a...'),
                    const SizedBox(height: 10),
                    _RoleToggle(
                      selected: _selectedRole,
                      onChanged: (r) => setState(() => _selectedRole = r),
                    ),

                    const SizedBox(height: 24),

                    // ── Personal Details ─────────────────────────────────────
                    _SectionLabel(
                        icon: Icons.person_outline, label: 'Personal Details'),
                    const SizedBox(height: 12),

                    Row(children: [
                      Expanded(
                        child: _FormField(
                          controller: _firstNameCtrl,
                          label: 'First Name',
                          hint: 'Tendai',
                          icon: Icons.badge_outlined,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FormField(
                          controller: _lastNameCtrl,
                          label: 'Last Name',
                          hint: 'Moyo',
                          icon: Icons.badge_outlined,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    _FormField(
                      controller: _emailCtrl,
                      label: 'Email Address',
                      hint: 'tendai@example.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Email is required.';
                        if (!v.contains('@') || !v.contains('.'))
                          return 'Invalid email.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    _FormField(
                      controller: _phoneCtrl,
                      label: 'Phone Number',
                      hint: '0771234567',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[\d+\s\-()]'))
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Phone is required.';
                        if (v.trim().length < 9)
                          return 'Enter a valid phone number.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    _PasswordField(
                      controller: _passwordCtrl,
                      label: 'Password',
                      obscure: _obscurePassword,
                      onToggle: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Password is required.';
                        if (v.length < 8) return 'Minimum 8 characters.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    _PasswordField(
                      controller: _confirmPasswordCtrl,
                      label: 'Confirm Password',
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: (v) {
                        if (v != _passwordCtrl.text)
                          return 'Passwords do not match.';
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    const SizedBox(height: 32),

                    // ── Submit Button ─────────────────────────────────────────
                    _isLoading
                        ? _LoadingButton()
                        : ElevatedButton(
                            onPressed: _register,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(double.infinity, 54),
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
                                height: 54,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.how_to_reg_outlined,
                                        color: Colors.white),
                                    const SizedBox(width: 10),
                                    Text('Create Account',
                                        style: FarmTextStyles.buttonText),
                                  ],
                                ),
                              ),
                            ),
                          ),

                    const SizedBox(height: 16),

                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/login'),
                        child: RichText(
                          text: TextSpan(
                            text: 'Already have an account? ',
                            style: FarmTextStyles.bodySmall,
                            children: [
                              TextSpan(
                                text: 'Sign In',
                                style: FarmTextStyles.bodySmall.copyWith(
                                  color: FarmColors.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Register Header ────────────────────────────────────────────────────────────
class _RegisterHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _RegisterHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: FarmColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 24, 20),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                onPressed: onBack,
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create Account',
                      style: FarmTextStyles.headlineMedium
                          .copyWith(color: Colors.white)),
                  Text('Join FarmFeed today',
                      style: FarmTextStyles.bodySmall
                          .copyWith(color: FarmColors.sageLight)),
                ],
              ),
              const Spacer(),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Image.asset(
                    'images/logo.png',
                    height: 32,
                    width: 32,
                    errorBuilder: (_, __, ___) => const Icon(Icons.agriculture, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Role Toggle ────────────────────────────────────────────────────────────────
class _RoleToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _RoleToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FarmColors.mintFaint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FarmColors.borderLight),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _RoleOption(
            label: 'Farmer',
            icon: Icons.agriculture_outlined,
            isSelected: selected == AppConstants.roleFarmer,
            onTap: () => onChanged(AppConstants.roleFarmer),
          ),
          _RoleOption(
            label: 'Supplier',
            icon: Icons.storefront_outlined,
            isSelected: selected == AppConstants.roleSupplier,
            onTap: () => onChanged(AppConstants.roleSupplier),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _RoleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? FarmColors.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: FarmColors.primaryGreen.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected ? Colors.white : FarmColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: FarmTextStyles.titleMedium.copyWith(
                  color: isSelected ? Colors.white : FarmColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Livestock Multi-Select Chips ───────────────────────────────────────────────
class _LivestockChips extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  const _LivestockChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConstants.livestockTypes.map((type) {
        final isSelected = selected.contains(type);
        return GestureDetector(
          onTap: () {
            final updated = List<String>.from(selected);
            isSelected ? updated.remove(type) : updated.add(type);
            onChanged(updated);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? FarmColors.primaryGreen : FarmColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? FarmColors.primaryGreen
                    : FarmColors.borderLight,
                width: 1.3,
              ),
            ),
            child: Text(
              type,
              style: FarmTextStyles.bodySmall.copyWith(
                color: isSelected ? Colors.white : FarmColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: FarmColors.primaryGreen),
        const SizedBox(width: 8),
        Text(label,
            style: FarmTextStyles.titleLarge
                .copyWith(color: FarmColors.primaryGreen)),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: '••••••••',
        prefixIcon: const Icon(Icons.lock_outlined),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: FarmColors.mediumGreen,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      hint: Text('Select...', style: FarmTextStyles.bodySmall),
      items: items
          .map((item) =>
              DropdownMenuItem<T>(value: item, child: Text(item.toString())))
          .toList(),
      onChanged: onChanged,
      style: FarmTextStyles.bodyLarge.copyWith(color: FarmColors.textPrimary),
      icon:
          const Icon(Icons.keyboard_arrow_down, color: FarmColors.mediumGreen),
      isExpanded: true,
      dropdownColor: FarmColors.white,
    );
  }
}

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

class _LoadingButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: FarmColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child:
              CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
        ),
      ),
    );
  }
}
