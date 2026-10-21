import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../struct/document_location_model.dart';

/// Thành phần chọn và thiết lập vị trí vật lý của tài liệu tại ĐH Thủy Lợi (TH2)
/// Phụ trách: NGUYỄN TRUNG KIÊN (MSSV: 2251172394)
class DocumentLocationPicker extends StatefulWidget {
  final DocumentLocation? initialLocation;
  final String documentId;
  final ValueChanged<DocumentLocation?> onLocationChanged;
  final bool isReadOnly;

  const DocumentLocationPicker({
    super.key,
    this.initialLocation,
    required this.documentId,
    required this.onLocationChanged,
    this.isReadOnly = false,
  });

  @override
  State<DocumentLocationPicker> createState() => _DocumentLocationPickerState();

  /// Tiện ích hiển thị Modal BottomSheet chọn nhanh vị trí
  static Future<DocumentLocation?> showLocationBottomSheet({
    required BuildContext context,
    required String documentId,
    DocumentLocation? currentLocation,
  }) async {
    return showModalBottomSheet<DocumentLocation?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _LocationPickerBottomSheet(
          documentId: documentId,
          initialLocation: currentLocation,
        );
      },
    );
  }
}

class _DocumentLocationPickerState extends State<DocumentLocationPicker> {
  late DocumentLocation? _location;

  @override
  void initState() {
    super.initState();
    _location = widget.initialLocation;
  }

  @override
  void didUpdateWidget(covariant DocumentLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLocation != oldWidget.initialLocation) {
      _location = widget.initialLocation;
    }
  }

  void _openPickerModal() async {
    if (widget.isReadOnly) return;
    final result = await DocumentLocationPicker.showLocationBottomSheet(
      context: context,
      documentId: widget.documentId,
      currentLocation: _location,
    );

    if (result != null || result == null) {
      setState(() => _location = result);
      widget.onLocationChanged(result);
    }
  }

  void _clearLocation() {
    setState(() => _location = null);
    widget.onLocationChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_location == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: InkWell(
          onTap: widget.isReadOnly ? null : _openPickerModal,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.add_location_alt_outlined,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vị trí vật lý tài liệu (TLU Campus)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Chưa gán vị trí (Tòa nhà, Phòng học, Kệ sách)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.isReadOnly)
                  FilledButton.tonal(
                    onPressed: _openPickerModal,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text('Chọn vị trí', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final loc = _location!;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
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
                        loc.building,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loc.summary,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.isReadOnly) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Chỉnh sửa vị trí',
                    onPressed: _openPickerModal,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    tooltip: 'Xóa vị trí',
                    onPressed: _clearLocation,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed_rounded, size: 14, color: Colors.teal),
                  const SizedBox(width: 6),
                  Text(
                    'GPS: ${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Text(
                    'ĐH Thủy Lợi (175 Tây Sơn)',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal BottomSheet chứa Form tùy biến và danh sách vị trí nhanh TLU
class _LocationPickerBottomSheet extends StatefulWidget {
  final String documentId;
  final DocumentLocation? initialLocation;

  const _LocationPickerBottomSheet({
    required this.documentId,
    this.initialLocation,
  });

  @override
  State<_LocationPickerBottomSheet> createState() => _LocationPickerBottomSheetState();
}

class _LocationPickerBottomSheetState extends State<_LocationPickerBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _buildingController;
  late TextEditingController _roomController;
  late TextEditingController _shelfController;
  late double _latitude;
  late double _longitude;
  TluLocationPreset? _selectedPreset;

  @override
  void initState() {
    super.initState();
    final init = widget.initialLocation;
    _buildingController = TextEditingController(text: init?.building ?? '');
    _roomController = TextEditingController(text: init?.room ?? '');
    _shelfController = TextEditingController(text: init?.shelf ?? '');
    _latitude = init?.latitude ?? TluLocationPreset.tluCenterLatitude;
    _longitude = init?.longitude ?? TluLocationPreset.tluCenterLongitude;

    if (init != null) {
      for (final p in TluLocationPreset.presets) {
        if (p.building == init.building && p.room == init.room) {
          _selectedPreset = p;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _buildingController.dispose();
    _roomController.dispose();
    _shelfController.dispose();
    super.dispose();
  }

  void _applyPreset(TluLocationPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _buildingController.text = preset.building;
      _roomController.text = preset.room;
      _shelfController.text = preset.defaultShelf;
      _latitude = preset.latitude;
      _longitude = preset.longitude;
    });
  }

  void _saveLocation() {
    if (!_formKey.currentState!.validate()) return;

    final location = DocumentLocation(
      id: widget.initialLocation?.id ?? const Uuid().v4(),
      documentId: widget.documentId,
      building: _buildingController.text.trim(),
      room: _roomController.text.trim(),
      shelf: _shelfController.text.trim().isEmpty ? null : _shelfController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      createdAt: widget.initialLocation?.createdAt ?? DateTime.now(),
    );

    Navigator.of(context).pop(location);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
                  Icon(Icons.pin_drop_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Định vị vị trí vật lý tài liệu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Thiết lập thông tin vị trí lưu trữ tại khuôn viên Trường ĐH Thủy Lợi',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),

              // Danh sách chọn nhanh vị trí TLU
              const Text(
                '📍 Chọn nhanh vị trí tại ĐH Thủy Lợi:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: TluLocationPreset.presets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final preset = TluLocationPreset.presets[index];
                    final isSelected = _selectedPreset == preset;
                    return ChoiceChip(
                      label: Text(
                        preset.title.split(' - ')[0],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: theme.colorScheme.primaryContainer,
                      onSelected: (_) => _applyPreset(preset),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Trường Tòa nhà (Building)
              TextFormField(
                controller: _buildingController,
                decoration: const InputDecoration(
                  labelText: 'Tòa nhà / Khu giảng đường *',
                  hintText: 'Ví dụ: Thư viện ĐH Thủy Lợi, Nhà A4...',
                  prefixIcon: Icon(Icons.business_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tên tòa nhà';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Trường Phòng học (Room)
              TextFormField(
                controller: _roomController,
                decoration: const InputDecoration(
                  labelText: 'Phòng học / Khu vực lưu trữ *',
                  hintText: 'Ví dụ: P.301 Lab KTPM, Phòng đọc tầng 2...',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập phòng học hoặc khu vực';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Trường Kệ sách (Shelf)
              TextFormField(
                controller: _shelfController,
                decoration: const InputDecoration(
                  labelText: 'Kệ sách / Tủ tài liệu (Tùy chọn)',
                  hintText: 'Ví dụ: Kệ TH-02, Ngăn A-1, Tủ tài liệu',
                  prefixIcon: Icon(Icons.shelves),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              // Tọa độ GPS info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location_rounded, color: Colors.teal, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tọa độ GPS bản đồ TLU',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.teal,
                            ),
                          ),
                          Text(
                            'Lat: ${_latitude.toStringAsFixed(5)} • Long: ${_longitude.toStringAsFixed(5)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _latitude = TluLocationPreset.tluCenterLatitude;
                          _longitude = TluLocationPreset.tluCenterLongitude;
                        });
                      },
                      child: const Text('Mặc định', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Nút Hành động
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _saveLocation,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Xác nhận vị trí'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
