import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_options.dart';

/// Mô hình quyền hạn chia sẻ
enum SharePermissionLevel {
  viewer,
  editor,
}

extension SharePermissionLevelExt on SharePermissionLevel {
  String get value => name;
  String get displayName {
    switch (this) {
      case SharePermissionLevel.viewer:
        return 'Chỉ xem (Viewer)';
      case SharePermissionLevel.editor:
        return 'Chỉnh sửa (Editor)';
    }
  }

  static SharePermissionLevel fromString(String? val) {
    if (val == 'editor') return SharePermissionLevel.editor;
    return SharePermissionLevel.viewer;
  }
}

/// Mô hình bản ghi chia sẻ tài liệu
class SupabaseDocumentShare {
  final String id;
  final String documentId;
  final String sharedWithEmail;
  final SharePermissionLevel permissionLevel;
  final DateTime createdAt;

  SupabaseDocumentShare({
    required this.id,
    required this.documentId,
    required this.sharedWithEmail,
    required this.permissionLevel,
    required this.createdAt,
  });

  factory SupabaseDocumentShare.fromMap(Map<String, dynamic> map) {
    return SupabaseDocumentShare(
      id: map['id']?.toString() ?? '',
      documentId: map['document_id']?.toString() ?? '',
      sharedWithEmail: map['shared_with_email']?.toString() ?? '',
      permissionLevel: SharePermissionLevelExt.fromString(map['permission_level']?.toString()),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Dịch vụ quản lý Cơ sở dữ liệu Supabase kết hợp Firebase
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isInitialized = false;

  /// Khởi tạo Supabase client
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
      _isInitialized = true;
      debugPrint('[SupabaseService] Khởi tạo thành công kết nối tới ${SupabaseConfig.url}');
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khởi tạo Supabase: $e');
    }
  }

  SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isReady => client != null;

  // ========================================================
  // 1. ĐỒNG BỘ NGƯỜI DÙNG TỪ FIREBASE AUTH SANG SUPABASE
  // ========================================================
  Future<bool> syncFirebaseUser(fb_auth.User firebaseUser) async {
    final cli = client;
    if (cli == null) return false;

    try {
      final email = firebaseUser.email ?? '';
      if (email.isEmpty) return false;

      final userData = {
        'id': firebaseUser.uid,
        'email': email.toLowerCase().trim(),
        'display_name': firebaseUser.displayName ?? email.split('@').first,
        'photo_url': firebaseUser.photoURL ?? '',
      };

      await cli.from('users').upsert(userData);
      debugPrint('[SupabaseService] Đã đồng bộ User sang Supabase: $email (${firebaseUser.uid})');
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi đồng bộ user sang Supabase: $e');
      return false;
    }
  }

  // ========================================================
  // 2. QUẢN LÝ TÀI LIỆU (DOCUMENTS - METADATA + LINK FIREBASE STORAGE)
  // ========================================================
  Future<Map<String, dynamic>?> createDocument({
    required String title,
    String? description,
    String? subject,
    required String fileFormat,
    int fileSizeBytes = 0,
    required String fileUrl,
    required String storagePath,
    required String ownerId,
    required String ownerEmail,
    bool isPublic = false,
  }) async {
    final cli = client;
    if (cli == null) return null;

    try {
      final docData = {
        'title': title,
        'description': description ?? '',
        'subject': subject ?? 'Chung',
        'file_format': fileFormat,
        'file_size_bytes': fileSizeBytes,
        'file_url': fileUrl,
        'storage_path': storagePath,
        'owner_id': ownerId,
        'owner_email': ownerEmail.toLowerCase().trim(),
        'is_public': isPublic,
      };

      final response = await cli
          .from('documents')
          .insert(docData)
          .select()
          .single()
          .timeout(const Duration(seconds: 4));
      debugPrint('[SupabaseService] Đã tạo tài liệu thành công: $title');
      return response;
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi tạo tài liệu trên Supabase: $e');
      return null;
    }
  }

  /// Lấy danh sách tài liệu (Hỗ trợ tìm kiếm, lọc môn học, định dạng)
  Future<List<Map<String, dynamic>>> getDocuments({
    String? currentUserEmail,
    String? searchQuery,
    String? subject,
    String? fileFormat,
    bool sharedOnly = false,
  }) async {
    final cli = client;
    if (cli == null) return [];

    try {
      final email = currentUserEmail?.toLowerCase().trim() ?? '';

      // 1. Lấy danh sách document_id được chia sẻ cho user
      List<String> sharedDocIds = [];
      if (email.isNotEmpty) {
        final shares = await cli
            .from('document_shares')
            .select('document_id')
            .eq('shared_with_email', email)
            .timeout(const Duration(seconds: 4), onTimeout: () => []);
        sharedDocIds = (shares as List)
            .map((s) => s['document_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
      }

      var query = cli.from('documents').select('*');

      if (sharedOnly) {
        if (sharedDocIds.isEmpty) return [];
        query = query.inFilter('id', sharedDocIds);
      } else if (email.isNotEmpty) {
        // Lấy tài liệu của tôi, hoặc công khai, hoặc được chia sẻ
        if (sharedDocIds.isNotEmpty) {
          query = query.or('owner_email.eq.$email,is_public.eq.true,id.in.(${sharedDocIds.join(",")})');
        } else {
          query = query.or('owner_email.eq.$email,is_public.eq.true');
        }
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query.or('title.ilike.%$q%,description.ilike.%$q%,subject.ilike.%$q%');
      }

      if (subject != null && subject.isNotEmpty && subject != 'Tất cả') {
        query = query.eq('subject', subject);
      }

      if (fileFormat != null && fileFormat.isNotEmpty && fileFormat != 'Tất cả') {
        query = query.eq('file_format', fileFormat);
      }

      final data = await query
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 4), onTimeout: () => []);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi lấy danh sách tài liệu: $e');
      return [];
    }
  }

  /// Cập nhật thông tin tài liệu
  Future<bool> updateDocument({
    required String documentId,
    required String title,
    String? description,
    String? subject,
    bool? isPublic,
    required String userEmail,
  }) async {
    final cli = client;
    if (cli == null) return false;

    try {
      // Kiểm tra quyền (chủ sở hữu hoặc editor)
      final permission = await checkUserPermission(
        documentId: documentId,
        userEmail: userEmail,
      );

      if (permission != 'owner' && permission != 'editor') {
        debugPrint('[SupabaseService] Không có quyền chỉnh sửa tài liệu: $userEmail');
        return false;
      }

      final updateData = <String, dynamic>{
        'title': title,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (description != null) updateData['description'] = description;
      if (subject != null) updateData['subject'] = subject;
      if (isPublic != null) updateData['is_public'] = isPublic;

      await cli.from('documents').update(updateData).eq('id', documentId);
      debugPrint('[SupabaseService] Cập nhật tài liệu thành công: $documentId');
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi cập nhật tài liệu: $e');
      return false;
    }
  }

  /// Xóa tài liệu (Chỉ chủ sở hữu mới có quyền xóa)
  Future<bool> deleteDocument({
    required String documentId,
    required String userEmail,
  }) async {
    final cli = client;
    if (cli == null) return false;

    try {
      final permission = await checkUserPermission(
        documentId: documentId,
        userEmail: userEmail,
      );

      if (permission != 'owner') {
        debugPrint('[SupabaseService] Chỉ chủ sở hữu mới có quyền xóa tài liệu!');
        return false;
      }

      await cli.from('documents').delete().eq('id', documentId);
      debugPrint('[SupabaseService] Đã xóa tài liệu: $documentId');
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi xóa tài liệu: $e');
      return false;
    }
  }

  // ========================================================
  // 3. TÍNH NĂNG CHIA SẺ TÀI LIỆU (DOCUMENT SHARING & PERMISSIONS)
  // ========================================================
  Future<bool> shareDocument({
    required String documentId,
    required String targetEmail,
    SharePermissionLevel permissionLevel = SharePermissionLevel.viewer,
    required String ownerEmail,
  }) async {
    final cli = client;
    if (cli == null) return false;

    try {
      final normTargetEmail = targetEmail.toLowerCase().trim();
      final normOwnerEmail = ownerEmail.toLowerCase().trim();

      if (normTargetEmail.isEmpty || normTargetEmail == normOwnerEmail) {
        return false;
      }

      // Kiểm tra xem người gọi có phải chủ sở hữu tài liệu không
      final doc = await cli
          .from('documents')
          .select('owner_email')
          .eq('id', documentId)
          .maybeSingle();

      if (doc == null || (doc['owner_email'] as String).toLowerCase() != normOwnerEmail) {
        debugPrint('[SupabaseService] Chỉ chủ sở hữu mới được cấp quyền chia sẻ tài liệu!');
        return false;
      }

      await cli.from('document_shares').upsert({
        'document_id': documentId,
        'shared_with_email': normTargetEmail,
        'permission_level': permissionLevel.value,
      });

      debugPrint('[SupabaseService] Đã chia sẻ tài liệu $documentId cho $normTargetEmail (${permissionLevel.value})');
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi chia sẻ tài liệu: $e');
      return false;
    }
  }

  /// Lấy danh sách những người được chia sẻ của một tài liệu
  Future<List<SupabaseDocumentShare>> getDocumentShares(String documentId) async {
    final cli = client;
    if (cli == null) return [];

    try {
      final data = await cli
          .from('document_shares')
          .select('*')
          .eq('document_id', documentId)
          .order('created_at', ascending: true);

      return (data as List).map((m) => SupabaseDocumentShare.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi lấy danh sách chia sẻ: $e');
      return [];
    }
  }

  /// Hủy quyền chia sẻ
  Future<bool> removeShare({
    required String shareId,
    required String ownerEmail,
  }) async {
    final cli = client;
    if (cli == null) return false;

    try {
      await cli.from('document_shares').delete().eq('id', shareId);
      debugPrint('[SupabaseService] Đã thu hồi quyền chia sẻ: $shareId');
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi thu hồi chia sẻ: $e');
      return false;
    }
  }

  /// Kiểm tra vai trò quyền hạn của người dùng đối với một tài liệu cụ thể:
  /// Trả về: 'owner', 'editor', 'viewer', hoặc 'none'
  Future<String> checkUserPermission({
    required String documentId,
    required String userEmail,
  }) async {
    final cli = client;
    if (cli == null) return 'none';

    try {
      final email = userEmail.toLowerCase().trim();

      // 1. Kiểm tra có phải Owner không
      final doc = await cli
          .from('documents')
          .select('owner_email, is_public')
          .eq('id', documentId)
          .maybeSingle();

      if (doc == null) return 'none';
      if ((doc['owner_email'] as String).toLowerCase() == email) {
        return 'owner';
      }

      // 2. Kiểm tra có được cấp quyền trong document_shares không
      final share = await cli
          .from('document_shares')
          .select('permission_level')
          .eq('document_id', documentId)
          .eq('shared_with_email', email)
          .maybeSingle();

      if (share != null) {
        return share['permission_level']?.toString() ?? 'viewer';
      }

      // 3. Nếu tài liệu công khai thì là viewer
      if (doc['is_public'] == true) {
        return 'viewer';
      }

      return 'none';
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi kiểm tra quyền hạn: $e');
      return 'none';
    }
  }
}
