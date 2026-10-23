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
  int _borrowDays = 7;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
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
      final req = await borrowService.createBorrowRequest(
        documentId: widget.document.id,
        documentTitle: widget.document.title,
        borrowerId: widget.currentUserEmail,
        borrowerEmail: widget.currentUserEmail,
        borrowerName: widget.currentUserName.isNotEmpty
            ? widget.currentUserName
            : 'Sinh viên TLU',
        ownerId: 'owner_${widget.document.subjectId}',
        ownerEmail: '2351170599@e.tlu.edu.vn', // Giả lập chủ sở hữu tài liệu học phần
        ownerName: 'Nguyễn Văn Huỳnh (Nhóm trưởng)',
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
          const SizedBox(height: 16),

          // Lựa chọn thời gian mượn (Số ngày)
          const Text(
            'Thời hạn mượn dự kiến:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildDayChip(3, '3 Ngày'),
              const SizedBox(width: 8),
              _buildDayChip(7, '7 Ngày (Chuẩn)'),
              const SizedBox(width: 8),
              _buildDayChip(14, '14 Ngày'),
              const SizedBox(width: 8),
              _buildDayChip(30, '30 Ngày'),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            '🗓️ Hạn trả dự kiến: ${DateFormat('dd/MM/yyyy (EEEE)', 'vi').format(_dueDate)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
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
