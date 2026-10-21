import 'package:flutter_test/flutter_test.dart';
import 'package:study_docs_app/database/tables.dart';
import 'package:study_docs_app/struct/document_enums.dart';
import 'package:study_docs_app/struct/document_location_model.dart';
import 'package:study_docs_app/struct/document_model.dart';
import 'package:study_docs_app/struct/borrow_model.dart';
import 'package:study_docs_app/struct/borrow_service.dart';
import 'package:study_docs_app/struct/firebase_messaging_service.dart';
import 'package:study_docs_app/struct/recommendation_service.dart';
import 'package:study_docs_app/struct/responsive_breakpoints.dart';
import 'package:study_docs_app/struct/tag_service.dart';
import 'package:study_docs_app/struct/th2_architecture_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🏆 TH2: BỘ KIỂM THỬ TÍCH HỢP TOÀN DIỆN 6 MỤC (NHÓM TRƯỞNG NGUYỄN VĂN HUỲNH)', () {
    // -------------------------------------------------------------------------
    // MỤC 1: KIẾN TRÚC HỆ THỐNG & MÔ HÌNH DỮ LIỆU HYBRID CLOUD
    // -------------------------------------------------------------------------
    test('TC-TH2-01: [Mục 1] Kiến trúc mô hình dữ liệu đa nền tảng và cầu nối Supabase Schema', () {
      expect(AppTables.tableDocuments, 'documents');
      expect(AppTables.tableSubjects, 'subjects');
      expect(AppTables.tableDocumentLocations, 'document_locations');
      expect(AppTables.tableBorrowRequests, 'borrow_requests');

      // Kiểm tra đầy đủ 7 bảng quan hệ đã thiết kế trong DDL Schema
      expect(TH2ArchitectureBridge.supabaseTables.length, 7);
      expect(TH2ArchitectureBridge.supabaseTables.contains('document_locations'), isTrue);
      expect(TH2ArchitectureBridge.supabaseTables.contains('borrow_requests'), isTrue);

      final doc = Document(
        id: 'doc-arch-001',
        title: 'Giáo trình Kiến trúc Phần mềm',
        description: 'Tài liệu môn Kiến trúc Hệ thống 65KTPM',
        subjectId: 'sub-ktpm',
        documentType: DocumentType.lecture,
        fileFormat: DocumentFormat.pdf,
        tags: const ['KTPM', 'Architecture', 'CleanArchitecture'],
      );

      final location = DocumentLocation(
        id: 'loc-arch-001',
        documentId: doc.id,
        building: 'Nhà A4 TLU',
        room: 'P.305',
        shelf: 'Kệ 2 - Ngăn B',
        latitude: 21.00742,
        longitude: 105.82479,
        createdAt: DateTime.now(),
      );

      final isValid = TH2ArchitectureBridge.validateCrossPlatformPayload(
        document: doc,
        location: location,
      );
      expect(isValid, isTrue);

      final row = TH2ArchitectureBridge.documentToSupabaseRow(doc);
      expect(row['title'], 'Giáo trình Kiến trúc Phần mềm');
      expect(row['document_type'], 'lecture');
      expect(row['tags'], contains('CleanArchitecture'));
    });

    // -------------------------------------------------------------------------
    // MỤC 2: GIAO DIỆN ĐA NỀN TẢNG RESPONSIVE
    // -------------------------------------------------------------------------
    test('TC-TH2-02: [Mục 2] Phân lớp Breakpoints và quy tắc thích ứng Responsive UI', () {
      expect(ResponsiveBreakpoints.getScreenTypeFromWidth(390), DeviceScreenType.mobile);
      expect(ResponsiveBreakpoints.getScreenTypeFromWidth(768), DeviceScreenType.tablet);
      expect(ResponsiveBreakpoints.getScreenTypeFromWidth(1280), DeviceScreenType.desktop);

      expect(ResponsiveBreakpoints.mobileBreakpoint, 600.0);
      expect(ResponsiveBreakpoints.tabletBreakpoint, 1024.0);
      expect(ResponsiveBreakpoints.desktopBreakpoint, 1440.0);
      expect(ResponsiveBreakpoints.maxContentWidth, 1200.0);
    });

    // -------------------------------------------------------------------------
    // MỤC 3: PHÂN LOẠI BẰNG TAG & ĐỊNH VỊ VỊ TRÍ VẬT LÝ TÀI LIỆU (LOCATION)
    // -------------------------------------------------------------------------
    test('TC-TH2-03: [Mục 3] Phân loại thẻ Tag, chuẩn hóa danh mục và gợi ý từ khóa', () {
      final rawTags = ['  Flutter  ', 'DART', 'flutter', 'FLUTTER', 'Mobile App'];
      final normalized = TagService.normalizeTags(rawTags);

      expect(normalized.length, 3);
      expect(normalized, contains('flutter'));
      expect(normalized, contains('dart'));
      expect(normalized, contains('mobile app'));

      final doc = Document(
        id: 'doc-tag-001',
        title: 'Lập trình Ứng dụng Di động với Flutter và Supabase',
        description: 'Hướng dẫn xây dựng ứng dụng Cross-Platform kết nối cơ sở dữ liệu thời gian thực',
        subjectId: 'sub-mobile',
        documentType: DocumentType.lecture,
        tags: const [],
      );

      final candidates = TagService.extractCandidateTags(doc, limit: 10);
      expect(candidates.isNotEmpty, isTrue);
      expect(candidates.any((t) => t == 'ứng' || t == 'dụng' || t == 'flutter'), isTrue);
    });

    test('TC-TH2-04: [Mục 3] Định vị tọa độ khuôn viên ĐH Thủy Lợi (TLU Campus Location)', () {
      final presets = TluLocationPreset.presets;
      expect(presets.length, greaterThanOrEqualTo(5));

      final a4 = presets.firstWhere((p) => p.building.contains('A4'));
      expect(a4.latitude, closeTo(21.00715, 0.001));
      expect(a4.longitude, closeTo(105.82425, 0.001));

      final library = presets.firstWhere((p) => p.building.contains('Thư viện'));
      expect(library.room.contains('Tầng'), isTrue);
    });

    // -------------------------------------------------------------------------
    // MỤC 4: NGHIỆP VỤ MƯỢN / TRẢ TÀI LIỆU & THÔNG BÁO ĐẨY FCM
    // -------------------------------------------------------------------------
    test('TC-TH2-05: [Mục 4] Vòng đời mượn tài liệu (Request -> Approve -> Return) & FCM Notification', () async {
      final borrowService = BorrowService();
      final fcmService = FirebaseMessagingService();

      final request = await borrowService.createBorrowRequest(
        documentId: 'doc-borrow-th2',
        documentTitle: 'Sách Thuật toán Nâng cao',
        borrowerId: 'user_letuan',
        borrowerEmail: '2151060296@e.tlu.edu.vn',
        borrowerName: 'Lê Anh Tuấn',
        ownerId: 'user_huynh',
        ownerEmail: '2351170599@e.tlu.edu.vn',
        ownerName: 'Nguyễn Văn Huỳnh',
        dueDate: DateTime.now().add(const Duration(days: 7)),
        note: 'Em xin mượn ôn thi kết thúc học phần',
      );

      expect(request.status, BorrowStatus.pending);

      // Mô phỏng FCM thông báo tới chủ sở hữu (được kích hoạt tự động khi tạo yêu cầu)
      final ownerNotifs = fcmService.currentNotifications
          .where((n) => n.recipientEmail == '2351170599@e.tlu.edu.vn')
          .toList();
      expect(ownerNotifs.isNotEmpty, isTrue);

      // Chủ sở hữu phê duyệt
      final approved = await borrowService.approveBorrowRequest(requestId: request.id);
      expect(approved.status, BorrowStatus.approved);

      // Hoàn trả tài liệu
      final returned = await borrowService.returnDocument(requestId: request.id);
      expect(returned.status, BorrowStatus.returned);
    });

    // -------------------------------------------------------------------------
    // MỤC 5: THUẬT TOÁN GỢI Ý TÀI LIỆU (RECOMMENDATION ENGINE)
    // -------------------------------------------------------------------------
    test('TC-TH2-06: [Mục 5] Thuật toán Recommendation dựa trên Jaccard Tag Similarity', () {
      final targetDoc = Document(
        id: 'doc-target',
        title: 'Giáo trình Flutter Nâng cao',
        subjectId: 'sub-mobile',
        documentType: DocumentType.lecture,
        tags: const ['flutter', 'dart', 'cross-platform', 'mobile'],
      );

      final allDocs = [
        Document(
          id: 'doc-similar-1',
          title: 'Bài tập Lớn Flutter & Firebase',
          subjectId: 'sub-mobile',
          documentType: DocumentType.assignment,
          tags: const ['flutter', 'dart', 'firebase'],
        ),
        Document(
          id: 'doc-different',
          title: 'Giải tích 1 cho Kỹ sư',
          subjectId: 'sub-math',
          documentType: DocumentType.lecture,
          tags: const ['toan', 'giaitich', 'daiso'],
        ),
      ];

      final related = RecommendationService.getRelatedDocuments(targetDoc, allDocs);
      expect(related.isNotEmpty, isTrue);
      expect(related.first.document.id, 'doc-similar-1');
      expect(related.first.score, greaterThan(0.0));
    });

    // -------------------------------------------------------------------------
    // MỤC 6: KIỂM THỬ TÍCH HỢP END-TO-END PIPELINE TOÀN DIỆN
    // -------------------------------------------------------------------------
    test('TC-TH2-07: [Mục 6] Luồng tích hợp End-to-End toàn diện 6 mục checklist TH2', () {
      // 1. Khởi tạo tài liệu với Tag phân loại (Mục 1 & 3)
      final doc = Document(
        id: 'doc-e2e-th2',
        title: 'Tài liệu Tổng ôn Hệ thống Quản trị CSDL',
        subjectId: 'sub-db',
        documentType: DocumentType.lecture,
        tags: const ['sql', 'database', 'postgres', 'supabase'],
      );

      // 2. Gán vị trí vật lý tại ĐH Thủy Lợi (Mục 3)
      final location = DocumentLocation(
        id: 'loc-e2e-th2',
        documentId: doc.id,
        building: 'Nhà A4 - Giảng đường',
        room: 'P.402',
        shelf: 'Kệ A - Ngăn 1',
        latitude: 21.00742,
        longitude: 105.82479,
        createdAt: DateTime.now(),
      );

      // 3. Kiểm tra tính hợp lệ payload trước khi đẩy đám mây (Mục 1)
      final payloadOk = TH2ArchitectureBridge.validateCrossPlatformPayload(
        document: doc,
        location: location,
      );
      expect(payloadOk, isTrue);

      // 4. Kiểm tra Responsive Adaptability (Mục 2)
      final screenType = ResponsiveBreakpoints.getScreenTypeFromWidth(768);
      expect(screenType, DeviceScreenType.tablet);

      // 5. Kiểm tra Gợi ý Recommendation từ tập dữ liệu (Mục 5)
      final samplePool = [
        doc,
        Document(
          id: 'doc-rel-1',
          title: 'Thực hành PostgreSQL và Supabase CSDL',
          subjectId: 'sub-db',
          documentType: DocumentType.assignment,
          tags: const ['postgres', 'supabase', 'sql'],
        ),
      ];
      final recs = RecommendationService.getRelatedDocuments(doc, samplePool);
      expect(recs.isNotEmpty, isTrue);
      expect(recs.first.document.id, 'doc-rel-1');

      // 6. Metadata Nhóm trưởng nghiệm thu (Mục 6)
      final metadata = TH2ArchitectureBridge.architectureMetadata;
      expect(metadata['author'], 'Nguyễn Văn Huỳnh');
      expect(metadata['role'], contains('Nhóm trưởng'));
    });
  });
}
