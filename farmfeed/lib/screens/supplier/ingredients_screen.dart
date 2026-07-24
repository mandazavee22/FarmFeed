import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../widgets/farm_header.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../main.dart';

class IngredientsScreen extends StatefulWidget {
  const IngredientsScreen({super.key});

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  List<Map<String, dynamic>> _ingredients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiClient.instance.getSupplierIngredients();
      if (resp['success'] == true && mounted) {
        setState(() {
          _ingredients = List<Map<String, dynamic>>.from(resp['data']['ingredients']);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: FarmColors.offWhite,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.inventory_2, color: FarmColors.primaryGreen, size: 20),
                const SizedBox(width: 10),
                Text('Stock Management',
                    style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.darkGreen)),
                const Spacer(),
                Text('${_ingredients.length} Items',
                    style: FarmTextStyles.bodySmall.copyWith(color: FarmColors.textSecondary)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen))
                : _ingredients.isEmpty
                    ? _EmptyInventory(onAdd: _showAddSheet)
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: FarmColors.primaryGreen,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _ingredients.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final ing = _ingredients[i];
                            return _IngredientCard(ingredient: ing, onRefresh: _load)
                                .animate()
                                .fadeIn(delay: Duration(milliseconds: 50 * i))
                                .slideX(begin: 0.05);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'ingredients_fab',
        backgroundColor: FarmColors.primaryGreen,
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        label: Text('List New Product', style: FarmTextStyles.buttonText),
        onPressed: _showAddSheet,
      ),
    );
  }

  void _showAddSheet({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddIngredientSheet(existing: existing),
    ).then((val) {
      if (val == true) _load();
    });
  }
}

class _EmptyInventory extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyInventory({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_outlined, size: 80, color: FarmColors.textSecondary.withOpacity(0.2)),
          const SizedBox(height: 20),
          Text('Your warehouse is empty', style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.textSecondary)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text('List your feed ingredients with nutritional data so farmers can start optimizing their rations.',
                textAlign: TextAlign.center, style: FarmTextStyles.bodySmall.copyWith(color: FarmColors.textSecondary)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add My First Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FarmColors.mintFaint,
              foregroundColor: FarmColors.primaryGreen,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  final Map<String, dynamic> ingredient;
  final VoidCallback onRefresh;
  const _IngredientCard({required this.ingredient, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final cp = ingredient['crude_protein_pct'] ?? 0.0;
    final me = ingredient['metabolizable_energy'] ?? 0.0;
    final cost = ingredient['cost_usd_per_kg'] ?? 0.0;
    final stock = ingredient['stock_kg'] ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FarmColors.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: FarmColors.mintFaint, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.grain, color: FarmColors.primaryGreen, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ingredient['name'] ?? '', style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.darkGreen, fontWeight: FontWeight.w700)),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Stock: ${stock}kg',
                                  overflow: TextOverflow.ellipsis,
                                  style: FarmTextStyles.bodySmall.copyWith(color: FarmColors.textSecondary),
                                ),
                              ),
                              if (ingredient['target_livestock_type'] != null) ...[
                                Text(' • ', style: FarmTextStyles.bodySmall),
                                Flexible(
                                  child: Text(
                                    ingredient['target_livestock_type'],
                                    overflow: TextOverflow.ellipsis,
                                    style: FarmTextStyles.bodySmall.copyWith(color: FarmColors.primaryGreen, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text('\$${cost.toStringAsFixed(2)}/kg', style: FarmTextStyles.bodyLarge.copyWith(color: FarmColors.primaryGreen, fontWeight: FontWeight.w800)),
                  ],
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NutrientBadge(label: 'Protein (CP)', value: '$cp%', color: Colors.blueAccent),
                    _NutrientBadge(label: 'Energy (ME)', value: '${me}MJ', color: Colors.orangeAccent),
                    _NutrientBadge(label: 'Fibre (CF)', value: '${ingredient['crude_fibre_pct'] ?? 0}%', color: Colors.greenAccent),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => (context.findAncestorStateOfType<_IngredientsScreenState>())?._showAddSheet(existing: ingredient),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
                style: TextButton.styleFrom(foregroundColor: FarmColors.primaryGreen),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove'),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to remove "${ingredient['name']}" from your inventory?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ApiClient.instance.deleteSupplierIngredient(ingredient['id'] as int);
              onRefresh();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _NutrientBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _NutrientBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.darkGreen, fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: FarmTextStyles.bodySmall.copyWith(fontSize: 10, color: FarmColors.textSecondary)),
      ],
    );
  }
}

class _AddIngredientSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _AddIngredientSheet({this.existing});

  @override
  State<_AddIngredientSheet> createState() => _AddIngredientSheetState();
}

class _AddIngredientSheetState extends State<_AddIngredientSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _cpCtrl;
  late TextEditingController _meCtrl;
  late TextEditingController _cfCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _descCtrl;
  String? _targetLivestock;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?['name']);
    _cpCtrl = TextEditingController(text: e?['crude_protein_pct']?.toString());
    _meCtrl = TextEditingController(text: e?['metabolizable_energy']?.toString());
    _cfCtrl = TextEditingController(text: e?['crude_fibre_pct']?.toString() ?? '0');
    _costCtrl = TextEditingController(text: e?['cost_usd_per_kg']?.toString());
    _stockCtrl = TextEditingController(text: e?['stock_kg']?.toString() ?? '100');
    _descCtrl = TextEditingController(text: e?['description']);
    final existingTarget = e?['target_livestock_type'];
    if (AppConstants.livestockTypes.contains(existingTarget)) {
      _targetLivestock = existingTarget;
    } else {
      _targetLivestock = null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'crude_protein_pct': double.parse(_cpCtrl.text),
        'metabolizable_energy': double.parse(_meCtrl.text),
        'crude_fibre_pct': double.parse(_cfCtrl.text),
        'cost_usd_per_kg': double.parse(_costCtrl.text),
        'stock_kg': double.parse(_stockCtrl.text),
        'description': _descCtrl.text.trim(),
        'target_livestock_type': _targetLivestock,
      };

      final resp = widget.existing != null
          ? await ApiClient.instance.updateSupplierIngredient(widget.existing!['id'], payload)
          : await ApiClient.instance.addSupplierIngredient(payload);

      if (resp['success'] == true && mounted) {
        Navigator.pop(context, true);
      } else {
        setState(() => _error = resp['message'] ?? 'Failed to add ingredient');
      }
    } catch (e) {
      String msg = 'Failed to connect to server';
      if (e is DioException && e.response?.data is Map) {
        msg = e.response?.data['message'] ?? msg;
      }
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: ctrl,
            children: [
               Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: FarmColors.borderLight, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text(widget.existing != null ? 'Edit Feed Product' : 'List New Feed Product', style: FarmTextStyles.headlineMedium.copyWith(color: FarmColors.darkGreen)),
              const SizedBox(height: 24),
              if (_error != null) _ErrorContainer(message: _error!),
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Ingredient Name', hintText: 'e.g. Yellow Maize, Cotton Seed Cake'), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Protein (CP %)', helperText: '% Dry Matter'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final val = double.tryParse(v);
                        if (val == null) return 'Invalid number';
                        if (val < 0 || val > 100) return 'Must be 0-100%';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _meCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Energy (ME MJ/kg)', helperText: 'MJ/kg DM'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final val = double.tryParse(v);
                        if (val == null) return 'Invalid number';
                        if (val < 0 || val > 50) return 'Must be 0-50 MJ';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _targetLivestock,
                decoration: const InputDecoration(labelText: 'Target Breed/Livestock', hintText: 'Who is this for?'),
                items: AppConstants.livestockTypes
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _targetLivestock = val),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cost (USD/kg)', prefixText: '\$'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final val = double.tryParse(v);
                        if (val == null) return 'Invalid number';
                        if (val <= 0) return 'Must be > 0';
                        if (val > 5000) return 'Max \$5,000';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stock (kg)'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final val = double.tryParse(v);
                        if (val == null) return 'Invalid number';
                        if (val < 0) return 'Must be >= 0';
                        if (val > 1000000) return 'Max 1M kg';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cfCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fibre (CF %)', helperText: '% Dry Matter'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final val = double.tryParse(v);
                  if (val == null) return 'Invalid number';
                  if (val < 0 || val > 100) return 'Must be 0-100%';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Product Description (Optional)')),
              const SizedBox(height: 24),
              _loading
                  ? const Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen))
                  : ElevatedButton.icon(
                      onPressed: _submit,
                      icon: Icon(widget.existing != null ? Icons.save : Icons.check_circle_outline, color: Colors.white),
                      label: Text(widget.existing != null ? 'Update Listing' : 'List Product for Farmers', style: FarmTextStyles.buttonText),
                      style: ElevatedButton.styleFrom(backgroundColor: FarmColors.primaryGreen, minimumSize: const Size(double.infinity, 54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorContainer extends StatelessWidget {
  final String message;
  const _ErrorContainer({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
