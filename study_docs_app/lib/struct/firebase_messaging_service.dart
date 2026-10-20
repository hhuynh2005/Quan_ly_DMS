import 'dart:async';
import 'package:flutter/foundation.dart';
import 'borrow_model.dart';

/// Loại thông báo hệ thống
enum NotificationType {
  borrowRequest,  // Có yêu cầu mượn mới
  borrowApproved, // Yêu cầu đã được duyệt
  borrowRejected, // Yêu cầu bị từ chối
  documentReturned,// Tài liệu đã được hoàn trả
  overdueReminder, // Nhắc nhở sắp/đã quá hạn trả
  general,        // Thông báo chung
}

/// Thực thể thông báo thời gian thực (Push Notification Item)
class PushNotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationType type;
  final String? targetRequestId;
  final String recipientEmail;
  bool isRead;

  PushNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.type = NotificationType.general,
    this.targetRequestId,
    required this.recipientEmail,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'target_request_id': targetRequestId,
      'recipient_email': recipientEmail,
      'is_read': isRead ? 1 : 0,
    };
  }

  factory PushNotificationItem.fromMap(Map<String, dynamic> map) {
    return PushNotificationItem(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.general,
      ),
      targetRequestId: map['target_request_id'] as String?,
      recipientEmail: map['recipient_email'] as String? ?? '',
      isRead: (map['is_read'] as int? ?? 0) == 1,
    );
  }
}

/// Dịch vụ Quản lý & Bắn Thông Báo Đẩy Thời Gian Thực (FCM Simulator / Service)
/// Phụ trách: Lê Anh Tuấn (MSV: 2151060296) - Nhóm 16 TH2
class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal() {
    _initSampleNotifications();
  }

  final List<PushNotificationItem> _notifications = [];
  final StreamController<List<PushNotificationItem>> _notificationsController =
      StreamController<List<PushNotificationItem>>.broadcast();

  Stream<List<PushNotificationItem>> get notificationsStream =>
      _notificationsController.stream;

  List<PushNotificationItem> get currentNotifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void _notifyListeners() {
    _notificationsController.add(List.unmodifiable(_notifications));
  }

  /// Khởi tạo một số thông báo mẫu phục vụ trải nghiệm người dùng
  void _initSampleNotifications() {
    _notifications.addAll([
      PushNotificationItem(
        id: 'notif_welcome',
        title: 'Chào mừng bạn đến với Smart DMS!',
        body: 'Tính năng Mượn & Chia sẻ quyền truy cập tài liệu TH2 đã sẵn sàng hoạt động.',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        type: NotificationType.general,
        recipientEmail: 'all',
        isRead: false,
      ),
      PushNotificationItem(
        id: 'notif_sample_1',
        title: 'Yêu cầu mượn tài liệu mới',
        body: 'Sinh viên Nguyễn Văn Huỳnh vừa gửi yêu cầu mượn tài liệu "Giáo trình Kiến trúc Máy tính".',
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        type: NotificationType.borrowRequest,
        targetRequestId: 'req_sample_1',
        recipientEmail: '2151060296@e.tlu.edu.vn',
        isRead: false,
      ),
    ]);
  }

  /// Bắn thông báo đẩy khi có người gửi yêu cầu mượn tài liệu
  Future<void> notifyBorrowRequested({required BorrowRequest request}) async {
    final item = PushNotificationItem(
      id: 'fcm_${DateTime.now().millisecondsSinceEpoch}_req',
      title: '🔔 Yêu cầu mượn tài liệu mới',
      body: '${request.borrowerName} (${request.borrowerEmail}) vừa gửi yêu cầu mượn "${request.documentTitle}".',
      timestamp: DateTime.now(),
      type: NotificationType.borrowRequest,
      targetRequestId: request.id,
      recipientEmail: request.ownerEmail,
    );
    _notifications.insert(0, item);
    _notifyListeners();
    debugPrint('[FCM] Sent Push Notification to ${request.ownerEmail}: ${item.title}');
  }

  /// Bắn thông báo khi chủ sở hữu duyệt yêu cầu
  Future<void> notifyBorrowApproved({required BorrowRequest request}) async {
    final dueStr = request.dueDate != null
        ? '${request.dueDate!.day}/${request.dueDate!.month}/${request.dueDate!.year}'
        : 'Theo thỏa thuận';
    final item = PushNotificationItem(
      id: 'fcm_${DateTime.now().millisecondsSinceEpoch}_appr',
      title: '✅ Yêu cầu mượn được CHẤP THUẬN',
      body: 'Chủ sở hữu ${request.ownerName} đã đồng ý cho bạn mượn "${request.documentTitle}". Hạn trả: $dueStr.',
      timestamp: DateTime.now(),
      type: NotificationType.borrowApproved,
      targetRequestId: request.id,
      recipientEmail: request.borrowerEmail,
    );
    _notifications.insert(0, item);
    _notifyListeners();
    debugPrint('[FCM] Sent Push Notification to ${request.borrowerEmail}: ${item.title}');
  }

  /// Bắn thông báo khi chủ sở hữu từ chối
  Future<void> notifyBorrowRejected({
    required BorrowRequest request,
    required String reason,
  }) async {
    final item = PushNotificationItem(
      id: 'fcm_${DateTime.now().millisecondsSinceEpoch}_rej',
      title: '❌ Yêu cầu mượn bị TỪ CHỐI',
      body: 'Chủ sở hữu đã từ chối yêu cầu mượn "${request.documentTitle}". Lý do: $reason',
      timestamp: DateTime.now(),
      type: NotificationType.borrowRejected,
      targetRequestId: request.id,
      recipientEmail: request.borrowerEmail,
    );
    _notifications.insert(0, item);
    _notifyListeners();
    debugPrint('[FCM] Sent Push Notification to ${request.borrowerEmail}: ${item.title}');
  }

  /// Bắn thông báo khi tài liệu đã được hoàn trả
  Future<void> notifyDocumentReturned({required BorrowRequest request}) async {
    final item = PushNotificationItem(
      id: 'fcm_${DateTime.now().millisecondsSinceEpoch}_ret',
      title: '📦 Tài liệu đã được hoàn trả',
      body: 'Tài liệu "${request.documentTitle}" đã được xác nhận hoàn trả thành công.',
      timestamp: DateTime.now(),
      type: NotificationType.documentReturned,
      targetRequestId: request.id,
      recipientEmail: request.ownerEmail,
    );
    _notifications.insert(0, item);
    _notifyListeners();
    debugPrint('[FCM] Sent Push Notification to ${request.ownerEmail}: ${item.title}');
  }

  /// Đánh dấu một thông báo là đã đọc
  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx].isRead = true;
      _notifyListeners();
    }
  }

  /// Đánh dấu tất cả thông báo là đã đọc
  void markAllAsRead() {
    for (final item in _notifications) {
      item.isRead = true;
    }
    _notifyListeners();
  }

  /// Xóa toàn bộ thông báo
  void clearAll() {
    _notifications.clear();
    _notifyListeners();
  }
}
