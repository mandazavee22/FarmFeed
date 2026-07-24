import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OpenMarketScreen extends StatefulWidget {
  const OpenMarketScreen({super.key});

  @override
  State<OpenMarketScreen> createState() => _OpenMarketScreenState();
}

class _OpenMarketScreenState extends State<OpenMarketScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.instance.getOpenMarket();
      if (res['success'] && mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(res['data']['requests']);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen));
    }

    if (_requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchRequests,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gavel_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No Open Dispatches', style: FarmTextStyles.titleMedium.copyWith(color: Colors.grey.shade500)),
                  Text('Farmer bidding requests will appear here.', style: FarmTextStyles.bodySmall.copyWith(color: Colors.grey.shade400)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final req = _requests[index];
          return _buildRequestCard(req).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1);
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
        ],
        border: Border.all(color: FarmColors.borderLight),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: FarmColors.primaryGreen.withOpacity(0.05),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: FarmColors.primaryGreen,
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(req['farmer_name'] ?? 'Farmer', style: FarmTextStyles.titleMedium),
                        Text(req['location'] ?? 'Unknown Location', style: FarmTextStyles.bodySmall.copyWith(color: FarmColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (req['bid_status'] == 'accepted')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: FarmColors.primaryGreen, borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('WON / ACCEPTED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else if (req['status'] == 'accepted')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                      child: Text('CLOSED', style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  else if (req['has_bidded'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: FarmColors.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 12, color: FarmColors.primaryGreen),
                          SizedBox(width: 4),
                          Text('BID SUBMITTED', style: TextStyle(color: FarmColors.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Text('MARKET DISPATCH', style: TextStyle(color: FarmColors.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     children: [
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text('REQUESTING', style: FarmTextStyles.bodySmall.copyWith(fontSize: 9, letterSpacing: 1)),
                             Text(req['ingredient_name'] ?? 'Ingredient', style: FarmTextStyles.titleLarge.copyWith(color: FarmColors.darkGreen, fontSize: 18)),
                           ],
                         ),
                       ),
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.end,
                         children: [
                           Text('VOLUME', style: FarmTextStyles.bodySmall.copyWith(fontSize: 9, letterSpacing: 1)),
                           Text('${req['quantity_kg']} kg', style: FarmTextStyles.titleLarge.copyWith(color: FarmColors.primaryGreen, fontSize: 18)),
                         ],
                       ),
                     ],
                   ),
                   const SizedBox(height: 20),
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: FarmColors.offWhite, borderRadius: BorderRadius.circular(16)),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text('ANALYSED REQUIREMENTS (PER ANIMAL)', style: TextStyle(fontSize: 9, color: FarmColors.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                         const SizedBox(height: 12),
                         Row(
                           children: [
                             _TargetChip(label: 'AVG Protein', value: '${req['daily_cp_kg_head'] ?? 0} kg', icon: Icons.science_outlined),
                             const SizedBox(width: 16),
                             _TargetChip(label: 'AVG Energy', value: '${req['daily_me_mj_head'] ?? 0} MJ', icon: Icons.bolt_outlined),
                           ],
                         ),
                         const Divider(height: 16),
                         Row(
                           children: [
                             Text('Formulation Density:', style: TextStyle(fontSize: 10, color: FarmColors.textSecondary)),
                             const Spacer(),
                             Text('${req['target_cp_pct']}% CP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FarmColors.darkGreen)),
                             const SizedBox(width: 12),
                             Text('${req['target_me_mj']} MJ/kg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FarmColors.primaryGreen)),
                           ],
                         ),
                       ],
                     ),
                   ),
                   const SizedBox(height: 24),
                   SizedBox(
                     width: double.infinity,
                     height: 52,
                     child: ElevatedButton(
                       onPressed: (req['has_bidded'] == true || req['status'] == 'accepted') ? null : () => _showBidSheet(req),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: (req['has_bidded'] == true || req['status'] == 'accepted') ? Colors.grey.shade200 : FarmColors.darkGreen,
                         foregroundColor: (req['has_bidded'] == true || req['status'] == 'accepted') ? Colors.grey.shade500 : Colors.white,
                         elevation: 0,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                       ),
                       child: Text(
                         (req['bid_status'] == 'accepted') ? 'Bid Accepted' : 
                         (req['status'] == 'accepted') ? 'Closed' :
                         (req['has_bidded'] == true) ? 'Bid Already Submitted' : 'Bid on this Dispatch', 
                         style: const TextStyle(fontWeight: FontWeight.bold)
                       ),
                     ),
                   ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBidSheet(Map<String, dynamic> req) {
    final qtyController = TextEditingController(text: req['quantity_kg'].toString());
    final priceController = TextEditingController();
    int? selectedIngredientId;
    List<Map<String, dynamic>> supplierItems = [];
    bool loadingItems = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          if (loadingItems) {
            ApiClient.instance.getSupplierIngredients().then((res) {
              if (res['success'] && mounted) {
                setSheetState(() {
                  supplierItems = List<Map<String, dynamic>>.from(res['data']['ingredients']);
                  loadingItems = false;
                });
              }
            });
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24, 
                right: 24, 
                top: 24, 
                bottom: MediaQuery.of(context).viewInsets.bottom + 32
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 24),
                Text('Submit Your Bid', style: FarmTextStyles.titleLarge.copyWith(fontSize: 24, color: FarmColors.darkGreen)),
                const SizedBox(height: 8),
                Text('Select your matching product and offer your price.', style: FarmTextStyles.bodySmall),
                const SizedBox(height: 24),
                
                // ── Ingredient Selection ──────────────────────────────────────────────
                Text('OFFER PRODUCT FOR: ${req['livestock_category'] ?? 'General'}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: FarmColors.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                if (loadingItems)
                  const LinearProgressIndicator(color: FarmColors.primaryGreen)
                else
                  Builder(
                    builder: (context) {
                      final reqCat = (req['livestock_category'] ?? '').toString().toLowerCase().trim();
                      
                      // Layer 1: Exact matches
                      var matches = supplierItems.where((ing) {
                        final ingCat = (ing['target_livestock_type'] ?? '').toString().toLowerCase().trim();
                        return ingCat == reqCat;
                      }).toList();

                      // Layer 2: Substring matches (if no exact matches)
                      if (matches.isEmpty && reqCat.isNotEmpty) {
                        matches = supplierItems.where((ing) {
                          final ingCat = (ing['target_livestock_type'] ?? '').toString().toLowerCase().trim();
                          return ingCat.contains(reqCat) || reqCat.contains(ingCat);
                        }).toList();
                      }

                      // Layer 3: Fallback (Show all if still empty, but with warning)
                      final isFallback = matches.isEmpty;
                      final displayItems = isFallback ? supplierItems : matches;

                      if (displayItems.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.red.shade200)),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                              SizedBox(width: 12),
                              Expanded(child: Text('You have no products in your stock. Please add items to your inventory first.', style: TextStyle(color: Colors.red, fontSize: 12))),
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isFallback) 
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('No exact matches found for "$reqCat". Showing your entire stock:', 
                                style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontStyle: FontStyle.italic)),
                            ),
                          DropdownButtonFormField<int>(
                            value: selectedIngredientId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: isFallback ? 'Select any product' : 'Select matching product',
                              prefixIcon: const Icon(Icons.inventory_2_outlined, color: FarmColors.primaryGreen),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            items: displayItems.map((ing) {
                              return DropdownMenuItem<int>(
                                value: ing['id'],
                                child: Text(
                                  '${ing['name']} (${ing['crude_protein_pct']}% CP)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => setSheetState(() => selectedIngredientId = val),
                          ),
                        ],
                      );
                    },
                  ),
                
                const SizedBox(height: 20),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity you can supply (kg)',
                    prefixIcon: const Icon(Icons.scale_outlined, color: FarmColors.primaryGreen),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Price per kilogram (USD)',
                    prefixIcon: const Icon(Icons.payments_outlined, color: FarmColors.primaryGreen),
                    prefixText: '\$ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: (selectedIngredientId == null) ? null : () async {
                       final data = {
                        'supplier_ingredient_id': selectedIngredientId,
                        'offered_quantity_kg': double.tryParse(qtyController.text) ?? 0,
                        'offered_cost_usd_per_kg': double.tryParse(priceController.text) ?? 0,
                        'notes': 'Bid on ${req['ingredient_name']} public dispatch.'
                      };
                      try {
                        final resp = await ApiClient.instance.submitBid(req['id'], data);
                        if (resp['success'] && mounted) {
                          Navigator.pop(context);
                          _fetchRequests();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bid submitted successfully! Farmer will be notified.')),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FarmColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: FarmColors.primaryGreen.withOpacity(0.3),
                    ),
                    child: const Text('SUBMIT BID', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _TargetChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: FarmColors.primaryGreen),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 8, color: FarmColors.textSecondary, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: FarmColors.darkGreen)),
            ],
          ),
        ],
      ),
    );
  }
}
