import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_docs_app/database/app_database.dart';
import 'package:study_docs_app/pages/borrow_management_page.dart';
import 'package:study_docs_app/struct/borrow_model.dart';
import 'package:study_docs_app/struct/borrow_service.dart';
import 'package:study_docs_app/struct/firebase_messaging_service.dart';
import 'package:study_docs_app/theme.dart';

void main() {
  group('1. Unit Test Mô hình dữ liệu Mượn / Trả (BorrowModel & BorrowStatus)', () {
    test('BorrowStatus extension chuyển đổi chuỗi chính xác', () {
      expect(BorrowStatusExtension.fromString('pending'), BorrowStatus.pending);
      expect(BorrowStatusExtension.fromString('approved'), BorrowStatus.approved);
      expect(BorrowStatusExtension.fromString('borrowed'), BorrowStatus.borrowed);
      expect(BorrowStatusExtension.fromString('returned'), BorrowStatus.returned);
      expect(BorrowStatusExtension.fromString('rejected'), BorrowStatus.rejected);
      expect(BorrowStatusExtension.fromString('cancelled'), BorrowStatus.cancelled);
      expect(BorrowStatusExtension.fromString('unknown_val'), BorrowStatus.pending);

      expect(BorrowStatus.pending.displayName, 'Chờ duyệt');
      expect(BorrowStatus.approved.displayName, 'Đã duyệt');
      expect(BorrowStatus.borrowed.displayName, 'Đang mượn');
      expect(BorrowStatus.returned.displayName, 'Đã trả');
      expect(BorrowStatus.rejected.displayName, 'Từ chối');
    });

    test('BorrowRequest toMap và fromMap roundtrip toàn vẹn dữ liệu', () {
      final now = DateTime.now();
      final dueDate = now.add(const Duration(days: 7));
      final request = BorrowRequest(
        id: 'test_req_1',
        documentId: 'doc_101',
        documentTitle: 'Giáo trình Kiến trúc Phần mềm',
        borrowerId: '2151060296',
        borrowerEmail: '2151060296@e.tlu.edu.vn',
        borrowerName: 'Lê Anh Tuấn',
        ownerId: '2351170599',
        ownerEmail: '2351170599@e.tlu.edu.vn',
        ownerName: 'Nguyễn Văn Huỳnh',
        status: BorrowStatus.pending,
        requestDate: now,
        dueDate: dueDate,
        note: 'Cần mượn gấp để làm bài tập lớn',
      );

      final map = request.toMap();
      expect(map['id'], 'test_req_1');
      expect(map['document_id'], 'doc_101');
      expect(map['document_title'], 'Giáo trình Kiến trúc Phần mềm');
      expect(map['borrower_email'], '2151060296@e.tlu.edu.vn');
      expect(map['status'], 'pending');

      final deserialized = BorrowRequest.fromMap(map);
      expect(deserialized.id, request.id);
      expect(deserialized.documentId, request.documentId);
      expect(deserialized.borrowerEmail, request.borrowerEmail);
      expect(deserialized.status, BorrowStatus.pending);
      expect(deserialized.note, request.note);
      expect(deserialized.isOverdue, isFalse);
    });

    test('Kiểm tra logic phát hiện quá hạn (isOverdue) chính xác', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      final futureDate = DateTime.now().add(const Duration(days: 5));

      final overdueReq = BorrowRequest(
        id: 'overdue_1',
        documentId: 'doc_1',
        documentTitle: 'Sách quá hạn',
        borrowerId: 'u1',
        borrowerEmail: 'u1@e.tlu.edu.vn',
        borrowerName: 'SV1',
        ownerId: 'u2',
        ownerEmail: 'u2@e.tlu.edu.vn',
        ownerName: 'SV2',
        status: BorrowStatus.borrowed,
        requestDate: pastDate.subtract(const Duration(days: 10)),
        dueDate: pastDate,
      );

      final normalReq = overdueReq.copyWith(
        id: 'normal_1',
        dueDate: futureDate,
      );

      expect(overdueReq.isOverdue, isTrue);
      expect(normalReq.isOverdue, isFalse);
    });
  });

  group('2. Unit Test Dịch vụ Thông Báo Đẩy FCM (FirebaseMessagingService)', () {
    late FirebaseMessagingService fcm;

    setUp(() {
      fcm = FirebaseMessagingService();
      fcm.clearAll();
    });

    test('Bắn thông báo khi có yêu cầu mượn mới và kiểm tra số đếm chưa đọc', () async {
      final req = BorrowRequest(
        id: 'req_fcm_1',
        documentId: 'doc_1',
        documentTitle: 'Giáo trình Mạng máy tính',
        borrowerId: '2151060296',
        borrowerEmail: '2151060296@e.tlu.edu.vn',
        borrowerName: 'Lê Anh Tuấn',
        ownerId: '2351170599',
        ownerEmail: '2351170599@e.tlu.edu.vn',
        ownerName: 'Nguyễn Văn Huỳnh',
        status: BorrowStatus.pending,
        requestDate: DateTime.now(),
      );

      await fcm.notifyBorrowRequested(request: req);

      expect(fcm.currentNotifications.isNotEmpty, isTrue);
      expect(fcm.unreadCount, 1);
      expect(fcm.currentNotifications.first.recipientEmail, '2351170599@e.tlu.edu.vn');
      expect(fcm.currentNotifications.first.type, NotificationType.borrowRequest);

      // Đánh dấu đã đọc
      fcm.markAsRead(fcm.currentNotifications.first.id);
      expect(fcm.unreadCount, 0);
    });

    test('Bắn thông báo phê duyệt và từ chối yêu cầu', () async {
      final req = BorrowRequest(
        id: 'req_fcm_2',
        documentId: 'doc_2',
        documentTitle: 'Slide Lập trình Web',
        borrowerId: '2151060296',
        borrowerEmail: '2151060296@e.tlu.edu.vn',
        borrowerName: 'Lê Anh Tuấn',
        ownerId: '2251172394',
        ownerEmail: '2251172394@e.tlu.edu.vn',
        ownerName: 'Nguyễn Trung Kiên',
        status: BorrowStatus.approved,
        requestDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 7)),
      );

      await fcm.notifyBorrowApproved(request: req);
      expect(fcm.currentNotifications.first.type, NotificationType.borrowApproved);
      expect(fcm.currentNotifications.first.recipientEmail, '2151060296@e.tlu.edu.vn');

      await fcm.notifyBorrowRejected(request: req, reason: 'Tài liệu đang bận');
      expect(fcm.currentNotifications.first.type, NotificationType.borrowRejected);
      expect(fcm.currentNotifications.first.body, contains('Tài liệu đang bận'));
    });
  });

  group('3. Unit Test Nghiệp vụ Mượn / Trả (BorrowService)', () {
    late BorrowService borrowService;
    late FirebaseMessagingService fcm;

    setUp(() async {
      fcm = FirebaseMessagingService();
      fcm.clearAll();
      borrowService = BorrowService(fcm: fcm);
      await borrowService.initialize();
    });

    test('Gửi yêu cầu mượn tài liệu mới thành công', () async {
      final newReq = await borrowService.createBorrowRequest(
        documentId: 'doc_cs_01',
        documentTitle: 'Cấu trúc Dữ liệu & Giải thuật',
        borrowerId: '2151060296',
        borrowerEmail: '2151060296@e.tlu.edu.vn',
        borrowerName: 'Lê Anh Tuấn',
        ownerId: '2351170629',
        ownerEmail: '2351170629@e.tlu.edu.vn',
        ownerName: 'Trần Anh Tuấn',
        note: 'Xin mượn tham khảo phần Cây nhị phân tìm kiếm',
      );

      expect(newReq.id, isNotEmpty);
      expect(newReq.status, BorrowStatus.pending);
      expect(newReq.documentTitle, 'Cấu trúc Dữ liệu & Giải thuật');

      // Kiểm tra trong danh sách gửi đi của người mượn
      final sentList = borrowService.getSentRequests('2151060296@e.tlu.edu.vn');
      expect(sentList.any((r) => r.id == newReq.id), isTrue);

      // Kiểm tra trong danh sách nhận được của chủ tài liệu
      final receivedList = borrowService.getReceivedRequests('2351170629@e.tlu.edu.vn');
      expect(receivedList.any((r) => r.id == newReq.id), isTrue);
    });

    test('Chủ sở hữu phê duyệt yêu cầu mượn thành công', () async {
      final req = await borrowService.createBorrowRequest(
        documentId: 'doc_db_02',
        documentTitle: 'Hệ Quản trị Cơ sở Dữ liệu',
        borrowerId: '2251172394',
        borrowerEmail: '2251172394@e.tlu.edu.vn',
        borrowerName: 'Nguyễn Trung Kiên',
        ownerId: '2151060296',
        ownerEmail: '2151060296@e.tlu.edu.vn',
        ownerName: 'Lê Anh Tuấn',
      );

      final newDue = DateTime.now().add(const Duration(days: 10));
      final approved = await borrowService.approveBorrowRequest(
        requestId: req.id,
        dueDate: newDue,
      );

      expect(approved.status, BorrowStatus.approved);
      expect(approved.approvedDate, isNotNull);
      expect(approved.dueDate?.day, newDue.day);
    });

    test('Chuyển trạng thái sang đang mượn và hoàn trả tài liệu', () async {
      final req = await borrowService.createBorrowRequest(
        documentId: 'doc_ai_03',
        documentTitle: 'Trí tuệ Nhân tạo Cơ bản',
        borrowerId: '2151060296',
        borrowerEmail: '2151060296@e.tlu.edu.vn',
        borrowerName: 'Lê Anh Tuấn',
        ownerId: '2351170599',
        ownerEmail: '2351170599@e.tlu.edu.vn',
        ownerName: 'Nguyễn Văn Huỳnh',
      );

      await borrowService.approveBorrowRequest(requestId: req.id);
      final borrowed = await borrowService.confirmBorrowed(requestId: req.id);
      expect(borrowed.status, BorrowStatus.borrowed);

      final returned = await borrowService.returnDocument(requestId: req.id);
      expect(returned.status, BorrowStatus.returned);
      expect(returned.returnedDate, isNotNull);
    });

    test('Từ chối yêu cầu mượn kèm lý do từ chối', () async {
      final req = await borrowService.createBorrowRequest(
        documentId: 'doc_os_04',
        documentTitle: 'Nguyên lý Hệ điều hành',
        borrowerId: '2351170629',
        borrowerEmail: '2351170629@e.tlu.edu.vn',
        borrowerName: 'Trần Anh Tuấn',
        ownerId: '2151060296',
        ownerEmail: '2151060296@e.tlu.edu.vn',
        ownerName: 'Lê Anh Tuấn',
      );

      final rejected = await borrowService.rejectBorrowRequest(
        requestId: req.id,
        reason: 'Hiện tại tài liệu đang được sử dụng trên lớp học',
      );

      expect(rejected.status, BorrowStatus.rejected);
      expect(rejected.rejectionReason, 'Hiện tại tài liệu đang được sử dụng trên lớp học');
    });
  });

  group('4. Widget Test Giao diện Quản Lý Mượn/Trả (BorrowManagementPage)', () {
    testWidgets('BorrowManagementPage render đủ AppBar, TabBar 2 tab và Banner tài khoản',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const BorrowManagementPage(
            initialEmail: '2151060296@e.tlu.edu.vn',
          ),
        ),
      );
      await tester.pump();

      // Kiểm tra tiêu đề và thông tin thành viên
      expect(find.text('Quản Lý Mượn & Chia Sẻ'), findsOneWidget);
      expect(find.textContaining('Mục 4 TH2 • Lê Anh Tuấn'), findsOneWidget);
      expect(find.textContaining('Đang xem với tư cách: Lê Anh Tuấn'), findsOneWidget);

      // Kiểm tra 2 tab chính
      expect(find.textContaining('Yêu cầu nhận được'), findsOneWidget);
      expect(find.textContaining('Đã gửi'), findsOneWidget);

      // Kiểm tra biểu tượng chuông thông báo FCM
      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);

      // Kiểm tra biểu tượng chuyển đổi tài khoản Demo
      expect(find.byIcon(Icons.switch_account_rounded), findsOneWidget);
    });
  });
}
