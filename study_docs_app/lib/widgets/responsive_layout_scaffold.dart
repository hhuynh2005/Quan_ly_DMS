import 'package:flutter/material.dart';
import '../struct/responsive_breakpoints.dart';

/// Mục điều hướng thích ứng trong ResponsiveLayoutScaffold
class ResponsiveDestination {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final String? tooltip;
  final int? badgeCount;

  const ResponsiveDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.tooltip,
    this.badgeCount,
  });
}

/// Khung giao diện Responsive đa nền tảng chuẩn Material Design 3 (TH2)
/// Tự động chuyển đổi giữa NavigationBar (Mobile), NavigationRail (Tablet) và Extended Sidebar (Desktop)
/// Phụ trách: NGUYỄN TRUNG KIÊN (MSSV: 2251172394)
class ResponsiveLayoutScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<ResponsiveDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onNavigationIndexChanged;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool limitContentWidth;
  final Widget? leading;
  final Widget? secondaryBody; // Cho phép hiển thị Dual-pane (Master-Detail) trên Desktop

  const ResponsiveLayoutScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.destinations,
    required this.currentIndex,
    required this.onNavigationIndexChanged,
    this.actions,
    this.floatingActionButton,
    this.limitContentWidth = true,
    this.leading,
    this.secondaryBody,
  });

  @override
  Widget build(BuildContext context) {
    final screenType = context.screenType;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    switch (screenType) {
      case DeviceScreenType.mobile:
        return _buildMobileScaffold(context, theme, isDark);
      case DeviceScreenType.tablet:
        return _buildTabletScaffold(context, theme, isDark);
      case DeviceScreenType.desktop:
        return _buildDesktopScaffold(context, theme, isDark);
    }
  }

  // ===========================================================================
  // 1. MOBILE LAYOUT: Scaffold chuẩn với Material 3 NavigationBar ở đáy
  // ===========================================================================
  Widget _buildMobileScaffold(BuildContext context, ThemeData theme, bool isDark) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: leading,
        actions: actions,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onNavigationIndexChanged,
        destinations: destinations.map((dest) {
          Widget iconWidget = Icon(dest.icon);
          if (dest.badgeCount != null && dest.badgeCount! > 0) {
            iconWidget = Badge(
              label: Text('${dest.badgeCount}'),
              child: iconWidget,
            );
          }
          return NavigationDestination(
            icon: iconWidget,
            selectedIcon: Icon(dest.selectedIcon ?? dest.icon),
            label: dest.label,
            tooltip: dest.tooltip,
          );
        }).toList(),
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  // ===========================================================================
  // 2. TABLET LAYOUT: NavigationRail bên trái (Icon + Nhãn nhỏ gọn)
  // ===========================================================================
  Widget _buildTabletScaffold(BuildContext context, ThemeData theme, bool isDark) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        leading: leading,
        actions: actions,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onNavigationIndexChanged,
            labelType: NavigationRailLabelType.all,
            leading: floatingActionButton != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: floatingActionButton,
                  )
                : null,
            destinations: destinations.map((dest) {
              Widget iconWidget = Icon(dest.icon);
              if (dest.badgeCount != null && dest.badgeCount! > 0) {
                iconWidget = Badge(
                  label: Text('${dest.badgeCount}'),
                  child: iconWidget,
                );
              }
              return NavigationRailDestination(
                icon: iconWidget,
                selectedIcon: Icon(dest.selectedIcon ?? dest.icon),
                label: Text(dest.label),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: limitContentWidth
                ? ResponsiveContentContainer(child: body)
                : body,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. DESKTOP / WIDE WEB LAYOUT: Sidebar mở rộng với Header & Footer nhận diện
  // ===========================================================================
  Widget _buildDesktopScaffold(BuildContext context, ThemeData theme, bool isDark) {
    final sidebarWidth = 260.0;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar mở rộng sang trọng cho Desktop
          SizedBox(
            width: sidebarWidth,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surface : Colors.grey.shade50,
                border: Border(
                  right: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // App Branding Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.auto_stories_rounded,
                            color: theme.colorScheme.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Smart DMS',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              Text(
                                'ĐH Thủy Lợi • TH2',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Nút tạo mới nếu có FAB
                  if (floatingActionButton != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: floatingActionButton,
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Danh sách Menu Items
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: destinations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final dest = destinations[index];
                        final isSelected = index == currentIndex;
                        return InkWell(
                          onTap: () => onNavigationIndexChanged(index),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? (dest.selectedIcon ?? dest.icon)
                                      : dest.icon,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                  size: 22,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    dest.label,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : (isDark ? Colors.white : Colors.black87),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (dest.badgeCount != null && dest.badgeCount! > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${dest.badgeCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Footer Sidebar: Thông tin thành viên & Responsive Badge
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                          child: Text(
                            'K',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nguyễn Trung Kiên',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Responsive & Location',
                                style: TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'DESKTOP',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Vùng nội dung chính trên Desktop
          Expanded(
            child: Column(
              children: [
                // Top App Bar cho Desktop
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (actions != null) ...actions!,
                    ],
                  ),
                ),

                // Nội dung thân trang
                Expanded(
                  child: secondaryBody != null
                      ? Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: limitContentWidth
                                  ? ResponsiveContentContainer(child: body)
                                  : body,
                            ),
                            const VerticalDivider(thickness: 1, width: 1),
                            Expanded(
                              flex: 2,
                              child: secondaryBody!,
                            ),
                          ],
                        )
                      : (limitContentWidth
                          ? ResponsiveContentContainer(child: body)
                          : body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
