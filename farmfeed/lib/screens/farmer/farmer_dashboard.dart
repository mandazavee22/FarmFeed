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
import 'livestock_screen.dart';
import 'feed_screen.dart';

class FarmerDashboard extends StatefulWidget {
  const FarmerDashboard({super.key});

  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  int _currentIndex = 0;
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
    
    // Initial notifications fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  Future<void> _fetchDashboard() async {
    try {
      final data = await ApiClient.instance.getFarmerDashboard();
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
                const LivestockScreen(),
                const FeedScreen(),
                const ProfileScreen(),
                const CommunityScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: FarmColors.white,
        indicatorColor: FarmColors.mintFaint,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: FarmColors.primaryGreen),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets, color: FarmColors.primaryGreen),
            label: 'Livestock',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science, color: FarmColors.primaryGreen),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: FarmColors.primaryGreen),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum, color: FarmColors.primaryGreen),
            label: '',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardArea(UserModel? user, Map<String, dynamic>? stats) {
    return Column(
      children: [
        // ── Scrollable Body ────────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            color: FarmColors.primaryGreen,
            onRefresh: _fetchDashboard,
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
                  // Overview cards...
                  Text('Dashboard', style: FarmTextStyles.titleLarge),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.pets_outlined,
                        label: 'Livestock\nRecords',
                        value: '${stats?['livestock_records'] ?? 0}',
                        color: FarmColors.primaryGreen,
                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.science_outlined,
                        label: 'Feed\nFormulations',
                        value: '${stats?['feed_formulations'] ?? 0}',
                        color: FarmColors.mediumGreen,
                      ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.bar_chart_outlined,
                        label: 'Simulations\nRun',
                        value: '${stats?['simulations'] ?? 0}',
                        color: FarmColors.accentLime,
                      ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.2),
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
                        icon: Icons.tune_outlined,
                        label: 'Optimize Feed',
                        subtitle: 'LP Simplex solver',
                        color: FarmColors.darkGreen,
                        onTap: () => setState(() => _currentIndex = 2),
                      ).animate().fadeIn(delay: 320.ms).scale(begin: const Offset(0.9, 0.9)),
                      _ActionCard(
                        icon: Icons.analytics_outlined,
                        label: 'Production\nAnalysis',
                        subtitle: 'Random Forest',
                        color: FarmColors.primaryGreen,
                        onTap: () => setState(() => _currentIndex = 2),
                      ).animate().fadeIn(delay: 380.ms).scale(begin: const Offset(0.9, 0.9)),
                      _ActionCard(
                        icon: Icons.shuffle_outlined,
                        label: 'Run Scenario',
                        subtitle: 'Monte Carlo sim',
                        color: FarmColors.mediumGreen,
                        onTap: () => setState(() => _currentIndex = 2),
                      ).animate().fadeIn(delay: 440.ms).scale(begin: const Offset(0.9, 0.9)),
                      _ActionCard(
                        icon: Icons.store_outlined,
                        label: 'Find Suppliers',
                        subtitle: 'Browse ingredients',
                        color: FarmColors.lightGreen,
                        onTap: () => setState(() => _currentIndex = 4),
                      ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.9, 0.9)),
                    ],
                  ),

                ],
              ],
            ),
          ),
        ),
        ),
      ],
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
          style: FarmTextStyles.bodySmall.copyWith(color: Colors.white.withOpacity(0.85), fontSize: 11)),
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
          Text(value,
              style: FarmTextStyles.headlineMedium.copyWith(color: color, fontSize: 20)),
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

