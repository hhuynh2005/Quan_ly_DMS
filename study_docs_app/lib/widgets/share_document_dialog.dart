import 'package:flutter/material.dart';
import '../struct/supabase_service.dart';
import '../theme.dart';

/// Hộp thoại Chia sẻ Tài liệu (Document Sharing Dialog)
/// Cho phép chia sẻ tài liệu an toàn giữa các người dùng với phân quyền RLS
class ShareDocumentDialog extends StatefulWidget {
  final String documentId;
  final String documentTitle;
  final String ownerEmail;
  final String currentUserEmail;

  const ShareDocumentDialog({
    super.key,
    required this.documentId,
    required this.documentTitle,
    required this.ownerEmail,
    required this.currentUserEmail,
  });

  static Future<void> show({
    required BuildContext context,
    required String documentId,
    required String documentTitle,
    required String ownerEmail,
    required String currentUserEmail,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ShareDocumentDialog(
        documentId: documentId,
        documentTitle: documentTitle,
        ownerEmail: ownerEmail,
        currentUserEmail: currentUserEmail,
      ),
    );
  }

  @override
  State<ShareDocumentDialog> createState() => _ShareDocumentDialogState();
}

class _ShareDocumentDialogState extends State<ShareDocumentDialog> {
  final _emailController = TextEditingController();
  SharePermissionLevel _selectedPermission = SharePermissionLevel.viewer;
  bool _isLoading = false;
  List<SupabaseDocumentShare> _shares = [];

  @override
  void initState() {
    super.initState();
    _loadShares();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadShares() async {
    setState(() => _isLoading = true);
    final shares = await SupabaseService().getDocumentShares(widget.documentId);
    if (mounted) {
      setState(() {
        _shares = shares;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleShare() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập email người nhận!')),
      );
      return;
    }

    if (email.toLowerCase() == widget.ownerEmail.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tự chia sẻ tài liệu cho chính chủ sở hữu!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await SupabaseService().shareDocument(
      documentId: widget.documentId,
      targetEmail: email,
      permissionLevel: _selectedPermission,
      ownerEmail: widget.currentUserEmail,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        _emailController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryColor,
            content: Text('Đã chia sẻ tài liệu cho $email (${_selectedPermission.displayName}) thành công!'),
          ),
        );
        _loadShares();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Không thể chia sẻ. Chỉ chủ sở hữu mới có quyền cấp quyền!'),
          ),
        );
      }
    }
  }

  Future<void> _handleRemoveShare(String shareId, String targetEmail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi quyền truy cập'),
        content: Text('Bạn có chắc chắn muốn thu hồi quyền truy cập của $targetEmail?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final ok = await SupabaseService().removeShare(
        shareId: shareId,
        ownerEmail: widget.currentUserEmail,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã thu hồi quyền của $targetEmail')),
          );
          _loadShares();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.currentUserEmail.toLowerCase() == widget.ownerEmail.toLowerCase();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.share_rounded, color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chia Sẻ Tài Liệu', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(
                  widget.documentTitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isOwner)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bạn không phải chủ sở hữu tài liệu này. Chỉ chủ sở hữu mới có quyền phân quyền chia sẻ.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Form nhập email chia sẻ
              if (isOwner) ...[
                const Text('Thêm người nhận:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: 'Nhập email sinh viên (VD: user@e.tlu.edu.vn)',
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Quyền hạn:', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 12),
                    DropdownButton<SharePermissionLevel>(
                      value: _selectedPermission,
                      borderRadius: BorderRadius.circular(12),
                      items: SharePermissionLevel.values.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(p.displayName, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPermission = val);
                      },
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isLoading ? null : _handleShare,
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Chia sẻ'),
                    ),
                  ],
                ),
                const Divider(height: 28),
              ],

              // Danh sách người đã được chia sẻ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Danh sách được cấp quyền:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(
                    'Chủ sở hữu: ${widget.ownerEmail}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
              else if (_shares.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'Tài liệu này chưa được chia sẻ cho người dùng nào khác.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _shares.length,
                  separatorBuilder: (_, __) => const Divider(height: 8),
                  itemBuilder: (ctx, index) {
                    final share = _shares[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                        child: Text(
                          share.sharedWithEmail.isNotEmpty ? share.sharedWithEmail[0].toUpperCase() : 'U',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      title: Text(share.sharedWithEmail, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        share.permissionLevel == SharePermissionLevel.editor ? 'Quyền: Chỉnh sửa (Editor)' : 'Quyền: Chỉ xem (Viewer)',
                        style: TextStyle(
                          fontSize: 11,
                          color: share.permissionLevel == SharePermissionLevel.editor ? Colors.orange.shade800 : Colors.blue.shade800,
                        ),
                      ),
                      trailing: isOwner
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                              tooltip: 'Thu hồi quyền',
                              onPressed: () => _handleRemoveShare(share.id, share.sharedWithEmail),
                            )
                          : null,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
