import 'package:uuid/uuid.dart';

/// Mô hình Vị trí vật lý của tài liệu học tập (Physical Document Location)
/// Phục vụ định vị vị trí: Tòa nhà, Tầng, Phòng học, Kệ sách thư viện TLU.
class DocumentLocation {
  final String id;
  final String documentId;
  final String building;
  final String room;
  final String? shelf;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  const DocumentLocation({
    required this.id,
    required this.documentId,
    required this.building,
    required this.room,
    this.shelf,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  /// Chuỗi hiển thị vắn tắt vị trí vật lý
  String get summary {
    final parts = [building, room];
    if (shelf != null && shelf!.trim().isNotEmpty) {
      parts.add('Kệ $shelf');
    }
    return parts.join(' • ');
  }

  /// Chuỗi hiển thị địa chỉ chi tiết
  String get formattedAddress {
    final buffer = StringBuffer();
    if (shelf != null && shelf!.trim().isNotEmpty) {
      buffer.write('$shelf, ');
    }
    buffer.write('$room, $building - Trường ĐH Thủy Lợi (175 Tây Sơn, Đống Đa, Hà Nội)');
    return buffer.toString();
  }

  /// Chuyển đổi sang Map để lưu trữ trong SQLite / Supabase PostgreSQL
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'building': building,
      'room': room,
      'shelf': shelf,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Khởi tạo DocumentLocation từ Map
  factory DocumentLocation.fromMap(Map<String, dynamic> map) {
    return DocumentLocation(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      building: (map['building'] as String?) ?? 'Thư viện TLU',
      room: (map['room'] as String?) ?? 'Phòng đọc',
      shelf: map['shelf'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 21.0073,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 105.8248,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Bản sao với các thuộc tính cập nhật
  DocumentLocation copyWith({
    String? id,
    String? documentId,
    String? building,
    String? room,
    String? shelf,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
  }) {
    return DocumentLocation(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      building: building ?? this.building,
      room: room ?? this.room,
      shelf: shelf ?? this.shelf,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentLocation && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Danh mục vị trí mẫu tại khuôn viên Trường Đại học Thủy Lợi (TLU Campus)
class TluLocationPreset {
  final String title;
  final String building;
  final String room;
  final String defaultShelf;
  final double latitude;
  final double longitude;
  final String description;

  const TluLocationPreset({
    required this.title,
    required this.building,
    required this.room,
    required this.defaultShelf,
    required this.latitude,
    required this.longitude,
    required this.description,
  });

  /// Chuyển thành đối tượng DocumentLocation mới gắn với DocumentId
  DocumentLocation toLocation(String documentId, {String? customShelf}) {
    return DocumentLocation(
      id: const Uuid().v4(),
      documentId: documentId,
      building: building,
      room: room,
      shelf: customShelf ?? defaultShelf,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now(),
    );
  }

  /// Danh sách các vị trí tiêu biểu tại ĐH Thủy Lợi
  static const List<TluLocationPreset> presets = [
    TluLocationPreset(
      title: 'Thư viện TLU - Tầng 2 (Sách Tin học & Công nghệ)',
      building: 'Thư viện ĐH Thủy Lợi',
      room: 'Phòng mượn Tầng 2',
      defaultShelf: 'Kệ TH-02',
      latitude: 21.00742,
      longitude: 105.82491,
      description: 'Khu vực lưu trữ tài liệu tin học, công nghệ thông tin và toán học ứng dụng.',
    ),
    TluLocationPreset(
      title: 'Thư viện TLU - Tầng 3 (Phòng tự học & Luận văn)',
      building: 'Thư viện ĐH Thủy Lợi',
      room: 'Phòng tự học Tầng 3',
      defaultShelf: 'Kệ LV-01',
      latitude: 21.00746,
      longitude: 105.82498,
      description: 'Lưu trữ đồ án tốt nghiệp, đề tài NCKH sinh viên Khoa CNTT.',
    ),
    TluLocationPreset(
      title: 'Nhà A4 - Khoa CNTT (Lab 301 KTPM)',
      building: 'Nhà A4 (Khoa CNTT)',
      room: 'Phòng 301 - Lab Công nghệ Phần mềm',
      defaultShelf: 'Tủ hồ sơ Lab 301',
      latitude: 21.00715,
      longitude: 105.82425,
      description: 'Tài liệu hướng dẫn thực hành môn học và tài liệu phát tay chuyên ngành.',
    ),
    TluLocationPreset(
      title: 'Nhà A4 - Khoa CNTT (Văn phòng Khoa P.204)',
      building: 'Nhà A4 (Khoa CNTT)',
      room: 'Phòng 204 - Văn phòng Khoa',
      defaultShelf: 'Ngăn tài liệu sinh viên',
      latitude: 21.00712,
      longitude: 105.82420,
      description: 'Đề cương chi tiết môn học, tài liệu thực tập và mẫu biểu đăng ký.',
    ),
    TluLocationPreset(
      title: 'Nhà A1 - Tòa Hiệu Bộ (Phòng Đào tạo P.102)',
      building: 'Nhà A1 (Tòa Hiệu Bộ)',
      room: 'Phòng 102 - Phòng Đào tạo',
      defaultShelf: 'Bàn tiếp nhận',
      latitude: 21.00685,
      longitude: 105.82523,
      description: 'Quy chế học vụ, chương trình khung đào tạo và sổ tay sinh viên.',
    ),
    TluLocationPreset(
      title: 'Nhà B1 - Giảng đường (Phòng 205)',
      building: 'Nhà B1 (Giảng đường)',
      room: 'Phòng học B1-205',
      defaultShelf: 'Bàn giảng viên',
      latitude: 21.00780,
      longitude: 105.82455,
      description: 'Khu vực giảng đường học lý thuyết và thảo luận nhóm.',
    ),
    TluLocationPreset(
      title: 'Nhà K1 - Khu học tập đa năng (P.402)',
      building: 'Nhà K1 (Khu Đa Năng)',
      room: 'Phòng học K1-402',
      defaultShelf: 'Tủ tài liệu nhóm',
      latitude: 21.00705,
      longitude: 105.82385,
      description: 'Không gian học tập và workshop công nghệ sinh viên.',
    ),
  ];

  /// Tọa độ trung tâm khuôn viên Trường ĐH Thủy Lợi (175 Tây Sơn)
  static const double tluCenterLatitude = 21.00732;
  static const double tluCenterLongitude = 21.00732 > 0 ? 105.82485 : 105.82485;
}
