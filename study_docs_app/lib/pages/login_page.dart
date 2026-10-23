import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../struct/google_auth_service.dart';
import '../theme.dart';

/// Màn hình Đăng nhập Google & Quản lý Trạng thái Xác thực (Auth State)
/// Ứng dụng: Quản lý Tài liệu Học tập (StudyDocs DMS)
/// Phụ trách: Lê Anh Tuấn (MSV: 2151060296) - Nhóm 16 (65KTPM - ĐH Thủy Lợi)
/// Nhánh Git: letuan-google-auth
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GoogleAuthService _authService = GoogleAuthService();
  bool _isLoading = false;

  Future<void> _handleStudentQuickSignIn(String email, String displayName) async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithStudentAccount(
        email: email,
        displayName: displayName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.school_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Đăng nhập thành công!\nSinh viên: $displayName ($email)',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Lỗi: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signInWithGoogle();
      if (!mounted) return;
      if (credential != null && credential.user != null) {
        final email = credential.user!.email ?? '';
        final isStudent = GoogleAuthService.isStudentEmail(email);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isStudent
                        ? 'Xin chào Sinh viên Thủy Lợi!\nĐã xác thực: $email'
                        : 'Đăng nhập Google thành công!\nĐã xác thực: $email',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Đăng nhập thất bại: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.blueGrey,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Đã đăng xuất tài khoản an toàn.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Lỗi khi đăng xuất: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác Thực Google Cloud'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Banner Nhóm 16
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF004D40), const Color(0xFF00796B)]
                    : [const Color(0xFFE0F2F1), const Color(0xFFB2DFDB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_sync_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NHÓM 16 — BÀI TẬP CLOUD DMS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Lê Anh Tuấn (2151060296) • Module Google Auth',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Xác thực một chạm Google Sign-In OAuth 2.0 tích hợp Firebase Authentication phục vụ hệ thống Quản lý Tài liệu Học tập.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Lắng nghe trạng thái Auth thời gian thực
          StreamBuilder<User?>(
            stream: _authService.authStateChanges,
            builder: (context, snapshot) {
              final User? user = snapshot.data;
              if (user != null) {
                return _buildSignedInView(context, user, isDark);
              } else {
                return _buildSignedOutView(context, isDark);
              }
            },
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// Giao diện khi người dùng ĐÃ ĐĂNG NHẬP
  Widget _buildSignedInView(BuildContext context, User user, bool isDark) {
    final email = user.email ?? '';
    final isStudent = GoogleAuthService.isStudentEmail(email);
    final badge = GoogleAuthService.getAccountBadge(email);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Avatar người dùng
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.2),
                      backgroundImage: user.photoURL != null
                          ? NetworkImage(user.photoURL!)
                          : null,
                      child: user.photoURL == null
                          ? Text(
                              user.displayName != null && user.displayName!.isNotEmpty
                                  ? user.displayName![0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            )
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text(
                  user.displayName ?? 'Người dùng Google',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),

                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Huy hiệu tài khoản
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isStudent
                        ? Colors.blue.withValues(alpha: 0.15)
                        : Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isStudent ? Colors.blue : Colors.green,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isStudent ? Icons.school_rounded : Icons.verified_user_rounded,
                        size: 16,
                        color: isStudent ? Colors.blue : Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        badge,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isStudent ? Colors.blue : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 32),

                // Thông số kỹ thuật phiên
                _buildInfoRow(
                  icon: Icons.fingerprint_rounded,
                  label: 'Firebase UID',
                  value: user.uid,
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  icon: Icons.shield_rounded,
                  label: 'Provider ID',
                  value: user.providerData.isNotEmpty
                      ? user.providerData.first.providerId
                      : 'google.com',
                  isDark: isDark,
                ),
                if (user.metadata.lastSignInTime != null) ...[
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    icon: Icons.access_time_rounded,
                    label: 'Đăng nhập gần nhất',
                    value: user.metadata.lastSignInTime.toString().split('.').first,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Nút Đăng xuất
        ElevatedButton.icon(
          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          label: Text(
            _isLoading ? 'Đang xử lý...' : 'Đăng xuất khỏi tài khoản',
            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isLoading ? null : _handleSignOut,
        ),

        const SizedBox(height: 10),

        // Nút Trở về trang Dashboard
        FilledButton.icon(
          icon: const Icon(Icons.folder_shared_rounded),
          label: const Text('Quay lại Quản lý Tài liệu'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// Giao diện khi người dùng CHƯA ĐĂNG NHẬP
  Widget _buildSignedOutView(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  size: 64,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Đăng Nhập Tài Khoản',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Đăng nhập bằng tài khoản Google để đồng bộ và truy cập tài liệu học tập trên đám mây Firebase.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                _buildFeatureBullet(
                  icon: Icons.bolt_rounded,
                  title: 'Xác thực một chạm',
                  desc: 'Đăng nhập bảo mật chuẩn OAuth 2.0 từ Google.',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildFeatureBullet(
                  icon: Icons.school_outlined,
                  title: 'Nhận diện sinh viên Thủy Lợi',
                  desc: 'Tự động cấp huy hiệu cho email @e.tlu.edu.vn.',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildFeatureBullet(
                  icon: Icons.cloud_done_rounded,
                  title: 'Đồng bộ hóa đám mây',
                  desc: 'Sẵn sàng tích hợp Cloud Storage lưu trữ tệp.',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 22),

        // Nút Đăng nhập với Google
        FilledButton.icon(
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.g_mobiledata_rounded, size: 28),
          label: Text(
            _isLoading ? 'Đang kết nối...' : 'Đăng nhập với Google',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _isLoading ? null : _handleSignIn,
        ),

        const SizedBox(height: 16),

        // Thẻ đăng nhập nhanh kiểm thử TH2
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.amber, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Đăng Nhập Nhanh Kiểm Thử TH2',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Chọn 1 tài khoản thành viên Nhóm 16 để đăng nhập tức thì kiểm thử Checklist 4:',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                _buildQuickAccountTile(
                  name: 'Lê Anh Tuấn (Phụ trách Mượn/Trả)',
                  email: '2151060296@e.tlu.edu.vn',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildQuickAccountTile(
                  name: 'Nguyễn Văn Huỳnh (Nhóm trưởng)',
                  email: '2351170599@e.tlu.edu.vn',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildQuickAccountTile(
                  name: 'NGUYỄN TRUNG KIÊN (Responsive & Map)',
                  email: '2251172394@e.tlu.edu.vn',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildQuickAccountTile(
                  name: 'Trần Anh Tuấn (Recommendation & Tag)',
                  email: '2351170629@e.tlu.edu.vn',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccountTile({
    required String name,
    required String email,
    required bool isDark,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isLoading ? null : () => _handleStudentQuickSignIn(email, name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0] : 'S',
                style: const TextStyle(
                  fontSize: 13,
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
                    name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.white54 : Colors.black45),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureBullet({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
