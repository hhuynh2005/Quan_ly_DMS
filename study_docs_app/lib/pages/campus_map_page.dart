import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../struct/document_location_model.dart';
import '../struct/document_state_provider.dart';
import '../struct/responsive_breakpoints.dart';
import '../widgets/location_map_view.dart';
import 'document_detail_page.dart';

/// Màn hình Bản đồ số định vị tài liệu tại Khuôn viên Đại học Thủy Lợi (TH2)
/// Phụ trách: NGUYỄN TRUNG KIÊN (MSSV: 2251172394)
class CampusMapPage extends StatefulWidget {
  final DocumentLocation? initialLocation;

  const CampusMapPage({super.key, this.initialLocation});

  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}

class _CampusMapPageState extends State<CampusMapPage> {
  DocumentLocation? _activeLocation;

  @override
  void initState() {
    super.initState();
    _activeLocation = widget.initialLocation;
  }

  void _onLocationSelected(DocumentLocation loc) {
    setState(() => _activeLocation = loc);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<DocumentStateProvider>();
    final locations = provider.locations;
    final isDesktop = context.isDesktop;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.map_rounded),
            SizedBox(width: 8),
            Text(
              'Bản đồ vị trí tài liệu TLU',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Thông tin bản đồ TLU',
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'Smart DMS - TLU Campus Map',
                applicationVersion: '2.0.0 (TH2)',
                children: const [
                  Text(
                    'Tính năng định vị vị trí vật lý của tài liệu học tập theo từng Tòa nhà, '
                    'Phòng học và Kệ sách tại Trường Đại học Thủy Lợi (175 Tây Sơn, Đống Đa, Hà Nội).\n\n'
                    'Phát triển bởi: Nguyễn Trung Kiên (MSSV: 2251172394) - Nhóm 16.',
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: isDesktop
          ? _buildDesktopView(context, locations, theme, isDark)
          : _buildMobileTabletView(context, locations, theme, isDark),
    );
  }

  // ===========================================================================
  // 1. MOBILE & TABLET LAYOUT
  // ===========================================================================
  Widget _buildMobileTabletView(
    BuildContext context,
    List<DocumentLocation> locations,
    ThemeData theme,
    bool isDark,
  ) {
    return Column(
      children: [
        _buildStatsBanner(locations, theme, isDark),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LocationMapView(
              height: double.infinity,
              highlightedLocation: _activeLocation,
              onLocationTapped: _onLocationSelected,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. DESKTOP DUAL-PANE LAYOUT (Bản đồ lớn bên trái, Danh sách vị trí bên phải)
  // ===========================================================================
  Widget _buildDesktopView(
    BuildContext context,
    List<DocumentLocation> locations,
    ThemeData theme,
    bool isDark,
  ) {
    final provider = context.watch<DocumentStateProvider>();
    final allDocs = provider.allDocuments;

    return Row(
      children: [
        // Cột bản đồ chính
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildStatsBanner(locations, theme, isDark),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LocationMapView(
                    height: double.infinity,
                    highlightedLocation: _activeLocation,
                    onLocationTapped: _onLocationSelected,
                  ),
                ),
              ),
            ],
          ),
        ),

        const VerticalDivider(thickness: 1, width: 1),

        // Cột danh sách chi tiết các vị trí bên phải
        SizedBox(
          width: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : Colors.grey.shade50,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 20, color: Colors.teal),
                    SizedBox(width: 8),
                    Text(
                      'Danh mục Vị trí Vật lý',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: locations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final loc = locations[idx];
                    final docs = allDocs.where((d) => d.id == loc.documentId).toList();
                    final isSelected = _activeLocation?.id == loc.id;

                    return Card(
                      elevation: isSelected ? 2 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isDark ? Colors.white10 : Colors.grey.shade300),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : Colors.grey,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    loc.building,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${docs.length} tệp',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.teal,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              loc.summary,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (docs.isNotEmpty) ...[
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DocumentDetailPage(
                                        documentId: docs.first.id,
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  '📄 ${docs.first.title}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Banner thống kê nhanh số lượng vị trí
  Widget _buildStatsBanner(
    List<DocumentLocation> locations,
    ThemeData theme,
    bool isDark,
  ) {
    final buildingsCount = locations.map((l) => l.building).toSet().length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.teal.shade50,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.teal.shade100,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Tổng vị trí', '${locations.length}', Icons.pin_drop_rounded, theme),
          _buildStatItem('Tòa nhà TLU', '$buildingsCount', Icons.business_rounded, theme),
          _buildStatItem('Tọa độ GPS', '175 Tây Sơn', Icons.gps_fixed_rounded, theme),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}
