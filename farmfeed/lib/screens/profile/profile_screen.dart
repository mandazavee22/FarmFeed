import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/api_client.dart';
import '../../models/user.dart';
import '../../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Shared
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _locationDescCtrl = TextEditingController();
  String? _selectedProvince;

  // Farmer
  final _farmNameCtrl = TextEditingController();
  final _farmSizeCtrl = TextEditingController();
  String? _selectedProductionGoal;
  List<String> _selectedLivestockTypes = [];

  // Supplier
  final _companyNameCtrl = TextEditingController();
  final _businessRegCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _operatingHoursCtrl = TextEditingController();
  bool _deliveryAvailable = false;
  final _deliveryRadiusCtrl = TextEditingController();

  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    _firstNameCtrl.text = user.firstName;
    _lastNameCtrl.text = user.lastName;
    _emailCtrl.text = user.email;
    _phoneCtrl.text = user.phone;
    _cityCtrl.text = user.city;
    _streetCtrl.text = user.streetAddress;
    _locationDescCtrl.text = user.locationDescription ?? '';
    if (AppConstants.zimbabweProvinces.contains(user.province)) {
      _selectedProvince = user.province;
    }

    if (user.isFarmer) {
      _farmNameCtrl.text = user.farmName;
      _farmSizeCtrl.text = (user.profile?['farm_size_ha']?.toString()) ?? '';
      final goal = user.profile?['primary_production_goal'] as String?;
      if (goal != null && AppConstants.productionGoals.contains(goal)) {
        _selectedProductionGoal = goal;
      }
      _selectedLivestockTypes = user.livestockTypes;
    } else if (user.isSupplier) {
      _companyNameCtrl.text = user.companyName;
      _businessRegCtrl.text = user.profile?['business_reg_no'] ?? '';
      _descriptionCtrl.text = user.profile?['description'] ?? '';
      _operatingHoursCtrl.text = user.profile?['operating_hours'] ?? '';
      _deliveryAvailable = user.profile?['delivery_available'] ?? false;
      _deliveryRadiusCtrl.text = (user.profile?['delivery_radius_km']?.toString()) ?? '';
    }

    // Watch for any change
    final controllers = [
      _firstNameCtrl, _lastNameCtrl, _emailCtrl, _phoneCtrl, _cityCtrl, _streetCtrl,
      _locationDescCtrl, _farmNameCtrl, _farmSizeCtrl, _companyNameCtrl,
      _businessRegCtrl, _descriptionCtrl, _operatingHoursCtrl, _deliveryRadiusCtrl,
    ];
    for (final c in controllers) {
      c.addListener(() => setState(() => _hasChanges = true));
    }
  }

  @override
  void dispose() {
    final controllers = [
      _firstNameCtrl, _lastNameCtrl, _emailCtrl, _phoneCtrl, _cityCtrl, _streetCtrl,
      _locationDescCtrl, _farmNameCtrl, _farmSizeCtrl, _companyNameCtrl,
      _businessRegCtrl, _descriptionCtrl, _operatingHoursCtrl, _deliveryRadiusCtrl,
    ];
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = context.read<AuthProvider>().user!;
    final body = <String, dynamic>{
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'province': _selectedProvince,
      'city': _cityCtrl.text.trim(),
      'street_address': _streetCtrl.text.trim(),
      'location_description': _locationDescCtrl.text.trim(),
    };

    if (user.isFarmer) {
      body['farm_name'] = _farmNameCtrl.text.trim();
      final rawSize = _farmSizeCtrl.text.trim();
      if (rawSize.isNotEmpty) {
        body['farm_size_ha'] = double.tryParse(rawSize);
      }
      body['primary_production_goal'] = _selectedProductionGoal;
      body['livestock_types'] = _selectedLivestockTypes;
    } else {
      body['company_name'] = _companyNameCtrl.text.trim();
      body['business_reg_no'] = _businessRegCtrl.text.trim();
      body['description'] = _descriptionCtrl.text.trim();
      body['operating_hours'] = _operatingHoursCtrl.text.trim();
      body['delivery_available'] = _deliveryAvailable;
      final rawRadius = _deliveryRadiusCtrl.text.trim();
      if (rawRadius.isNotEmpty) {
        body['delivery_radius_km'] = double.tryParse(rawRadius);
      }
    }

    try {
      final resp = await ApiClient.instance.updateMe(body);
      if (resp['success'] == true && mounted) {
        final updatedUser = UserModel.fromJson(resp['data']['user']);
        context.read<AuthProvider>().updateUser(updatedUser);
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: FarmColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update, please try again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshProfile() async {
    await context.read<AuthProvider>().loadFromStorage();
    if (mounted) _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return RefreshIndicator(
      color: FarmColors.primaryGreen,
      onRefresh: _refreshProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account Profile',
                style: FarmTextStyles.headlineMedium.copyWith(color: FarmColors.darkGreen)),
            const SizedBox(height: 16),
            // ── Personal Details Card ──────────────────────────────────
                    _FormCard(
                      title: 'Personal Details',
                      icon: Icons.badge_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _Field(
                                controller: _firstNameCtrl,
                                label: 'First Name',
                                validator: (v) =>
                                    (v?.trim().isEmpty ?? true) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _Field(
                                controller: _lastNameCtrl,
                                label: 'Last Name',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _Field(
                          controller: _emailCtrl,
                          label: 'Email Address',
                          enabled: false,
                          icon: Icons.lock_outline,
                        ),
                        const SizedBox(height: 14),
                        _Field(
                          controller: _phoneCtrl,
                          label: 'Phone Number',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]'))],
                          validator: (v) {
                            final val = v?.trim() ?? '';
                            if (val.isEmpty) return null;
                            if (val.length < 9) return 'Enter a valid phone number';
                            return null;
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Role-specific Card ─────────────────────────────────────
                    if (user.isFarmer)
                      _FormCard(
                        title: 'Farm Details',
                        icon: Icons.agriculture_outlined,
                        children: [
                          _Field(
                            controller: _farmNameCtrl,
                            label: 'Farm Name',
                            validator: (v) =>
                                (v?.trim().isEmpty ?? true) ? 'Farm name is required' : null,
                          ),
                          const SizedBox(height: 14),
                          _Field(
                            controller: _farmSizeCtrl,
                            label: 'Farm Size (hectares)',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final d = double.tryParse(v.trim());
                              if (d == null || d < 0) return 'Enter a valid size (≥ 0)';
                              if (d > 500000) return 'Size seems too large';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _selectedProductionGoal,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Primary Production Goal'),
                            items: AppConstants.productionGoals
                                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _selectedProductionGoal = v;
                              _hasChanges = true;
                            }),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Livestock Types',
                                style: FarmTextStyles.bodySmall.copyWith(
                                    color: FarmColors.textSecondary, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: AppConstants.livestockTypes.map((type) {
                              final sel = _selectedLivestockTypes.contains(type);
                              return FilterChip(
                                label: Text(type,
                                    style: FarmTextStyles.bodySmall.copyWith(
                                        color: sel ? FarmColors.darkGreen : FarmColors.textSecondary,
                                        fontSize: 12)),
                                selected: sel,
                                onSelected: (v) => setState(() {
                                  v
                                      ? _selectedLivestockTypes.add(type)
                                      : _selectedLivestockTypes.remove(type);
                                  _hasChanges = true;
                                }),
                                selectedColor: FarmColors.mintFaint,
                                checkmarkColor: FarmColors.primaryGreen,
                                backgroundColor: FarmColors.offWhite,
                                side: BorderSide(
                                    color: sel ? FarmColors.primaryGreen : FarmColors.borderLight),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              );
                            }).toList(),
                          ),
                        ],
                      )
                    else
                      _FormCard(
                        title: 'Company Details',
                        icon: Icons.business_outlined,
                        children: [
                          _Field(
                            controller: _companyNameCtrl,
                            label: 'Company Name',
                            validator: (v) =>
                                (v?.trim().isEmpty ?? true) ? 'Company name is required' : null,
                          ),
                          const SizedBox(height: 14),
                          _Field(
                            controller: _businessRegCtrl,
                            label: 'Business Reg No (optional)',
                          ),
                          const SizedBox(height: 14),
                          _Field(
                            controller: _descriptionCtrl,
                            label: 'What do you supply?',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 14),
                          _Field(
                            controller: _operatingHoursCtrl,
                            label: 'Operating Hours (e.g. Mon-Fri 08:00-17:00)',
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Text('Delivery Available',
                                    style: FarmTextStyles.bodyMedium),
                              ),
                              Switch(
                                value: _deliveryAvailable,
                                activeColor: FarmColors.primaryGreen,
                                onChanged: (v) => setState(() {
                                  _deliveryAvailable = v;
                                  _hasChanges = true;
                                }),
                              ),
                            ],
                          ),
                          if (_deliveryAvailable) ...[
                            const SizedBox(height: 10),
                            _Field(
                              controller: _deliveryRadiusCtrl,
                              label: 'Delivery Radius (km)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                              validator: (v) {
                                if (!_deliveryAvailable) return null;
                                if (v == null || v.trim().isEmpty) return 'Enter radius';
                                final d = double.tryParse(v.trim());
                                if (d == null || d <= 0) return 'Must be > 0';
                                if (d > 1000) return 'Too large (max 1000 km)';
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),

                    const SizedBox(height: 16),

                    // ── Location Card ──────────────────────────────────────────
                    _FormCard(
                      title: 'Location',
                      icon: Icons.location_on_outlined,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedProvince,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Province'),
                          items: AppConstants.zimbabweProvinces
                              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _selectedProvince = v;
                            _hasChanges = true;
                          }),
                        ),
                        const SizedBox(height: 14),
                        _Field(controller: _cityCtrl, label: 'City / Town'),
                        const SizedBox(height: 14),
                        _Field(controller: _streetCtrl, label: 'Street / Area'),
                        const SizedBox(height: 14),
                        _Field(
                          controller: _locationDescCtrl,
                          label: 'Landmarks or Directions (optional)',
                          maxLines: 2,
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Save Button ────────────────────────────────────────────
                    AnimatedOpacity(
                      opacity: _hasChanges ? 1.0 : 0.65,
                      duration: const Duration(milliseconds: 250),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: FarmColors.primaryGreen)
                          : SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _hasChanges ? _updateProfile : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: FarmColors.primaryGreen,
                                  disabledBackgroundColor:
                                      FarmColors.primaryGreen.withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: Text('Save Profile', style: FarmTextStyles.buttonText),
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

// ── Clean Form Card Widget ─────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _FormCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FarmColors.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: FarmColors.mintFaint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 17, color: FarmColors.primaryGreen),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: FarmTextStyles.titleMedium.copyWith(
                        color: FarmColors.darkGreen, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Clean Field Widget ─────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final IconData? icon;
  final bool enabled;

  const _Field({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.icon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      enabled: enabled,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      ),
    );
  }
}
