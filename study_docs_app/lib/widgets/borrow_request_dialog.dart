import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../struct/borrow_model.dart';
import '../struct/borrow_service.dart';
import '../struct/document_model.dart';
import '../theme.dart';

/// Hộp thoại Gửi Yêu Cầu Mượn Tài Liệu (Borrow Request Dialog)
/// Phụ trách: Lê Anh Tuấn (MSV: 2151060296) - Nhóm 16 TH2
class BorrowRequestDialog extends StatefulWidget {
  final Document document;
  final String currentUserEmail;
  final String currentUserName;

  static final List<Map<String, String>> teamAccounts = [
    {
      'email': '2351170599@e.tlu.edu.vn',
      'name': 'Nguyễn Văn Huỳnh (Nhóm trưởng)',
      'role': 'Trưởng nhóm TH2',
    },
    {
      'email': '2151060296@e.tlu.edu.vn',
      'name': 'Lê Anh Tuấn (Phụ trách Mượn/Trả)',
      'role': 'Thành viên TH2',
    },
    {
      'email': '2251172394@e.tlu.edu.vn',
      'name': 'NGUYỄN TRUNG KIÊN (Responsive & Map)',
      'role': 'Thành viên TH2',
    },
    {
      'email': '2351170629@e.tlu.edu.vn',
      'name': 'Trần Anh Tuấn (Recommendation & Tag)',
      'role': 'Thành viên TH2',
    },
  ];

  const BorrowRequestDialog({
    super.key,
    required this.document,
    required this.currentUserEmail,
    required this.currentUserName,
  });

  static Future<BorrowRequest?> show({
    required BuildContext context,
    required Document document,
    required String currentUserEmail,
    required String currentUserName,
  }) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    if (isWide) {
      return showDialog<BorrowRequest>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Material(
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: BorrowRequestDialog(
                document: document,
                currentUserEmail: currentUserEmail,
                currentUserName: currentUserName,
              ),
            ),
          ),
        ),
      );
    }
    return showModalBottomSheet<BorrowRequest>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BorrowRequestDialog(
        document: document,
        currentUserEmail: currentUserEmail,
        currentUserName: currentUserName,
      ),
    );
  }

  @override
  State<BorrowRequestDialog> createState() => _BorrowRequestDialogState();
}

class _BorrowRequestDialogState extends State<BorrowRequestDialog> {
  final _noteController = TextEditingController();
  final _customEmailController = TextEditingController();
  final _customNameController = TextEditingController();
  int _borrowDays = 7;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isSubmitting = false;
  bool _isCustomOwner = false;
  late Map<String, String> _selectedOwner;

  @override
  void initState() {
    super.initState();
    final others = BorrowRequestDialog.teamAccounts.where(
      (m) => m['email']?.toLowerCase() != widget.currentUserEmail.toLowerCase(),
    ).toList();
    _selectedOwner = others.isNotEmpty ? others.first : BorrowRequestDialog.teamAccounts.first;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _customEmailController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  void _updateDays(int days) {
    setState(() {
      _borrowDays = days;
      _dueDate = DateTime.now().add(Duration(days: days));
    });
  }

  Future<void> _submitRequest() async {
    setState(() => _isSubmitting = true);
    try {
      final borrowService = BorrowService();
      String ownerEmail;
      String ownerName;
      if (_isCustomOwner) {
        ownerEmail = _customEmailController.text.trim();
        ownerName = _customNameController.text.trim();
        if (ownerEmail.isEmpty || !ownerEmail.contains('@')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng nhập định dạng email hợp lệ cho chủ sở hữu!'),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() => _isSubmitting = false);
          return;
        }
        if (ownerName.isEmpty) {
          ownerName = ownerEmail.split('@').first;
        }
      } else {
        ownerEmail = _selectedOwner['email']!;
        ownerName = _selectedOwner['name']!;
      }

      final req = await borrowService.createBorrowRequest(
        documentId: widget.document.id,
        documentTitle: widget.document.title,
        borrowerId: widget.currentUserEmail,
        borrowerEmail: widget.currentUserEmail,
        borrowerName: widget.currentUserName.isNotEmpty
            ? widget.currentUserName
            : 'Sinh viên TLU',
        ownerId: ownerEmail,
        ownerEmail: ownerEmail,
        ownerName: ownerName,
        dueDate: _dueDate,
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : 'Mượn tài liệu phục vụ ôn tập học kỳ.',
      );

      if (mounted) {
        Navigator.of(context).pop(req);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi gửi yêu cầu mượn: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 24 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MediaQuery.sizeOf(context).width < 600)
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Tiêu đề BottomSheet
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Yêu Cầu Mượn Tài Liệu',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.document.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Đóng',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Thông tin người mượn
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.blueGrey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_rounded, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Người mượn: ${widget.currentUserName} (${widget.currentUserEmail})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Lựa chọn Chủ sở hữu tài liệu (Người duyệt mượn)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Chủ sở hữu tài liệu (Gửi yêu cầu tới):',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _isCustomOwner = !_isCustomOwner;
                  });
                },
                child: Text(
                  _isCustomOwner ? 'Chọn từ danh sách' : '✏️ Nhập email lạ...',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!_isCustomOwner) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.blueGrey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedOwner['email'],
                  isExpanded: true,
                  items: [
                    ...BorrowRequestDialog.teamAccounts.map((m) {
                      final isSelf = m['email']?.toLowerCase() == widget.currentUserEmail.toLowerCase();
                      return DropdownMenuItem<String>(
                        value: m['email'],
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_circle_rounded,
                              size: 18,
                              color: isSelf ? Colors.grey : AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${m['name']} (${m['email']})${isSelf ? " - (Bạn)" : ""}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelf ? FontWeight.bold : FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const DropdownMenuItem<String>(
                      value: '__custom__',
                      child: Row(
                        children: [
                          Icon(Icons.edit_note_rounded, size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            '✏️ Nhập email khác / Mail lạ...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (email) {
                    if (email == '__custom__') {
                      setState(() => _isCustomOwner = true);
                    } else if (email != null) {
                      setState(() {
                        _selectedOwner = BorrowRequestDialog.teamAccounts.firstWhere(
                          (m) => m['email'] == email,
                        );
                      });
                    }
                  },
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _customEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.alternate_email_rounded, size: 18),
                      labelText: 'Email chủ sở hữu tài liệu *',
                      hintText: 'Ví dụ: giangvien@tlu.edu.vn, ban.an@gmail.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customNameController,
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.badge_rounded, size: 18),
                      labelText: 'Tên chủ sở hữu (Tùy chọn)',
                      hintText: 'Ví dụ: Thầy Trần Hùng, Bạn An K65',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Lựa chọn thời gian mượn (Số ngày)
          const Text(
            'Thời hạn mượn dự kiến:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDayChip(3, '3 Ngày'),
              _buildDayChip(7, '7 Ngày (Chuẩn)'),
              _buildDayChip(14, '14 Ngày'),
              _buildDayChip(30, '30 Ngày'),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            '🗓️ Hạn trả dự kiến: ${DateFormat('dd/MM/yyyy').format(_dueDate)}',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Ghi chú mục đích mượn
          const Text(
            'Ghi chú / Mục đích mượn (tùy chọn):',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Ví dụ: Cần mượn bản thảo in để ôn thi giữa kỳ...',
              hintStyle: const TextStyle(fontSize: 12),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 20),

          // Nút xác nhận gửi yêu cầu
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isSubmitting ? 'Đang gửi yêu cầu...' : 'Gửi Yêu Cầu Mượn',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(int days, String label) {
    final isSelected = _borrowDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _updateDays(days),
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppTheme.primaryColor : null,
      ),
    );
  }
}
