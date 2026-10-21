import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_docs_app/struct/document_location_model.dart';
import 'package:study_docs_app/struct/responsive_breakpoints.dart';
import 'package:study_docs_app/widgets/document_location_picker.dart';
import 'package:study_docs_app/widgets/responsive_layout_scaffold.dart';

void main() {
  group('Kiểm thử Giao diện (Widget Tests) - ResponsiveBreakpoints & Containers', () {
    testWidgets('TC-WIDGET-01: ResponsiveContentContainer giới hạn chiều rộng tối đa chính xác', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveContentContainer(
              maxWidth: 800,
              padding: EdgeInsets.zero,
              child: Container(
                key: const ValueKey('inner_container'),
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      final innerBox = tester.renderObject(find.byKey(const ValueKey('inner_container'))) as RenderBox;
      expect(innerBox.size.width, equals(800.0));
    });
  });

  group('Kiểm thử Giao diện (Widget Tests) - ResponsiveLayoutScaffold Adaptive Layouts', () {
    final sampleDestinations = [
      const ResponsiveDestination(icon: Icons.dashboard_rounded, label: 'Tổng quan'),
      const ResponsiveDestination(icon: Icons.folder_rounded, label: 'Tài liệu'),
      const ResponsiveDestination(icon: Icons.map_rounded, label: 'Bản đồ'),
    ];

    testWidgets('TC-WIDGET-02: Màn hình Mobile hiển thị NavigationBar ở thanh đáy', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveLayoutScaffold(
            title: 'Smart DMS Mobile',
            currentIndex: 0,
            onNavigationIndexChanged: (_) {},
            destinations: sampleDestinations,
            body: const Text('Mobile Content'),
          ),
        ),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Tổng quan'), findsOneWidget);
      expect(find.text('Tài liệu'), findsOneWidget);
      expect(find.text('Bản đồ'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-03: Màn hình Tablet hiển thị NavigationRail thanh ray bên sườn', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveLayoutScaffold(
            title: 'Smart DMS Tablet',
            currentIndex: 0,
            onNavigationIndexChanged: (_) {},
            destinations: sampleDestinations,
            body: const Text('Tablet Content'),
          ),
        ),
      );

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Tổng quan'), findsOneWidget);
      expect(find.text('Tài liệu'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-04: Màn hình Desktop hiển thị Sidebar mở rộng nhận diện thương hiệu', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveLayoutScaffold(
            title: 'Smart DMS Desktop',
            currentIndex: 0,
            onNavigationIndexChanged: (_) {},
            destinations: sampleDestinations,
            body: const Text('Desktop Content'),
          ),
        ),
      );

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Smart DMS'), findsOneWidget);
      expect(find.text('ĐH Thủy Lợi • TH2'), findsOneWidget);
      expect(find.text('Tổng quan'), findsOneWidget);
    });
  });

  group('Kiểm thử Giao diện (Widget Tests) - DocumentLocationPicker', () {
    testWidgets('TC-WIDGET-05: Hiển thị trạng thái chưa chọn vị trí và mở BottomSheet danh mục TLU Presets', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      DocumentLocation? selectedLoc;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentLocationPicker(
              documentId: 'doc_demo_widget_test',
              initialLocation: null,
              onLocationChanged: (loc) {
                selectedLoc = loc;
              },
            ),
          ),
        ),
      );

      expect(find.text('Vị trí vật lý tài liệu (TLU Campus)'), findsOneWidget);
      expect(find.text('Chưa gán vị trí (Tòa nhà, Phòng học, Kệ sách)'), findsOneWidget);
      expect(find.text('Chọn vị trí'), findsOneWidget);

      // Nhấn nút Chọn vị trí để mở BottomSheet
      await tester.tap(find.text('Chọn vị trí'));
      await tester.pumpAndSettle();

      // Kiểm tra sự xuất hiện của tiêu đề Modal và danh mục TLU Presets
      expect(find.text('Định vị vị trí vật lý tài liệu'), findsOneWidget);
      expect(find.text('📍 Chọn nhanh vị trí tại ĐH Thủy Lợi:'), findsOneWidget);
      expect(find.textContaining('Nhà A4'), findsWidgets);

      // Chọn preset Nhà A4
      await tester.tap(find.textContaining('Nhà A4').first);
      await tester.pumpAndSettle();

      // Xác nhận chọn vị trí
      expect(find.text('Xác nhận vị trí'), findsOneWidget);
      await tester.tap(find.text('Xác nhận vị trí'));
      await tester.pumpAndSettle();

      // Callback được gọi với thông tin vị trí TLU
      expect(selectedLoc, isNotNull);
      expect(selectedLoc!.building, contains('A4'));
    });

    testWidgets('TC-WIDGET-06: Hiển thị thông tin vị trí đã được cấu hình đầy đủ', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final presetLocation = DocumentLocation(
        id: 'loc_w_01',
        documentId: 'doc_w_01',
        building: 'Nhà B1 (Phòng Thí Nghiệm)',
        room: 'Phòng 204 - Lab Mạng',
        shelf: 'Kệ LAB-03',
        latitude: 21.0076,
        longitude: 105.8245,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentLocationPicker(
              documentId: 'doc_w_01',
              initialLocation: presetLocation,
              onLocationChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Nhà B1 (Phòng Thí Nghiệm)'), findsOneWidget);
      expect(find.textContaining('Phòng 204 - Lab Mạng'), findsOneWidget);
      expect(find.textContaining('Kệ LAB-03'), findsOneWidget);
      expect(find.textContaining('175 Tây Sơn'), findsOneWidget);
      expect(find.textContaining('GPS: 21.00760, 105.82450'), findsOneWidget);
    });
  });
}
