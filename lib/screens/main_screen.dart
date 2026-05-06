import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'add_medicine_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _homeRefreshToken = 0;
  int _statsRefreshToken = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(key: ValueKey(_homeRefreshToken)),
          const HistoryScreen(),
          StatsScreen(key: ValueKey(_statsRefreshToken)),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 84,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildNavItem(
                      index: 0,
                      label: 'Ana Sayfa',
                      activeIcon: Icons.home_rounded,
                      inactiveIcon: Icons.home_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      index: 1,
                      label: 'Takvim',
                      activeIcon: Icons.calendar_month_rounded,
                      inactiveIcon: Icons.calendar_month_outlined,
                    ),
                  ),
                  Expanded(child: Center(child: _buildAddButton())),
                  Expanded(
                    child: _buildNavItem(
                      index: 2,
                      label: 'İstatistik',
                      activeIcon: Icons.bar_chart_rounded,
                      inactiveIcon: Icons.bar_chart_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      index: 3,
                      label: 'Ayarlar',
                      activeIcon: Icons.settings_rounded,
                      inactiveIcon: Icons.settings_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _openAddMedicine,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 2),
          Text(
            'Ekle',
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData activeIcon,
    required IconData inactiveIcon,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppTheme.primaryColor : AppTheme.textTertiary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          if (index == 2) {
            _statsRefreshToken++;
          }
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddMedicine() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute<Object?>(
        builder: (_) => const AddMedicineScreen(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _currentIndex = 0;
        _homeRefreshToken++;
      });
    }
  }
}
