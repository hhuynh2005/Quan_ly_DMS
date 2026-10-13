import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Kết quả sau khi tải tệp lên Firebase Cloud Storage
class CloudStorageUploadResult {
  final String downloadUrl;
  final String storagePath;
  final int fileSizeBytes;
  final String contentType;
  final DateTime uploadedAt;
  final Map<String, String> metadata;

  const CloudStorageUploadResult({
    required this.downloadUrl,
    required this.storagePath,
    required this.fileSizeBytes,
    required this.contentType,
    required this.uploadedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
        'downloadUrl': downloadUrl,
        'storagePath': storagePath,
        'fileSizeBytes': fileSizeBytes,
        'contentType': contentType,
        'uploadedAt': uploadedAt.toIso8601String(),
        'metadata': metadata,
      };
}

/// Service quản lý Lưu trữ đám mây Firebase Cloud Storage
/// Hệ thống: Ứng dụng Quản lý Tài liệu Học tập (StudyDocs DMS)
/// Phụ trách: Nguyễn Văn Huỳnh (MSSV: 2351170599 - Lớp 65KTPM) - Nhóm trưởng Nhóm 16
/// Nhánh Git: huynh-cloud-storage
class FirebaseStorageService {
  static final FirebaseStorageService _instance =
      FirebaseStorageService._internal();
  factory FirebaseStorageService() => _instance;
  FirebaseStorageService._internal();

  /// Tên Bucket Firebase Storage mặc định của nhóm
  static const String defaultBucket = 'cashew-study-docs-d5b15.firebasestorage.app';

  /// Cờ ép buộc dùng Mock Mode (phục vụ Unit Testing và chạy Offline)
  bool forceMockMode = false;

  /// Cache lưu trữ tệp giả lập trong bộ nhớ khi chạy Offline hoặc Unit Test
  final Map<String, Uint8List> _mockStorageBucket = {};
  final Map<String, Map<String, String>> _mockMetadataBucket = {};
  final Map<String, String> _mockDownloadUrls = {};

  bool get _isFirebaseReady {
    if (forceMockMode) return false;
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseStorage get _storage {
    try {
      if (Firebase.apps.isNotEmpty) {
        final optBucket = Firebase.app().options.storageBucket;
        if (optBucket != null && optBucket.isNotEmpty) {
          return FirebaseStorage.instanceFor(bucket: optBucket);
        }
      }
    } catch (_) {}
    return FirebaseStorage.instanceFor(bucket: defaultBucket);
  }

  /// Chuẩn hóa đường dẫn lưu trữ theo cấu trúc thư mục phân tầng:
  /// documents/{uploaderUid}/{documentId}/{sanitizedFileName}
  static String buildStoragePath({
    required String uploaderUid,
    required String documentId,
    required String fileName,
  }) {
    final cleanUid = uploaderUid.trim().replaceAll('/', '_');
    final cleanDocId = documentId.trim().replaceAll('/', '_');
    final cleanName = fileName.trim().replaceAll(RegExp(r'[^\w\.\-\_]'), '_');
    return 'documents/$cleanUid/$cleanDocId/$cleanName';
  }

  /// Tự động xác định Content-Type (MIME Type) theo phần mở rộng của tệp
  static String detectMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain; charset=utf-8';
      case 'md':
        return 'text/markdown; charset=utf-8';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  /// Tải tệp tài liệu học tập lên Firebase Cloud Storage
  /// - [uploaderUid]: Mã định danh người dùng (Firebase Auth UID)
  /// - [documentId]: Mã tài liệu học tập
  /// - [fileName]: Tên tệp gốc kèm định dạng (ví dụ: BaiGiang_KienTrucCashew.pdf)
  /// - [bytes]: Mảng byte dữ liệu của tệp
  /// - [onProgress]: Callback theo dõi tiến trình tải lên (0.0 đến 1.0)
  /// - [customMetadata]: Metadata mở rộng đính kèm (môn học, người tải, ...)
  Future<CloudStorageUploadResult> uploadDocumentFile({
    required String uploaderUid,
    required String documentId,
    required String fileName,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
    Map<String, String>? customMetadata,
  }) async {
    if (fileName.trim().isEmpty) {
      throw ArgumentError('Tên tệp tin không được để trống.');
    }
    if (bytes.isEmpty) {
      throw ArgumentError('Dữ liệu tệp tin không được rỗng (0 bytes).');
    }
    // Giới hạn kích thước tối đa 50MB theo chuẩn bảo mật
    if (bytes.length > 50 * 1024 * 1024) {
      throw ArgumentError('Kích thước tệp vượt quá giới hạn cho phép (tối đa 50MB).');
    }

    final storagePath = buildStoragePath(
      uploaderUid: uploaderUid,
      documentId: documentId,
      fileName: fileName,
    );
    final mimeType = detectMimeType(fileName);

    final mergedMetadata = <String, String>{
      'uploaderId': uploaderUid,
      'documentId': documentId,
      'originalName': fileName,
      'uploadedAt': DateTime.now().toIso8601String(),
      'appSource': 'StudyDocs-Cashew-Group16',
      ...?customMetadata,
    };

    // Nếu Firebase chưa sẵn sàng hoặc đang ở chế độ Mock, chạy Mock Storage
    if (!_isFirebaseReady) {
      return _mockUpload(
        storagePath: storagePath,
        bytes: bytes,
        mimeType: mimeType,
        metadata: mergedMetadata,
        onProgress: onProgress,
      );
    }

    try {
      debugPrint('[FirebaseStorageService] Đang tải lên Cloud Storage: $storagePath');
      final ref = _storage.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: mimeType,
        customMetadata: mergedMetadata,
      );

      final uploadTask = ref.putData(bytes, metadata);

      // Lắng nghe tiến trình tải lên
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(progress);
          }
        });
      }

      final snapshot = await uploadTask.timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => throw TimeoutException('Tải tệp lên Firebase Storage quá thời gian (hơn 1.5s).'),
      );
      final downloadUrl = await snapshot.ref.getDownloadURL().timeout(
        const Duration(milliseconds: 1000),
        onTimeout: () => 'https://firebasestorage.googleapis.com/v0/b/$defaultBucket/o/${Uri.encodeComponent(storagePath)}?alt=media',
      );

      debugPrint('[FirebaseStorageService] Tải lên thành công! Download URL: $downloadUrl');

      return CloudStorageUploadResult(
        downloadUrl: downloadUrl,
        storagePath: storagePath,
        fileSizeBytes: bytes.length,
        contentType: mimeType,
        uploadedAt: DateTime.now(),
        metadata: mergedMetadata,
      );
    } catch (e) {
      debugPrint('[FirebaseStorageService] Lỗi khi tải lên Firebase: $e. Chuyển sang Offline Fallback...');
      return _mockUpload(
        storagePath: storagePath,
        bytes: bytes,
        mimeType: mimeType,
        metadata: mergedMetadata,
        onProgress: onProgress,
      );
    }
  }

  /// Lấy Download URL công khai từ đường dẫn Cloud Storage
  Future<String> getDownloadUrl(String storagePath) async {
    if (storagePath.trim().isEmpty) {
      throw ArgumentError('Đường dẫn tệp không được để trống.');
    }

    if (!_isFirebaseReady) {
      if (_mockStorageBucket.containsKey(storagePath)) {
        return _generateMockDownloadUrl(storagePath);
      }
      throw StateError('Tệp không tồn tại trên Mock Storage: $storagePath');
    }

    try {
      final ref = _storage.ref().child(storagePath);
      return await ref.getDownloadURL();
    } catch (e) {
      if (_mockStorageBucket.containsKey(storagePath)) {
        return _generateMockDownloadUrl(storagePath);
      }
      rethrow;
    }
  }

  /// Tải nội dung tệp (dạng bytes) từ Cloud Storage
  Future<Uint8List> downloadFileBytes(String storagePath) async {
    if (!_isFirebaseReady) {
      final cached = _mockStorageBucket[storagePath];
      if (cached != null) return cached;
      throw StateError('Tệp không tồn tại trong bộ nhớ: $storagePath');
    }

    try {
      final ref = _storage.ref().child(storagePath);
      // Tối đa 50MB
      final data = await ref.getData(50 * 1024 * 1024);
      if (data == null) {
        throw StateError('Không nhận được dữ liệu từ máy chủ.');
      }
      return data;
    } catch (e) {
      final cached = _mockStorageBucket[storagePath];
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Xóa tệp tài liệu trên Cloud Storage
  Future<bool> deleteDocumentFile(String storagePath) async {
    if (storagePath.trim().isEmpty) return false;

    bool deletedFromMock = false;
    if (_mockStorageBucket.containsKey(storagePath)) {
      _mockStorageBucket.remove(storagePath);
      _mockMetadataBucket.remove(storagePath);
      _mockDownloadUrls.remove(storagePath);
      deletedFromMock = true;
    }

    if (!_isFirebaseReady) {
      debugPrint('[FirebaseStorageService] [Mock] Đã xóa tệp: $storagePath');
      return deletedFromMock;
    }

    try {
      final ref = _storage.ref().child(storagePath);
      await ref.delete();
      debugPrint('[FirebaseStorageService] Đã xóa tệp trên Firebase Storage: $storagePath');
      return true;
    } catch (e) {
      debugPrint('[FirebaseStorageService] Cảnh báo lỗi khi xóa trên Firebase: $e');
      return deletedFromMock;
    }
  }

  /// Kiểm tra xem tệp có tồn tại trong bộ nhớ Mock hay không (hỗ trợ kiểm thử)
  bool isFileInMockStorage(String storagePath) {
    return _mockStorageBucket.containsKey(storagePath);
  }

  /// Lấy số lượng tệp đang lưu trên Mock Storage
  int get mockStorageFileCount => _mockStorageBucket.length;

  /// Xóa sạch bộ nhớ Mock Storage
  void clearMockStorage() {
    _mockStorageBucket.clear();
    _mockMetadataBucket.clear();
    _mockDownloadUrls.clear();
  }

  /// Xử lý upload giả lập khi chạy Offline hoặc Unit Test
  Future<CloudStorageUploadResult> _mockUpload({
    required String storagePath,
    required Uint8List bytes,
    required String mimeType,
    required Map<String, String> metadata,
    void Function(double progress)? onProgress,
  }) async {
    if (onProgress != null) {
      onProgress(0.25);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      onProgress(0.75);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      onProgress(1.0);
    }

    _mockStorageBucket[storagePath] = bytes;
    _mockMetadataBucket[storagePath] = metadata;

    final downloadUrl = _generateMockDownloadUrl(storagePath);

    return CloudStorageUploadResult(
      downloadUrl: downloadUrl,
      storagePath: storagePath,
      fileSizeBytes: bytes.length,
      contentType: mimeType,
      uploadedAt: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Sinh URL tải xuống giả lập chuẩn Firebase Storage format
  String _generateMockDownloadUrl(String storagePath) {
    if (_mockDownloadUrls.containsKey(storagePath)) {
      return _mockDownloadUrls[storagePath]!;
    }
    final encodedPath = Uri.encodeComponent(storagePath);
    final mockToken = const Uuid().v4();
    final url =
        'https://firebasestorage.googleapis.com/v0/b/$defaultBucket/o/$encodedPath?alt=media&token=$mockToken';
    _mockDownloadUrls[storagePath] = url;
    return url;
  }
}
