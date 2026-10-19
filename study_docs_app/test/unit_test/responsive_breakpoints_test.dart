import 'package:flutter_test/flutter_test.dart';
import 'package:study_docs_app/struct/document_location_model.dart';
import 'package:study_docs_app/struct/responsive_breakpoints.dart';

void main() {
  group('Kiểm thử Đơn vị (Unit Test) - Responsive Breakpoints & Adaptive Engine', () {
    test('TC-RESP-01: Phân loại đúng kích thước Mobile (Width < 600dp)', () {
      expect(ResponsiveBreakpoints.getScreenTypeFromWidth(320), DeviceScreenType.mobile);
      expect(ResponsiveBreakpoints.getScreenTypeFromWidth(390), DeviceScreenType.mobile); // iPhone 14
      expect(ResponsiveBreakpoints.getScreenTypeFromWidth(412), DeviceScreenType.mobile); // Pixel 7
      expect(ResponsiveBreakpoints.getScreenTypeFromWidth(599.9), DeviceScreenType.mobile);
    });

    test('TC-RESP-02: Phân loại đúng kích thước Tablet (600dp <= Width < 1024dp)', () {
      expect(ResponsiveBreakpoints.getScreenTypeFromWidth(600), DeviceScreenType.tablet);
      expect(ResponsiveBreakpoints.getScreenTypeFromWidth(768), DeviceScreenType.tablet); // iPad Mini
      expect(ResponsiveBreakpoints.getScreenTypeFromWidth(820), DeviceScreenType.tablet); // iPad Air
      expect(ResponsiveBreakpoints.getScreenTypeFromWidth(1023.9), DeviceScreenType.tablet);
    });

    test('TC-RESP-03: Phân loại đúng kích thước Desktop / Web rộng (Width >= 1024dp)', () {
      expect(ResponsiveBreakpoints.getScreenTypeFromWidth(1024), DeviceScreenType.desktop);
      expect(ResponsiveBreakpoints.getScreenTypeFromWidth(1280), DeviceScreenType.desktop);
      expect(ResponsiveBreakpoints.getScreenTypeFromWidth(1440), DeviceScreenType.desktop);
      expect(ResponsiveBreakpoints.getScreenTypeFromWidth(1920), DeviceScreenType.desktop); // Full HD
    });

    test('TC-RESP-04: Hằng số điểm ngắt Breakpoints tuân thủ chuẩn Material 3', () {
      expect(ResponsiveBreakpoints.mobileBreakpoint, 600.0);
      expect(ResponsiveBreakpoints.tabletBreakpoint, 1024.0);
      expect(ResponsiveBreakpoints.desktopBreakpoint, 1440.0);
      expect(ResponsiveBreakpoints.maxContentWidth, 1200.0);
    });
  });

  group('Kiểm thử Đơn vị (Unit Test) - DocumentLocation Model & TLU Presets', () {
    test('TC-LOC-01: Khởi tạo, chuyển đổi toMap và fromMap DocumentLocation chính xác', () {
      final now = DateTime.now();
      final loc = DocumentLocation(
        id: 'loc_test_01',
        documentId: 'doc_cse441',
        building: 'Nhà A4 (Khoa CNTT)',
        room: 'Phòng 301 - Lab KTPM',
        shelf: 'Kệ TH-01',
        latitude: 21.00715,
        longitude: 105.82425,
        createdAt: now,
      );

      final map = loc.toMap();
      expect(map['id'], 'loc_test_01');
      expect(map['document_id'], 'doc_cse441');
      expect(map['building'], 'Nhà A4 (Khoa CNTT)');
      expect(map['room'], 'Phòng 301 - Lab KTPM');
      expect(map['shelf'], 'Kệ TH-01');
      expect(map['latitude'], 21.00715);
      expect(map['longitude'], 105.82425);

      final reconstructed = DocumentLocation.fromMap(map);
      expect(reconstructed.id, loc.id);
      expect(reconstructed.documentId, loc.documentId);
      expect(reconstructed.building, loc.building);
      expect(reconstructed.room, loc.room);
      expect(reconstructed.shelf, loc.shelf);
      expect(reconstructed.latitude, loc.latitude);
      expect(reconstructed.longitude, loc.longitude);
    });

    test('TC-LOC-02: Định dạng chuỗi summary và formattedAddress đầy đủ thông tin', () {
      final loc = DocumentLocation(
        id: 'loc_test_02',
        documentId: 'doc_slide',
        building: 'Thư viện ĐH Thủy Lợi',
        room: 'Phòng mượn Tầng 2',
        shelf: 'Kệ TH-02',
        latitude: 21.00742,
        longitude: 105.82491,
        createdAt: DateTime.now(),
      );

      expect(loc.summary, 'Thư viện ĐH Thủy Lợi • Phòng mượn Tầng 2 • Kệ Kệ TH-02');
      expect(loc.formattedAddress.contains('Thư viện ĐH Thủy Lợi'), isTrue);
      expect(loc.formattedAddress.contains('175 Tây Sơn'), isTrue);
    });

    test('TC-LOC-03: Danh mục vị trí TLU Presets có đầy đủ các địa điểm trọng điểm', () {
      expect(TluLocationPreset.presets.length, greaterThanOrEqualTo(5));

      final hasLibrary = TluLocationPreset.presets.any(
        (p) => p.building.contains('Thư viện'),
      );
      final hasA4 = TluLocationPreset.presets.any(
        (p) => p.building.contains('A4') && p.building.contains('CNTT'),
      );
      final hasA1 = TluLocationPreset.presets.any(
        (p) => p.building.contains('A1'),
      );

      expect(hasLibrary, isTrue);
      expect(hasA4, isTrue);
      expect(hasA1, isTrue);
    });

    test('TC-LOC-04: Tọa độ trung tâm khuôn viên ĐH Thủy Lợi chuẩn xác', () {
      expect(TluLocationPreset.tluCenterLatitude, closeTo(21.0073, 0.001));
      expect(TluLocationPreset.tluCenterLongitude, closeTo(105.8248, 0.001));
    });
  });
}
