import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

/// Service quản lý Xác thực Google Sign-In & Firebase Authentication
/// Hệ thống: Ứng dụng Quản lý Tài liệu Học tập (StudyDocs DMS)
/// Phụ trách: Lê Anh Tuấn (MSV: 2151060296) - Nhóm 16 (Lớp 65KTPM - ĐH Thủy Lợi)
/// Nhánh Git: letuan-google-auth
class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  bool get _isFirebaseInitialized {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;

  GoogleSignIn? _googleSignInInstance;
  GoogleSignIn get _googleSignIn => _googleSignInInstance ??= GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  static final ValueNotifier<Map<String, dynamic>?> activeUserNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  String? _demoEmail;
  String? _demoUid;
  String? _demoDisplayName;

  String get currentUserEmail => _demoEmail ?? currentUser?.email ?? '';
  String get currentUserId => _demoUid ?? currentUser?.uid ?? '';
  String get currentUserDisplayName => _demoDisplayName ?? currentUser?.displayName ?? '';
  bool get isDemoAccount => _demoEmail != null;

  /// Stream theo dõi thay đổi trạng thái đăng nhập thời gian thực
  Stream<User?> get authStateChanges =>
      _isFirebaseInitialized ? _auth.authStateChanges() : const Stream<User?>.empty();

  /// Lấy thông tin người dùng Firebase hiện tại
  User? get currentUser =>
      _isFirebaseInitialized ? _auth.currentUser : null;

  /// Kiểm tra xem người dùng đã đăng nhập hay chưa
  bool get isSignedIn => _demoEmail != null || currentUser != null;

  /// Kiểm tra xem email có thuộc tên miền trường Đại học Thủy Lợi hay không
  /// Định dạng email sinh viên TLU chuẩn: `<Mã_SV>@e.tlu.edu.vn`
  static bool isStudentEmail(String? email) {
    if (email == null) return false;
    final lower = email.toLowerCase().trim();
    return lower.endsWith('@e.tlu.edu.vn') ||
        lower.endsWith('@tlu.edu.vn') ||
        lower.endsWith('@thuyloi.edu.vn');
  }

  /// Phân loại cấp phát huy hiệu (Badge) người dùng
  static String getAccountBadge(String? email) {
    if (email == null || email.isEmpty) return 'Khách';
    if (isStudentEmail(email)) {
      return 'Sinh viên Thủy Lợi (TLU)';
    }
    return 'Google Account';
  }

  /// Thực hiện đăng nhập Google một chạm (Google Sign-In -> Firebase Auth)
  Future<UserCredential?> signInWithGoogle({bool silent = false}) async {
    try {
      debugPrint('[GoogleAuthService] Bắt đầu luồng đăng nhập Google...');

      UserCredential userCredential;

      if (kIsWeb) {
        // Trên nền tảng Web: Sử dụng Firebase Google Auth Provider Popup chính thức
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('https://www.googleapis.com/auth/userinfo.profile');
        // Yêu cầu Google luôn hiển thị màn hình chọn tài khoản, không bị kẹt hay crash
        googleProvider.setCustomParameters({
          'prompt': 'select_account',
        });
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        GoogleSignInAccount? googleAccount;
        if (silent) {
          googleAccount = await _googleSignIn.signInSilently();
        } else {
          googleAccount = await _googleSignIn.signIn();
        }

        if (googleAccount == null) {
          debugPrint('[GoogleAuthService] Người dùng đã hủy đăng nhập.');
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleAccount.authentication;

        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      final User? user = userCredential.user;
      if (user != null) {
        _demoEmail = null;
        _demoUid = null;
        _demoDisplayName = null;
        debugPrint(
            '[GoogleAuthService] Đăng nhập Firebase Auth thành công: ${user.email} (${user.uid})');

        // Lưu thông tin người dùng vào Local Storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentUserEmail', user.email ?? '');
        await prefs.setString('currentUserName', user.displayName ?? '');

        // Đồng bộ sang Supabase Database (bảng users)
        try {
          await SupabaseService().syncFirebaseUser(user);
        } catch (e) {
          debugPrint('[GoogleAuthService] Cảnh báo đồng bộ Supabase: $e');
        }

        activeUserNotifier.value = getUserProfile();
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[GoogleAuthService] Lỗi FirebaseAuth: [${e.code}] ${e.message}');
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        debugPrint('[GoogleAuthService] Người dùng đã đóng popup đăng nhập.');
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('[GoogleAuthService] Lỗi ngoại lệ Google Sign-In: $e');
      return null;
    }
  }

  /// Chuyển đổi nhanh giữa các tài khoản kiểm thử (Phục vụ Checklist Mục 6)
  Future<void> switchAccount({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    _demoUid = uid;
    _demoEmail = email.toLowerCase().trim();
    _demoDisplayName = displayName;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentUserEmail', _demoEmail!);
    await prefs.setString('currentUserName', _demoDisplayName!);
    await prefs.setString('currentUserId', _demoUid!);

    // Đồng bộ user sang Supabase
    try {
      await SupabaseService().client?.from('users').upsert({
        'id': _demoUid,
        'email': _demoEmail,
        'display_name': _demoDisplayName,
        'photo_url': '',
      });
    } catch (e) {
      debugPrint('[GoogleAuthService] Đồng bộ tài khoản sang Supabase: $e');
    }

    activeUserNotifier.value = getUserProfile();
    debugPrint('[GoogleAuthService] Đã chuyển sang tài khoản: $_demoEmail ($_demoDisplayName)');
  }

  /// Đăng xuất khỏi Firebase Auth và Google Sign-In
  Future<void> signOut() async {
    try {
      debugPrint('[GoogleAuthService] Đang thực hiện đăng xuất...');
      _demoEmail = null;
      _demoUid = null;
      _demoDisplayName = null;
      activeUserNotifier.value = null;

      if (_isFirebaseInitialized) {
        await _auth.signOut();
      }
      if (!kIsWeb) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }

      // Xóa thông tin session trong Local Storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentUserEmail');
      await prefs.remove('currentUserName');
      await prefs.remove('currentUserId');
      debugPrint('[GoogleAuthService] Đã đăng xuất thành công.');
    } catch (e) {
      debugPrint('[GoogleAuthService] Lỗi khi đăng xuất: $e');
    }
  }

  /// Lấy thông tin tóm tắt hồ sơ người dùng phục vụ hiển thị UI
  Map<String, dynamic> getUserProfile() {
    if (_demoEmail != null) {
      return <String, dynamic>{
        'signedIn': true,
        'displayName': _demoDisplayName ?? 'Demo User',
        'email': _demoEmail!,
        'photoUrl': null,
        'uid': _demoUid ?? 'demo_uid',
        'badge': getAccountBadge(_demoEmail),
        'isStudent': isStudentEmail(_demoEmail),
        'creationTime': DateTime.now(),
        'lastSignInTime': DateTime.now(),
      };
    }

    final User? user = currentUser;
    if (user == null) {
      return <String, dynamic>{
        'signedIn': false,
        'displayName': 'Chưa đăng nhập',
        'email': '',
        'photoUrl': null,
        'uid': '',
        'badge': 'Khách',
        'isStudent': false,
      };
    }

    final email = user.email ?? '';
    return <String, dynamic>{
      'signedIn': true,
      'displayName': user.displayName ?? (email.isNotEmpty ? email.split('@')[0] : 'Sinh viên TLU'),
      'email': email,
      'photoUrl': user.photoURL,
      'uid': user.uid,
      'badge': getAccountBadge(email),
      'isStudent': isStudentEmail(email),
      'creationTime': user.metadata.creationTime,
      'lastSignInTime': user.metadata.lastSignInTime,
    };
  }
}
