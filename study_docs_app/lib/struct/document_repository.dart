import 'dart:async';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../functions.dart';
import 'document_enums.dart';
import 'document_location_model.dart';
import 'document_model.dart';
import 'subject_model.dart';

/// Repository Layer - Đóng gói logic nghiệp vụ và điều phối giữa Database Layer và Presentation Layer
class DocumentRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  DocumentRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  bool get databaseIsUsingMemoryFallback => _db.isUsingMemoryFallback;

  // ===========================================================================
  // REACTIVE WATCHERS (Chuyển tiếp stream reactive từ Database lên State Provider)
  // ===========================================================================

  Stream<List<Document>> watchAllDocuments() => _db.watchAllDocuments();
  Stream<List<Subject>> watchSubjects() => _db.watchSubjects();
  Stream<Map<String, int>> watchStats() => _db.watchStats();
  Stream<List<DocumentLocation>> watchDocumentLocations() => _db.watchDocumentLocations();

  // ===========================================================================
  // TÀI LIỆU HỌC TẬP (DOCUMENTS) - BUSINESS LOGIC & VALIDATION
  // ===========================================================================

  /// Lấy toàn bộ danh sách tài liệu
  Future<List<Document>> getAllDocuments() async {
    return await _db.getAllDocuments();
  }

  /// Lấy chi tiết tài liệu theo ID
  Future<Document?> getDocumentById(String id) async {
    if (id.trim().isEmpty) return null;
    return await _db.getDocumentById(id);
  }

  /// Thêm tài liệu mới kèm validation nghiệp vụ chặt chẽ
  Future<Document> createDocument({
    required String title,
    String description = '',
    required String subjectId,
    required DocumentType documentType,
    DocumentFormat fileFormat = DocumentFormat.pdf,
    String? filePath,
    String? fileUrl,
    int fileSizeBytes = 0,
    bool isFavorite = false,
    DocumentStatus status = DocumentStatus.newDoc,
    DocumentPriority priority = DocumentPriority.medium,
    DateTime? dueDate,
    List<String>? tags,
  }) async {
    // 1. Validation nghiệp vụ
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError('Tiêu đề tài liệu không được để trống.');
    }

    if (cleanTitle.length > 255) {
      throw ArgumentError('Tiêu đề tài liệu không được vượt quá 255 ký tự.');
    }

    if (subjectId.trim().isEmpty) {
      throw ArgumentError('Môn học không hợp lệ hoặc chưa được chọn.');
    }

    if (fileUrl != null && fileUrl.trim().isNotEmpty && !AppFunctions.isValidUrl(fileUrl)) {
      throw ArgumentError('Đường dẫn URL tài liệu không đúng định dạng HTTP/HTTPS.');
    }

    // 2. Khởi tạo Entity với UUID v4
    final newDoc = Document(
      id: _uuid.v4(),
      title: cleanTitle,
      description: description.trim(),
      subjectId: subjectId,
      documentType: documentType,
      fileFormat: fileFormat,
      filePath: filePath?.trim(),
      fileUrl: fileUrl?.trim(),
      fileSizeBytes: fileSizeBytes >= 0 ? fileSizeBytes : 0,
      isFavorite: isFavorite,
      status: status,
      priority: priority,
      dueDate: dueDate,
      tags: tags ?? [],
      dateCreated: DateTime.now(),
      dateModified: DateTime.now(),
    );

    // 3. Lưu vào Database
    await _db.insertDocument(newDoc);
    return newDoc;
  }

  /// Cập nhật thông tin tài liệu
  Future<Document> updateDocument(Document document) async {
    final cleanTitle = document.title.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError('Tiêu đề tài liệu không được để trống.');
    }

    final updated = document.copyWith(
      title: cleanTitle,
      description: document.description.trim(),
      dateModified: DateTime.now(),
    );

    await _db.updateDocument(updated);
    return updated;
  }

  /// Xóa tài liệu (kèm ghi nhận delete_logs trong database)
  Future<void> deleteDocument(String id) async {
    if (id.trim().isEmpty) {
      throw ArgumentError('ID tài liệu cần xóa không hợp lệ.');
    }
    await _db.deleteDocument(id);
  }

  /// Đổi trạng thái yêu thích
  Future<bool> toggleFavorite(String id) async {
    return await _db.toggleFavorite(id);
  }

  /// Chuyển đổi trạng thái học tập của tài liệu
  Future<void> updateDocumentStatus(String id, DocumentStatus newStatus) async {
    await _db.updateDocumentStatus(id, newStatus);
  }

  /// Tìm kiếm và lọc đa tiêu chí
  Future<List<Document>> searchDocuments({
    String query = '',
    String? subjectId,
    DocumentType? type,
    DocumentStatus? status,
    bool? isFavorite,
    String sortBy = 'date_desc',
  }) async {
    return await _db.searchDocuments(
      query: query,
      subjectId: subjectId,
      type: type,
      status: status,
      isFavorite: isFavorite,
      sortBy: sortBy,
    );
  }

  // ===========================================================================
  // MÔN HỌC (SUBJECTS)
  // ===========================================================================

  /// Lấy toàn bộ danh sách môn học
  Future<List<Subject>> getAllSubjects() async {
    return await _db.getAllSubjects();
  }

  /// Lấy môn học theo ID
  Future<Subject?> getSubjectById(String id) async {
    return await _db.getSubjectById(id);
  }

  /// Thêm mới môn học kèm validation
  Future<Subject> createSubject({
    required String name,
    required String code,
    String colorHex = '#00796B',
    String iconName = 'book',
    String semester = '',
  }) async {
    final cleanName = name.trim();
    final cleanCode = code.trim().toUpperCase();

    if (cleanName.isEmpty) {
      throw ArgumentError('Tên môn học không được để trống.');
    }
    if (cleanCode.isEmpty) {
      throw ArgumentError('Mã môn học không được để trống.');
    }

    final newSubject = Subject(
      id: _uuid.v4(),
      name: cleanName,
      code: cleanCode,
      colorHex: colorHex,
      iconName: iconName,
      semester: semester.trim(),
      dateCreated: DateTime.now(),
      dateModified: DateTime.now(),
    );

    await _db.insertSubject(newSubject);
    return newSubject;
  }

  /// Cập nhật môn học
  Future<Subject> updateSubject(Subject subject) async {
    final cleanName = subject.name.trim();
    final cleanCode = subject.code.trim().toUpperCase();

    if (cleanName.isEmpty || cleanCode.isEmpty) {
      throw ArgumentError('Tên và mã môn học không được để trống.');
    }

    final updated = subject.copyWith(
      name: cleanName,
      code: cleanCode,
      dateModified: DateTime.now(),
    );

    await _db.updateSubject(updated);
    return updated;
  }

  /// Xóa môn học
  Future<void> deleteSubject(String id) async {
    await _db.deleteSubject(id);
  }

  // ===========================================================================
  // THỐNG KÊ & KHÔI PHỤC
  // ===========================================================================

  Future<Map<String, int>> getDocumentStats() async {
    return await _db.getDocumentStats();
  }

  Future<List<Map<String, dynamic>>> getDeleteLogs() async {
    return await _db.getDeleteLogs();
  }

  // ===========================================================================
  // VỊ TRÍ VẬT LÝ TÀI LIỆU (DOCUMENT LOCATIONS - TH2)
  // ===========================================================================

  /// Lấy toàn bộ danh sách vị trí vật lý
  Future<List<DocumentLocation>> getAllDocumentLocations() async {
    return await _db.getAllDocumentLocations();
  }

  /// Lấy vị trí vật lý theo documentId
  Future<DocumentLocation?> getDocumentLocation(String documentId) async {
    if (documentId.trim().isEmpty) return null;
    return await _db.getDocumentLocation(documentId);
  }

  /// Lưu hoặc cập nhật vị trí vật lý tài liệu
  Future<void> saveDocumentLocation(DocumentLocation location) async {
    if (location.building.trim().isEmpty) {
      throw ArgumentError('Tên tòa nhà không được để trống.');
    }
    if (location.room.trim().isEmpty) {
      throw ArgumentError('Phòng học / khu vực không được để trống.');
    }
    await _db.saveDocumentLocation(location);
  }

  /// Xóa vị trí vật lý tài liệu
  Future<int> deleteDocumentLocation(String documentId) async {
    if (documentId.trim().isEmpty) return 0;
    return await _db.deleteDocumentLocation(documentId);
  }

  Future<void> resetData() async {
    await _db.resetToDefault();
  }
}
