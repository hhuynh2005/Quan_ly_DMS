import 'package:flutter/material.dart';

/// Trạng thái của một yêu cầu mượn tài liệu
enum BorrowStatus {
  pending,  // Đang chờ chủ sở hữu phê duyệt
  approved, // Chủ sở hữu đã phê duyệt, chờ nhận tài liệu
  borrowed, // Đang mượn (đã bàn giao tài liệu)
  returned, // Đã hoàn trả tài liệu
  rejected, // Bị từ chối
  cancelled // Người mượn tự hủy yêu cầu
}

extension BorrowStatusExtension on BorrowStatus {
  String get id => name;

  String get displayName {
    switch (this) {
      case BorrowStatus.pending:
        return 'Chờ duyệt';
      case BorrowStatus.approved:
        return 'Đã duyệt';
      case BorrowStatus.borrowed:
        return 'Đang mượn';
      case BorrowStatus.returned:
        return 'Đã trả';
      case BorrowStatus.rejected:
        return 'Từ chối';
      case BorrowStatus.cancelled:
        return 'Đã hủy';
    }
  }

  Color get color {
    switch (this) {
      case BorrowStatus.pending:
        return const Color(0xFFF59E0B); // Amber / Orange
      case BorrowStatus.approved:
        return const Color(0xFF3B82F6); // Blue
      case BorrowStatus.borrowed:
        return const Color(0xFF10B981); // Emerald Green
      case BorrowStatus.returned:
        return const Color(0xFF6B7280); // Gray
      case BorrowStatus.rejected:
        return const Color(0xFFEF4444); // Red
      case BorrowStatus.cancelled:
        return const Color(0xFF9CA3AF); // Light gray
    }
  }

  IconData get icon {
    switch (this) {
      case BorrowStatus.pending:
        return Icons.hourglass_top_rounded;
      case BorrowStatus.approved:
        return Icons.task_alt_rounded;
      case BorrowStatus.borrowed:
        return Icons.menu_book_rounded;
      case BorrowStatus.returned:
        return Icons.assignment_turned_in_rounded;
      case BorrowStatus.rejected:
        return Icons.cancel_outlined;
      case BorrowStatus.cancelled:
        return Icons.block_rounded;
    }
  }

  static BorrowStatus fromString(String? val) {
    if (val == null) return BorrowStatus.pending;
    switch (val.toLowerCase().trim()) {
      case 'approved':
        return BorrowStatus.approved;
      case 'borrowed':
        return BorrowStatus.borrowed;
      case 'returned':
        return BorrowStatus.returned;
      case 'rejected':
        return BorrowStatus.rejected;
      case 'cancelled':
        return BorrowStatus.cancelled;
      default:
        return BorrowStatus.pending;
    }
  }
}

/// Model thực thể Yêu cầu Mượn / Chia sẻ Tài liệu (Borrow Request)
/// Tương thích với bảng `borrow_requests` trên Supabase và SQLite Cache
class BorrowRequest {
  final String id;
  final String documentId;
  final String documentTitle;
  final String borrowerId;
  final String borrowerEmail;
  final String borrowerName;
  final String ownerId;
  final String ownerEmail;
  final String ownerName;
  final BorrowStatus status;
  final DateTime requestDate;
  final DateTime? approvedDate;
  final DateTime? dueDate;
  final DateTime? returnedDate;
  final String? note;
  final String? rejectionReason;

  BorrowRequest({
    required this.id,
    required this.documentId,
    required this.documentTitle,
    required this.borrowerId,
    required this.borrowerEmail,
    required this.borrowerName,
    required this.ownerId,
    required this.ownerEmail,
    required this.ownerName,
    this.status = BorrowStatus.pending,
    required this.requestDate,
    this.approvedDate,
    this.dueDate,
    this.returnedDate,
    this.note,
    this.rejectionReason,
  });

  /// Kiểm tra xem yêu cầu có bị quá hạn trả hay không
  bool get isOverdue {
    if (status != BorrowStatus.borrowed && status != BorrowStatus.approved) {
      return false;
    }
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Số ngày còn lại trước hạn trả (âm nếu đã quá hạn)
  int? get remainingDays {
    if (dueDate == null) return null;
    return dueDate!.difference(DateTime.now()).inDays;
  }

  BorrowRequest copyWith({
    String? id,
    String? documentId,
    String? documentTitle,
    String? borrowerId,
    String? borrowerEmail,
    String? borrowerName,
    String? ownerId,
    String? ownerEmail,
    String? ownerName,
    BorrowStatus? status,
    DateTime? requestDate,
    DateTime? approvedDate,
    DateTime? dueDate,
    DateTime? returnedDate,
    String? note,
    String? rejectionReason,
  }) {
    return BorrowRequest(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      documentTitle: documentTitle ?? this.documentTitle,
      borrowerId: borrowerId ?? this.borrowerId,
      borrowerEmail: borrowerEmail ?? this.borrowerEmail,
      borrowerName: borrowerName ?? this.borrowerName,
      ownerId: ownerId ?? this.ownerId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerName: ownerName ?? this.ownerName,
      status: status ?? this.status,
      requestDate: requestDate ?? this.requestDate,
      approvedDate: approvedDate ?? this.approvedDate,
      dueDate: dueDate ?? this.dueDate,
      returnedDate: returnedDate ?? this.returnedDate,
      note: note ?? this.note,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'document_title': documentTitle,
      'borrower_id': borrowerId,
      'borrower_email': borrowerEmail,
      'borrower_name': borrowerName,
      'owner_id': ownerId,
      'owner_email': ownerEmail,
      'owner_name': ownerName,
      'status': status.id,
      'request_date': requestDate.toIso8601String(),
      'approved_date': approvedDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'returned_date': returnedDate?.toIso8601String(),
      'note': note,
      'rejection_reason': rejectionReason,
    };
  }

  factory BorrowRequest.fromMap(Map<String, dynamic> map) {
    return BorrowRequest(
      id: map['id'] as String,
      documentId: map['document_id'] as String? ?? '',
      documentTitle: map['document_title'] as String? ?? 'Tài liệu không tên',
      borrowerId: map['borrower_id'] as String? ?? '',
      borrowerEmail: map['borrower_email'] as String? ?? '',
      borrowerName: map['borrower_name'] as String? ?? 'Sinh viên',
      ownerId: map['owner_id'] as String? ?? '',
      ownerEmail: map['owner_email'] as String? ?? '',
      ownerName: map['owner_name'] as String? ?? 'Chủ sở hữu',
      status: BorrowStatusExtension.fromString(map['status'] as String?),
      requestDate: DateTime.tryParse(map['request_date'] as String? ?? '') ??
          DateTime.now(),
      approvedDate: map['approved_date'] != null
          ? DateTime.tryParse(map['approved_date'] as String)
          : null,
      dueDate: map['due_date'] != null
          ? DateTime.tryParse(map['due_date'] as String)
          : null,
      returnedDate: map['returned_date'] != null
          ? DateTime.tryParse(map['returned_date'] as String)
          : null,
      note: map['note'] as String?,
      rejectionReason: map['rejection_reason'] as String?,
    );
  }
}
