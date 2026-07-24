import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/user.dart';
import '../core/notification_provider.dart';
import 'package:provider/provider.dart';

class FarmAppHeader extends StatelessWidget {
  final UserModel? user;
  final VoidCallback onLogout;
  final VoidCallback? onNotificationTap;

  const FarmAppHeader({
    super.key,
    required this.user,
    required this.onLogout,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFarmer = user?.isFarmer ?? true;
    final mainName = isFarmer
        ? (user?.firstName ?? 'Farmer')
        : (user?.companyName.isNotEmpty == true ? user!.companyName : 'Supplier');

    return Container(
      decoration: const BoxDecoration(
        gradient: FarmColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          child: Row(
            children: [
              // Logo
              Image.asset(
                'images/logo.png',
                height: 42,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.agriculture, color: Colors.white, size: 38),
              ),
              const SizedBox(width: 14),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    Text(
                      isFarmer ? (user?.firstName ?? 'Farmer') : (user?.fullName ?? 'Supplier'),
                      style: FarmTextStyles.headlineMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    _buildSubInfo(),
                  ],
                ),
              ),

              // Actions
              /*
              Consumer<NotificationProvider>(
                builder: (context, provider, child) {
                  return Badge(
                    label: Text('${provider.unreadCount}'),
                    isLabelVisible: provider.unreadCount > 0,
                    backgroundColor: Colors.red,
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: () {
                        if (onNotificationTap != null) {
                          onNotificationTap!();
                        }
                      },
                      tooltip: 'Notifications',
                    ),
                  );
                },
              ),
              */
              IconButton(
                icon: const Icon(Icons.lock_outline, color: Colors.white),
                onPressed: onLogout,
                tooltip: 'Sign Out',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubInfo() {
    String subText = '';
    if (user == null) return const SizedBox.shrink();

    if (user!.isFarmer) {
      final farm = user!.farmName;
      final loc = user!.city.isNotEmpty ? user!.city : user!.province;
      if (farm.isNotEmpty && loc.isNotEmpty) {
        subText = '$farm • $loc';
      } else {
        subText = farm.isNotEmpty ? farm : loc;
      }
    } else {
      final city = user!.city;
      final prov = user!.province;
      if (city.isNotEmpty && prov.isNotEmpty) {
        subText = '$city, $prov';
      } else {
        subText = city.isNotEmpty ? city : prov;
      }
    }

    if (subText.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        subText,
        style: FarmTextStyles.bodySmall.copyWith(
          color: Colors.white.withOpacity(0.75),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
