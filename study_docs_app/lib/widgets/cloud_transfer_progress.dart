import 'dart:async';
import 'package:flutter/material.dart';

import '../functions.dart';
import '../struct/document_enums.dart';
import '../theme.dart';

/// Loại tác vụ truyền tải tệp tin Cloud
enum TransferType {
  upload, // Tải lên Firebase Cloud Storage (Asia-Southeast1)
  download, // Tải về thiết bị ngoại tuyến (Local Storage)
}

/// Trạng thái của tiến trình truyền tải
enum TransferStatus {
  idle,
  transferring,
  paused,
  completed,
  error,
}

/// Widget thanh tiến trình tải tệp Upload / Download Progress Bar
/// Phụ trách: NGUYỄN TRUNG KIÊN (MSV: 2251172394) - Nhóm 16 (65KTPM - ĐH Thủy Lợi)
/// Nhánh Git: kien-cloud-ui
class CloudTransferProgress extends StatelessWidget {
  final TransferType type;
  final String fileName;
  final DocumentFormat fileFormat;
  final int totalBytes;
  final int transferredBytes;
  final TransferStatus status;
  final String? speedText;
  final String? etaText;
  final String? errorMessage;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onDone;

  const CloudTransferProgress({
    super.key,
    required this.type,
    required this.fileName,
    this.fileFormat = DocumentFormat.pdf,
    required this.totalBytes,
    required this.transferredBytes,
    required this.status,
    this.speedText,
    this.etaText,
    this.errorMessage,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onRetry,
    this.onDone,
  });

  double get progress {
    if (totalBytes <= 0) return 0.0;
    return (transferredBytes / totalBytes).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isUpload = type == TransferType.upload;
    final primaryColor = isUpload ? AppTheme.primaryColor : const Color(0xFF0288D1);
    final accentBg = primaryColor.withValues(alpha: 0.12);

    final percentInt = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2826) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hàng 1: Icon hoạt ảnh + Tên tệp + Nút hủy
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isUpload ? Icons.cloud_upload_rounded : Icons.cloud_download_rounded,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUpload
                          ? 'Đang đẩy lên Firebase Storage (asia-southeast1)'
                          : 'Đang tải về bộ nhớ ngoại tuyến SQLite',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (status == TransferStatus.transferring && onPause != null)
                IconButton(
                  icon: const Icon(Icons.pause_circle_outline_rounded, size: 24),
                  color: Colors.orange,
                  tooltip: 'Tạm dừng tải',
                  onPressed: onPause,
                )
              else if (status == TransferStatus.paused && onResume != null)
                IconButton(
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 24),
                  color: primaryColor,
                  tooltip: 'Tiếp tục tải',
                  onPressed: onResume,
                ),
              if ((status == TransferStatus.transferring || status == TransferStatus.paused) &&
                  onCancel != null)
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, size: 22),
                  color: Colors.redAccent,
                  tooltip: 'Hủy tác vụ',
                  onPressed: onCancel,
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Hàng 2: Thanh tiến trình Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: status == TransferStatus.error ? 1.0 : progress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                status == TransferStatus.error
                    ? Colors.redAccent
                    : (status == TransferStatus.completed
                        ? Colors.green
                        : (status == TransferStatus.paused ? Colors.orange : primaryColor)),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Hàng 3: Chỉ số chi tiết (%, Dung lượng, Tốc độ, ETA)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppFunctions.formatFileSize(transferredBytes)} / ${AppFunctions.formatFileSize(totalBytes)} ($percentInt%)',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              if (status == TransferStatus.transferring)
                Text(
                  '${speedText ?? "2.8 MB/s"} • ${etaText ?? "~2s"}',
                  style: TextStyle(
                    fontSize: 11,
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (status == TransferStatus.paused)
                const Text(
                  'Đã tạm dừng (Resumable)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (status == TransferStatus.completed)
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Hoàn tất 100%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else if (status == TransferStatus.error)
                Text(
                  errorMessage ?? 'Lỗi truyền tải',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),

          if (status == TransferStatus.completed && onDone != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Xong'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onDone,
              ),
            ),
          ],

          if (status == TransferStatus.error && onRetry != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onCancel != null)
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Hủy'),
                  ),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Thử lại'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onRetry,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Hiển thị BottomSheet tương tác tải file Cloud
  static Future<bool> showTransferSheet({
    required BuildContext context,
    required TransferType type,
    required String fileName,
    required int totalBytes,
    DocumentFormat fileFormat = DocumentFormat.pdf,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InteractiveTransferModal(
        type: type,
        fileName: fileName,
        totalBytes: totalBytes,
        fileFormat: fileFormat,
      ),
    );
    return result ?? false;
  }
}

/// Modal quản lý luồng truyền tải thời gian thực (Simulation & Stream)
class _InteractiveTransferModal extends StatefulWidget {
  final TransferType type;
  final String fileName;
  final int totalBytes;
  final DocumentFormat fileFormat;

  const _InteractiveTransferModal({
    required this.type,
    required this.fileName,
    required this.totalBytes,
    required this.fileFormat,
  });

  @override
  State<_InteractiveTransferModal> createState() => _InteractiveTransferModalState();
}

class _InteractiveTransferModalState extends State<_InteractiveTransferModal> {
  Timer? _timer;
  int _transferredBytes = 0;
  TransferStatus _status = TransferStatus.transferring;
  final double _speedMbps = 35.0;

  @override
  void initState() {
    super.initState();
    _startTransfer();
  }

  void _startTransfer() {
    _status = TransferStatus.transferring;
    const intervalMs = 50;
    // Mỗi step tăng một lượng byte dựa theo tốc độ
    final bytesPerStep = ((_speedMbps * 1024 * 1024) / (1000 / intervalMs)).round();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: intervalMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _transferredBytes += bytesPerStep;
        if (_transferredBytes >= widget.totalBytes) {
          _transferredBytes = widget.totalBytes;
          _status = TransferStatus.completed;
          t.cancel();
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        }
      });
    });
  }

  void _pauseTransfer() {
    _timer?.cancel();
    setState(() => _status = TransferStatus.paused);
  }

  void _resumeTransfer() {
    _startTransfer();
  }

  void _cancelTransfer() {
    _timer?.cancel();
    Navigator.of(context).pop(false);
  }

  void _retryTransfer() {
    setState(() => _transferredBytes = 0);
    _startTransfer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainingBytes = widget.totalBytes - _transferredBytes;
    final remainingSeconds =
        (_speedMbps > 0 ? (remainingBytes / (_speedMbps * 1024 * 1024)).ceil() : 0);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: CloudTransferProgress(
        type: widget.type,
        fileName: widget.fileName,
        fileFormat: widget.fileFormat,
        totalBytes: widget.totalBytes,
        transferredBytes: _transferredBytes,
        status: _status,
        speedText: '${_speedMbps.toStringAsFixed(1)} MB/s',
        etaText: '~${remainingSeconds}s',
        onPause: _pauseTransfer,
        onResume: _resumeTransfer,
        onCancel: _cancelTransfer,
        onRetry: _retryTransfer,
        onDone: () => Navigator.of(context).pop(true),
      ),
    );
  }
}
