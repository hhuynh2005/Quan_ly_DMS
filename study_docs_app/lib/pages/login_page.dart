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
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: GoogleAuthService.activeUserNotifier,
            builder: (context, _, __) {
              final profile = _authService.getUserProfile();
              if (profile['signedIn'] == true) {
                return _buildSignedInView(context, profile, isDark);
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
  Widget _buildSignedInView(BuildContext context, Map<String, dynamic> user, bool isDark) {
    final email = user['email']?.toString() ?? '';
    final displayName = user['displayName']?.toString() ?? 'Người dùng';
    final photoUrl = user['photoUrl']?.toString();
    final uid = user['uid']?.toString() ?? '';
    final badge = user['badge']?.toString() ?? 'Khách';
    final isStudent = user['isStudent'] == true;
    final lastSignIn = user['lastSignInTime']?.toString().split('.').first ?? 'Vừa xong';

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
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
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
                  displayName,
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
                  label: 'Định danh (UID)',
                  value: uid,
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  icon: Icons.shield_rounded,
                  label: 'Phân quyền',
                  value: isStudent ? 'Sinh viên xác thực' : 'Tài khoản thường',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  icon: Icons.access_time_rounded,
                  label: 'Phiên hoạt động',
                  value: lastSignIn,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Khối chuyển đổi 3 tài khoản thử nghiệm
        _buildTestAccountCard(context, isDark, email),

        const SizedBox(height: 16),

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

        const SizedBox(height: 18),

        // Hoặc kiểm thử phân quyền 3 tài khoản (Checklist Mục 6)
        _buildTestAccountCard(context, isDark, ''),
      ],
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

  Widget _buildTestAccountCard(BuildContext context, bool isDark, String currentEmail) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: const Color(0xFF3ECF8E).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3ECF8E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.supervisor_account_rounded,
                    color: Color(0xFF3ECF8E),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kiểm Thử Phân Quyền RLS (Mục 6)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '1 chạm chuyển đổi 3 tài khoản để quay video & test',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tài khoản A (Owner)
            _buildTestAccountTile(
              context: context,
              roleBadge: 'Tài khoản A • Chủ sở hữu (Owner)',
              email: 'owner_user_a@e.tlu.edu.vn',
              displayName: 'Nguyễn Văn A (Owner)',
              uid: 'user_a_owner_tlueduvn',
              badgeColor: Colors.amber.shade700,
              icon: Icons.workspace_premium_rounded,
              isCurrent: currentEmail == 'owner_user_a@e.tlu.edu.vn',
              permissionDesc: 'Toàn quyền: Đọc, Sửa, Chia sẻ, Xóa tài liệu',
            ),
            const SizedBox(height: 8),

            // Tài khoản B (Shared)
            _buildTestAccountTile(
              context: context,
              roleBadge: 'Tài khoản B • Thành viên chia sẻ (Shared)',
              email: 'shared_user_b@e.tlu.edu.vn',
              displayName: 'Trần Thị B (Shared Member)',
              uid: 'user_b_shared_tlueduvn',
              badgeColor: Colors.blue.shade600,
              icon: Icons.share_rounded,
              isCurrent: currentEmail == 'shared_user_b@e.tlu.edu.vn',
              permissionDesc: 'Cấp Viewer (Chỉ xem) hoặc Editor (Sửa), không được Xóa',
            ),
            const SizedBox(height: 8),

            // Tài khoản C (Stranger)
            _buildTestAccountTile(
              context: context,
              roleBadge: 'Tài khoản C • Người dùng ngoài (Stranger)',
              email: 'stranger_user_c@gmail.com',
              displayName: 'Lê Văn C (Người lạ)',
              uid: 'user_c_stranger_gmailcom',
              badgeColor: Colors.red.shade400,
              icon: Icons.block_rounded,
              isCurrent: currentEmail == 'stranger_user_c@gmail.com',
              permissionDesc: 'RLS chặn hoàn toàn truy cập vào tài liệu riêng tư',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestAccountTile({
    required BuildContext context,
    required String roleBadge,
    required String email,
    required String displayName,
    required String uid,
    required Color badgeColor,
    required IconData icon,
    required bool isCurrent,
    required String permissionDesc,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await _authService.switchAccount(
          uid: uid,
          email: email,
          displayName: displayName,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: badgeColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Đã kích hoạt: $displayName\nEmail: $email'),
                  ),
                ],
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent
              ? badgeColor.withValues(alpha: 0.12)
              : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent ? badgeColor : Colors.grey.withValues(alpha: 0.25),
            width: isCurrent ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: badgeColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          roleBadge,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ĐANG CHỌN',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    permissionDesc,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.touch_app_rounded, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
