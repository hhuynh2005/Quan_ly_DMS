import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../struct/document_model.dart';
import '../struct/document_state_provider.dart';
import '../widgets/borrow_request_dialog.dart';
import '../struct/document_enums.dart';
import 'package:intl/intl.dart';

import '../struct/borrow_model.dart';
import '../struct/borrow_service.dart';
import '../struct/firebase_messaging_service.dart';
import '../struct/google_auth_service.dart';
import '../theme.dart';
import '../widgets/empty_state_view.dart';

/// Màn hình Quản Lý Mượn & Chia Sẻ Tài Liệu Đa Nền Tảng (TH2)
/// Phụ trách: Lê Anh Tuấn (MSV: 2151060296) - Nhóm 16 (65KTPM - ĐH Thủy Lợi)
/// Nhánh Git: letuan-th2-borrow-sharing
class BorrowManagementPage extends StatefulWidget {
  final String? initialEmail;

  const BorrowManagementPage({super.key, this.initialEmail});

  @override
  State<BorrowManagementPage> createState() => _BorrowManagementPageState();
}

class _BorrowManagementPageState extends State<BorrowManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BorrowService _borrowService = BorrowService();
  final FirebaseMessagingService _fcm = FirebaseMessagingService();
  StreamSubscription? _requestsSub;
  StreamSubscription? _fcmSub;

  // Tài khoản đang mô phỏng / đăng nhập
  late String _activeEmail;
  late String _activeName;

  // Lọc theo trạng thái
  BorrowStatus? _receivedStatusFilter;
  BorrowStatus? _sentStatusFilter;

  // Danh sách các tài khoản Demo của Nhóm 16 để giảng viên/sinh viên kiểm thử nhanh
  final List<Map<String, String>> _demoAccounts = [
    {
      'email': '2151060296@e.tlu.edu.vn',
      'name': 'Lê Anh Tuấn (Phụ trách Mượn/Trả)',
      'role': 'Thành viên TH2',
    },
    {
      'email': '2351170599@e.tlu.edu.vn',
      'name': 'Nguyễn Văn Huỳnh (Nhóm trưởng)',
      'role': 'Trưởng nhóm TH2',
    },
    {
      'email': '2251172394@e.tlu.edu.vn',
      'name': 'NGUYỄN TRUNG KIÊN (Responsive & Map)',
      'role': 'Thành viên TH2',
    },
    {
      'email': '2351170629@e.tlu.edu.vn',
      'name': 'Trần Anh Tuấn (Recommendation & Tag)',
      'role': 'Thành viên TH2',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final firebaseUser = GoogleAuthService().currentUser;
    _activeEmail = widget.initialEmail ??
        firebaseUser?.email ??
        '2151060296@e.tlu.edu.vn';
    _activeName = firebaseUser?.displayName ?? 'Lê Anh Tuấn (2151060296)';

    _borrowService.initialize().then((_) {
      if (mounted) setState(() {});
    });

    _requestsSub = _borrowService.requestsStream.listen((_) {
      if (mounted) setState(() {});
    });

    _fcmSub = _fcm.notificationsStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _requestsSub?.cancel();
    _fcmSub?.cancel();
    super.dispose();
  }

  void _switchUser(String email, String name) {
    setState(() {
      _activeEmail = email;
      _activeName = name;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã chuyển phiên làm việc sang: $name'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ===========================================================================
  // TẠO YÊU CẦU MƯỢN MỚI TRỰC TIẾP TỪ BORROW MANAGEMENT PAGE
  // ===========================================================================

  Future<void> _showCreateRequestPicker(BuildContext context) async {
    final docs = context.read<DocumentStateProvider>().allDocuments;
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có tài liệu nào trong hệ thống để mượn.')),
      );
      return;
    }

    final selectedDoc = await showModalBottomSheet<Document>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.menu_book_rounded, color: AppTheme.primaryColor),
                      SizedBox(width: 8),
                      Text(
                        'Chọn Tài Liệu Muốn Mượn',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (c, idx) {
                    final d = docs[idx];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: d.fileFormat.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(d.fileFormat.icon, color: d.fileFormat.color, size: 20),
                      ),
                      title: Text(d.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('${d.documentType.displayName} • ${d.fileFormat.extensionName}', style: const TextStyle(fontSize: 11)),
                      trailing: FilledButton.tonal(
                        onPressed: () => Navigator.of(ctx).pop(d),
                        child: const Text('Chọn', style: TextStyle(fontSize: 12)),
                      ),
                      onTap: () => Navigator.of(ctx).pop(d),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedDoc != null && context.mounted) {
      final req = await BorrowRequestDialog.show(
        context: context,
        document: selectedDoc,
        currentUserEmail: _activeEmail,
        currentUserName: _activeName,
      );
      if (req != null && mounted) {
        _tabController.animateTo(1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            content: Text('🎉 Đã gửi yêu cầu mượn "${selectedDoc.title}" thành công!'),
          ),
        );
      }
    }
  }

  // ===========================================================================
  // HỘP THOẠI XỬ LÝ NGHIỆP VỤ (Duyệt, Từ chối, Gia hạn)
  // ===========================================================================

  Future<void> _handleApprove(BorrowRequest req) async {
    DateTime selectedDate = req.dueDate ?? DateTime.now().add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'CHỌN HẠN TRẢ CHO YÊU CẦU MƯỢN',
      confirmText: 'XÁC NHẬN DUYỆT',
    );

    if (picked != null && mounted) {
      try {
        await _borrowService.approveBorrowRequest(
          requestId: req.id,
          dueDate: picked,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              content: Text(
                '✅ Đã phê duyệt yêu cầu mượn của ${req.borrowerName}! Hạn trả: ${DateFormat('dd/MM/yyyy').format(picked)}',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleReject(BorrowRequest req) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('Từ Chối Yêu Cầu Mượn'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tài liệu: ${req.documentTitle}'),
            const SizedBox(height: 6),
            Text('Người mượn: ${req.borrowerName}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Lý do từ chối *',
                hintText: 'Ví dụ: Sách đang có người mượn khác, cần bản in...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập lý do từ chối!')),
                );
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Xác nhận từ chối', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _borrowService.rejectBorrowRequest(
          requestId: req.id,
          reason: reasonController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              content: Text('❌ Đã từ chối yêu cầu mượn tài liệu.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleConfirmBorrowed(BorrowRequest req) async {
    try {
      await _borrowService.confirmBorrowed(requestId: req.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            content: Text('📖 Đã xác nhận bàn giao tài liệu. Trạng thái: Đang mượn.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleReturn(BorrowRequest req) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Xác Nhận Hoàn Trả'),
          ],
        ),
        content: Text(
          'Xác nhận tài liệu "${req.documentTitle}" đã được hoàn trả đầy đủ và nguyên vẹn?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đã nhận lại', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _borrowService.returnDocument(requestId: req.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              content: Text('🎉 Đã xác nhận hoàn trả tài liệu thành công!'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleCancel(BorrowRequest req) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy Yêu Cầu Mượn'),
        content: Text('Bạn có chắc chắn muốn hủy yêu cầu mượn "${req.documentTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hủy yêu cầu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _borrowService.cancelRequest(requestId: req.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã hủy yêu cầu mượn.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleExtend(BorrowRequest req) async {
    final currentDue = req.dueDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDue.add(const Duration(days: 7)),
      firstDate: currentDue,
      lastDate: currentDue.add(const Duration(days: 45)),
      helpText: 'CHỌN HẠN TRẢ MỚI (GIA HẠN)',
    );

    if (picked != null && mounted) {
      try {
        await _borrowService.extendDueDate(
          requestId: req.id,
          newDueDate: picked,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.primaryColor,
              content: Text(
                'Đã gia hạn tài liệu đến ngày ${DateFormat('dd/MM/yyyy').format(picked)}',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ===========================================================================
  // MODAL XEM THÔNG BÁO THỜI GIAN THỰC (FCM NOTIFICATIONS)
  // ===========================================================================

  void _showNotificationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final notifications = _fcm.currentNotifications;
        final theme = Theme.of(ctx);

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded,
                          color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Thông Báo Đẩy Thời Gian Thực',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _fcm.markAllAsRead();
                      Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('Đã đọc hết', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có thông báo nào.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = notifications[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: item.isRead
                                  ? Colors.grey.withValues(alpha: 0.15)
                                  : AppTheme.primaryColor.withValues(alpha: 0.15),
                              child: Icon(
                                _getNotifIcon(item.type),
                                color: item.isRead
                                    ? Colors.grey
                                    : AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: item.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  item.body,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('HH:mm - dd/MM/yyyy')
                                      .format(item.timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              _fcm.markAsRead(item.id);
                              Navigator.of(ctx).pop();
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getNotifIcon(NotificationType type) {
    switch (type) {
      case NotificationType.borrowRequest:
        return Icons.forward_to_inbox_rounded;
      case NotificationType.borrowApproved:
        return Icons.check_circle_outline_rounded;
      case NotificationType.borrowRejected:
        return Icons.highlight_off_rounded;
      case NotificationType.documentReturned:
        return Icons.assignment_return_rounded;
      case NotificationType.overdueReminder:
        return Icons.warning_amber_rounded;
      case NotificationType.general:
        return Icons.info_outline_rounded;
    }
  }

  // ===========================================================================
  // GIAO DIỆN CHÍNH (BUILD)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final receivedList = _borrowService.getReceivedRequests(_activeEmail);
    final sentList = _borrowService.getSentRequests(_activeEmail);
    final pendingCount = _borrowService.getPendingReceivedCount(_activeEmail);
    final unreadNotifs = _fcm.unreadCount;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Gửi yêu cầu mượn'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        tooltip: 'Chọn tài liệu và gửi yêu cầu mượn mới',
        onPressed: () => _showCreateRequestPicker(context),
      ),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quản Lý Mượn & Chia Sẻ',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'Mục 4 TH2 • Lê Anh Tuấn (2151060296)',
              style: TextStyle(
                fontSize: 11,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          // Nút Chuông Thông Báo FCM
          IconButton(
            icon: Badge(
              isLabelVisible: unreadNotifs > 0,
              label: Text('$unreadNotifs'),
              child: const Icon(Icons.notifications_rounded),
            ),
            tooltip: 'Thông báo đẩy thời gian thực (FCM)',
            onPressed: _showNotificationSheet,
          ),

          // Menu chuyển đổi người dùng Demo siêu tiện lợi
          PopupMenuButton<Map<String, String>>(
            icon: const Icon(Icons.switch_account_rounded),
            tooltip: 'Chuyển tài khoản Demo kiểm thử',
            onSelected: (acc) => _switchUser(acc['email']!, acc['name']!),
            itemBuilder: (ctx) {
              return _demoAccounts.map((acc) {
                final isCurrent = acc['email'] == _activeEmail;
                return PopupMenuItem<Map<String, String>>(
                  value: acc,
                  child: Row(
                    children: [
                      Icon(
                        isCurrent
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: isCurrent ? AppTheme.primaryColor : Colors.grey,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              acc['name']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            Text(
                              acc['email']!,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color,
          indicatorColor: AppTheme.primaryColor,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox_rounded, size: 18),
                  const SizedBox(width: 6),
                  const Text('Yêu cầu nhận được'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.outbox_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text('Đã gửi (${sentList.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Banner thông tin tài khoản đang thao tác
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? Colors.grey[900] : const Color(0xFFF1F5F9),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: Text(
                    _activeName.isNotEmpty ? _activeName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đang xem với tư cách: $_activeName',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _activeEmail,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'TLU Student',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Yêu cầu nhận được (Chủ sở hữu)
                _buildReceivedTab(receivedList),

                // TAB 2: Yêu cầu đã gửi (Người mượn)
                _buildSentTab(sentList),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET BUILDER: TAB YÊU CẦU NHẬN ĐƯỢC
  // ===========================================================================

  Widget _buildReceivedTab(List<BorrowRequest> list) {
    final filtered = _receivedStatusFilter == null
        ? list
        : list.where((r) => r.status == _receivedStatusFilter).toList();

    return Column(
      children: [
        // Thanh lọc trạng thái
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Tất cả'),
                selected: _receivedStatusFilter == null,
                onSelected: (_) => setState(() => _receivedStatusFilter = null),
              ),
              const SizedBox(width: 6),
              ...BorrowStatus.values.map((st) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    avatar: Icon(st.icon, size: 14, color: st.color),
                    label: Text(st.displayName),
                    selected: _receivedStatusFilter == st,
                    onSelected: (_) =>
                        setState(() => _receivedStatusFilter = st),
                  ),
                );
              }),
            ],
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? const EmptyStateView(
                  title: 'Không có yêu cầu mượn nào',
                  message:
                      'Khi các sinh viên khác gửi yêu cầu mượn tài liệu của bạn, chúng sẽ xuất hiện tại đây.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final req = filtered[index];
                    return _buildReceivedRequestCard(req);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReceivedRequestCard(BorrowRequest req) {
    final theme = Theme.of(context);
    final statusColor = req.status.color;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dòng 1: Status badge & Thời gian gửi
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(req.status.icon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        req.status.displayName,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('dd/MM HH:mm').format(req.requestDate),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Dòng 2: Tên tài liệu
            Text(
              req.documentTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),

            // Dòng 3: Thông tin người mượn
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Người mượn: ${req.borrowerName} (${req.borrowerEmail})',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),

            if (req.dueDate != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 16,
                    color: req.isOverdue ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hạn trả: ${DateFormat('dd/MM/yyyy').format(req.dueDate!)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          req.isOverdue ? FontWeight.bold : FontWeight.normal,
                      color: req.isOverdue ? Colors.red : null,
                    ),
                  ),
                  if (req.isOverdue) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'QUÁ HẠN',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],

            if (req.note != null && req.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '💬 Ghi chú: ${req.note}',
                  style: const TextStyle(
                      fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),
            ],

            if (req.rejectionReason != null) ...[
              const SizedBox(height: 6),
              Text(
                'Lý do từ chối: ${req.rejectionReason}',
                style: const TextStyle(fontSize: 11, color: Colors.red),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Các nút hành động theo trạng thái
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (req.status == BorrowStatus.pending) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => _handleReject(req),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Từ chối', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _handleApprove(req),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Duyệt mượn',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ] else if (req.status == BorrowStatus.approved) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _handleConfirmBorrowed(req),
                    icon: const Icon(Icons.handshake_rounded, size: 16),
                    label: const Text('Đã giao tài liệu',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ] else if (req.status == BorrowStatus.borrowed) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _handleReturn(req),
                    icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
                    label: const Text('Xác nhận đã nhận lại',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ] else if (req.status == BorrowStatus.returned) ...[
                  const Text(
                    'Đã hoàn tất quy trình mượn trả',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET BUILDER: TAB YÊU CẦU ĐÃ GỬI
  // ===========================================================================

  Widget _buildSentTab(List<BorrowRequest> list) {
    final filtered = _sentStatusFilter == null
        ? list
        : list.where((r) => r.status == _sentStatusFilter).toList();

    return Column(
      children: [
        // Thanh lọc trạng thái
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Tất cả'),
                selected: _sentStatusFilter == null,
                onSelected: (_) => setState(() => _sentStatusFilter = null),
              ),
              const SizedBox(width: 6),
              ...BorrowStatus.values.map((st) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    avatar: Icon(st.icon, size: 14, color: st.color),
                    label: Text(st.displayName),
                    selected: _sentStatusFilter == st,
                    onSelected: (_) => setState(() => _sentStatusFilter = st),
                  ),
                );
              }),
            ],
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? EmptyStateView(
                  title: 'Chưa gửi yêu cầu mượn nào',
                  message:
                      'Bạn có thể tạo yêu cầu mượn tài liệu học tập ngay tại đây hoặc trong màn hình Chi tiết Tài liệu.',
                  actionText: 'Tạo yêu cầu mượn ngay',
                  onAction: () => _showCreateRequestPicker(context),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final req = filtered[index];
                    return _buildSentRequestCard(req);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSentRequestCard(BorrowRequest req) {
    final theme = Theme.of(context);
    final statusColor = req.status.color;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(req.status.icon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        req.status.displayName,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('dd/MM HH:mm').format(req.requestDate),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              req.documentTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.account_balance_rounded,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Chủ tài liệu: ${req.ownerName} (${req.ownerEmail})',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),

            if (req.dueDate != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.alarm_rounded,
                    size: 16,
                    color: req.isOverdue ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hạn trả: ${DateFormat('dd/MM/yyyy').format(req.dueDate!)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          req.isOverdue ? FontWeight.bold : FontWeight.normal,
                      color: req.isOverdue ? Colors.red : null,
                    ),
                  ),
                  if (req.remainingDays != null && !req.isOverdue) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(Còn ${req.remainingDays} ngày)',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.primaryColor),
                    ),
                  ],
                ],
              ),
            ],

            if (req.rejectionReason != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '❌ Bị từ chối: ${req.rejectionReason}',
                  style: const TextStyle(fontSize: 11, color: Colors.red),
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (req.status == BorrowStatus.pending) ...[
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => _handleCancel(req),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Hủy yêu cầu', style: TextStyle(fontSize: 12)),
                  ),
                ] else if (req.status == BorrowStatus.borrowed) ...[
                  OutlinedButton.icon(
                    onPressed: () => _handleExtend(req),
                    icon: const Icon(Icons.update_rounded, size: 16),
                    label: const Text('Xin gia hạn', style: TextStyle(fontSize: 12)),
                  ),
                ] else ...[
                  Text(
                    'Trạng thái: ${req.status.displayName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
