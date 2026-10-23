import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/tables.dart';
import 'borrow_model.dart';
import 'firebase_messaging_service.dart';

/// Dịch vụ Quản lý Mượn / Trả và Chia sẻ Tài liệu (Borrow & Sharing Service)
/// Hệ thống: Smart DMS TH2 (Mobile CSE441)
/// Phụ trách: Lê Anh Tuấn (MSV: 2151060296) - Nhóm 16 (Lớp 65KTPM - ĐH Thủy Lợi)
/// Nhánh Git: letuan-th2-borrow-sharing
class BorrowService {
  static final BorrowService _instance = BorrowService._internal();
  factory BorrowService({AppDatabase? db, FirebaseMessagingService? fcm}) {
    if (db != null) _instance._appDb = db;
    if (fcm != null) _instance._fcm = fcm;
    return _instance;
  }
  BorrowService._internal();

  AppDatabase _appDb = AppDatabase.instance;
  FirebaseMessagingService _fcm = FirebaseMessagingService();
  final _uuid = const Uuid();

  final List<BorrowRequest> _memoryRequests = [];
  final StreamController<List<BorrowRequest>> _requestsStreamController =
      StreamController<List<BorrowRequest>>.broadcast();

  bool _isInitialized = false;

  Stream<List<BorrowRequest>> get requestsStream =>
      _requestsStreamController.stream;

  List<BorrowRequest> get allRequests => List.unmodifiable(_memoryRequests);

  static const String _storageKey = 'cached_borrow_requests_v1';

  /// Khởi tạo và nạp danh sách yêu cầu mượn
  Future<void> initialize() async {
    if (_isInitialized) {
      await reloadFromStorage();
      return;
    }

    // 1. Thử nạp từ LocalStorage / SharedPreferences (bền vững trên Web & đa tab)
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_storageKey);
      if (savedJson != null && savedJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(savedJson);
        _memoryRequests.clear();
        for (final item in list) {
          _memoryRequests.add(BorrowRequest.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    } catch (e) {
      debugPrint('[BorrowService] Cảnh báo đọc SharedPreferences: $e');
    }

    // 2. Nếu LocalStorage chưa có, nạp từ SQLite
    if (_memoryRequests.isEmpty) {
      try {
        final db = await _appDb.database;
        if (db != null) {
          final List<Map<String, dynamic>> maps =
              await db.query(AppTables.tableBorrowRequests, orderBy: 'request_date DESC');
          for (final m in maps) {
            _memoryRequests.add(BorrowRequest.fromMap(m));
          }
        }
      } catch (e) {
        debugPrint('[BorrowService] Cảnh báo nạp DB (chuyển sang cache bộ nhớ): $e');
      }
    }

    // 3. Nếu chưa có dữ liệu mượn nào, nạp dữ liệu mẫu ban đầu cho sinh viên Thủy Lợi
    if (_memoryRequests.isEmpty) {
      await _seedSampleBorrowRequests();
    } else {
      await _saveToStorage();
    }

    _isInitialized = true;
    _notifyWatchers();
  }

  Future<void> reloadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_storageKey);
      if (savedJson != null && savedJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(savedJson);
        final loaded = list.map((item) => BorrowRequest.fromMap(Map<String, dynamic>.from(item))).toList();
        if (loaded.isNotEmpty && (loaded.length != _memoryRequests.length ||
            loaded.first.id != (_memoryRequests.isEmpty ? '' : _memoryRequests.first.id))) {
          _memoryRequests.clear();
          _memoryRequests.addAll(loaded);
          _notifyWatchers();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_memoryRequests.map((r) => r.toMap()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('[BorrowService] Lỗi lưu SharedPreferences: $e');
    }
  }

  void _notifyWatchers() {
    _requestsStreamController.add(List.unmodifiable(_memoryRequests));
  }

  /// Nạp các yêu cầu mượn mẫu thực tế giữa các thành viên Nhóm 16
  Future<void> _seedSampleBorrowRequests() async {
    final now = DateTime.now();
    final sampleRequests = [
      BorrowRequest(
        id: 'req_sample_1',
        documentId: 'doc_1',
        documentTitle: 'Giáo trình Kiến trúc Máy tính & Vi xử lý',
        borrowerId: 'user_huynh',
        borrowerEmail: '2351170599@e.tlu.edu.vn',
        borrowerName: 'Nguyễn Văn Huỳnh',
        ownerId: 'user_letuan',
        ownerEmail: '2151060296@e.tlu.edu.vn',
        ownerName: 'Lê Anh Tuấn',
        status: BorrowStatus.pending,
        requestDate: now.subtract(const Duration(hours: 2)),
        dueDate: now.add(const Duration(days: 7)),
        note: 'Em muốn mượn bản cứng giáo trình để ôn thi giữa kỳ môn Kiến trúc máy tính.',
      ),
      BorrowRequest(
        id: 'req_sample_2',
        documentId: 'doc_2',
        documentTitle: 'Slide Bài giảng Lập trình Thiết bị Di động (Flutter)',
        borrowerId: 'user_letuan',
        borrowerEmail: '2151060296@e.tlu.edu.vn',
        borrowerName: 'Lê Anh Tuấn',
        ownerId: 'user_kien',
        ownerEmail: '2251172394@e.tlu.edu.vn',
        ownerName: 'Nguyễn Trung Kiên',
        status: BorrowStatus.approved,
        requestDate: now.subtract(const Duration(days: 1)),
        approvedDate: now.subtract(const Duration(hours: 18)),
        dueDate: now.add(const Duration(days: 5)),
        note: 'Mình mượn tài liệu bài giảng để nghiên cứu luồng Provider và Responsive UI.',
      ),
      BorrowRequest(
        id: 'req_sample_3',
        documentId: 'doc_3',
        documentTitle: 'Đề thi Mạng máy tính K65 - Khoa CNTT',
        borrowerId: 'user_trantuan',
        borrowerEmail: '2351170629@e.tlu.edu.vn',
        borrowerName: 'Trần Anh Tuấn',
        ownerId: 'user_letuan',
        ownerEmail: '2151060296@e.tlu.edu.vn',
        ownerName: 'Lê Anh Tuấn',
        status: BorrowStatus.borrowed,
        requestDate: now.subtract(const Duration(days: 3)),
        approvedDate: now.subtract(const Duration(days: 2)),
        dueDate: now.add(const Duration(days: 4)),
        note: 'Mượn ôn tập dạng bài tập định tuyến mạng OSPF/RIP.',
      ),
      BorrowRequest(
        id: 'req_sample_4',
        documentId: 'doc_4',
        documentTitle: 'Tài liệu hướng dẫn thực hành Hệ điều hành Linux',
        borrowerId: 'user_letuan',
        borrowerEmail: '2151060296@e.tlu.edu.vn',
        borrowerName: 'Lê Anh Tuấn',
        ownerId: 'user_huynh',
        ownerEmail: '2351170599@e.tlu.edu.vn',
        ownerName: 'Nguyễn Văn Huỳnh',
        status: BorrowStatus.returned,
        requestDate: now.subtract(const Duration(days: 10)),
        approvedDate: now.subtract(const Duration(days: 9)),
        dueDate: now.subtract(const Duration(days: 2)),
        returnedDate: now.subtract(const Duration(days: 1)),
        note: 'Đã hoàn thành các bài lab thực hành Shell Script và hoàn trả tài liệu.',
      ),
      BorrowRequest(
        id: 'req_sample_hn7456',
        documentId: 'doc_3',
        documentTitle: 'Giáo trình Mạng Máy tính & Truyền thông Dữ liệu',
        borrowerId: 'user_letuan',
        borrowerEmail: '2151060296@e.tlu.edu.vn',
        borrowerName: 'Lê Anh Tuấn',
        ownerId: 'user_hn7456',
        ownerEmail: 'hn7456401@gmail.com',
        ownerName: 'Chủ tài liệu ngoài (hn7456401@gmail.com)',
        status: BorrowStatus.pending,
        requestDate: now.subtract(const Duration(minutes: 10)),
        dueDate: now.add(const Duration(days: 7)),
        note: 'Em muốn mượn bản cứng giáo trình ôn thi cuối kỳ.',
      ),
    ];

    for (final req in sampleRequests) {
      await _insertOrUpdateDb(req);
      _memoryRequests.add(req);
    }
  }

  /// Lưu trữ bền vững vào SQLite nếu khả dụng
  Future<void> _insertOrUpdateDb(BorrowRequest req) async {
    try {
      final db = await _appDb.database;
      if (db != null) {
        await db.insert(
          AppTables.tableBorrowRequests,
          req.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      debugPrint('[BorrowService] Ghi SQLite lỗi (lưu vào bộ nhớ): $e');
    }
    await _saveToStorage();
  }

  // ===========================================================================
  // NGHIỆP VỤ MƯỢN / TRẢ TÀI LIỆU
  // ===========================================================================

  /// Gửi yêu cầu mượn tài liệu mới
  Future<BorrowRequest> createBorrowRequest({
    required String documentId,
    required String documentTitle,
    required String borrowerId,
    required String borrowerEmail,
    required String borrowerName,
    required String ownerId,
    required String ownerEmail,
    required String ownerName,
    DateTime? dueDate,
    String? note,
  }) async {
    await initialize();

    final newRequest = BorrowRequest(
      id: 'req_${_uuid.v4().substring(0, 8)}',
      documentId: documentId,
      documentTitle: documentTitle,
      borrowerId: borrowerId,
      borrowerEmail: borrowerEmail,
      borrowerName: borrowerName,
      ownerId: ownerId,
      ownerEmail: ownerEmail,
      ownerName: ownerName,
      status: BorrowStatus.pending,
      requestDate: DateTime.now(),
      dueDate: dueDate ?? DateTime.now().add(const Duration(days: 7)),
      note: note,
    );

    _memoryRequests.insert(0, newRequest);
    await _insertOrUpdateDb(newRequest);
    _notifyWatchers();

    // Bắn thông báo đẩy thời gian thực FCM tới chủ tài liệu
    await _fcm.notifyBorrowRequested(request: newRequest);

    return newRequest;
  }

  /// Chủ sở hữu phê duyệt yêu cầu mượn
  Future<BorrowRequest> approveBorrowRequest({
    required String requestId,
    DateTime? dueDate,
  }) async {
    await initialize();
    final idx = _memoryRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) {
      throw Exception('Không tìm thấy yêu cầu mượn ID: $requestId');
    }

    final oldReq = _memoryRequests[idx];
    final updatedReq = oldReq.copyWith(
      status: BorrowStatus.approved,
      approvedDate: DateTime.now(),
      dueDate: dueDate ?? oldReq.dueDate ?? DateTime.now().add(const Duration(days: 7)),
    );

    _memoryRequests[idx] = updatedReq;
    await _insertOrUpdateDb(updatedReq);
    _notifyWatchers();

    // Bắn thông báo đẩy FCM tới người mượn
    await _fcm.notifyBorrowApproved(request: updatedReq);

    return updatedReq;
  }

  /// Chủ sở hữu từ chối yêu cầu mượn
  Future<BorrowRequest> rejectBorrowRequest({
    required String requestId,
    required String reason,
  }) async {
    await initialize();
    final idx = _memoryRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) {
      throw Exception('Không tìm thấy yêu cầu mượn ID: $requestId');
    }

    final oldReq = _memoryRequests[idx];
    final updatedReq = oldReq.copyWith(
      status: BorrowStatus.rejected,
      rejectionReason: reason,
    );

    _memoryRequests[idx] = updatedReq;
    await _insertOrUpdateDb(updatedReq);
    _notifyWatchers();

    // Bắn thông báo đẩy FCM
    await _fcm.notifyBorrowRejected(request: updatedReq, reason: reason);

    return updatedReq;
  }

  /// Xác nhận đã bàn giao tài liệu (chuyển sang trạng thái đang mượn)
  Future<BorrowRequest> confirmBorrowed({required String requestId}) async {
    await initialize();
    final idx = _memoryRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) {
      throw Exception('Không tìm thấy yêu cầu mượn ID: $requestId');
    }

    final oldReq = _memoryRequests[idx];
    final updatedReq = oldReq.copyWith(status: BorrowStatus.borrowed);

    _memoryRequests[idx] = updatedReq;
    await _insertOrUpdateDb(updatedReq);
    _notifyWatchers();

    return updatedReq;
  }

  /// Xác nhận hoàn trả tài liệu
  Future<BorrowRequest> returnDocument({required String requestId}) async {
    await initialize();
    final idx = _memoryRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) {
      throw Exception('Không tìm thấy yêu cầu mượn ID: $requestId');
    }

    final oldReq = _memoryRequests[idx];
    final updatedReq = oldReq.copyWith(
      status: BorrowStatus.returned,
      returnedDate: DateTime.now(),
    );

    _memoryRequests[idx] = updatedReq;
    await _insertOrUpdateDb(updatedReq);
    _notifyWatchers();

    // Bắn thông báo hoàn trả
    await _fcm.notifyDocumentReturned(request: updatedReq);

    return updatedReq;
  }

  /// Gia hạn thời gian mượn tài liệu
  Future<BorrowRequest> extendDueDate({
    required String requestId,
    required DateTime newDueDate,
  }) async {
    await initialize();
    final idx = _memoryRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) {
      throw Exception('Không tìm thấy yêu cầu mượn ID: $requestId');
    }

    final oldReq = _memoryRequests[idx];
    final updatedReq = oldReq.copyWith(dueDate: newDueDate);

    _memoryRequests[idx] = updatedReq;
    await _insertOrUpdateDb(updatedReq);
    _notifyWatchers();

    return updatedReq;
  }

  /// Người mượn tự hủy yêu cầu
  Future<BorrowRequest> cancelRequest({required String requestId}) async {
    await initialize();
    final idx = _memoryRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) {
      throw Exception('Không tìm thấy yêu cầu mượn ID: $requestId');
    }

    final oldReq = _memoryRequests[idx];
    final updatedReq = oldReq.copyWith(status: BorrowStatus.cancelled);

    _memoryRequests[idx] = updatedReq;
    await _insertOrUpdateDb(updatedReq);
    _notifyWatchers();

    return updatedReq;
  }

  // ===========================================================================
  // TRUY VẤN LỌC THEO NGƯỜI DÙNG & TÀI LIỆU
  // ===========================================================================

  /// Lấy danh sách yêu cầu mình gửi đi (mình là người mượn)
  List<BorrowRequest> getSentRequests(String userEmail) {
    if (userEmail.isEmpty) return [];
    return _memoryRequests
        .where((r) => r.borrowerEmail.toLowerCase() == userEmail.toLowerCase())
        .toList();
  }

  /// Lấy danh sách yêu cầu nhận được từ người khác (mình là chủ sở hữu)
  List<BorrowRequest> getReceivedRequests(String userEmail) {
    if (userEmail.isEmpty) return [];
    return _memoryRequests
        .where((r) => r.ownerEmail.toLowerCase() == userEmail.toLowerCase())
        .toList();
  }

  /// Lấy yêu cầu mượn hiện hành của một tài liệu với người dùng hiện tại
  BorrowRequest? getActiveRequestForDocument(String documentId, String userEmail) {
    try {
      return _memoryRequests.firstWhere(
        (r) =>
            r.documentId == documentId &&
            r.borrowerEmail.toLowerCase() == userEmail.toLowerCase() &&
            (r.status == BorrowStatus.pending ||
                r.status == BorrowStatus.approved ||
                r.status == BorrowStatus.borrowed),
      );
    } catch (_) {
      return null;
    }
  }

  /// Đếm số yêu cầu đang chờ phê duyệt mà người dùng nhận được
  int getPendingReceivedCount(String userEmail) {
    return _memoryRequests
        .where((r) =>
            r.ownerEmail.toLowerCase() == userEmail.toLowerCase() &&
            r.status == BorrowStatus.pending)
        .length;
  }
}
