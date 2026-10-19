import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../struct/document_location_model.dart';
import '../struct/document_model.dart';
import '../struct/document_state_provider.dart';
import '../struct/responsive_breakpoints.dart';

/// Thành phần Bản đồ số định vị vị trí tài liệu tại ĐH Thủy Lợi (TH2)
/// Phụ trách: NGUYỄN TRUNG KIÊN (MSSV: 2251172394)
class LocationMapView extends StatefulWidget {
  final DocumentLocation? highlightedLocation;
  final ValueChanged<DocumentLocation>? onLocationTapped;
  final bool showControls;
  final double height;

  const LocationMapView({
    super.key,
    this.highlightedLocation,
    this.onLocationTapped,
    this.showControls = true,
    this.height = 420.0,
  });

  @override
  State<LocationMapView> createState() => _LocationMapViewState();
}

class _LocationMapViewState extends State<LocationMapView> {
  late final MapController _mapController;
  DocumentLocation? _selectedLocation;
  String? _selectedBuildingFilter;
  bool _isListView = false;

  // Tọa độ trung tâm khuôn viên ĐH Thủy Lợi (175 Tây Sơn, Đống Đa, Hà Nội)
  static const LatLng tluCampusCenter = LatLng(
    TluLocationPreset.tluCenterLatitude,
    TluLocationPreset.tluCenterLongitude,
  );

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = widget.highlightedLocation;
  }

  @override
  void didUpdateWidget(covariant LocationMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightedLocation != oldWidget.highlightedLocation &&
        widget.highlightedLocation != null) {
      _selectedLocation = widget.highlightedLocation;
      _moveToLocation(_selectedLocation!);
    }
  }

  void _moveToLocation(DocumentLocation loc) {
    _mapController.move(
      LatLng(loc.latitude, loc.longitude),
      17.8,
    );
  }

  void _recenterTlu() {
    _mapController.move(tluCampusCenter, 17.2);
    setState(() => _selectedLocation = null);
  }

  void _showLocationDetailsModal(
    BuildContext context,
    DocumentLocation location,
    List<Document> documents,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.building,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          location.summary,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${documents.length} tài liệu',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pin_drop_rounded, size: 16, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        location.formattedAddress,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '📚 Tài liệu lưu trữ tại vị trí này:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (documents.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Chưa có tài liệu nào được xếp vào vị trí này.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: documents.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final doc = documents[idx];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                          child: Icon(
                            doc.fileFormat.icon,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          doc.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Môn: ${doc.subjectId} • ${doc.documentType.displayName}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (widget.onLocationTapped != null) {
                            widget.onLocationTapped!(location);
                          }
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Đóng'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<DocumentStateProvider>();
    final allLocations = provider.locations;
    final allDocuments = provider.allDocuments;

    // Lọc theo tòa nhà nếu người dùng chọn
    final displayedLocations = _selectedBuildingFilter == null
        ? allLocations
        : allLocations
            .where((loc) => loc.building == _selectedBuildingFilter)
            .toList();

    // Gom danh sách các tòa nhà duy nhất để làm bộ lọc
    final uniqueBuildings = allLocations.map((l) => l.building).toSet().toList();

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Bản đồ OpenStreetMap hoặc Danh sách vị trí
          if (_isListView)
            _buildListView(displayedLocations, allDocuments, theme, isDark)
          else
            _buildFlutterMap(displayedLocations, allDocuments, theme, isDark),

          // 2. Thanh bộ lọc tòa nhà ở trên cùng
          if (widget.showControls)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Tất cả tòa nhà', style: TextStyle(fontSize: 11)),
                      selected: _selectedBuildingFilter == null,
                      onSelected: (_) {
                        setState(() => _selectedBuildingFilter = null);
                      },
                    ),
                    const SizedBox(width: 6),
                    ...uniqueBuildings.map((building) {
                      final isSelected = _selectedBuildingFilter == building;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(building, style: const TextStyle(fontSize: 11)),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedBuildingFilter = isSelected ? null : building;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

          // 3. Nút điều khiển Map (Zoom, Recenter TLU, Chuyển List/Map)
          if (widget.showControls)
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'map_recenter_tlu',
                    tooltip: 'ĐH Thủy Lợi (175 Tây Sơn)',
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.primary,
                    onPressed: _recenterTlu,
                    child: const Icon(Icons.school_rounded, size: 20),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'map_toggle_view',
                    tooltip: _isListView ? 'Xem dạng bản đồ' : 'Xem dạng danh sách',
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.primary,
                    onPressed: () {
                      setState(() => _isListView = !_isListView);
                    },
                    child: Icon(_isListView ? Icons.map_rounded : Icons.view_list_rounded, size: 20),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'map_zoom_in',
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.primary,
                    onPressed: () {
                      final zoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, zoom + 1);
                    },
                    child: const Icon(Icons.add, size: 20),
                  ),
                  const SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: 'map_zoom_out',
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.primary,
                    onPressed: () {
                      final zoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, zoom - 1);
                    },
                    child: const Icon(Icons.remove, size: 20),
                  ),
                ],
              ),
            ),

          // 4. Attribution OpenStreetMap ở góc dưới trái
          Positioned(
            left: 10,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black87 : Colors.white70),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap • TLU Smart DMS',
                style: TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Giao diện bản đồ số FlutterMap
  Widget _buildFlutterMap(
    List<DocumentLocation> locations,
    List<Document> allDocs,
    ThemeData theme,
    bool isDark,
  ) {
    // Tạo danh sách Marker cho từng vị trí
    final markers = locations.map((loc) {
      final docsAtLoc = allDocs.where((d) => d.id == loc.documentId).toList();
      final isSelected = _selectedLocation?.id == loc.id;

      return Marker(
        point: LatLng(loc.latitude, loc.longitude),
        width: 140,
        height: 60,
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedLocation = loc);
            _moveToLocation(loc);
            _showLocationDetailsModal(context, loc, docsAtLoc);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.orange.shade700
                      : theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.book_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        loc.building.replaceAll('ĐH Thủy Lợi', 'TLU'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.location_on_rounded,
                color: isSelected ? Colors.orange.shade700 : theme.colorScheme.primary,
                size: 26,
              ),
            ],
          ),
        ),
      );
    }).toList();

    // Thêm Marker trung tâm TLU Campus
    final campusMarker = Marker(
      point: tluCampusCenter,
      width: 40,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.25),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.teal, width: 2),
        ),
        child: const Icon(Icons.school, color: Colors.teal, size: 20),
      ),
    );

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _selectedLocation != null
            ? LatLng(_selectedLocation!.latitude, _selectedLocation!.longitude)
            : tluCampusCenter,
        initialZoom: 17.2,
        minZoom: 14.0,
        maxZoom: 19.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.studydocs.dms',
        ),
        MarkerLayer(
          markers: [campusMarker, ...markers],
        ),
      ],
    );
  }

  /// Giao diện xem danh sách vị trí khi chuyển chế độ
  Widget _buildListView(
    List<DocumentLocation> locations,
    List<Document> allDocs,
    ThemeData theme,
    bool isDark,
  ) {
    if (locations.isEmpty) {
      return const Center(
        child: Text('Không tìm thấy vị trí tài liệu nào phù hợp bộ lọc.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 60),
      itemCount: locations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final loc = locations[index];
        final docsAtLoc = allDocs.where((d) => d.id == loc.documentId).toList();
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.location_on, color: theme.colorScheme.primary),
            ),
            title: Text(loc.building, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(loc.summary),
            trailing: Chip(
              label: Text('${docsAtLoc.length} tệp', style: const TextStyle(fontSize: 10)),
              padding: EdgeInsets.zero,
            ),
            onTap: () {
              setState(() {
                _isListView = false;
                _selectedLocation = loc;
              });
              _moveToLocation(loc);
            },
          ),
        );
      },
    );
  }
}
