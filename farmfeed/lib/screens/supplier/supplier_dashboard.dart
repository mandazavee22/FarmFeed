import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../models/user.dart';
import '../../main.dart';
import '../profile/profile_screen.dart';
import '../community/community_screen.dart';
import '../../widgets/farm_header.dart';
import '../../widgets/notification_sheet.dart';
import '../../core/notification_provider.dart';
import 'ingredients_screen.dart';
import 'open_market_screen.dart';

class SupplierDashboard extends StatefulWidget {
  const SupplierDashboard({super.key});

  @override
  State<SupplierDashboard> createState() => _SupplierDashboardState();
}

class _SupplierDashboardState extends State<SupplierDashboard> {
  int _currentIndex = 0;
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;

  List<Map<String, dynamic>> _orders = [];
  bool _isLoadingOrders = false;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
    
    // Initial notifications fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoadingOrders = true);
    try {
      final res = await ApiClient.instance.getSupplierOrders();
      if (res['success'] && mounted) {
        setState(() => _orders = List<Map<String, dynamic>>.from(res['data']['orders']));
      }
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      final res = await ApiClient.instance.updateOrderStatus(id, status);
      if (res['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'])),
        );
        _fetchOrders();
        _fetchDashboard();
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  Future<void> _fetchDashboard() async {
    try {
      final data = await ApiClient.instance.getSupplierDashboard();
      if (mounted && data['success'] == true) {
        setState(() {
          _dashboardData = data['data'];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().clearSession();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final stats = _dashboardData?['stats'] as Map<String, dynamic>?;
    final companyName = user?.companyName ?? 'Your Company';

    return Scaffold(
      backgroundColor: FarmColors.offWhite,
      body: Column(
        children: [
          FarmAppHeader(
            user: user,
            onLogout: _logout,
            onNotificationTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const FractionallySizedBox(
                  heightFactor: 0.8,
                  child: NotificationSheet(),
                ),
              );
            },
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildDashboardArea(user, stats),
                const IngredientsScreen(),
                const OpenMarketScreen(), 
                const ProfileScreen(),
                const CommunityScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          // Auto-refresh when switching
          _fetchDashboard();
          if (i == 1) {
             // Ingredients typically refreshes itself in initState, 
             // but we'll assume the user wants a fresh pull on every switch.
          }
        },
        backgroundColor: FarmColors.white,
        indicatorColor: FarmColors.mintFaint,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: FarmColors.primaryGreen),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: FarmColors.primaryGreen),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: FarmColors.primaryGreen),
            label: 'Market',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: FarmColors.primaryGreen),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum, color: FarmColors.primaryGreen),
            label: 'Social',
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    if (_isLoadingOrders) {
      return const Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen));
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No orders yet', style: FarmTextStyles.titleMedium.copyWith(color: Colors.grey.shade500)),
            Text('Farmer requests will appear here.', style: FarmTextStyles.bodySmall.copyWith(color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          final status = order['status'].toString().toLowerCase();
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FarmColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                            color: _getStatusColor(status),
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '#ORD-${order['id']}',
                      style: FarmTextStyles.bodySmall.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(order['farmer_name'] ?? 'Unknown Farmer', style: FarmTextStyles.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.label_outline, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(order['ingredient_name'] ?? 'Generic Ingredient', 
                        style: FarmTextStyles.bodySmall.copyWith(color: Colors.grey.shade700)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quantity', style: FarmTextStyles.bodySmall.copyWith(fontSize: 10)),
                        Text('${order['quantity_kg']} kg', 
                            style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.darkGreen)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Est. Value', style: FarmTextStyles.bodySmall.copyWith(fontSize: 10)),
                        Text('\$${order['estimated_cost_usd']}', 
                            style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.primaryGreen)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showBidSheet(order),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FarmColors.primaryGreen,
                            side: const BorderSide(color: FarmColors.primaryGreen),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Submit Bid'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _updateStatus(order['id'], 'rejected'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateStatus(order['id'], 'accepted'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FarmColors.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  )
                else if (status == 'accepted')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _updateStatus(order['id'], 'fulfilled'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FarmColors.darkGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Mark as Fulfilled'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showBidSheet(Map<String, dynamic> order) {
    final qtyController = TextEditingController(text: order['quantity_kg'].toString());
    final priceController = TextEditingController(text: '0.00'); // Usually fetched from the ingredient
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Submit Counter-Bid', style: FarmTextStyles.titleLarge.copyWith(color: FarmColors.darkGreen)),
            const SizedBox(height: 8),
            Text('Adjust quantities and pricing to send an offer to ${order['farmer_name']}.', style: FarmTextStyles.bodySmall),
            const SizedBox(height: 24),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Offered Quantity (kg)', prefixIcon: Icon(Icons.scale_outlined)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Your Price per kg (USD)', prefixIcon: Icon(Icons.attach_money), prefixText: '\$'),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final data = {
                    'offered_quantity_kg': double.tryParse(qtyController.text) ?? 0,
                    'offered_cost_usd_per_kg': double.tryParse(priceController.text) ?? 0,
                    'notes': 'Bid submitted for ${order['ingredient_name']}'
                  };
                  try {
                    final resp = await ApiClient.instance.submitBid(order['id'], data);
                    if (resp['success'] && mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bid submitted successfully!')));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FarmColors.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Send Bid to Farmer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'fulfilled': return FarmColors.primaryGreen;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildDashboardArea(UserModel? user, Map<String, dynamic>? stats) {
    return RefreshIndicator(
      onRefresh: _fetchDashboard,
      color: FarmColors.primaryGreen,
      child: Column(
        children: [
          // ── Scrollable Body ────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(color: FarmColors.primaryGreen),
                      ),
                    )
                  else ...[
                    Text('Dashboard', style: FarmTextStyles.titleLarge),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.explore_outlined,
                          label: 'Market\nBids',
                          value: '${stats?['open_biddings'] ?? 0}',
                          color: FarmColors.primaryGreen,
                        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
                      ),
                    ]),
  
                    const SizedBox(height: 24),
                    Text('Quick Actions', style: FarmTextStyles.titleLarge),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0,
                      children: [
                        _ActionCard(
                          icon: Icons.add_box_outlined,
                          label: 'Add Ingredient',
                          subtitle: 'List a feed product',
                          color: FarmColors.darkGreen,
                          onTap: () => setState(() => _currentIndex = 1),
                        ).animate().fadeIn(delay: 320.ms).scale(begin: const Offset(0.9, 0.9)),
                        _ActionCard(
                          icon: Icons.explore_outlined,
                          label: 'View Market',
                          subtitle: 'Farmer requests',
                          color: FarmColors.primaryGreen,
                          onTap: () => setState(() => _currentIndex = 2),
                        ).animate().fadeIn(delay: 380.ms).scale(begin: const Offset(0.9, 0.9)),
                        _ActionCard(
                          icon: Icons.inventory_outlined,
                          label: 'Manage Stock',
                          subtitle: 'Update quantities',
                          color: FarmColors.mediumGreen,
                          onTap: () => setState(() => _currentIndex = 1),
                        ).animate().fadeIn(delay: 440.ms).scale(begin: const Offset(0.9, 0.9)),
                        _ActionCard(
                          icon: Icons.receipt_long_outlined,
                          label: 'View Bids',
                          subtitle: 'Your active offers',
                          color: FarmColors.lightGreen,
                          onTap: () => setState(() => _currentIndex = 2),
                        ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.9, 0.9)),
                      ],
                    ),
  
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: FarmTextStyles.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.85), fontSize: 11)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FarmColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FarmColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value, style: FarmTextStyles.headlineMedium.copyWith(color: color, fontSize: 20)),
          Text(label, style: FarmTextStyles.bodySmall.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FarmTextStyles.titleMedium.copyWith(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FarmTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.75), fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: FarmColors.lightGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FarmColors.accentLime, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.rocket_launch, color: FarmColors.primaryGreen, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phase 3 Coming Soon',
                    style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.darkGreen)),
                const SizedBox(height: 3),
                Text(
                  'Full ingredient management, procurement fulfilment, demand forecasting and farmer-supplier matching will be enabled in Phase 3.',
                  style: FarmTextStyles.bodySmall.copyWith(
                      color: FarmColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1);
  }
}
