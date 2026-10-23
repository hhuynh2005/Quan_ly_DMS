import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  /// Stream theo dõi thay đổi trạng thái đăng nhập thời gian thực
  Stream<User?> get authStateChanges =>
      _isFirebaseInitialized ? _auth.authStateChanges() : const Stream<User?>.empty();

  /// Lấy thông tin người dùng Firebase hiện tại
  User? get currentUser =>
      _isFirebaseInitialized ? _auth.currentUser : null;

  /// Kiểm tra xem người dùng đã đăng nhập hay chưa
  bool get isSignedIn => currentUser != null;

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

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        final UserCredential userCredential =
            await _auth.signInWithPopup(googleProvider);
        final User? user = userCredential.user;
        if (user != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('currentUserEmail', user.email ?? '');
          await prefs.setString('currentUserName', user.displayName ?? '');
        }
        return userCredential;
      }

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

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final User? user = userCredential.user;
      if (user != null) {
        debugPrint(
            '[GoogleAuthService] Đăng nhập Firebase Auth thành công: ${user.email} (${user.uid})');

        // Lưu thông tin người dùng vào Local Storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentUserEmail', user.email ?? '');
        await prefs.setString('currentUserName', user.displayName ?? '');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[GoogleAuthService] Lỗi FirebaseAuth: [${e.code}] ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[GoogleAuthService] Lỗi ngoại lệ Google Sign-In: $e');
      rethrow;
    }
  }

  /// Đăng nhập nhanh tài khoản sinh viên TLU mô phỏng kiểm thử đồ án TH2
  Future<User?> signInWithStudentAccount({
    required String email,
    required String displayName,
  }) async {
    try {
      debugPrint('[GoogleAuthService] Đăng nhập nhanh sinh viên: $email');
      User? user;
      if (_isFirebaseInitialized) {
        try {
          final cred = await _auth.signInAnonymously();
          user = cred.user;
          await user?.updateDisplayName(displayName);
        } catch (e) {
          debugPrint('[GoogleAuthService] Anonymous sign-in: $e');
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUserEmail', email);
      await prefs.setString('currentUserName', displayName);
      return user;
    } catch (e) {
      debugPrint('[GoogleAuthService] Lỗi signInWithStudentAccount: $e');
      rethrow;
    }
  }

  /// Đăng xuất khỏi Firebase Auth và Google Sign-In
  Future<void> signOut() async {
    try {
      debugPrint('[GoogleAuthService] Đang thực hiện đăng xuất...');
      if (_isFirebaseInitialized) {
        await _auth.signOut();
      }
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // Xóa thông tin session trong Local Storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentUserEmail');
      await prefs.remove('currentUserName');
      debugPrint('[GoogleAuthService] Đã đăng xuất thành công.');
    } catch (e) {
      debugPrint('[GoogleAuthService] Lỗi khi đăng xuất: $e');
      rethrow;
    }
  }

  /// Lấy thông tin tóm tắt hồ sơ người dùng phục vụ hiển thị UI
  Map<String, dynamic> getUserProfile() {
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
