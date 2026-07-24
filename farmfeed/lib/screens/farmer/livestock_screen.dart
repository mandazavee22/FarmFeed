import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../widgets/farm_header.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../main.dart';

class LivestockScreen extends StatefulWidget {
  const LivestockScreen({super.key});

  @override
  State<LivestockScreen> createState() => _LivestockScreenState();
}

class _LivestockScreenState extends State<LivestockScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiClient.instance.getLivestock();
      if (resp['success'] == true && mounted) {
        setState(() {
          _records = List<Map<String, dynamic>>.from(resp['data']['livestock']);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddLivestockSheet(),
    ).then((val) {
      if (val == true) _load();
    });
  }

  void _showEditDialog(Map<String, dynamic> record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddLivestockSheet(itemToEdit: record),
    ).then((val) {
      if (val == true) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: FarmColors.offWhite,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.pets, color: FarmColors.primaryGreen, size: 20),
                const SizedBox(width: 8),
                Text('My Livestock Groups',
                    style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.darkGreen)),
                const Spacer(),
                Text('${_records.length} Records',
                    style: FarmTextStyles.bodySmall.copyWith(color: FarmColors.textSecondary)),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen))
                : _records.isEmpty
                    ? _EmptyState(onAdd: _showAddDialog)
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: FarmColors.primaryGreen,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _records.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final r = _records[i];
                            return _LivestockCard(record: r, onDeleted: _load, onEdit: () => _showEditDialog(r))
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
        heroTag: 'livestock_fab',
        onPressed: _showAddDialog,
        backgroundColor: FarmColors.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Records', style: FarmTextStyles.buttonText),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.agriculture_outlined, 
              size: 80, color: FarmColors.textSecondary.withOpacity(0.2)),
          const SizedBox(height: 20),
          Text('No livestock recorded yet',
              style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.textSecondary)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text('Add your animal groups to start optimizing their feed and monitoring production.',
                textAlign: TextAlign.center,
                style: FarmTextStyles.bodySmall.copyWith(color: FarmColors.textSecondary)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: FarmColors.mintFaint,
              foregroundColor: FarmColors.primaryGreen,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add My First Record', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _LivestockCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onDeleted;
  final VoidCallback onEdit;
  const _LivestockCard({required this.record, required this.onDeleted, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final type = record['animal_type'] as String? ?? 'Other';
    final qty = record['herd_size'] ?? 1;
    final weight = record['average_weight_kg'] ?? 0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FarmColors.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: _getColorForType(type),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('$qty x $type',
                                style: FarmTextStyles.titleMedium.copyWith(
                                    color: FarmColors.darkGreen, fontWeight: FontWeight.w800),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Text(record['production_stage'] ?? 'Growing',
                              style: FarmTextStyles.bodySmall.copyWith(
                                  color: FarmColors.primaryGreen, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(record['breed_category'] ?? 'Indigenous',
                          style: FarmTextStyles.bodySmall.copyWith(color: FarmColors.textSecondary)),
                      const Divider(height: 24),
                      Row(
                        children: [
                          _StatItem(label: 'Avg Weight', value: '${weight}kg', icon: Icons.monitor_weight_outlined),
                          const SizedBox(width: 20),
                          _StatItem(label: 'Age', value: '${record['age_in_months']} Mo', icon: Icons.calendar_today_outlined),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Record?'),
        content: const Text('Are you sure you want to remove this livestock group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ApiClient.instance.deleteLivestockRecord(record['id'] as int);
              onDeleted();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getColorForType(String type) {
    if (type.contains('Cattle')) return const Color(0xFF3B82F6);
    if (type.contains('Poultry')) return const Color(0xFFF59E0B);
    if (type.contains('Pig')) return const Color(0xFFEC4899);
    if (type.contains('Goat')) return const Color(0xFF10B981);
    return FarmColors.primaryGreen;
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: FarmColors.textSecondary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: FarmTextStyles.bodySmall.copyWith(fontSize: 10, color: FarmColors.textSecondary)),
            Text(value, style: FarmTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: FarmColors.darkGreen)),
          ],
        ),
      ],
    );
  }
}

class _AddLivestockSheet extends StatefulWidget {
  final Map<String, dynamic>? itemToEdit;
  const _AddLivestockSheet({this.itemToEdit});

  @override
  State<_AddLivestockSheet> createState() => _AddLivestockSheetState();
}

class _AddLivestockSheetState extends State<_AddLivestockSheet> {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = AppConstants.livestockTypes.first;
  String _selectedBreed = 'Indigenous';
  String _selectedStage = 'Growing';
  final _qtyCtrl = TextEditingController(text: '1');
  final _weightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController(text: '1');
  final _freqCtrl = TextEditingController(text: '2');
  final _notesCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  final List<String> _stages = ['Growing', 'Lactating', 'Finishing', 'Starter', 'Layer', 'Breeding'];

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      final i = widget.itemToEdit!;
      if (AppConstants.livestockTypes.contains(i['animal_type'])) _selectedType = i['animal_type'];
      if (['Indigenous', 'Hybrid', 'Exotic'].contains(i['breed_category'])) _selectedBreed = i['breed_category'];
      if (_stages.contains(i['production_stage'])) _selectedStage = i['production_stage'];
      
      _qtyCtrl.text = i['herd_size']?.toString() ?? '1';
      _weightCtrl.text = i['average_weight_kg']?.toString() ?? '';
      _ageCtrl.text = i['age_in_months']?.toString() ?? '1';
      _freqCtrl.text = i['feeding_frequency']?.toString() ?? '2';
      _notesCtrl.text = i['notes'] ?? '';
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    _freqCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = {
        'animal_type': _selectedType,
        'breed_category': _selectedBreed,
        'production_stage': _selectedStage,
        'herd_size': int.parse(_qtyCtrl.text),
        'average_weight_kg': double.parse(_weightCtrl.text),
        'age_in_months': int.parse(_ageCtrl.text),
        'feeding_frequency': int.parse(_freqCtrl.text),
        'notes': _notesCtrl.text,
      };
      
      final isEdit = widget.itemToEdit != null;
      final resp = isEdit 
          ? await ApiClient.instance.updateLivestockRecord(widget.itemToEdit!['id'] as int, payload)
          : await ApiClient.instance.createLivestockRecord(payload);
          
      if (resp['success'] == true && mounted) {
        Navigator.pop(context, true);
      } else if (mounted) {
        setState(() => _error = resp['message'] ?? 'Error saving record');
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
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: ctrl,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: FarmColors.borderLight, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text(widget.itemToEdit != null ? 'Edit Livestock Record' : 'Record New Livestock', style: FarmTextStyles.headlineMedium.copyWith(color: FarmColors.darkGreen)),
              const SizedBox(height: 24),
              
              if (_error != null) _ErrorContainer(message: _error!),
              
              DropdownButtonFormField<String>(
                value: _selectedType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Livestock Type', prefixIcon: Icon(Icons.category_outlined)),
                items: AppConstants.livestockTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedBreed,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Breed Category'),
                      items: ['Indigenous', 'Hybrid', 'Exotic'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _selectedBreed = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedStage,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Prod. Stage'),
                      items: _stages.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _selectedStage = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Herd Size', helperText: 'Number of head'),
                      validator: (v) => (v == null || int.tryParse(v) == null || int.parse(v) <= 0) ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _weightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Avg. Weight (kg)', helperText: 'Per animal'),
                      validator: (v) => (v == null || double.tryParse(v) == null || double.parse(v) <= 0) ? 'Invalid' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                   Expanded(
                    child: TextFormField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age (Months)', helperText: 'Current age'),
                      validator: (v) => (v == null || int.tryParse(v) == null || int.parse(v) <= 0) ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _freqCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Feed Freq', helperText: 'Times/day'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes (Optional)', hintText: 'Health status, batch info...'),
              ),
              const SizedBox(height: 24),
              
              _loading
                  ? const Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen))
                  : ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: Text('Save Livestock Record', style: FarmTextStyles.buttonText),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FarmColors.primaryGreen,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
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
