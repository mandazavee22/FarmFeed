import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../widgets/farm_header.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../main.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _livestock = [];
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _marketIngredients = [];
  int? _selectedLivestockId;
  String? _selectedIngredientId;
  Map<String, dynamic>? _results;
  Map<String, dynamic>? _prediction;
  Map<String, dynamic>? _simulation;
  String? _formulationError;
  
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _bids = [];
  bool _loadingSuppliers = true;
  
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;
  String? _chartAnimalFilter;
  
  bool _loading = true;
  bool _solving = false;
  bool _simulating = false;
  bool _procuring = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {}); // Rebuild to toggle FAB visibility
      // Fetch fresh data when user lands on a new tab
      if (!_tabController.indexIsChanging) {
        _init(silent: true);
      }
    });
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    
    try {
      final lvResp = await ApiClient.instance.getLivestock();
      final invResp = await ApiClient.instance.getFarmerInventory();
      final histResp = await ApiClient.instance.getFarmerHistory();
      final marketResp = await ApiClient.instance.getMarketIngredients();
      final supplierResp = await ApiClient.instance.getAllSuppliers();
      final bidResp = await ApiClient.instance.getBids();
      
      if (mounted) {
        setState(() {
          if (lvResp['success']) _livestock = List<Map<String, dynamic>>.from(lvResp['data']['livestock']);
          if (invResp['success']) _inventory = List<Map<String, dynamic>>.from(invResp['data']['inventory']);
          if (marketResp['success']) _marketIngredients = List<Map<String, dynamic>>.from(marketResp['data']['ingredients']);
          if (supplierResp['success']) _suppliers = List<Map<String, dynamic>>.from(supplierResp['data']['suppliers']);
          if (bidResp['success']) _bids = List<Map<String, dynamic>>.from(bidResp['data']['bids']);
          
          if (histResp['success']) {
             _history = List<Map<String, dynamic>>.from(histResp['data']['history']);
          }
          
          _loadingHistory = false;
          
          // Ensure selected ID still exists in the new list
          if (_selectedLivestockId != null) {
            bool exists = _livestock.any((l) => l['id'] == _selectedLivestockId);
            if (!exists) {
              _selectedLivestockId = null;
               _selectedIngredientId = null;
            }
          }
          
          if (!silent) _loading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _optimize() async {
    if (_selectedLivestockId == null || _selectedIngredientId == null) return;
    
    setState(() {
      _solving = true;
      _results = null;
      _prediction = null;
      _simulation = null;
      _formulationError = null;
    });

    try {
      // Send the full composite ID (e.g., 'inv_1' or 'mkt_3') to the backend
      final res = await ApiClient.instance.optimizeFeed(_selectedLivestockId!, [_selectedIngredientId!]);
      if (res['success'] && mounted) {
        setState(() {
          _results = res['data'];
          _solving = false;
          _formulationError = null;
        });
        
        // Auto-predict performance
        try {
          final pred = await ApiClient.instance.predictPerformance(res['data']['formulation']['id']);
          if (pred['success'] && mounted) {
            setState(() => _prediction = pred['data']['analysis']);
          }
        } catch (e) {
          debugPrint('ML Prediction quiet failure: $e');
        }
      } else {
        setState(() {
          _solving = false;
          _formulationError = res['message'] ?? 'Optimization failed';
        });
      }
    } catch (e) {
      String msg = 'Failed to connect to server';
      if (e is DioException && e.response?.data is Map) {
        msg = e.response?.data['message'] ?? msg;
      }
      if (mounted) setState(() {
        _solving = false;
        _formulationError = msg;
      });
    }
  }

  Future<void> _runSimulation() async {
    if (_results == null) return;
    setState(() => _simulating = true);
    try {
      final sim = await ApiClient.instance.simulateScenarios(_results!['formulation']['id']);
      if (sim['success'] && mounted) {
        setState(() => _simulation = sim['data']['simulation']);
      }
    } catch (e) {
      String msg = 'Simulation failed';
      if (e is DioException && e.response?.data is Map) {
        msg = e.response?.data['message'] ?? msg;
      }
      _showError(msg);
    } finally {
      if (mounted) setState(() {
        _simulating = false;
        _solving = false; // Cleanup both
      });
    }
  }

  Future<void> _procure() async {
    if (_results == null || _procuring) return;
    setState(() => _procuring = true);
    try {
      final resp = await ApiClient.instance.initiateProcurement(_results!['formulation']['id']);
      if (resp['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resp['message']),
            backgroundColor: FarmColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      String msg = 'Failed to initiate procurement';
      if (e is DioException && e.response?.data is Map) {
        msg = e.response?.data['message'] ?? msg;
      }
      _showError(msg);
    } finally {
      if (mounted) setState(() => _procuring = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: FarmColors.offWhite,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 0,
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: FarmColors.primaryGreen,
            unselectedLabelColor: FarmColors.textSecondary,
            indicatorColor: FarmColors.primaryGreen,
            indicatorWeight: 3,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: const [
              Tab(text: 'OPTIMIZE', icon: Icon(Icons.analytics_outlined)),
              Tab(text: 'MY STOCKS', icon: Icon(Icons.inventory_2_outlined)),
              Tab(text: 'SUPPLIERS', icon: Icon(Icons.storefront_outlined)),
              Tab(text: 'HISTORY', icon: Icon(Icons.history)),
              Tab(text: 'CHARTS', icon: Icon(Icons.bar_chart)),
            ],
          ),
        ),
        body: _loading 
          ? const Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen))
          : SafeArea(
              bottom: true,
              child: TabBarView(
                controller: _tabController,
                children: [
                  RefreshIndicator(
                    onRefresh: () => _init(silent: true),
                    color: FarmColors.primaryGreen,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSelector(),
                          const SizedBox(height: 20),
                          if (_selectedLivestockId != null && _selectedIngredientId != null && _results == null && !_solving && _formulationError == null)
                            _buildEmptyResults(),
                          if (_solving)
                            _buildSolvingState(),
                          if (_formulationError != null)
                            _buildErrorCard(),
                          if (_results != null) ...[
                            _buildFormulationCard(),
                            const SizedBox(height: 16),
                            if (_prediction != null) 
                              _buildPredictionCard().animate().fadeIn().slideY(begin: 0.1),
                            const SizedBox(height: 16),
                            if (_simulation == null && !_simulating)
                              _buildSimulateButton()
                            else if (_simulating && _simulation == null)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 30),
                                child: Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen)),
                              )
                            else if (_simulation != null)
                              _buildSimulationCard(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  RefreshIndicator(onRefresh: () => _init(silent: true), color: FarmColors.primaryGreen, child: _buildInventoryTab()),
                  RefreshIndicator(onRefresh: () => _init(silent: true), color: FarmColors.primaryGreen, child: _buildSuppliersTab()),
                  RefreshIndicator(onRefresh: () => _init(silent: true), color: FarmColors.primaryGreen, child: _buildHistoryTab()),
                  RefreshIndicator(onRefresh: () => _init(silent: true), color: FarmColors.primaryGreen, child: _buildChartsTab()),
                ],
              ),
            ),
        floatingActionButton: _tabController.index == 1 ? FloatingActionButton(
          heroTag: 'add_inv_fab',
          onPressed: _showAddStockSheet,
          backgroundColor: FarmColors.primaryGreen,
          child: const Icon(Icons.add, color: Colors.white),
        ) : null,
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded, size: 48, color: Colors.red.shade700),
          const SizedBox(height: 16),
          Text(
            'Infeasible Formulation',
            style: FarmTextStyles.titleMedium.copyWith(color: Colors.red.shade900, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _formulationError ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: FarmTextStyles.bodySmall.copyWith(color: Colors.red.shade800, height: 1.5),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _formulationError = null;
                _results = null;
              });
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.red.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Reset Analysis', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildSelector() {
    final selectedLivestock = _livestock.firstWhere((l) => l['id'] == _selectedLivestockId, orElse: () => {});
    final selectedAnimalType = selectedLivestock.isNotEmpty ? selectedLivestock['animal_type']?.toString() : null;

    // Filter inventory to only match the selected livestock's animal type
    final filteredInventory = selectedAnimalType != null
        ? _inventory.where((i) => i['target_livestock_type'] == selectedAnimalType).toList()
        : <Map<String, dynamic>>[];

    final filteredMarket = selectedAnimalType != null
        ? _marketIngredients.where((i) {
            final target = i['target_livestock_type'];
            if (target == null) return true;
            if (target == selectedAnimalType) return true;
            // Support generic poultry matching
            if (selectedAnimalType!.startsWith('Poultry') && target == 'Poultry') return true;
            // Support generic cattle matching
            if (selectedAnimalType!.startsWith('Cattle') && target == 'Cattle') return true;
            return false;
          }).toList()
        : <Map<String, dynamic>>[];

    // Build the items list and ensure uniqueness to prevent "mkt_3" duplicate errors
    final List<Map<String, dynamic>> rawCombined = [
      ...filteredInventory.map((i) => {'cid': 'inv_${i['id']}', 'name': '${i['name']} (My Stock)'}),
      ...filteredMarket.map((i) => {'cid': 'mkt_${i['id']}', 'name': '${i['name']} (Market: ${i['supplier_name']})'}),
    ];

    final Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var item in rawCombined) {
      uniqueMap[item['cid']!] = item;
    }
    final combinedDropdownItems = uniqueMap.values.toList();

    // Reset selection if ingredient no longer exists in filtered list
    if (_selectedIngredientId != null && !combinedDropdownItems.any((item) => item['cid'] == _selectedIngredientId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIngredientId = null);
      });
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FarmColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configure Analysis', style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.darkGreen)),
          const SizedBox(height: 16),
          
          // 1. Livestock Selection
          DropdownButtonFormField<int>(
            value: _selectedLivestockId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Livestock Group',
              prefixIcon: Icon(Icons.pets_outlined),
            ),
            items: _livestock.map((l) => DropdownMenuItem<int>(
              value: l['id'],
              child: Text('${l['animal_type']} - ${l['production_stage']}'),
            )).toList(),
            onChanged: (v) => setState(() {
              _selectedLivestockId = v;
              _selectedIngredientId = null;
              _results = null;
              _prediction = null;
              _simulation = null;
            }),
          ),

          // 2. Ingredient Package Selection (filtered by livestock type)
          if (_selectedLivestockId != null) ...[
            const SizedBox(height: 16),
            if (combinedDropdownItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'No matching ingredients found in your stocks or the marketplace for $selectedAnimalType.',
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.w500),
                    )),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedIngredientId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select Ingredient Source',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: combinedDropdownItems.map((item) => DropdownMenuItem<String>(
                  value: item['cid'] as String,
                  child: Text(item['name'] as String),
                )).toList(),
                onChanged: (v) => setState(() {
                  _selectedIngredientId = v;
                  _results = null;
                  _prediction = null;
                  _simulation = null;
                }),
              ),

            if (_selectedIngredientId != null) ...[
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _optimize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FarmColors.primaryGreen,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Generate Optimal Mix', style: FarmTextStyles.buttonText),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyResults() {
    final selected = _livestock.firstWhere((l) => l['id'] == _selectedLivestockId, orElse: () => {});
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.science_outlined, size: 64, color: FarmColors.textSecondary.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('Ready to Analyze', style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.textSecondary)),
            Text('Formulate feed for ${selected['animal_type'] ?? 'selected group'}.', textAlign: TextAlign.center, style: FarmTextStyles.bodySmall.copyWith(color: FarmColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSolvingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const CircularProgressIndicator(color: FarmColors.primaryGreen),
            const SizedBox(height: 20),
            Text('Solving Linear Programming Model...', style: FarmTextStyles.bodyMedium),
            Text('Optimizing for cost & nutritional adequacy', style: FarmTextStyles.bodySmall.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulationCard() {
    final formulation = _results?['formulation'];
    if (formulation == null) return const SizedBox.shrink();

    // Backend to_dict() returns 'ingredients' (List) and 'nutrient_summary' (Map) already parsed
    final List items = formulation['ingredients'] is List 
        ? formulation['ingredients']
        : (formulation['ingredients_json'] != null ? json.decode(formulation['ingredients_json']) : []);
    final Map nutrients = formulation['nutrient_summary'] is Map 
        ? formulation['nutrient_summary']
        : (formulation['nutrient_summary_json'] != null ? json.decode(formulation['nutrient_summary_json']) : {});
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FarmColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: FarmColors.mintFaint,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate_outlined, color: FarmColors.primaryGreen),
                const SizedBox(width: 10),
                Expanded(child: Text('Least-Cost Ration Result', style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.darkGreen))),
                Text('\$${(formulation['total_cost_usd'] ?? 0.0).toStringAsFixed(3)}/kg', 
                   style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.primaryGreen, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily Mix Requirements (Batch for ${_results?['daily_requirement_kg'] ?? 0}kg)', 
                  style: FarmTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: FarmColors.primaryGreen)),
                const SizedBox(height: 10),
                ...items.map((i) {
                  final double batchKg = (i['kg_per_unit'] ?? 0.0) * (_results?['daily_requirement_kg'] ?? 1.0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 14, color: FarmColors.primaryGreen),
                        const SizedBox(width: 8),
                        Expanded(child: Text(i['name'] ?? 'Ingredient', style: FarmTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500))),
                        Text('${batchKg.toStringAsFixed(2)} kg', style: FarmTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w900, color: FarmColors.darkGreen)),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Metric(
                      label: 'Crude Protein', 
                      value: '${nutrients['crude_protein_pct'] ?? 0}% (${((nutrients['crude_protein_pct'] ?? 0) / 100 * (_results?['daily_requirement_kg'] ?? 0)).toStringAsFixed(2)}kg)'
                    ),
                    _Metric(
                      label: 'Energy Density', 
                      value: '${(nutrients['metabolizable_energy'] ?? 0).toStringAsFixed(1)} MJ/kg'
                    ),
                    _Metric(
                      label: 'Total Demand', 
                      value: '${_results?['daily_requirement_kg'] ?? 0}kg'
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ).animate().fadeIn().slideY(begin: 0.1),
    );
  }

  Widget _buildPredictionCard() {
    final status = _prediction!['status'];
    final eff = _prediction!['production_efficiency'];
    final label = _prediction!['label'];
    final value = _prediction!['value'];
    final perf = _prediction!['metrics'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FarmColors.primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Text('ML Production Analysis', style: FarmTextStyles.titleMedium.copyWith(color: Colors.blue.shade900)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: FarmTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value, style: FarmTextStyles.headlineMedium.copyWith(color: FarmColors.primaryGreen, fontSize: 28)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_prediction!['lifecycle_status'] != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red),
                          const SizedBox(width: 4),
                          Text('Stage Alert', style: TextStyle(color: Colors.red.shade900, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: status == 'Optimal' ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          if (_prediction!['lifecycle_status'] != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(_prediction!['lifecycle_status'], style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 14),
          Text(_prediction!['insight'] ?? '', style: FarmTextStyles.bodySmall.copyWith(fontStyle: FontStyle.italic)),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.settings_suggest_outlined, size: 14, color: FarmColors.textSecondary),
              const SizedBox(width: 8),
              Text('Model Performance: MAE ${perf['mae']} | R² ${perf['r2']}', 
                  style: FarmTextStyles.bodySmall.copyWith(fontSize: 10, color: FarmColors.textSecondary)),
            ],
          ),
        ],
      ).animate().fadeIn(delay: 200.ms),
    );
  }

  Widget _buildSimulateButton() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _simulating ? null : _runSimulation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade800,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _simulating 
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simulate Risk', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _procuring ? null : _getProcurementAdvice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FarmColors.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _procuring 
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Procure All', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Synchronise with suppliers based on demand & stock efficiency', 
           style: FarmTextStyles.bodySmall.copyWith(fontSize: 10, color: FarmColors.textSecondary)),
      ],
    );
  }

  Widget _buildSimulationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [FarmColors.darkGreen, Colors.black87], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shuffle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Monte Carlo Simulation Results', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          Text('Simulated Outcomes (N=500)', style: TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SimStat(label: 'Avg Cost/kg', value: '\$${_simulation!['expected_cost_mean']}'),
              _SimStat(label: 'Profitability Risk', value: '${_simulation!['profitability_risk']}'),
              _SimStat(label: 'Best Case', value: '\$${_simulation!['best_case_cost']}'),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          Text('95% Confidence Interval: \$${_simulation!['cost_95_ci'][0]} - \$${_simulation!['cost_95_ci'][1]}', style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ).animate().scale(delay: 100.ms),
    );
  }

  Widget _buildInventoryTab() {
    if (_inventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: FarmColors.textSecondary.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('No Inventory Yet', style: FarmTextStyles.titleMedium),
            Text('Add ingredients you have on hand to include them in optimization.', style: FarmTextStyles.bodySmall),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddStockSheet,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add My First Ingredient'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FarmColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _inventory.length,
      itemBuilder: (context, index) {
        final item = _inventory[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: FarmColors.mintFaint,
              child: Icon(Icons.grain, color: FarmColors.primaryGreen),
            ),
            title: Text(item['name'], style: FarmTextStyles.titleMedium),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Protein: ${item['crude_protein_pct']}% | Energy: ${item['metabolizable_energy']}MJ', style: FarmTextStyles.bodySmall),
                Text('Stock: ${item['stock_kg']}kg | Price Paid: \$${item['cost_paid_usd_per_kg']}/kg', style: FarmTextStyles.bodySmall.copyWith(color: FarmColors.primaryGreen)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                  onPressed: () => _showEditStockSheet(item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteInventory(item['id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteInventory(int id) async {
    try {
      await ApiClient.instance.deleteFarmerInventory(id);
      _init(); // Refresh
    } catch (_) {
      _showError('Failed to delete item');
    }
  }

  void _showAddStockSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddInventorySheet(),
    ).then((val) {
      if (val == true) _init();
    });
  }

  void _showEditStockSheet(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddInventorySheet(itemToEdit: item),
    ).then((val) {
      if (val == true) _init();
    });
  }


  Widget _buildSuppliersTab() {
    if (_suppliers.isEmpty && _bids.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: 80, color: FarmColors.textSecondary.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('No Suppliers Found', style: FarmTextStyles.titleMedium),
            Text('Registered suppliers will appear here.', style: FarmTextStyles.bodySmall),
          ],
        ),
      );
    }

    // Group bids by procurement_request_id (robustly handle types)
    final Map<int, List<Map<String, dynamic>>> groupedBids = {};
    for (var b in _bids) {
      final rawId = b['procurement_request_id'];
      if (rawId == null) continue;
      final int reqId = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
      if (reqId == 0) continue;
      
      if (!groupedBids.containsKey(reqId)) groupedBids[reqId] = [];
      groupedBids[reqId]!.add(b);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (groupedBids.isNotEmpty) ...[
          Text('MARKET DISPATCH BIDS', style: FarmTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold, color: FarmColors.primaryGreen, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          ...groupedBids.entries.map((entry) {
            final requestId = entry.key;
            final bidsForRequest = entry.value;
            // Use the first bid to get request info (name, qty)
            final firstBid = bidsForRequest.first;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRequestGroupHeader(firstBid, requestId),
                const SizedBox(height: 12),
                ...bidsForRequest.map((bid) => _buildBidCard(bid)),
                const SizedBox(height: 32),
              ],
            );
          }),
        ],
        
        Text('REGISTERED SUPPLIERS', style: FarmTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold, color: FarmColors.darkGreen, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        ..._suppliers.map((s) => _buildSupplierCard(s)),
      ],
    );
  }
  Widget _buildBidCard(Map<String, dynamic> bid) {
    final double matchScore = (bid['match_score'] ?? 0.0).toDouble();
    final String status = bid['status'] ?? 'pending';
    
    Color rankColor = Colors.grey;
    if (matchScore > 94) rankColor = FarmColors.primaryGreen;
    else if (matchScore > 85) rankColor = Colors.blueAccent;
    else if (matchScore > 75) rankColor = Colors.orangeAccent;

    // Determine custom ranking tag if not already set or override
    String effectiveTag = bid['rank_tag'] ?? 'Alternative';
    if (matchScore > 94 && (bid['price_score_pct'] ?? 0) > 90) effectiveTag = "🏆 BEST DEAL";
    else if (matchScore > 94) effectiveTag = "🎖️ TOP MATCH";
    else if (bid['price_score_pct'] != null && bid['price_score_pct'] > 95) effectiveTag = "💎 BEST VALUE";

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: status == 'accepted' ? FarmColors.primaryGreen : rankColor.withOpacity(0.2), width: 2),
      ),
      elevation: 8,
      shadowColor: rankColor.withOpacity(0.1),
      child: Column(
        children: [
          if (status == 'accepted')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                color: FarmColors.primaryGreen,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: const Center(
                child: Text('BID ACCEPTED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CircularScore(score: matchScore, color: rankColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bid['supplier_name'] ?? 'Supplier', style: FarmTextStyles.titleMedium.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: rankColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                            child: Text(effectiveTag.toUpperCase(), style: TextStyle(color: rankColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          ),
                        ],
                      ),
                    ),
                    if (status == 'pending')
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        onSelected: (val) {
                          if (val == 'reject') _rejectBid(bid);
                          if (val == 'analyze') _analyzeBid(bid);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'analyze', child: Row(children: [Icon(Icons.analytics_outlined, size: 18), SizedBox(width: 8), Text('Re-Run Analysis')])),
                          const PopupMenuItem(value: 'reject', child: Row(children: [Icon(Icons.close, size: 18, color: Colors.red), SizedBox(width: 8), Text('Reject Bid', style: TextStyle(color: Colors.red))])),
                        ],
                      ),
                  ],
                ),
                const Divider(height: 32, thickness: 1),
                
                // ── Item Details ──────────────────────────────────────────────
                Text('OFFER FOR: ${bid['ingredient_name']}', style: FarmTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800, color: FarmColors.darkGreen)),
                const SizedBox(height: 16),
                
                // ── Comparison Analytics Row ──────────────────────────────────
                _ComparisonGauges(bid: bid),
                
                const SizedBox(height: 24),
                
                // ── Basic Stats ──────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SimpleStat(label: 'OFFERED', value: '${bid['offered_quantity_kg']}kg'),
                    _SimpleStat(label: 'PRICE/KG', value: '\$${bid['offered_price_per_kg']}', highlight: true),
                    _SimpleStat(label: 'TOTAL', value: '\$${bid['total_bid_cost']}'),
                  ],
                ),

                if (status == 'pending') ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _acceptBid(bid),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FarmColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shadowColor: FarmColors.primaryGreen.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Accept Bid & Create Order', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptBid(Map<String, dynamic> bid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept this Bid?'),
        content: Text('This will notify ${bid['supplier_name']} and finalize your procurement for ${bid['ingredient_name']}. All other bids for this request will be automatically rejected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: FarmColors.primaryGreen, foregroundColor: Colors.white),
            child: const Text('Yes, Accept Bid'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final resp = await ApiClient.instance.acceptBid(bid['id']);
      if (resp['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bid accepted! Supplier has been notified.')));
        _init(silent: true); // Refresh the list
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _rejectBid(Map<String, dynamic> bid) async {
    try {
      final resp = await ApiClient.instance.rejectBid(bid['id']);
      if (resp['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bid rejected.')));
        _init(silent: true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _closeRequest(int requestId, String ingredientName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Request?'),
        content: Text('This will stop all bidding for "$ingredientName" and reject any remaining pending bids. You can re-initiate this from the Optimize tab if needed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Close Dispatch'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final resp = await ApiClient.instance.closeRequest(requestId);
      if (resp['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Procurement dispatch closed.')));
        _init(silent: true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildRequestGroupHeader(Map<String, dynamic> firstBid, int requestId) {
    final String reqStatus = firstBid['request_status'] ?? 'pending';
    final bool isPending = reqStatus == 'pending';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isPending ? FarmColors.darkGreen : Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Icon(isPending ? Icons.shopping_cart_outlined : Icons.check_circle_outline, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(firstBid['ingredient_name']?.toUpperCase() ?? 'INGREDIENT', 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                Text('Requirement: ${firstBid['requested_quantity']}kg | ${firstBid['target_cp_pct']}% CP', 
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
              ],
            ),
          ),
          if (isPending)
            TextButton(
              onPressed: () => _closeRequest(requestId, firstBid['ingredient_name'] ?? 'Ingredient'),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade100, padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: reqStatus == 'accepted' ? FarmColors.primaryGreen : Colors.grey.shade600,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(reqStatus.toUpperCase(), 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
            ),
        ],
      ),
    );
  }


  Widget _buildSupplierCard(Map<String, dynamic> s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: FarmColors.offWhite,
          child: const Icon(Icons.storefront, color: FarmColors.darkGreen),
        ),
        title: Text(s['company_name'] ?? 'Unknown', style: FarmTextStyles.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(s['description'] ?? 'No description available', maxLines: 2, overflow: TextOverflow.ellipsis, style: FarmTextStyles.bodySmall),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('${s['ingredient_count'] ?? 0} packages listed', style: FarmTextStyles.bodySmall.copyWith(fontSize: 10)),
                if (s['delivery_available'] == true) ...[
                   const SizedBox(width: 12),
                   const Icon(Icons.local_shipping_outlined, size: 12, color: FarmColors.primaryGreen),
                   const SizedBox(width: 4),
                   const Text('Delivery', style: TextStyle(fontSize: 10, color: FarmColors.primaryGreen, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ],
        ),
        onTap: () => _showSupplierProducts(s),
      ),
    );
  }

  Future<void> _analyzeBid(Map<String, dynamic> bid) async {
    final specs = bid['ingredient_specs'] ?? {};
    final targetType = specs['target_livestock_type'];
    
    int? autoSelectLvId;
    if (targetType != null) {
      final matches = _livestock.where((l) => l['animal_type'] == targetType).toList();
      if (matches.isNotEmpty) autoSelectLvId = matches.first['id'];
    }

    setState(() {
      if (autoSelectLvId != null) _selectedLivestockId = autoSelectLvId;
      _selectedIngredientId = 'mkt_${specs['id']}'; 
      _tabController.animateTo(0);
    });
    
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _optimize();
    });
  }

  Future<void> _getProcurementAdvice() async {
    if (_results == null) return;
    await _procure();
  }

  void _showSupplierProducts(Map<String, dynamic> supplier) {
    final supplierId = supplier['supplier_profile_id'];
    final products = _marketIngredients.where((ing) => ing['supplier_id'] == supplierId).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront, color: FarmColors.primaryGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    supplier['company_name'] ?? 'Supplier Products',
                    style: FarmTextStyles.titleLarge.copyWith(color: FarmColors.darkGreen),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              supplier['description'] ?? 'Select a package to run nutritional analysis.',
              style: FarmTextStyles.bodySmall,
            ),
            const Divider(height: 32),
            if (products.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text('No products listed by this supplier yet.'),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: FarmColors.offWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: FarmColors.borderLight),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(p['name'] ?? 'Package', style: FarmTextStyles.titleMedium),
                        subtitle: Text(
                          'Protein: ${p['crude_protein_pct']}% | \$${p['cost_usd_per_kg']}/kg',
                          style: FarmTextStyles.bodySmall,
                        ),
                        trailing: SizedBox(
                          width: 90,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _analyzeProduct(p);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FarmColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Analyze', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyzeProduct(Map<String, dynamic> product) async {
    final targetType = product['target_livestock_type'];
    
    int? autoSelectLvId;
    if (targetType != null) {
      final matches = _livestock.where((l) => l['animal_type'] == targetType).toList();
      if (matches.isNotEmpty) autoSelectLvId = matches.first['id'];
    }

    setState(() {
      if (autoSelectLvId != null) _selectedLivestockId = autoSelectLvId;
      _selectedIngredientId = 'mkt_${product['id']}'; 
      _tabController.animateTo(0);
    });
    
    // Smooth delay then trigger
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _optimize();
    });
  }

  Widget _buildHistoryTab() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen));
    }
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: FarmColors.textSecondary.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('No History Yet', style: FarmTextStyles.titleMedium),
            Text('Generate optimized mixes to see them here.', style: FarmTextStyles.bodySmall),
          ],
        ),
      );
    }
    
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final h = _history[index];
        final date = DateTime.tryParse(h['created_at'] ?? '');
        final dateStr = date != null ? DateFormat('MMM d, yyyy • hh:mm:ss a').format(date.toLocal()) : 'Unknown Date';
        
        final livestock = h['livestock'] as Map<String, dynamic>?;
        final ingredients = h['ingredients_json'] as List<dynamic>? ?? [];

        // Formulation Details (The Batch Recipe)
        double batchSize = 1.0;
        final String notes = h['notes'] ?? '';
        if (notes.contains('Total daily requirement:')) {
          try {
            batchSize = double.parse(notes.split('requirement: ')[1].split('kg')[0]);
          } catch (_) {}
        }

        // Nutrients Achieved
        final Map nutrients = h['nutrient_summary_json'] is Map 
          ? h['nutrient_summary_json'] 
          : (h['nutrient_summary'] is Map ? h['nutrient_summary'] : {});
        
        final double cpPct = (nutrients['crude_protein_pct'] ?? 0).toDouble();
        final double meVal = (nutrients['metabolizable_energy'] ?? 0).toDouble();
        final double absoluteCpKg = (cpPct / 100) * batchSize;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 20),
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(h['formulation_name'] ?? 'Formulation', style: FarmTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: FarmColors.mintFaint, borderRadius: BorderRadius.circular(10)),
                      child: Text('\$${(h['total_cost_usd'] ?? 0).toStringAsFixed(3)}/kg', style: TextStyle(color: FarmColors.primaryGreen, fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(dateStr, style: FarmTextStyles.bodySmall.copyWith(color: FarmColors.textSecondary, fontSize: 11)),
                
                const Divider(height: 24),
                
                // Group Info
                if (livestock != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.pets, size: 14, color: FarmColors.textSecondary),
                      const SizedBox(width: 8),
                      Text('${livestock['herd_size']} x ${livestock['animal_type']} (${livestock['production_stage']})', 
                        style: FarmTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: FarmColors.darkGreen)),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                Text('DAILY BATCH MIX (${batchSize.toStringAsFixed(1)}kg TOTAL)', style: FarmTextStyles.bodySmall.copyWith(fontSize: 10, fontWeight: FontWeight.bold, color: FarmColors.primaryGreen, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FarmColors.offWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FarmColors.borderLight),
                  ),
                  child: Column(
                    children: ingredients.map((ing) {
                      final double absoluteKg = (ing['kg_per_unit'] ?? 0.0) * batchSize;
                      return Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(ing['name'] ?? 'Ingredient', style: FarmTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                            Text('${absoluteKg.toStringAsFixed(2)} kg', style: FarmTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w900, color: FarmColors.darkGreen)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),
                
                // Nutrients Achieved
                Row(
                  children: [
                    const Icon(Icons.analytics_outlined, size: 14, color: FarmColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Achieved: $cpPct% CP (${absoluteCpKg.toStringAsFixed(2)}kg) | $meVal MJ/kg ME', 
                        style: FarmTextStyles.bodySmall.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),

                if (h['prediction'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.auto_graph, size: 14, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text('Yield Result: ${
                            h['prediction']['qualitative_label'] != null 
                              ? h['prediction']['qualitative_label'] 
                              : h['prediction']['predicted_milk_yield'] > 0 
                                ? '${h['prediction']['predicted_milk_yield']} L/day' 
                                : h['prediction']['predicted_weight_gain'] > 0 
                                  ? '${h['prediction']['predicted_weight_gain']} kg gain' 
                                  : 'Maintained'
                          }', style: FarmTextStyles.bodySmall.copyWith(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartsTab() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen));
    }
    
    // Extract unique animal types from history
    final animalTypes = _history.map((h) => h['livestock']?['animal_type']?.toString()).where((t) => t != null).toSet().toList();
    if (animalTypes.isEmpty) {
      return const Center(child: Text('No analytical data available. Generate more mixes.'));
    }
    
    if (_chartAnimalFilter == null || !animalTypes.contains(_chartAnimalFilter)) {
      _chartAnimalFilter = animalTypes.first;
    }
    
    // Process data for the selected filter
    final filteredHistory = _history.where((h) => h['livestock']?['animal_type'] == _chartAnimalFilter).toList();
    // Sort oldest to newest for chronological plotting
    filteredHistory.sort((a, b) => (DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now()).compareTo((DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now())));
    
    final List<FlSpot> costSpots = [];
    final List<BarChartGroupData> yieldBars = [];
    
    for (int i = 0; i < filteredHistory.length; i++) {
        final h = filteredHistory[i];
        final cost = (h['total_cost_usd'] ?? 0.0) as double;
        costSpots.add(FlSpot(i.toDouble(), cost.toDouble()));
        
        final pred = h['prediction'];
        if (pred != null) {
            double yieldVal = 0.0;
            if (pred['predicted_milk_yield'] != null && pred['predicted_milk_yield'] > 0) yieldVal = pred['predicted_milk_yield'];
            else if (pred['predicted_weight_gain'] != null && pred['predicted_weight_gain'] > 0) yieldVal = pred['predicted_weight_gain'];
            else if (pred['predicted_egg_production'] != null && pred['predicted_egg_production'] > 0) yieldVal = pred['predicted_egg_production'];
            
            yieldBars.add(BarChartGroupData(
                x: i,
                barRods: [BarChartRodData(toY: yieldVal, color: Colors.blueAccent, width: 14, borderRadius: BorderRadius.circular(4))],
            ));
        }
    }
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Expanded(
                 child: Text('Analytics', style: FarmTextStyles.titleMedium),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: DropdownButton<String>(
                     isExpanded: true,
                     value: _chartAnimalFilter,
                     items: animalTypes.map((t) => DropdownMenuItem(value: t, child: Text(t!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)))).toList(),
                     onChanged: (v) => setState(() => _chartAnimalFilter = v),
                 ),
               ),
            ],
          ),
          const SizedBox(height: 24),
          
          Text('Cost Trend (USD/kg)', style: FarmTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text('Sequential Formulations', style: TextStyle(fontSize: 10)),
                    axisNameSize: 16,
                    sideTitles: const SideTitles(showTitles: true, reservedSize: 22, interval: 1),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text('Cost (USD/kg)', style: TextStyle(fontSize: 10)),
                    axisNameSize: 16,
                    sideTitles: const SideTitles(showTitles: true, reservedSize: 40),
                  ),
                ),
                borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.grey.shade300), left: BorderSide(color: Colors.grey.shade300))),
                lineBarsData: [
                  LineChartBarData(
                    spots: costSpots.isEmpty ? [const FlSpot(0, 0)] : costSpots,
                    isCurved: true,
                    color: FarmColors.primaryGreen,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: FarmColors.primaryGreen.withOpacity(0.1)),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          
          Text('Predicted Yield Trend', style: FarmTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text('Sequential Formulations', style: TextStyle(fontSize: 10)),
                    axisNameSize: 16,
                    sideTitles: const SideTitles(showTitles: true, reservedSize: 22, interval: 1),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text('Predicted Yield', style: TextStyle(fontSize: 10)),
                    axisNameSize: 16,
                    sideTitles: const SideTitles(showTitles: true, reservedSize: 40),
                  ),
                ),
                borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.grey.shade300), left: BorderSide(color: Colors.grey.shade300))),
                barGroups: yieldBars.isEmpty ? [BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 0)])] : yieldBars,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BidStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _BidStat({required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FarmTextStyles.bodySmall.copyWith(fontSize: 8, color: FarmColors.textSecondary, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: FarmTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: color ?? FarmColors.darkGreen)),
      ],
    );
  }
}

class _MatchInsight extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MatchInsight({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: FarmColors.primaryGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, 
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: FarmColors.textSecondary)),
              Text(value, 
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FarmColors.darkGreen)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FarmTextStyles.bodySmall.copyWith(fontSize: 9, color: FarmColors.textSecondary)),
        Text(value, style: FarmTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: FarmColors.darkGreen)),
      ],
    );
  }
}

class _AddInventorySheet extends StatefulWidget {
  final Map<String, dynamic>? itemToEdit;
  const _AddInventorySheet({this.itemToEdit});

  @override
  State<_AddInventorySheet> createState() => _AddInventorySheetState();
}

class _AddInventorySheetState extends State<_AddInventorySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();
  final _meCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  
  String? _selectedType;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      final item = widget.itemToEdit!;
      _nameCtrl.text = item['name'] ?? '';
      _cpCtrl.text = item['crude_protein_pct']?.toString() ?? '';
      _meCtrl.text = item['metabolizable_energy']?.toString() ?? '';
      _costCtrl.text = item['cost_paid_usd_per_kg']?.toString() ?? '';
      _stockCtrl.text = item['stock_kg']?.toString() ?? '';
      
      final type = item['target_livestock_type'];
      if (AppConstants.livestockTypes.contains(type)) {
        _selectedType = type;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cpCtrl.dispose();
    _meCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final Map<String, dynamic> data = {
        'name': _nameCtrl.text,
        'target_livestock_type': _selectedType,
        'crude_protein_pct': double.parse(_cpCtrl.text),
        'metabolizable_energy': double.parse(_meCtrl.text),
        'cost_paid_usd_per_kg': double.parse(_costCtrl.text),
        'stock_kg': double.parse(_stockCtrl.text.isEmpty ? '0' : _stockCtrl.text),
      };

      Map<String, dynamic> resp;
      if (widget.itemToEdit != null) {
        resp = await ApiClient.instance.updateFarmerInventory(widget.itemToEdit!['id'], data);
      } else {
        resp = await ApiClient.instance.addFarmerInventory(data);
      }

      if (resp['success'] == true && mounted) {
        Navigator.pop(context, true);
      } else {
        setState(() => _error = resp['message'] ?? 'Failed to save ingredient');
      }
    } catch (e) {
      String msg = 'Failed to connect to server';
      if (e is DioException && e.response?.data is Map) {
        msg = e.response?.data['message'] ?? msg;
      }
      setState(() => _error = msg);
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
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: ctrl,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: FarmColors.borderLight, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Text(widget.itemToEdit == null ? 'Add Your Local Stock' : 'Edit Ingredient', style: FarmTextStyles.headlineMedium.copyWith(color: FarmColors.darkGreen)),
              const SizedBox(height: 8),
              Text(widget.itemToEdit == null ? 'Record ingredients you already have on your farm.' : 'Update nutritional values and pricing.', style: FarmTextStyles.bodySmall),
              const SizedBox(height: 20),
              
               if (_error != null) _ErrorContainer(message: _error!),

               DropdownButtonFormField<String>(
                 value: _selectedType,
                 decoration: const InputDecoration(labelText: 'Animal Category', hintText: 'Select purpose...'),
                 items: AppConstants.livestockTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                 onChanged: (v) => setState(() => _selectedType = v),
                 validator: (v) => v == null ? 'Required' : null,
               ),
               const SizedBox(height: 16),

               TextFormField(
                 controller: _nameCtrl,
                 decoration: const InputDecoration(labelText: 'Ingredient Name', hintText: 'e.g. Home-grown Maize'),
                 validator: (v) => v!.isEmpty ? 'Required' : null,
               ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _cpCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Protein %'), validator: (v) => v!.isEmpty ? 'Required' : null)),
                  const SizedBox(width: 16),
                  Expanded(child: TextFormField(controller: _meCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Energy (MJ)'), validator: (v) => v!.isEmpty ? 'Required' : null)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost/kg (USD)', prefixText: '\$'), validator: (v) => v!.isEmpty ? 'Required' : null)),
                  const SizedBox(width: 16),
                  Expanded(child: TextFormField(controller: _stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total kg'))),
                ],
              ),
              const SizedBox(height: 32),
              _loading
                  ? const Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen))
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: FarmColors.primaryGreen, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: Text(widget.itemToEdit == null ? 'Add to My Inventory' : 'Update Inventory', style: FarmTextStyles.buttonText),
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
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _SimStat extends StatelessWidget {
  final String label;
  final String value;
  const _SimStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _CircularScore extends StatelessWidget {
  final double score;
  final Color color;
  const _CircularScore({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 54, width: 54,
          child: CircularProgressIndicator(
            value: score / 100,
            backgroundColor: color.withOpacity(0.1),
            color: color,
            strokeWidth: 5,
          ),
        ),
        Text('${score.toInt()}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}

class _ComparisonGauges extends StatelessWidget {
  final Map<String, dynamic> bid;
  const _ComparisonGauges({required this.bid});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SpecRow(
          label: 'CRUDE PROTEIN',
          target: '${bid['target_cp_pct'] ?? '--'}%',
          actual: '${bid['offered_cp_pct'] ?? '--'}%',
          icon: Icons.fitness_center_outlined,
          color: Colors.blueAccent,
        ),
        const SizedBox(height: 12),
        _SpecRow(
          label: 'METABOLIZABLE ENERGY',
          target: '${bid['target_me_mj'] ?? '--'} MJ',
          actual: '${bid['offered_me_mj'] ?? '--'} MJ',
          icon: Icons.bolt_outlined,
          color: Colors.orangeAccent,
        ),
        const SizedBox(height: 12),
        _SpecRow(
          label: 'PRICE COMPETITIVENESS',
          target: '\$${bid['target_price_per_kg'] ?? '--'}',
          actual: '\$${bid['offered_price_per_kg'] ?? '--'}',
          icon: Icons.savings_outlined,
          color: FarmColors.primaryGreen,
        ),
      ],
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String target;
  final String actual;
  final IconData icon;
  final Color color;

  const _SpecRow({required this.label, required this.target, required this.actual, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: FarmColors.offWhite, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('Target: $target', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('|', style: TextStyle(color: Colors.grey))),
                    Text('Offer: $actual', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SimpleStat({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(
          fontSize: 14, 
          fontWeight: FontWeight.w900, 
          color: highlight ? FarmColors.primaryGreen : FarmColors.darkGreen
        )),
      ],
    );
  }
}
