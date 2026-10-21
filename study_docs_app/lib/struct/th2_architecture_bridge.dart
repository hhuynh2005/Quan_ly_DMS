import 'document_location_model.dart';
import 'document_model.dart';
import 'borrow_model.dart';

/// Lớp kết nối kiến trúc Đa nền tảng TH2 (Nhóm trưởng Nguyễn Văn Huỳnh - MSV: 2351170599)
///
/// Định nghĩa cầu nối tích hợp đồng bộ dữ liệu giữa:
/// - Firebase Cloud Ecosystem: Authentication (Google Sign-In OAuth) & Cloud Messaging (FCM)
/// - Supabase Cloud Ecosystem: PostgreSQL DB, Storage Bucket, Realtime Event Stream, Row Level Security (RLS)
/// - SQLite Local-First Cache: Đọc/Ghi tức thời khi mất kết nối mạng và đồng bộ nền hai chiều.
class TH2ArchitectureBridge {
  static const String appVersion = '2.0.0-TH2';
  static const String architecturePattern = 'Clean Architecture + Local-First Hybrid Cloud';

  // Cấu hình định danh Cloud
  static const String firebaseProject = 'cashew-study-docs';
  static const String supabaseProject = 'cashew-study-docs-tlu';
  static const String storageBucketName = 'study_documents';

  // Các bảng quan hệ Supabase đã thiết kế trong DDL Schema
  static const List<String> supabaseTables = [
    'subjects',
    'documents',
    'document_locations',
    'borrow_requests',
    'tags',
    'document_tags',
    'user_preferences',
  ];

  /// Kiểm tra tính hợp lệ của gói dữ liệu đa nền tảng trước khi đẩy lên Cloud
  static bool validateCrossPlatformPayload({
    required Document document,
    DocumentLocation? location,
    BorrowRequest? activeBorrowRequest,
  }) {
    if (document.id.isEmpty || document.title.trim().isEmpty) {
      return false;
    }
    if (document.subjectId.isEmpty) {
      return false;
    }
    if (location != null && location.documentId != document.id) {
      return false;
    }
    if (activeBorrowRequest != null && activeBorrowRequest.documentId != document.id) {
      return false;
    }
    return true;
  }

  /// Chuyển đổi mô hình Document sang JSON tương thích hoàn toàn với Schema Supabase PostgreSQL
  static Map<String, dynamic> documentToSupabaseRow(Document doc, {String? uploaderEmail}) {
    return {
      'id': doc.id,
      'title': doc.title,
      'description': doc.description,
      'subject_id': doc.subjectId,
      'document_type': doc.documentType.name,
      'file_format': doc.fileFormat.name,
      'file_path': doc.filePath,
      'file_url': doc.fileUrl,
      'file_size_bytes': doc.fileSizeBytes,
      'is_favorite': doc.isFavorite,
      'status': doc.status.name,
      'priority': doc.priority.name,
      'due_date': doc.dueDate?.toIso8601String(),
      'tags': doc.tags,
      'uploader_email': uploaderEmail ?? '2351170599@e.tlu.edu.vn',
      'is_public': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Chuyển đổi mô hình DocumentLocation sang JSON tương thích với Supabase
  static Map<String, dynamic> locationToSupabaseRow(DocumentLocation loc) {
    return {
      'id': loc.id,
      'document_id': loc.documentId,
      'building': loc.building,
      'room': loc.room,
      'shelf': loc.shelf,
      'latitude': loc.latitude,
      'longitude': loc.longitude,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Chuyển đổi mô hình BorrowRequest sang JSON tương thích với Supabase
  static Map<String, dynamic> borrowRequestToSupabaseRow(BorrowRequest req) {
    return {
      'id': req.id,
      'document_id': req.documentId,
      'document_title': req.documentTitle,
      'borrower_id': req.borrowerId,
      'borrower_email': req.borrowerEmail,
      'borrower_name': req.borrowerName,
      'owner_id': req.ownerId,
      'owner_email': req.ownerEmail,
      'owner_name': req.ownerName,
      'status': req.status.name,
      'request_date': req.requestDate.toIso8601String(),
      'approved_date': req.approvedDate?.toIso8601String(),
      'due_date': req.dueDate?.toIso8601String(),
      'returned_date': req.returnedDate?.toIso8601String(),
      'note': req.note,
      'rejection_reason': req.rejectionReason,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Thông tin phiên bản và tác giả kiến trúc
  static Map<String, String> get architectureMetadata => {
    'author': 'Nguyễn Văn Huỳnh',
    'studentId': '2351170599',
    'role': 'Nhóm trưởng (Team Leader)',
    'team': 'Nhóm 16 - Lớp 65KTPM',
    'assignment': 'TH2: Phát triển Hệ thống Quản lý Tài liệu Đa nền tảng',
    'architecture': 'Flutter + Firebase (Auth/FCM) + Supabase (DB/Storage/Realtime) + SQLite Local-First',
  };
}
