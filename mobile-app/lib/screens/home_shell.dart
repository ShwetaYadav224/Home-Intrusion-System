import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';

import '../config/theme.dart';
import 'alerts/alerts_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'devices/devices_screen.dart';
import 'known_persons/known_persons_screen.dart';
import 'profile/profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final _pages = const [
    DashboardScreen(),
    DevicesScreen(),
    KnownPersonsScreen(),
    AlertsScreen(),
    ProfileScreen(),
  ];

  final _titles = const ['Dashboard', 'Devices', 'Family', 'Alerts', 'Profile'];

  static const _navItems = [
    _NavItem(IconlyLight.home, IconlyBold.home, 'Home'),
    _NavItem(IconlyLight.video, IconlyBold.video, 'Devices'),
    _NavItem(IconlyLight.heart, IconlyBold.heart, 'Family'),
    _NavItem(IconlyLight.notification, IconlyBold.notification, 'Alerts'),
    _NavItem(IconlyLight.profile, IconlyBold.profile, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.ambient),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _titles[_currentIndex],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (_currentIndex == 0)
                      _circleAction(IconlyLight.arrow_down_circle, () => setState(() {})),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 96),
                child: IndexedStack(
                  index: _currentIndex,
                  children: _pages,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.15),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (i) {
                final active = _currentIndex == i;
                final item = _navItems[i];
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () => setState(() => _currentIndex = i),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        width: active ? 54 : 44,
                        height: active ? 54 : 44,
                        decoration: BoxDecoration(
                          gradient: active ? AppTheme.primaryGradient : null,
                          shape: BoxShape.circle,
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(alpha: 0.45),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: AppTheme.secondary.withValues(alpha: 0.3),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          active ? item.activeIcon : item.icon,
                          color: active ? Colors.white : AppTheme.textMuted,
                          size: active ? 24 : 22,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleAction(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, size: 20, color: AppTheme.primary),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
